import { Section, ToggleRow, FieldBlock, type SectionProps, withMeta } from './parts'
import { NumberInput } from '../ui/NumberInput'

/**
 * Sounds — the script's audio, which today means holster and draw. Per-type sound files stay
 * in config.lua (technical); the menu exposes the runtime-safe toggles.
 *
 * Titled SOUNDS and not HOLSTER SOUNDS: it governs `MBT.Sounds`, every sound the script
 * plays, and calling it after one of them put it in the same sentence as Holster Confirm —
 * which lives under Core, on another page. Two "holster" cards two pages apart is a question
 * an owner should never have to answer.
 */
export function HolsterSection({ config, update }: SectionProps) {
  const s = config.Sounds ?? {}
  return (
    <Section icon="speaker" title="SOUNDS" sub="Audio on holster and draw, heard by nearby players."
      action={<ToggleRow.Inline label="Sounds" checked={!!s.Enabled}
        onChange={(v) => update('Sounds.Enabled', v)} />}>
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 14, marginTop: 4 }}>
        <FieldBlock label="Hearing Distance (m)" hint="How far players hear it." style={{ marginBottom: 0 }}>
          <NumberInput min={1} max={50} step={1} value={String(s.MaxDistance ?? 8)}
            onChange={(raw) => update('Sounds.MaxDistance', raw === '' ? 8 : parseFloat(raw) || 8)} />
        </FieldBlock>
        <FieldBlock label="Volume (0–1)" hint="0 is silent, 1 is full." style={{ marginBottom: 0 }}>
          <NumberInput min={0} max={1} step={0.05} value={String(s.Volume ?? 0.3)}
            onChange={(raw) => update('Sounds.Volume', raw === '' ? 0.3 : parseFloat(raw) || 0)} />
        </FieldBlock>
      </div>
    </Section>
  )
}

export default HolsterSection

withMeta(HolsterSection, { label: 'Sounds', path: 'Sounds.Enabled' })
