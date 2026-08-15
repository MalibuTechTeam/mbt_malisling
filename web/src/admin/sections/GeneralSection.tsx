import { useEffect, useState, type CSSProperties } from 'react'
import { PositionPicker } from '../ui/PositionPicker'
import { Segmented } from '../ui/Segmented'
import { NumberInput } from '../ui/NumberInput'
import { Icon } from '../ui/Icon'
import { Select } from '../ui/Select'
import { fetchNui } from '../../utils/fetchNui'
import { ColorPicker } from '../ui/ColorPicker'
import { accentContrast, accentTokens, isHexColor, DEFAULT_ACCENT, MIN_CONTRAST } from '../../utils/accent'
import { Section, ToggleRow, FieldBlock, type SectionProps } from './parts'
import type { Job } from './PositionsSection'

/**
 * Core category — split into atomic cards so the category page can order them
 * freely (CoreSection and InterfaceSection are placed separately in the grid).
 */

/** CORE — core sling toggles (runtime-safe; Debug stays in config.lua). */
export function CoreSection({ config, update }: SectionProps) {
  return (
    <Section icon="power" title="CORE" sub="Whether weapons show on the body at all.">
      <ToggleRow title="Enable Sling" desc="Show the weapon on the player's body"
        checked={!!config.EnableSling} onChange={(v) => update('EnableSling', v)} />
      <ToggleRow title="Enable Flashlight" desc="A slung weapon's torch stays lit if it was on"
        checked={!!config.EnableFlashlight} onChange={(v) => update('EnableFlashlight', v)} />
      <ToggleRow title="Holster Confirm" desc="Ask before a drawn sidearm reaches the hand — the draw animation plays either way"
        checked={!!config.HolsterConfirm} onChange={(v) => update('HolsterConfirm', v)} />
      <ToggleRow title="Drop Weapon on Death" desc="The weapon in hand falls where the player died"
        checked={!!config.DropWeaponOnDeath} onChange={(v) => update('DropWeaponOnDeath', v)} />
    </Section>
  )
}

/** MULTI-WEAPON — more than one weapon visible in the same body slot.
 *  Off by default: the slots are body positions, not weapon families, so turning this on
 *  changes what every player looks like. */
export function MultiWeaponSection({ config, update }: SectionProps) {
  const mw = config.MultiWeaponVisibility ?? {}
  return (
    <Section icon="power" title="MULTI-WEAPON" sub="More than one weapon in the same body slot.">
      <ToggleRow title="Show Multiple Weapons"
        desc="A rifle and a shotgun share the back slot — off, only one of them shows"
        checked={!!mw.Enabled} onChange={(v) => update('MultiWeaponVisibility.Enabled', v)} />
      <FieldBlock label="Max Per Slot"
        hint="Distinct weapons drawn per slot. Copies of the same model share one prop; the rest are still tracked."
        disabled={!mw.Enabled} style={{ marginBottom: 0 }}>
        <NumberInput min={1} max={4} step={1} value={String(mw.MaxPerType ?? 2)}
          onChange={(raw) => update('MultiWeaponVisibility.MaxPerType', raw === '' ? 2 : parseInt(raw, 10) || 2)} />
      </FieldBlock>
    </Section>
  )
}

// Offered above the picker's square. Every one of these clears 3:1 against the in-game
// chip, so the short way in is also the safe one — the square is for the case this list
// misses, not the way most owners should have to get there.
const ACCENT_PRESETS = [
  DEFAULT_ACCENT, // MalibuTech green
  '#40C4FF',      // ice blue
  '#FFB300',      // amber
  '#FF5252',      // red
  '#B388FF',      // violet
  '#E0E0E0',      // neutral, for servers that want no colour at all
]

/** INTERFACE — HUD prompt position (3 presets), style and brand accent. "Custom"
 *  placement (a live drag-to-place HUD editor) is reserved for v2.1; the picker shows
 *  it disabled with a badge. */
