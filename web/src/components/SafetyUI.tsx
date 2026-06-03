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
      {isSafe ? (
        <svg className="safety-ic" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
          <path d="M12 3l7 3v6c0 4.4-3 7.6-7 9-4-1.4-7-4.6-7-9V6l7-3z" stroke="currentColor" strokeWidth="2" strokeLinejoin="round" />
        </svg>
      ) : (
        <svg className="safety-ic" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
          <path d="M5 12h11l3-3M5 12l3 3" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
        </svg>
      )}
      <span className="safety-label">{label}</span>
    </div>
  )
}
