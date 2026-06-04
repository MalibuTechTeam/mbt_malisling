import type { ReactNode } from "react";

/**
 * Icon — single source for the dashboard's line icons.
 *
 * Paths live in a module-level map, defined once at module load and never
 * recreated per render (vercel rerender/rendering-hoist-jsx). Every icon shares
 * one 24x24 viewBox and inherits `currentColor`, so colour comes from CSS.
 *
 * Stroke icons are the default. Filled glyphs (the kebab dots) set their own
 * `fill` on the inner elements.
 */

export type IconName =
  // brand + rail
  | "logo"
  | "grid"
  | "book"
  | "power"
  // header
  | "search"
  | "plus"
  // status glyphs (shape-distinct, readable without colour)
  | "operational"
  | "faulty"
  | "hacked"
  | "draft"
  // card actions
  | "teleport"
  | "repair"
  | "more"
  | "trash"
  | "duplicate"
  | "configure"
  // config view
  | "back"
  | "save"
  | "chevron"
  | "capture"
  | "clipboard"
  | "help"
  | "check"
  | "circle"
  | "alert"
  // config section nav
  | "clock"
  | "cursor"
  | "layers"
  | "lock"
  | "palette"
  // malisling-specific glyphs (weapon/audio/world domain)
  | "speaker"
  | "flame"
  | "target"
  | "pose"
  | "vehicle"
  | "globe";

