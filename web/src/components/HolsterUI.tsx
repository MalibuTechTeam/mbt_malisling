import { useState, useRef, useEffect } from 'react'
import { useNuiEvent } from '../utils/useNuiEvent'
import { makeT, type Locale } from '../utils/i18n'
import './HolsterUI.css'

interface KeybindHint { label: string; display: string }

// Long key names break the keycap shape — abbreviate the common offenders.
// The visible action label carries the meaning, so a short cap is enough.
const KEY_ABBR: Record<string, string> = { BACKSPACE: 'BSPC', RIGHTBRACKET: ']', LEFTBRACKET: '[' }
const shortKey = (k: string) => KEY_ABBR[k.toUpperCase()] ?? k

interface HolsterData {
  weaponLabel: string
  position: 'bottom-center' | 'top-center' | 'bottom-right'
  style?: 'standard' | 'cinematic'
  confirm: KeybindHint
  cancel:  KeybindHint
  locale?: Locale
}

export default function HolsterUI() {
  const [visible, setVisible] = useState(false)
  const [exiting, setExiting] = useState(false)
  const [data,    setData]    = useState<HolsterData | null>(null)
  const hideTimer = useRef<number | null>(null)
  const anchorRef = useRef<HTMLDivElement | null>(null)

  useNuiEvent<HolsterData>('showHolster', (incoming) => {
    // Cancel a pending hide so a quick re-show isn't killed by the stale timer.
    if (hideTimer.current) { clearTimeout(hideTimer.current); hideTimer.current = null }
    setData(incoming)
    setExiting(false)
    setVisible(true)
  })

  useNuiEvent('hideHolster', () => {
    setExiting(true)
    if (hideTimer.current) clearTimeout(hideTimer.current)
    hideTimer.current = window.setTimeout(() => {
      setVisible(false); setExiting(false); hideTimer.current = null
    }, 350)
  })

  // Cinematic tracks a world point near the player (Lua projects it each frame).
  // Position it via the ref imperatively — no React re-render per frame.
  useNuiEvent<{ x?: number; y?: number; off?: boolean }>('holster:anchor', (p) => {
    const el = anchorRef.current
    if (!el) return
    if (p.off || p.x == null || p.y == null) { el.style.left = '-9999px'; return }
    el.style.left = `${(p.x * 100).toFixed(3)}%`
    el.style.top  = `${(p.y * 100).toFixed(3)}%`
  })

  useEffect(() => () => { if (hideTimer.current) clearTimeout(hideTimer.current) }, [])

  if (!visible || !data) return null

  const t = makeT(data.locale)
  const weaponName = data.weaponLabel.replace('WEAPON_', '')

  // Cinematic style (Holster.Style = 'cinematic'): a filmic lower-third reveal.
  // Same data + RMB/BSPC flow as the standard pill — purely a different look.
  if (data.style === 'cinematic') {
    return (
      <div ref={anchorRef} className={`holcine holcine-anchored ${exiting ? 'holcine-exit' : 'holcine-enter'}`} aria-hidden="true">
        <span className="holcine-tick" />
        <div className="holcine-body">
          <div className="holcine-over">{t('holster_action', 'Holster')}</div>
          <div className="holcine-name">{weaponName}</div>
          <div className="holcine-line" />
          <div className="holcine-keys">
            <span className="mbt-kc">{shortKey(data.confirm.display)}</span> {t('holster_confirm', 'Confirm')}
            <span className="holcine-sep">·</span>
            <span className="mbt-kc">{shortKey(data.cancel.display)}</span> {t('holster_cancel', 'Cancel')}
          </div>
        </div>
      </div>
    )
  }

  return (
    <div className={`holster-pill holster-pos-${data.position} ${exiting ? 'holster-exit' : 'holster-enter'}`}>
      <span className="holster-top">
        <span className="holster-ic">
          <svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
            <path d="M3 8h12l2 4H5L3 8z" fill="currentColor" opacity="0.9"/>
            <path d="M15 8l1-3h3v3" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round"/>
          </svg>
        </span>
        <span className="holster-tx">
          {t('holster_action', 'Holster')} <em>{weaponName}</em>
        </span>
      </span>
      <span className="holster-actions">
        <span className="holster-hint">
          <span className="mbt-kc">{shortKey(data.confirm.display)}</span>
          <span className="holster-lbl holster-lbl--primary">{t('holster_confirm', 'Confirm')}</span>
        </span>
        <span className="holster-hint">
          <span className="mbt-kc">{shortKey(data.cancel.display)}</span>
          <span className="holster-lbl">{t('holster_cancel', 'Cancel')}</span>
        </span>
      </span>
    </div>
  )
}
