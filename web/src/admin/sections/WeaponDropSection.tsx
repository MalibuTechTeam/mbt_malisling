import { Section, ToggleRow, FieldBlock, Grid2, type SectionProps } from './parts'
import { NumberInput } from '../ui/NumberInput'

/**
 * Weapon Drop — three atomic cards (Drop Visual, Despawn Timer, Drop Logging) so
 * the Core category page can order and place them independently in the grid.
 */

/** DROP VISUAL — rendered drop model + ox_target pickup. */
export function DropVisualSection({ config, update }: SectionProps) {
  const d = config.WeaponDrop ?? {}
  return (
    <Section icon="layers" title="DROP VISUAL" sub="Look and pickup of a dropped weapon.">
      <ToggleRow title="Render Weapon Model" desc="Real weapon on the ground, not ox's bag"
        checked={!!d.WeaponModelProp} onChange={(v) => update('WeaponDrop.WeaponModelProp', v)} />
      <ToggleRow title="ox_target Pickup" desc="Pick it up via ox_target"
        checked={!!d.OxTargetPickup} onChange={(v) => update('WeaponDrop.OxTargetPickup', v)} />
    </Section>
  )
}

/** DESPAWN TIMER — auto-remove dropped weapons after a delay. */
export function DespawnSection({ config, update }: SectionProps) {
  const dd = (config.WeaponDrop ?? {}).Despawn ?? {}
  return (
    <Section icon="clock" title="DESPAWN TIMER" sub="Auto-remove dropped weapons after a delay.">
      <ToggleRow title="Enable Despawn" desc="Remove dropped weapons after the timer"
        checked={!!dd.Enabled} onChange={(v) => update('WeaponDrop.Despawn.Enabled', v)} />
      <Grid2>
        <FieldBlock label="Despawn After (s)" hint="Time before removal." style={{ marginBottom: 0 }}>
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

/** DROP LOGGING — Discord webhook audit of weapon drops. */
export function DropLoggingSection({ config, update }: SectionProps) {
  const dl = (config.WeaponDrop ?? {}).Logging ?? {}
  return (
    <Section icon="clipboard" title="DROP LOGGING" sub="Log weapon drops to a Discord webhook.">
      <ToggleRow title="Enable Logging" desc="Log drops (death, throw, manual) to Discord"
        checked={!!dl.Enabled} onChange={(v) => update('WeaponDrop.Logging.Enabled', v)} />
      <FieldBlock label="Discord Webhook" hint="Required — logging needs a webhook URL." style={{ marginBottom: 0 }}>
        <input className="mbt-input" value={dl.Webhook ?? ''} placeholder="https://discord.com/api/webhooks/..."
          onChange={(e) => update('WeaponDrop.Logging.Webhook', e.target.value)} />
      </FieldBlock>
    </Section>
  )
}
