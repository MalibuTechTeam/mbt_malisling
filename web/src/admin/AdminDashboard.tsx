import { useState, useEffect, useLayoutEffect, useCallback, useRef, Fragment } from 'react'
import { useNuiEvent } from '../utils/useNuiEvent'
import { fetchNui } from '../utils/fetchNui'
import { Icon, type IconName } from './ui/Icon'
import type { SectionComponent } from './sections/parts'
import { CoreSection, PromptSection, AccentSection, MultiWeaponSection, HiddenByJobSection } from './sections/GeneralSection'
import { HolsterSection } from './sections/HolsterSection'
import { DropVisualSection, DespawnSection } from './sections/WeaponDropSection'
import { JammingSection, SuppressorSection, SafetySection, ChargeSection, WeightSection, LowReadySection, DrawStyleSection } from './sections/CombatSections'
import { InspectSection, WeaponNameSection, PosesSection, ThrowSection, ChainOfCustodySection, ShellCasingsSection, HandoffSection, SerialsSection, ConcealedCarrySection, PatDownSection, AmmoSharingSection } from './sections/InteractionSections'
import { NoDrawSection, VehicleSection, TrunkRackSection, WeaponRackSection, RackPlacementSection, TrunkPositionsSection } from './sections/WorldSections'
import { PositionsSection, SlingPositionsSection, type Job, type EditTarget } from './sections/PositionsSection'
import { PropEditorOverlay } from './PropEditorOverlay'
import { TrunkEditorOverlay } from './TrunkEditorOverlay'
import { GestureOverlay } from './GestureOverlay'
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
  sections: (SectionComponent | SectionComponent[])[]
  /** Renders its own layout instead of the card grid, and is grouped apart in the rail.
   *  Placement is a MODE: the panel hides, you place props in 3D, and each editor writes
   *  its own table immediately rather than joining the draft. It lives in this array all
   *  the same, so the overview can see the features it owns — filed by hand it claimed
   *  Tactical Sling was under Core, on a page the card has never been on. */
  mode?: boolean
}

/**
 * Card order is ROW order: the page draws pairs, left then right, and a pair is only as
 * tidy as its two members are alike in height. Measured heights are in each comment so the
 * next person pairing a new card is not guessing — and `.mbt-admin__row` measures anyway
 * and falls back to top-alignment when a pair turns out mismatched, so a wrong guess costs
 * a gap under one card, never a card inflated with dead space.
 *
 * A nested array is one CELL holding a stack — the way to pair one tall card against two
 * short ones, and the way to say "these two belong together" without merging their code.
 */
