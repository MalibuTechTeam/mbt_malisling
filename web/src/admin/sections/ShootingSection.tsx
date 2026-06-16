import { fetchNui } from '../../utils/fetchNui'
import { Icon, type IconName } from '../ui/Icon'

/**
 * ShootingSection — the in-menu upsell / status page for the paid companion
 * (mbt_shooting). When the bridge is connected it flips from "locked add-on"
 * to "active". It names the product (public marketing) but ships none of its
 * logic — consistent with the opaque bridge.
 */

interface ShootFeature { icon: IconName; title: string; desc: string }

const FEATURES: ShootFeature[] = [
  { icon: 'layers',    title: 'Skill Recoil',      desc: 'Per-weapon skill that tames recoil and speeds your draw as you train.' },
  { icon: 'alert',     title: 'Weapon Condition',  desc: 'Real degradation with jam and recoil consequences — clean and maintain your weapons.' },
  { icon: 'alert',     title: 'Malfunctions',      desc: 'Three stoppage types, each with its own tap-rack-bang clearing sequence.' },
  { icon: 'cursor',    title: 'Shooting Range',    desc: 'Game modes, leaderboards and daily challenges to train and compete.' },
  { icon: 'search',    title: 'Crosshair',         desc: 'Per-player crosshair: thickness, length, center gap, color, dot.' },
  { icon: 'help',      title: 'Licensing & Exam',  desc: 'Practical and theory exams, CCW and permits tied to the range.' },
]

export function ShootingSection({ companion }: { companion: boolean }) {
  return (
    <div className="mbt-shoot">
      <div className={`mbt-shoot__hero${companion ? ' is-connected' : ''}`}>
        <span className="mbt-shoot__badge">
          <Icon name={companion ? 'check' : 'layers'} size={13} />
          {companion ? 'Connected' : 'Add-on'}
        </span>
        <h3 className="mbt-shoot__title">mbt_shooting</h3>
        <p className="mbt-shoot__sub">
          {companion
            ? 'Companion connected — these systems are live and driving your weapons through the bridge. Configure them in the mbt_shooting menu.'
            : 'The paid combat layer: skill progression, weapon condition, malfunctions and a full shooting range. malisling stays free and standalone — shooting adds the depth players feel.'}
        </p>
        {!companion && (
          <button type="button" className="mbt-btn-primary" onClick={() => fetchNui('shootingLink')}>
            <Icon name="cursor" size={14} /> Get mbt_shooting
          </button>
        )}
      </div>

      <div className="mbt-shoot__grid">
        {FEATURES.map((f) => (
          <div key={f.title} className={`mbt-shoot__card${companion ? ' is-active' : ' is-locked'}`}>
            <span className="mbt-shoot__ic"><Icon name={f.icon} size={16} /></span>
            <div className="mbt-shoot__cardtx">
              <span className="mbt-shoot__cardtitle">
                {f.title}
                <span className="mbt-shoot__tag">{companion ? 'active' : 'locked'}</span>
              </span>
              <span className="mbt-shoot__carddesc">{f.desc}</span>
            </div>
          </div>
        ))}
      </div>
    </div>
  )
}
