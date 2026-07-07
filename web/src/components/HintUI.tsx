import { useState, useRef, useEffect } from 'react'
import { useNuiEvent } from '../utils/useNuiEvent'
import './HintUI.css'

interface HintItem { k: string; l: string }
interface HintData { items: HintItem[]; style?: 'standard' | 'cinematic' }

/** Generic key-hint pill (placement modes, tuners…). Labels arrive already
 *  localized from Lua; this component just renders keycaps + labels. */
export default function HintUI() {
  const [visible, setVisible] = useState(false)
  const [exiting, setExiting] = useState(false)
  const [items,   setItems]   = useState<HintItem[]>([])
  const [cine,    setCine]    = useState(false)
  const hideTimer = useRef<number | null>(null)

  useNuiEvent<HintData>('showHint', (d) => {
    if (hideTimer.current) { clearTimeout(hideTimer.current); hideTimer.current = null }
    setItems(d.items ?? [])
    setCine(d.style === 'cinematic')
    setExiting(false)
    setVisible(true)
  })

  useNuiEvent('hideHint', () => {
    setExiting(true)
    if (hideTimer.current) clearTimeout(hideTimer.current)
    hideTimer.current = window.setTimeout(() => { setVisible(false); setExiting(false); hideTimer.current = null }, 200)
  })

  useEffect(() => () => { if (hideTimer.current) clearTimeout(hideTimer.current) }, [])

  if (!visible || items.length === 0) return null

  return (
    <div className={`hnt-pill${cine ? ' cine-chip' : ''} ${exiting ? 'hnt-exit' : 'hnt-enter'}`}>
      {items.map((it, i) => (
        <span className="hnt-item" key={i}>
          <span className="mbt-kc">{it.k}</span>
          <span className="hnt-lbl">{it.l}</span>
        </span>
      ))}
    </div>
  )
}
