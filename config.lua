-- ════════════════════════════════════════════════════════════════════════════
-- mbt_malisling — server config (loaded AFTER default.lua)
--
-- Server-owner settings: admin access, framework interop, language, dev flags.
-- Feature gameplay defaults live in default.lua and are tuned LIVE from the admin
-- dashboard (/mbtsling) — you don't edit them here. You CAN hard-override any
-- default.lua value by re-declaring it below (this file loads after default.lua).
-- ════════════════════════════════════════════════════════════════════════════

MBT = MBT or {}

-- ── General ───────────────────────────────────────────────────────────────────
MBT.Debug              = true   -- dev logging; intentionally NOT exposed in the dashboard
MBT.Language           = 'en'   -- read-only in the dashboard; set the server language here

-- ── Admin ─────────────────────────────────────────────────────────────────────
MBT.Admin              = {
    Command    = 'mbtsling',          -- chat command that opens the admin dashboard
    -- Optional keybind to open the dashboard (FiveM keymapping, rebindable by the
    -- player in Settings → Key Bindings). '' = unbound (command only). Server
    -- re-checks the ACE before opening, so binding a key grants nothing extra.
    Key        = '',                  -- e.g. 'F10' · '' = no keybind
    -- ACE permission required. Defaults to 'command.<Command>'. The command is
    -- registered server-side so its ACE auto-registers: a server with the usual
    -- `add_ace group.admin command.* allow` (or a wildcard admin principal) works
    -- with NO extra server.cfg lines — same as mbt_elevator. Override only to use
    -- a custom ACE object.
    Permission = nil,
}

-- ── QB-weapons interop ─────────────────────────────────────────────────────────
-- Only relevant on QBCore + qb-weapons. qb-weapons owns its own pistol draw
-- animation (Config.WeapDraw), played by an independent loop on weapon switch.
--   'native'    → (default, drop-in) let qb-weapons draw sidearms. No malisling
--                 confirm modal for 'side' weapons on qb; the slung prop still
--                 works. No double animation, no extra setup.
--   'malisling' → ox-parity: malisling runs the confirm modal + our custom draw
--                 anim for sidearms. REQUIRES removing your sidearms from
--                 qb-weapons `Config.WeapDraw.weapons`, otherwise qb-weapons will
--                 double-play the draw animation (a startup warning reminds you).
MBT.QBWeapons          = {
    SidearmDrawMode = 'native',   -- 'native' | 'malisling'
    -- Play malisling's own holster/draw animation (MBT.PropInfo[type].HolsterAnim)
    -- on equip/holster. Use this when you've disabled qb-weapons' weapdraw so the
    -- draw still has a gesture. Cosmetic upper-body clip — never hides/oscillates the
    -- weapon, so it can't break the sling like weapdraw did. Clips/timing are tuned
    -- per weapon type in MBT.PropInfo (default.lua).
    DrawAnimation   = true,
}

-- Reduced motion for all NUI (dashboard + overlays). FiveM's CEF often doesn't
-- expose the OS "reduce motion" setting, so this is a manual switch: true freezes
-- entrance/exit animations, pulses and the looping jam indicator for motion-
-- sensitive players. Applied client-side via the `mbt-reduce-motion` root class.
MBT.ReduceMotion       = false

MBT.Notification       = function(data)
    lib.notify(data)
end
