/** CamSlider — a labelled range slider for the live-editor camera (rotate /
 *  height / distance). Absolute value, shown numerically on the right. */
interface Props {
  label: string
  min: number
  max: number
  step: number
  val: number
  unit?: string
  onChange: (v: number) => void
  fmt?: (v: number) => string
}

export function CamSlider({ label, min, max, step, val, unit = '', onChange, fmt }: Props) {
  return (
    <label className="mbt-pe__slider">
      <span className="mbt-pe__slabel">{label}</span>
      <input type="range" min={min} max={max} step={step} value={val}
        onChange={(e) => onChange(+e.target.value)} />
      <b className="mbt-pe__sval">{(fmt ? fmt(val) : String(val))}{unit}</b>
    </label>
  )
}
