import { useState } from 'react'
import { useNuiEvent } from '../utils/useNuiEvent'
import { makeT, type Locale } from '../utils/i18n'
import './PoseHUD.css'

/**
 * PoseHUD — "showcase pose" mode panel. Shows the active pose name + position in
 * the list + controls (← → cycle, ⌫ exit). Bottom-centre. Driven by the
 * showcase_poses module: showPose / hidePose.
 */

interface PoseData {
  name: string
  index: number   // 1-based
  total: number
  locale?: Locale
  style?: 'standard' | 'cinematic'
}

export default function PoseHUD() {
  const [visible, setVisible] = useState(false)
  const [data, setData] = useState<PoseData | null>(null)

  useNuiEvent<PoseData>('showPose', (d) => { setData(d); setVisible(true) })
  useNuiEvent('hidePose', () => setVisible(false))

  if (!visible || !data) return null

  const t = makeT(data.locale)
  const dots = Array.from({ length: data.total }, (_, i) => i + 1)

  return (
    <div className={`pose-hud${data.style === 'cinematic' ? ' cine-chip' : ''}`}>
      <div className="pose-hud__top">
        <span className="pose-hud__ic">
          <svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
            <rect x="3" y="6" width="18" height="13" rx="2" stroke="currentColor" strokeWidth="2" />
            <circle cx="12" cy="12.5" r="3" stroke="currentColor" strokeWidth="2" />
            <path d="M8 6l1.5-2h5L16 6" stroke="currentColor" strokeWidth="2" strokeLinejoin="round" />
          </svg>
        </span>
        <span className="pose-hud__eyebrow">{t('pose_title', 'SHOWCASE')}</span>
        <span className="pose-hud__dots">
          {dots.map((i) => (
            <span key={i} className={`pose-hud__dot${i === data.index ? ' is-on' : ''}`} />
          ))}
        </span>
      </div>

      <div className="pose-hud__name">
        <b>{data.name}</b>
        <span className="pose-hud__idx"><em>{data.index}</em> / {data.total}</span>
      </div>

      <div className="pose-hud__bar" />

      <div className="pose-hud__ctrl">
        <span className="pose-hud__hint">
          <span className="mbt-kc">&larr;</span>
          <span className="mbt-kc">&rarr;</span>
          <span className="pose-hud__lbl">{t('pose_cycle', 'Cycle')}</span>
        </span>
        <span className="pose-hud__sp" />
        <span className="pose-hud__hint">
          <span className="mbt-kc">&#9003;</span>
          <span className="pose-hud__lbl">{t('pose_exit', 'Exit')}</span>
        </span>
      </div>
    </div>
  )
}
