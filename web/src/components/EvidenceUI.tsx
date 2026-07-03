import { useState, useRef, useEffect } from 'react'
import { useNuiEvent } from '../utils/useNuiEvent'
import { makeT, type Locale } from '../utils/i18n'
import './EvidenceUI.css'

interface EvidenceData {
  weapon?: string        // WEAPON_ name
  serial?: string | null // masked server-side; null/undefined = withheld
  agoMin?: number
  locale?: Locale
}

export default function EvidenceUI() {
  const [visible, setVisible] = useState(false)
  const [exiting, setExiting] = useState(false)
  const [data,    setData]    = useState<EvidenceData | null>(null)
  const hideTimer = useRef<number | null>(null)

  useNuiEvent<EvidenceData>('showEvidence', (incoming) => {
    if (hideTimer.current) { clearTimeout(hideTimer.current); hideTimer.current = null }
    setData(incoming)
    setExiting(false)
    setVisible(true)
  })

  useNuiEvent('hideEvidence', () => {
    setExiting(true)
    if (hideTimer.current) clearTimeout(hideTimer.current)
    hideTimer.current = window.setTimeout(() => { setVisible(false); setExiting(false); hideTimer.current = null }, 250)
  })

  useEffect(() => () => { if (hideTimer.current) clearTimeout(hideTimer.current) }, [])

  if (!visible || !data) return null

  const t = makeT(data.locale)
  const weaponName = (data.weapon || 'WEAPON').replace('WEAPON_', '')
  const ago = (data.agoMin ?? 0) < 1
    ? t('casing_ago_now', 'moments ago')
    : t('casing_ago', '%d min ago').replace('%d', String(data.agoMin))

  return (
    <div className={`evd-overlay ${exiting ? 'evd-exit' : 'evd-enter'}`}>
      <div className="evd-card">
        <div className="evd-header">
          <span className="evd-label">{t('casing_title', 'SHELL CASING')}</span>
          <span className="evd-weapon">{weaponName}</span>
        </div>
        <div className="evd-body">
          <div className="evd-row">
            <span className="evd-row-label">{t('casing_serial', 'Serial')}</span>
            <span className="evd-row-value">{data.serial ?? '—'}</span>
          </div>
          <div className="evd-row">
            <span className="evd-row-label">{t('casing_fired', 'Fired')}</span>
            <span className="evd-row-value evd-row-value--dim">{ago}</span>
          </div>
        </div>
      </div>
    </div>
  )
}
