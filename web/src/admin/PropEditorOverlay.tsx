import { useEffect, useState, useCallback, useRef } from 'react'
import { fetchNui } from '../utils/fetchNui'
import { Icon } from './ui/Icon'
import { Select } from './ui/Select'
import { CamSlider } from './ui/CamSlider'

/**
 * PropEditorOverlay — the floating control card shown while live-editing a weapon
 * prop position. The dashboard collapses behind it (game world visible); this card
 * keeps pointer events. Pos/Rot nudges re-attach the preview prop live via Lua;
 * camera buttons orbit a scripted cam. Save/Reset go through ACE-checked events.
 */

interface Vec { x: number; y: number; z: number }
interface Data {
  Bone: number; isPed: boolean; RotOrder: number; FixedRot: boolean
  Pos: { male: Vec; female: Vec }; Rot: { male: Vec; female: Vec }
}
interface Props { wtype: string; job: string; gender: string; onClose: () => void }

// The length-class shift for the loaded preview weapon. Not per-gender and not per-job —
// a weapon's length is the same whoever carries it — which is why it saves somewhere else
// than the position and why the gender switch goes quiet while it is being edited.
interface Offset { Pos: Vec; Rot: Vec }
const ZERO_OFFSET: Offset = { Pos: { x: 0, y: 0, z: 0 }, Rot: { x: 0, y: 0, z: 0 } }

// Weapons offered as a preview for each body slot, chosen as the EXTREMES of what that slot
// carries plus the middle: a position tuned against one model is a bet that the other 39 are
// the same size, and this is how you check instead of hoping. Purely a way of looking —
// picking one changes nothing that gets saved. The lane suffix ('back#2') is stripped first:
// a lane holds the same weapons as its slot.
const PREVIEW_WEAPONS: Record<string, { v: string; l: string }[]> = {
  back: [
    { v: 'WEAPON_CARBINERIFLE', l: 'Carbine — standard' },
    { v: 'WEAPON_SAWNOFFSHOTGUN', l: 'Sawn-off — compact' },
    { v: 'WEAPON_HEAVYSNIPER', l: 'Heavy sniper — long' },
    { v: 'WEAPON_PUMPSHOTGUN', l: 'Pump shotgun' },
    { v: 'WEAPON_SMG', l: 'SMG' },
  ],
  back2: [
    { v: 'WEAPON_RPG', l: 'RPG' },
    { v: 'WEAPON_HOMINGLAUNCHER', l: 'Homing launcher' },
  ],
  side: [
    { v: 'WEAPON_PISTOL', l: 'Pistol — standard' },
    { v: 'WEAPON_PISTOL50', l: 'Pistol .50 — large' },
    { v: 'WEAPON_SNSPISTOL', l: 'SNS — compact' },
  ],
  melee: [
    { v: 'WEAPON_HATCHET', l: 'Hatchet' },
    { v: 'WEAPON_BATTLEAXE', l: 'Battle axe — long' },
    { v: 'WEAPON_WRENCH', l: 'Wrench — compact' },
  ],
  melee2: [
    { v: 'WEAPON_KNIFE', l: 'Knife' },
    { v: 'WEAPON_MACHETE', l: 'Machete — long' },
    { v: 'WEAPON_NIGHTSTICK', l: 'Nightstick' },
  ],
  melee3: [
    { v: 'WEAPON_BAT', l: 'Bat' },
    { v: 'WEAPON_POOLCUE', l: 'Pool cue — long' },
    { v: 'WEAPON_GOLFCLUB', l: 'Golf club' },
  ],
}

const BONES = [
  { id: 24816, label: 'Upper back' },
  { id: 24818, label: 'Chest' },
  { id: 23553, label: 'Lower back' },
  { id: 11816, label: 'Pelvis' },
  { id: 51826, label: 'Right thigh' },
  { id: 58271, label: 'Left thigh' },
  { id: 57005, label: 'Right hand' },
  { id: 36029, label: 'Left hand' },
]

