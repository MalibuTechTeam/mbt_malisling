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

  // Enter edit mode once; leave on unmount.
  useEffect(() => {
    let alive = true
    fetchNui('propEdit:start', { wtype, job, gender }).then((r: any) => {
      if (!alive || !r?.ok || !r.data) return
      setData(normalizeData(r.data))
      if (r.view) setView(r.view)
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
  const pos = data.Pos[g]
  const rot = data.Rot[g]

  const setAxis = (kind: 'Pos' | 'Rot', axis: 'x' | 'y' | 'z', v: number) => {
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
  const copyGender = () => {
    const other = g === 'male' ? 'female' : 'male'
    const next = structuredClone(data)
    next.Pos[other] = { ...next.Pos[g] }
    next.Rot[other] = { ...next.Rot[g] }
    setData(next)
  }
  const save = () => {
    fetchNui('propEdit:save', { scope: job, wtype, data: normalizeData(data) })
    setSaved(true); window.setTimeout(() => setSaved(false), 1200)
  }
  // Reset to the FACTORY default (config.lua) — clears any saved override and snaps
  // the sliders + live preview back to a known-good position (Lua returns it).
  const reset = () => {
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

      <div className="mbt-pe__seg">
        <button className={g === 'male' ? 'is-on' : ''} onClick={() => setGender('male')}>Male</button>
        <button className={g === 'female' ? 'is-on' : ''} onClick={() => setGender('female')}>Female</button>
        <button className="mbt-pe__copy" onClick={copyGender}>Copy →</button>
      </div>

      <div className="mbt-pe__axgroup">
        <span className="mbt-pe__camhead">Position (m)</span>
        {/* Body props all attach to the spine "Back" bone, whose LOCAL frame is rotated:
            local X runs vertically, local Z runs horizontally. Map the world-intuitive
            labels onto the matching axis so the sliders move the way they read (Left/Right
            → local Z, Up/Down → local X). The stored offset stays bone-local — only which
            slider edits which component changes. */}
        <CamSlider label="Left / Right" min={-1} max={1} step={0.005} val={pos.z} fmt={(v) => v.toFixed(3)} onChange={(v) => setAxis('Pos', 'z', v)} />
        <CamSlider label="Fwd / Back"   min={-1} max={1} step={0.005} val={pos.y} fmt={(v) => v.toFixed(3)} onChange={(v) => setAxis('Pos', 'y', v)} />
        <CamSlider label="Up / Down"    min={-1} max={1} step={0.005} val={pos.x} fmt={(v) => v.toFixed(3)} onChange={(v) => setAxis('Pos', 'x', v)} />
      </div>
      <div className="mbt-pe__axgroup">
        <span className="mbt-pe__camhead">Rotation (°)</span>
        <CamSlider label="Pitch" min={-180} max={180} step={1} val={n180(rot.x)} unit="°" fmt={(v) => String(Math.round(v))} onChange={(v) => setAxis('Rot', 'x', v)} />
        <CamSlider label="Roll"  min={-180} max={180} step={1} val={n180(rot.y)} unit="°" fmt={(v) => String(Math.round(v))} onChange={(v) => setAxis('Rot', 'y', v)} />
        <CamSlider label="Yaw"   min={-180} max={180} step={1} val={n180(rot.z)} unit="°" fmt={(v) => String(Math.round(v))} onChange={(v) => setAxis('Rot', 'z', v)} />
      </div>

      <div className="mbt-pe__bone">
        <span>Bone</span>
        <Select value={String(data.Bone)} aria-label="Bone" onChange={(v) => setBone(Number(v))}
          options={BONES.map((b) => ({ value: String(b.id), label: b.label }))} />
      </div>

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
