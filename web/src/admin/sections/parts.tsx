import { cloneElement, isValidElement, type ComponentType, type ReactNode } from 'react'
import { Icon, type IconName } from '../ui/Icon'
import { Toggle } from '../ui/Toggle'

/**
 * What a card declares about itself, so the overview panel can be DERIVED rather than
 * hand-mirrored.
 *
 * There used to be two more lists — a `FEATURES` array and an `OV_CATS` array — maintained
 * by hand alongside `CATEGORIES`. They had already drifted before anybody reorganised
 * anything: Tactical Sling was filed under Core while its card renders on Positions, so the
 * panel told you a feature was on a page it is not; Condition Pips was listed with no card
 * of its own; and the master switch of the entire script, Enable Sling, was missing from a
 * list whose own comment called itself "every on/off toggle". A counter that reads
 * "21 / 26 active" while omitting the thing that turns everything on is worse than no
 * counter.
 *
 * A card is the only place that knows what it contains, so it is the only place that can
 * say so without going stale.
 */
export interface SectionMeta {
  /** Name in the overview list. Not the card title — that shouts in caps. */
  label: string
  /** Config path of the card's own on/off switch. Omitted when it has none (Interface,
   *  Hidden By Job and the position editors are configuration, not features). */
  path?: string
  /** Features this card owns that are not its own switch — Condition Pips lives inside
   *  Weapon Safety, and listing it as a card of its own was the lie. */
  also?: { label: string; path: string }[]
}

/**
 * A section component plus what it declares about itself.
 *
 * Props are `any` rather than `SectionProps` because the Placement page's sections take
 * their own (a job list, editor callbacks) and are listed alongside the rest so the
 * overview can see the features they own. Nothing is lost that was being enforced: the
 * card map already casts each entry to `ComponentType<SectionProps>` before rendering, so
 * the check was nominal there too.
 */
export type SectionComponent = ComponentType<any> & { meta?: SectionMeta }

/** Attach metadata to a section. Returns the same component, so it stays a plain export. */
export function withMeta<T extends ComponentType<any>>(component: T, meta: SectionMeta): T & { meta: SectionMeta } {
  return Object.assign(component, { meta })
}

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

/** A title + description row with a toggle on the right (card style). `disabled` dims the row and
 *  blocks interaction (used when the row depends on a parent toggle being on). */
export function ToggleRow({ title, desc, checked, onChange, disabled }: { title: string; desc?: string; checked: boolean; onChange: (v: boolean) => void; disabled?: boolean }) {
  return (
    <div className={`mbt-setting${disabled ? ' is-disabled' : ''}`} aria-disabled={disabled || undefined}>
      <div className="mbt-setting__head">
        <div className="mbt-setting__info">
          <span className="mbt-setting__title">{title}</span>
          {desc && <span className="mbt-setting__desc">{desc}</span>}
        </div>
        {/* The visible title isn't tied to the checkbox, so name it for AT. */}
        <Toggle checked={checked} onChange={onChange} disabled={disabled} aria-label={title} />
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

/** A labelled field wrapper (label + optional hint + control). `disabled` dims it + blocks input. */
export function FieldBlock({ label, hint, children, style, disabled }: { label: string; hint?: string; children: ReactNode; style?: React.CSSProperties; disabled?: boolean }) {
  return (
    <div className={`mbt-field${disabled ? ' is-disabled' : ''}`} style={style} aria-disabled={disabled || undefined}>
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
