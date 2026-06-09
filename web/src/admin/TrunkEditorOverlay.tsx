import { useState, useCallback, useEffect, useRef } from 'react'
import { fetchNui } from '../utils/fetchNui'
import { Icon } from './ui/Icon'
import { CamSlider } from './ui/CamSlider'

/**
 * TrunkEditorOverlay — floating control card for live-editing the trunk weapon
 * offset. Mirrors PropEditorOverlay: the dashboard collapses behind it, an orbit
 * camera (Lua) frames the open trunk of the CLOSEST vehicle, and Pos/Rot nudges
 * re-attach the preview weapon live. Save writes a per-model or per-class override
 * through the ACE-checked offset event. `trunkEdit:start` already ran in the opener
 * (so a "no vehicle nearby" failure never collapses the dashboard).
 */

interface Vec { x: number; y: number; z: number }
interface Off { Pos: Vec; Rot: Vec }
interface View { yaw: number; pitch: number; dist: number }
interface Props { model: string; vclass: number; off: Off; view?: View; onClose: () => void }

// Wrap an angle to -180..180 (slider centre = 0°, no 0/360 jump).
const n180 = (v: number) => { const m = (((v % 360) + 360) % 360); return m > 180 ? m - 360 : m }
const clamp = (v: number, lo: number, hi: number) => Math.max(lo, Math.min(hi, Number(v) || 0))
// Pitch/Roll are capped at ±45°: larger combined tilt gimbal-locks the vehicle
// boot-bone attach (yaw stops responding, the prop snaps to a degenerate pose). Yaw
// stays free. safeOff also scrubs any corrupt rotation reloaded from an old DB row.
const TRUNK_MAX_TILT = 45
const safeOff = (o: Off): Off => ({
  Pos: { ...o.Pos },
  Rot: {
    x: clamp(n180(o.Rot.x), -TRUNK_MAX_TILT, TRUNK_MAX_TILT),
    y: clamp(n180(o.Rot.y), -TRUNK_MAX_TILT, TRUNK_MAX_TILT),
    z: n180(o.Rot.z),
  },
})

export function TrunkEditorOverlay({ model, vclass, off: initOff, view: initView, onClose }: Props) {
  const [off, setOff] = useState<Off>(() => safeOff(initOff))
  const [view, setView] = useState<View>(initView ?? { yaw: 180, pitch: -15, dist: 2.6 })
  const [scope, setScope] = useState<'model' | 'class'>('model')
  const [saved, setSaved] = useState(false)

  const push = useCallback((next: Off) => {
    next = safeOff(next)   // cap pitch/roll to the gimbal-safe range before applying
    setOff(next)
    fetchNui('trunkEdit:update', { off: next })
  }, [])

  const setAxis = (kind: 'Pos' | 'Rot', axis: 'x' | 'y' | 'z', v: number) => {
    const next = structuredClone(off)
    next[kind][axis] = v
    push(next)
  }
  const setCam = (key: 'yaw' | 'pitch' | 'dist', v: number) => {
    const next = { ...view, [key]: v }
    setView(next)
    fetchNui('trunkEdit:cam', next)
  }
  const save = () => {
    fetchNui('trunkEdit:save', { scope })
    setSaved(true); window.setTimeout(() => setSaved(false), 1200)
  }
  const reset = () => fetchNui('trunkEdit:reset').then((r: any) => { if (r?.Pos) setOff(safeOff(r)) })
  const close = () => { fetchNui('trunkEdit:stop'); onClose() }

  const cardRef = useRef<HTMLDivElement>(null)
  // Stop the Lua editor on ANY unmount path (button, Escape, parent close) so the
  // camera/ped never get left in edit state.
  useEffect(() => () => { fetchNui('trunkEdit:stop') }, [])
  // Focus into the card once on open.
  useEffect(() => { cardRef.current?.querySelector<HTMLElement>('button, input, [tabindex]')?.focus() }, [])
  // Escape closes the editor (the dashboard yields Escape while an editor is open).
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => { if (e.key === 'Escape') { e.stopPropagation(); onClose() } }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [onClose])

  return (
    <div className="mbt-pe" ref={cardRef} role="dialog" aria-modal="true"
      aria-label={`Trunk weapon editor — ${model}`}>
      <div className="mbt-pe__head">
        <Icon name="vehicle" size={14} />
        <b>TRUNK</b>
        <span className="mbt-pe__scope">{model} · cls {vclass}</span>
      </div>

      <div className="mbt-pe__seg">
        <button className={scope === 'model' ? 'is-on' : ''} onClick={() => setScope('model')}>This model</button>
        <button className={scope === 'class' ? 'is-on' : ''} onClick={() => setScope('class')}>Whole class</button>
      </div>

      <div className="mbt-pe__axgroup">
        <span className="mbt-pe__camhead">Position (m)</span>
        <CamSlider label="Left / Right" min={-1} max={1} step={0.005} val={off.Pos.x} fmt={(v) => v.toFixed(3)} onChange={(v) => setAxis('Pos', 'x', v)} />
        <CamSlider label="Fwd / Back"   min={-1} max={1} step={0.005} val={off.Pos.y} fmt={(v) => v.toFixed(3)} onChange={(v) => setAxis('Pos', 'y', v)} />
        <CamSlider label="Up / Down"    min={-1} max={1} step={0.005} val={off.Pos.z} fmt={(v) => v.toFixed(3)} onChange={(v) => setAxis('Pos', 'z', v)} />
      </div>
      <div className="mbt-pe__axgroup">
        <span className="mbt-pe__camhead">Rotation (°)</span>
        <CamSlider label="Pitch" min={-45} max={45} step={1} val={off.Rot.x} unit="°" fmt={(v) => String(Math.round(v))} onChange={(v) => setAxis('Rot', 'x', v)} />
        <CamSlider label="Roll"  min={-45} max={45} step={1} val={off.Rot.y} unit="°" fmt={(v) => String(Math.round(v))} onChange={(v) => setAxis('Rot', 'y', v)} />
        <CamSlider label="Yaw"   min={-180} max={180} step={1} val={n180(off.Rot.z)} unit="°" fmt={(v) => String(Math.round(v))} onChange={(v) => setAxis('Rot', 'z', v)} />
      </div>

      <div className="mbt-pe__cam">
        <span className="mbt-pe__camhead">Camera</span>
        <CamSlider label="Rotate"   min={0}   max={360} step={1}    val={view.yaw}   unit="°" fmt={(v) => String(Math.round(v))} onChange={(v) => setCam('yaw', v)} />
        <CamSlider label="Height"   min={-45} max={45}  step={1}    val={view.pitch} unit="°" fmt={(v) => String(Math.round(v))} onChange={(v) => setCam('pitch', v)} />
        <CamSlider label="Distance" min={1}   max={6}   step={0.05} val={view.dist}  unit="m" fmt={(v) => v.toFixed(1)} onChange={(v) => setCam('dist', v)} />
      </div>

      <div className="mbt-pe__actions">
        <button className="mbt-btn-ghost" onClick={reset}>Reset</button>
        <button className="mbt-btn-ghost" onClick={close}>Close</button>
        <button className={`mbt-btn-primary${saved ? ' is-complete' : ''}`} onClick={save} aria-live="polite">
          <Icon name="save" size={13} /> {saved ? 'Saved' : (scope === 'model' ? 'Save model' : 'Save class')}
        </button>
      </div>
    </div>
  )
}
