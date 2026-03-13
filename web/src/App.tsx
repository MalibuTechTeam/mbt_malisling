import './index.css'
import { debugData } from './utils/debugData'
import HolsterUI from './components/HolsterUI'

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

export default function App() {
  return <HolsterUI />
}
