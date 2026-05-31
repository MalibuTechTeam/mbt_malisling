import { useState } from 'react'
import { useNuiEvent } from '../utils/useNuiEvent'
import { makeT, type Locale } from '../utils/i18n'
import './SafetyUI.css'

interface SafetyData {
  state: 'safe' | 'fire'
  locale?: Locale
}

export default function SafetyUI() {
  const [visible, setVisible] = useState(false)
  const [data, setData] = useState<SafetyData | null>(null)

  useNuiEvent<SafetyData>('showSafety', (incoming) => {
    setData(incoming)
    setVisible(true)
  })

  useNuiEvent('hideSafety', () => setVisible(false))

  if (!visible || !data) return null

  const t = makeT(data.locale)
  const isSafe = data.state === 'safe'
  const label = isSafe ? t('safety_on', 'SAFE') : t('safety_off', 'FIRE')

  return (
    <div className={`safety-pill ${isSafe ? 'safety-safe' : 'safety-fire'}`}>
      <div className="safety-dot" />
      <span className="safety-label">{label}</span>
    </div>
  )
}