const ICON_PATHS: Record<IconName, ReactNode> = {
  logo: <path d="M4 19V7l8 5 8-5v12" />,
  grid: (
    <>
      <rect x="3" y="3" width="7" height="7" rx="1.5" />
      <rect x="14" y="3" width="7" height="7" rx="1.5" />
      <rect x="3" y="14" width="7" height="7" rx="1.5" />
      <rect x="14" y="14" width="7" height="7" rx="1.5" />
    </>
  ),
  book: <path d="M4 5.5A2.5 2.5 0 0 1 6.5 3H20v15H6.5A2.5 2.5 0 0 0 4 20.5V5.5Z" />,
  power: <path d="M12 3v9M6.5 7a8 8 0 1 0 11 0" />,

  search: (
    <>
      <circle cx="11" cy="11" r="7" />
      <path d="m20 20-3.5-3.5" />
    </>
  ),
  plus: <path d="M12 5v14M5 12h14" />,

  operational: (
    <>
      <circle cx="12" cy="12" r="9" />
      <path d="m8.5 12 2.5 2.5 4.5-5" />
    </>
  ),
  faulty: (
    <>
      <path d="M12 3.5 22 20H2L12 3.5Z" />
      <path d="M12 10v4.5M12 17.5v.2" />
    </>
  ),
  hacked: (
    <>
      <path d="M12 3l7.5 3v6c0 4.5-3 7.5-7.5 9-4.5-1.5-7.5-4.5-7.5-9V6L12 3Z" />
      <path d="M9.4 9.4 14.6 14.6M14.6 9.4 9.4 14.6" />
    </>
  ),
  draft: (
    <>
      <circle cx="12" cy="12" r="9" strokeDasharray="3 3" />
      <path d="M12 8v4.5l3 2" />
    </>
  ),

  teleport: <path d="m22 2-7 20-4-9-9-4 20-7Z" />,
  repair: (
    <path d="M14.5 5.5a4 4 0 0 1-5 5L4 16v4h4l5.5-5.5a4 4 0 0 0 5-5l-2.6 2.6-2.4-.6-.6-2.4 2.6-2.6Z" />
  ),
  more: (
    <>
      <circle cx="5" cy="12" r="1.6" fill="currentColor" stroke="none" />
      <circle cx="12" cy="12" r="1.6" fill="currentColor" stroke="none" />
      <circle cx="19" cy="12" r="1.6" fill="currentColor" stroke="none" />
    </>
  ),
  trash: <path d="M4 7h16M9 7V4h6v3M6 7l1 13h10l1-13" />,
  duplicate: (
    <>
      <rect x="8" y="8" width="13" height="13" rx="2" />
      <path d="M5 16H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h10a2 2 0 0 1 2 2v1" />
    </>
  ),
  configure: <path d="M3 21v-4l11-11 4 4L7 21H3Z" />,

  back: <path d="M15 5l-7 7 7 7" />,
  save: (
    <>
      <path d="M5 4h11l3 3v13H5V4Z" />
      <path d="M9 4v5h6M9 20v-6h6v6" />
    </>
  ),
  chevron: <path d="m6 9 6 6 6-6" />,
  capture: (
    <>
      <path d="M12 2v4M12 18v4M2 12h4M18 12h4" />
      <circle cx="12" cy="12" r="4.5" />
    </>
  ),
  help: (
    <>
      <path d="M9.2 9a2.8 2.8 0 1 1 4.4 2.3c-1 .7-1.6 1.2-1.6 2.4" />
      <path d="M12 17.5v.2" />
    </>
  ),
  check: <path d="M5 12.5 10 17 19 7" />,
  circle: <circle cx="12" cy="12" r="9" />,
  alert: (
    <>
      <path d="M12 3.5 2.5 20h19L12 3.5Z" />
      <path d="M12 10v4M12 17.2v.2" />
    </>
  ),
  clipboard: (
    <>
      <path d="M9 11l3 3L22 4" />
      <path d="M21 12v7a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h11" />
    </>
  ),

  clock: (
    <>
      <circle cx="12" cy="12" r="9" />
      <path d="M12 8v4l3 2" />
    </>
  ),
  cursor: <path d="M5 3l14 9-6 1.5L10 20 5 3Z" />,
  layers: (
    <>
      <path d="M12 3 3 8l9 5 9-5-9-5Z" />
      <path d="m3 16 9 5 9-5M3 12l9 5 9-5" />
    </>
  ),
  lock: (
    <>
      <rect x="4" y="10" width="16" height="11" rx="2" />
      <path d="M8 10V7a4 4 0 0 1 8 0v3" />
    </>
  ),
  palette: (
    <>
      <circle cx="12" cy="12" r="9" />
      <circle cx="9" cy="9.5" r="1.4" fill="currentColor" stroke="none" />
      <circle cx="15" cy="9.5" r="1.4" fill="currentColor" stroke="none" />
      <circle cx="9.5" cy="15" r="1.4" fill="currentColor" stroke="none" />
    </>
  ),

  speaker: (
    <>
      <path d="M4 9v6h3.5L13 19V5L7.5 9H4Z" />
      <path d="M16.5 9a4 4 0 0 1 0 6" />
    </>
  ),
  flame: (
    <path d="M12 2.5c2.5 3.5 5 5.5 5 9.5a5 5 0 0 1-10 0c0-2 .8-3.3 2-4.3.3 1.8 1.3 2.8 2.5 2.8-1.3-2.3-1.3-5.3.5-8Z" />
  ),
  target: (
    <>
      <circle cx="12" cy="12" r="7.5" />
      <circle cx="12" cy="12" r="3" />
      <path d="M12 1.5v3M12 19.5v3M1.5 12h3M19.5 12h3" />
    </>
  ),
  pose: (
    <>
      <circle cx="12" cy="5.5" r="2.5" />
      <path d="M12 8v6M12 10.5 7.5 13M12 10.5 16.5 13M12 14l-2.5 6.5M12 14l2.5 6.5" />
    </>
  ),
  vehicle: (
    <>
      <path d="M5 11l1.4-4.2A2 2 0 0 1 8.3 5.5h7.4a2 2 0 0 1 1.9 1.3L19 11" />
      <path d="M3.5 11h17v4.5a1 1 0 0 1-1 1H18M16 16.5H8M6 16.5H4.5a1 1 0 0 1-1-1V11" />
      <circle cx="7.5" cy="16.5" r="1.5" />
      <circle cx="16.5" cy="16.5" r="1.5" />
    </>
  ),
  globe: (
    <>
      <circle cx="12" cy="12" r="9" />
      <path d="M3 12h18" />
      <path d="M12 3c2.5 2.5 2.5 15 0 18M12 3c-2.5 2.5-2.5 15 0 18" />
    </>
  ),
};

export interface IconProps {
  name: IconName;
  /** Square size in px. Default 16. */
  size?: number;
  /** Stroke width. Default 2. */
  strokeWidth?: number;
  className?: string;
}

/**
 * Renders a 24x24 line icon. Colour is inherited via `currentColor`; set it
 * with CSS `color` on this element or an ancestor.
 */
export function Icon({ name, size = 16, strokeWidth = 2, className }: IconProps) {
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth={strokeWidth}
      strokeLinecap="round"
      strokeLinejoin="round"
      className={className}
      aria-hidden="true"
      focusable="false"
    >
      {ICON_PATHS[name]}
    </svg>
  );
}

export default Icon;
