import { useState } from 'react'
import { useNuiEvent } from '../utils/useNuiEvent'
import { makeT, type Locale } from '../utils/i18n'
import './RackPickerUI.css'

interface RackWeapon {
  name: string                      // engraved custom name, or the raw weapon code
  serial?: string
  condition?: string                // localized tier label (from Lua)
  tone?: 'good' | 'warn' | 'bad'
}

interface RackPickerData {
  weapons: RackWeapon[]
  index: number                     // 1-based selection (Lua side)
  locale?: Locale
}

export default function RackPickerUI() {
  const [visible, setVisible] = useState(false)
  const [exiting, setExiting] = useState(false)
  const [data,    setData]    = useState<RackPickerData | null>(null)
  const [index,   setIndex]   = useState(1)

  useNuiEvent<RackPickerData>('showRackPicker', (incoming) => {
    setData(incoming)
    setIndex(incoming.index ?? 1)
    setExiting(false)
    setVisible(true)
  })

  useNuiEvent<{ index: number }>('updateRackPicker', (d) => setIndex(d.index))

  useNuiEvent('hideRackPicker', () => {
    setExiting(true)
    setTimeout(() => { setVisible(false); setExiting(false) }, 250)
  })

  if (!visible || !data) return null

  const t = makeT(data.locale)

  return (
    <div className={`rkp-overlay ${exiting ? 'rkp-exit' : 'rkp-enter'}`}>
      <div className="rkp-card">
        <div className="rkp-header">
          <span className="rkp-label">{t('rack_picker_title', 'WEAPON RACK')}</span>
          <span className="rkp-count">{index}/{data.weapons.length}</span>
        </div>

        <div className="rkp-list">
          {data.weapons.map((w, i) => (
            <div className={`rkp-entry${i + 1 === index ? ' rkp-entry--sel' : ''}`} key={i}>
              <span className="rkp-marker" />
              <span className="rkp-info">
                <span className="rkp-name">{w.name.replace('WEAPON_', '')}</span>
                {w.serial && <span className="rkp-serial">{w.serial}</span>}
              </span>
              {w.condition && (
                <span className={`rkp-cond${w.tone ? ` rkp-cond--${w.tone}` : ''}`}>{w.condition}</span>
              )}
            </div>
          ))}
        </div>

        <div className="rkp-footer">
          <span className="rkp-hint">
            <span className="mbt-kc">↑↓</span>
            <span className="rkp-hint-lbl">{t('rack_picker_select', 'Select')}</span>
          </span>
          <span className="rkp-hint">
            <span className="mbt-kc">E</span>
            <span className="rkp-hint-lbl rkp-hint-lbl--primary">{t('rack_picker_take', 'Take')}</span>
          </span>
          <span className="rkp-hint">
            <span className="mbt-kc">BSPC</span>
            <span className="rkp-hint-lbl">{t('rack_picker_cancel', 'Cancel')}</span>
          </span>
        </div>
      </div>
    </div>
  )
}
