import { useState } from 'react'
import { useNuiEvent } from '../utils/useNuiEvent'
import { makeT, type Locale } from '../utils/i18n'
import './HolsterUI.css'

interface KeybindHint { label: string; display: string }

// Long key names break the keycap shape — abbreviate the common offenders.
// The visible action label carries the meaning, so a short cap is enough.
const KEY_ABBR: Record<string, string> = { BACKSPACE: 'BSPC', RIGHTBRACKET: ']', LEFTBRACKET: '[' }
const shortKey = (k: string) => KEY_ABBR[k.toUpperCase()] ?? k

interface HolsterData {
  weaponLabel: string
  position: 'bottom-center' | 'top-center' | 'bottom-right'
  confirm: KeybindHint
  cancel:  KeybindHint
  locale?: Locale
}

export default function HolsterUI() {
  const [visible, setVisible] = useState(false)
  const [exiting, setExiting] = useState(false)
  const [data,    setData]    = useState<HolsterData | null>(null)

  useNuiEvent<HolsterData>('showHolster', (incoming) => {
    setData(incoming)
    setExiting(false)
    setVisible(true)
  })

  useNuiEvent('hideHolster', () => {
    setExiting(true)
    setTimeout(() => { setVisible(false); setExiting(false) }, 350)
  })

  if (!visible || !data) return null

  const t = makeT(data.locale)
  const weaponName = data.weaponLabel.replace('WEAPON_', '')

  return (
    <div className={`holster-pill holster-pos-${data.position} ${exiting ? 'holster-exit' : 'holster-enter'}`}>
      <span className="holster-top">
        <span className="holster-ic">
          <svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
            <path d="M3 8h12l2 4H5L3 8z" fill="currentColor" opacity="0.9"/>
            <path d="M15 8l1-3h3v3" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round"/>
          </svg>
        </span>
        <span className="holster-tx">
          {t('holster_action', 'Holster')} <em>{weaponName}</em>
        </span>
      </span>
      <span className="holster-actions">
        <span className="holster-hint">
          <span className="mbt-kc">{shortKey(data.confirm.display)}</span>
          <span className="holster-lbl holster-lbl--primary">{t('holster_confirm', 'Confirm')}</span>
        </span>
        <span className="holster-hint">
          <span className="mbt-kc">{shortKey(data.cancel.display)}</span>
          <span className="holster-lbl">{t('holster_cancel', 'Cancel')}</span>
        </span>
      </span>
    </div>
  )
}
