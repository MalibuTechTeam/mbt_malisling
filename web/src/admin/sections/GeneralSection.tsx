import { PositionPicker } from '../ui/PositionPicker'
import { Section, ToggleRow, type SectionProps } from './parts'

/**
 * Core category — split into atomic cards so the category page can order them
 * freely (CoreSection and InterfaceSection are placed separately in the grid).
 */

/** CORE — core sling toggles (runtime-safe; Debug stays in config.lua). */
export function CoreSection({ config, update }: SectionProps) {
  return (
    <Section icon="power" title="CORE" sub="Main sling toggles.">
      <ToggleRow title="Enable Sling" desc="Show the weapon on the player's body"
        checked={!!config.EnableSling} onChange={(v) => update('EnableSling', v)} />
      <ToggleRow title="Enable Flashlight" desc="Render attached weapon flashlights"
        checked={!!config.EnableFlashlight} onChange={(v) => update('EnableFlashlight', v)} />
      <ToggleRow title="Drop Weapon on Death" desc="Weapon drops to the ground on death"
        checked={!!config.DropWeaponOnDeath} onChange={(v) => update('DropWeaponOnDeath', v)} />
    </Section>
  )
}

/** INTERFACE — HUD prompt position (3 presets + Custom; drag lands with the
 *  overlay reskin, default spot for now). */
export function InterfaceSection({ config, update }: SectionProps) {
  const pos = config.UIPosition ?? 'bottom-center'
  return (
    <Section icon="grid" title="INTERFACE" sub="On-screen prompt placement.">
      <PositionPicker value={pos} onChange={(v) => update('UIPosition', v)} />
      {pos === 'custom' && (
        <p className="mbt-field__hint" style={{ marginTop: 8 }}>
          Custom drag ships with the overlay reskin — uses a default spot for now.
        </p>
      )}
    </Section>
  )
}
