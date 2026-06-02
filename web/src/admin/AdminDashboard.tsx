import { useState, useEffect, useCallback } from 'react'
import { useNuiEvent } from '../utils/useNuiEvent'
import { fetchNui } from '../utils/fetchNui'
import { Icon, type IconName } from './ui/Icon'
import { GeneralSection } from './sections/GeneralSection'
import './Admin.css'

/**
 * AdminDashboard — the malisling admin config panel. Brand-coherent with the
 * mbt_elevator Control-Room dashboard (shared --mbt-* design system): rail +
 * center + overview. Opens on the `openAdmin` NUI event with the full config
 * snapshot, edits a local draft, and saves via the `adminSave` callback which
 * the server broadcasts live to every client.
 */

interface RailItem { id: string; label: string; hint?: string; icon: IconName; group: string }

const RAIL: RailItem[] = [
  { id: 'general',   label: 'General',         hint: 'Core sling & interface', icon: 'configure', group: 'ESSENTIALS' },
  { id: 'holster',   label: 'Holster & Sounds',                                icon: 'book',      group: 'ESSENTIALS' },
  { id: 'drop',      label: 'Weapon Drop',                                     icon: 'layers',    group: 'ESSENTIALS' },
  { id: 'jamming',   label: 'Jamming',                                         icon: 'clock',     group: 'COMBAT / RP' },
  { id: 'suppressor',label: 'Suppressor Heat',                                 icon: 'power',     group: 'COMBAT / RP' },
  { id: 'safety',    label: 'Weapon Safety',                                   icon: 'lock',      group: 'COMBAT / RP' },
  { id: 'charge',    label: 'Charge Weapon',                                   icon: 'cursor',    group: 'COMBAT / RP' },
  { id: 'weight',    label: 'Weapon Weight',                                   icon: 'layers',    group: 'COMBAT / RP' },
  { id: 'inspect',   label: 'Inspect & Ammo',                                  icon: 'search',    group: 'INTERACTION' },
  { id: 'wname',     label: 'Weapon Name',                                     icon: 'book',      group: 'INTERACTION' },
  { id: 'poses',     label: 'Showcase Poses',                                  icon: 'cursor',    group: 'INTERACTION' },
  { id: 'nodraw',    label: 'No-Draw Zones',                                   icon: 'alert',     group: 'WORLD' },
  { id: 'vehicle',   label: 'Vehicle Hiding',                                  icon: 'configure', group: 'WORLD' },
  { id: 'logging',   label: 'Drop Logging',                                    icon: 'clipboard', group: 'WORLD' },
]

const GROUPS = ['ESSENTIALS', 'COMBAT / RP', 'INTERACTION', 'WORLD']

