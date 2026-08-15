-- ════════════════════════════════════════════════════════════════════════════
-- mbt_malisling — server config (loaded AFTER default.lua)
--
-- Server-owner settings: admin access, framework interop, language, dev flags.
-- Feature gameplay defaults live in default.lua and are tuned LIVE from the admin
-- dashboard (/mbt_malisling) — you don't edit them here. You CAN hard-override any
-- default.lua value by re-declaring it below (this file loads after default.lua).
-- ════════════════════════════════════════════════════════════════════════════

MBT = MBT or {}

-- ── General ───────────────────────────────────────────────────────────────────
MBT.Debug              = true  -- dev logging; intentionally NOT exposed in the dashboard
MBT.Language           = 'en'   -- read-only in the dashboard; set the server language here

-- ── Admin ─────────────────────────────────────────────────────────────────────
MBT.Admin              = {
    -- Brand rule: the admin command IS the resource name. Nothing to remember beyond
    -- the line already in your server.cfg, and two resources can never collide.
    -- See patterns/admin-command-naming.md in the vault.
    Command    = 'mbt_malisling',     -- chat command that opens the admin dashboard
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

-- ── Keybinds ──────────────────────────────────────────────────────────────────
-- Every key the resource binds, in one place. They live HERE and not in default.lua
-- for a concrete reason: they are the one setting you cannot tune live. Bindings are
-- registered once at resource start, and **FiveM then caches them per player profile**
-- — so changing a key later does nothing for anyone who has already joined. Set them
-- before your first start; after that, players rebind in
-- GTA Settings → Key Bindings → FiveM.
--
-- '' = no key, command only (each feature keeps its chat command either way).
-- Defaults also live in default.lua, so deleting a line here falls back rather than
-- breaking. And like every file in this folder, config.lua is REPLACED on update —
-- keep a note of your keys, or you will re-do this after the next release.
-- (The admin dashboard key is in MBT.Admin above, next to its command and ACE.)

MBT.Inspect.Key        = 'I'        -- hold: examine the weapon in hand (serial, condition)
MBT.ConcealedCarry.Key = 'U'        -- conceal / reveal (the weapon must be holstered)
MBT.PatDown.Key        = 'Y'        -- hold near a person: frisk them (allowed jobs only)
MBT.Handoff.Key        = 'G'        -- hand the weapon you hold to a nearby player
MBT.AmmoSharing.Key    = 'H'        -- give ammo to a nearby player
MBT.Throw.Key          = 'K'        -- throw the weapon in hand
MBT.LowReady.Key       = 'HOME'     -- low ready / chest carry stance
MBT.Safety.Key         = 'END'      -- toggle the safety
MBT.ChargeWeapon.Key   = 'INSERT'   -- charge (rack) the weapon
MBT.WeaponName.Key     = ''         -- engrave a custom name on a weapon
MBT.ShowcasePoses.Key  = ''         -- showcase poses

-- Holster prompt: two bindings, and each carries the INPUT FAMILY it belongs to.
-- Change Key and Input together — a keyboard key with Input = 'MOUSE_BUTTON' simply
-- never fires, and it fails silently.
MBT.HolsterControls.Confirm.Key   = 'MOUSE_RIGHT'
MBT.HolsterControls.Confirm.Input = 'MOUSE_BUTTON'   -- 'MOUSE_BUTTON' | 'keyboard'
MBT.HolsterControls.Cancel.Key    = 'BACK'
MBT.HolsterControls.Cancel.Input  = 'keyboard'

-- ── Hide sling props per job ──────────────────────────────────────────────────
-- Police uniforms — GTA's own and most EUP packs — have a duty holster with a pistol
-- MODELLED INTO THE CLOTHING. We then attach ours on the same hip, and the officer
-- visibly carries two. The second one lives in the mesh: we can't see it or move it,
-- we can only decline to add a third thing to the picture.
--
-- Keys are BODY SLOTS, not weapon families: `side` is every pistol, `back` is every long
-- gun, then back2 / melee / melee2 / melee3. Hiding applies to everyone who sees that
-- player, not just to themselves — it is their uniform.
--
-- ⚠️ The rule is per JOB, not per outfit. An officer in plain clothes has the same job
-- and no modelled holster, so this takes their pistol away too. Reading the ped's
-- clothing to tell the difference is not something we can ship: the drawable indices
-- change with every EUP pack. If your server needs the distinction, use two jobs.
--
-- Hiding is the blunt option. MBT.CustomPropPosition in default.lua does the other half
-- and already works: move the pistol to the thigh instead of removing it.
--
-- The "*" job means everyone, whatever they do for a living. Use it when a slot should
-- never show at all — pistols that draw normally and never hang on the hip, say — instead
-- of listing every job on the server to mean "never".
--
-- ⚠️ This table is the SEED, not the live value. It fills the dashboard the first time the
-- resource starts against an empty `mbt_malisling_config` row; from then on that row is
-- canonical and editing here changes nothing. That is the point: this file is REPLACED on
-- every update and the DB row is not, so the rules you set once are not the ones that
-- vanish. Edit them under Core → HIDDEN BY JOB, or use that section's
-- "Restore from config.lua" to drop the saved rules and come back to this table.
MBT.HiddenByJob = {
    -- ["*"]      = { ["side"] = true },     -- nobody ever shows a holstered pistol
    -- ["police"] = { ["side"] = true },     -- only the uniform that already has one
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

-- One configurable sink: uncomment the preset for your notification resource. Called
-- with { title?, description, type?, icon?, duration? } (also via MBT.NotifyLabel).
-- Every preset ships commented on purpose — pick the one your server actually runs.
-- ox_lib is already a dependency of this resource, so lib.notify is the safest choice
-- if you have no preference. Until you uncomment one, notifications are silent.
MBT.Notification       = function(data)

    -- mbt_visual (our own notification system — not published yet):
    -- exports.mbt_visual:notify({ title = data.title, description = data.description, type = data.type or 'inform', icon = data.icon, duration = data.duration or 5000 })

    -- ox_lib (required by this resource):
    -- lib.notify(data)

    -- Native GTA feed:
    -- BeginTextCommandThefeedPost('STRING')
    -- AddTextComponentSubstringPlayerName(data.description or data.title or '')
    -- EndTextCommandThefeedPostTicker(false, true)

    -- ESX:
    -- ESX.ShowNotification(data.description or data.title)

    -- QBCore:
    -- QBCore.Functions.Notify(data.description or data.title, data.type or 'primary')
end

-- ── Discord audit-log webhooks — SERVER-ONLY secrets ───────────────────────────
-- Set here, NOT in the dashboard: a webhook URL is a secret, and the dashboard is
-- client-rendered NUI. This block is guarded by IsDuplicityVersion() (true only on
-- the server) so the URLs NEVER reach any client, and they're never stored in the DB.
-- Paste your Discord webhook URL to enable that audit log; leave '' (the default) to
-- keep it off. No webhook = no logging.
if IsDuplicityVersion() then
    MBT.WeaponDrop.Logging.Webhook = ''   -- weapon drop / throw / death-drop (who, weapon, serial, coords)
    MBT.WeaponRack.Logging.Webhook = ''   -- armory rack store/take (who, weapon, serial, job, rack)
    MBT.PatDown.Logging.Webhook    = ''   -- frisk (officer, suspect, weapons, serials, concealment)

    -- Optional: force a feature's log off even with a URL set, or rename the bot.
    -- MBT.WeaponDrop.Logging.Enabled = false
    -- MBT.WeaponDrop.Logging.BotName = 'MBT Malisling'
end
