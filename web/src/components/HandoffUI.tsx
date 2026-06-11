import { useState } from 'react'
import { useNuiEvent } from '../utils/useNuiEvent'
import { makeT, type Locale } from '../utils/i18n'
import './HandoffUI.css'

interface HandoffData {
  fromName?: string
  weapon?: string        // WEAPON_ name
  label?: string         // engraved custom name, if any
  serial?: string
  locale?: Locale
}

export default function HandoffUI() {
  const [visible, setVisible] = useState(false)
  const [exiting, setExiting] = useState(false)
  const [data,    setData]    = useState<HandoffData | null>(null)

  useNuiEvent<HandoffData>('showHandoff', (incoming) => {
    setData(incoming)
    setExiting(false)
    setVisible(true)
  })

  useNuiEvent('hideHandoff', () => {
    setExiting(true)
    setTimeout(() => { setVisible(false); setExiting(false) }, 250)
  })

  if (!visible || !data) return null

  const t = makeT(data.locale)
  const weaponName = data.label || (data.weapon || 'WEAPON').replace('WEAPON_', '')

  return (
    <div className={`hof-pill ${exiting ? 'hof-exit' : 'hof-enter'}`}>
      <span className="hof-top">
        <span className="hof-ic">
          <svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
            <path d="M3 8h12l2 4H5L3 8z" fill="currentColor" opacity="0.9"/>
            <path d="M15 8l1-3h3v3" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round"/>
          </svg>
        </span>
        <span className="hof-tx">
          <span className="hof-from">{data.fromName ?? '—'}</span>
          {' '}{t('handoff_offers', 'offers you')}{' '}
          <em>{weaponName}</em>
          {data.serial && <span className="hof-serial">{data.serial}</span>}
        </span>
      </span>
      <span className="hof-actions">
        <span className="hof-hint">
          <span className="mbt-kc">E</span>
          <span className="hof-lbl hof-lbl--primary">{t('handoff_accept', 'Accept')}</span>
        </span>
        <span className="hof-hint">
          <span className="mbt-kc">BSPC</span>
          <span className="hof-lbl">{t('handoff_decline', 'Decline')}</span>
        </span>
      </span>
    </div>
  )
}
