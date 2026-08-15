/**
 * Colour primitives — hex / RGB / HSV conversion and WCAG contrast.
 *
 * Hand-rolled rather than pulled from a library: this is maths against specs that
 * haven't moved in fifteen years, and the resource ships its bundle to every player.
 * Kept apart from accent.ts, which owns what the accent MEANS (which surface it is
 * read against, which tokens it drives) rather than how colour arithmetic works.
 */

export interface RGB { r: number; g: number; b: number }
export interface HSV { h: number; s: number; v: number }

const HEX_RE = /^#[0-9a-fA-F]{6}$/

/** True for exactly '#rrggbb' — the same shape the server enforces before saving. */
export const isHexColor = (v: unknown): v is string => typeof v === 'string' && HEX_RE.test(v)

export function hexToRgb(hex: string): RGB | null {
  if (!isHexColor(hex)) return null
  return {
    r: parseInt(hex.slice(1, 3), 16),
    g: parseInt(hex.slice(3, 5), 16),
    b: parseInt(hex.slice(5, 7), 16),
  }
}

export const rgbToHex = ({ r, g, b }: RGB): string =>
  '#' + [r, g, b]
    .map((c) => Math.max(0, Math.min(255, Math.round(c))).toString(16).padStart(2, '0'))
    .join('')
    .toUpperCase()

/** RGB (0-255) → HSV with h in degrees, s and v in [0..1]. */
export function rgbToHsv({ r, g, b }: RGB): HSV {
  const R = r / 255, G = g / 255, B = b / 255
  const max = Math.max(R, G, B)
  const min = Math.min(R, G, B)
  const d = max - min

  let h = 0
  if (d !== 0) {
    if (max === R) h = ((G - B) / d) % 6
    else if (max === G) h = (B - R) / d + 2
    else h = (R - G) / d + 4
    h *= 60
    if (h < 0) h += 360
  }
  return { h, s: max === 0 ? 0 : d / max, v: max }
}

/** HSV → RGB (0-255). h wraps, s and v clamp. */
export function hsvToRgb({ h, s, v }: HSV): RGB {
  const H = ((h % 360) + 360) % 360
  const S = Math.max(0, Math.min(1, s))
  const V = Math.max(0, Math.min(1, v))

  const c = V * S
  const x = c * (1 - Math.abs(((H / 60) % 2) - 1))
  const m = V - c
  const i = Math.floor(H / 60) % 6
  const [r, g, b] = [
    [c, x, 0], [x, c, 0], [0, c, x], [0, x, c], [x, 0, c], [c, 0, x],
  ][i]
  return { r: Math.round((r + m) * 255), g: Math.round((g + m) * 255), b: Math.round((b + m) * 255) }
}

export const hexToHsv = (hex: string): HSV | null => {
  const rgb = hexToRgb(hex)
  return rgb ? rgbToHsv(rgb) : null
}
export const hsvToHex = (hsv: HSV): string => rgbToHex(hsvToRgb(hsv))

/** sRGB relative luminance (WCAG 2.1). */
function luminance({ r, g, b }: RGB): number {
  const ch = (v: number) => {
    const s = v / 255
    return s <= 0.03928 ? s / 12.92 : ((s + 0.055) / 1.055) ** 2.4
  }
  return 0.2126 * ch(r) + 0.7152 * ch(g) + 0.0722 * ch(b)
}

/** WCAG contrast ratio between two colours, 1 (identical) to 21 (black on white). */
export function contrastRatio(a: RGB, b: RGB): number {
  const la = luminance(a)
  const lb = luminance(b)
  const hi = Math.max(la, lb)
  const lo = Math.min(la, lb)
  return (hi + 0.05) / (lo + 0.05)
}
