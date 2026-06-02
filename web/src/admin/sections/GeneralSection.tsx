import { Icon } from '../ui/Icon'
import { Toggle } from '../ui/Toggle'
import { Segmented } from '../ui/Segmented'

/**
 * GeneralSection — core sling toggles + interface. Presentational: reads its
 * slice from `config`, writes through the path-based `update`. Runtime-safe
 * fields only; Language is shown read-only (config.lua, not live-applicable).
 */

export interface SectionProps {
  config: any
  update: (path: string, value: unknown) => void
}

const POSITIONS = [
  { value: 'bottom-center', label: 'Bottom Center' },
  { value: 'top-center', label: 'Top Center' },
  { value: 'bottom-right', label: 'Bottom Right' },
]

function SettingRow({ title, desc, checked, onChange }: { title: string; desc: string; checked: boolean; onChange: (v: boolean) => void }) {
  return (
    <div className="mbt-setting" style={{ marginBottom: 10 }}>
      <div className="mbt-setting__head">
        <div className="mbt-setting__info">
          <span className="mbt-setting__title">{title}</span>
          <span className="mbt-setting__desc">{desc}</span>
        </div>
        <Toggle checked={checked} onChange={onChange} />
      </div>
    </div>
  )
}

export function GeneralSection({ config, update }: SectionProps) {
  return (
    <>
      <div className="mbt-section">
        <div className="mbt-section__head">
          <span className="mbt-section__ic"><Icon name="power" size={16} /></span>
          <div className="mbt-section__head-tx">
            <h4 className="mbt-section__title">CORE</h4>
            <p className="mbt-section__sub">Main sling toggles.</p>
          </div>
        </div>
        <div className="mbt-section__body">
          <SettingRow title="Enable Sling" desc="Weapon shown on the player's body"
            checked={!!config.EnableSling} onChange={(v) => update('EnableSling', v)} />
          <SettingRow title="Enable Flashlight" desc="Render attached weapon flashlights"
            checked={!!config.EnableFlashlight} onChange={(v) => update('EnableFlashlight', v)} />
          <SettingRow title="Drop Weapon on Death" desc="Weapon falls to the ground on death"
            checked={!!config.DropWeaponOnDeath} onChange={(v) => update('DropWeaponOnDeath', v)} />
          <SettingRow title="Debug Mode" desc="Verbose console logging"
            checked={!!config.Debug} onChange={(v) => update('Debug', v)} />
        </div>
      </div>

      <div className="mbt-section">
        <div className="mbt-section__head">
          <span className="mbt-section__ic"><Icon name="grid" size={16} /></span>
          <div className="mbt-section__head-tx">
            <h4 className="mbt-section__title">INTERFACE</h4>
            <p className="mbt-section__sub">On-screen prompt placement.</p>
          </div>
        </div>
        <div className="mbt-section__body">
          <div className="mbt-field">
            <span className="mbt-field__label">HUD Position</span>
            <Segmented
              value={config.UIPosition ?? 'bottom-center'}
              options={POSITIONS}
              onChange={(v) => update('UIPosition', v)}
            />
          </div>
          <div className="mbt-field" style={{ marginBottom: 0 }}>
            <span className="mbt-field__label">
              Language <span style={{ textTransform: 'none', letterSpacing: 0, fontWeight: 400, color: 'var(--mbt-text-faint)', marginLeft: 4 }}>— config.lua only</span>
            </span>
            <p className="mbt-field__hint">Locale reload at runtime isn't safe — set in config. Current: {String(config.Language ?? 'en').toUpperCase()}.</p>
          </div>
        </div>
      </div>
    </>
  )
}

export default GeneralSection
