import { useState } from 'react'
import { Section, FieldBlock } from './parts'
import { Segmented } from '../ui/Segmented'
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
      sub="Live-edit where each weapon sits on the body — per type and per job.">
      <FieldBlock label="Weapon Type" hint="Which prop type to position.">
        <select className="mbt-select" value={wtype} onChange={(e) => setWtype(e.target.value)}>
          {WTYPES.map((t) => <option key={t.v} value={t.v}>{t.l}</option>)}
        </select>
      </FieldBlock>
      <FieldBlock label="Job" hint="Default applies to everyone; a job overrides it just for that job.">
        <select className="mbt-select" value={job} onChange={(e) => setJob(e.target.value)}>
          <option value="default">Default (everyone)</option>
          {jobs.map((j) => <option key={j.name} value={j.name}>{j.label}</option>)}
        </select>
      </FieldBlock>
      <FieldBlock label="Gender" hint="Edit the male or female offset (you can copy one to the other).">
        <Segmented value={gender} options={GENDERS} onChange={setGender} />
      </FieldBlock>
      <button className="mbt-btn-primary" style={{ alignSelf: 'flex-start' }}
        onClick={() => onEdit({ wtype, job, gender })}>
        <Icon name="cursor" size={14} /> Open Live Editor
      </button>
      <div className="mbt-field__hint" style={{ marginTop: 2 }}>
        The dashboard hides while you position the weapon in 3D. Saving applies live to every
        player. Requires <code>oxmysql</code> to persist.
      </div>
    </Section>
  )
}
