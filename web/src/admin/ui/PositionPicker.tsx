/**
 * PositionPicker — HUD prompt position as a compact 2×2 button grid
 * (Bottom Center / Top Center / Bottom Right / Custom). Two rows fit the card
 * width without the long labels overflowing a single segmented row.
 */

interface Props {
  value: string
  onChange: (v: string) => void
}

// `soon` options are inert teasers — the live drag-to-place HUD editor behind
// "Custom" ships in v2.1; the button is shown (so the capability is visible) but
// disabled until then.
const OPTIONS: { value: string; label: string; soon?: boolean }[] = [
  { value: 'bottom-center', label: 'Bottom Center' },
  { value: 'top-center',    label: 'Top Center' },
  { value: 'bottom-right',  label: 'Bottom Right' },
  { value: 'custom',        label: 'Custom', soon: true },
]

export function PositionPicker({ value, onChange }: Props) {
  return (
    <div className="mbt-pospick">
      {OPTIONS.map((o) => (
        <button
          key={o.value}
          type="button"
          disabled={o.soon}
          aria-disabled={o.soon || undefined}
          title={o.soon ? 'Live drag-to-place HUD editor — coming in v2.1' : undefined}
          className={`mbt-pospick__btn${value === o.value && !o.soon ? ' is-on' : ''}${o.soon ? ' is-soon' : ''}`}
          onClick={() => { if (!o.soon) onChange(o.value) }}
        >
          {o.label}
          {o.soon && <span className="mbt-pospick__soon">2.1</span>}
        </button>
      ))}
    </div>
  )
}

export default PositionPicker
