import './index.css'
import './components/overlay.css'
import { useEffect } from 'react'
import { debugData } from './utils/debugData'
import { useNuiEvent } from './utils/useNuiEvent'
import { fetchNui } from './utils/fetchNui'
import HolsterUI from './components/HolsterUI'
import JamUI from './components/JamUI'
import InspectUI from './components/InspectUI'
import NoDrawUI from './components/NoDrawUI'
import WeaponStatusUI from './components/WeaponStatusUI'
import PoseHUD from './components/PoseHUD'
import RackPickerUI from './components/RackPickerUI'
import EvidenceUI from './components/EvidenceUI'
import HandoffUI from './components/HandoffUI'
import HintUI from './components/HintUI'
import PatdownUI from './components/PatdownUI'
import AmmoPickerUI from './components/AmmoPickerUI'
import AdminDashboard from './admin/AdminDashboard'

// ── Browser dev preview (npm run dev) ────────────────────────────────────────
// 'admin'    → opens the dashboard with a full mock config (UI polish in Chrome).
// 'overlays' → plays the in-game overlay sequence (holster, jam, inspect, …).
// Flip this while iterating; it has NO effect in-game (debugData only fires in the
// browser during development).
const DEV_PREVIEW = 'admin' as 'admin' | 'overlays'

// Which integration state to preview in the admin dashboard (browser dev only):
//   'healthy'  → nothing shown (status-by-exception)
//   'critical' → centered role=alert banner (ox patch failed)
//   'warning'  → discreet amber chip in the overview (e.g. qb-weapons weapdraw)
//   'both'     → critical banner + warning chip together
const DEV_SCENARIO = 'healthy' as 'healthy' | 'critical' | 'warning' | 'both'

// Full mock of the server config snapshot (modules/config/server.lua → snapshot()).
const MOCK_ADMIN_CONFIG = {
  EnableSling: true, EnableFlashlight: true, DropWeaponOnDeath: true, UIPosition: 'bottom-center', Language: 'en',
  Sounds: { Enabled: true, MaxDistance: 8.0, Volume: 0.3 },
  WeaponDrop: { WeaponModelProp: true, OxTargetPickup: true, Despawn: { Enabled: true, Seconds: 300, BlinkLastSec: 10 }, Logging: { Enabled: false, Webhook: '' } },
  Jamming: { Enabled: true, Cooldown: 5, UnjamPresses: 5 },
  SuppressorHeat: { Enabled: true, Mode: 'glow', HeatPerShot: 5, DecayRate: 16, WarmThreshold: 35, HotThreshold: 75 },
  Safety: { Enabled: true, DefaultOn: true, PerWeapon: true, HudIndicator: true },
  ConditionHUD: { Enabled: true },
  ChargeWeapon: { Enabled: false, MaxDistance: 20.0, Cooldown: 1500 },
  WeaponWeight: { Enabled: false, Mode: 'light', Threshold: 2, PerWeapon: 0.03, MaxPenalty: 0.18 },
  Inspect: { Enabled: true, MaxDistance: 20.0, AmmoMode: 'exact', Show: { Serial: true, Condition: true, Name: true, Ammo: true } },
  WeaponName: { Enabled: true, MaxLength: 24, Permission: 'everyone', OncePerWeapon: false },
  ShowcasePoses: { Enabled: true, Sync: true },
  Throw: { Enabled: true, Groups: { MELEE: true, PISTOL: true, RIFLE: true, MG: false, SMG: true, SHOTGUN: false, STUNGUN: false, SNIPER: false, HEAVY: false } },
  ChainOfCustody: { Enabled: true, MaxEntries: 10, ShowInInspect: true },
  NoDrawZones: { Enabled: true, AllowMelee: true, HudIndicator: true, NotifyCooldown: 3000 },
  VehicleHiding: { Enabled: true, UseRoofCheck: true },
  VehicleTrunkRack: { Enabled: true, Capacity: 2, InteractionDistance: 2.5, EquipOnRetrieve: true, AllowedTypes: { back: true, back2: true } },
  WeaponRack: { Enabled: true, Capacity: 4, InteractionDistance: 2.0, EquipOnRetrieve: true, AllowedTypes: { back: true, back2: true, side: true }, Logging: { Enabled: false, Webhook: '' }, Placement: { Enabled: true, MaxPerPlayer: 2, AllowPickup: true, Access: 'owner' } },
  TacticalSling: { Enabled: false },
  ShellCasings: { Enabled: true, Chance: 0.5, ExpireMinutes: 30, MaxCasings: 150, SerialReveal: 'partial', AllowCollect: true },
  Handoff: { Enabled: true, MaxDistance: 2.5, EquipOnAccept: true },
  Serials: { EnsureGeneration: true, Format: 'marked', SweepOnLoad: true },
  ConcealedCarry: { Enabled: true, ToggleCooldownMs: 3000, Tell: { Enabled: true, RollSeconds: 25, ChanceGood: 0.15, ChancePoor: 0.45 } },
  PatDown: { Enabled: true, RequireConsent: true, CuffedBypass: true, ShowAmmo: true, MaxDistance: 2.0, Logging: { Enabled: false, Webhook: '' } },
  AmmoSharing: { Enabled: true, ShareAmount: 30, MaxDistance: 2.5 },
}

