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

/**
 * A dark surface carrying a colour's hue.
 *
 * The overlay cards are painted with this, not with the colour itself: white text on a
 * full-strength accent measures 1.2-2.8:1 against every preset we ship (the default green
 * is 1.46), while on a tint of the same hue it stays at 15-17:1 — where the neutral
 * surfaces already were. The card still reads unmistakably as the server's colour, because
 * hue is what identifies a colour; lightness is what makes text on it readable.
 *
 * `satCap` keeps it a tint rather than a wash, and a near-grey accent stays near-grey —
 * a server that picks neutral gets the neutral panel it asked for.
 */
export function tintSurface(hex: string, lightness: number, satCap = 0.45): RGB | null {
  const rgb = hexToRgb(hex)
  if (!rgb) return null
  const { h, s } = rgbToHsl(rgb)
  return hslToRgb({ h, s: Math.min(s, satCap), l: lightness })
}

interface HSL { h: number; s: number; l: number }

function rgbToHsl({ r, g, b }: RGB): HSL {
  const R = r / 255, G = g / 255, B = b / 255
  const max = Math.max(R, G, B), min = Math.min(R, G, B)
  const l = (max + min) / 2
  if (max === min) return { h: 0, s: 0, l }
  const d = max - min
  const s = l > 0.5 ? d / (2 - max - min) : d / (max + min)
  const h = (max === R ? (G - B) / d + (G < B ? 6 : 0) : max === G ? (B - R) / d + 2 : (R - G) / d + 4) / 6
  return { h, s, l }
}

function hslToRgb({ h, s, l }: HSL): RGB {
  if (!s) return { r: Math.round(l * 255), g: Math.round(l * 255), b: Math.round(l * 255) }
  const q = l < 0.5 ? l * (1 + s) : l + s - l * s
  const p = 2 * l - q
  const ch = (t: number) => {
    if (t < 0) t += 1
    if (t > 1) t -= 1
    if (t < 1 / 6) return p + (q - p) * 6 * t
    if (t < 1 / 2) return q
    if (t < 2 / 3) return p + (q - p) * (2 / 3 - t) * 6
    return p
  }
  return { r: Math.round(ch(h + 1 / 3) * 255), g: Math.round(ch(h) * 255), b: Math.round(ch(h - 1 / 3) * 255) }
}
