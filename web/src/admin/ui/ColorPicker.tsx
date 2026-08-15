import { useCallback, useEffect, useLayoutEffect, useRef, useState } from 'react'
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
 * - **The popover flips.** Fixed below the swatch, it fell off the bottom of the panel
 *   for any section low on the page, and a colour picker you have to scroll to is one
 *   you cannot use while looking at what it changes.
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
  const [flip, setFlip] = useState(false)
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
    const onDown = (e: MouseEvent) => {
      if (rootRef.current && !rootRef.current.contains(e.target as Node)) setOpen(false)
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

  // Open upward when there isn't room below. Measured after layout, before paint, so it
  // never renders once in the wrong place and jumps.
  useLayoutEffect(() => {
    if (!open || !popRef.current || !rootRef.current) return
    const anchor = rootRef.current.getBoundingClientRect()
    const height = popRef.current.offsetHeight
    setFlip(anchor.bottom + 8 + height > window.innerHeight && anchor.top - 8 - height > 0)
  }, [open])

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

      {open && (
        <div ref={popRef} className={`mbt-cp__pop${flip ? ' is-flipped' : ''}`}
          role="dialog" aria-label="Colour picker">

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
        </div>
      )}
    </div>
  )
}

export default ColorPicker
