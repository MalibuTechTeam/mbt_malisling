import type { ReactNode } from 'react'
import { Icon, type IconName } from '../ui/Icon'
import { Toggle } from '../ui/Toggle'

/** Section panel: bordered card with an icon-box head + body. */
export function Section({ icon, title, sub, children }: { icon: IconName; title: string; sub?: string; children: ReactNode }) {
  return (
    <div className="mbt-section">
      <div className="mbt-section__head">
        <span className="mbt-section__ic"><Icon name={icon} size={16} /></span>
        <div className="mbt-section__head-tx">
          <h4 className="mbt-section__title">{title}</h4>
          {sub && <p className="mbt-section__sub">{sub}</p>}
        </div>
      </div>
      <div className="mbt-section__body">{children}</div>
    </div>
  )
}

/** A title + description row with a toggle on the right (card style). */
export function ToggleRow({ title, desc, checked, onChange }: { title: string; desc?: string; checked: boolean; onChange: (v: boolean) => void }) {
  return (
    <div className="mbt-setting" style={{ marginBottom: 10 }}>
      <div className="mbt-setting__head">
        <div className="mbt-setting__info">
          <span className="mbt-setting__title">{title}</span>
          {desc && <span className="mbt-setting__desc">{desc}</span>}
        </div>
        <Toggle checked={checked} onChange={onChange} />
      </div>
    </div>
  )
}

/** A labelled field wrapper (label + optional hint + control). */
export function FieldBlock({ label, hint, children, style }: { label: string; hint?: string; children: ReactNode; style?: React.CSSProperties }) {
  return (
    <div className="mbt-field" style={style}>
      <span className="mbt-field__label">{label}</span>
      {children}
      {hint && <p className="mbt-field__hint">{hint}</p>}
    </div>
  )
}

export interface SectionProps {
  config: any
  update: (path: string, value: unknown) => void
}
