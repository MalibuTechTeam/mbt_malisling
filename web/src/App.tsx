import './index.css'
import './components/overlay.css'
import { debugData } from './utils/debugData'
import { useNuiEvent } from './utils/useNuiEvent'
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
import AdminDashboard from './admin/AdminDashboard'

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

export default function App() {
  useNuiEvent<{ file: string; volume: number }>('playHolsterSound', ({ file, volume }) => {
    const audio = new Audio(`sounds/${file}.ogg`)
    audio.volume = Math.min(1, Math.max(0, volume))
    audio.play()
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
      <AdminDashboard />
    </>
  )
}
