import { useState } from 'react'
import { useNuiEvent } from '../utils/useNuiEvent'
import { makeT, type Locale } from '../utils/i18n'
import './PatdownUI.css'

interface Finding {
  label: string
  serial?: string
  status: 'visible' | 'concealed' | 'carried'
  quality?: 'good' | 'poor'
}

interface PromptData { officer?: string; locale?: Locale }
interface ResultData { findings: Finding[]; locale?: Locale }

function statusText(t: (k: string, f: string) => string, f: Finding): string {
  if (f.status === 'concealed') {
    return f.quality === 'poor'
      ? t('patdown_st_concealed_poor', 'Concealed (poorly)')
      : t('patdown_st_concealed_good', 'Concealed')
  }
  if (f.status === 'carried') return t('patdown_st_carried', 'On the back')
  return t('patdown_st_visible', 'In the open')
}

export default function PatdownUI() {
  // Consent prompt (target)
  const [prompt, setPrompt]   = useState<PromptData | null>(null)
  const [pExit,  setPExit]    = useState(false)
  // Result card (officer)
  const [result, setResult]   = useState<ResultData | null>(null)
  const [rExit,  setRExit]    = useState(false)

  useNuiEvent<PromptData>('showPatdownPrompt', (d) => { setPrompt(d); setPExit(false) })
  useNuiEvent('hidePatdownPrompt', () => {
    setPExit(true); setTimeout(() => { setPrompt(null); setPExit(false) }, 220)
  })
  useNuiEvent<ResultData>('showPatdownResult', (d) => {
    setResult(d); setRExit(false)
    setTimeout(() => { setRExit(true); setTimeout(() => { setResult(null); setRExit(false) }, 300) }, 6500)
  })

  return (
    <>
      {prompt && (() => {
        const t = makeT(prompt.locale)
        return (
          <div className={`ptd-pill ${pExit ? 'ptd-exit' : 'ptd-enter'}`}>
            <span className="ptd-top">
              <span className="ptd-ic">
                <svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                  <path d="M7 11V7a2 2 0 0 1 4 0M11 11V6a2 2 0 0 1 4 0v5M15 11V8a2 2 0 0 1 4 0v6a6 6 0 0 1-6 6h-2.5a4 4 0 0 1-3.2-1.6L4 14"
                    stroke="currentColor" strokeWidth="1.4" strokeLinecap="round" strokeLinejoin="round"/>
                </svg>
              </span>
              <span className="ptd-tx">
                <span className="ptd-from">{prompt.officer ?? '—'}</span>{' '}
                {t('patdown_wants', 'wants to search you')}
              </span>
            </span>
            <span className="ptd-actions">
              <span className="ptd-hint"><span className="mbt-kc">E</span>
                <span className="ptd-lbl ptd-lbl--primary">{t('patdown_allow', 'Allow')}</span></span>
              <span className="ptd-hint"><span className="mbt-kc">BSPC</span>
                <span className="ptd-lbl">{t('patdown_refuse', 'Refuse')}</span></span>
            </span>
          </div>
        )
      })()}

      {result && (() => {
        const t = makeT(result.locale)
        return (
          <div className={`ptd-card-wrap ${rExit ? 'ptd-exit' : 'ptd-enter'}`}>
            <div className="ptd-card">
              <div className="ptd-header">
                <span className="ptd-label">{t('patdown_result', 'PAT-DOWN')}</span>
                <span className="ptd-count">{result.findings.length}</span>
              </div>
              <div className="ptd-list">
                {result.findings.map((f, i) => (
                  <div className="ptd-row" key={i}>
                    <span className="ptd-info">
                      <span className="ptd-name">{f.label.replace('WEAPON_', '')}</span>
                      {f.serial && <span className="ptd-serial">{f.serial}</span>}
                    </span>
                    <span className={`ptd-status ptd-status--${f.status}${f.quality ? ` ptd-status--${f.quality}` : ''}`}>
                      {statusText(t, f)}
                    </span>
                  </div>
                ))}
              </div>
            </div>
          </div>
        )
      })()}
    </>
  )
}
