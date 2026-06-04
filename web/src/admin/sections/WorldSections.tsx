import { Section, ToggleRow, FieldBlock, Grid2, type SectionProps } from './parts'
import { NumberInput } from '../ui/NumberInput'

const numUpdate = (update: SectionProps['update'], path: string, def: number, int = false) =>
  (raw: string) => update(path, raw === '' ? def : (int ? parseInt(raw, 10) : parseFloat(raw)) || def)

/** No-Draw Zones — areas where firearms can't be drawn (zone list in config.lua). */
export function NoDrawSection({ config, update }: SectionProps) {
  const n = config.NoDrawZones ?? {}
  return (
    <Section icon="alert" title="NO-DRAW ZONES" sub="Block drawing firearms in safe-zone areas."
      action={<ToggleRow.Inline checked={!!n.Enabled} onChange={(v) => update('NoDrawZones.Enabled', v)} />}>
      <ToggleRow title="Allow Melee" desc="Melee stays usable inside zones (firearms only)"
        checked={!!n.AllowMelee} onChange={(v) => update('NoDrawZones.AllowMelee', v)} />
      <ToggleRow title="HUD Banner" desc="Show an on-screen banner while inside a no-draw zone"
        checked={!!n.HudIndicator} onChange={(v) => update('NoDrawZones.HudIndicator', v)} />
      <FieldBlock label="Notify Cooldown (ms)" hint="Minimum time between “can't draw here” notifications." style={{ marginBottom: 0 }}>
        <NumberInput min={500} max={30000} step={500} value={String(n.NotifyCooldown ?? 3000)}
          onChange={numUpdate(update, 'NoDrawZones.NotifyCooldown', 3000, true)} />
      </FieldBlock>
    </Section>
  )
}

/** Vehicle Smart Hiding — keep the slung weapon visible on roofless vehicles.
 *  NOTE: Enabled is smart-vs-legacy, NOT on/off. The weapon is ALWAYS hidden in
 *  enclosed vehicles (it would clip the roof). On = smart (visible on bikes/quads/
 *  convertibles); Off = legacy (hide in any vehicle). */
export function VehicleSection({ config, update }: SectionProps) {
  const v = config.VehicleHiding ?? {}
  return (
    <Section icon="vehicle" title="VEHICLE SMART HIDING" sub="Hidden in enclosed vehicles; configure roofless ones."
      action={<ToggleRow.Inline checked={!!v.Enabled} onChange={(x) => update('VehicleHiding.Enabled', x)} />}>
      <ToggleRow title="Smart Hiding"
        desc="On: visible on roofless vehicles. Off: hidden in all."
        checked={!!v.Enabled} onChange={(x) => update('VehicleHiding.Enabled', x)} />
      <ToggleRow title="Roof Check"
        desc="Keep visible on roofless vehicles too (quads, buggies)"
        checked={!!v.UseRoofCheck} onChange={(x) => update('VehicleHiding.UseRoofCheck', x)} />
    </Section>
  )
}

/** Tactical Sling — visible strap prop on the torso while a long gun is slung. */
export function TacticalSlingSection({ config, update }: SectionProps) {
  const t = config.TacticalSling ?? {}
  return (
    <Section icon="layers" title="TACTICAL SLING" sub="Visible strap prop for slung long guns."
      action={<ToggleRow.Inline checked={!!t.Enabled} onChange={(v) => update('TacticalSling.Enabled', v)} />}>
      <div className="mbt-field__hint" style={{ marginTop: 2 }}>
        Ships disabled until you add a strap prop model to <code>stream/</code> and set
        its name + position in <code>config.lua</code>. Enabling it without a model has no effect.
      </div>
    </Section>
  )
}

/** Trunk Weapon Rack — stow long guns in a vehicle trunk (oxmysql-persisted). */
export function TrunkRackSection({ config, update }: SectionProps) {
  const t = config.VehicleTrunkRack ?? {}
  const at = t.AllowedTypes ?? {}
  return (
    <Section icon="layers" title="TRUNK WEAPON RACK" sub="Stow long guns in a vehicle's trunk."
      action={<ToggleRow.Inline checked={!!t.Enabled} onChange={(v) => update('VehicleTrunkRack.Enabled', v)} />}>
      <FieldBlock label="Allowed Weapons" hint="Which long-gun types can be racked.">
        <Grid2>
          <ToggleRow title="Rifles / Long guns" checked={!!at.back}
            onChange={(v) => update('VehicleTrunkRack.AllowedTypes.back', v)} />
          <ToggleRow title="Heavy / Launchers" checked={!!at.back2}
            onChange={(v) => update('VehicleTrunkRack.AllowedTypes.back2', v)} />
        </Grid2>
      </FieldBlock>
      <Grid2>
        <FieldBlock label="Capacity" hint="Max weapons per vehicle." style={{ marginBottom: 0 }}>
          <NumberInput min={1} max={10} step={1} value={String(t.Capacity ?? 2)}
            onChange={numUpdate(update, 'VehicleTrunkRack.Capacity', 2, true)} />
        </FieldBlock>
        <FieldBlock label="Reach (m)" hint="Interaction distance at the trunk." style={{ marginBottom: 0 }}>
          <NumberInput min={1} max={10} step={0.5} value={String(t.InteractionDistance ?? 2.5)}
            onChange={numUpdate(update, 'VehicleTrunkRack.InteractionDistance', 2.5)} />
        </FieldBlock>
      </Grid2>
    </Section>
  )
}
