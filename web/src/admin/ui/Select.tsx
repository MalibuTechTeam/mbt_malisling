import { useEffect, useRef, useState } from "react";
import { Icon } from "./Icon";
import "./Select.css";

/**
 * Select — a Control-Room-styled dropdown. The native <select> popup can't be
 * skinned (the browser/OS draws it), so this is a custom listbox: a button +
 * an absolutely-positioned menu. Closes on outside click or selection.
 */

export interface SelectOption {
  value: string;
  label: string;
}

export interface SelectProps {
  value: string;
  options: SelectOption[];
  onChange: (value: string) => void;
  id?: string;
  "aria-label"?: string;
}

export function Select({
  value,
  options,
  onChange,
  id,
  "aria-label": ariaLabel,
}: SelectProps) {
  const [open, setOpen] = useState(false);
  const ref = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!open) return;
    const close = (e: globalThis.MouseEvent) => {
      if (ref.current && !ref.current.contains(e.target as Node)) {
        setOpen(false);
      }
    };
    document.addEventListener("mousedown", close);
    return () => document.removeEventListener("mousedown", close);
  }, [open]);

  const current = options.find((o) => o.value === value);

  return (
    <div className="mbt-select2" ref={ref}>
      <button
        type="button"
        id={id}
        className={`mbt-select2__btn${open ? " is-open" : ""}`}
        aria-haspopup="listbox"
        aria-expanded={open}
        aria-label={ariaLabel}
        onClick={() => setOpen((o) => !o)}
      >
        <span>{current?.label ?? value}</span>
        <Icon name="chevron" size={14} className="mbt-select2__chev" />
      </button>
      {open && (
        <ul className="mbt-select2__menu" role="listbox">
          {options.map((o) => (
            <li
              key={o.value}
              role="option"
              aria-selected={o.value === value}
              className={`mbt-select2__opt${o.value === value ? " is-selected" : ""}`}
              onClick={() => {
                onChange(o.value);
                setOpen(false);
              }}
            >
              <span>{o.label}</span>
              {o.value === value && (
                <Icon name="check" size={13} strokeWidth={2.6} />
              )}
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}

export default Select;