export function InterfaceSection({ config, update }: SectionProps) {
  const pos = config.UIPosition ?? 'bottom-center'
  const accent = isHexColor(config.Accent) ? config.Accent : DEFAULT_ACCENT
  const ratio = accentContrast(accent)

  // The hex field is typed one character at a time, so it can't be driven straight off
  // the config: committing only valid hex would freeze the input the moment you delete
  // a digit. The draft holds the half-typed value; config only sees complete ones.
  const [hexDraft, setHexDraft] = useState(accent)
  useEffect(() => { setHexDraft(accent) }, [accent])

  // Reset arms on the first click and commits on the second, disarming itself after 4s:
  // this control throws away a colour someone tuned, and it sits next to the field they
  // tuned it in.
  const [armed, setArmed] = useState(false)
  useEffect(() => {
    if (!armed) return
    const t = window.setTimeout(() => setArmed(false), 4000)
    return () => window.clearTimeout(t)
  }, [armed])

  return (
    <Section icon="grid" title="INTERFACE" sub="Prompt placement, style and brand colour.">
      <FieldBlock label="Prompt Style" hint="Standard sits in a fixed spot on screen · Cinematic appears beside the weapon.">
        <Segmented
          value={config.UIStyle ?? 'standard'}
          onChange={(v) => update('UIStyle', v)}
          options={[{ value: 'standard', label: 'Standard' }, { value: 'cinematic', label: 'Cinematic' }]}
        />
      </FieldBlock>
      <FieldBlock label="Brand Accent"
        hint="Your server's colour on the prompts players see. This dashboard is the MalibuTech panel and keeps its own green.">
        {/* A sample of the real thing rather than a swatch: the accent lands on a prompt
            chip over dark gameplay, and a square of colour on a bright card tells you
            nothing about whether it will read there. Tokens are set inline so this one
            element previews the DRAFT while everything around it stays brand-coloured. */}
        <div className="mbt-accent-preview cine-chip" style={accentTokens(accent) as CSSProperties}>
          <span className="mbt-kc">R</span>
          <span className="mbt-accent-preview__label">Holster weapon</span>
          <span className="mbt-accent-preview__dot" />
        </div>
        <div className="mbt-accent-row">
          <ColorPicker value={accent} aria-label="Brand accent colour" presets={ACCENT_PRESETS}
            onChange={(hex) => update('Accent', hex)}
            footer={
              <span className={`mbt-cp-ratio${ratio < MIN_CONTRAST ? ' is-low' : ''}`}>
                <b>{ratio.toFixed(1)}:1</b> on the in-game prompt
              </span>
            } />
          <input type="text" className="mbt-input mbt-accent-hex" value={hexDraft} maxLength={7}
            spellCheck={false} aria-label="Brand accent hex value" placeholder={DEFAULT_ACCENT}
            onChange={(e) => {
              const v = e.target.value.trim()
              setHexDraft(v)
              if (isHexColor(v)) update('Accent', v.toUpperCase())
            }}
            onBlur={() => setHexDraft(accent)} />
          <button type="button" className={`mbt-btn-ghost mbt-btn--sm${armed ? ' is-armed' : ''}`}
            onClick={() => {
              if (!armed) { setArmed(true); return }
              setArmed(false)
              update('Accent', DEFAULT_ACCENT)
            }}>
            {armed ? 'Confirm reset' : 'Reset'}
          </button>
        </div>
      </FieldBlock>
      {ratio < MIN_CONTRAST && (
        <div className="mbt-notice mbt-notice--warn" role="alert">
          <Icon name="alert" size={15} />
          <span>
            Hard to read — this colour scores <b>{ratio.toFixed(2)}:1</b> against the in-game prompt, under the
            {' '}{MIN_CONTRAST}:1 minimum. Players will struggle to make out keycaps and highlights. Saving is still allowed.
          </span>
        </div>
      )}
      <PositionPicker value={pos} onChange={(v) => update('UIPosition', v)} />
      {pos === 'custom' && (
        <p className="mbt-field__hint" style={{ marginTop: 8 }}>
          Custom placement — a live drag-to-place editor — ships in v2.1; using a default spot for now.
        </p>
      )}
    </Section>
  )
}

// What each stock slot actually holds, for the chip tooltips. The chip itself shows the RAW
// slot key: that is the name in config.lua and in a support thread, and a server that added
// its own type gets it listed without an entry here.
const SLOT_HINT: Record<string, string> = {
  side: 'Pistols',
  back: 'Rifles and long guns',
  back2: 'Heavy weapons and launchers',
  melee: 'Melee',
  melee2: 'Knives',
  melee3: 'Hatchets and alternate melee',
  extinguisher: 'Fire extinguisher',
}

/** HIDDEN BY JOB — per-job list of body slots that never get a prop (uniforms that already
 *  model the weapon). Sparse by design: one row per job with exceptions, not a job x slot
 *  matrix, because a server has dozens of jobs and a handful of rules. */
