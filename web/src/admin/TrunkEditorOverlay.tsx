import { useState, useCallback } from 'react'
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

export function TrunkEditorOverlay({ model, vclass, off: initOff, view: initView, onClose }: Props) {
  const [off, setOff] = useState<Off>(initOff)
  const [view, setView] = useState<View>(initView ?? { yaw: 180, pitch: -15, dist: 2.6 })
  const [scope, setScope] = useState<'model' | 'class'>('model')
  const [saved, setSaved] = useState(false)

  const push = useCallback((next: Off) => {
    setOff(next)
    fetchNui('trunkEdit:update', { off: next })
  }, [])

  const setAxis = (kind: 'Pos' | 'Rot', axis: 'x' | 'y' | 'z', v: number) => {
    const next = structuredClone(off)
    next[kind][axis] = v
    push(next)
  }
  const n180 = (v: number) => { const m = (((v % 360) + 360) % 360); return m > 180 ? m - 360 : m }
  const setCam = (key: 'yaw' | 'pitch' | 'dist', v: number) => {
    const next = { ...view, [key]: v }
    setView(next)
    fetchNui('trunkEdit:cam', next)
  }
  const save = () => {
    fetchNui('trunkEdit:save', { scope })
    setSaved(true); window.setTimeout(() => setSaved(false), 1200)
  }
  const reset = () => fetchNui('trunkEdit:reset').then((r: any) => { if (r?.Pos) setOff(r) })
  const close = () => { fetchNui('trunkEdit:stop'); onClose() }


  return (
    <div className="mbt-pe">
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
        <CamSlider label="Pitch" min={-180} max={180} step={1} val={n180(off.Rot.x)} unit="°" fmt={(v) => String(Math.round(v))} onChange={(v) => setAxis('Rot', 'x', v)} />
        <CamSlider label="Roll"  min={-180} max={180} step={1} val={n180(off.Rot.y)} unit="°" fmt={(v) => String(Math.round(v))} onChange={(v) => setAxis('Rot', 'y', v)} />
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
        <button className={`mbt-btn-primary${saved ? ' is-complete' : ''}`} onClick={save}>
          <Icon name="save" size={13} /> {saved ? 'Saved' : (scope === 'model' ? 'Save model' : 'Save class')}
        </button>
      </div>
    </div>
  )
}
