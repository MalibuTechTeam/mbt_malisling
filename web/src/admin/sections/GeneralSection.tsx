import { Segmented } from '../ui/Segmented'
import { Section, ToggleRow, type SectionProps } from './parts'

/**
 * GeneralSection — core sling toggles + interface. Runtime-safe fields only.
 * Debug stays in config.lua (dev flag). Language is read-only (locale reload at
 * runtime isn't safe). HUD position: 3 presets + Custom (drag implemented with
 * the overlay reskin — Custom is a placeholder default for now).
 */

const POSITIONS = [
  { value: 'bottom-center', label: 'Bottom Center' },
  { value: 'top-center', label: 'Top Center' },
  { value: 'bottom-right', label: 'Bottom Right' },
  { value: 'custom', label: 'Custom' },
]

export function GeneralSection({ config, update }: SectionProps) {
  const pos = config.UIPosition ?? 'bottom-center'
  return (
    <>
      <Section icon="power" title="CORE" sub="Main sling toggles.">
        <ToggleRow title="Enable Sling" desc="Weapon shown on the player's body"
          checked={!!config.EnableSling} onChange={(v) => update('EnableSling', v)} />
        <ToggleRow title="Enable Flashlight" desc="Render attached weapon flashlights"
          checked={!!config.EnableFlashlight} onChange={(v) => update('EnableFlashlight', v)} />
        <ToggleRow title="Drop Weapon on Death" desc="Weapon falls to the ground on death"
          checked={!!config.DropWeaponOnDeath} onChange={(v) => update('DropWeaponOnDeath', v)} />
      </Section>

      <Section icon="grid" title="INTERFACE" sub="On-screen prompt placement."
        action={<Segmented value={pos} options={POSITIONS} onChange={(v) => update('UIPosition', v)} />}>
        {pos === 'custom' && (
          <p className="mbt-field__hint">
            Custom drag is coming with the overlay reskin — uses a default spot for now.
          </p>
        )}
      </Section>
    </>
  )
}

export default GeneralSection
