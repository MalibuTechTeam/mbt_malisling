import { useState } from 'react'
import { Section, ToggleRow, FieldBlock, Grid2, type SectionProps, withMeta } from './parts'
import { NumberInput } from '../ui/NumberInput'
import { Segmented } from '../ui/Segmented'
import { Select } from '../ui/Select'
import { Icon } from '../ui/Icon'

const numUpdate = (update: SectionProps['update'], path: string, def: number, int = false) =>
  (raw: string) => update(path, raw === '' ? def : (int ? parseInt(raw, 10) : parseFloat(raw)) || def)

/** Jamming — durability-based weapon jams + unjam minigame. */
export function JammingSection({ config, update }: SectionProps) {
  const j = config.Jamming ?? {}
  return (
    <Section icon="configure" title="WEAPON JAMMING" sub="Worn weapons jam; clear with a key minigame."
      action={<ToggleRow.Inline checked={!!j.Enabled} onChange={(v) => update('Jamming.Enabled', v)} />}>
      <Grid2>
        <FieldBlock label="Jam Cooldown (s)" hint="Minimum time between jams." style={{ marginBottom: 0 }}>
          <NumberInput min={1} max={120} step={1} value={String(j.Cooldown ?? 5)}
            onChange={numUpdate(update, 'Jamming.Cooldown', 5, true)} />
        </FieldBlock>
        <FieldBlock label="Unjam Presses" hint="Key presses to clear a jam." style={{ marginBottom: 0 }}>
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
    <Section icon="flame" title="SUPPRESSOR HEAT" sub="Glows orange→red during sustained fire."
      action={<ToggleRow.Inline checked={!!s.Enabled} onChange={(v) => update('SuppressorHeat.Enabled', v)} />}>
      <FieldBlock label="Render Mode" hint="Glow = no wall reflection · Light = lights the surroundings · Particle = heat haze.">
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
    <Section icon="lock" title="WEAPON SAFETY" sub="Block fire on the held firearm; aim still allowed."
      action={<ToggleRow.Inline checked={!!s.Enabled} onChange={(v) => update('Safety.Enabled', v)} />}>
      <ToggleRow title="Default On" desc="Newly drawn weapons start safetied"
        checked={!!s.DefaultOn} onChange={(v) => update('Safety.DefaultOn', v)} />
      <ToggleRow title="Per-Weapon State" desc="Each weapon remembers its own safety, by serial"
        checked={!!s.PerWeapon} onChange={(v) => update('Safety.PerWeapon', v)} />
      <ToggleRow title="HUD Indicator" desc="Show the SAFE/FIRE pill while a firearm is held"
        checked={!!s.HudIndicator} onChange={(v) => update('Safety.HudIndicator', v)} />
      <ToggleRow title="Condition Pips" desc="Show condition (tier 1-5) next to SAFE/FIRE"
        checked={!!c.Enabled} onChange={(v) => update('ConditionHUD.Enabled', v)} />
    </Section>
  )
}

/** Charge Weapon — rack-the-slide intimidation gesture. */
export function ChargeSection({ config, update }: SectionProps) {
  const c = config.ChargeWeapon ?? {}
  return (
    <Section icon="target" title="CHARGE WEAPON" sub="Rack-the-slide intimidation (anim + sound nearby)."
      action={<ToggleRow.Inline checked={!!c.Enabled} onChange={(v) => update('ChargeWeapon.Enabled', v)} />}>
      <Grid2>
        <FieldBlock label="Cooldown (ms)" hint="Anti-spam between racks." style={{ marginBottom: 0 }}>
          <NumberInput min={0} max={10000} step={100} value={String(c.Cooldown ?? 1500)}
            onChange={numUpdate(update, 'ChargeWeapon.Cooldown', 1500, true)} />
        </FieldBlock>
        <FieldBlock label="Hearing Distance (m)" hint="How far players see and hear it." style={{ marginBottom: 0 }}>
          <NumberInput min={1} max={100} step={1} value={String(c.MaxDistance ?? 20)}
            onChange={numUpdate(update, 'ChargeWeapon.MaxDistance', 20)} />
        </FieldBlock>
      </Grid2>
    </Section>
  )
}

