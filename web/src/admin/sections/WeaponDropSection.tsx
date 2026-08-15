import { Section, ToggleRow, FieldBlock, Grid2, type SectionProps, withMeta } from './parts'
import { NumberInput } from '../ui/NumberInput'

/**
 * Weapon Drop — two atomic cards (Drop Visual, Despawn Timer) so the Core category
 * page can order and place them independently in the grid. Drop logging is a Discord
 * webhook (a server-only secret) → configured in config.lua, not the dashboard.
 */

/** DROP VISUAL — rendered drop model + ox_target pickup. */
export function DropVisualSection({ config, update }: SectionProps) {
  const d = config.WeaponDrop ?? {}
  return (
    <Section icon="layers" title="DROP VISUAL" sub="Look and pickup of a dropped weapon.">
      <ToggleRow title="Render Weapon Model" desc="The actual gun lies on the ground, not a generic bag"
        checked={!!d.WeaponModelProp} onChange={(v) => update('WeaponDrop.WeaponModelProp', v)} />
      <ToggleRow title="ox_target Pickup" desc="Aim at it to pick it up, instead of walking over it"
        checked={!!d.OxTargetPickup} onChange={(v) => update('WeaponDrop.OxTargetPickup', v)} />
    </Section>
  )
}

/** DESPAWN TIMER — auto-remove dropped weapons after a delay. */
export function DespawnSection({ config, update }: SectionProps) {
  const dd = (config.WeaponDrop ?? {}).Despawn ?? {}
  return (
    <Section icon="clock" title="DESPAWN TIMER" sub="Auto-remove dropped weapons after a delay.">
      <ToggleRow title="Enable Despawn" desc="Off means dropped weapons stay until someone takes them"
        checked={!!dd.Enabled} onChange={(v) => update('WeaponDrop.Despawn.Enabled', v)} />
      <Grid2>
        <FieldBlock label="Despawn After (s)" hint="Counted from when it hits the ground." style={{ marginBottom: 0 }}>
          <NumberInput min={5} max={3600} step={5} value={String(dd.Seconds ?? 300)}
            onChange={(raw) => update('WeaponDrop.Despawn.Seconds', raw === '' ? 300 : parseInt(raw, 10) || 300)} />
        </FieldBlock>
        <FieldBlock label="Blink Last (s)" hint="Warn before vanishing (0 = off)." style={{ marginBottom: 0 }}>
          <NumberInput min={0} max={60} step={1} value={String(dd.BlinkLastSec ?? 10)}
            onChange={(raw) => update('WeaponDrop.Despawn.BlinkLastSec', raw === '' ? 0 : parseInt(raw, 10) || 0)} />
        </FieldBlock>
      </Grid2>
    </Section>
  )
}


withMeta(DropVisualSection, {
  label: 'Drop Visual',
  also: [
    { label: 'Render Weapon Model', path: 'WeaponDrop.WeaponModelProp' },
    { label: 'ox_target Pickup', path: 'WeaponDrop.OxTargetPickup' },
  ],
})
withMeta(DespawnSection, { label: 'Drop Despawn', path: 'WeaponDrop.Despawn.Enabled' })
