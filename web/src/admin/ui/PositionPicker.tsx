/**
 * PositionPicker — HUD prompt position as a compact 2×2 button grid
 * (Bottom Center / Top Center / Bottom Right / Custom). Two rows fit the card
 * width without the long labels overflowing a single segmented row.
 */

interface Props {
  value: string
  onChange: (v: string) => void
}

const OPTIONS = [
  { value: 'bottom-center', label: 'Bottom Center' },
  { value: 'top-center',    label: 'Top Center' },
  { value: 'bottom-right',  label: 'Bottom Right' },
  { value: 'custom',        label: 'Custom' },
]

export function PositionPicker({ value, onChange }: Props) {
  return (
    <div className="mbt-pospick">
      {OPTIONS.map((o) => (
        <button
          key={o.value}
          type="button"
          className={`mbt-pospick__btn${value === o.value ? ' is-on' : ''}`}
          onClick={() => onChange(o.value)}
        >
          {o.label}
        </button>
      ))}
    </div>
  )
}

export default PositionPicker
