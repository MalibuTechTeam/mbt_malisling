import { useState } from 'react'
import { Section, FieldBlock, Grid2, ToggleRow, type SectionProps } from './parts'
import { Segmented } from '../ui/Segmented'
import { Select } from '../ui/Select'
import { Icon } from '../ui/Icon'

/** Weapon prop position editor — picks a type/job/gender then opens the live editor. */

export interface Job { name: string; label: string }
export interface EditTarget { wtype: string; job: string; gender: string }

const WTYPES = [
  { v: 'back', l: 'Rifle / Long gun' },
  { v: 'back2', l: 'Heavy / Launcher' },
  { v: 'side', l: 'Pistol' },
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

/** Tactical Sling — on/off toggle + per-gender live position editor (same editor as weapons). */
export function SlingPositionsSection({ config, update, onEdit }: SectionProps & { onEdit: (gender: string) => void }) {
  const t = config?.TacticalSling ?? {}
  const ty = t.Types ?? {}
  const [gender, setGender] = useState('male')
  return (
    <Section icon="layers" title="TACTICAL SLING" sub="Visible strap on the back while a long gun is slung."
      action={
        <span className="mbt-section__action-row">
          <button type="button" className="mbt-btn-primary mbt-btn--sm" onClick={() => onEdit(gender)}
            disabled={!t.Enabled} title={t.Enabled ? '' : 'Enable the sling first'}>
            <Icon name="configure" size={13} /> Live Editor
          </button>
          <ToggleRow.Inline label="Sling" checked={!!t.Enabled} onChange={(v) => update('TacticalSling.Enabled', v)} />
        </span>
      }>
      <div className="mbt-notice">
        Toggle on, pick the <b>variant</b> and which weapons show it, then <b>Live Editor</b> to place the strap
        per gender — same editor as the weapons. Saving applies live.
      </div>
      <Grid2>
        <FieldBlock label="Variant" hint="Strap prop colour.">
          <Select value={t.Variant ?? 'normal'} aria-label="Sling variant"
            onChange={(v) => update('TacticalSling.Variant', v)}
            options={[{ value: 'normal', label: 'Normal' }, { value: 'camo', label: 'Camo' }]} />
        </FieldBlock>
        <FieldBlock label="Gender" hint="Which offset to edit.">
          <Segmented value={gender} options={GENDERS} onChange={setGender} />
        </FieldBlock>
      </Grid2>
      <FieldBlock label="Show On" hint="Which slung weapons display the strap." style={{ marginBottom: 0 }}>
        <Grid2>
          <ToggleRow title="Rifles / Long guns" checked={!!ty.back}
            onChange={(v) => update('TacticalSling.Types.back', v)} />
          <ToggleRow title="Heavy / Launchers" checked={!!ty.back2}
            onChange={(v) => update('TacticalSling.Types.back2', v)} />
        </Grid2>
      </FieldBlock>
    </Section>
  )
}
