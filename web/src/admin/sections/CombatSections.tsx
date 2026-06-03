import { Section, ToggleRow, FieldBlock, Grid2, type SectionProps } from './parts'
import { NumberInput } from '../ui/NumberInput'
import { Segmented } from '../ui/Segmented'

const numUpdate = (update: SectionProps['update'], path: string, def: number, int = false) =>
  (raw: string) => update(path, raw === '' ? def : (int ? parseInt(raw, 10) : parseFloat(raw)) || def)

/** Jamming — durability-based weapon jams + unjam minigame. */
export function JammingSection({ config, update }: SectionProps) {
  const j = config.Jamming ?? {}
  return (
    <Section icon="clock" title="WEAPON JAMMING" sub="Low-durability weapons can jam; clear with a key minigame."
      action={<ToggleRow.Inline checked={!!j.Enabled} onChange={(v) => update('Jamming.Enabled', v)} />}>
      <Grid2>
        <FieldBlock label="Jam Cooldown (s)" hint="Minimum time between possible jams." style={{ marginBottom: 0 }}>
          <NumberInput min={1} max={120} step={1} value={String(j.Cooldown ?? 5)}
            onChange={numUpdate(update, 'Jamming.Cooldown', 5, true)} />
        </FieldBlock>
        <FieldBlock label="Unjam Presses" hint="Key presses needed to clear a jam." style={{ marginBottom: 0 }}>
          <NumberInput min={1} max={20} step={1} value={String(j.UnjamPresses ?? 5)}
            onChange={numUpdate(update, 'Jamming.UnjamPresses', 5, true)} />
        </FieldBlock>
      </Grid2>
    </Section>
  )
}

/** Suppressor Heat — orange→red glow on sustained fire. */
const HEAT_MODES = [
  { value: 'glow', label: 'Glow' },
  { value: 'light', label: 'Light' },
  { value: 'particle', label: 'Particle' },
]
export function SuppressorSection({ config, update }: SectionProps) {
  const s = config.SuppressorHeat ?? {}
  return (
    <Section icon="power" title="SUPPRESSOR HEAT" sub="Suppressor glows orange→red during sustained fire."
      action={<ToggleRow.Inline checked={!!s.Enabled} onChange={(v) => update('SuppressorHeat.Enabled', v)} />}>
      <FieldBlock label="Render Mode" hint="Glow = no wall reflection · Light = real light · Particle = ptfx.">
        <Segmented value={s.Mode ?? 'glow'} options={HEAT_MODES} onChange={(v) => update('SuppressorHeat.Mode', v)} />
      </FieldBlock>
      <Grid2>
        <FieldBlock label="Heat per Shot" hint="How fast it heats up." style={{ marginBottom: 0 }}>
          <NumberInput min={1} max={100} step={1} value={String(s.HeatPerShot ?? 5)}
            onChange={numUpdate(update, 'SuppressorHeat.HeatPerShot', 5, true)} />
        </FieldBlock>
        <FieldBlock label="Decay Rate" hint="How fast it cools down." style={{ marginBottom: 0 }}>
          <NumberInput min={1} max={100} step={1} value={String(s.DecayRate ?? 16)}
            onChange={numUpdate(update, 'SuppressorHeat.DecayRate', 16, true)} />
        </FieldBlock>
        <FieldBlock label="Warm Threshold" hint="Heat where the glow appears." style={{ marginBottom: 0 }}>
          <NumberInput min={0} max={100} step={1} value={String(s.WarmThreshold ?? 35)}
            onChange={numUpdate(update, 'SuppressorHeat.WarmThreshold', 35, true)} />
        </FieldBlock>
        <FieldBlock label="Hot Threshold" hint="Heat where it turns deep red." style={{ marginBottom: 0 }}>
          <NumberInput min={0} max={100} step={1} value={String(s.HotThreshold ?? 75)}
            onChange={numUpdate(update, 'SuppressorHeat.HotThreshold', 75, true)} />
        </FieldBlock>
      </Grid2>
    </Section>
  )
}

