import { useState, useRef } from 'react'
import { useNuiEvent } from '../utils/useNuiEvent'
import { makeT, type Locale } from '../utils/i18n'
import './WeaponStatusUI.css'

/**
 * WeaponStatusUI — one "weapon status" pill shown while a firearm is in hand.
 * Merges the Safety SAFE/FIRE indicator (PRIMARY, safety-critical) with a compact
 * Condition readout (SECONDARY, durability tier 1-5 pips). Either segment is
 * absent when its feature is off. Colour rule: green is exclusive to FIRE;
 * condition "good" is neutral grey (default, unsignalled) → orange → red.
 * A one-shot pulse fires when the player tries to shoot on safe (attention cue).
 */

type Safety = 'safe' | 'fire'

interface StatusData {
  safety?: Safety | null
  condition?: number | null   // durability tier 1-5 (5 = pristine)
  locale?: Locale
}

const PIPS = [1, 2, 3, 4, 5]

export default function WeaponStatusUI() {
  const [visible, setVisible] = useState(false)
  const [data, setData] = useState<StatusData | null>(null)
  const [pulse, setPulse] = useState(false)
  const pulseTimer = useRef<number | null>(null)

  useNuiEvent<StatusData>('showWeaponStatus', (d) => { setData(d); setVisible(true) })
  useNuiEvent('hideWeaponStatus', () => setVisible(false))
  useNuiEvent('weaponStatusPulse', () => {
    setPulse(true)
    if (pulseTimer.current) window.clearTimeout(pulseTimer.current)
    pulseTimer.current = window.setTimeout(() => setPulse(false), 380)
  })

  if (!visible || !data) return null

  const t = makeT(data.locale)
  const safety = data.safety ?? null
  const tier = typeof data.condition === 'number' ? data.condition : null
  // Tone: 4-5 good (grey, unsignalled) · 3 worn (orange) · 1-2 bad (red).
  const tone = tier == null ? null : tier >= 4 ? 'good' : tier === 3 ? 'warn' : 'bad'

  return (
    <div className="ws-pill">
      {safety && (
        <span className={`ws-safety ws-safety--${safety}${pulse ? ' is-pulse' : ''}`}>
          {safety === 'safe' ? (
            <svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
              <path d="M12 3l7 3v6c0 4.4-3 7.6-7 9-4-1.4-7-4.6-7-9V6l7-3z" stroke="currentColor" strokeWidth="2" strokeLinejoin="round" />
            </svg>
          ) : (
            <svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
              <path d="M5 12h11l3-3M5 12l3 3" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
            </svg>
          )}
          {safety === 'safe' ? t('safety_on', 'SAFE') : t('safety_off', 'FIRE')}
        </span>
      )}

      {safety && tier != null && <span className="ws-div" />}

      {tier != null && (
        <span className={`ws-cond ws-cond--${tone}`}>
          <span className="ws-cond__k">{t('cond_label', 'COND')}</span>
          <span className="ws-cond__pips">
            {PIPS.map((i) => (
              <span key={i} className={`ws-pip${i <= tier ? ' is-on' : ''}`} />
            ))}
          </span>
        </span>
      )}
    </div>
  )
}
