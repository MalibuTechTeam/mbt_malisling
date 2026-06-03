import './index.css'
import './components/overlay.css'
import { debugData } from './utils/debugData'
import { useNuiEvent } from './utils/useNuiEvent'
import HolsterUI from './components/HolsterUI'
import JamUI from './components/JamUI'
import InspectUI from './components/InspectUI'
import NoDrawUI from './components/NoDrawUI'
import WeaponStatusUI from './components/WeaponStatusUI'
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
      <AdminDashboard />
    </>
  )
}
