import { useState } from 'react'
import { useNuiEvent } from '../utils/useNuiEvent'
import './NoDrawUI.css'

interface NoDrawData {
  title: string
  subtitle: string
}

export default function NoDrawUI() {
  const [visible, setVisible] = useState(false)
  const [exiting, setExiting] = useState(false)
  const [data, setData] = useState<NoDrawData | null>(null)

  useNuiEvent<NoDrawData>('showNoDraw', (incoming) => {
    setData(incoming)
    setExiting(false)
    setVisible(true)
  })

  useNuiEvent('hideNoDraw', () => {
    setExiting(true)
    setTimeout(() => { setVisible(false); setExiting(false) }, 250)
  })

  if (!visible || !data) return null

  return (
    <div className={`nodraw-pill ${exiting ? 'nodraw-exit' : 'nodraw-enter'}`}>
      <div className="nodraw-icon">
        <svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
          <circle cx="12" cy="12" r="9" stroke="currentColor" strokeWidth="1.8" />
          <path d="M5.6 5.6l12.8 12.8" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" />
        </svg>
      </div>
      <div className="nodraw-content">
        <div className="nodraw-title">{data.title}</div>
        <div className="nodraw-subtitle">{data.subtitle}</div>
      </div>
    </div>
  )
}
