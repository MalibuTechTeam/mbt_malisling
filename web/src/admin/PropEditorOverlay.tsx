import { useEffect, useState, useCallback } from 'react'
import { fetchNui } from '../utils/fetchNui'
import { Icon } from './ui/Icon'
import { Select } from './ui/Select'

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

export function PropEditorOverlay({ wtype, job, gender: initGender, onClose }: Props) {
  const [data, setData] = useState<Data | null>(null)
  const [gender, setGender] = useState<'male' | 'female'>(initGender === 'female' ? 'female' : 'male')
  const [saved, setSaved] = useState(false)

  // Enter edit mode once; leave on unmount.
  useEffect(() => {
    let alive = true
    fetchNui('propEdit:start', { wtype, job, gender }).then((r: any) => {
      if (alive && r?.ok && r.data) setData(r.data)
    })
    return () => { alive = false; fetchNui('propEdit:stop') }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [wtype, job])

  const push = useCallback((next: Data, g: 'male' | 'female') => {
    setData(next)
    fetchNui('propEdit:update', { data: next, gender: g })
  }, [])

  if (!data) return null
  const g = gender
  const pos = data.Pos[g]
  const rot = data.Rot[g]

  const setAxis = (kind: 'Pos' | 'Rot', axis: 'x' | 'y' | 'z', v: number) => {
    const next = structuredClone(data)
    ;(next[kind][g] as any)[axis] = v
    push(next, g)
  }
  const nudge = (kind: 'Pos' | 'Rot', axis: 'x' | 'y' | 'z', d: number) => {
    const cur = (kind === 'Pos' ? pos : rot)[axis]
    setAxis(kind, axis, +(cur + d).toFixed(3))
  }
  const cam = (dyaw = 0, dpitch = 0, dzoom = 0) => fetchNui('propEdit:cam', { dyaw, dpitch, dzoom })
  const setBone = (b: number) => push({ ...structuredClone(data), Bone: b }, g)
  const copyGender = () => {
    const other = g === 'male' ? 'female' : 'male'
    const next = structuredClone(data)
    next.Pos[other] = { ...next.Pos[g] }
    next.Rot[other] = { ...next.Rot[g] }
    setData(next)
  }
  const save = () => {
    fetchNui('propEdit:save', { scope: job, wtype, data })
    setSaved(true); window.setTimeout(() => setSaved(false), 1200)
  }
  const reset = () => fetchNui('propEdit:reset', { scope: job, wtype })
  const close = () => { fetchNui('propEdit:stop'); onClose() }

  const Axis = ({ kind, axis, step }: { kind: 'Pos' | 'Rot'; axis: 'x' | 'y' | 'z'; step: number }) => {
    const val = (kind === 'Pos' ? pos : rot)[axis]
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
        <Icon name="configure" size={14} />
        <b>{wtype.toUpperCase()}</b>
        <span className="mbt-pe__scope">{job === 'default' ? 'Default' : job}</span>
      </div>

      <div className="mbt-pe__seg">
        <button className={g === 'male' ? 'is-on' : ''} onClick={() => setGender('male')}>Male</button>
        <button className={g === 'female' ? 'is-on' : ''} onClick={() => setGender('female')}>Female</button>
        <button className="mbt-pe__copy" onClick={copyGender}>Copy →</button>
      </div>

      <div className="mbt-pe__grid">
        <Axis kind="Pos" axis="x" step={0.01} />
        <Axis kind="Rot" axis="x" step={1} />
        <Axis kind="Pos" axis="y" step={0.01} />
        <Axis kind="Rot" axis="y" step={1} />
        <Axis kind="Pos" axis="z" step={0.01} />
        <Axis kind="Rot" axis="z" step={1} />
      </div>

      <div className="mbt-pe__bone">
        <span>Bone</span>
        <Select value={String(data.Bone)} aria-label="Bone" onChange={(v) => setBone(Number(v))}
          options={BONES.map((b) => ({ value: String(b.id), label: b.label }))} />
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
          <Icon name="save" size={13} /> {saved ? 'Saved' : 'Save'}
        </button>
      </div>
    </div>
  )
}