// Wrap an angle to -180..180 and force the attach flags the Lua side needs:
// isPed=true (so the native applies full pitch/roll/yaw — isPed=false ignored pitch
// and only took negative roll, which produced the NaN matrix), integer Bone/RotOrder.
const normAngle = (v: number) => { const m = ((((Number(v) || 0) + 180) % 360) + 360) % 360; return m - 180 }
const normalizeData = (d: Data): Data => {
  const c = structuredClone(d)
  return {
    ...c,
    Bone: Math.trunc(Number(d.Bone) || 0),
    RotOrder: Math.trunc(Number(d.RotOrder) || 2),
    FixedRot: d.FixedRot !== false,
    isPed: true,
    Rot: {
      male:   { x: normAngle(d.Rot.male.x),   y: normAngle(d.Rot.male.y),   z: normAngle(d.Rot.male.z) },
      female: { x: normAngle(d.Rot.female.x), y: normAngle(d.Rot.female.y), z: normAngle(d.Rot.female.z) },
    },
  }
}

export function PropEditorOverlay({ wtype, job, gender: initGender, onClose }: Props) {
  const [data, setData] = useState<Data | null>(null)
  const [gender, setGender] = useState<'male' | 'female'>(initGender === 'female' ? 'female' : 'male')
  const [saved, setSaved] = useState(false)
  const [view, setView] = useState({ yaw: 180, pitch: -5, dist: 2.4 })

  // Which weapon the preview is wearing, and its length class. Never saved.
  const slot = wtype.replace(/#\d+$/, '')
  const weapons = PREVIEW_WEAPONS[slot] ?? []
  const [previewWeapon, setPreviewWeapon] = useState(weapons[0]?.v ?? '')
  const [previewClass, setPreviewClass] = useState('standard')

  // Which of the two the sliders are moving. A weapon whose class is 'standard' has no
  // offset to move: the slot's tuned position IS the standard, and a second control
  // saying the same thing would only make it ambiguous which one did the moving.
  const [target, setTarget] = useState<'position' | 'offset'>('position')
  // null = this slot declares no class offsets, so there is nothing to edit. Driven by what
  // Lua sends back rather than by the class name alone: offering a control whose save the
  // server would silently drop is worse than not offering it.
  const [offset, setOffset] = useState<Offset | null>(null)
  const [offsetDirty, setOffsetDirty] = useState(false)
  const hasOffset = offset !== null && (previewClass === 'compact' || previewClass === 'long')

  const pickWeapon = (v: string) => {
    setPreviewWeapon(v)
    fetchNui('propEdit:previewWeapon', { weapon: v }).then((r: any) => {
      if (!r?.ok) return
      const cls = r.class || 'standard'
      setPreviewClass(cls)
      setOffset(r.offset ?? null)
      setOffsetDirty(false)
      // Loading a standard weapon while the offset tab is open would leave the sliders
      // pointing at nothing.
      if (cls !== 'compact' && cls !== 'long') setTarget('position')
    })
  }

  // Enter edit mode once; leave on unmount.
  useEffect(() => {
    let alive = true
    fetchNui('propEdit:start', { wtype, job, gender }).then((r: any) => {
      if (!alive || !r?.ok || !r.data) return
      setData(normalizeData(r.data))
      if (r.view) setView(r.view)
      if (r.weapon) setPreviewWeapon(r.weapon)
      if (r.class) setPreviewClass(r.class)
      setOffset(r.offset ?? null)
    })
    return () => { alive = false; fetchNui('propEdit:stop') }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [wtype, job])

  const push = useCallback((next: Data, g: 'male' | 'female') => {
    const normalized = normalizeData(next)
    setData(normalized)
    fetchNui('propEdit:update', { data: normalized, gender: g })
  }, [])

  // Dialog behaviour: Escape closes the editor (the dashboard yields Escape while
  // an editor is open, so this won't also close the whole panel). onClose unmounts
  // us, and the unmount cleanup above fires propEdit:stop.
  const cardRef = useRef<HTMLDivElement>(null)
  const didFocus = useRef(false)
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => { if (e.key === 'Escape') { e.stopPropagation(); onClose() } }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [onClose])
  // Move focus into the card once, when it first renders (not on every update).
  useEffect(() => {
    if (data && !didFocus.current) {
      didFocus.current = true
      cardRef.current?.querySelector<HTMLElement>('button, input, [tabindex]')?.focus()
    }
  }, [data])

  if (!data) return null
  const g = gender

  const editingOffset = target === 'offset' && hasOffset
  const pos = editingOffset && offset ? offset.Pos : data.Pos[g]
  const rot = editingOffset && offset ? offset.Rot : data.Rot[g]
  const posLimit = editingOffset ? 0.3 : 1   // a shift past 30cm is not a length correction
  const setAxis = (kind: 'Pos' | 'Rot', axis: 'x' | 'y' | 'z', v: number) => {
    if (editingOffset) {
      const next = structuredClone(offset)
      ;(next[kind] as any)[axis] = v
      setOffset(next); setOffsetDirty(true)
      fetchNui('propEdit:classOffset', next)
      return
    }
    const next = structuredClone(data)
    ;(next[kind][g] as any)[axis] = v
    push(next, g)
  }
  // Rotations are circular — map to -180..180 so the rest position (0°) is the
  // slider centre (small drags = small changes, no 0/360 wrap jump).
  const n180 = (v: number) => { const m = (((v % 360) + 360) % 360); return m > 180 ? m - 360 : m }
  const setCam = (key: 'yaw' | 'pitch' | 'dist', v: number) => {
    const next = { ...view, [key]: v }
    setView(next)
    fetchNui('propEdit:cam', next)
  }
  const setBone = (b: number) => push({ ...structuredClone(data), Bone: b }, g)
  // Switching gender has to reach Lua, not just the sliders. Without the push the preview
  // keeps the pose of the gender you left: the numbers on screen say female, the weapon on
  // the ped is still where male put it, and you tune against the wrong thing. It never
  // showed while only the male positions were ever touched.
  const pickGender = (next: 'male' | 'female') => {
    if (next === g) return
    setGender(next)
    push(structuredClone(data), next)
  }
  const copyGender = () => {
    const other = g === 'male' ? 'female' : 'male'
    const next = structuredClone(data)
    next.Pos[other] = { ...next.Pos[g] }
    next.Rot[other] = { ...next.Rot[g] }
    push(next, g)
  }
  // Saves both, because they are two halves of one adjustment: you tune the position on a
  // standard weapon, load a long one, correct the shift — and clicking Save once should
  // keep everything you just did, not the half the active tab happens to point at.
  const save = () => {
    fetchNui('propEdit:save', { scope: job, wtype, data: normalizeData(data) })
    if (offsetDirty) { fetchNui('propEdit:saveClassOffset', {}); setOffsetDirty(false) }
    setSaved(true); window.setTimeout(() => setSaved(false), 1200)
  }
  // Reset to the FACTORY default (config.lua) — clears any saved override and snaps
  // the sliders + live preview back to a known-good position (Lua returns it).
  const reset = () => {
    // On the shift tab Reset means "no shift" — resetting the position from here would
    // undo work on a tab you are not looking at.
    if (editingOffset) {
      setOffset(ZERO_OFFSET); setOffsetDirty(true)
      fetchNui('propEdit:classOffset', ZERO_OFFSET)
      return
    }
    fetchNui('propEdit:reset', { scope: job, wtype, gender: g }).then((r: any) => {
      if (r && r.Pos) setData(normalizeData(r))
    })
  }
  const close = () => { fetchNui('propEdit:stop'); onClose() }

  return (
    <div className="mbt-pe" ref={cardRef} role="dialog" aria-modal="true"
      aria-label={`Weapon position editor — ${wtype.toUpperCase()}`}>
      <div className="mbt-pe__head">
        <Icon name="configure" size={14} />
        <b>{wtype.toUpperCase()}</b>
        <span className="mbt-pe__scope">{job === 'default' ? 'Default' : job}</span>
      </div>

      {/* Disabled, not hidden, while the offset is being edited: the offset is not
          per-gender, and a control that vanishes reads as a bug where one that greys out
          reads as an answer. */}
      <div className="mbt-pe__seg" aria-disabled={editingOffset}>
        <button className={g === 'male' ? 'is-on' : ''} disabled={editingOffset} onClick={() => pickGender('male')}>Male</button>
        <button className={g === 'female' ? 'is-on' : ''} disabled={editingOffset} onClick={() => pickGender('female')}>Female</button>
        <button className="mbt-pe__copy" disabled={editingOffset} onClick={copyGender}>Copy →</button>
      </div>

      {hasOffset && (
        <div className="mbt-pe__seg mbt-pe__target">
          <button className={!editingOffset ? 'is-on' : ''} onClick={() => setTarget('position')}>Position</button>
          <button className={editingOffset ? 'is-on' : ''} onClick={() => setTarget('offset')}
            title="Shift applied to every weapon of this length class, on top of the position">
            Shift · {previewClass}
          </button>
        </div>
      )}

      <div className="mbt-pe__axgroup">
        <span className="mbt-pe__camhead">
          {editingOffset ? `${previewClass} shift (m) — every ${slot} lane` : 'Position (m)'}
        </span>
        {/* Body props all attach to the spine "Back" bone, whose LOCAL frame is rotated:
            local X runs vertically, local Z runs horizontally. Map the world-intuitive
            labels onto the matching axis so the sliders move the way they read (Left/Right
            → local Z, Up/Down → local X). The stored offset stays bone-local — only which
            slider edits which component changes. */}
        <CamSlider label="Left / Right" min={-posLimit} max={posLimit} step={0.005} val={pos.z} fmt={(v) => v.toFixed(3)} onChange={(v) => setAxis('Pos', 'z', v)} />
        <CamSlider label="Fwd / Back"   min={-posLimit} max={posLimit} step={0.005} val={pos.y} fmt={(v) => v.toFixed(3)} onChange={(v) => setAxis('Pos', 'y', v)} />
        <CamSlider label="Up / Down"    min={-posLimit} max={posLimit} step={0.005} val={pos.x} fmt={(v) => v.toFixed(3)} onChange={(v) => setAxis('Pos', 'x', v)} />
      </div>
      <div className="mbt-pe__axgroup">
        <span className="mbt-pe__camhead">{editingOffset ? 'Shift rotation (°)' : 'Rotation (°)'}</span>
        <CamSlider label="Pitch" min={-180} max={180} step={1} val={n180(rot.x)} unit="°" fmt={(v) => String(Math.round(v))} onChange={(v) => setAxis('Rot', 'x', v)} />
        <CamSlider label="Roll"  min={-180} max={180} step={1} val={n180(rot.y)} unit="°" fmt={(v) => String(Math.round(v))} onChange={(v) => setAxis('Rot', 'y', v)} />
        <CamSlider label="Yaw"   min={-180} max={180} step={1} val={n180(rot.z)} unit="°" fmt={(v) => String(Math.round(v))} onChange={(v) => setAxis('Rot', 'z', v)} />
      </div>

      {weapons.length > 1 && (
        <div className="mbt-pe__bone">
          <span>Preview</span>
          <Select value={previewWeapon} aria-label="Preview weapon" onChange={pickWeapon}
            options={weapons.map((w) => ({ value: w.v, label: w.l }))} />
          <span className="mbt-pe__class" title="Length class — shifts this weapon on top of the position">
            {previewClass}
          </span>
        </div>
      )}

      {/* The bone belongs to the position. A shift has nowhere to put one — it is added to
          whatever the position already resolved to. */}
      {!editingOffset && (
        <div className="mbt-pe__bone">
          <span>Bone</span>
          <Select value={String(data.Bone)} aria-label="Bone" onChange={(v) => setBone(Number(v))}
            options={BONES.map((b) => ({ value: String(b.id), label: b.label }))} />
        </div>
      )}

      <div className="mbt-pe__cam">
        <span className="mbt-pe__camhead">Camera</span>
        <CamSlider label="Rotate"   min={0}   max={360} step={1}    val={view.yaw}   unit="°" fmt={(v) => String(Math.round(v))} onChange={(v) => setCam('yaw', v)} />
        <CamSlider label="Height"   min={-45} max={45}  step={1}    val={view.pitch} unit="°" fmt={(v) => String(Math.round(v))} onChange={(v) => setCam('pitch', v)} />
        <CamSlider label="Distance" min={1}   max={5}   step={0.05} val={view.dist}  unit="m" fmt={(v) => v.toFixed(1)} onChange={(v) => setCam('dist', v)} />
      </div>

      <div className="mbt-pe__actions">
        <button className="mbt-btn-ghost" onClick={reset}>Reset</button>
        <button className="mbt-btn-ghost" onClick={close}>Close</button>
        <button className={`mbt-btn-primary${saved ? ' is-complete' : ''}`} onClick={save} aria-live="polite">
          <Icon name="save" size={13} /> {saved ? 'Saved' : 'Save'}
        </button>
      </div>
    </div>
  )
}
