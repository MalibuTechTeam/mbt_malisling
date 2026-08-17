import { useState, useEffect, useCallback, useRef } from 'react'
import { fetchNui } from '../utils/fetchNui'
import { Icon } from './ui/Icon'
import { Select } from './ui/Select'
import { CamSlider } from './ui/CamSlider'
import { NumberInput } from './ui/NumberInput'

/**
 * GestureOverlay — audition every holster animation on your own character, then keep the one
 * that reads best. The dashboard collapses behind it, exactly like the position editors.
 *
 * Why an overlay and not a dropdown in the card: a gesture cannot be chosen from its name.
 * `weapons@holster_2h / unholster` and `reaction@intimidation@1h / intro` are both plausible
 * strings and one of them is a man threatening someone. The only way to pick is to watch it.
 *
 * SCOPE — this edits `style + slot`, and nothing else. Not per job, not per gender: a style is
 * assigned to jobs in the card behind this, so a gesture saved here changes the draw for every
 * job pointed at that style. That is why the header states the style it is writing to instead
 * of just saying "Draw Style".
 *
 * Auditioning is free and local. Nothing leaves this client until Use is pressed.
 */

interface Gesture { dict?: string; dictOut?: string; animIn?: string; animOut?: string }
interface Candidate extends Gesture { id: string; label: string; fits?: string }
interface Resolved extends Gesture { sleep?: number; sleepOut?: number }

interface Props {
  /** Style to open on — the server's active one. Becomes editable here when several are live. */
  style: string
  styleLabel: string
  /** The whole catalogue, for the scope selector shown in multi-style mode. */
  styles?: { id: string; label: string }[]
  candidates: Candidate[]
  /** The style the server actually draws with, and its label — see the in-use warning below. */
  activeStyle?: string
  activeLabel?: string
  /**
   * True when more than one style is genuinely in play, i.e. a per-job rule exists.
   *
   * When false this panel says nothing about styles at all. There is one, everyone uses it, and
   * naming it only invites the question "what is a style?" in front of someone who wants to
   * change how a pistol comes out of a holster.
   */
  multiStyle?: boolean
  onClose: () => void
}

// The slots as an owner thinks of them. Falls back to the raw key for a slot added in
// default.lua that this list has not been taught — better a bare `harness` in the dropdown
// than a slot you cannot reach.
const SLOT_LABELS: Record<string, string> = {
  side: 'Pistol',
  back: 'Rifle / Long gun',
  back2: 'Heavy / Launcher',
  melee: 'Melee',
  melee2: 'Knife',
  melee3: 'Hatchet / Alt melee',
  extinguisher: 'Fire extinguisher',
}

// Browser-dev stand-in for what Lua reports on enter. Ignored in-game: fetchNui only returns
// mock data when there is no invokeNative. Without it the panel previews with no slot list and
// no "In use" block — the two things worth looking at while styling it.
const DEV_ENTER = {
  ok: true,
  yaw: 150,
  slots: ['back', 'back2', 'extinguisher', 'melee', 'melee2', 'melee3', 'side'],
  current: {
    side: { dict: 'reaction@intimidation@cop@unarmed', animIn: 'intro', animOut: 'outro', sleep: 400, sleepOut: 450 },
    back: { dict: 'reaction@intimidation@1h', animIn: 'intro', animOut: 'outro', sleep: 1200, sleepOut: 1600 },
  } as Record<string, Resolved>,
}

const same = (a: Gesture | undefined, b: Gesture | undefined) =>
  !!a && !!b && a.dict === b.dict && a.animIn === b.animIn &&
  (a.animOut ?? '') === (b.animOut ?? '') && (a.dictOut ?? '') === (b.dictOut ?? '')

