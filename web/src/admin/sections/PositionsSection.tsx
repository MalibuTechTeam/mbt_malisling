import { useState } from 'react'
import { Section, FieldBlock, Grid2 } from './parts'
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
      sub="Where each weapon sits on the body — per type & job."
      action={
        <button className="mbt-btn-primary mbt-btn--sm" onClick={() => onEdit({ wtype, job, gender })}>
          <Icon name="cursor" size={13} /> Live Editor
        </button>
      }>
      <div className="mbt-notice">
        Pick a <b>type</b>, <b>job</b> and <b>gender</b>, then hit <b>Live Editor</b> — the dashboard hides and you
        place the weapon in 3D. Saving applies live to every player. Requires <code>oxmysql</code> to persist.
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