/** Weapon Weight — carry penalty preset. */
// 'off' intentionally omitted — the section's Enable toggle turns the feature off
// (an 'off' preset would just duplicate that). Kept valid in config.lua/validate.
const WEIGHT_MODES = [
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
          <FieldBlock label="Threshold" hint="Weapons carried before the slowdown starts." style={{ marginBottom: 0 }}>
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

/** Low Ready — drop a slung long gun to a chest-carry stance (keybind, default HOME). */
export function LowReadySection({ config, update }: SectionProps) {
  const l = config.LowReady ?? {}
  const ty = l.Types ?? {}
  return (
    <Section icon="target" title="LOW READY" sub="A long gun rests across the chest instead of the back (key HOME)."
      action={<ToggleRow.Inline checked={!!l.Enabled} onChange={(v) => update('LowReady.Enabled', v)} />}>
      <FieldBlock label="Eligible Weapons" hint="Which slung long guns can drop to the chest stance."
        style={{ marginBottom: 0 }}>
        <Grid2>
          <ToggleRow title="Rifles" checked={!!ty.back} onChange={(v) => update('LowReady.Types.back', v)} />
          <ToggleRow title="Heavy" checked={!!ty.back2} onChange={(v) => update('LowReady.Types.back2', v)} />
        </Grid2>
      </FieldBlock>
    </Section>
  )
}

/**
 * DRAW STYLE — which gesture the character uses to reach for the weapon.
 *
 * The options come from the server (`DrawStyles`, derived from default.lua on every
 * snapshot), not from a list in here: styles are config, and a server that adds one should
 * see it in this dropdown without the panel being taught about it.
 *
 * Named DRAW STYLE and not "preset" on purpose — mbt_shooting already ships presets
 * (`balanced_rp`), and they are combat behaviour. An owner running both would otherwise find
 * two cards with the same word meaning opposite things.
 */
export function DrawStyleSection({ config, update, openGesture, jobs = [] }: SectionProps) {
  const styles: { id: string; label: string }[] =
    Array.isArray(config.DrawStyles) && config.DrawStyles.length
      ? config.DrawStyles
      : [{ id: 'standard', label: 'Standard' }]
  const styleOpts = styles.map((s) => ({ value: s.id, label: s.label }))
  const styleLabel = (id: string) => styles.find((s) => s.id === id)?.label ?? id

  // Jobs come from the dashboard — see SectionProps.jobs.
  const jobLabel = (name: string) => jobs.find((j) => j.name === name)?.label ?? name

  // A Lua empty table serialises to a JSON array; coerce so we always write an object
  // (a string key on an array breaks both dirty-detection and persistence).
  const byJob: Record<string, string> =
    config.DrawStyleByJob && !Array.isArray(config.DrawStyleByJob) ? config.DrawStyleByJob : {}
  const setJobStyle = (job: string, id: string) => {
    const next = { ...byJob }
    if (id) next[job] = id
    else delete next[job]
    update('DrawStyleByJob', next)   // write the whole map, never a per-key path
  }
  const rules = Object.entries(byJob).filter(([, id]) => id)
  const used = new Set(rules.map(([j]) => j))
  const freeJobs = jobs.filter((j) => !used.has(j.name))

  const [newJob, setNewJob] = useState('')
  const [newStyle, setNewStyle] = useState(styles[0]?.id ?? 'standard')
  const addJob = newJob || freeJobs[0]?.name

  /**
   * Whether more than one style is genuinely in play.
   *
   * With no per-job rules there is exactly one, so every control that asks WHICH is a choice
   * between a thing and itself — and asking anyway is what produced the failure this card was
   * built to avoid: an admin edited a style the server did not draw with, the save worked
   * perfectly, and nothing changed in game. Five concepts to change one animation.
   *
   * The card no longer asks at all. The picker asks, when there is something to ask.
   */
  const multiStyle = rules.length > 0
  // How many slots the ACTIVE style has had re-picked in-world. Shown so an owner can tell a
  // style they have tuned from one still on its shipped clips.
  const ov = config.DrawStyleOverrides && !Array.isArray(config.DrawStyleOverrides)
    ? config.DrawStyleOverrides : {}
  const tuned = Object.keys(ov[config.DrawStyle ?? 'standard'] ?? {}).length

  return (
    <Section icon="pose" title="DRAW STYLE" sub="How the character reaches for the weapon."
      // The primary action in the header, like every other card on this page: Weapon Positions
      // and Tactical Sling both put their Live Editor here. It used to sit in the middle of the
      // body, where the one thing this card is for read as the third of three settings.
      action={openGesture ? (
        <button type="button" className="mbt-btn-primary mbt-btn--sm"
          onClick={() => openGesture(config.DrawStyle ?? 'standard')}>
          <Icon name="cursor" size={13} /> Live Picker
        </button>
      ) : undefined}>
      {/* No standing notice here. The button is in the header where the eye lands first, the
          sub-line under the title already says what the card is for, and the overlay explains
          itself the moment it opens — a third telling costs 60px of card and repeats twice. */}
      <FieldBlock label="Default Style"
        hint={`Used by every job without a rule below. Takes effect without a restart. ${
          tuned > 0
            ? `${tuned} slot${tuned > 1 ? 's' : ''} re-picked in the editor.`
            : 'Still on its shipped clips.'}`}>
        <Select value={config.DrawStyle ?? 'standard'} aria-label="Draw style"
          onChange={(v) => update('DrawStyle', v)} options={styleOpts} />
      </FieldBlock>
      {/* The gesture picker. Not a dropdown of clip names, because a gesture cannot be chosen
          from its name — 'reaction@intimidation@1h / intro' is a man threatening someone and it
          is what the pistol slot ships with. You have to watch it. */}
      {/* No "which style does the picker write to" control here any more. That choice belongs
          to the picker, next to "which slot" — it is the picker's scope, not a property of this
          card, and having it here is what let an admin edit one style while the server drew
          with another. It appears inside the overlay, and only when a per-job rule makes two
          styles genuinely live. */}
      <FieldBlock label="Per-Job Style" hint="Override the gesture for specific jobs."
        style={{ marginBottom: 0 }}>
        {rules.length > 0 && (
          <div className="mbt-trunk-list">
            {rules.map(([job, id]) => (
              <div key={job} className="mbt-trunk-row">
                <span className="mbt-trunk-row__info">
                  <span className="mbt-trunk-row__nm">{jobLabel(job)}</span>
                  <span className="mbt-trunk-row__coords">→ {styleLabel(id)}</span>
                </span>
                <button type="button" className="mbt-btn-ghost"
                  onClick={() => setJobStyle(job, '')}>Remove</button>
              </div>
            ))}
          </div>
        )}
        {freeJobs.length > 0 && (
          <Grid2>
            <Select value={addJob} aria-label="Job" onChange={setNewJob}
              options={freeJobs.map((j) => ({ value: j.name, label: j.label }))} />
            <span className="mbt-section__action-row">
              <Select value={newStyle} aria-label="Style for job" onChange={setNewStyle} options={styleOpts} />
              <button type="button" className="mbt-btn-ghost"
                onClick={() => addJob && setJobStyle(addJob, newStyle)}>Add</button>
            </span>
          </Grid2>
        )}
      </FieldBlock>
      {/* Only worth saying once a job rule exists. Until then "a style cannot change how long
          the draw takes" is an answer to a question nobody has asked yet, sitting under a card
          whose whole job is to be simple. */}
      {multiStyle && (
        <div className="mbt-notice">
          The gesture only. A style <b>cannot</b> change how long the draw takes — that is the
          slot's, so a job never draws faster than another. Add your own in{' '}
          <code>default.lua</code> (<code>MBT.DrawStyles</code>): a style overrides only the
          slots it names.
        </div>
      )}
    </Section>
  )
}

withMeta(DrawStyleSection, { label: 'Draw Style' })
withMeta(SuppressorSection, { label: 'Suppressor Heat', path: 'SuppressorHeat.Enabled' })
// Condition Pips has no card of its own — it renders inside Weapon Safety, beside SAFE/FIRE.
// Listing it as a peer was what sent owners looking for a card that does not exist.
withMeta(SafetySection, {
  label: 'Weapon Safety', path: 'Safety.Enabled',
  also: [{ label: 'Condition Pips', path: 'ConditionHUD.Enabled' }],
})
withMeta(JammingSection, { label: 'Weapon Jamming', path: 'Jamming.Enabled' })
withMeta(ChargeSection, { label: 'Charge Weapon', path: 'ChargeWeapon.Enabled' })
withMeta(WeightSection, { label: 'Weapon Weight', path: 'WeaponWeight.Enabled' })
withMeta(LowReadySection, { label: 'Low Ready', path: 'LowReady.Enabled' })
