import { useState } from 'react'
import { Section, FieldBlock, Grid2, ToggleRow, type SectionProps } from './parts'
import { Segmented } from '../ui/Segmented'
import { Select } from '../ui/Select'
import { Icon } from '../ui/Icon'

/** Weapon prop position editor — picks a type/job/gender then opens the live editor. */

export interface Job { name: string; label: string }
export interface EditTarget { wtype: string; job: string; gender: string }

// The '#n' entries are the extra multi-weapon lanes: ordinary positions with their own key,
// edited exactly like the first one. They are listed next to the slot they belong to rather
// than in a section of their own — you place a second rifle by thinking about the back, not
// about lanes. Which of them exist is decided in default.lua (LaneOffsets): a slot without
// one simply never draws a second weapon.
const WTYPES = [
  { v: 'back', l: 'Rifle / Long gun' },
  { v: 'back#2', l: 'Rifle / Long gun — 2nd' },
  { v: 'back2', l: 'Heavy / Launcher' },
  { v: 'side', l: 'Pistol' },
  { v: 'side#2', l: 'Pistol — 2nd' },
  { v: 'melee', l: 'Melee' },
  { v: 'melee2', l: 'Knife' },
  { v: 'melee3', l: 'Hatchet / Alt melee' },
  { v: 'extinguisher', l: 'Fire extinguisher' },
  { v: 'sling', l: 'Tactical Sling (strap)' },
]
const GENDERS = [
  { value: 'male', label: 'Male' },
  { value: 'female', label: 'Female' },
]

export function PositionsSection({ jobs, onEdit }: { jobs: Job[]; onEdit: (t: EditTarget) => void }) {
  const [wtype, setWtype] = useState('back')
  const [job, setJob] = useState('default')
  const [gender, setGender] = useState('male')
  return (
    <Section icon="configure" title="WEAPON POSITIONS"
      sub="Where each weapon sits on the body, per type and job."
      action={
        <button className="mbt-btn-primary mbt-btn--sm" onClick={() => onEdit({ wtype, job, gender })}>
          <Icon name="cursor" size={13} /> Live Editor
        </button>
      }>
      <div className="mbt-notice">
        Pick a <b>type</b>, <b>job</b> and <b>gender</b>, then hit <b>Live Editor</b> — the dashboard hides and you
        place the weapon in 3D. Saving applies live to all players. Requires <code>oxmysql</code> to persist.
      </div>
      <Grid2>
        <FieldBlock label="Weapon Type" hint="Which prop type to position.">
          <Select value={wtype} aria-label="Weapon type" onChange={setWtype}
            options={WTYPES.map((t) => ({ value: t.v, label: t.l }))} />
        </FieldBlock>
        <FieldBlock label="Job" hint="Default applies to everyone; a job overrides it for that job.">
          <Select value={job} aria-label="Job" onChange={setJob}
            options={[{ value: 'default', label: 'Default (everyone)' },
              ...jobs.map((j) => ({ value: j.name, label: j.label }))]} />
        </FieldBlock>
      </Grid2>
      <FieldBlock label="Gender" hint="Edit the male or female offset (you can copy one to the other).">
        <Segmented value={gender} options={GENDERS} onChange={setGender} />
      </FieldBlock>
    </Section>
  )
}

