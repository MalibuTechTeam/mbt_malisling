import { useState, useEffect, useCallback, useRef, type ComponentType } from 'react'
import { useNuiEvent } from '../utils/useNuiEvent'
import { fetchNui } from '../utils/fetchNui'
import { Icon, type IconName } from './ui/Icon'
import type { SectionProps } from './sections/parts'
import { CoreSection, InterfaceSection } from './sections/GeneralSection'
import { HolsterSection } from './sections/HolsterSection'
import { DropVisualSection, DespawnSection, DropLoggingSection } from './sections/WeaponDropSection'
import { JammingSection, SuppressorSection, SafetySection, ChargeSection, WeightSection } from './sections/CombatSections'
import { InspectSection, WeaponNameSection, PosesSection, ThrowSection } from './sections/InteractionSections'
import { NoDrawSection, VehicleSection } from './sections/WorldSections'
import './Admin.css'

/**
 * AdminDashboard — the malisling admin config panel. Brand-coherent with the
 * mbt_elevator Control-Room dashboard (shared --mbt-* design system + ConfigRail
 * styling): rail + center + overview.
 *
 * The rail navigates by CATEGORY (not per-feature) — malisling has many small
 * features, so each category page stacks several feature cards (fills the page;
 * no "2-toggle ghost pages"). Forensics is reserved (coming soon) until it ships;
 * Tactical Sling stays out of the menu until its stream asset exists.
 */

interface Category {
  id: string
  label: string
  hint: string
  icon: IconName
  sections: ComponentType<SectionProps>[]
}

const CATEGORIES: Category[] = [
  { id: 'core',        label: 'Core',        hint: 'Sling · holster · drop', icon: 'layers',
    sections: [CoreSection, HolsterSection, DropVisualSection, DespawnSection, InterfaceSection, DropLoggingSection] },
  { id: 'handling',    label: 'Handling',    hint: 'Feel & combat RP',       icon: 'target',
    // Ordered to pair similar heights for the equal-height grid: the two tall
    // cards (Suppressor, Safety) share row 1; the two short 2-input cards
    // (Jamming, Charge) share row 2; Weight closes.
    sections: [SuppressorSection, SafetySection, JammingSection, ChargeSection, WeightSection] },
  { id: 'interaction', label: 'Interaction', hint: 'Inspect · name · poses', icon: 'cursor',
    // Height-paired for the equal-height grid: the two tall cards (Inspect,
    // Throw) share row 1; the shorter Name + the tiny Poses share row 2.
    sections: [InspectSection, ThrowSection, WeaponNameSection, PosesSection] },
  { id: 'world',       label: 'World',       hint: 'Zones · vehicle',        icon: 'globe',
    sections: [NoDrawSection, VehicleSection] },
]

