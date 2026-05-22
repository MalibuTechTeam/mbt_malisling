import { useState } from 'react'
import { useNuiEvent } from '../utils/useNuiEvent'
import { makeT, type Locale } from '../utils/i18n'
import './HolsterUI.css'

interface KeybindHint { label: string; display: string }

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
    <div className={`holster-overlay holster-pos-${data.position} ${exiting ? 'holster-exit' : 'holster-enter'}`}>
      <div className="holster-card">
        <div className="holster-accent-bar" />
        <div className="holster-header">
          <div className="holster-icon">
            <svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
              <path d="M3 8h12l2 4H5L3 8z" fill="currentColor" opacity="0.9"/>
              <path d="M15 8l1-3h3v3" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round"/>
              <path d="M7 12v3l1 1h2l1-1v-3" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/>
            </svg>
          </div>
          <div className="holster-title-block">
            <span className="holster-label">{t('holster_title', 'HOLSTER WEAPON')}</span>
            <span className="holster-weapon-name">{weaponName}</span>
          </div>
        </div>
        <div className="holster-divider" />
        <div className="holster-hints">
          <div className="holster-hint">
            <span className="holster-key holster-key--confirm">{data.confirm.display}</span>
            <span className="holster-hint-label">{data.confirm.label}</span>
          </div>
          <div className="holster-hint-separator" />
          <div className="holster-hint">
            <span className="holster-key holster-key--cancel">{data.cancel.display}</span>
            <span className="holster-hint-label">{data.cancel.label}</span>
          </div>
        </div>
      </div>
    </div>
  )
}
