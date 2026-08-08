import { useEffect, useId, useRef, useState } from "react";
import { Icon } from "./Icon";
import "./Select.css";

/**
 * Select — a Control-Room-styled dropdown. The native <select> popup can't be
 * skinned (the browser/OS draws it), so this is a custom listbox: a button +
 * an absolutely-positioned menu. Fully keyboard-operable (combobox pattern):
 * focus stays on the button, a roving `activeIndex` + aria-activedescendant
 * tracks the cursor. Closes on outside click, selection, Escape, or blur/Tab.
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
  const [activeIndex, setActiveIndex] = useState(0);
  const ref = useRef<HTMLDivElement>(null);
  const btnRef = useRef<HTMLButtonElement>(null);
  const listRef = useRef<HTMLUListElement>(null);

  // Unique fallback id so multiple Selects without an explicit id don't collide on
  // aria-controls / option ids (the old "mbt-select" constant duplicated them).
  const autoId = useId();
  const baseId = id || autoId;
  const listId = `${baseId}-list`;
  const optId = (i: number) => `${baseId}-opt-${i}`;
  const selectedIndex = Math.max(
    0,
    options.findIndex((o) => o.value === value),
  );

  // Close on outside click.
  useEffect(() => {
    if (!open) return;
    const onDown = (e: globalThis.MouseEvent) => {
      if (ref.current && !ref.current.contains(e.target as Node)) setOpen(false);
    };
    document.addEventListener("mousedown", onDown);
    return () => document.removeEventListener("mousedown", onDown);
  }, [open]);

  // Opening starts the cursor on the current value.
  useEffect(() => {
    if (open) setActiveIndex(selectedIndex);
  }, [open, selectedIndex]);

  // Keep the active option scrolled into view as the cursor moves.
  useEffect(() => {
    if (!open) return;
    (listRef.current?.children[activeIndex] as HTMLElement | undefined)?.scrollIntoView({
      block: "nearest",
    });
  }, [open, activeIndex]);

  const choose = (i: number) => {
    const o = options[i];
    if (o) onChange(o.value);
    setOpen(false);
    btnRef.current?.focus();
  };

  const onKeyDown = (e: React.KeyboardEvent) => {
    if (!open) {
      if (e.key === "ArrowDown" || e.key === "Enter" || e.key === " ") {
        e.preventDefault();
        setOpen(true);
      }
      return;
    }
    switch (e.key) {
      case "Escape":
        // Close the LIST only — stop the event so the dashboard's Escape→close
        // doesn't also fire and shut the whole panel.
        e.preventDefault();
        e.stopPropagation();
        setOpen(false);
        btnRef.current?.focus();
        break;
      case "ArrowDown":
        e.preventDefault();
        if (options.length) setActiveIndex((i) => (i + 1) % options.length);
        break;
      case "ArrowUp":
        e.preventDefault();
        if (options.length) setActiveIndex((i) => (i - 1 + options.length) % options.length);
        break;
      case "Home":
        e.preventDefault();
        setActiveIndex(0);
        break;
      case "End":
        e.preventDefault();
        if (options.length) setActiveIndex(options.length - 1);
        break;
      case "Enter":
      case " ":
        e.preventDefault();
        choose(activeIndex);
        break;
      case "Tab":
        setOpen(false); // let focus move on naturally
        break;
    }
  };

  const current = options.find((o) => o.value === value);

  return (
    <div className="mbt-select2" ref={ref}>
      <button
        ref={btnRef}
        type="button"
        id={id}
        className={`mbt-select2__btn${open ? " is-open" : ""}`}
        role="combobox"
        aria-haspopup="listbox"
        aria-expanded={open}
        aria-controls={open ? listId : undefined}
        aria-activedescendant={open ? optId(activeIndex) : undefined}
        aria-label={ariaLabel}
        onClick={() => setOpen((o) => !o)}
        onKeyDown={onKeyDown}
      >
        <span>{current?.label ?? value}</span>
        <Icon name="chevron" size={14} className="mbt-select2__chev" />
      </button>
      {open && (
        <ul className="mbt-select2__menu" id={listId} role="listbox" ref={listRef}>
          {options.map((o, i) => (
            <li
              key={o.value}
              id={optId(i)}
              role="option"
              aria-selected={o.value === value}
              className={`mbt-select2__opt${o.value === value ? " is-selected" : ""}${i === activeIndex ? " is-active" : ""}`}
              onMouseEnter={() => setActiveIndex(i)}
              onClick={() => choose(i)}
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
