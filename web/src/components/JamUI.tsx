import { useState } from 'react'
import { useNuiEvent } from '../utils/useNuiEvent'
import { makeT, type Locale } from '../utils/i18n'
import './JamUI.css'

interface JamData {
  weaponLabel: string
  presses: number
  total: number
  key: string
  locale?: Locale
}

export default function JamUI() {
  const [visible,  setVisible]  = useState(false)
  const [exiting,  setExiting]  = useState(false)
  const [data,     setData]     = useState<JamData | null>(null)
  const [progress, setProgress] = useState(0)

  useNuiEvent<JamData>('showJam', (incoming) => {
    setData(incoming)
    setProgress(0)
    setExiting(false)
    setVisible(true)
  })

  useNuiEvent<{ presses: number }>('updateJam', ({ presses }) => {
    setProgress(presses)
  })

  useNuiEvent('hideJam', () => {
    setExiting(true)
    setTimeout(() => { setVisible(false); setExiting(false) }, 300)
  })

  if (!visible || !data) return null

  const t = makeT(data.locale)
  const weaponName = data.weaponLabel.replace('WEAPON_', '')
  const dots = Array.from({ length: data.total }, (_, i) => i < progress)

  return (
    <div className={`jam-overlay ${exiting ? 'jam-exit' : 'jam-enter'}`}>
      <div className="jam-card">
        <div className="jam-accent-bar" />
        <div className="jam-header">
          <div className="jam-icon">
            <svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
              <path d="M12 3L3 9v6l9 6 9-6V9L12 3z" stroke="currentColor" strokeWidth="1.5" strokeLinejoin="round"/>
              <path d="M12 8v4" stroke="currentColor" strokeWidth="2" strokeLinecap="round"/>
              <circle cx="12" cy="15" r="1" fill="currentColor"/>
            </svg>
          </div>
          <div className="jam-title-block">
            <span className="jam-label">{t('jam_title', 'WEAPON JAMMED')}</span>
            <span className="jam-weapon-name">{weaponName}</span>
          </div>
        </div>
        <div className="jam-divider" />
        <div className="jam-body">
          <div className="jam-dots">
            {dots.map((filled, i) => (
              <div key={i} className={`jam-dot ${filled ? 'jam-dot--filled' : ''}`} />
            ))}
          </div>
          <div className="jam-hint">
            <span className="jam-key">{data.key}</span>
            <span className="jam-hint-label">{t('jam_clear', 'Clear Jam')}</span>
          </div>
        </div>
      </div>
    </div>
  )
}
