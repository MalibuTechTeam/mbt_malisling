// Locale strings are shipped from Lua inside each show/open NUI message
// (buildNuiLocale() in modules/locales.lua). Each component receives a flat
// { key: string } table on its data payload and resolves text through makeT.

export type Locale = Record<string, string>

/**
 * Build a translator bound to a locale table. Always pass a fallback so the
 * UI renders correctly even if the locale payload is missing or incomplete.
 */
export function makeT(locale: Locale | undefined) {
  return (key: string, fallback: string): string => locale?.[key] ?? fallback
}
