/**
 * Brand accent — what the accent MEANS: which surface it is read against, and which
 * tokens one hex colour drives. The arithmetic lives in utils/color.ts.
 */

import { hexToRgb, rgbToHex, contrastRatio, isHexColor, type RGB } from './color'

export { isHexColor }

/** Factory accent. Mirrors MBT.Accent (default.lua) and --mbt-accent (styles/tokens.css). */
export const DEFAULT_ACCENT = '#00E676'

/** WCAG 2.1 SC 1.4.11 (non-text contrast) — the floor for a UI colour still being
 *  distinguishable. Below this the accent is warned about, never blocked. */
export const MIN_CONTRAST = 3

/** What the accent is actually read against: the in-game prompt chip, NOT the dashboard
 *  card. The accent is the SERVER's colour on what its players see; the dashboard is our
 *  panel and keeps the MalibuTech green, so measuring against it would be answering a
 *  question nobody asked. Mid of the .cine-chip gradient (components/cinematic-chip.css,
 *  rgba(16,21,18,.90) → rgba(9,12,10,.93)). Kept in sync by hand: the chip is translucent
 *  over live gameplay, so there is no single value to read at runtime — this is the base
 *  it is painted on, and the brightest thing behind it can only help. */
const CHIP_BG: RGB = { r: 0x0D, g: 0x11, b: 0x0F }

/** Multiplier for --mbt-accent-deep (hover-on-fill). Reproduces the shipped
 *  #00E676 -> #00C665 pair, within a shade of the hand-picked #00C66B. */
const DEEP_FACTOR = 0.86

/** Contrast of an accent hex against the in-game prompt chip. 0 for a malformed hex. */
export function accentContrast(hex: string): number {
  const rgb = hexToRgb(hex)
  return rgb ? contrastRatio(rgb, CHIP_BG) : 0
}

/** The accent token set for one hex, as CSS custom properties.
 *
 *  --mbt-accent-rgb must stay a BARE "r, g, b" triplet: dozens of rules consume it as
 *  rgba(var(--mbt-accent-rgb), 0.4), and a hex string there makes every one of them an
 *  invalid declaration that the browser drops without a word. */
export function accentTokens(hex?: string | null): Record<string, string> {
  const value = isHexColor(hex) ? hex.toUpperCase() : DEFAULT_ACCENT
  const { r, g, b } = hexToRgb(value)!
  return {
    '--mbt-accent': value,
    '--mbt-accent-rgb': `${r}, ${g}, ${b}`,
    '--mbt-accent-deep': rgbToHex({ r: r * DEEP_FACTOR, g: g * DEEP_FACTOR, b: b * DEEP_FACTOR }),
    '--mbt-accent-soft': `rgba(${r}, ${g}, ${b}, 0.08)`,
    '--mbt-accent-glow': `rgba(${r}, ${g}, ${b}, 0.22)`,
  }
}

/**
 * Paint the accent onto ONE element — the in-game overlay root, never <html>.
 *
 * Scoped deliberately. The accent is the server owner's colour for what their PLAYERS
 * see; the admin dashboard is the MalibuTech panel and keeps the brand green. On <html>
 * it repainted both, which reads as "I am recolouring the tool" rather than "I am
 * branding my server" — and every in-game overlay and the dashboard share one CEF
 * document, so scoping is the only thing separating them.
 *
 * Falls back to the factory colour for anything malformed, so a bad value can never
 * leave the page half-themed.
 */
export function applyAccent(hex: string | null | undefined, el: HTMLElement | null): void {
  if (!el) return
  for (const [prop, value] of Object.entries(accentTokens(hex))) {
    el.style.setProperty(prop, value)
  }
}
