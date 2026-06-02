import "./NumberInput.css";

/**
 * NumberInput — a number field with themed up/down steppers.
 *
 * The native spinner arrows can't be recoloured in CEF/Chromium, so they're
 * hidden globally (Field.css) and replaced by these Control Room chevrons.
 * Drop-in for `<input type="number" className="mbt-input">`: `onChange` still
 * receives the raw string (so existing buffer/parse logic is unchanged); the
 * steppers bump the value by `step`, rounded to the step's precision and
 * clamped to min/max.
 */

export interface NumberInputProps {
  value: string | number;
  onChange: (raw: string) => void;
  step?: number;
  min?: number;
  max?: number;
  /** Applied to the inner input (defaults to the standard field input). */
  className?: string;
  placeholder?: string;
  ariaLabel?: string;
}

export function NumberInput({
  value,
  onChange,
  step = 1,
  min,
  max,
  className = "mbt-input",
  placeholder,
  ariaLabel,
}: NumberInputProps) {
  const bump = (dir: 1 | -1) => {
    const cur = parseFloat(String(value));
    const base = Number.isNaN(cur) ? 0 : cur;
    const decimals = (String(step).split(".")[1] || "").length;
    let next = Number((base + dir * step).toFixed(decimals));
    if (typeof min === "number") next = Math.max(min, next);
    if (typeof max === "number") next = Math.min(max, next);
    onChange(String(next));
  };

  return (
    <div className="mbt-num">
      <input
        type="number"
        className={className}
        value={value}
        step={step}
        min={min}
        max={max}
        placeholder={placeholder}
        aria-label={ariaLabel}
        onChange={(e) => onChange(e.target.value)}
      />
      <div className="mbt-num__btns" aria-hidden="true">
        <button
          type="button"
          className="mbt-num__btn"
          tabIndex={-1}
          onClick={() => bump(1)}
        >
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.6" strokeLinecap="round" strokeLinejoin="round">
            <path d="m6 14 6-6 6 6" />
          </svg>
        </button>
        <button
          type="button"
          className="mbt-num__btn"
          tabIndex={-1}
          onClick={() => bump(-1)}
        >
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.6" strokeLinecap="round" strokeLinejoin="round">
            <path d="m6 10 6 6 6-6" />
          </svg>
        </button>
      </div>
    </div>
  );
}

export default NumberInput;