export default function AdminDashboard() {
  const [open, setOpen] = useState(false)
  const [active, setActive] = useState('general')
  const [cfg, setCfg] = useState<any>(null)
  const [version, setVersion] = useState('v2.0')

  useNuiEvent<any>('openAdmin', (data) => {
    setCfg(data?.config ?? {})
    if (data?.version) setVersion(data.version)
    setActive('general')
    setOpen(true)
  })
  useNuiEvent('closeAdmin', () => setOpen(false))

  const close = useCallback(() => {
    setOpen(false)
    fetchNui('adminClose')
  }, [])

  useEffect(() => {
    if (!open) return
    const onKey = (e: KeyboardEvent) => { if (e.key === 'Escape') close() }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [open, close])

  // Path-based updater: update("Jamming.Cooldown", 8) writes into the draft.
  const update = useCallback((path: string, value: unknown) => {
    setCfg((prev: any) => {
      const next = structuredClone(prev ?? {})
      const keys = path.split('.')
      let node = next
      for (let i = 0; i < keys.length - 1; i++) {
        node[keys[i]] = node[keys[i]] ?? {}
        node = node[keys[i]]
      }
      node[keys[keys.length - 1]] = value
      return next
    })
  }, [])

  const save = useCallback(() => {
    fetchNui('adminSave', cfg)
    setOpen(false)
  }, [cfg])

  if (!open || !cfg) return null

  const activeItem = RAIL.find((r) => r.id === active)

  return (
    <div className="mbt-admin-overlay">
      <div className="mbt-admin">
        {/* Close (top-right corner of the panel) */}
        <button className="mbt-admin__close" onClick={close} aria-label="Close">
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none">
            <path d="M6 6l12 12M18 6 6 18" stroke="currentColor" strokeWidth="2" strokeLinecap="round" />
          </svg>
        </button>

        {/* ── Rail ── */}
        <nav className="mbt-admin__rail">
          <div className="mbt-rail__logo">
            <span className="ic"><Icon name="logo" size={24} /></span>
            <div><b>MALIBUTECH</b><span>MALISLING</span></div>
          </div>

          {GROUPS.map((group) => (
            <div key={group}>
              <div className="mbt-rail__group">{group}</div>
              {RAIL.filter((r) => r.group === group).map((it) => (
                <button
                  key={it.id}
                  className={`mbt-rail__item${active === it.id ? ' is-active' : ''}`}
                  onClick={() => setActive(it.id)}
                >
                  <span className="ic"><Icon name={it.icon} size={18} /></span>
                  <span className="mbt-rail__tx">
                    <span className="mbt-rail__label">{it.label}</span>
                    {it.hint && <span className="mbt-rail__hint">{it.hint}</span>}
                  </span>
                </button>
              ))}
            </div>
          ))}

          <div className="mbt-rail__spacer" />
          <div className="mbt-rail__status">
            <span className="sdot" />
            <div><b>Running</b><small>Resource status</small></div>
            <span className="ver">{version}</span>
          </div>
        </nav>

        {/* ── Center ── */}
        <div className="mbt-admin__center">
          <div className="mbt-admin__crumb">Configuration <span style={{ opacity: .5 }}>›</span> <b>{activeItem?.label}</b></div>
          <div className="mbt-admin__head">
            <div>
              <span className="mbt-admin__title">{activeItem?.label}</span>
              <div className="mbt-admin__meta">Applies live on save</div>
            </div>
            <div className="mbt-admin__head-sp" />
            <button className="mbt-btn-ghost" onClick={close}>
              <Icon name="back" size={14} /> Close
            </button>
            <button className="mbt-btn-primary" onClick={save}>
              <Icon name="save" size={14} /> Save &amp; Apply
            </button>
          </div>

          {active === 'general' && <GeneralSection config={cfg} update={update} />}
          {active !== 'general' && (
            <div className="mbt-section">
              <div className="mbt-section__head">
                <span className="mbt-section__ic"><Icon name={activeItem?.icon ?? 'configure'} size={16} /></span>
                <div className="mbt-section__head-tx">
                  <h4 className="mbt-section__title">{activeItem?.label}</h4>
                  <p className="mbt-section__sub">Section coming next phase.</p>
                </div>
              </div>
            </div>
          )}
        </div>

        {/* ── Overview ── */}
        <aside className="mbt-admin__overview">
          <div className="mbt-ov__label"><Icon name="layers" size={12} /> FEATURE OVERVIEW</div>
          <div className="mbt-ov__summary">
            {[
              ['Suppressor Heat', cfg?.SuppressorHeat?.Enabled],
              ['Weapon Inspect', cfg?.Inspect?.Enabled],
              ['Weapon Safety', cfg?.Safety?.Enabled],
              ['No-Draw Zones', cfg?.NoDrawZones?.Enabled],
              ['Drop Logging', cfg?.WeaponDrop?.Logging?.Enabled],
              ['Tactical Sling', cfg?.TacticalSling?.Enabled],
            ].map(([label, on]) => (
              <div key={label as string} className="mbt-ov__row">
                <span className="k">{label}</span>
                <span className={`v ${on ? 'is-on' : 'is-off'}`}>{on ? 'On' : 'Off'}</span>
              </div>
            ))}
          </div>
          <div className="mbt-ov__tip">
            <span className="ic"><Icon name="help" size={15} /></span>
            <div>
              <b>LIVE APPLY</b>
              <p>Changes apply to every connected player the moment you hit Save. Keybinds and language stay in config.lua.</p>
            </div>
          </div>
        </aside>
      </div>
    </div>
  )
}
