import { Section, ToggleRow, FieldBlock, type SectionProps } from './parts'
import { NumberInput } from '../ui/NumberInput'

const numUpdate = (update: SectionProps['update'], path: string, def: number, int = false) =>
  (raw: string) => update(path, raw === '' ? def : (int ? parseInt(raw, 10) : parseFloat(raw)) || def)

/** No-Draw Zones — areas where firearms can't be drawn (zone list in config.lua). */
export function NoDrawSection({ config, update }: SectionProps) {
  const n = config.NoDrawZones ?? {}
  return (
    <Section icon="alert" title="NO-DRAW ZONES" sub="Block drawing firearms in safe areas (zone coords in config.lua)."
      action={<ToggleRow.Inline checked={!!n.Enabled} onChange={(v) => update('NoDrawZones.Enabled', v)} />}>
      <ToggleRow title="Allow Melee" desc="Melee weapons stay usable inside zones (block firearms only)"
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
    <Section icon="configure" title="VEHICLE SMART HIDING" sub="Slung weapons are always hidden in enclosed vehicles; this controls roofless ones."
      action={<ToggleRow.Inline checked={!!v.Enabled} onChange={(x) => update('VehicleHiding.Enabled', x)} />}>
      <ToggleRow title="Smart Hiding"
        desc="On: stay visible on roofless vehicles (bikes/quads/convertibles). Off: hide in any vehicle."
        checked={!!v.Enabled} onChange={(x) => update('VehicleHiding.Enabled', x)} />
      <ToggleRow title="Roof Check"
        desc="Also keep visible on any vehicle without a roof (quads, buggies, top-down convertibles)"
        checked={!!v.UseRoofCheck} onChange={(x) => update('VehicleHiding.UseRoofCheck', x)} />
    </Section>
  )
}

/** Tactical Sling — visible strap prop on the torso while a long gun is slung. */
export function TacticalSlingSection({ config, update }: SectionProps) {
  const t = config.TacticalSling ?? {}
  return (
    <Section icon="layers" title="TACTICAL SLING" sub="Visible strap prop while a long gun is slung. Requires a strap model in stream/."
      action={<ToggleRow.Inline checked={!!t.Enabled} onChange={(v) => update('TacticalSling.Enabled', v)} />}>
      <div className="mbt-field__hint" style={{ marginTop: 2 }}>
        Ships disabled until you add a strap prop model to <code>stream/</code> and set
        its name + position in <code>config.lua</code>. Enabling it without a model has no effect.
      </div>
    </Section>
  )
}
