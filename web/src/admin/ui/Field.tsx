import type { ReactNode } from "react";
import "./Field.css";

/**
 * Field — a labelled form control wrapper for the config view. Label above the
 * control, optional hint below. Shared by every config section component;
 * Field.css also carries the section shell and input primitives.
 */

export interface FieldProps {
  label: string;
  hint?: string;
  /** id of the control, wired to the label's htmlFor. */
  htmlFor?: string;
  /** Width preset: "sm" caps short/numeric fields so they don't sprawl. */
  size?: "sm" | "md";
  /** Marks the field as required — renders an amber asterisk on the label. */
  required?: boolean;
  /** Validation message — amber border + message, replaces the hint while set. */
  error?: string;
  children: ReactNode;
}

export function Field({
  label,
  hint,
  htmlFor,
  size,
  required,
  error,
  children,
}: FieldProps) {
  return (
    <div
      className={`mbt-field${size ? ` mbt-field--${size}` : ""}${
        error ? " mbt-field--error" : ""
      }`}
    >
      <label className="mbt-field__label" htmlFor={htmlFor}>
        {label}
        {required && (
          <span className="mbt-field__req" aria-hidden="true">
            *
          </span>
        )}
      </label>
      {children}
      {error ? (
        <p className="mbt-field__err">
          <svg width="11" height="11" viewBox="0 0 24 24" fill="none">
            <circle cx="12" cy="12" r="9" stroke="currentColor" strokeWidth="2" />
            <path
              d="M12 8v4M12 15.5v.5"
              stroke="currentColor"
              strokeWidth="2"
              strokeLinecap="round"
            />
          </svg>
          {error}
        </p>
      ) : (
        hint && <p className="mbt-field__hint">{hint}</p>
      )}
    </div>
  );
}

export default Field;
