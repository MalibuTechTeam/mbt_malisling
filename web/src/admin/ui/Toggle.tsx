import "./Toggle.css";

/**
 * Toggle — an accessible switch control. The visible track is a styled sibling
 * of a visually-hidden checkbox.
 */

export interface ToggleProps {
  checked: boolean;
  onChange: (checked: boolean) => void;
  id?: string;
  "aria-label"?: string;
}

export function Toggle({ checked, onChange, id, "aria-label": ariaLabel }: ToggleProps) {
  return (
    <label className="mbt-toggle">
      <input
        type="checkbox"
        id={id}
        checked={checked}
        aria-label={ariaLabel}
        onChange={(e) => onChange(e.target.checked)}
      />
      <span className="mbt-toggle__track">
        <span className="mbt-toggle__thumb" />
      </span>
    </label>
  );
}

export default Toggle;
