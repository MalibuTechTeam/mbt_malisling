import { useState, useCallback } from 'react'
import { fetchNui } from '../utils/fetchNui'
import { Icon } from './ui/Icon'

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
interface Props { model: string; vclass: number; off: Off; onClose: () => void }

export function TrunkEditorOverlay({ model, vclass, off: initOff, onClose }: Props) {
  const [off, setOff] = useState<Off>(initOff)
  const [scope, setScope] = useState<'model' | 'class'>('model')
  const [saved, setSaved] = useState(false)

  const push = useCallback((next: Off) => {
    setOff(next)
    fetchNui('trunkEdit:update', { off: next })
  }, [])

  const nudge = (kind: 'Pos' | 'Rot', axis: 'x' | 'y' | 'z', d: number) => {
    const next = structuredClone(off)
    next[kind][axis] = +(next[kind][axis] + d).toFixed(3)
    push(next)
  }
  const cam = (dyaw = 0, dpitch = 0, dzoom = 0) => fetchNui('trunkEdit:cam', { dyaw, dpitch, dzoom })
  const save = () => {
    fetchNui('trunkEdit:save', { scope })
    setSaved(true); window.setTimeout(() => setSaved(false), 1200)
  }
  const reset = () => fetchNui('trunkEdit:reset').then((r: any) => { if (r?.Pos) setOff(r) })
  const close = () => { fetchNui('trunkEdit:stop'); onClose() }

  const Axis = ({ kind, axis, step }: { kind: 'Pos' | 'Rot'; axis: 'x' | 'y' | 'z'; step: number }) => {
    const val = off[kind][axis]
    return (
      <div className="mbt-pe__axis">
        <span className="mbt-pe__axlabel">{kind === 'Pos' ? 'P' : 'R'} {axis.toUpperCase()}</span>
        <button className="mbt-pe__nudge" onClick={() => nudge(kind, axis, -step)}>−</button>
        <span className="mbt-pe__val">{val.toFixed(kind === 'Pos' ? 3 : 1)}</span>
        <button className="mbt-pe__nudge" onClick={() => nudge(kind, axis, step)}>+</button>
      </div>
    )
  }

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

      <div className="mbt-pe__grid">
        <Axis kind="Pos" axis="x" step={0.01} />
        <Axis kind="Rot" axis="x" step={1} />
        <Axis kind="Pos" axis="y" step={0.01} />
        <Axis kind="Rot" axis="y" step={1} />
        <Axis kind="Pos" axis="z" step={0.01} />
        <Axis kind="Rot" axis="z" step={1} />
      </div>

      <div className="mbt-pe__cam">
        <span>Camera</span>
        <button onClick={() => cam(-20)}>◄</button>
        <button onClick={() => cam(20)}>►</button>
        <button onClick={() => cam(0, 10)}>▲</button>
        <button onClick={() => cam(0, -10)}>▼</button>
        <button onClick={() => cam(0, 0, -0.3)}>＋</button>
        <button onClick={() => cam(0, 0, 0.3)}>－</button>
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
