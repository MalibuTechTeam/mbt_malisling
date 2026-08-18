import { useCallback, useEffect, useLayoutEffect, useRef, useState } from 'react'
import { createPortal } from 'react-dom'
import { hexToHsv, hsvToHex, hsvToRgb, isHexColor, type HSV } from '../../utils/color'
import './ColorPicker.css'

/**
 * ColorPicker — swatch plus popover, replacing `<input type="color">`, whose native
 * popup CEF renders in the OS chrome and cannot be styled: in game it appears as a
 * Windows dialog floating over the panel.
 *
 * Two things this does that the stock control and our first pass at one do not:
 *
 * - **It works without a mouse.** Hue is a real `<input type="range">`, so it gets
 *   keyboard, screen-reader semantics and OS accessibility settings for free rather
 *   than a div pretending. The saturation/value square is focusable and takes arrow
 *   keys (shift for coarse steps) — a 2D control has no native equivalent, so it is
 *   the one place with hand-written key handling.
 * - **The popover escapes the card, and flips.** An absolutely-positioned popover could
 *   not work here whatever its z-index: .mbt-section animates transform with fill-mode
 *   both, which leaves every card a stacking context of its own, so the next card paints
 *   over it — and the centre column is overflow-y:auto, which clips it as well. It is
 *   portalled to <body> and positioned fixed against the swatch, then flipped upward when
 *   the viewport has no room below. A picker you have to scroll to is one you cannot use
 *   while looking at what it changes.
 */

export interface ColorPickerProps {
  value: string
  onChange: (hex: string) => void
  /** Starting points offered above the square. Left out entirely if empty. */
  presets?: string[]
  /** Rendered along the popover's bottom edge — the caller's readout of the colour being
   *  dragged (for the accent, how readable it is). Kept as a slot so the picker itself
   *  stays about picking a colour and knows nothing about what the colour is for. */
  footer?: React.ReactNode
  'aria-label'?: string
}

/** Normalised [0..1] pointer position within an element, clamped. */
function posIn(el: HTMLElement, clientX: number, clientY: number) {
  const r = el.getBoundingClientRect()
  return {
    x: Math.max(0, Math.min(1, (clientX - r.left) / r.width)),
    y: Math.max(0, Math.min(1, (clientY - r.top) / r.height)),
  }
}

const FALLBACK: HSV = { h: 0, s: 0, v: 1 }

