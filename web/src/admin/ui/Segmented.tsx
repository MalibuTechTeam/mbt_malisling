import { Icon, type IconName } from "./Icon";
import "./Segmented.css";

/** Segmented — a small segmented control (mutually exclusive options). */

export interface SegmentedOption {
  value: string;
  label: string;
  icon?: IconName;
}

export interface SegmentedProps {
  options: SegmentedOption[];
  value: string;
  onChange: (value: string) => void;
}

export function Segmented({ options, value, onChange }: SegmentedProps) {
  return (
    <div className="mbt-segmented" role="group">
      {options.map((opt) => (
        <button
          key={opt.value}
          type="button"
          className={`mbt-seg${value === opt.value ? " is-active" : ""}`}
          aria-pressed={value === opt.value}
          onClick={() => onChange(opt.value)}
        >
          {opt.icon && <Icon name={opt.icon} size={14} />}
          {opt.label}
        </button>
      ))}
    </div>
  );
}

export default Segmented;
