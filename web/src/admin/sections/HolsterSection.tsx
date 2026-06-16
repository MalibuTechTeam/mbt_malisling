import { Section, ToggleRow, FieldBlock, type SectionProps } from './parts'
import { NumberInput } from '../ui/NumberInput'

/** Holster & Sounds — holster/unholster sound feedback. Per-type sound files
 *  stay in config.lua (technical); the menu exposes the runtime-safe toggles. */
export function HolsterSection({ config, update }: SectionProps) {
  const s = config.Sounds ?? {}
  return (
    <Section icon="speaker" title="HOLSTER SOUNDS" sub="Audio on holster and draw.">
      <ToggleRow title="Enable Sounds" desc="Plays a sound on holster and draw"
        checked={!!s.Enabled} onChange={(v) => update('Sounds.Enabled', v)} />
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 14, marginTop: 4 }}>
        <FieldBlock label="Hearing Distance (m)" hint="How far players hear it." style={{ marginBottom: 0 }}>
          <NumberInput min={1} max={50} step={1} value={String(s.MaxDistance ?? 8)}
            onChange={(raw) => update('Sounds.MaxDistance', raw === '' ? 8 : parseFloat(raw) || 8)} />
        </FieldBlock>
        <FieldBlock label="Volume (0–1)" hint="Playback volume." style={{ marginBottom: 0 }}>
          <NumberInput min={0} max={1} step={0.05} value={String(s.Volume ?? 0.3)}
            onChange={(raw) => update('Sounds.Volume', raw === '' ? 0.3 : parseFloat(raw) || 0)} />
        </FieldBlock>
      </div>
    </Section>
  )
}

export default HolsterSection
