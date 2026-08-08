import { useState } from 'react'
import { useNuiEvent } from '../utils/useNuiEvent'
import './ChargeMeter.css'

/**
 * ChargeMeter — the charge-power throw meter. A thin radial arc hugging the screen
 * centre (reticle) that sweeps as the player holds the throw key. Passive: driven by
 * the weapon_throw module's charge:start / charge:update {pct} / charge:end messages.
 * Hidden whenever not charging; pointer-events none so it never blocks input.
 */

const R = 42
const CIRC = 2 * Math.PI * R

export default function ChargeMeter() {
  const [visible, setVisible] = useState(false)
  const [pct, setPct] = useState(0)

  useNuiEvent('charge:start', () => { setPct(0); setVisible(true) })
  useNuiEvent<{ pct: number }>('charge:update', (d) =>
    setPct(Math.max(0, Math.min(1, Number(d?.pct) || 0))))
  useNuiEvent('charge:end', () => setVisible(false))

  if (!visible) return null
  const full = pct >= 0.985

  return (
    <div className="mbt-charge" aria-hidden="true">
      <div className={`mbt-charge__ring${full ? ' is-full' : ''}`}>
        <svg viewBox="0 0 100 100">
          <circle className="mbt-charge__track" cx="50" cy="50" r={R} />
          <circle className="mbt-charge__fill" cx="50" cy="50" r={R}
            style={{ strokeDasharray: CIRC, strokeDashoffset: CIRC * (1 - pct) }} />
        </svg>
        <span className="mbt-charge__dot" />
      </div>
      <span className="mbt-charge__label">POWER</span>
    </div>
  )
}
