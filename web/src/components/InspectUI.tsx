import { useState } from 'react'
import { useNuiEvent } from '../utils/useNuiEvent'
import { makeT, type Locale } from '../utils/i18n'
import './InspectUI.css'

interface InspectShow {
  Serial?: boolean
  Condition?: boolean
  Name?: boolean
  Ammo?: boolean
}

interface InspectData {
  name?: string
  serial?: string
  condition?: string
  ammo?: number | string   // exact count (number) or vague label (string)
  show?: InspectShow
  locale?: Locale
}

function Row({ label, value }: { label: string; value: string }) {
  return (
    <div className="insp-row">
      <span className="insp-row-label">{label}</span>
      <span className="insp-row-value">{value}</span>
    </div>
  )
}

export default function InspectUI() {
  const [visible, setVisible] = useState(false)
  const [exiting, setExiting] = useState(false)
  const [data, setData] = useState<InspectData | null>(null)

  useNuiEvent<InspectData>('showInspect', (incoming) => {
    setData(incoming)
    setExiting(false)
    setVisible(true)
  })

  useNuiEvent('hideInspect', () => {
    setExiting(true)
    setTimeout(() => { setVisible(false); setExiting(false) }, 300)
  })

  if (!visible || !data) return null

  const t = makeT(data.locale)
  const show = data.show ?? { Serial: true, Condition: true, Name: true, Ammo: true }
  const weaponName = (data.name || 'WEAPON').replace('WEAPON_', '')

  return (
    <div className={`insp-overlay ${exiting ? 'insp-exit' : 'insp-enter'}`}>
      <div className="insp-card">
        <div className="insp-accent-bar" />
        <div className="insp-header">
          <div className="insp-icon">
            <svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
              <circle cx="11" cy="11" r="7" stroke="currentColor" strokeWidth="1.5" />
              <path d="M16 16l4.5 4.5" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" />
            </svg>
          </div>
          <div className="insp-title-block">
            <span className="insp-label">{t('inspect_title', 'INSPECTING')}</span>
            {show.Name && <span className="insp-weapon-name">{weaponName}</span>}
          </div>
        </div>
        <div className="insp-divider" />
        <div className="insp-body">
          {show.Serial && (
            <Row label={t('inspect_serial', 'Serial')} value={data.serial ?? '—'} />
          )}
          {show.Condition && (
            <Row label={t('inspect_condition', 'Condition')} value={data.condition ?? '—'} />
          )}
          {show.Ammo && (
            <Row label={t('inspect_ammo', 'Ammo')} value={data.ammo != null ? String(data.ammo) : '—'} />
          )}
        </div>
      </div>
    </div>
  )
}
