import { PositionPicker } from '../ui/PositionPicker'
import { Segmented } from '../ui/Segmented'
import { NumberInput } from '../ui/NumberInput'
import { Section, ToggleRow, FieldBlock, type SectionProps } from './parts'

/**
 * Core category — split into atomic cards so the category page can order them
 * freely (CoreSection and InterfaceSection are placed separately in the grid).
 */

/** CORE — core sling toggles (runtime-safe; Debug stays in config.lua). */
export function CoreSection({ config, update }: SectionProps) {
  return (
    <Section icon="power" title="CORE" sub="Whether weapons show on the body at all.">
      <ToggleRow title="Enable Sling" desc="Show the weapon on the player's body"
        checked={!!config.EnableSling} onChange={(v) => update('EnableSling', v)} />
      <ToggleRow title="Enable Flashlight" desc="A slung weapon's torch stays lit if it was on"
        checked={!!config.EnableFlashlight} onChange={(v) => update('EnableFlashlight', v)} />
      <ToggleRow title="Holster Confirm" desc="Ask before a drawn sidearm reaches the hand — the draw animation plays either way"
        checked={!!config.HolsterConfirm} onChange={(v) => update('HolsterConfirm', v)} />
      <ToggleRow title="Drop Weapon on Death" desc="The weapon in hand falls where the player died"
        checked={!!config.DropWeaponOnDeath} onChange={(v) => update('DropWeaponOnDeath', v)} />
    </Section>
  )
}

/** MULTI-WEAPON — more than one weapon visible in the same body slot.
 *  Off by default: the slots are body positions, not weapon families, so turning this on
 *  changes what every player looks like. */
export function MultiWeaponSection({ config, update }: SectionProps) {
  const mw = config.MultiWeaponVisibility ?? {}
  return (
    <Section icon="power" title="MULTI-WEAPON" sub="More than one weapon in the same body slot.">
      <ToggleRow title="Show Multiple Weapons"
        desc="A rifle and a shotgun share the back slot — off, only one of them shows"
        checked={!!mw.Enabled} onChange={(v) => update('MultiWeaponVisibility.Enabled', v)} />
      <FieldBlock label="Max Per Slot"
        hint="Distinct weapons drawn per slot. Copies of the same model share one prop; the rest are still tracked."
        disabled={!mw.Enabled} style={{ marginBottom: 0 }}>
        <NumberInput min={1} max={4} step={1} value={String(mw.MaxPerType ?? 2)}
          onChange={(raw) => update('MultiWeaponVisibility.MaxPerType', raw === '' ? 2 : parseInt(raw, 10) || 2)} />
      </FieldBlock>
    </Section>
  )
}

/** INTERFACE — HUD prompt position (3 presets). "Custom" (a live drag-to-place
 *  HUD editor) is reserved for v2.1; the picker shows it disabled with a badge. */
export function InterfaceSection({ config, update }: SectionProps) {
  const pos = config.UIPosition ?? 'bottom-center'
  return (
    <Section icon="grid" title="INTERFACE" sub="Prompt placement and style.">
      <FieldBlock label="Prompt Style" hint="Standard sits in a fixed spot on screen · Cinematic appears beside the weapon.">
        <Segmented
          value={config.UIStyle ?? 'standard'}
          onChange={(v) => update('UIStyle', v)}
          options={[{ value: 'standard', label: 'Standard' }, { value: 'cinematic', label: 'Cinematic' }]}
        />
      </FieldBlock>
      <PositionPicker value={pos} onChange={(v) => update('UIPosition', v)} />
      {pos === 'custom' && (
        <p className="mbt-field__hint" style={{ marginTop: 8 }}>
          Custom placement — a live drag-to-place editor — ships in v2.1; using a default spot for now.
        </p>
      )}
    </Section>
  )
}
