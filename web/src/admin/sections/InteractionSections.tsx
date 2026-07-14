import { Section, ToggleRow, FieldBlock, Grid2, type SectionProps } from './parts'
import { NumberInput } from '../ui/NumberInput'
import { Segmented } from '../ui/Segmented'
import { Icon } from '../ui/Icon'

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
        <FieldBlock label="Sync Distance (m)" hint="How far players see the inspect animation." style={{ marginBottom: 0 }}>
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
      <FieldBlock label="Overlay Preview" hint="A live sample of what players see — reflects the fields above." style={{ marginBottom: 0, flex: 1 }}>
        <div className="mbt-prev">
          <div className="mbt-prev__hero">
            <span className="mbt-prev__ic"><Icon name="search" size={20} /></span>
            <span className="mbt-prev__title">{show.Name ? 'Carbine Rifle' : 'Held Weapon'}</span>
            <span className="mbt-prev__tag">INSPECT</span>
          </div>
          <div className="mbt-prev__div" />
          <div className="mbt-prev__rows">
            {show.Serial && <div className="mbt-prev__row"><span>Serial</span><b>A7F-3K9Q</b></div>}
            {show.Condition && <div className="mbt-prev__row"><span>Condition</span><b className="is-warn">Worn</b></div>}
            {show.Ammo && <div className="mbt-prev__row"><span>Ammo</span><b>{i.AmmoMode === 'vague' ? 'Half' : '18 rounds'}</b></div>}
            {!show.Serial && !show.Condition && !show.Ammo &&
              <div className="mbt-prev__empty">
                {show.Name ? 'Only the weapon name is shown.' : 'No fields enabled — the overlay stays hidden.'}
              </div>}
          </div>
        </div>
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
      <ToggleRow title="Once Per Weapon" desc="Block renaming once a weapon is named"
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
      <ToggleRow title="Sync to Nearby Players" desc="Others see your pose, including latecomers"
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
  const c = t.Charge ?? {}
  const chargeOn = !!c.Enabled
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
      <ToggleRow title="Charge Power Throw"
        desc="Hold the throw key to charge power, release to throw farther; a tap is the normal throw (experimental)"
        checked={chargeOn} onChange={(v) => update('Throw.Charge.Enabled', v)} />
      <ToggleRow title="Show Charge Meter" disabled={!chargeOn}
        desc="Radial power meter around the reticle while charging"
        checked={!!c.ShowUI} onChange={(v) => update('Throw.Charge.ShowUI', v)} />
      <Grid2>
        <FieldBlock label="Charge Time (ms)" hint="Hold time to reach full power." style={{ marginBottom: 0 }} disabled={!chargeOn}>
          <NumberInput min={200} max={3000} step={50} disabled={!chargeOn} value={String(c.ChargeMs ?? 900)}
            onChange={numUpdate(update, 'Throw.Charge.ChargeMs', 900)} />
        </FieldBlock>
        <FieldBlock label="Max Power (×)" hint="Throw strength at full charge (× the normal throw)." style={{ marginBottom: 0 }} disabled={!chargeOn}>
          <NumberInput min={1} max={3} step={0.05} disabled={!chargeOn} value={String(c.MaxMultiplier ?? 1.25)}
            onChange={numUpdate(update, 'Throw.Charge.MaxMultiplier', 1.25)} />
        </FieldBlock>
      </Grid2>
    </Section>
  )
}

/** Chain of Custody — the weapon remembers everyone who carried it (Forensics). */
export function ChainOfCustodySection({ config, update }: SectionProps) {
  const c = config.ChainOfCustody ?? {}
  return (
    <Section icon="search" title="CHAIN OF CUSTODY" sub="The weapon remembers who has carried it (Forensics)."
      action={<ToggleRow.Inline checked={!!c.Enabled} onChange={(v) => update('ChainOfCustody.Enabled', v)} />}>
      <ToggleRow title="Show in Inspect" desc="List previous owners in the weapon inspect overlay"
        checked={c.ShowInInspect !== false} onChange={(v) => update('ChainOfCustody.ShowInInspect', v)} />
      <FieldBlock label="Max Entries" hint="Chain length cap (the origin owner is always kept).">
        <NumberInput min={2} max={50} step={1} value={String(c.MaxEntries ?? 10)}
          onChange={numUpdate(update, 'ChainOfCustody.MaxEntries', 10, true)} />
      </FieldBlock>
    </Section>
  )
}

