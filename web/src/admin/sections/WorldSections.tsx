import { useState, useEffect, useCallback } from 'react'
import { Section, ToggleRow, FieldBlock, Grid2, type SectionProps } from './parts'
import { NumberInput } from '../ui/NumberInput'
import { Icon } from '../ui/Icon'
import { fetchNui } from '../../utils/fetchNui'

const numUpdate = (update: SectionProps['update'], path: string, def: number, int = false) =>
  (raw: string) => update(path, raw === '' ? def : (int ? parseInt(raw, 10) : parseFloat(raw)) || def)

/** No-Draw Zones — areas where firearms can't be drawn (zone list in config.lua). */
export function NoDrawSection({ config, update }: SectionProps) {
  const n = config.NoDrawZones ?? {}
  return (
    <Section icon="alert" title="NO-DRAW ZONES" sub="Block drawing firearms in safe-zone areas."
      action={<ToggleRow.Inline checked={!!n.Enabled} onChange={(v) => update('NoDrawZones.Enabled', v)} />}>
      <ToggleRow title="Allow Melee" desc="Keep melee usable inside zones; blocks firearms only"
        checked={!!n.AllowMelee} onChange={(v) => update('NoDrawZones.AllowMelee', v)} />
      <ToggleRow title="HUD Banner" desc="Show a banner while inside a no-draw zone"
        checked={!!n.HudIndicator} onChange={(v) => update('NoDrawZones.HudIndicator', v)} />
      <FieldBlock label="Notify Cooldown (ms)" hint="Minimum time between “can't draw here” notices." style={{ marginBottom: 0 }}>
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
        desc="On: visible on roofless vehicles. Off: hidden in all"
        checked={!!v.Enabled} onChange={(x) => update('VehicleHiding.Enabled', x)} />
      <ToggleRow title="Roof Check"
        desc="Stay visible on quads and buggies too"
        checked={!!v.UseRoofCheck} onChange={(x) => update('VehicleHiding.UseRoofCheck', x)} />
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
      <ToggleRow title="Retrieve to Hand" desc="Take the weapon straight into hand (ox + qb)"
        checked={!!t.EquipOnRetrieve} onChange={(v) => update('VehicleTrunkRack.EquipOnRetrieve', v)} />
    </Section>
  )
}

/** Weapon Rack / Gun Locker — stow weapons on a fixed world rack (oxmysql-persisted).
 *  Rack locations, props and offsets are defined in config.lua (MBT.WeaponRack.Locations). */
export function WeaponRackSection({ config, update }: SectionProps) {
  const t = config.WeaponRack ?? {}
  const at = t.AllowedTypes ?? {}
  return (
    <Section icon="layers" title="WEAPON RACK" sub="Stow weapons on fixed world racks / gun lockers."
      action={<ToggleRow.Inline checked={!!t.Enabled} onChange={(v) => update('WeaponRack.Enabled', v)} />}>
      <FieldBlock label="Allowed Weapons" hint="Which weapon types can go on a rack.">
        <Grid2>
          <ToggleRow title="Rifles / Long guns" checked={!!at.back}
            onChange={(v) => update('WeaponRack.AllowedTypes.back', v)} />
          <ToggleRow title="Heavy / Launchers" checked={!!at.back2}
            onChange={(v) => update('WeaponRack.AllowedTypes.back2', v)} />
        </Grid2>
        <ToggleRow title="Pistols / Sidearms" checked={!!at.side}
          onChange={(v) => update('WeaponRack.AllowedTypes.side', v)} />
      </FieldBlock>
      <Grid2>
        <FieldBlock label="Capacity" hint="Max weapons per rack." style={{ marginBottom: 0 }}>
          <NumberInput min={1} max={12} step={1} value={String(t.Capacity ?? 4)}
            onChange={numUpdate(update, 'WeaponRack.Capacity', 4, true)} />
        </FieldBlock>
        <FieldBlock label="Reach (m)" hint="Interaction distance at the rack." style={{ marginBottom: 0 }}>
          <NumberInput min={1} max={10} step={0.5} value={String(t.InteractionDistance ?? 2.0)}
            onChange={numUpdate(update, 'WeaponRack.InteractionDistance', 2.0)} />
        </FieldBlock>
      </Grid2>
      <ToggleRow title="Retrieve to Hand" desc="Take the weapon straight into hand (ox + qb)"
        checked={!!t.EquipOnRetrieve} onChange={(v) => update('WeaponRack.EquipOnRetrieve', v)} />
      <FieldBlock label="Item Placement" hint="Players place their own racks from an inventory item.">
        <ToggleRow title="Enable Placement" desc="Install a rack in the world from the rack item (needs oxmysql)"
          checked={!!t.Placement?.Enabled} onChange={(v) => update('WeaponRack.Placement.Enabled', v)} />
        <ToggleRow title="Owner-only Access" desc="Only the player who placed a rack can use it"
          checked={t.Placement?.Access === 'owner'}
          onChange={(v) => update('WeaponRack.Placement.Access', v ? 'owner' : 'everyone')} />
        <ToggleRow title="Allow Pickup" desc="The owner can dismount an empty rack and get the item back"
          checked={!!t.Placement?.AllowPickup} onChange={(v) => update('WeaponRack.Placement.AllowPickup', v)} />
        <FieldBlock label="Max per Player" hint="Item-placed racks each player can have at once." style={{ marginBottom: 0 }}>
          <NumberInput min={1} max={20} step={1} value={String(t.Placement?.MaxPerPlayer ?? 2)}
            onChange={numUpdate(update, 'WeaponRack.Placement.MaxPerPlayer', 2, true)} />
        </FieldBlock>
      </FieldBlock>
      <div className="mbt-field__hint" style={{ marginTop: 2 }}>
        Rack locations, props, per-type offsets and per-job access live in <code>config.lua</code>
        (<code>MBT.WeaponRack</code>).
      </div>
    </Section>
  )
}