export function HiddenByJobSection({ config, update }: SectionProps) {
  // Slots come from the server's live MBT.PropInfo — a custom type is covered, and the
  // strap / multi-weapon lanes are already filtered out there.
  const slots: string[] = Array.isArray(config?.BodySlots) ? config.BodySlots : []
  // A Lua empty table serialises to a JSON array; coerce so we always work with an object
  // (writing a string key onto an array breaks JSON.stringify dirty-detection + persistence).
  const rules: Record<string, Record<string, boolean>> =
    config?.HiddenByJob && !Array.isArray(config.HiddenByJob) ? config.HiddenByJob : {}

  const [jobs, setJobs] = useState<Job[]>([])
  useEffect(() => { fetchNui('getJobs').then((l: any) => setJobs(Array.isArray(l) ? l : [])) }, [])

  // Two-step restore: the first click arms, the second one fires, and it disarms itself after
  // a few seconds. This control throws away work and sits next to nothing that undoes it.
  const [armed, setArmed] = useState(false)
  useEffect(() => {
    if (!armed) return
    const id = window.setTimeout(() => setArmed(false), 4000)
    return () => window.clearTimeout(id)
  }, [armed])

  const known = new Map(jobs.map((j) => [j.name, j.label]))
  const scopeLabel = (name: string) => (name === '*' ? 'Everyone (*)' : known.get(name) ?? name)
  // Only claim a job is gone once we actually have the list — an empty `jobs` means the
  // framework hasn't answered (or has no jobs), not that every rule is orphaned.
  const isUnknown = (name: string) => name !== '*' && jobs.length > 0 && !known.has(name)

  const entries = Object.entries(rules)
  const used = new Set(entries.map(([j]) => j))
  const free = [{ name: '*', label: 'Everyone (*)' }, ...jobs].filter((j) => !used.has(j.name))
  const [newJob, setNewJob] = useState('')
  const addTarget = free.some((j) => j.name === newJob) ? newJob : free[0]?.name ?? ''

  // The server's slots, plus anything the rule already names that isn't one of them (a slot
  // whose type was removed from MBT.PropInfo). Same reason unknown jobs stay on screen: a rule
  // nobody can see is a rule nobody can delete.
  const rowSlots = (row: Record<string, boolean>) =>
    [...slots, ...Object.keys(row ?? {}).filter((s) => !slots.includes(s))]

  const write = (next: Record<string, Record<string, boolean>>) => update('HiddenByJob', next)
  // A row with no slots hides nothing, so the server drops it on save — which is also what
  // clearing the last chip is meant to do. Until then it stays visible and editable.
  const addRule = () => { if (addTarget && !rules[addTarget]) write({ ...rules, [addTarget]: {} }) }
  const removeRule = (job: string) => { const next = { ...rules }; delete next[job]; write(next) }
  const toggleSlot = (job: string, slot: string) => {
    const row = { ...(rules[job] ?? {}) }
    if (row[slot]) delete row[slot]
    else row[slot] = true
    write({ ...rules, [job]: row })
  }

  return (
    <Section icon="lock" title="HIDDEN BY JOB" sub="Body slots that never show a prop, per job."
      action={
        <button type="button" className={`mbt-btn-ghost is-danger${armed ? ' is-armed' : ''}`}
          title="Drop the saved rules and go back to the ones in config.lua"
          onClick={() => { if (!armed) { setArmed(true); return } setArmed(false); fetchNui('hiddenByJob:restore') }}>
          {armed ? 'Confirm restore' : 'Restore from config.lua'}
        </button>
      }>
      <div className="mbt-notice">
        Police uniforms often have a pistol <b>modelled into the clothing</b> — hide <code>side</code> for that job
        and the officer stops carrying two. Rules are <b>per job, not per outfit</b>. Restoring reloads this
        panel from the server, so save anything else first.
      </div>
      {entries.length === 0 ? (
        <div className="mbt-field__hint" style={{ marginTop: 2, whiteSpace: 'normal' }}>
          No exceptions — every job shows every slot it carries.
        </div>
      ) : (
        <div className="mbt-hbj-list">
          {entries.map(([job, row]) => {
            const mine = rowSlots(row)
            const on = mine.filter((s) => row?.[s])
            return (
              <div key={job} className="mbt-hbj-row">
                <div className="mbt-hbj-row__head">
                  <span className="mbt-trunk-row__nm">{scopeLabel(job)}</span>
                  {isUnknown(job) && (
                    <span className="mbt-trunk-row__tag mbt-hbj-tag--unknown" title="No job by this name — renamed or removed">
                      unknown job
                    </span>
                  )}
                  <span className="mbt-hbj-row__sum">
                    {on.length > 0 ? `→ ${on.join(', ')}` : '→ nothing hidden'}
                  </span>
                  <button type="button" className="mbt-btn-ghost" onClick={() => removeRule(job)}>Remove</button>
                </div>
                <div className="mbt-hbj-chips">
                  {mine.map((s) => (
                    <button key={s} type="button" aria-pressed={!!row?.[s]}
                      className={`mbt-chip${row?.[s] ? ' is-on' : ''}`}
                      title={SLOT_HINT[s] ?? (slots.includes(s) ? s : `${s} — no such slot on this server`)}
                      onClick={() => toggleSlot(job, s)}>{s}</button>
                  ))}
                </div>
              </div>
            )
          })}
        </div>
      )}
      {free.length > 0 && (
        <FieldBlock label="Add Rule" hint="Pick a job, then tick the slots it should never show." style={{ marginBottom: 0 }}>
          <span className="mbt-section__action-row">
            <Select value={addTarget} aria-label="Job to hide slots for" onChange={setNewJob}
              options={free.map((j) => ({ value: j.name, label: j.label }))} />
            <button type="button" className="mbt-btn-ghost" onClick={addRule}>Add</button>
          </span>
        </FieldBlock>
      )}
    </Section>
  )
}