const CATEGORIES: Category[] = [
  { id: 'core',        label: 'Core',        hint: 'Sling, drop, visibility', icon: 'layers',
    // Rows: [Core 338 | Hidden By Job 290] · [Multi-Weapon 239 | Despawn 224] · [Drop Visual].
    // The odd one out closes the page and is the SHORTEST card, so the half-row of empty
    // space at the end is the smallest it can be.
    sections: [CoreSection, HiddenByJobSection, MultiWeaponSection, DespawnSection, DropVisualSection] },
  // Prompts, colour and audio: what the script looks and sounds like, which is not what
  // Core is about. Interface sat under a rail entry reading "sling, holster, drop" and was
  // none of the three — you went looking for the accent colour under the weapon settings.
  { id: 'presentation', label: 'Presentation', hint: 'Prompts, colour, audio', icon: 'palette',
    // Rows: [Prompt | Brand Accent] · [Holster Sounds]. One card held placement, style AND
    // colour, which made it 404px against a 228px neighbour — a 177px hole, the biggest on
    // any page. Split, the two halves are near-equal and the page has no hole at all.
    sections: [PromptSection, AccentSection, HolsterSection] },
  { id: 'handling',    label: 'Handling',    hint: 'Feel and combat RP',     icon: 'target',
    // Rows: [Suppressor 342 | Safety 322] · [Jamming 161 | Charge 161] · [Weight 160 |
    // Low Ready 177]. Three even pairs, no odd card left over.
    //
    // Draw Style used to close this page and now lives in Placement. It was filed here because
    // drawing a weapon is handling, which is true and was the wrong axis: every other card on
    // this page is a number you set and read back, while Draw Style is a button that hides the
    // dashboard and puts you in front of your own character. That is what the Placement page
    // is, and it is what an admin is looking for when they go there.
    sections: [SuppressorSection, SafetySection, JammingSection, ChargeSection,
      WeightSection, LowReadySection] },
  { id: 'interaction', label: 'Interaction', hint: 'Inspect, throw, carry', icon: 'cursor',
    // Rows: [Inspect 593 | Throw 623] · [Concealed Carry 367 | Pat-down 376] ·
    // [Name+Poses 392 | Handoff+Ammo 473].
    // Pat-down moved here from Forensics: it and Concealed Carry are the two halves of one
    // mechanic — one hides the weapon, the other finds it — and their thresholds were being
    // tuned on two different pages. Handoff and Ammo Sharing share a cell because they are
    // the same gesture with different cargo.
    sections: [InspectSection, ThrowSection, ConcealedCarrySection, PatDownSection,
      [WeaponNameSection, PosesSection], [HandoffSection, AmmoSharingSection]] },
  { id: 'forensics',   label: 'Forensics',   hint: 'Serial, custody, casings', icon: 'search',
    // One row: [Serials 250 + Chain of Custody 224 | Shell Casings 413]. The serial and the
    // ledger of who carried it are one subject, so they share the left cell and Serials —
    // the backbone the other two hang off — still reads first.
    sections: [[SerialsSection, ChainOfCustodySection], ShellCasingsSection] },
  { id: 'world',       label: 'World',       hint: 'Zones, vehicle, racks',  icon: 'globe',
    // Rows: [Weapon Rack | No-Draw + Vehicle Hiding] · [Trunk Rack | Rack Placement].
    // Weapon Rack was 757px — twice anything else here — because it also configured racks
    // players place themselves. Split out as Rack Placement, what is left pairs against two
    // stacked cards, and the leftover pairs with Trunk Rack. No hole, no odd card.
    sections: [WeaponRackSection, [NoDrawSection, VehicleSection],
      TrunkRackSection, RackPlacementSection] },
  // NOTE: a `mode` category's sections are listed for the overview and the card count ONLY —
  // the page renders them explicitly further down, because each takes props of its own
  // (job list, editor callbacks) that the generic card map cannot supply. Adding one here
  // does not put it on screen.
  // Every card here opens an in-world editor: the dashboard steps aside and you place, or
  // watch, the thing on your own character. That is the axis, not "positions" — which is why
  // Draw Style belongs here and not under Handling with the numbers.
  { id: 'positions',   label: 'Placement',   hint: 'In-world editors', icon: 'configure', mode: true,
    sections: [PositionsSection, TrunkPositionsSection, SlingPositionsSection, DrawStyleSection] },
]

/** DOM id of the slot a card renders into, derived from the label it already declares.
 *  A stacked pair shares its first member's id: they occupy one slot, so one is the
 *  destination for both.
 *
 *  A `function`, not a const arrow: FEATURES below is built at module load and calls this,
 *  and as a const it sat in the temporal dead zone at that moment — a blank dashboard that
 *  BOTH tsc and the production build accepted without a word. */
function cardSlotId(S?: SectionComponent) {
  return 'card-' + (S?.meta?.label ?? 'unknown').toLowerCase().replace(/[^a-z0-9]+/g, '-')
}

/**
 * The overview list, DERIVED from the categories above.
 *
 * It used to be two hand-kept arrays sitting beside this one, and they had already drifted:
 * Tactical Sling filed under Core while its card renders on Placement, Condition Pips listed
 * as a peer of the card it actually lives inside, and Enable Sling — the switch that turns
 * the whole script on — missing entirely from a list whose comment called itself "every
 * on/off toggle". Deriving is not tidiness: it is the only way the panel cannot lie.
 */
