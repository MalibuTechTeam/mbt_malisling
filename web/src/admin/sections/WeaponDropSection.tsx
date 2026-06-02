import { Section, ToggleRow, FieldBlock, Grid2, type SectionProps } from './parts'
import { NumberInput } from '../ui/NumberInput'

/** Weapon Drop — rendered drop model, ox_target pickup, despawn timer, logging.
 *  Two-column layout: Drop Visual + Despawn side by side, Logging full width. */
export function WeaponDropSection({ config, update }: SectionProps) {
  const d = config.WeaponDrop ?? {}
  const dd = d.Despawn ?? {}
  const dl = d.Logging ?? {}
  return (
    <>
      <Grid2>
        <Section icon="layers" title="DROP VISUAL" sub="Look & pickup of a dropped weapon.">
          <ToggleRow title="Render Weapon Model" desc="Real weapon on the ground (not ox's bag)"
            checked={!!d.WeaponModelProp} onChange={(v) => update('WeaponDrop.WeaponModelProp', v)} />
          <ToggleRow title="ox_target Pickup" desc="Add an ox_target option to pick it up"
            checked={!!d.OxTargetPickup} onChange={(v) => update('WeaponDrop.OxTargetPickup', v)} />
        </Section>

        <Section icon="clock" title="DESPAWN TIMER" sub="Dropped weapons disappear after a while.">
          <ToggleRow title="Enable Despawn" desc="Remove dropped weapons after the timer"
            checked={!!dd.Enabled} onChange={(v) => update('WeaponDrop.Despawn.Enabled', v)} />
          <Grid2>
            <FieldBlock label="Despawn After (s)" hint="Time before removal." style={{ marginBottom: 0 }}>
              <NumberInput min={5} max={3600} step={5} value={String(dd.Seconds ?? 300)}
                onChange={(raw) => update('WeaponDrop.Despawn.Seconds', raw === '' ? 300 : parseInt(raw, 10) || 300)} />
            </FieldBlock>
            <FieldBlock label="Blink Last (s)" hint="Warning before vanishing (0 = off)." style={{ marginBottom: 0 }}>
              <NumberInput min={0} max={60} step={1} value={String(dd.BlinkLastSec ?? 10)}
                onChange={(raw) => update('WeaponDrop.Despawn.BlinkLastSec', raw === '' ? 0 : parseInt(raw, 10) || 0)} />
            </FieldBlock>
          </Grid2>
        </Section>
      </Grid2>

      <Section icon="clipboard" title="DROP LOGGING" sub="Log drops to console / Discord webhook.">
        <ToggleRow title="Enable Logging" desc="Log weapon drops (death / throw / manual)"
          checked={!!dl.Enabled} onChange={(v) => update('WeaponDrop.Logging.Enabled', v)} />
        <ToggleRow title="Console Output" desc="Also print a line to the server console"
          checked={!!dl.Console} onChange={(v) => update('WeaponDrop.Logging.Console', v)} />
        <FieldBlock label="Discord Webhook" hint="Leave empty to log to console only." style={{ marginBottom: 0 }}>
          <input className="mbt-input" value={dl.Webhook ?? ''} placeholder="https://discord.com/api/webhooks/..."
            onChange={(e) => update('WeaponDrop.Logging.Webhook', e.target.value)} />
        </FieldBlock>
      </Section>
    </>
  )
}

export default WeaponDropSection
