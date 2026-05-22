import { useEffect, useState } from 'react'
import { useNuiEvent } from '../utils/useNuiEvent'
import { fetchNui } from '../utils/fetchNui'
import { makeT, type Locale } from '../utils/i18n'
import './ConfigUI.css'

interface ConfigData {
  debug: boolean
  dropWeaponOnDeath: boolean
  enableSling: boolean
  enableFlashlight: boolean
  uiPosition: string
  jamming: { enabled: boolean; cooldown: number; unjamPresses: number }
  throw: { enabled: boolean; key: string }
  locale?: Locale
}

export default function ConfigUI() {
  const [visible, setVisible] = useState(false)
  const [config, setConfig]   = useState<ConfigData | null>(null)

  useNuiEvent<ConfigData>('openConfig', (data) => {
    setConfig(data)
    setVisible(true)
  })

  useNuiEvent('closeConfig', () => setVisible(false))

  useEffect(() => {
    if (!visible) return
    const onKey = (e: KeyboardEvent) => { if (e.key === 'Escape') handleClose() }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [visible])

  const handleSave = () => {
    fetchNui('configSave', config)
    setVisible(false)
  }

  const handleClose = () => {
    fetchNui('configClose', {})
    setVisible(false)
  }

  const set = (path: string[], value: unknown) => {
    setConfig(prev => {
      if (!prev) return prev
      const next = structuredClone(prev) as unknown as Record<string, unknown>
      let obj = next
      for (let i = 0; i < path.length - 1; i++) obj = obj[path[i]] as Record<string, unknown>
      obj[path[path.length - 1]] = value
      return next as unknown as ConfigData
    })
  }

  if (!visible || !config) return null

  const t = makeT(config.locale)

  return (
    <div className="cfg-overlay" onClick={e => e.target === e.currentTarget && handleClose()}>
      <div className="cfg-panel">
        <div className="cfg-accent-bar" />
        <div className="cfg-title-row">
          <span className="cfg-title">{t('cfg_title', 'MBT Configuration')}</span>
          <button className="cfg-close-btn" onClick={handleClose}>✕</button>
        </div>

        <div className="cfg-body">
          <Section title={t('cfg_general', 'General')}>
            <Toggle label={t('cfg_debug', 'Debug Mode')}                   value={config.debug}             onChange={v => set(['debug'], v)} />
            <Toggle label={t('cfg_drop_death', 'Drop Weapon on Death')}     value={config.dropWeaponOnDeath} onChange={v => set(['dropWeaponOnDeath'], v)} />
            <Toggle label={t('cfg_enable_sling', 'Enable Sling')}           value={config.enableSling}       onChange={v => set(['enableSling'], v)} />
            <Toggle label={t('cfg_enable_flashlight', 'Enable Flashlight')} value={config.enableFlashlight}  onChange={v => set(['enableFlashlight'], v)} />
          </Section>

          <Section title={t('cfg_interface', 'Interface')}>
            <SelectRow
              label={t('cfg_holster_position', 'Holster UI Position')}
              value={config.uiPosition}
              options={['bottom-center', 'top-center', 'bottom-right']}
              onChange={v => set(['uiPosition'], v)}
            />
          </Section>

          <Section title={t('cfg_jamming', 'Weapon Jamming')}>
            <Toggle    label={t('cfg_enabled', 'Enabled')}                 value={config.jamming.enabled}      onChange={v => set(['jamming', 'enabled'], v)} />
            <NumberRow label={t('cfg_cooldown', 'Cooldown (seconds)')}     value={config.jamming.cooldown}     min={1} max={60} onChange={v => set(['jamming', 'cooldown'], v)} />
            <NumberRow label={t('cfg_unjam_presses', 'Unjam Key Presses')} value={config.jamming.unjamPresses} min={1} max={20} onChange={v => set(['jamming', 'unjamPresses'], v)} />
          </Section>

          <Section title={t('cfg_throw', 'Weapon Throw')}>
            <Toggle  label={t('cfg_enabled', 'Enabled')}     value={config.throw.enabled} onChange={v => set(['throw', 'enabled'], v)} />
            <TextRow label={t('cfg_throw_key', 'Throw Key')} value={config.throw.key}     onChange={v => set(['throw', 'key'], v)} />
          </Section>
        </div>

        <div className="cfg-footer">
          <button className="cfg-btn cfg-btn--cancel" onClick={handleClose}>{t('cfg_cancel', 'Cancel')}</button>
          <button className="cfg-btn cfg-btn--save"   onClick={handleSave}>{t('cfg_save', 'Save & Apply')}</button>
        </div>
      </div>
    </div>
  )
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <div className="cfg-section">
      <span className="cfg-section-title">{title}</span>
      {children}
    </div>
  )
}

function Toggle({ label, value, onChange }: { label: string; value: boolean; onChange: (v: boolean) => void }) {
  return (
    <div className="cfg-row">
      <span className="cfg-row-label">{label}</span>
      <button className={`cfg-toggle ${value ? 'cfg-toggle--on' : ''}`} onClick={() => onChange(!value)}>
        <span className="cfg-toggle-thumb" />
      </button>
    </div>
  )
}

function NumberRow({ label, value, min, max, onChange }: { label: string; value: number; min: number; max: number; onChange: (v: number) => void }) {
  return (
    <div className="cfg-row">
      <span className="cfg-row-label">{label}</span>
      <input
        className="cfg-input"
        type="number"
        value={value}
        min={min}
        max={max}
        onChange={e => onChange(Math.min(max, Math.max(min, Number(e.target.value))))}
      />
    </div>
  )
}

function SelectRow({ label, value, options, onChange }: { label: string; value: string; options: string[]; onChange: (v: string) => void }) {
  return (
    <div className="cfg-row">
      <span className="cfg-row-label">{label}</span>
      <select className="cfg-select" value={value} onChange={e => onChange(e.target.value)}>
        {options.map(o => <option key={o} value={o}>{o}</option>)}
      </select>
    </div>
  )
}

function TextRow({ label, value, onChange }: { label: string; value: string; onChange: (v: string) => void }) {
  return (
    <div className="cfg-row">
      <span className="cfg-row-label">{label}</span>
      <input
        className="cfg-input cfg-input--text"
        type="text"
        value={value}
        maxLength={4}
        onChange={e => onChange(e.target.value.toUpperCase())}
      />
    </div>
  )
}
