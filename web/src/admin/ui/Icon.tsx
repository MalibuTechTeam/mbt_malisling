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
  // brand links (filled glyphs — they're recognisable marks, not line icons)
  | "github"
  | "discord"
  | "docs"
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
  // A page with a folded corner and text lines. The `book` glyph above collapses to a
  // plain rounded box at rail size and reads as nothing.
  docs: (
    <>
      <path d="M14 3H7a1 1 0 0 0-1 1v16a1 1 0 0 0 1 1h10a1 1 0 0 0 1-1V7l-4-4Z" />
      <path d="M14 3v4h4" />
      <path d="M9 13h6M9 17h4" />
    </>
  ),
  power: <path d="M12 3v9M6.5 7a8 8 0 1 0 11 0" />,

  // Brand marks are filled, not stroked: at 15px the GitHub cat and the Discord
  // face only stay recognisable as solid glyphs. They set fill/stroke themselves
  // so the shared stroke defaults on <svg> don't smear them.
  github: (
    <path fill="currentColor" stroke="none" d="M12 .297c-6.63 0-12 5.373-12 12 0 5.303 3.438 9.8 8.205 11.385.6.113.82-.258.82-.577 0-.285-.01-1.04-.015-2.04-3.338.724-4.042-1.61-4.042-1.61C4.422 18.07 3.633 17.7 3.633 17.7c-1.087-.744.084-.729.084-.729 1.205.084 1.838 1.236 1.838 1.236 1.07 1.835 2.809 1.305 3.495.998.108-.776.417-1.305.76-1.605-2.665-.3-5.466-1.332-5.466-5.93 0-1.31.465-2.38 1.235-3.22-.135-.303-.54-1.523.105-3.176 0 0 1.005-.322 3.3 1.23.96-.267 1.98-.399 3-.405 1.02.006 2.04.138 3 .405 2.28-1.552 3.285-1.23 3.285-1.23.645 1.653.24 2.873.12 3.176.765.84 1.23 1.91 1.23 3.22 0 4.61-2.805 5.625-5.475 5.92.42.36.81 1.096.81 2.22 0 1.606-.015 2.896-.015 3.286 0 .315.21.69.825.57C20.565 22.092 24 17.592 24 12.297c0-6.627-5.373-12-12-12" />
  ),
  discord: (
    <path fill="currentColor" stroke="none" d="M20.317 4.3698a19.7913 19.7913 0 00-4.8851-1.5152.0741.0741 0 00-.0785.0371c-.211.3753-.4447.8648-.6083 1.2495-1.8447-.2762-3.68-.2762-5.4868 0-.1636-.3933-.4058-.8742-.6177-1.2495a.077.077 0 00-.0785-.037 19.7363 19.7363 0 00-4.8852 1.515.0699.0699 0 00-.0321.0277C.5334 9.0458-.319 13.5799.0992 18.0578a.0824.0824 0 00.0312.0561c2.0528 1.5076 4.0413 2.4228 5.9929 3.0294a.0777.0777 0 00.0842-.0276c.4616-.6304.8731-1.2952 1.226-1.9942a.076.076 0 00-.0416-.1057c-.6528-.2476-1.2743-.5495-1.8722-.8923a.077.077 0 01-.0076-.1277c.1258-.0943.2517-.1923.3718-.2914a.0743.0743 0 01.0776-.0105c3.9278 1.7933 8.18 1.7933 12.0614 0a.0739.0739 0 01.0785.0095c.1202.099.246.1981.3728.2924a.077.077 0 01-.0066.1276 12.2986 12.2986 0 01-1.873.8914.0766.0766 0 00-.0407.1067c.3604.698.7719 1.3628 1.225 1.9932a.076.076 0 00.0842.0286c1.961-.6067 3.9495-1.5219 6.0023-3.0294a.077.077 0 00.0313-.0552c.5004-5.177-.8382-9.6739-3.5485-13.6604a.061.061 0 00-.0312-.0286zM8.02 15.3312c-1.1825 0-2.1569-1.0857-2.1569-2.419 0-1.3332.9555-2.4189 2.157-2.4189 1.2108 0 2.1757 1.0952 2.1568 2.419 0 1.3332-.9555 2.4189-2.1569 2.4189zm7.9748 0c-1.1825 0-2.1569-1.0857-2.1569-2.419 0-1.3332.9554-2.4189 2.1569-2.4189 1.2108 0 2.1757 1.0952 2.1568 2.419 0 1.3332-.946 2.4189-2.1568 2.4189Z" />
  ),

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
