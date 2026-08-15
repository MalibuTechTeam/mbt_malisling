import { useEffect, useState } from 'react'
import { PositionPicker } from '../ui/PositionPicker'
import { Segmented } from '../ui/Segmented'
import { NumberInput } from '../ui/NumberInput'
import { Icon } from '../ui/Icon'
import { accentContrast, isHexColor, DEFAULT_ACCENT, MIN_CONTRAST } from '../../utils/accent'
import { Section, ToggleRow, FieldBlock, type SectionProps } from './parts'

/**
 * Core category — split into atomic cards so the category page can order them
 * freely (CoreSection and InterfaceSection are placed separately in the grid).
 */

/** CORE — core sling toggles (runtime-safe; Debug stays in config.lua). */
export function CoreSection({ config, update }: SectionProps) {
  return (
    <Section icon="power" title="CORE" sub="Whether weapons show on the body at all.">
      <ToggleRow title="Enable Sling" desc="Show the weapon on the player's body"
        checked={!!config.EnableSling} onChange={(v) => update('EnableSling', v)} />
      <ToggleRow title="Enable Flashlight" desc="A slung weapon's torch stays lit if it was on"
        checked={!!config.EnableFlashlight} onChange={(v) => update('EnableFlashlight', v)} />
      <ToggleRow title="Holster Confirm" desc="Ask before a drawn sidearm reaches the hand — the draw animation plays either way"
        checked={!!config.HolsterConfirm} onChange={(v) => update('HolsterConfirm', v)} />
      <ToggleRow title="Drop Weapon on Death" desc="The weapon in hand falls where the player died"
        checked={!!config.DropWeaponOnDeath} onChange={(v) => update('DropWeaponOnDeath', v)} />
    </Section>
  )
}

/** MULTI-WEAPON — more than one weapon visible in the same body slot.
 *  Off by default: the slots are body positions, not weapon families, so turning this on
 *  changes what every player looks like. */
export function MultiWeaponSection({ config, update }: SectionProps) {
  const mw = config.MultiWeaponVisibility ?? {}
  return (
    <Section icon="power" title="MULTI-WEAPON" sub="More than one weapon in the same body slot.">
      <ToggleRow title="Show Multiple Weapons"
        desc="A rifle and a shotgun share the back slot — off, only one of them shows"
        checked={!!mw.Enabled} onChange={(v) => update('MultiWeaponVisibility.Enabled', v)} />
      <FieldBlock label="Max Per Slot"
        hint="Distinct weapons drawn per slot. Copies of the same model share one prop; the rest are still tracked."
        disabled={!mw.Enabled} style={{ marginBottom: 0 }}>
        <NumberInput min={1} max={4} step={1} value={String(mw.MaxPerType ?? 2)}
          onChange={(raw) => update('MultiWeaponVisibility.MaxPerType', raw === '' ? 2 : parseInt(raw, 10) || 2)} />
      </FieldBlock>
    </Section>
  )
}

/** INTERFACE — HUD prompt position (3 presets), style and brand accent. "Custom"
 *  placement (a live drag-to-place HUD editor) is reserved for v2.1; the picker shows
 *  it disabled with a badge. */
export function InterfaceSection({ config, update }: SectionProps) {
  const pos = config.UIPosition ?? 'bottom-center'
  const accent = isHexColor(config.Accent) ? config.Accent : DEFAULT_ACCENT
  const ratio = accentContrast(accent)

  // The hex field is typed one character at a time, so it can't be driven straight off
  // the config: committing only valid hex would freeze the input the moment you delete
  // a digit. The draft holds the half-typed value; config only sees complete ones.
  const [hexDraft, setHexDraft] = useState(accent)
  useEffect(() => { setHexDraft(accent) }, [accent])

  // Reset arms on the first click and commits on the second, disarming itself after 4s:
  // this control throws away a colour someone tuned, and it sits next to the field they
  // tuned it in.
  const [armed, setArmed] = useState(false)
  useEffect(() => {
    if (!armed) return
    const t = window.setTimeout(() => setArmed(false), 4000)
    return () => window.clearTimeout(t)
  }, [armed])

  return (
    <Section icon="grid" title="INTERFACE" sub="Prompt placement, style and brand colour.">
      <FieldBlock label="Prompt Style" hint="Standard sits in a fixed spot on screen · Cinematic appears beside the weapon.">
        <Segmented
          value={config.UIStyle ?? 'standard'}
          onChange={(v) => update('UIStyle', v)}
          options={[{ value: 'standard', label: 'Standard' }, { value: 'cinematic', label: 'Cinematic' }]}
        />
      </FieldBlock>
      <FieldBlock label="Brand Accent"
        hint="The one interactive colour — buttons, selection, focus rings. Repaints this dashboard and every in-game prompt as you pick.">
        <div className="mbt-accent-row">
          <input type="color" className="mbt-accent-swatch" value={accent} aria-label="Brand accent colour"
            onChange={(e) => update('Accent', e.target.value.toUpperCase())} />
          <input type="text" className="mbt-input mbt-accent-hex" value={hexDraft} maxLength={7}
            spellCheck={false} aria-label="Brand accent hex value" placeholder={DEFAULT_ACCENT}
            onChange={(e) => {
              const v = e.target.value.trim()
              setHexDraft(v)
              if (isHexColor(v)) update('Accent', v.toUpperCase())
            }}
            onBlur={() => setHexDraft(accent)} />
          <button type="button" className={`mbt-btn-ghost mbt-btn--sm${armed ? ' is-armed' : ''}`}
            onClick={() => {
              if (!armed) { setArmed(true); return }
              setArmed(false)
              update('Accent', DEFAULT_ACCENT)
            }}>
            {armed ? 'Confirm reset' : 'Reset'}
          </button>
        </div>
      </FieldBlock>
      {ratio < MIN_CONTRAST && (
        <div className="mbt-notice mbt-notice--warn" role="alert">
          <Icon name="alert" size={15} />
          <span>
            Hard to read — this colour scores <b>{ratio.toFixed(2)}:1</b> against the panel, under the {MIN_CONTRAST}:1
            minimum. Prompts, focus rings and pills will be difficult to make out in game. Saving is still allowed.
          </span>
        </div>
      )}
      <PositionPicker value={pos} onChange={(v) => update('UIPosition', v)} />
      {pos === 'custom' && (
        <p className="mbt-field__hint" style={{ marginTop: 8 }}>
          Custom placement — a live drag-to-place editor — ships in v2.1; using a default spot for now.
        </p>
      )}
    </Section>
  )
}