/** Ammo Sharing — hand a portion of your ammo to a nearby player. */
export function AmmoSharingSection({ config, update }: SectionProps) {
  const a = config.AmmoSharing ?? {}
  return (
    <Section icon="cursor" title="AMMO SHARING" sub="Hand a portion of your ammo to a nearby player."
      action={<ToggleRow.Inline checked={!!a.Enabled} onChange={(v) => update('AmmoSharing.Enabled', v)} />}>
      <Grid2>
        <FieldBlock label="Share Amount" hint="Rounds offered per share (capped to what you have)." style={{ marginBottom: 0 }}>
          <NumberInput min={1} max={1000} step={5} value={String(a.ShareAmount ?? 30)}
            onChange={numUpdate(update, 'AmmoSharing.ShareAmount', 30, true)} />
        </FieldBlock>
        <FieldBlock label="Reach (m)" hint="How close the receiver must be." style={{ marginBottom: 0 }}>
          <NumberInput min={1} max={10} step={0.5} value={String(a.MaxDistance ?? 2.5)}
            onChange={numUpdate(update, 'AmmoSharing.MaxDistance', 2.5)} />
        </FieldBlock>
      </Grid2>
      <div className="mbt-field__hint" style={{ marginTop: 2 }}>
        The share key lives in <code>config.lua</code> (<code>MBT.AmmoSharing</code>). Ammo type comes
        from the held weapon.
      </div>
    </Section>
  )
}

/** Pat-down — police frisk a nearby person for weapons (open vs concealed). */
export function PatDownSection({ config, update }: SectionProps) {
  const p = config.PatDown ?? {}
  return (
    <Section icon="search" title="PAT-DOWN" sub="Police frisk a person for weapons — open vs concealed."
      action={<ToggleRow.Inline checked={!!p.Enabled} onChange={(v) => update('PatDown.Enabled', v)} />}>
      <ToggleRow title="Require Consent" desc="The target must accept the search (off = always allowed)"
        checked={p.RequireConsent !== false} onChange={(v) => update('PatDown.RequireConsent', v)} />
      <ToggleRow title="Cuffed Bypass" desc="Skip consent when the target is cuffed"
        checked={p.CuffedBypass !== false} onChange={(v) => update('PatDown.CuffedBypass', v)} />
      <ToggleRow title="Show Ammo" desc="Include loaded-ammo count in the result"
        checked={!!p.ShowAmmo} onChange={(v) => update('PatDown.ShowAmmo', v)} />
      <FieldBlock label="Reach (m)" hint="How close the officer must stand.">
        <NumberInput min={1} max={10} step={0.5} value={String(p.MaxDistance ?? 2.0)}
          onChange={numUpdate(update, 'PatDown.MaxDistance', 2.0)} />
      </FieldBlock>
      <div className="mbt-field__hint" style={{ marginTop: 2 }}>
        The frisk key, allowed jobs, and the audit-log Discord webhook live in <code>config.lua</code> (<code>MBT.PatDown</code>).
      </div>
    </Section>
  )
}

/** Concealed Carry — hide holstered small weapons if clothing allows it. */
export function ConcealedCarrySection({ config, update }: SectionProps) {
  const c = config.ConcealedCarry ?? {}
  const t = c.Tell ?? {}
  return (
    <Section icon="search" title="CONCEALED CARRY" sub="Hide holstered small weapons — if your clothes can cover them."
      action={<ToggleRow.Inline checked={!!c.Enabled} onChange={(v) => update('ConcealedCarry.Enabled', v)} />}>
      <FieldBlock label="Toggle Cooldown (ms)" hint="Anti-spam between conceal toggles.">
        <NumberInput min={0} max={60000} step={500} value={String(c.ToggleCooldownMs ?? 3000)}
          onChange={numUpdate(update, 'ConcealedCarry.ToggleCooldownMs', 3000, true)} />
      </FieldBlock>
      <ToggleRow title="Waistband Tell" desc="Carriers occasionally adjust their waistband — an observable RP tell"
        checked={t.Enabled !== false} onChange={(v) => update('ConcealedCarry.Tell.Enabled', v)} />
      <Grid2>
        <FieldBlock label="Tell Roll (s)" hint="Seconds between tell chances." style={{ marginBottom: 0 }}>
          <NumberInput min={5} max={600} step={5} value={String(t.RollSeconds ?? 25)}
            onChange={numUpdate(update, 'ConcealedCarry.Tell.RollSeconds', 25, true)} />
        </FieldBlock>
        <FieldBlock label="Chance poor / good" hint="Per-roll chance by concealment quality." style={{ marginBottom: 0 }}>
          <Grid2>
            <NumberInput min={0} max={1} step={0.05} value={String(t.ChancePoor ?? 0.45)}
              onChange={numUpdate(update, 'ConcealedCarry.Tell.ChancePoor', 0.45)} />
            <NumberInput min={0} max={1} step={0.05} value={String(t.ChanceGood ?? 0.15)}
              onChange={numUpdate(update, 'ConcealedCarry.Tell.ChanceGood', 0.15)} />
          </Grid2>
        </FieldBlock>
      </Grid2>
      <div className="mbt-field__hint" style={{ marginTop: 2 }}>
        Clothing blocklists, key and concealable types live in <code>config.lua</code>
        (<code>MBT.ConcealedCarry</code>). Use <code>/mbt_concealdebug</code> to tune custom clothing packs.
      </div>
    </Section>
  )
}