/** Tactical Sling — on/off + variant selection (default + per-job) + per-variant live editor. */
export function SlingPositionsSection(
  { config, update, onEdit, jobs }: SectionProps & { onEdit: (variant: string, gender: string) => void; jobs: Job[] }
) {
  const t = config?.TacticalSling ?? {}
  const ty = t.Types ?? {}
  const variants: { id: string; label: string }[] = t.Variants?.length ? t.Variants : [{ id: 'normal', label: 'Normal' }]
  const variantOpts = variants.map((v) => ({ value: v.id, label: v.label }))
  const variantLabel = (id: string) => variants.find((v) => v.id === id)?.label ?? id
  const jobLabel = (name: string) => jobs.find((j) => j.name === name)?.label ?? name
  // A Lua empty table serialises to a JSON array; coerce so we always work with an object
  // (writing a string key onto an array breaks JSON.stringify dirty-detection + persistence).
  const jobVariants: Record<string, string> =
    t.JobVariants && !Array.isArray(t.JobVariants) ? t.JobVariants : {}
  const setJobVariant = (job: string, vid: string) => {
    const next: Record<string, string> = { ...jobVariants }
    if (vid) next[job] = vid
    else delete next[job]
    update('TacticalSling.JobVariants', next)   // write the whole object, never a per-key path
  }
  const overrides = Object.entries(jobVariants).filter(([, vid]) => vid)
  const used = new Set(overrides.map(([j]) => j))
  const freeJobs = jobs.filter((j) => !used.has(j.name))

  const [gender, setGender] = useState('male')
  const [editVariant, setEditVariant] = useState(variants[0]?.id ?? 'normal')
  const [newJob, setNewJob] = useState('')
  const [newVariant, setNewVariant] = useState(variants[0]?.id ?? 'normal')
  const addJob = newJob || freeJobs[0]?.name

  return (
    <Section icon="layers" title="TACTICAL SLING" sub="Visible strap on the back while a long gun is slung."
      action={
        <span className="mbt-section__action-row">
          <button type="button" className="mbt-btn-primary mbt-btn--sm" onClick={() => onEdit(editVariant, gender)}
            disabled={!t.Enabled} title={t.Enabled ? '' : 'Enable the sling first'}>
            <Icon name="configure" size={13} /> Live Editor
          </button>
          <ToggleRow.Inline label="Sling" checked={!!t.Enabled} onChange={(v) => update('TacticalSling.Enabled', v)} />
        </span>
      }>
      <div className="mbt-notice">
        Each variant is a separate prop with its own position. Pick a <b>variant + gender</b> and hit <b>Live Editor</b>
        to place it; set the default and per-job variants below. Saving applies live.
      </div>
      <Grid2>
        <FieldBlock label="Edit Variant" hint="Which variant the Live Editor positions.">
          <Select value={editVariant} aria-label="Edit variant" onChange={setEditVariant} options={variantOpts} />
        </FieldBlock>
        <FieldBlock label="Gender" hint="Which offset to edit.">
          <Segmented value={gender} options={GENDERS} onChange={setGender} />
        </FieldBlock>
      </Grid2>
      <Grid2>
        <FieldBlock label="Default Variant" hint="Worn by jobs without an override below.">
          <Select value={t.DefaultVariant ?? variants[0]?.id} aria-label="Default variant"
            onChange={(v) => update('TacticalSling.DefaultVariant', v)} options={variantOpts} />
        </FieldBlock>
        <FieldBlock label="Show On" hint="Which slung weapons display the strap.">
          <Grid2>
            <ToggleRow title="Rifles" checked={!!ty.back} onChange={(v) => update('TacticalSling.Types.back', v)} />
            <ToggleRow title="Heavy" checked={!!ty.back2} onChange={(v) => update('TacticalSling.Types.back2', v)} />
          </Grid2>
        </FieldBlock>
      </Grid2>
      <FieldBlock label="Per-Job Variant" hint="Override the variant for specific jobs." style={{ marginBottom: 0 }}>
        {overrides.length > 0 && (
          <div className="mbt-trunk-list">
            {overrides.map(([job, vid]) => (
              <div key={job} className="mbt-trunk-row">
                <span className="mbt-trunk-row__info">
                  <span className="mbt-trunk-row__nm">{jobLabel(job)}</span>
                  <span className="mbt-trunk-row__coords">→ {variantLabel(vid)}</span>
                </span>
                <button type="button" className="mbt-btn-ghost"
                  onClick={() => setJobVariant(job, '')}>Remove</button>
              </div>
            ))}
          </div>
        )}
        {freeJobs.length > 0 && (
          <Grid2>
            <Select value={addJob} aria-label="Job" onChange={setNewJob}
              options={freeJobs.map((j) => ({ value: j.name, label: j.label }))} />
            <span className="mbt-section__action-row">
              <Select value={newVariant} aria-label="Variant for job" onChange={setNewVariant} options={variantOpts} />
              <button type="button" className="mbt-btn-ghost"
                onClick={() => addJob && setJobVariant(addJob, newVariant)}>Add</button>
            </span>
          </Grid2>
        )}
      </FieldBlock>
    </Section>
  )
}