if (DEV_PREVIEW === 'admin') {
  debugData([{
    action: 'openAdmin',
    data: {
      version: 'v2.0.0', companion: false, config: MOCK_ADMIN_CONFIG,
      oxPatch: (DEV_SCENARIO === 'critical' || DEV_SCENARIO === 'both') ? 'ox_inventory weapons-as-items is disabled' : 'ok',
      warnings: (DEV_SCENARIO === 'warning' || DEV_SCENARIO === 'both')
        ? [{ code: 'qb_weapdraw', msg: 'qb-weapons detected — disable weapdraw.lua for correct holster/switch animations.' }]
        : [],
    },
  }], 300)
}

if (DEV_PREVIEW === 'overlays') {
  debugData([{
    action: 'showHolster',
    data: {
      weaponLabel: 'WEAPON_PISTOL',
      position: 'bottom-center',
      confirm: { label: 'Confirm Holster', display: 'RMB' },
      cancel:  { label: 'Cancel Holster',  display: 'BACKSPACE' },
    },
  }], 500)
  debugData([{ action: 'hideHolster', data: {} }], 5000)

  debugData([{
    action: 'showJam',
    data: { weaponLabel: 'WEAPON_PISTOL', presses: 0, total: 5, key: 'R' },
  }], 1000)
  debugData([{ action: 'updateJam', data: { presses: 2 } }], 2500)
  debugData([{ action: 'updateJam', data: { presses: 4 } }], 3500)
  debugData([{ action: 'hideJam',   data: {} }], 4500)

  debugData([{
    action: 'showInspect',
    data: {
      name: 'WEAPON_CARBINERIFLE',
      serial: 'A7F-3K9Q',
      condition: 'Worn',
      conditionTone: 'warn',
      ammo: 18,
      show: { Serial: true, Condition: true, Name: true, Ammo: true },
    },
  }], 5500)
  debugData([{ action: 'hideInspect', data: {} }], 9000)

  debugData([{
    action: 'showNoDraw',
    data: { title: 'Pillbox Hospital', subtitle: 'No weapons allowed' },
  }], 9500)
  debugData([{ action: 'hideNoDraw', data: {} }], 13000)

  debugData([{ action: 'showWeaponStatus', data: { safety: 'safe', condition: 5 } }], 13500)
  debugData([{ action: 'showWeaponStatus', data: { safety: 'fire', condition: 3 } }], 15500)
  debugData([{ action: 'weaponStatusPulse', data: {} }], 16500)
  debugData([{ action: 'showWeaponStatus', data: { safety: 'fire', condition: 1 } }], 17200)
  debugData([{ action: 'hideWeaponStatus', data: {} }], 19000)

  debugData([{ action: 'showPose', data: { name: 'Lean back', index: 2, total: 5 } }], 19500)
  debugData([{ action: 'showPose', data: { name: 'Guard stance', index: 4, total: 5 } }], 21500)
  debugData([{ action: 'hidePose', data: {} }], 23500)

  debugData([{
    action: 'showRackPicker',
    data: {
      index: 1,
      weapons: [
        { name: 'Punisher',           serial: 'A7F-3K9Q', condition: 'Pristine', tone: 'good' },
        { name: 'WEAPON_CARBINERIFLE', serial: 'X2B-77TN', condition: 'Worn',     tone: 'warn' },
        { name: 'WEAPON_PISTOL',       serial: 'QQ1-04ZZ', condition: 'Damaged',  tone: 'bad' },
      ],
    },
  }], 24000)
  debugData([{ action: 'updateRackPicker', data: { index: 2 } }], 25500)
  debugData([{ action: 'hideRackPicker', data: {} }], 28000)

  debugData([{
    action: 'showEvidence',
    data: { weapon: 'WEAPON_PISTOL', serial: 'A7••••9Q', agoMin: 5 },
  }], 28500)
  debugData([{ action: 'hideEvidence', data: {} }], 31500)

  debugData([{
    action: 'showHandoff',
    data: { fromName: 'John Doe', weapon: 'WEAPON_CARBINERIFLE', label: 'Punisher', serial: 'A7F-3K9Q' },
  }], 32000)
  debugData([{ action: 'hideHandoff', data: {} }], 35500)
}

export default function App() {
  // Reduced motion (manual — CEF often can't read the OS setting): pull the flag on
  // mount and toggle the root class; the live event lets a config save update it too.
  useEffect(() => {
    fetchNui('getReduceMotion', {}, { on: false }).then((r: any) =>
      document.documentElement.classList.toggle('mbt-reduce-motion', !!r?.on))
  }, [])
  useNuiEvent<{ on: boolean }>('setReduceMotion', ({ on }) =>
    document.documentElement.classList.toggle('mbt-reduce-motion', !!on))

  useNuiEvent<{ file: string; volume: number }>('playHolsterSound', ({ file, volume }) => {
    // Guard the filename (it builds a path): only a safe token can be played, and
    // swallow the play() rejection so CEF doesn't log an unhandled promise when the
    // overlay closes mid-play or autoplay is blocked.
    if (typeof file !== 'string' || !/^[a-z0-9_]+$/.test(file)) return
    const audio = new Audio(`sounds/${file}.ogg`)
    audio.volume = Math.min(1, Math.max(0, Number(volume) || 0))
    audio.play().catch(() => {})
  })

  return (
    <>
      <HolsterUI />
      <JamUI />
      <InspectUI />
      <NoDrawUI />
      <WeaponStatusUI />
      <PoseHUD />
      <RackPickerUI />
      <EvidenceUI />
      <HandoffUI />
      <HintUI />
      <PatdownUI />
      <AmmoPickerUI />
      <AdminDashboard />
    </>
  )
}
