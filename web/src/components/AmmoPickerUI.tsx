import { useState } from 'react'
import { useNuiEvent } from '../utils/useNuiEvent'
import { makeT, type Locale } from '../utils/i18n'
import './AmmoPickerUI.css'

interface AmmoPickerData { amount: number; max: number; locale?: Locale }

/** Key-driven ammo amount selector (no ox_lib). The Lua side owns the value and
 *  pushes updates; this just renders the current amount / max + key hints. */
export default function AmmoPickerUI() {
  const [visible, setVisible] = useState(false)
  const [exiting, setExiting] = useState(false)
  const [data,    setData]    = useState<AmmoPickerData | null>(null)
  const [amount,  setAmount]  = useState(0)

  useNuiEvent<AmmoPickerData>('showAmmoPicker', (d) => {
    setData(d); setAmount(d.amount); setExiting(false); setVisible(true)
  })
  useNuiEvent<{ amount: number }>('updateAmmoPicker', (d) => setAmount(d.amount))
  useNuiEvent('hideAmmoPicker', () => {
    setExiting(true); setTimeout(() => { setVisible(false); setExiting(false) }, 200)
  })

  if (!visible || !data) return null
  const t = makeT(data.locale)
  const pct = data.max > 0 ? Math.round((amount / data.max) * 100) : 0

  return (
    <div className={`amp-pill ${exiting ? 'amp-exit' : 'amp-enter'}`}>
      <div className="amp-head">
        <span className="amp-label">{t('ammo_share_title', 'SHARE AMMO')}</span>
        <span className="amp-val">{amount}<span className="amp-max"> / {data.max}</span></span>
      </div>
      <div className="amp-bar"><span className="amp-bar-fill" style={{ width: `${pct}%` }} /></div>
      <div className="amp-actions">
        <span className="amp-hint"><span className="mbt-kc">◄ ►</span>
          <span className="amp-lbl">{t('ammo_adjust', 'Adjust')}</span></span>
        <span className="amp-hint"><span className="mbt-kc">E</span>
          <span className="amp-lbl amp-lbl--primary">{t('ammo_give', 'Give')}</span></span>
        <span className="amp-hint"><span className="mbt-kc">BSPC</span>
          <span className="amp-lbl">{t('ammo_cancel', 'Cancel')}</span></span>
      </div>
    </div>
  )
}