const FEATURES = CATEGORIES.flatMap((cat) =>
  cat.sections.flatMap((item) => {
    const members = (Array.isArray(item) ? item : [item]) as SectionComponent[]
    const slot = cardSlotId(members[0])
    return members.flatMap((S) => {
      const m = S.meta
      if (!m) return []
      const base = { cat: cat.label, catId: cat.id, slot }
      // EVERY card, switch or not. Listing only the ones with an on/off left Placement
      // showing one line for its three cards and Presentation one for its three — and since
      // a line is also the way to REACH a card, Weapon Positions and Trunk Positions could
      // not be reached from the index at all, while the rail beside it counted three. A
      // card without a switch has no state to report; it still has a name and a place.
      const own = [{ label: m.label, path: m.path, ...base }]
      return own.concat((m.also ?? []).map((a) => ({ ...a, ...base })))
    })
  }))

const OV_CATS = CATEGORIES.map((c) => c.label)

/** How far apart two cards in a row may be before stretching them to match stops being
 *  tidy and starts being a hole. 90px is roughly one setting row plus its padding — under
 *  that the extra space lands in the card's own bottom padding and reads as breathing room;
 *  over it, it reads as a card missing something. */
const MAX_STRETCH = 90

/** Slots two at a time — the page is drawn as rows, so the array is read as rows. */
const pairs = <T,>(items: T[]): T[][] =>
  items.reduce<T[][]>((rows, item, i) => {
    if (i % 2 === 0) rows.push([item]); else rows[rows.length - 1].push(item)
    return rows
  }, [])

/** Cards a category renders — flattened, because a stacked pair is two cards in one cell
 *  and counting the cell told Interaction it had six when it draws seven. */
