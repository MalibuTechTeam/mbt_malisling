import { useRef } from 'react'
import { useNuiEvent } from '../utils/useNuiEvent'
import './CinematicCard.css'

export interface CinematicRow { label: string; value: string; tone?: 'accent' | 'good' | 'warn' | 'bad' }
export interface CinematicKey { cap: string; label: string }
/** Pre-collapsed, pre-localized custody list (InspectUI owns the i18n + tail collapse). */
export type CinematicCustodyItem = { name: string; tag?: string } | { gap: string }
export interface CinematicCustody { title: string; count: number; items: CinematicCustodyItem[] }

interface CinematicCardProps {
  overline: string          // small mono eyebrow, e.g. "Holster" / "Inspecting"
  title: string             // the weapon name (display type)
  anchor: string            // matches the `<anchor>:anchor` messages the Lua side sends
  exiting: boolean
  rows?: CinematicRow[]      // data body (inspect)
  keys?: CinematicKey[]      // action keys (prompts, e.g. holster)
  custody?: CinematicCustody // chain of custody (inspect), rendered below the rows
}

/**
 * CinematicCard — the shared filmic overlay for the 'cinematic' UI style (MBT.UIStyle).
 * Accent tick + overline + display weapon name + hairline, then data rows (inspect) or
 * action keys (holster). Anchors to a world point near the weapon: the Lua side projects
 * it each frame and this positions the element via a ref — no React re-render per frame.
 */
export function CinematicCard({ overline, title, anchor, exiting, rows, keys, custody }: CinematicCardProps) {
  const ref = useRef<HTMLDivElement | null>(null)

  useNuiEvent<{ x?: number; y?: number; off?: boolean }>(`${anchor}:anchor`, (p) => {
    const el = ref.current
    if (!el) return
    if (p.off || p.x == null || p.y == null) { el.style.left = '-9999px'; return }
    el.style.left = `${(p.x * 100).toFixed(3)}%`
    el.style.top  = `${(p.y * 100).toFixed(3)}%`
  })

  return (
    <div ref={ref} className={`holcine holcine-anchored ${exiting ? 'holcine-exit' : 'holcine-enter'}`} aria-hidden="true">
      <span className="holcine-tick" />
      <div className="holcine-body">
        <div className="holcine-over">{overline}</div>
        <div className="holcine-name">{title}</div>
        <div className="holcine-line" />
        {rows && rows.length > 0 && (
          <div className="holcine-rows">
            {rows.map((r, i) => (
              <div className="holcine-row" key={i}>
                <span className="holcine-row-l">{r.label}</span>
                <span className={`holcine-row-v${r.tone ? ` is-${r.tone}` : ''}`}>{r.value}</span>
              </div>
            ))}
          </div>
        )}
        {keys && keys.length > 0 && (
          <div className="holcine-keys">
            {keys.map((k, i) => (
              <span key={i}>
                {i > 0 && <span className="holcine-sep">·</span>}
                <span className="mbt-kc">{k.cap}</span> {k.label}
              </span>
            ))}
          </div>
        )}
        {custody && custody.items.length > 0 && (
          <div className="holcine-custody">
            <div className="holcine-custody-title">
              {custody.title}<span className="holcine-custody-count">{custody.count}</span>
            </div>
            <div className="holcine-custody-list">
              {custody.items.map((it, i) =>
                'gap' in it ? (
                  <div className="holcine-custody-gap" key={`g${i}`}>{it.gap}</div>
                ) : (
                  <div className="holcine-custody-entry" key={i}>
                    <span className="holcine-custody-dot" />
                    <span className="holcine-custody-name">{it.name}</span>
                    {it.tag && <span className="holcine-custody-tag">{it.tag}</span>}
                  </div>
                )
              )}
            </div>
          </div>
        )}
      </div>
    </div>
  )
}

export default CinematicCard