/** Weapon Serials — ensure-generation: every weapon gets a forensic serial. */
const SERIAL_FORMATS = [
  { value: 'marked', label: 'Marked (MBT-…)' },
  { value: 'oxlike', label: 'Factory-like' },
]
export function SerialsSection({ config, update }: SectionProps) {
  const s = config.Serials ?? {}
  return (
    <Section icon="search" title="WEAPON SERIALS" sub="Guarantee every weapon a serial (forensic backbone)."
      action={<ToggleRow.Inline checked={!!s.EnsureGeneration} onChange={(v) => update('Serials.EnsureGeneration', v)} />}>
      <FieldBlock label="Generated Format" hint="Marked = auditable field-assigned serials · Factory-like = indistinguishable from ox.">
        <Segmented value={s.Format ?? 'marked'} options={SERIAL_FORMATS}
          onChange={(v) => update('Serials.Format', v)} />
      </FieldBlock>
      <ToggleRow title="Sweep on Join" desc="Scan a player's weapons on join and fix missing serials"
        checked={s.SweepOnLoad !== false} onChange={(v) => update('Serials.SweepOnLoad', v)} />
      <div className="mbt-field__hint" style={{ marginTop: 2 }}>
        Serials are written once, on safe inventory transitions only (rack, handoff, drop, sweep) —
        never while a weapon is in use.
      </div>
    </Section>
  )
}

/** Physical Weapon Handoff — hand the drawn weapon to a nearby player. */
export function HandoffSection({ config, update }: SectionProps) {
  const h = config.Handoff ?? {}
  return (
    <Section icon="cursor" title="WEAPON HANDOFF" sub="Hand your drawn weapon to a nearby player, hand-to-hand."
      action={<ToggleRow.Inline checked={!!h.Enabled} onChange={(v) => update('Handoff.Enabled', v)} />}>
      <FieldBlock label="Reach (m)" hint="How close the receiver must be.">
        <NumberInput min={1} max={10} step={0.5} value={String(h.MaxDistance ?? 2.5)}
          onChange={numUpdate(update, 'Handoff.MaxDistance', 2.5)} />
      </FieldBlock>
      <ToggleRow title="Equip on Accept" desc="The receiver takes the weapon straight into hand (ox)"
        checked={!!h.EquipOnAccept} onChange={(v) => update('Handoff.EquipOnAccept', v)} />
      <div className="mbt-field__hint" style={{ marginTop: 2 }}>
        The handoff key and give/take animation clips live in <code>config.lua</code> (<code>MBT.Handoff</code>).
        Serial, condition, custom name and Chain of Custody travel with the weapon.
      </div>
    </Section>
  )
}

/** Forensic Shell Casings — gunfire leaves serial-linked casings on the ground. */
const SERIAL_REVEALS = [
  { value: 'none',    label: 'None' },
  { value: 'partial', label: 'Partial' },
  { value: 'full',    label: 'Full' },
]
export function ShellCasingsSection({ config, update }: SectionProps) {
  const s = config.ShellCasings ?? {}
  return (
    <Section icon="search" title="SHELL CASINGS" sub="Gunfire leaves serial-linked casings on the ground (Forensics)."
      action={<ToggleRow.Inline checked={!!s.Enabled} onChange={(v) => update('ShellCasings.Enabled', v)} />}>
      <Grid2>
        <FieldBlock label="Drop Chance" hint="Probability (0–1) a shot leaves a recoverable casing." style={{ marginBottom: 0 }}>
          <NumberInput min={0} max={1} step={0.05} value={String(s.Chance ?? 0.5)}
            onChange={numUpdate(update, 'ShellCasings.Chance', 0.5)} />
        </FieldBlock>
        <FieldBlock label="Expire (min)" hint="Casings disappear after this long." style={{ marginBottom: 0 }}>
          <NumberInput min={1} max={720} step={5} value={String(s.ExpireMinutes ?? 30)}
            onChange={numUpdate(update, 'ShellCasings.ExpireMinutes', 30, true)} />
        </FieldBlock>
      </Grid2>
      <FieldBlock label="Serial Reveal" hint="What examining a casing shows of the weapon's serial.">
        <Segmented value={s.SerialReveal ?? 'partial'} options={SERIAL_REVEALS}
          onChange={(v) => update('ShellCasings.SerialReveal', v)} />
      </FieldBlock>
      <ToggleRow title="Allow Collect" desc="Casings can be picked up, letting criminals clean the scene"
        checked={s.AllowCollect !== false} onChange={(v) => update('ShellCasings.AllowCollect', v)} />
      <FieldBlock label="World Cap" hint="Max casings in the world (oldest removed first)." style={{ marginBottom: 0 }}>
        <NumberInput min={10} max={1000} step={10} value={String(s.MaxCasings ?? 150)}
          onChange={numUpdate(update, 'ShellCasings.MaxCasings', 150, true)} />
      </FieldBlock>
    </Section>
  )
}
