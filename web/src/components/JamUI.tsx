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
    <div className={`jam-pill ${exiting ? 'jam-exit' : 'jam-enter'}`}>
      <div className="jam-top">
        <span className="jam-chip"><span className="jam-chip-dot" />{t('jam_status', 'JAMMED')}</span>
        <span className="jam-wn">{weaponName}</span>
      </div>
      <div className="jam-instr">
        <span className="mbt-kc">{data.key}</span>
        <span>{t('jam_clear', 'Clear Jam')}</span>
      </div>
      <div className="jam-pips">
        {dots.map((filled, i) => (
          <span key={i} className={`jam-pip ${filled ? 'jam-pip--on' : ''}`} />
        ))}
      </div>
    </div>
  )
}
