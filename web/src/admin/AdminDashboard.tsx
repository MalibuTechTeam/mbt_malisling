import { useState, useEffect, useCallback, useRef, type ComponentType } from 'react'
import { useNuiEvent } from '../utils/useNuiEvent'
import { fetchNui } from '../utils/fetchNui'
import { Icon, type IconName } from './ui/Icon'
import type { SectionProps } from './sections/parts'
import { CoreSection, InterfaceSection } from './sections/GeneralSection'
import { HolsterSection } from './sections/HolsterSection'
import { DropVisualSection, DespawnSection } from './sections/WeaponDropSection'
import { JammingSection, SuppressorSection, SafetySection, ChargeSection, WeightSection, LowReadySection } from './sections/CombatSections'
import { InspectSection, WeaponNameSection, PosesSection, ThrowSection, ChainOfCustodySection, ShellCasingsSection, HandoffSection, SerialsSection, ConcealedCarrySection, PatDownSection, AmmoSharingSection } from './sections/InteractionSections'
import { NoDrawSection, VehicleSection, TrunkRackSection, WeaponRackSection, TrunkPositionsSection } from './sections/WorldSections'
import { PositionsSection, SlingPositionsSection, type Job, type EditTarget } from './sections/PositionsSection'
import { PropEditorOverlay } from './PropEditorOverlay'
import { TrunkEditorOverlay } from './TrunkEditorOverlay'
import './Admin.css'

/**
 * AdminDashboard — the malisling admin config panel. Brand-coherent with the
 * mbt_elevator Control-Room dashboard (shared --mbt-* design system + ConfigRail
 * styling): rail + center + overview.
 *
 * The rail navigates by CATEGORY (not per-feature) — malisling has many small
 * features, so each category page stacks several feature cards (fills the page;
 * no "2-toggle ghost pages").
 */

interface Category {
  id: string
  label: string
  hint: string
  icon: IconName
  // An entry can be a single section or an array of sections rendered stacked
  // in a single grid cell (see .mbt-admin__section-stack in Admin.css).
  sections: (ComponentType<SectionProps> | ComponentType<SectionProps>[])[]
}

const CATEGORIES: Category[] = [
  { id: 'core',        label: 'Core',        hint: 'Sling, holster, drop', icon: 'layers',
    // Height-paired for the equal-height grid: the two tall cards (Core's 3 toggles,
    // Interface's 2x2 placement picker) share row 1; the three ~equal mid cards fill
    // rows 2-3 with the shortest (Drop Visual) closing — keeps the columns balanced.
    sections: [CoreSection, InterfaceSection, HolsterSection, DespawnSection, DropVisualSection] },
  { id: 'handling',    label: 'Handling',    hint: 'Feel and combat RP',     icon: 'target',
    // Ordered to pair similar heights for the equal-height grid: the two tall
    // cards (Suppressor, Safety) share row 1; the two short 2-input cards
    // (Jamming, Charge) share row 2; Weight closes.
    sections: [SuppressorSection, SafetySection, JammingSection, ChargeSection, WeightSection, LowReadySection] },
  { id: 'interaction', label: 'Interaction', hint: 'Inspect, throw, carry', icon: 'cursor',
    // Height-paired: Inspect + Throw (both tall) row 1; Concealed Carry (tall) +
    // the [Weapon Name, Showcase Poses] stack (right) row 2 — the two short cards
    // stacked together fill the tall Concealed Carry card's height; Handoff + Ammo
    // Sharing (both mid) row 3.
    sections: [InspectSection, ThrowSection, ConcealedCarrySection, [WeaponNameSection, PosesSection], HandoffSection, AmmoSharingSection] },
  { id: 'forensics',   label: 'Forensics',   hint: 'Serial, custody, casings', icon: 'search',
    // Evidence / investigation systems, grouped by admin intent (not animation) —
    // Pat-down lives here as a police-discovery tool. Order: the foundational pair
    // (Weapon Serials = the backbone, Chain of Custody) leads in row 1; the two tall
    // application cards (Shell Casings, Pat-down) share row 2.
    sections: [SerialsSection, ChainOfCustodySection, ShellCasingsSection, PatDownSection] },
  { id: 'world',       label: 'World',       hint: 'Zones, vehicle, racks',  icon: 'globe',
    // Height-paired for the equal-height grid: the two mid cards (No-Draw, Vehicle)
    // share row 1; the two tall cards (Trunk Rack, Weapon Rack) share row 2.
    sections: [NoDrawSection, VehicleSection, TrunkRackSection, WeaponRackSection] },
]