const cardCount = (cat: Category) =>
  cat.sections.reduce((n, s) => n + (Array.isArray(s) ? s.length : 1), 0)

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
  // Which Draw Style the gesture picker is auditioning clips for, or null when it is closed.
  const [gesture, setGesture] = useState<string | null>(null)
  const [closing, setClosing] = useState(false)     // playing the exit animation before unmount
  const [oxPatch, setOxPatch] = useState<string | false>(false) // ox auto-patch failure reason (CRITICAL → center alert)
  const [warnings, setWarnings] = useState<{ code: string; msg: string }[]>([]) // non-critical integration warnings → discreet right chips
  // What the server bridges resolved to — framework, inventory, persistence. Empty until
  // openAdmin lands, so the Environment block renders "none" rather than nothing.
  const [env, setEnv] = useState<{ framework?: string; inventory?: string; persistence?: string; language?: string }>({})
  // The card slot the index last navigated to. No timer: it is a bookmark, not a toast.
  const [targeted, setTargeted] = useState<string | null>(null)
  const [updateInfo, setUpdateInfo] = useState<{ current: string; latest: string; url: string } | null>(null) // newer release on GitHub, else null
  const baseline = useRef('')                       // last-saved snapshot
  const closeTimer = useRef<number | null>(null)    // deferred-unmount timer
  /**
   * Equal-height rows, but only where equal height is honest.
   *
   * A row stretches its two cards to match — that is what makes the page read as rows
   * rather than as two independent columns. Stretching a 228px card to 404 does not make
   * it tidy though: it makes a card with a hole in it, which is exactly what got the
   * previous grid layout thrown out. So the pair is measured at its natural height and
   * keeps the stretch only when the gap is small enough to disappear into the padding.
   *
   * Measured rather than declared: a card's height moves with the config (a toggle reveals
   * fields), so any number written next to it in CATEGORIES is a hint for a human, not
   * something the layout can trust. Runs on `cfg` for that reason.
   */
  useLayoutEffect(() => {
    document.querySelectorAll<HTMLElement>('.mbt-admin__row').forEach((row) => {
      row.classList.remove('is-tight')      // measure natural heights, not stretched ones
      const kids = Array.from(row.children) as HTMLElement[]
      if (kids.length < 2) return
      const [a, b] = kids.map((k) => k.getBoundingClientRect().height)
      if (Math.abs(a - b) <= MAX_STRETCH) row.classList.add('is-tight')
    })
  })

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
    setEnv(data?.env && typeof data.env === 'object' ? data.env : {})
    setUpdateInfo(data?.update?.latest ? data.update : null)
    setActive('core')
    setTargeted(null)
    setEditing(null)
    setTrunkEditing(null)
    setGesture(null)
    // Cancel any in-flight close so a re-open snaps back instantly.
    if (closeTimer.current) { window.clearTimeout(closeTimer.current); closeTimer.current = null }
    setClosing(false)
    setOpen(true)
    loadJobs()
  })

  /**
   * The framework's job list, fetched once here for every card that needs it.
   *
   * Retried, because an empty answer is indistinguishable from "this framework has no jobs"
   * and both look like a broken card: HIDDEN BY JOB offered only "Everyone" while the same
   * list rendered correctly on another page, each card having fetched its own copy. There is
   * one fetch now, and one empty result gets a second chance a second later rather than being
   * kept for the life of the panel.
   *
   * Not a loop: two attempts. A framework that genuinely has no jobs must settle, and the
   * cards say so rather than pretending the list is still coming.
   */
  const loadJobs = useCallback(() => {
    const pull = (retry: boolean) => {
      fetchNui('getJobs').then((list: any) => {
        const l = Array.isArray(list) ? list : []
        if (l.length === 0 && retry) { window.setTimeout(() => pull(false), 1200); return }
        setJobs(l)
      })
    }
    pull(true)
  }, [])

  /**
   * The server changed a value the panel is holding but does not edit.
   *
   * The draft round-trips the WHOLE config: everything the snapshot sends comes back on
   * Save. So when something outside the panel rewrites one of those keys — the position
   * editor's Reset All zeroes the length-class shifts server-side — the draft still holds
   * the old value, and the next ordinary Save quietly puts it back. The reset appears to
   * work and is undone by an unrelated click minutes later.
   *
   * Patched into the baseline as well as the draft: the value did not come from the user,
   * so it must not register as unsaved work, or Discard would offer to revert to the state
   * the server has just discarded.
   */
  useNuiEvent<Record<string, unknown>>('patchDraft', (patch) => {
    if (!patch || typeof patch !== 'object') return
    setCfg((c: any) => {
      if (!c) return c
      const next = { ...c, ...patch }
      baseline.current = JSON.stringify(next)
      return next
    })
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
      if (editing || trunkEditing || gesture) return
      if (e.key === 'Escape') close()
    }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [open, close, editing, trunkEditing, gesture])

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

  // No live repaint of the dashboard: it keeps the MalibuTech green whatever the server
  // picks. The draft colour is shown instead on a sample prompt inside the Interface
  // section — you see what a PLAYER will see, which is the thing being chosen, and the
  // panel does not pretend to be the product being branded.

  if (!open || !cfg) return null

  // Derived: the draft differs from the last-saved snapshot (drives Save/Discard).
  const dirty = JSON.stringify(cfg) !== baseline.current
  dirtyRef.current = dirty   // read by close(), which lives above this line

  const activeCat = CATEGORIES.find((c) => c.id === active) ?? CATEGORIES[0]
  const isPositions = !!activeCat.mode
  const headLabel = activeCat.label
  const headHint = isPositions
    ? `${activeCat.hint} · set in-world · saved to oxmysql`
    // "cards", not "features": the page draws cards, and one of them can own several
    // features while another owns none. Calling them features made the number disagree
    // with both the overview list and what is on screen.
    : `${activeCat.hint} · ${cardCount(activeCat)} cards · applies live on save`

  // Real feature state for the overview — derived from the same config paths the
  // section toggles write (single source of truth, always accurate). Grouped by
  // category and computed live from the draft.
  // `on` is undefined — not false — for a card with no switch: it has no state to be in,
  // and showing it as off would be the panel stating something untrue about it.
  const feats = FEATURES.map((f) => ({ ...f, on: f.path ? !!getPath(cfg, f.path) : undefined }))

  // Which paths the draft has moved since the last save. The panel could tell you THAT
  // something was unsaved but never WHICH — the one question at Save time.
  const saved = (() => { try { return JSON.parse(baseline.current || '{}') } catch { return {} } })()
  const isDirtyPath = (path?: string) => !!path && getPath(cfg, path) !== getPath(saved, path)
  const dirtyCount = feats.filter((f) => isDirtyPath(f.path)).length

  /**
   * Index row → its card.
   *
   * The scroll deliberately passes NO `behavior`: given as an option it overrides the CSS
   * property, and `.mbt-reduce-motion` sets `scroll-behavior: auto !important` — so passing
   * 'smooth' would ship motion to exactly the people who turned it off. Letting CSS own it
   * covers both cases for free.
   *
   * The mark has no timer. Two seconds is a guess about reading speed, and this user
   * alt-tabs to a running game mid-thought; it is a bookmark, not a notification, and a
   * static 2px rule costs nothing to leave up.
   */
  const goToFeature = (f: { catId: string; slot?: string }) => {
    if (!f.slot) return
    setActive(f.catId)
    setTargeted(f.slot)
    // After the category has rendered — switching it replaces the whole card tree.
    requestAnimationFrame(() => {
      const el = document.getElementById(f.slot!)
      if (!el) return
      const box = el.getBoundingClientRect()
      const scroller = el.closest('.mbt-admin__center')?.getBoundingClientRect()
      // Skip the scroll when it is already fully in view: a 0px smooth scroll still moves
      // a page someone is reading, and under column layout this is the common case.
      if (!scroller || box.top < scroller.top || box.bottom > scroller.bottom) {
        el.scrollIntoView({ block: 'center' })
      }
      el.focus({ preventScroll: true })
    })
  }

  return (
    <>
    <div className={`mbt-admin-overlay${editing || trunkEditing || gesture ? ' is-editing' : ''}${closing ? ' is-closing' : ''}`}>
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
            <div><b>MBT MALISLING</b><span>Control panel</span></div>
          </div>

          {/* One loop for every destination. The mode entry gets its own group heading —
              Placement is not a sixth page of toggles, it hides the panel and edits in 3D —
              but it is no longer hand-written beside the loop, which is how its count and
              its overview group drifted from everything else. */}
          {CATEGORIES.map((cat, i) => (
            <Fragment key={cat.id}>
              {(i === 0 || cat.mode !== CATEGORIES[i - 1].mode) && (
                <div className="mbt-rail__group">{cat.mode ? 'Placement' : 'Configuration'}</div>
              )}
              <button
                className={`mbt-rail__item${active === cat.id ? ' is-active' : ''}`}
                aria-current={active === cat.id ? 'page' : undefined}
                onClick={() => setActive(cat.id)}
              >
                <span className="ic"><Icon name={cat.icon} size={18} /></span>
                <span className="mbt-rail__tx">
                  <span className="mbt-rail__label">{cat.label}</span>
                  <span className="mbt-rail__hint">{cat.hint}</span>
                </span>
                <span className="mbt-rail__count">{cardCount(cat)}</span>
              </button>
            </Fragment>
          ))}

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
              // Same slot wrappers as the card map, written by hand because each of these
              // takes props of its own. Without them the index listed three cards it could
              // not reach: the click switched the page and then looked up an id that was
              // never in the DOM.
              // Rows here too, hand-written because each of these takes props of its own.
              //
              // Two pairs. [Weapon Positions | Tactical Sling] are the same job — place a prop
              // on the BODY — and measure 402/402. [Draw Style | Trunk Positions] are the two
              // that place nothing on the body, and on a server in its default state they
              // measure 206/206: the row stretches and reads as a pair.
              //
              // It does NOT stay even in every state — add a per-job draw style and that card
              // grows to 357 against Trunk Positions' 178. That is what the measured stretch
              // above is for: past 90px of difference it stops stretching and the two simply
              // sit side by side at their own heights, which is the honest outcome. Do not
              // "fix" that by forcing the stretch; a 179px hole inside a card is what got the
              // previous layout thrown out.
              <>
                <div className="mbt-admin__row">
                  <div id={cardSlotId(PositionsSection)} tabIndex={-1}
                    className={`mbt-card-slot${targeted === cardSlotId(PositionsSection) ? ' is-targeted' : ''}`}>
                    <PositionsSection jobs={jobs} onEdit={(t) => setEditing(t)}
                      multiOn={!!cfg.MultiWeaponVisibility?.Enabled} />
                  </div>
                  <div id={cardSlotId(SlingPositionsSection)} tabIndex={-1}
                    className={`mbt-card-slot${targeted === cardSlotId(SlingPositionsSection) ? ' is-targeted' : ''}`}>
                    <SlingPositionsSection config={cfg} update={update} jobs={jobs}
                      onEdit={(variant, g) => setEditing({ wtype: 'sling:' + variant, job: 'default', gender: g })} />
                  </div>
                </div>
                <div className="mbt-admin__row">
                  <div id={cardSlotId(DrawStyleSection)} tabIndex={-1}
                    className={`mbt-card-slot${targeted === cardSlotId(DrawStyleSection) ? ' is-targeted' : ''}`}>
                    <DrawStyleSection config={cfg} update={update} openGesture={setGesture} jobs={jobs} />
                  </div>
                  <div id={cardSlotId(TrunkPositionsSection)} tabIndex={-1}
                    className={`mbt-card-slot${targeted === cardSlotId(TrunkPositionsSection) ? ' is-targeted' : ''}`}>
                    <TrunkPositionsSection config={cfg} update={update} refreshKey={trunkRefresh}
                      onEdit={(s) => setTrunkEditing({ model: s.model, vclass: s.class, off: s.off, view: s.view })} />
                  </div>
                </div>
              </>
            ) : (
              // Each card sits in a slot carrying its DOM id, so the index can scroll to it
              // and mark it. The id is derived from the label a card already declares —
              // asking 31 files to repeat an identifier is 31 chances for it to diverge from
              // the one the index looks up.
              // A category with an odd number of slots ends on a row holding one card. Left
              // at half width that reads as a hole the size of a card — the single thing
              // that made this layout look untidier than the packing it replaced. Full
              // width, it reads as a wide card closing the page, and Core goes from 1.6
              // screens of scroll to one screen with nothing missing.
              pairs(activeCat.sections).map((row, r) => (
                <div key={`${active}-r${r}`}
                  className={`mbt-admin__row${row.length === 1 ? ' is-solo' : ''}`}>
                  {row.map((item, i) => {
                    const members = (Array.isArray(item) ? item : [item]) as SectionComponent[]
                    const slotId = cardSlotId(members[0])
                    return (
                      // tabIndex -1: the index moves focus here after scrolling, so Tab continues
                      // from the card you were sent to rather than from the top of the page.
                      <div key={`${active}-${r}-${i}`} id={slotId} tabIndex={-1}
                        className={`mbt-card-slot${Array.isArray(item) ? ' mbt-admin__section-stack' : ''}${
                          targeted === slotId ? ' is-targeted' : ''}`}>
                        {members.map((S, j) => (
                          <S key={j} config={cfg} update={update} openGesture={setGesture} jobs={jobs} />
                        ))}
                      </div>
                    )
                  })}
                </div>
              ))
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
            <Icon name="layers" size={12} /> FEATURE INDEX
          </div>

          <div className="mbt-ov__body">
          {/* Exceptions first. These used to sit below the list and a flex spacer, which is
              the opposite of status-by-exception: the thing needing attention was the last
              thing read. Nothing renders when clean — the empty space is the message. */}
          {warnings.map((w) => (
            <div key={w.code} className="mbt-ov__warn-chip">
              <Icon name="alert" size={13} />
              <span>{w.msg}</span>
            </div>
          ))}

          {/* What needs attention NOW, as opposed to how the server is configured. Only
              renders when there is something to say. */}
          {dirty && (
            <div className="mbt-ov__state">
              <span className="mbt-ov__state-dot" />
              <b>{dirtyCount}</b> unsaved {dirtyCount === 1 ? 'change' : 'changes'}
            </div>
          )}

          {/* Environment — every one of these checks already existed as the guard at the top
              of a bridge or inventory module, but none of them reached the panel, so "did it
              detect my setup?" could only be answered from the server console. */}
          <dl className="mbt-ov__kv">
            <div className="mbt-ov__grouphead">Environment</div>
            <div><dt>Framework</dt><dd>{env.framework ?? <span className="is-off">none</span>}</dd></div>
            <div><dt>Inventory</dt><dd>{env.inventory ?? <span className="is-off">none</span>}</dd></div>
            <div><dt>Persistence</dt>
              <dd className={env.persistence ? 'is-ok' : 'is-warn'}>{env.persistence ?? 'not started'}</dd></div>
            {/* Only when it FAILED. "ox patch: applied" is the normal case on every server
                that has ox_inventory, so it spent a permanent row telling you nothing —
                the same status-by-exception rule the warnings above already follow. */}
            {oxPatch && oxPatch !== 'ok' ? (
              <div><dt>ox patch</dt><dd className="is-warn">failed</dd></div>
            ) : null}
            {/* No Version row: the rail's bottom card already carries it, and states it
                better — it also knows whether that version is the current one. */}
          </dl>

          {/* The index. Rows are buttons: this is the only place in the panel that lists
              features BY NAME, and until now it could not be used to reach one. */}
          <div className="mbt-ov__list">
            {OV_CATS.map((cat) => (
              <Fragment key={cat}>
                <div className="mbt-ov__grouphead is-sticky">{cat}</div>
                {/* Two per line. 32 rows in one column overflowed the column by 507px at
                    900px tall — no density fixes that, only fewer lines do. Measured before
                    committing to it: of the 32 labels exactly ONE is wider than a half-width
                    row, so the pairing costs one ellipsis, not a column of them. */}
                <div className="mbt-ov__grid">
                  {feats.filter((f) => f.cat === cat).map((f) => (
                    <button key={f.path ?? f.label} type="button"
                      className={`mbt-ov__feat${f.on ? ' is-on' : ''}${f.on === undefined ? ' is-static' : ''}${
                        f.slot === targeted ? ' is-current' : ''}${isDirtyPath(f.path) ? ' is-dirty' : ''}`}
                      aria-current={f.slot === targeted ? 'location' : undefined}
                      title={f.label}
                      onClick={() => goToFeature(f)}>
                      <span className="mbt-ov__mark" aria-hidden="true" />
                      <span className="mbt-ov__featname">{f.label}</span>
                    </button>
                  ))}
                </div>
              </Fragment>
            ))}
          </div>

          <div className="mbt-ov__spacer" />
          {/* The standing note that used to close this column is gone. Its first half —
              saving applies live — is already on every page header, and the space it took
              is what the cards without a switch needed to be listed at all. A sentence read
              once does not outrank five cards you cannot otherwise reach. */}
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
    {gesture ? (
      <GestureOverlay
        style={gesture}
        styleLabel={
          (Array.isArray(cfg?.DrawStyles) ? cfg.DrawStyles : [])
            .find((s: any) => s.id === gesture)?.label ?? gesture
        }
        styles={Array.isArray(cfg?.DrawStyles) ? cfg.DrawStyles : []}
        candidates={Array.isArray(cfg?.DrawStyleCandidates) ? cfg.DrawStyleCandidates : []}
        activeStyle={cfg?.DrawStyle ?? 'standard'}
        activeLabel={
          (Array.isArray(cfg?.DrawStyles) ? cfg.DrawStyles : [])
            .find((s: any) => s.id === (cfg?.DrawStyle ?? 'standard'))?.label ?? cfg?.DrawStyle
        }
        // One style in play until a per-job rule exists — the same test the card makes to
        // decide whether to offer the selector at all.
        multiStyle={
          !!cfg?.DrawStyleByJob && !Array.isArray(cfg.DrawStyleByJob) &&
          Object.values(cfg.DrawStyleByJob).some(Boolean)
        }
        onClose={() => setGesture(null)}
      />
    ) : null}
    </>
  )
}
