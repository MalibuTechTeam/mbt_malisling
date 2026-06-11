import { useState } from 'react'
import { useNuiEvent } from '../utils/useNuiEvent'
import './HintUI.css'

interface HintItem { k: string; l: string }
interface HintData { items: HintItem[] }

/** Generic key-hint pill (placement modes, tuners…). Labels arrive already
 *  localized from Lua; this component just renders keycaps + labels. */
export default function HintUI() {
  const [visible, setVisible] = useState(false)
  const [exiting, setExiting] = useState(false)
  const [items,   setItems]   = useState<HintItem[]>([])

  useNuiEvent<HintData>('showHint', (d) => {
    setItems(d.items ?? [])
    setExiting(false)
    setVisible(true)
  })

  useNuiEvent('hideHint', () => {
    setExiting(true)
    setTimeout(() => { setVisible(false); setExiting(false) }, 200)
  })

  if (!visible || items.length === 0) return null

  return (
    <div className={`hnt-pill ${exiting ? 'hnt-exit' : 'hnt-enter'}`}>
      {items.map((it, i) => (
        <span className="hnt-item" key={i}>
          <span className="mbt-kc">{it.k}</span>
          <span className="hnt-lbl">{it.l}</span>
        </span>
      ))}
    </div>
  )
}