// MalibuTech links in the rail. Brand constants, not server config — a server owner
// tunes their server here, not who wrote the script.
// 'brand' renders the real logo file as a mask instead of an icon path: the MBT mark
// is an interlocking M/T monogram that no 24px line glyph reproduces honestly, and
// masking it keeps currentColor working so it still lights up on hover.
const BRAND_LINKS: { icon: IconName | 'brand'; href: string; title: string }[] = [
  { icon: 'brand',   href: 'https://malibutechteam.com/',                      title: 'MalibuTech — all our scripts' },
  { icon: 'docs',    href: 'https://malibutechteam.com/docs/mbt-malisling/introduction', title: 'Documentation' },
  { icon: 'discord', href: 'https://discord.gg/TaDRKtfaQt',                    title: 'Discord — support and updates' },
  { icon: 'github',  href: 'https://github.com/MalibuTechTeam/mbt_malisling',  title: 'GitHub — source, issues, releases' },
]

// Feature overview — every on/off toggle, keyed to the exact config path its
// section writes (keep in sync when adding a feature). Drives the gauge + list.
const FEATURES: { label: string; path: string; cat: string }[] = [
  // Core — sling, holster, drop (in page-card order).
  { label: 'Holster Sounds', path: 'Sounds.Enabled',              cat: 'Core' },
  { label: 'Drop Despawn',   path: 'WeaponDrop.Despawn.Enabled',  cat: 'Core' },
  { label: 'Tactical Sling', path: 'TacticalSling.Enabled',       cat: 'Core' },
  // Handling — feel and combat RP.
  { label: 'Suppressor Heat',path: 'SuppressorHeat.Enabled',      cat: 'Handling' },
  { label: 'Weapon Safety',  path: 'Safety.Enabled',              cat: 'Handling' },
  { label: 'Condition Pips', path: 'ConditionHUD.Enabled',        cat: 'Handling' },
  { label: 'Weapon Jamming', path: 'Jamming.Enabled',             cat: 'Handling' },
  { label: 'Charge Weapon',  path: 'ChargeWeapon.Enabled',        cat: 'Handling' },
  { label: 'Weapon Weight',  path: 'WeaponWeight.Enabled',        cat: 'Handling' },
  { label: 'Low Ready',      path: 'LowReady.Enabled',            cat: 'Handling' },
  // Interaction — inspect, throw, carry (in page-card order).
  { label: 'Weapon Inspect', path: 'Inspect.Enabled',             cat: 'Interaction' },
  { label: 'Weapon Throw',   path: 'Throw.Enabled',               cat: 'Interaction' },
  { label: 'Concealed Carry',path: 'ConcealedCarry.Enabled',      cat: 'Interaction' },
  { label: 'Weapon Name',    path: 'WeaponName.Enabled',          cat: 'Interaction' },
  { label: 'Showcase Poses', path: 'ShowcasePoses.Enabled',       cat: 'Interaction' },
  { label: 'Weapon Handoff', path: 'Handoff.Enabled',             cat: 'Interaction' },
  { label: 'Ammo Sharing',   path: 'AmmoSharing.Enabled',         cat: 'Interaction' },
  // Forensics — serial, custody, casings (in page-card order: Serials backbone first).
  { label: 'Serial Ensure',  path: 'Serials.EnsureGeneration',    cat: 'Forensics' },
  { label: 'Chain of Custody',path: 'ChainOfCustody.Enabled',     cat: 'Forensics' },
  { label: 'Shell Casings',  path: 'ShellCasings.Enabled',        cat: 'Forensics' },
  { label: 'Pat-down',       path: 'PatDown.Enabled',             cat: 'Forensics' },
  // World — zones, vehicle, racks (in page-card order).
  { label: 'No-Draw Zones',  path: 'NoDrawZones.Enabled',         cat: 'World' },
  { label: 'Vehicle Hiding', path: 'VehicleHiding.Enabled',       cat: 'World' },
  { label: 'Trunk Rack',     path: 'VehicleTrunkRack.Enabled',    cat: 'World' },
  { label: 'Weapon Rack',    path: 'WeaponRack.Enabled',          cat: 'World' },
]
const OV_CATS = ['Core', 'Handling', 'Interaction', 'Forensics', 'World'] as const

