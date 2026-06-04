import { Section, ToggleRow, FieldBlock, Grid2, type SectionProps } from './parts'
import { NumberInput } from '../ui/NumberInput'
import { Segmented } from '../ui/Segmented'

const numUpdate = (update: SectionProps['update'], path: string, def: number, int = false) =>
  (raw: string) => update(path, raw === '' ? def : (int ? parseInt(raw, 10) : parseFloat(raw)) || def)

/** Weapon Inspect — examine the held weapon (anim + local overlay). */
const AMMO_MODES = [
  { value: 'exact', label: 'Exact' },
  { value: 'vague', label: 'Vague' },
]
export function InspectSection({ config, update }: SectionProps) {
  const i = config.Inspect ?? {}
  const show = i.Show ?? {}
  return (
    <Section icon="search" title="WEAPON INSPECT" sub="Hold the inspect key to examine the held weapon."
      action={<ToggleRow.Inline checked={!!i.Enabled} onChange={(v) => update('Inspect.Enabled', v)} />}>
      <Grid2>
        <FieldBlock label="Sync Distance (m)" hint="How far nearby players see the inspect animation." style={{ marginBottom: 0 }}>
          <NumberInput min={1} max={50} step={1} value={String(i.MaxDistance ?? 20)}
            onChange={numUpdate(update, 'Inspect.MaxDistance', 20)} />
        </FieldBlock>
        <FieldBlock label="Ammo Display" hint="Exact = round count · Vague = Full/Half/Low (no-HUD servers)." style={{ marginBottom: 0 }}>
          <Segmented value={i.AmmoMode ?? 'exact'} options={AMMO_MODES} onChange={(v) => update('Inspect.AmmoMode', v)} />
        </FieldBlock>
      </Grid2>
      <FieldBlock label="Overlay Fields" hint="Which details the inspect overlay shows.">
        <Grid2>
          <ToggleRow title="Serial" checked={!!show.Serial} onChange={(v) => update('Inspect.Show.Serial', v)} />
          <ToggleRow title="Condition" checked={!!show.Condition} onChange={(v) => update('Inspect.Show.Condition', v)} />
          <ToggleRow title="Name" checked={!!show.Name} onChange={(v) => update('Inspect.Show.Name', v)} />
          <ToggleRow title="Ammo" checked={!!show.Ammo} onChange={(v) => update('Inspect.Show.Ammo', v)} />
        </Grid2>
      </FieldBlock>
    </Section>
  )
}

/** Custom Weapon Name — engrave a name stored in the weapon metadata. */
const NAME_PERMS = [
  { value: 'everyone', label: 'Everyone' },
  { value: 'job', label: 'Job' },
  { value: 'ace', label: 'ACE' },
]
export function WeaponNameSection({ config, update }: SectionProps) {
  const w = config.WeaponName ?? {}
  return (
    <Section icon="book" title="WEAPON NAME" sub="Engrave a custom name on a firearm."
      action={<ToggleRow.Inline checked={!!w.Enabled} onChange={(v) => update('WeaponName.Enabled', v)} />}>
      <Grid2>
        <FieldBlock label="Max Length" hint="Character cap on the engraved name." style={{ marginBottom: 0 }}>
          <NumberInput min={1} max={64} step={1} value={String(w.MaxLength ?? 24)}
            onChange={numUpdate(update, 'WeaponName.MaxLength', 24, true)} />
        </FieldBlock>
        <FieldBlock label="Who Can Rename" hint="Job list / ACE perm are set in config.lua." style={{ marginBottom: 0 }}>
          <Segmented value={w.Permission ?? 'everyone'} options={NAME_PERMS} onChange={(v) => update('WeaponName.Permission', v)} />
        </FieldBlock>
      </Grid2>
      <ToggleRow title="Once Per Weapon" desc="Block re-naming once a weapon is named"
        checked={!!w.OncePerWeapon} onChange={(v) => update('WeaponName.OncePerWeapon', v)} />
    </Section>
  )
}

/** Showcase Poses — cycle RP idle poses (group photos). */
export function PosesSection({ config, update }: SectionProps) {
  const p = config.ShowcasePoses ?? {}
  return (
    <Section icon="pose" title="SHOWCASE POSES" sub="Cycle RP idle poses for screenshots."
      action={<ToggleRow.Inline checked={!!p.Enabled} onChange={(v) => update('ShowcasePoses.Enabled', v)} />}>
      <ToggleRow title="Sync to Nearby Players" desc="Others see your pose, including late arrivals"
        checked={!!p.Sync} onChange={(v) => update('ShowcasePoses.Sync', v)} />
    </Section>
  )
}

/** Weapon Throw — toss the held weapon; allowed per weapon group. */
const THROW_GROUPS: { key: string; label: string }[] = [
  { key: 'MELEE', label: 'Melee' },
  { key: 'PISTOL', label: 'Pistol' },
  { key: 'RIFLE', label: 'Rifle' },
  { key: 'SMG', label: 'SMG' },
  { key: 'SHOTGUN', label: 'Shotgun' },
  { key: 'STUNGUN', label: 'Stun Gun' },
  { key: 'MG', label: 'MG' },
  { key: 'SNIPER', label: 'Sniper' },
  { key: 'HEAVY', label: 'Heavy' },
]
export function ThrowSection({ config, update }: SectionProps) {
  const t = config.Throw ?? {}
  const groups = t.Groups ?? {}
  return (
    <Section icon="teleport" title="WEAPON THROW" sub="Toss the held weapon by weapon group."
      action={<ToggleRow.Inline checked={!!t.Enabled} onChange={(v) => update('Throw.Enabled', v)} />}>
      <FieldBlock label="Throwable Weapon Groups" hint="Which weapon groups the player is allowed to throw.">
        <Grid2>
          {THROW_GROUPS.map((g) => (
            <ToggleRow key={g.key} title={g.label}
              checked={!!groups[g.key]} onChange={(v) => update(`Throw.Groups.${g.key}`, v)} />
          ))}
        </Grid2>
      </FieldBlock>
    </Section>
  )
}