export function ColorPicker({ value, onChange, presets = [], footer, 'aria-label': label }: ColorPickerProps) {
  const [open, setOpen] = useState(false)
  const [pos, setPos] = useState<{ left: number; top: number; flip: boolean } | null>(null)
  const [hsv, setHsv] = useState<HSV>(() => hexToHsv(value) ?? FALLBACK)

  const rootRef = useRef<HTMLDivElement>(null)
  const popRef = useRef<HTMLDivElement>(null)
  const svRef = useRef<HTMLDivElement>(null)
  // What we last emitted. Re-deriving HSV from our own output would snap the hue to 0
  // every time the colour goes fully grey or black, because those have no hue to recover
  // — the square would jump under the pointer mid-drag.
  const lastEmitted = useRef(value)

  useEffect(() => {
    if (value === lastEmitted.current) return
    lastEmitted.current = value
    const next = hexToHsv(value)
    if (next) setHsv(next)
  }, [value])

  const emit = useCallback((next: HSV) => {
    setHsv(next)
    const hex = hsvToHex(next)
    lastEmitted.current = hex
    onChange(hex)
  }, [onChange])

  // Close on outside click / Escape. Escape is stopped: the dashboard closes on it too,
  // and shutting the whole panel to dismiss a popover loses unsaved work.
  useEffect(() => {
    if (!open) return
    // The popover is portalled out, so it is NOT inside rootRef any more — checking only
    // the anchor would close it the moment you touched the square you came to drag.
    const onDown = (e: MouseEvent) => {
      const t = e.target as Node
      if (rootRef.current?.contains(t) || popRef.current?.contains(t)) return
      setOpen(false)
    }
    const onKey = (e: KeyboardEvent) => {
      if (e.key !== 'Escape') return
      e.stopPropagation()
      setOpen(false)
    }
    document.addEventListener('mousedown', onDown)
    document.addEventListener('keydown', onKey, true)
    return () => {
      document.removeEventListener('mousedown', onDown)
      document.removeEventListener('keydown', onKey, true)
    }
  }, [open])

  // Place it against the swatch, in viewport coordinates. Measured after layout and before
  // paint, so it never renders once in the wrong place and jumps.
  const place = useCallback(() => {
    if (!popRef.current || !rootRef.current) return
    const a = rootRef.current.getBoundingClientRect()
    const w = popRef.current.offsetWidth
    const h = popRef.current.offsetHeight
    const flip = a.bottom + 8 + h > window.innerHeight && a.top - 8 - h > 0
    setPos({
      // Clamped so a swatch near the right edge does not push the popover off-screen.
      left: Math.max(8, Math.min(a.left, window.innerWidth - w - 8)),
      top: flip ? a.top - 8 - h : a.bottom + 8,
      flip,
    })
  }, [])

  useLayoutEffect(() => {
    if (!open) { setPos(null); return }
    place()
    // Fixed positioning does not follow the scrolling card it is anchored to, so re-place
    // on any scroll (capture: the centre column scrolls, not the window) and on resize.
    const onMove = () => place()
    document.addEventListener('scroll', onMove, true)
    window.addEventListener('resize', onMove)
    return () => {
      document.removeEventListener('scroll', onMove, true)
      window.removeEventListener('resize', onMove)
    }
  }, [open, place])

  // Pointer capture rather than window listeners: the drag survives leaving the window,
  // and the browser cancels it for us if the pointer is lost.
  const drag = (apply: (x: number, y: number) => void) => (e: React.PointerEvent<HTMLElement>) => {
    const el = e.currentTarget
    e.preventDefault()
    el.setPointerCapture(e.pointerId)
    const p = posIn(el, e.clientX, e.clientY)
    apply(p.x, p.y)
    const move = (ev: PointerEvent) => {
      const q = posIn(el, ev.clientX, ev.clientY)
      apply(q.x, q.y)
    }
    const up = () => {
      el.removeEventListener('pointermove', move)
      el.removeEventListener('pointerup', up)
      el.removeEventListener('pointercancel', up)
    }
    el.addEventListener('pointermove', move)
    el.addEventListener('pointerup', up)
    el.addEventListener('pointercancel', up)
  }

  const onSvKey = (e: React.KeyboardEvent) => {
    const step = e.shiftKey ? 0.1 : 0.01
    let { s, v } = hsv
    switch (e.key) {
      case 'ArrowLeft':  s -= step; break
      case 'ArrowRight': s += step; break
      case 'ArrowUp':    v += step; break
      case 'ArrowDown':  v -= step; break
      case 'Home':       s = 0; break
      case 'End':        s = 1; break
      default: return
    }
    e.preventDefault()
    emit({ h: hsv.h, s: Math.max(0, Math.min(1, s)), v: Math.max(0, Math.min(1, v)) })
  }

  const hueRgb = hsvToRgb({ h: hsv.h, s: 1, v: 1 })
  const current = isHexColor(value) ? value.toUpperCase() : hsvToHex(hsv)

  return (
    <div className={`mbt-cp${open ? ' is-open' : ''}`} ref={rootRef}>
      <button type="button" className="mbt-cp__swatch" style={{ background: current }}
        aria-label={label ?? 'Pick a colour'} aria-expanded={open} aria-haspopup="dialog"
        onClick={() => setOpen((o) => !o)} />

      {open && createPortal(
        <div ref={popRef} className={`mbt-cp__pop${pos?.flip ? ' is-flipped' : ''}`}
          role="dialog" aria-label="Colour picker"
          // Hidden for the one frame before it has been measured, or it would flash at
          // the top-left corner on every open.
          style={pos ? { left: pos.left, top: pos.top } : { opacity: 0, pointerEvents: 'none' }}>

          {presets.length > 0 && (
            <div className="mbt-cp__presets">
              {presets.map((p) => (
                <button key={p} type="button" style={{ background: p }}
                  className={`mbt-cp__preset${p.toUpperCase() === current ? ' is-on' : ''}`}
                  aria-label={p} title={p} aria-pressed={p.toUpperCase() === current}
                  onClick={() => {
                    lastEmitted.current = p
                    setHsv(hexToHsv(p) ?? FALLBACK)
                    onChange(p)
                  }} />
              ))}
            </div>
          )}

          <div ref={svRef} className="mbt-cp__sv" tabIndex={0} role="group"
            aria-label="Saturation and brightness — arrow keys to adjust"
            style={{ background: `rgb(${hueRgb.r}, ${hueRgb.g}, ${hueRgb.b})` }}
            onPointerDown={drag((x, y) => emit({ h: hsv.h, s: x, v: 1 - y }))}
            onKeyDown={onSvKey}>
            <div className="mbt-cp__sv-white" />
            <div className="mbt-cp__sv-black" />
            <span className="mbt-cp__sv-handle"
              style={{ left: `${hsv.s * 100}%`, top: `${(1 - hsv.v) * 100}%`, background: current }} />
          </div>

          <input type="range" className="mbt-cp__hue" min={0} max={360} step={1}
            value={Math.round(hsv.h)} aria-label="Hue"
            onChange={(e) => emit({ ...hsv, h: Number(e.target.value) })} />

          {footer && <div className="mbt-cp__footer">{footer}</div>}
        </div>,
        document.body,
      )}
    </div>
  )
}

export default ColorPicker