export function GestureOverlay(
  { style: initialStyle, styleLabel: initialLabel, styles, candidates,
    activeStyle, activeLabel, multiStyle, onClose }: Props,
) {
  // The scope lives HERE, with the slot selector, because both answer "what am I editing" —
  // and putting the style half of that question on the card behind this is what let the two
  // drift apart unnoticed.
  const [style, setStyle] = useState(initialStyle)
  const styleLabel = styles?.find((s) => s.id === style)?.label ?? initialLabel
  // Editing a style the server does not draw with. The save works perfectly and nothing
  // changes in game, which is the worst way for a feature to fail — it looks broken rather
  // than misaimed. Said here, where the saving happens, not in a doc nobody reads.
  // Cannot happen with one style in play, which is why the whole warning is conditional.
  const orphan = !!multiStyle && !!activeStyle && activeStyle !== style
  const [slots, setSlots] = useState<string[]>([])
  const [slot, setSlot] = useState('side')
  const [current, setCurrent] = useState<Record<string, Resolved>>({})
  const [dir, setDir] = useState<'in' | 'out'>('in')
  const [busy, setBusy] = useState('')
  const [err, setErr] = useState('')
  const [saved, setSaved] = useState('')
  const [custom, setCustom] = useState<Gesture>({ dict: '', animIn: '', animOut: '' })
  // Degrees around the ped, relative to its heading — 0 is its front, 180 its back.
  const [yaw, setYaw] = useState(150)
  const setCam = (v: number) => { setYaw(v); fetchNui('drawStyle:cam', { yaw: v }) }

  // What each slot resolves to RIGHT NOW, for this style. Computed in Lua: two of the three
  // layers (PropInfo, MBT.DrawStyles) are code and never reach the NUI, so a panel deciding
  // this on its own would be guessing at the answer it exists to display.
  useEffect(() => {
    fetchNui('drawStyle:enter', { style }, DEV_ENTER).then((r: any) => {
      if (Array.isArray(r?.slots) && r.slots.length) {
        setSlots(r.slots)
        if (!r.slots.includes('side')) setSlot(r.slots[0])
      }
      if (r?.current) setCurrent(r.current)
      // The camera keeps its angle across a re-open, so the slider reads Lua rather than
      // snapping the view back to a default the admin already moved away from.
      if (typeof r?.yaw === 'number') setYaw(r.yaw)
    })
  }, [style])

  // Leave gesture mode on ANY unmount path — button, Escape, the dashboard closing under us —
  // so the ped never stays stuck mid-clip.
  useEffect(() => () => { fetchNui('drawStyle:exit') }, [])

  const cardRef = useRef<HTMLDivElement>(null)
  useEffect(() => { cardRef.current?.querySelector<HTMLElement>('button, input, [tabindex]')?.focus() }, [])
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => { if (e.key === 'Escape') { e.stopPropagation(); onClose() } }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [onClose])

  const cur = current[slot]

  /**
   * The duration being auditioned, in ms — and the one Save writes.
   *
   * It is a control and not a read-out because `sleep` is BOTH the clip's playback length and
   * the gate before the weapon reaches the hand: the pistol slot ships 400ms, tuned against the
   * short intimidation clip it came with, and a real holster animation runs about a second. Pick
   * one without touching this and you watch a third of it, in the picker AND in the game. The
   * clip is half a gesture; the time it is given is the other half.
   */
  const [ms, setMs] = useState<{ sleep: number; sleepOut: number } | null>(null)
  useEffect(() => {
    setMs(cur ? { sleep: cur.sleep ?? 1200, sleepOut: cur.sleepOut ?? 1200 } : null)
  }, [slot, cur])
  const curMs = (dir === 'out' ? ms?.sleepOut : ms?.sleep) ?? 1200
  // Natural length of the clip played last, from GetAnimDuration. Null until something plays.
  const [clipMs, setClipMs] = useState<number | null>(null)
  useEffect(() => { setClipMs(null) }, [slot, dir])

  // `override` lets one caller ask for an untrimmed pass — long enough that any clip in GTA
  // finishes — so "I dislike this gesture" can be told apart from "I am only seeing a third
  // of it". It plays; it never saves.
  const play = useCallback((g: Gesture, id: string, override?: number) => {
    const dict = dir === 'out' ? (g.dictOut || g.dict) : g.dict
    const clip = dir === 'out' ? g.animOut : g.animIn
    if (!dict || !clip) { setErr(`this entry has no "${dir === 'out' ? 'put away' : 'draw'}" clip`); return }
    setErr(''); setBusy(id)
    const len = override ?? curMs
    fetchNui('drawStyle:play', { dict, clip, ms: len }, { ok: true, clipMs: 1133 }).then((r: any) => {
      if (r && r.ok === false) { setErr(r.err || 'the clip did not play'); setClipMs(null); return }
      // Measured by Lua, so "Fit" is the clip's real length and not a guess. Kept per play
      // rather than for the whole list: measuring 17 entries × 2 directions on open would
      // stall the panel to load dictionaries the admin may never audition.
      setClipMs(typeof r?.clipMs === 'number' ? r.clipMs : null)
    }).finally(() => window.setTimeout(() => setBusy(''), len))
  }, [dir, curMs])

  /**
   * Persist. `false` clears a field back to what the server ships; omitting it leaves it alone.
   *
   * Not `null` for a clear: JSON null arrives in Lua as nil, indistinguishable from "this save
   * is only about the other field" — which would have wiped the chosen gesture every time
   * someone nudged a duration.
   */
  const send = (id: string, body: { gesture?: Gesture | false; timing?: { sleep: number; sleepOut: number } | false }) => {
    setErr('')
    fetchNui('drawStyle:save', { style, slot, ...body }).then((r: any) => {
      if (!r?.ok) { setErr(r?.err || 'the server refused the save'); return }
      setSaved(id); window.setTimeout(() => setSaved(''), 1600)
      // The card's "re-picked" count updates on its own: the save broadcasts patchDraft, which
      // rewrites DrawStyleOverrides in the draft the card reads.
      //
      // Re-read the resolved state rather than assuming ours landed: the server merges, rounds
      // and clamps, and this panel should show what it stored, not what we sent.
      fetchNui('drawStyle:enter', { style }).then((s: any) => { if (s?.current) setCurrent(s.current) })
    })
  }

  /**
   * Keep a gesture — and the duration that completes it, in the same save.
   *
   * The clip and the time it is given are ONE decision: a clip stored against a duration
   * shorter than itself plays a fragment and stops, which is what every slot in this script
   * did before 2.1.0. Asking the admin to read a number off the panel and type it in would be
   * the same defect moved into the UI, so Lua measures both directions with GetAnimDuration
   * and the save carries them.
   *
   * The Draw time field stays: it is now an override for someone who wants a deliberately
   * slower or snappier draw, not a step you must complete for the feature to work.
   */
  const use = async (g: Gesture | false, id: string) => {
    if (!g) return send(id, { gesture: false, timing: false })
    const gesture = { dict: g.dict, dictOut: g.dictOut, animIn: g.animIn, animOut: g.animOut }
    const m: any = await fetchNui('drawStyle:measure', gesture, { sleep: 1133, sleepOut: 900 })
    // Clamped to the server's own bounds, and falling back to the slot's current value per
    // direction: a clip whose length could not be read must not take the other one down with it.
    const fit = (v: unknown, fallback: number) =>
      typeof v === 'number' && v > 0 ? Math.max(400, Math.min(4000, Math.round(v))) : fallback
    const timing = ms && {
      sleep: fit(m?.sleep, ms.sleep),
      sleepOut: fit(m?.sleepOut, ms.sleepOut),
    }
    send(id, { gesture, timing: timing || undefined })
  }
  const saveTiming = () => ms && send('__timing', { timing: ms })

  // The entries built for this slot first. `fits` is a hint from default.lua, not a filter —
  // an owner who wants the pistol drawn with the rifle gesture is allowed to, and that pairing
  // is exactly what the shipped Street style does.
  const sorted = [...candidates].sort((a, b) =>
    (a.fits === slot ? 0 : 1) - (b.fits === slot ? 0 : 1))
  const customReady = !!(custom.dict && custom.animIn)

  return (
    <div className="mbt-pe mbt-gp" ref={cardRef} role="dialog" aria-modal="true"
      aria-label={`Gesture picker — ${styleLabel}`}>
      <div className="mbt-pe__head">
        <Icon name="pose" size={14} />
        <b>GESTURE</b>
        <span className="mbt-pe__scope">{multiStyle ? styleLabel : 'everyone'}</span>
      </div>

      <div className="mbt-pe__hint">
        {multiStyle ? (
          <>Writes to the <b>{styleLabel}</b> style — every job assigned to it. Playing a clip
            changes nothing; only <b>Use</b> saves.</>
        ) : (
          <>Changes the gesture for <b>everyone</b> on the server. Playing a clip changes
            nothing; only <b>Use</b> saves.</>
        )}
      </div>

      {orphan && (
        <div className="mbt-gp__orphan" role="status">
          <Icon name="alert" size={13} />
          <span>
            Your server draws with <b>{activeLabel ?? activeStyle}</b>. What you save here is
            stored, but nothing will change in game until <b>{styleLabel}</b> is set as the
            Default Style — or given to a job — in the card behind this.
          </span>
        </div>
      )}

      <div className="mbt-gp__slot">
        {multiStyle && styles && styles.length > 1 && (
          <Select value={style} aria-label="Style being edited" onChange={setStyle}
            options={styles.map((s) => ({ value: s.id, label: s.label }))} />
        )}
        <Select value={slot} aria-label="Weapon slot" onChange={setSlot}
          options={(slots.length ? slots : ['side']).map((s) => ({ value: s, label: SLOT_LABELS[s] ?? s }))} />
      </div>

      <div className="mbt-pe__seg">
        <button className={dir === 'in' ? 'is-on' : ''} onClick={() => setDir('in')}>Draw</button>
        <button className={dir === 'out' ? 'is-on' : ''} onClick={() => setDir('out')}>Put away</button>
      </div>

      {cur && (
        <div className="mbt-gp__now">
          <span className="mbt-gp__nowhead">In use</span>
          <code>{(dir === 'out' ? (cur.dictOut || cur.dict) : cur.dict) ?? '—'}</code>
          <code className="mbt-gp__clip">{(dir === 'out' ? cur.animOut : cur.animIn) ?? '—'}</code>
          <button type="button" className="mbt-gp__play" title="Play the gesture in use"
            aria-label="Play the gesture in use"
            onClick={() => play(cur, '__cur')} disabled={busy === '__cur'}>
            <Icon name="cursor" size={12} />
          </button>
        </div>
      )}

      {/* Duration. Sits between the current gesture and the catalogue because it applies to
          both: every ▶ on this panel plays at this value, so what you audition is what a
          player gets. Filled in by Use, which measures the clip it saves — this row is the
          override, not a step you have to complete. Per SLOT and server-wide, never per style
          and never per job. */}
      <div className="mbt-gp__timing">
        <span className="mbt-pe__camhead" title="Set automatically by Use; change it only to deviate from the clip's own length">
          {dir === 'out' ? 'Put-away time' : 'Draw time'}
        </span>
        {/* 400 is the server's floor, not a UI preference — the fastest draw the script ships.
            Matched here so the field cannot offer a value the save will reject. */}
        <NumberInput min={400} max={4000} step={50} ariaLabel="Duration in milliseconds"
          value={String(curMs)}
          onChange={(raw) => {
            const v = parseInt(raw, 10)
            if (!ms || Number.isNaN(v)) return
            setMs(dir === 'out' ? { ...ms, sleepOut: v } : { ...ms, sleep: v })
          }} />
        {/* Fit appears only once something has played, because only then is the clip's length
            known. Before that it would be a button with nothing to fit to. */}
        {clipMs ? (
          <button type="button" className="mbt-btn-ghost"
            title={`The clip that just played runs ${clipMs}ms`}
            onClick={() => {
              if (!ms) return
              // Clamped to the same floor the server enforces: a clip shorter than 400ms would
              // otherwise fill the field with a value whose Save comes back rejected.
              const v = Math.max(400, Math.min(4000, clipMs))
              setMs(dir === 'out' ? { ...ms, sleepOut: v } : { ...ms, sleep: v })
            }}>
            Fit {clipMs}
          </button>
        ) : (
          <button type="button" className="mbt-btn-ghost" disabled={!cur}
            title="Play the whole clip once, ignoring the duration above"
            onClick={() => cur && play(cur, '__untrim', 4000)}>Untrimmed</button>
        )}
        <button type="button" className={`mbt-btn-ghost${saved === '__timing' ? ' is-complete' : ''}`}
          disabled={!ms} onClick={saveTiming}>
          {saved === '__timing' ? 'Saved' : 'Save time'}
        </button>
      </div>

      <div className="mbt-gp__list" role="list">
        {sorted.map((c) => {
          const isOn = same(cur, c)
          return (
            <div key={c.id} role="listitem"
              className={`mbt-gp__row${isOn ? ' is-on' : ''}${c.fits === slot ? ' is-fit' : ''}`}>
              <span className="mbt-gp__info">
                <span className="mbt-gp__nm">{c.label}</span>
                <span className="mbt-gp__path">
                  {dir === 'out' ? (c.dictOut || c.dict) : c.dict} · {dir === 'out' ? c.animOut : c.animIn}
                </span>
              </span>
              <button type="button" className="mbt-gp__play" title={`Play — ${c.label}`}
                aria-label={`Play ${c.label}`}
                onClick={() => play(c, c.id)} disabled={busy === c.id}>
                <Icon name="cursor" size={12} />
              </button>
              <button type="button" className={`mbt-btn-ghost mbt-gp__use${saved === c.id ? ' is-complete' : ''}`}
                onClick={() => use(c, c.id)} aria-live="polite">
                {saved === c.id ? 'Saved' : isOn ? 'In use' : 'Use'}
              </button>
            </div>
          )
        })}
      </div>

      {/* Any dict, typed by hand. The seed list can never know about an animation the server
          installed itself, and a picker that only offers what shipped would be a shorter list
          than the server actually has. */}
      <div className="mbt-gp__custom">
        <span className="mbt-pe__camhead">Your own dict</span>
        <input className="mbt-input" placeholder="dict — e.g. weapons@holster_2h"
          aria-label="Animation dictionary" value={custom.dict ?? ''}
          onChange={(e) => setCustom({ ...custom, dict: e.target.value.trim() })} />
        <div className="mbt-gp__custom-row">
          <input className="mbt-input" placeholder="draw clip" aria-label="Draw clip"
            value={custom.animIn ?? ''}
            onChange={(e) => setCustom({ ...custom, animIn: e.target.value.trim() })} />
          <input className="mbt-input" placeholder="put-away clip" aria-label="Put-away clip"
            value={custom.animOut ?? ''}
            onChange={(e) => setCustom({ ...custom, animOut: e.target.value.trim() })} />
        </div>
        <div className="mbt-gp__custom-row">
          <button type="button" className="mbt-btn-ghost" disabled={!customReady}
            onClick={() => play(custom, '__custom')}>Play</button>
          <button type="button" className={`mbt-btn-ghost${saved === '__custom' ? ' is-complete' : ''}`}
            disabled={!customReady} onClick={() => use(custom, '__custom')}>
            {saved === '__custom' ? 'Saved' : 'Use'}
          </button>
        </div>
      </div>

      {/* One axis, because one axis is what this needs: a hip draw reads from the front and a
          rifle off the back reads from behind. Height and distance were never the thing you
          wanted to move while watching a gesture, so they are fixed in Lua. */}
      <div className="mbt-pe__cam">
        <CamSlider label="Camera" min={0} max={360} step={5} val={yaw} unit="°"
          fmt={(v) => String(Math.round(v))} onChange={setCam} />
      </div>

      {err && <div className="mbt-gp__err" role="alert">{err}</div>}

      <div className="mbt-pe__actions">
        {/* Clears BOTH halves — the clip and the duration. A reset that left a 900ms timing
            behind on the shipped 400ms clip would be a slot nobody chose. */}
        <button className="mbt-btn-ghost"
          onClick={() => send('__reset', { gesture: false, timing: false })}
          title="Back to the clip and the duration this style ships with">
          {saved === '__reset' ? 'Reset' : 'Reset slot'}
        </button>
        <button className="mbt-btn-primary" onClick={onClose}>Done</button>
      </div>
    </div>
  )
}

export default GestureOverlay
