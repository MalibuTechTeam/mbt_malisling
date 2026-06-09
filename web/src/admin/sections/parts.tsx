import { cloneElement, isValidElement, type ReactNode } from 'react'
import { Icon, type IconName } from '../ui/Icon'
import { Toggle } from '../ui/Toggle'

/** Section panel: bordered card with an icon-box head + body.
 *  `action` renders right-aligned in the head (e.g. a segmented control).
 *  `wide` makes the card span both masonry columns (for wide controls). */
export function Section({ icon, title, sub, action, children, wide }: { icon: IconName; title: string; sub?: string; action?: ReactNode; children?: ReactNode; wide?: boolean }) {
  return (
    <div className={`mbt-section${wide ? ' mbt-section--wide' : ''}`}>
      <div className="mbt-section__head">
        <span className="mbt-section__ic"><Icon name={icon} size={16} /></span>
        <div className="mbt-section__head-tx">
          <h4 className="mbt-section__title">{title}</h4>
          {sub && <p className="mbt-section__sub">{sub}</p>}
        </div>
        {action && (
          <span className="mbt-section__action">
            {/* A header on/off toggle (ToggleRow.Inline) has no label of its own —
                inject the section title so screen readers announce what it controls. */}
            {isValidElement(action) && action.type === ToggleRow.Inline
              ? cloneElement(action as any, { label: (action.props as any).label ?? title })
              : action}
          </span>
        )}
      </div>
      {children && <div className="mbt-section__body">{children}</div>}
    </div>
  )
}

/** A title + description row with a toggle on the right (card style). */
export function ToggleRow({ title, desc, checked, onChange }: { title: string; desc?: string; checked: boolean; onChange: (v: boolean) => void }) {
  return (
    <div className="mbt-setting">
      <div className="mbt-setting__head">
        <div className="mbt-setting__info">
          <span className="mbt-setting__title">{title}</span>
          {desc && <span className="mbt-setting__desc">{desc}</span>}
        </div>
        {/* The visible title isn't tied to the checkbox, so name it for AT. */}
        <Toggle checked={checked} onChange={onChange} aria-label={title} />
      </div>
    </div>
  )
}

/** Bare toggle for a section header (feature on/off, right-aligned). `label` is
 *  the accessible name (the section's feature name) — required so screen readers
 *  announce what the switch controls. */
ToggleRow.Inline = function ToggleRowInline({ checked, onChange, label }: { checked: boolean; onChange: (v: boolean) => void; label?: string }) {
  return <Toggle checked={checked} onChange={onChange} aria-label={label || 'Feature toggle'} />
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

/** Two-column grid wrapper — pack sections side by side (mbt_elevator pattern). */
export function Grid2({ children }: { children: ReactNode }) {
  return <div className="mbt-card-grid mbt-card-grid--2">{children}</div>
}

export interface SectionProps {
  config: any
  update: (path: string, value: unknown) => void
}