/** Weapon Safety — SAFE/FIRE toggle on the held firearm. */
export function SafetySection({ config, update }: SectionProps) {
  const s = config.Safety ?? {}
  const c = config.ConditionHUD ?? {}
  return (
    <Section icon="lock" title="WEAPON SAFETY" sub="Toggle the safety on the held firearm (blocks fire, allows aim)."
      action={<ToggleRow.Inline checked={!!s.Enabled} onChange={(v) => update('Safety.Enabled', v)} />}>
      <ToggleRow title="Default On" desc="A freshly drawn weapon starts safetied"
        checked={!!s.DefaultOn} onChange={(v) => update('Safety.DefaultOn', v)} />
      <ToggleRow title="Per-Weapon State" desc="Each weapon remembers its own safety (by serial)"
        checked={!!s.PerWeapon} onChange={(v) => update('Safety.PerWeapon', v)} />
      <ToggleRow title="HUD Indicator" desc="Show the SAFE/FIRE pill while a firearm is in hand"
        checked={!!s.HudIndicator} onChange={(v) => update('Safety.HudIndicator', v)} />
      <ToggleRow title="Condition Pips" desc="Show the weapon's condition (tier 1-5) next to SAFE/FIRE in the same pill"
        checked={!!c.Enabled} onChange={(v) => update('ConditionHUD.Enabled', v)} />
    </Section>
  )
}

/** Charge Weapon — rack-the-slide intimidation gesture. */
export function ChargeSection({ config, update }: SectionProps) {
  const c = config.ChargeWeapon ?? {}
  return (
    <Section icon="cursor" title="CHARGE WEAPON" sub="Rack-the-slide intimidation gesture (anim + sound to nearby players)."
      action={<ToggleRow.Inline checked={!!c.Enabled} onChange={(v) => update('ChargeWeapon.Enabled', v)} />}>
      <Grid2>
        <FieldBlock label="Cooldown (ms)" hint="Anti-spam between racks." style={{ marginBottom: 0 }}>
          <NumberInput min={0} max={10000} step={100} value={String(c.Cooldown ?? 1500)}
            onChange={numUpdate(update, 'ChargeWeapon.Cooldown', 1500, true)} />
        </FieldBlock>
        <FieldBlock label="Hearing Distance (m)" hint="How far others see/hear it." style={{ marginBottom: 0 }}>
          <NumberInput min={1} max={100} step={1} value={String(c.MaxDistance ?? 20)}
            onChange={numUpdate(update, 'ChargeWeapon.MaxDistance', 20)} />
        </FieldBlock>
      </Grid2>
    </Section>
  )
}

/** Weapon Weight — carry penalty preset. */
const WEIGHT_MODES = [
  { value: 'off', label: 'Off' },
  { value: 'light', label: 'Light' },
  { value: 'medium', label: 'Medium' },
  { value: 'heavy', label: 'Heavy' },
  { value: 'custom', label: 'Custom' },
]
export function WeightSection({ config, update }: SectionProps) {
  const w = config.WeaponWeight ?? {}
  const isCustom = w.Mode === 'custom'
  return (
    <Section icon="layers" title="WEAPON WEIGHT" sub="Carrying many weapons slows the player."
      action={<ToggleRow.Inline checked={!!w.Enabled} onChange={(v) => update('WeaponWeight.Enabled', v)} />}>
      <FieldBlock label="Penalty Preset" hint='How marked the slowdown is. "Custom" uses the values below.'>
        <Segmented value={w.Mode ?? 'light'} options={WEIGHT_MODES} onChange={(v) => update('WeaponWeight.Mode', v)} />
      </FieldBlock>
      {isCustom && (
        <Grid2>
          <FieldBlock label="Threshold" hint="No penalty up to N weapons." style={{ marginBottom: 0 }}>
            <NumberInput min={0} max={20} step={1} value={String(w.Threshold ?? 2)}
              onChange={numUpdate(update, 'WeaponWeight.Threshold', 2, true)} />
          </FieldBlock>
          <FieldBlock label="Per Weapon" hint="Speed cut per extra weapon (0.03 = 3%)." style={{ marginBottom: 0 }}>
            <NumberInput min={0} max={1} step={0.01} value={String(w.PerWeapon ?? 0.03)}
              onChange={numUpdate(update, 'WeaponWeight.PerWeapon', 0.03)} />
          </FieldBlock>
          <FieldBlock label="Max Penalty" hint="Cap on total slowdown (0.18 = 82% speed)." style={{ marginBottom: 0 }}>
            <NumberInput min={0} max={0.9} step={0.01} value={String(w.MaxPenalty ?? 0.18)}
              onChange={numUpdate(update, 'WeaponWeight.MaxPenalty', 0.18)} />
          </FieldBlock>
        </Grid2>
      )}
    </Section>
  )
}