export default function AdminDashboard() {
  const [open, setOpen] = useState(false)
  const [active, setActive] = useState('core')
  const [cfg, setCfg] = useState<any>(null)
  const [version, setVersion] = useState('v2.0')
  const [dirty, setDirty] = useState(false)        // unsaved changes
  const [savePulse, setSavePulse] = useState(false) // one-shot pulse on save
  const baseline = useRef('')                       // last-saved snapshot

  useNuiEvent<any>('openAdmin', (data) => {
    const c = data?.config ?? {}
    setCfg(c)
    baseline.current = JSON.stringify(c)
    setDirty(false)
    if (data?.version) setVersion(data.version)
    setActive('core')
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
      setDirty(JSON.stringify(next) !== baseline.current)
      return next
    })
  }, [])

  const save = useCallback(() => {
    fetchNui('adminSave', cfg)   // panel stays open; feedback is on the button
    baseline.current = JSON.stringify(cfg)
    setDirty(false)
    setSavePulse(true)
    window.setTimeout(() => setSavePulse(false), 560)
  }, [cfg])

  // Discard — revert the draft to the last-saved snapshot (no NUI round-trip).
  const discard = useCallback(() => {
    setCfg(JSON.parse(baseline.current))
    setDirty(false)
  }, [])

  if (!open || !cfg) return null

  const activeCat = CATEGORIES.find((c) => c.id === active) ?? CATEGORIES[0]

  // Key feature flags, shared by the gauge and the overview list below it.
  const features: [string, boolean][] = [
    ['Suppressor Heat', !!cfg?.SuppressorHeat?.Enabled],
    ['Weapon Inspect', !!cfg?.Inspect?.Enabled],
    ['Weapon Safety', !!cfg?.Safety?.Enabled],
    ['Condition HUD', !!cfg?.ConditionHUD?.Enabled],
    ['No-Draw Zones', !!cfg?.NoDrawZones?.Enabled],
    ['Drop Logging', !!cfg?.WeaponDrop?.Logging?.Enabled],
  ]
  const activeCount = features.filter(([, on]) => on).length

  return (
    <div className="mbt-admin-overlay">
      <div className="mbt-admin">

        {/* ── Rail ── */}
        <nav className="mbt-admin__rail">
          <div className="mbt-rail__logo">
            <span className="ic"><Icon name="logo" size={24} /></span>
            <div><b>MBT MALISLING</b><span>MALIBUTECH</span></div>
          </div>

          <div className="mbt-rail__group">Categories</div>
          {CATEGORIES.map((cat) => (
            <button
              key={cat.id}
              className={`mbt-rail__item${active === cat.id ? ' is-active' : ''}`}
              onClick={() => setActive(cat.id)}
            >
              <span className="ic"><Icon name={cat.icon} size={18} /></span>
              <span className="mbt-rail__tx">
                <span className="mbt-rail__label">{cat.label}</span>
                <span className="mbt-rail__hint">{cat.hint}</span>
              </span>
              <span className="mbt-rail__count">{cat.sections.length}</span>
            </button>
          ))}

          {/* Reserved — appears as a real category once it ships. */}
          <div className="mbt-rail__item is-soon" aria-disabled="true">
            <span className="ic"><Icon name="search" size={18} /></span>
            <span className="mbt-rail__tx">
              <span className="mbt-rail__label">Forensics</span>
              <span className="mbt-rail__hint">Serial · custody · casings</span>
            </span>
            <span className="mbt-rail__count">soon</span>
          </div>

          <div className="mbt-rail__spacer" />

          <button className="mbt-rail__item mbt-rail__exit" onClick={close}>
            <span className="ic">
              <svg width="18" height="18" viewBox="0 0 24 24" fill="none">
                <path d="M14 8V6a2 2 0 0 0-2-2H6a2 2 0 0 0-2 2v12a2 2 0 0 0 2 2h6a2 2 0 0 0 2-2v-2" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
                <path d="M10 12h11M18 9l3 3-3 3" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
              </svg>
            </span>
            <span className="mbt-rail__tx"><span className="mbt-rail__label">Exit</span></span>
          </button>

          <div className="mbt-rail__status">
            <span className="sdot" />
            <div><b>Running</b><small>Resource status</small></div>
            <span className="ver">{version}</span>
          </div>
        </nav>

        {/* ── Center ── */}
        <div className="mbt-admin__center">
          <div className="mbt-admin__crumb">Configuration <span style={{ opacity: .5 }}>›</span> <b>{activeCat.label}</b></div>
          <div className="mbt-admin__head">
            <div>
              <span className="mbt-admin__title">{activeCat.label}</span>
              <div className="mbt-admin__meta">{activeCat.hint} · {activeCat.sections.length} features · applies live on save</div>
            </div>
            <div className="mbt-admin__head-sp" />
            {dirty ? (
              <span className="mbt-admin__dirty"><i />Unsaved changes</span>
            ) : null}
            {dirty ? (
              <button type="button" className="mbt-btn-ghost" onClick={discard}>
                Discard
              </button>
            ) : null}
            <button
              type="button"
              className={`mbt-btn-primary${savePulse ? ' is-complete' : ''}`}
              onClick={save}
              disabled={!dirty}
            >
              <Icon name="save" size={14} /> Save &amp; Apply
            </button>
          </div>

          <div className="mbt-admin__sections">
            {activeCat.sections.map((Section, i) => (
              <Section key={`${active}-${i}`} config={cfg} update={update} />
            ))}
          </div>
        </div>

        {/* ── Overview (right sidebar — mirrors elevator's config view) ── */}
        <aside className="mbt-admin__overview">
          {/* Active-features gauge — a glanceable summary of the list below
              (mirrors the elevator overview's data-driven top block). */}
          <div className="mbt-ov__gauge">
            <div className="mbt-ov__gauge-head">
              <span className="mbt-ov__gauge-n">{activeCount}</span>
              <span className="mbt-ov__gauge-d">/ {features.length} active</span>
            </div>
            <div className="mbt-ov__segs" aria-hidden="true">
              {features.map(([label, on]) => (
                <span key={label} className={on ? 'is-on' : ''} />
              ))}
            </div>
          </div>

          <div className="mbt-ov__label"><Icon name="layers" size={12} /> FEATURE OVERVIEW</div>
          <div className="mbt-ov__summary">
            {features.map(([label, on]) => (
              <div key={label} className="mbt-ov__row">
                <span className="k">{label}</span>
                <span className={`v ${on ? 'is-on' : 'is-off'}`}>{on ? 'On' : 'Off'}</span>
              </div>
            ))}
          </div>
          <div className="mbt-ov__spacer" />
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
