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

type Tone = 'accent' | 'good' | 'warn' | 'bad'

interface CustodyEntry { name: string; id: string; at: number }

interface InspectData {
  name?: string
  serial?: string
  condition?: string
  conditionTone?: 'good' | 'warn' | 'bad'   // durability-derived colour (from Lua)
  ammo?: number | string   // exact count (number) or vague label (string)
  custody?: CustodyEntry[]   // chain of custody (oldest first), optional
  show?: InspectShow
  locale?: Locale
}

function Row({ label, value, tone }: { label: string; value: string; tone?: Tone }) {
  return (
    <div className="insp-row">
      <span className="insp-row-label">{label}</span>
      <span className={`insp-row-value${tone ? ` insp-row-value--${tone}` : ''}`}>{value}</span>
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

  // Ammo accent ONLY when there are rounds: a green "0" reads as "good" when the
  // gun is actually empty. Empty (exact 0) → faulty; vague labels stay neutral.
  const ammoTone: Tone | undefined =
    typeof data.ammo === 'number' ? (data.ammo > 0 ? 'accent' : 'bad') : undefined

  return (
    <div className={`insp-overlay ${exiting ? 'insp-exit' : 'insp-enter'}`}>
      <div className="insp-card">
        <div className="insp-header">
          <span className="insp-label">{t('inspect_title', 'INSPECTING')}</span>
          {show.Name && <span className="insp-weapon-name">{weaponName}</span>}
        </div>
        <div className="insp-body">
          {show.Serial && (
            <Row label={t('inspect_serial', 'Serial')} value={data.serial ?? '—'} />
          )}
          {show.Condition && (
            <Row label={t('inspect_condition', 'Condition')} value={data.condition ?? '—'} tone={data.conditionTone} />
          )}
          {show.Ammo && (
            <Row label={t('inspect_ammo', 'Ammo')} value={data.ammo != null ? String(data.ammo) : '—'} tone={ammoTone} />
          )}
        </div>
        {Array.isArray(data.custody) && data.custody.length > 0 && (
          <div className="insp-custody">
            <span className="insp-custody-title">{t('inspect_custody', 'Chain of Custody')}</span>
            <div className="insp-custody-list">
              {data.custody.map((c, i) => (
                <div className="insp-custody-entry" key={`${c.id}-${i}`}>
                  <span className="insp-custody-dot" />
                  <span className="insp-custody-name">{c.name}</span>
                  {i === 0 && <span className="insp-custody-tag">{t('custody_origin', 'origin')}</span>}
                  {i === data.custody!.length - 1 && i !== 0 && (
                    <span className="insp-custody-tag insp-custody-tag--now">{t('custody_now', 'current')}</span>
                  )}
                </div>
              ))}
            </div>
          </div>
        )}
      </div>
    </div>
  )
}
