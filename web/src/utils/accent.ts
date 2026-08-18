/**
 * Brand accent — what the accent MEANS: which surface it is read against, and which
 * tokens one hex colour drives. The arithmetic lives in utils/color.ts.
 */

import { hexToRgb, rgbToHex, contrastRatio, isHexColor, tintSurface, type RGB } from './color'

export { isHexColor }

/** Factory accent. Mirrors MBT.Accent (default.lua) and --mbt-accent (styles/tokens.css). */
export const DEFAULT_ACCENT = '#00E676'

/** WCAG 2.1 SC 1.4.11 (non-text contrast) — the floor for a UI colour still being
 *  distinguishable. Below this the accent is warned about, never blocked. */
export const MIN_CONTRAST = 3

/**
 * The overlay surface ladder, as lightness values.
 *
 * These are the lightnesses of the neutral surfaces they replace in-game — #0B100E, #121814
 * and #1A221E sit at 5.3%, 8.2% and 11.8% — so a tinted panel keeps exactly the depth
 * relationships the neutral one had. Only the hue changes.
 */
const SURFACE_L = { s1: 0.055, s2: 0.078, s3: 0.115 } as const

/** The card background for an accent: what the accent is read against, DERIVED rather than
 *  copied. This was a hand-maintained constant of the .cine-chip literals with a comment
 *  asking the next person to keep it in sync; now the chip and this both come from here. */
const surfaceFor = (hex: string): RGB => tintSurface(hex, SURFACE_L.s2) ?? { r: 0x0D, g: 0x11, b: 0x0F }

/** Multiplier for --mbt-accent-deep (hover-on-fill). Reproduces the shipped
 *  #00E676 -> #00C665 pair, within a shade of the hand-picked #00C66B. */
const DEEP_FACTOR = 0.86

/**
 * Contrast of an accent against the card it will be drawn on. 0 for a malformed hex.
 *
 * Since the card is now tinted with the accent's own hue, this asks the one question that
 * can still go wrong: is the colour bright enough to be seen against itself? The shipped
 * presets score 6-10:1. A colour chosen too dark — #1A3D2A, #2B2B2B — scores 1.3-1.5 and
 * gets warned about, which is precisely the case that would vanish in game.
 */
export function accentContrast(hex: string): number {
  const rgb = hexToRgb(hex)
  return rgb ? contrastRatio(rgb, surfaceFor(hex)) : 0
}

/** The accent token set for one hex, as CSS custom properties.
 *
 *  --mbt-accent-rgb must stay a BARE "r, g, b" triplet: dozens of rules consume it as
 *  rgba(var(--mbt-accent-rgb), 0.4), and a hex string there makes every one of them an
 *  invalid declaration that the browser drops without a word. */
export function accentTokens(hex?: string | null): Record<string, string> {
  const value = isHexColor(hex) ? hex.toUpperCase() : DEFAULT_ACCENT
  const { r, g, b } = hexToRgb(value)!
  const s1 = tintSurface(value, SURFACE_L.s1)!
  const s2 = tintSurface(value, SURFACE_L.s2)!
  const s3 = tintSurface(value, SURFACE_L.s3)!
  return {
    '--mbt-accent': value,
    '--mbt-accent-rgb': `${r}, ${g}, ${b}`,
    '--mbt-accent-deep': rgbToHex({ r: r * DEEP_FACTOR, g: g * DEEP_FACTOR, b: b * DEEP_FACTOR }),
    '--mbt-accent-soft': `rgba(${r}, ${g}, ${b}, 0.08)`,
    '--mbt-accent-glow': `rgba(${r}, ${g}, ${b}, 0.22)`,
    // The surfaces the overlays are painted on. Thirteen of the fifteen overlay stylesheets
    // already draw their card from these tokens, so tinting them here recolours all of them
    // at once — and because applyAccent writes onto the in-game root only, the dashboard
    // around them keeps its neutral panel.
    '--mbt-surface-1': rgbToHex(s1),
    '--mbt-surface-2': rgbToHex(s2),
    '--mbt-surface-3': rgbToHex(s3),
    // The cinematic chip is translucent over live gameplay, so it needs the same two shades
    // WITH their alpha rather than a flat hex. It used to hardcode them.
    '--mbt-chip-top': `rgba(${s3.r}, ${s3.g}, ${s3.b}, 0.90)`,
    '--mbt-chip-bottom': `rgba(${s1.r}, ${s1.g}, ${s1.b}, 0.93)`,
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
