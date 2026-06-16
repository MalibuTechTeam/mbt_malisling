import { useState, useMemo } from 'react'
import qrcode from 'qrcode-generator'
import { fetchNui } from '../../utils/fetchNui'
import { Icon, type IconName } from '../ui/Icon'

/**
 * ShootingSection — the in-menu upsell / status page for the paid companion
 * (mbt_shooting). When the bridge is connected it flips from "locked add-on"
 * to "active". It names the product (public marketing) but ships none of its
 * logic — consistent with the opaque bridge.
 *
 * CTA is EVERGREEN: it routes the owner to the Tebex package URL (a "coming
 * soon" package that becomes the live product at the SAME url). The launch-state
 * messaging ("notify me" → "buy") lives on Tebex, so malisling never needs a
 * release-day update. CEF can't open a browser, so the CTA opens a modal with a
 * QR + copyable link instead — no data leaves the resource.
 */

// TODO: replace with the real MalibuTech URLs once the Tebex package + Discord exist.
const STORE_URL   = 'https://malibutech.tebex.io'
const DISCORD_URL = 'https://discord.gg/malibutech'

interface ShootFeature { icon: IconName; title: string; desc: string }

// Outcome-driven copy — what each system changes for the server, not just what it is.
const FEATURES: ShootFeature[] = [
  { icon: 'layers', title: 'Skill Recoil',     desc: 'Reward trained players with steadier handling and a faster draw.' },
  { icon: 'alert',  title: 'Weapon Condition', desc: 'Real wear that drives maintenance, scarcity and a weapon economy.' },
  { icon: 'alert',  title: 'Malfunctions',     desc: 'Add risk to neglected weapons — three stoppages, each with its own clear.' },
  { icon: 'cursor', title: 'Shooting Range',   desc: 'Give players a place to train, with modes, leaderboards and challenges.' },
  { icon: 'search', title: 'Crosshair',        desc: 'Per-player crosshair: thickness, length, center gap, color, dot.' },
  { icon: 'help',   title: 'Licensing & Exam', desc: 'Gate weapon access through your server rules — exams, CCW, permits.' },
]

function copyText(text: string) {
  if (navigator.clipboard?.writeText) {
    navigator.clipboard.writeText(text).catch(() => fallbackCopy(text))
  } else {
    fallbackCopy(text)
  }
}
function fallbackCopy(text: string) {
  // CEF often blocks the async clipboard API — execCommand on a hidden textarea works.
  const ta = document.createElement('textarea')
  ta.value = text
  ta.style.position = 'fixed'
  ta.style.opacity = '0'
  document.body.appendChild(ta)
  ta.select()
  try { document.execCommand('copy') } catch { /* best-effort */ }
  ta.remove()
}

export function ShootingSection({ companion }: { companion: boolean }) {
  const [showModal, setShowModal] = useState(false)
  const [copied, setCopied] = useState(false)

  // QR is generated locally from the static store URL (no runtime network).
  const qrSrc = useMemo(() => {
    const qr = qrcode(0, 'M')
    qr.addData(STORE_URL)
    qr.make()
    return qr.createDataURL(5, 1)
  }, [])

  const onCopy = () => {
    copyText(STORE_URL)
    setCopied(true)
    window.setTimeout(() => setCopied(false), 1600)
  }

  return (
    <div className="mbt-shoot">
      <div className={`mbt-shoot__hero${companion ? ' is-connected' : ''}`}>
        <span className="mbt-shoot__badge">
          <Icon name={companion ? 'check' : 'layers'} size={13} />
          {companion ? 'Connected' : 'Add-on'}
        </span>
        <h3 className="mbt-shoot__title">mbt_shooting</h3>
        <p className="mbt-shoot__sub">
          {companion
            ? 'Companion connected — these systems are live and driving your weapons through the bridge. Configure them in the mbt_shooting menu.'
            : 'The paid combat companion to malisling: skill progression, weapon condition, malfunctions and a full shooting range. malisling stays free and standalone — shooting adds the depth players feel.'}
        </p>
        {companion ? (
          <button type="button" className="mbt-btn-primary" onClick={() => fetchNui('openShooting')}>
            <Icon name="cursor" size={14} /> Open mbt_shooting menu
          </button>
        ) : (
          <>
            <button type="button" className="mbt-btn-primary" onClick={() => setShowModal(true)}>
              <Icon name="cursor" size={14} /> See mbt_shooting on Tebex
            </button>
            <p className="mbt-shoot__trust">
              <Icon name="lock" size={12} /> Info only — nothing is sent from this resource.
            </p>
          </>
        )}
      </div>

      <div className="mbt-shoot__grid">
        {FEATURES.map((f) => (
          <div key={f.title} className={`mbt-shoot__card${companion ? ' is-active' : ' is-locked'}`}>
            <span className="mbt-shoot__ic"><Icon name={f.icon} size={16} /></span>
            <div className="mbt-shoot__cardtx">
              <span className="mbt-shoot__cardtitle">
                {f.title}
                <span className="mbt-shoot__tag">{companion ? 'active' : 'locked'}</span>
              </span>
              <span className="mbt-shoot__carddesc">{f.desc}</span>
            </div>
          </div>
        ))}
      </div>

      {showModal && (
        <div className="mbt-shoot__modal-overlay" onClick={() => setShowModal(false)}>
          <div
            className="mbt-shoot__modal"
            role="dialog"
            aria-modal="true"
            aria-label="See mbt_shooting on Tebex"
            onClick={(e) => e.stopPropagation()}
          >
            <button className="mbt-shoot__modal-x" onClick={() => setShowModal(false)} aria-label="Close">✕</button>
            <b>See mbt_shooting on Tebex</b>
            <p>Scan the code, or copy the link and open it in your browser. The Tebex page shows the latest and lets you get notified at launch.</p>
            <img className="mbt-shoot__qr" src={qrSrc} alt="QR code linking to the mbt_shooting Tebex page" />
            <div className="mbt-shoot__url">{STORE_URL}</div>
            <button type="button" className="mbt-btn-primary" onClick={onCopy}>
              <Icon name={copied ? 'check' : 'clipboard'} size={14} /> {copied ? 'Copied' : 'Copy link'}
            </button>
            <button type="button" className="mbt-shoot__discord" onClick={() => copyText(DISCORD_URL)}>
              Prefer Discord? Copy our invite
            </button>
            <p className="mbt-shoot__trust">
              <Icon name="lock" size={12} /> Nothing is sent from this resource.
            </p>
          </div>
        </div>
      )}
    </div>
  )
}
