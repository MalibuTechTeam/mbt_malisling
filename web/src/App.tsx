import './index.css'
import { debugData } from './utils/debugData'
import { useNuiEvent } from './utils/useNuiEvent'
import HolsterUI from './components/HolsterUI'
import JamUI from './components/JamUI'
import ConfigUI from './components/ConfigUI'

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
      <ConfigUI />
    </>
  )
}