const VEHICLE_CLASSES: Record<number, string> = {
  0: 'Compacts', 1: 'Sedans', 2: 'SUVs', 3: 'Coupes', 4: 'Muscle', 5: 'Sports Classics',
  6: 'Sports', 7: 'Super', 8: 'Motorcycles', 9: 'Off-road', 10: 'Industrial', 11: 'Utility',
  12: 'Vans', 13: 'Cycles', 14: 'Boats', 15: 'Helicopters', 16: 'Planes', 17: 'Service',
  18: 'Emergency', 19: 'Military', 20: 'Commercial', 21: 'Trains',
}
interface TrunkOverride { scope: string; data: { Pos: { x: number; y: number; z: number }; Rot: { x: number; y: number; z: number } } }
interface TrunkStart { ok: boolean; model: string; class: number; off: TrunkOverride['data']; view?: { yaw: number; pitch: number; dist: number } }
interface TrunkPositionsProps extends SectionProps { onEdit?: (s: TrunkStart) => void; refreshKey?: number }

/** Trunk Positions — feature toggle + live in-world editor + per-model/class offsets. */
export function TrunkPositionsSection({ config, update, onEdit, refreshKey }: TrunkPositionsProps) {
  const t = config?.VehicleTrunkRack ?? {}
  const [list, setList] = useState<TrunkOverride[]>([])
  const [note, setNote] = useState('')   // in-dashboard warning (no ox_lib)
  const refresh = useCallback(() => {
    fetchNui('trunkOffsets:get').then((r: any) => setList(Array.isArray(r) ? r : []))
  }, [])
  useEffect(() => { refresh() }, [refresh])
  // The live editor lives in a sibling component; when it saves, the dashboard bumps refreshKey.
  // Re-pull after a short delay so the server has persisted the new override before we read it.
  useEffect(() => { if (refreshKey) window.setTimeout(refresh, 150) }, [refreshKey, refresh])

  // Auto-dismiss the inline warning after a few seconds.
  useEffect(() => {
    if (!note) return
    const id = window.setTimeout(() => setNote(''), 4000)
    return () => window.clearTimeout(id)
  }, [note])

  const REASONS: Record<string, string> = {
    no_vehicle: 'No vehicle nearby — stand behind a car, then open the Live Editor.',
    on_foot: 'Exit the vehicle first, then open the Live Editor.',
    not_at_trunk: 'Stand next to the trunk, then open the Live Editor.',
    trunk_wont_open: "Couldn't open this trunk — the vehicle may not have one.",
    busy: 'The editor is already open.',
  }
  const openEditor = () => {
    setNote('')
    fetchNui('trunkEdit:start').then((r: any) => {
      if (r?.ok) { if (onEdit) onEdit(r) }
      else setNote(REASONS[r?.reason] ?? "Couldn't open the trunk editor.")
    })
  }

  const label = (scope: string) => {
    const [kind, key] = scope.split(':')
    if (kind === 'class') return VEHICLE_CLASSES[Number(key)] ?? `Class ${key}`
    return key
  }
  const reset = (scope: string) => {
    fetchNui('trunkOffsets:reset', { scope }).then(() => window.setTimeout(refresh, 150))
  }

  return (
    <Section icon="vehicle" title="TRUNK POSITIONS" sub="Where the weapon sits in a vehicle's trunk."
      action={
        <span className="mbt-section__action-row">
          <button type="button" className="mbt-btn-primary mbt-btn--sm" onClick={openEditor}
            disabled={!t.Enabled} title={t.Enabled ? '' : 'Enable the trunk rack first'}>
            <Icon name="configure" size={13} /> Live Editor
          </button>
          <ToggleRow.Inline label="Trunk Rack" checked={!!t.Enabled} onChange={(v) => update('VehicleTrunkRack.Enabled', v)} />
        </span>
      }>
      <div className="mbt-notice">
        Stand <b>next to the trunk</b> and hit <b>Live Editor</b> — it opens the boot, then nudge the weapon
        into place and Save per <b>model</b> (exact) or <b>class</b> (broad). Applies live.
        <code>/mbt_trunktune</code> is the key-driven tuner.
      </div>
      {note && (
        <div className="mbt-notice mbt-notice--warn" role="alert">
          <Icon name="alert" size={13} />
          <span>{note}</span>
          <button type="button" className="mbt-notice__x" aria-label="Dismiss warning" onClick={() => setNote('')}>×</button>
        </div>
      )}
      {list.length === 0 ? (
        <div className="mbt-field__hint" style={{ marginTop: 2, whiteSpace: 'normal' }}>
          No overrides yet — every vehicle uses the default placement.
        </div>
      ) : (
        <div className="mbt-trunk-list">
          {list.map((o) => (
            <div key={o.scope} className="mbt-trunk-row">
              <span className="mbt-trunk-row__info">
                <span className="mbt-trunk-row__name">
                  <span className="mbt-trunk-row__nm">{label(o.scope)}</span>
                  <span className={`mbt-trunk-row__tag mbt-trunk-row__tag--${o.scope.startsWith('class:') ? 'class' : 'model'}`}>
                    {o.scope.startsWith('class:') ? 'class' : 'model'}
                  </span>
                </span>
                <span className="mbt-trunk-row__coords">
                  z {o.data.Pos.z.toFixed(2)} · y {o.data.Pos.y.toFixed(2)} · rz {o.data.Rot.z.toFixed(0)}°
                </span>
              </span>
              <button type="button" className="mbt-btn-ghost" onClick={() => reset(o.scope)}>Reset</button>
            </div>
          ))}
        </div>
      )}
    </Section>
  )
}