const getPath = (obj: any, path: string) => path.split('.').reduce((o, k) => (o == null ? o : o[k]), obj)

/** Open an external URL from inside the game.
 *  A plain target=_blank does nothing in FiveM's CEF — there is no browser to open a tab
 *  in. The `openUrl` native is the way out, and it raises FiveM's own "you are leaving"
 *  confirmation. Falls back to window.open so the links still work in browser dev. */
const openExternal = (url: string) => {
  const invoke = (window as any).invokeNative
  if (typeof invoke === 'function') invoke('openUrl', url)
  else window.open(url, '_blank', 'noreferrer')
}

export default function AdminDashboard() {
  const [open, setOpen] = useState(false)
  const [active, setActive] = useState('core')
  const [cfg, setCfg] = useState<any>(null)
  const [version, setVersion] = useState('v2.0')
  const [savePulse, setSavePulse] = useState(false) // one-shot pulse on save
  const [jobs, setJobs] = useState<Job[]>([])       // framework job list (lazy)
  const [editing, setEditing] = useState<EditTarget | null>(null) // live position editor
  const [trunkEditing, setTrunkEditing] = useState<{ model: string; vclass: number; off: any; view?: any } | null>(null)
  const [trunkRefresh, setTrunkRefresh] = useState(0) // bump → TrunkPositionsSection re-pulls its list after a save
  const [closing, setClosing] = useState(false)     // playing the exit animation before unmount
  const [oxPatch, setOxPatch] = useState<string | false>(false) // ox auto-patch failure reason (CRITICAL → center alert)
  const [warnings, setWarnings] = useState<{ code: string; msg: string }[]>([]) // non-critical integration warnings → discreet right chips
  const [updateInfo, setUpdateInfo] = useState<{ current: string; latest: string; url: string } | null>(null) // newer release on GitHub, else null
  const baseline = useRef('')                       // last-saved snapshot
  const closeTimer = useRef<number | null>(null)    // deferred-unmount timer
  // `dirty` is derived further down, after the draft exists. The close handler is wired
  // into a keydown effect, so it reads the flag through a ref: no re-subscribing the
  // listener on every keystroke, and no stale value inside the callback.
  const dirtyRef = useRef(false)

  useNuiEvent<any>('openAdmin', (data) => {
    const c = data?.config ?? {}
    setCfg(c)
    baseline.current = JSON.stringify(c)
    if (data?.version) setVersion(data.version)
    setOxPatch(typeof data?.oxPatch === 'string' ? data.oxPatch : false)
    setWarnings(Array.isArray(data?.warnings) ? data.warnings : [])
    setUpdateInfo(data?.update?.latest ? data.update : null)
    setActive('core')
    setEditing(null)
    setTrunkEditing(null)
    // Cancel any in-flight close so a re-open snaps back instantly.
    if (closeTimer.current) { window.clearTimeout(closeTimer.current); closeTimer.current = null }
    setClosing(false)
    setOpen(true)
    // Lazy-load the framework job list for the position editor.
    fetchNui('getJobs').then((list: any) => setJobs(Array.isArray(list) ? list : []))
  })

  // Play the exit animation, then unmount. `notify` releases NUI focus (user-
  // initiated close); the game-initiated closeAdmin event already dropped it.
  const beginClose = useCallback((notify: boolean) => {
    if (closeTimer.current) return
    setClosing(true)
    closeTimer.current = window.setTimeout(() => {
      closeTimer.current = null
      setClosing(false)
      setOpen(false)
      if (notify) fetchNui('adminClose')
    }, 150)
  }, [])

  // The game closing the panel (death, resource stop) is not a choice — it never asks.
  useNuiEvent('closeAdmin', () => beginClose(false))

  // Closing with edits pending asks first. Escape is a reflex key and the close control
  // sits a panel away from Save, so without this a long tuning session dies in silence.
  const [confirmClose, setConfirmClose] = useState(false)
  const close = useCallback(() => {
    if (dirtyRef.current) { setConfirmClose(true); return }
    beginClose(true)
  }, [beginClose])

  useEffect(() => {
    if (!open) return
    const onKey = (e: KeyboardEvent) => {
      // A live editor owns Escape while it's open (it closes itself first); the
      // dashboard must not also close out from under it.
      if (editing || trunkEditing) return
      if (e.key === 'Escape') close()
    }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [open, close, editing, trunkEditing])

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
    fetchNui('adminSave', cfg)   // panel stays open; feedback is on the button
    baseline.current = JSON.stringify(cfg)
    setSavePulse(true)
    window.setTimeout(() => setSavePulse(false), 560)
  }, [cfg])

  // Discard — revert the draft to the last-saved snapshot (no NUI round-trip).
  const discard = useCallback(() => {
    setCfg(JSON.parse(baseline.current))
  }, [])

  if (!open || !cfg) return null

  // Derived: the draft differs from the last-saved snapshot (drives Save/Discard).
  const dirty = JSON.stringify(cfg) !== baseline.current
  dirtyRef.current = dirty   // read by close(), which lives above this line

  const activeCat = CATEGORIES.find((c) => c.id === active) ?? CATEGORIES[0]
  const isPositions = active === 'positions'
  const headLabel = isPositions ? 'Positions' : activeCat.label
  const headHint = isPositions
    ? 'Body and trunk placement · set in-world · saved to oxmysql'
    : `${activeCat.hint} · ${activeCat.sections.length} features · applies live on save`

  // Real feature state for the overview — derived from the same config paths the
  // section toggles write (single source of truth, always accurate). Grouped by
  // category and computed live from the draft.
  const feats = FEATURES.map((f) => ({ ...f, on: !!getPath(cfg, f.path) }))
  const activeCount = feats.filter((f) => f.on).length

  return (
    <>
    <div className={`mbt-admin-overlay${editing || trunkEditing ? ' is-editing' : ''}${closing ? ' is-closing' : ''}`}>
      <div className="mbt-admin">

        {/* Close lives in the panel's top-right corner — over the overview column, where a
            dismiss control is always looked for, and a full column away from Save & Apply
            so the click that leaves can't be the one that meant to save. A child of the
            panel, not of the column: that column scrolls, and this must not scroll away. */}
        <button className="mbt-admin__close" onClick={close} title="Close (ESC)" aria-label="Close dashboard">
          <svg width="15" height="15" viewBox="0 0 24 24" fill="none" aria-hidden="true">
            <path d="M6 6l12 12M18 6L6 18" stroke="currentColor" strokeWidth="2" strokeLinecap="round" />
          </svg>
        </button>

        {/* ── Rail ── */}
        <nav className="mbt-admin__rail">
          <div className="mbt-rail__logo">
            <span className="ic"><img src={`${import.meta.env.BASE_URL}logo_mbt.svg`} alt="MalibuTech" /></span>
            <div><b>MBT MALISLING</b></div>
          </div>

          <div className="mbt-rail__group">Categories</div>
          {CATEGORIES.map((cat) => (
            <button
              key={cat.id}
              className={`mbt-rail__item${active === cat.id ? ' is-active' : ''}`}
              aria-current={active === cat.id ? 'page' : undefined}
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

          {/* Weapon position editor — special live-edit page (not a card grid). */}
          <button
            className={`mbt-rail__item${isPositions ? ' is-active' : ''}`}
            aria-current={isPositions ? 'page' : undefined}
            onClick={() => setActive('positions')}
          >
            <span className="ic"><Icon name="configure" size={18} /></span>
            <span className="mbt-rail__tx">
              <span className="mbt-rail__label">Positions</span>
              <span className="mbt-rail__hint">Body and trunk placement</span>
            </span>
            <span className="mbt-rail__count">3</span>
          </button>

          <div className="mbt-rail__spacer" />

          {/* No Exit item here any more: closing is an action, not a destination, and
              styling it like a seventh category said otherwise. The X in the panel's
              top-right corner owns it now, with Escape as the shortcut. */}

          {/* One card, two states: the version you run and whether it's current are the
              same fact about the same thing, so an update recolours this card instead of
              stacking a second one. When it's a link the click goes through openExternal. */}
          {(() => {
            const Tag = updateInfo ? 'a' : 'div'
            const linkProps = updateInfo
              ? { href: updateInfo.url,
                  onClick: (e: React.MouseEvent) => { e.preventDefault(); openExternal(updateInfo.url) },
                  title: `${updateInfo.current} → ${updateInfo.latest} — open the release page` }
              : {}
            return (
              <Tag className={`mbt-rail__status${updateInfo ? ' has-update' : ''}`} {...linkProps}>
                <span className="sdot" />
                <div>
                  {/* An update takes over the primary line — on the secondary one it read as
                      decoration and got missed. "Running" is what the green dot already says. */}
                  <b>{updateInfo ? 'Update available' : 'Running'}</b>
                  <small>{updateInfo ? `${updateInfo.latest} on GitHub` : 'Resource status'}</small>
                </div>
                {/* The chip is dropped while updating: the card is about the NEW version, so
                    repeating the one you're on just competes with it. */}
                {!updateInfo && <span className="ver">{version}</span>}
              </Tag>
            )
          })()}

          {/* MalibuTech links close the column: the quietest thing last, under the status
              plate. Real hrefs so they read as links and carry a middle-click in dev, but
              the click is handled by openExternal — see it for why. */}
          <div className="mbt-rail__links">
            {BRAND_LINKS.map((l) => (
              <a key={l.href} className="mbt-rail__link" href={l.href}
                 onClick={(e) => { e.preventDefault(); openExternal(l.href) }}
                 title={l.title} aria-label={l.title}>
                {l.icon === 'brand' ? (
                  <span className="mbt-rail__brandmark" style={{
                    maskImage: `url(${import.meta.env.BASE_URL}logo_mbt.svg)`,
                    WebkitMaskImage: `url(${import.meta.env.BASE_URL}logo_mbt.svg)`,
                  }} />
                ) : (
                  <Icon name={l.icon} size={15} />
                )}
              </a>
            ))}
          </div>
        </nav>

        {/* ── Center ── */}
        <div className="mbt-admin__center">
          <div className="mbt-admin__crumb">Configuration <span style={{ opacity: .5 }}>›</span> <b>{headLabel}</b></div>
          <div className="mbt-admin__head">
            <div>
              <span className="mbt-admin__title">{headLabel}</span>
              <div className="mbt-admin__meta">{headHint}</div>
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

          {/* Critical ox_inventory patch failure — kept in the center so it's
              visible even at narrow widths where the overview is hidden. */}
          {oxPatch && oxPatch !== 'ok' ? (
            <div className="mbt-ov__warn mbt-admin__alert" role="alert">
              <span className="mbt-ov__warn-ic"><Icon name="alert" size={15} /></span>
              <div>
                <b>ox_inventory patch failed</b>
                <p>{oxPatch}. Run the installer for your OS from <code>tools/</code>, then restart — the weapon-on-back holster flow needs it.</p>
              </div>
            </div>
          ) : null}

          <div className="mbt-admin__sections">
            {isPositions ? (
              <>
                <PositionsSection jobs={jobs} onEdit={(t) => setEditing(t)} />
                <TrunkPositionsSection config={cfg} update={update} refreshKey={trunkRefresh}
                  onEdit={(s) => setTrunkEditing({ model: s.model, vclass: s.class, off: s.off, view: s.view })} />
                <SlingPositionsSection config={cfg} update={update} jobs={jobs}
                  onEdit={(variant, g) => setEditing({ wtype: 'sling:' + variant, job: 'default', gender: g })} />
              </>
            ) : (
              activeCat.sections.map((item, i) =>
                Array.isArray(item) ? (
                  <div key={`${active}-${i}`} className="mbt-admin__section-stack">
                    {(item as ComponentType<SectionProps>[]).map((Section, j) => (
                      <Section key={j} config={cfg} update={update} />
                    ))}
                  </div>
                ) : (() => { const Section = item as ComponentType<SectionProps>; return <Section key={`${active}-${i}`} config={cfg} update={update} /> })()
              )
            )}
          </div>
        </div>

        {/* ── Overview (right sidebar — mirrors elevator's config view) ── */}
        <aside className="mbt-admin__overview">
          {/* Column header, elevator's icon+label lockup. It sits OUTSIDE the scroll area
              and on the same line as the close button, which is pinned to the panel: a
              title that slid away under a fixed button would look broken. Naming the
              column here lets the list below drop its own label. */}
          <div className="mbt-ov__head">
            <Icon name="layers" size={12} /> SLING FEATURE OVERVIEW
          </div>

          <div className="mbt-ov__body">
          {/* Active-features gauge — a glanceable summary of the list below
              (mirrors the elevator overview's data-driven top block). */}
          <div className="mbt-ov__gauge">
            <div className="mbt-ov__gauge-head">
              <span className="mbt-ov__gauge-n">{activeCount}</span>
              <span className="mbt-ov__gauge-d">/ {feats.length} active</span>
            </div>
            <div className="mbt-ov__segs" aria-hidden="true">
              {feats.map((f) => (
                <span key={f.path} className={f.on ? 'is-on' : ''} />
              ))}
            </div>
          </div>

          <div className="mbt-ov__summary">
            {OV_CATS.map((cat) => (
              <div key={cat} className="mbt-ov__group">
                <div className="mbt-ov__grouphead">{cat}</div>
                {feats.filter((f) => f.cat === cat).map((f) => (
                  <div key={f.path} className={`mbt-ov__feat${f.on ? ' is-on' : ''}`} title={f.on ? 'On' : 'Off'}>
                    <span className="mbt-ov__dot" />
                    <span className="mbt-ov__featname">{f.label}</span>
                  </div>
                ))}
              </div>
            ))}
          </div>
          <div className="mbt-ov__spacer" />
          {/* Non-critical integration warnings — discreet amber chips above the
              LIVE APPLY note, shown only when present (status-by-exception). The
              gauge stays the hero up top; critical failures use the centered
              role="alert" banner instead. */}
          {warnings.map((w) => (
            <div key={w.code} className="mbt-ov__warn-chip">
              <Icon name="alert" size={13} />
              <span>{w.msg}</span>
            </div>
          ))}
          <div className="mbt-ov__tip">
            <span className="ic"><Icon name="help" size={15} /></span>
            <div>
              <b>LIVE APPLY</b>
              {/* Answers the three things an owner actually wonders here, in order: does
                  this hit everyone, must I restart, will it survive one. */}
              <p>Saving reaches every player at once — no restart — and is stored in the database. Keybinds and language are set in config.lua.</p>
            </div>
          </div>
          </div>
        </aside>

      {/* Leaving with edits pending is the one place this panel can destroy work, so it
          is the one place that stops and asks. Discard is styled as the destructive
          option; keeping the draft is the safe default and takes the primary button. */}
      {confirmClose && (
        <div className="mbt-admin__confirm" role="alertdialog" aria-modal="true" aria-labelledby="mbt-confirm-t">
          <div className="mbt-admin__confirm-card">
            <b id="mbt-confirm-t">Unsaved changes</b>
            <p>Your edits haven't been applied yet. Close the dashboard and lose them?</p>
            <div className="mbt-admin__confirm-actions">
              <button type="button" className="mbt-btn-ghost is-danger"
                      onClick={() => { setConfirmClose(false); beginClose(true) }}>
                Discard &amp; close
              </button>
              <button type="button" className="mbt-btn-primary" autoFocus
                      onClick={() => setConfirmClose(false)}>
                Keep editing
              </button>
            </div>
          </div>
        </div>
      )}
      </div>
    </div>
    {editing ? (
      <PropEditorOverlay
        wtype={editing.wtype}
        job={editing.job}
        gender={editing.gender}
        onClose={() => setEditing(null)}
      />
    ) : null}
    {trunkEditing ? (
      <TrunkEditorOverlay
        model={trunkEditing.model}
        vclass={trunkEditing.vclass}
        off={trunkEditing.off}
        view={trunkEditing.view}
        onClose={() => setTrunkEditing(null)}
        onSaved={() => setTrunkRefresh((n) => n + 1)}
      />
    ) : null}
    </>
  )
}
