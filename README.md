# MBT Malisling — Weapon on Back & Tactical Carry for FiveM

<p align="center">
  <img src="https://img.shields.io/badge/FiveM-Ready-00e676?style=for-the-badge&logo=fivem&logoColor=white" alt="FiveM Ready" />
  <img src="https://img.shields.io/badge/Framework-ESX%20%7C%20QBox%20%7C%20QBCore%20%7C%20OX-blue?style=for-the-badge" alt="Framework" />
  <img src="https://img.shields.io/badge/Inventory-ox__inventory%20%7C%20qb--inventory-orange?style=for-the-badge" alt="Inventory" />
  <img src="https://img.shields.io/badge/Version-2.0.0-informational?style=for-the-badge" alt="Version" />
  <img src="https://img.shields.io/badge/Lua-5.4-purple?style=for-the-badge&logo=lua" alt="Lua 5.4" />
  <img src="https://img.shields.io/badge/React-TypeScript-61DAFB?style=for-the-badge&logo=react" alt="React + TS" />
  <img src="https://img.shields.io/badge/License-PolyForm%20Noncommercial%201.0.0-blue?style=for-the-badge" alt="PolyForm Noncommercial 1.0.0" />
</p>

<!-- SLOT IMMAGINE — hero.
     Quando .github/release-assets/hero.png esiste, sostituisci l'src qui sotto con
     ".github/release-assets/hero.png" e cancella questo commento.
     L'URL attuale sta su un CDN CFX/Tebex che non controlliamo. -->
<p align="center">
  <img src="https://dunb17ur4ymx4.cloudfront.net/packages/images/280c2cbddfa31ba913a1345362fbaafbf6f570fd.png" alt="A player carrying a rifle slung across their back" />
</p>

<p align="center"><strong>Your weapon stops being an icon in a menu and becomes an object in the world.</strong></p>

It rides on your back or your hip where everyone can see it. You can hide it under a jacket, hand it to someone, leave brass on the floor when you fire, and read the serial off a gun to find out whose hands it passed through. Free, for any ESX, QBCore, QBox, or OX server — and it does not touch your combat balance.

---

<!-- SLOT IMMAGINE — preview.
     Decommenta questo blocco quando inspect.png e dashboard.png sono in
     .github/release-assets/. Vedi il README lì dentro per cosa devono mostrare.

## Preview

<p align="center">
  <img src=".github/release-assets/inspect.png" alt="The inspect overlay open in game, showing the weapon serial and its chain of custody" />
</p>

<p align="center"><em>Inspecting a weapon — the serial, and every player who has carried it.</em></p>

<p align="center">
  <img src=".github/release-assets/dashboard.png" alt="The admin dashboard open in game, with feature cards for one category" />
</p>

<p align="center"><em>Every feature is toggled and tuned from here, live, without touching a file.</em></p>
-->

## What players get

- **The gun is on your body.** Rifle across the back, sidearm on the hip, blade at the belt — visible to everyone, in positions the server can tune. Drawing it plays a real holster animation instead of the weapon appearing in your hands.
- **Hide it under your clothes.** A jacket conceals well, a light top conceals badly, a bare torso refuses. Walk around with a subtle tell that you are adjusting something at your belt.
- **Weapons jam.** How often depends on the condition of the gun, and you clear it under pressure while someone is shooting back.
- **Every weapon has a serial, and a memory.** Inspect one and you see its serial, its condition, the name engraved on it — and the list of players who have carried it before you.
- **Firing leaves brass.** Casings stay on the ground, tied to the weapon that fired them. Someone can read a serial off one, or you can pick them up and clean the scene.
- **Hand a weapon to another player.** They have to accept it. The transfer happens on the server, so nothing duplicates and nothing is lost.
- **Store guns where guns go.** Wall racks, gun lockers, and vehicle trunks — the weapon is physically in there, with its serial and condition intact.
- **Police can pat you down.** A badly concealed weapon is found instantly; a well-hidden one takes a search.

## What server owners get

- **It does not touch combat balance.** No recoil changes, no damage changes, no accuracy changes. Everything here is carry, identity, and consequence — so it drops into a server that already has its shooting tuned.
- **Configure it in game, not in files.** A React dashboard (`/mbt_malisling`) toggles and tunes every feature at runtime. Changes persist to the database and survive the next update, because they do not live in the resource folder.
- **Two interface styles, one switch.** Every prompt and HUD ships in **Standard** (fixed on screen) and **Cinematic** (anchored beside the weapon in the world). Nothing else about the script changes.
- **Clients are never trusted.** Inventory, serials, ownership and transfers are all resolved server-side. A faked event gets nothing, and every inbound net event is rate-limited per player.
- **One resource, four frameworks, two inventories.** ESX, QBCore, QBox and OX are auto-detected; `ox_inventory` is primary with a complete `qb-inventory` bridge.
- **oxmysql is optional.** Without it the script runs DB-free and only the persistence features step aside. Nothing breaks.
- **English, Italian and French included**, and adding a language is one file.

<details>
<summary><strong>Full feature list</strong> — every feature by system, for anyone implementing rather than evaluating</summary>

### Carry & Sling

- **Visual sling** — the weapon shows on the player's body in **6 configurable positions** (back, secondary back, hip/side, melee slots), attached per weapon type
- **Tactical Sling prop** — a strap/rig worn on the body, on by default: **three prop variants ship with the resource** and can be assigned **per job** (e.g. police carry differently), with positions tuned live in the dashboard
- **Holster prompt** — drawing a sidearm shows a branded confirm prompt with **gender-specific holster animations** and synced holster/unholster sounds (including a blade sound for melee)
- **Concealed Carry** — toggle to hide a weapon under clothing; server-authoritative, replicated via state bag. Clothing is evaluated (bare torso refuses, light tops conceal *poorly*, jackets conceal *well*) with subtle "adjust your belt" tells
- **Low Ready** — a choreographed chest-carry stance
- **Vehicle Smart Hiding** — the sling tucks away sensibly while in vehicles

### Weapon Handling

- **Weapon Jamming** — base jam chance scaled by weapon condition, cleared with a short key-press minigame
- **Weapon Throw** — throw the weapon forward (the original physics feel), with an **optional hold-to-charge power throw** (tap = normal, hold = farther; off by default)
- **Drop on Death** — the equipped weapon falls to the ground as a real, lootable prop
- **Weapon Drop rework** — dropped weapons spawn as the correct model with an `ox_target` interaction and a despawn timer
- **Weapon Safety Toggle** — flip the safety on/off (fused into the weapon-status pill)
- **Charge Weapon** — rack the slide as an intimidation gesture, broadcast to nearby players
- **Suppressor Heat Glow** — the suppressor heats up under sustained fire and glows orange → red, cooling on the slung prop after holstering (purely visual)
- **Weapon Weight / Carry Penalty** — carrying many long guns slightly slows movement (preset: off / light / medium / heavy / custom)
- **No-Draw Zones** — configurable areas where drawing a weapon is disabled, with a cooldowned notice

### Inspection & Identity

- **Weapon Inspect** — hold a key to examine the held weapon: an inspection animation plus an overlay with serial, condition, custom name and ammo (with an optional *vague ammo* mode)
- **Weapon Condition HUD** — discrete condition pips (tier 1–5) shown in the weapon-status pill
- **Custom Weapon Name** — engrave a personal name onto a weapon
- **Showcase Poses** — synced presentation poses for group photos (late-join aware)
- **Synced attachments & flashlight** — scope/suppressor/flashlight show on the slung prop, and the flashlight still lights the world from your back. Its saved state survives equip and relog (see *Known limitations* for the engine-level caveat)

### Interaction & Social

- **Physical Weapon Handoff** — hand your weapon to a nearby player: a key-driven consent prompt on the receiver, a server-atomic transfer with rollback, intact metadata, and synced give/take animations
- **Ammo Sharing** — share ammunition with a nearby player using the same consent flow; the server resolves the right ammo type and transfers atomically with rollback
- **Pat-down (LEO)** — a job-whitelisted officer can pat someone down (with consent, cuffed-bypass): reveals carried weapons and their carry status (visible / concealed) plus serials, with an audit webhook. Poorly concealed weapons are found instantly; well-concealed ones need a search

### Forensics

- **Serial Number System** — every weapon is guaranteed a serial on first safe contact with the system (writes only on safe transitions — never during fire). Auditable `MBT-XXXXXXXX` format or ox-like
- **Chain of Custody** — a server-side per-serial ledger of who has held a weapon, surfaced in the Inspect overlay
- **Forensic Shell Casings** — firing has a server-side chance to leave a brass casing on the ground (golden glint); examine it to read the (masked) serial and age, pick it up to clean the scene. Ephemeral, in-memory, FIFO-capped

### Storage

- **Weapon Rack / Gun Locker** — fixed world racks (config locations) **and** player-placeable racks from an inventory item (carry → rotate → mount). Contents sync via GlobalState (no networked-prop jitter). Per-job access and a custom key-driven picker showing each weapon's serial, condition and engraved name
- **Vehicle Trunk Weapon Rack** — stow and retrieve long guns in a vehicle's trunk via `ox_target` on the boot; respects the vehicle lock; prop synced per plate

### Admin & Configuration

- **Live React dashboard** (`/mbt_malisling`) — a premium NUI control panel to toggle and tune every feature in real time, organized by category (Core, Handling, Interaction, Forensics, World), persisted to the database
- **Two interface styles** — every on-screen prompt and HUD ships in **Standard** (fixed on screen) and **Cinematic** (filmic, anchored beside the weapon in the world). One switch in the dashboard changes all of them; nothing else about the script changes
- **NUI Position Editor** — a live, in-world editor (orbit camera, preview prop, button controls) to set each weapon type's sling position **per type and per job**, saved to the database
- **Dev tuning commands** — `/mbt_racktune` and `/mbt_trunktune` print ready-to-paste offset lines for fine placement (admin / debug only)

</details>

---

## Requirements

| Dependency | Notes |
|---|---|
| [FiveM Server](https://fivem.net) | OneSync **enabled** (required) |
| [ox_lib](https://github.com/overextended/ox_lib) | Required |
| [ox_inventory](https://github.com/overextended/ox_inventory) **or** [qb-inventory](https://github.com/qbcore-framework/qb-inventory) | One of the two |
| [oxmysql](https://github.com/overextended/oxmysql) | Optional — enables persistence (racks, trunk, custody, positions). Already present on most servers |

Frameworks: **ESX · QBCore · QBox · OX** (auto-detected).

---

## Installation

> ### ⚠️ Upgrading from 1.x? Replace the whole folder — do **not** keep your old `config.lua`
>
> The old `config.lua` opens with `MBT = {}`, and it is loaded **after** `default.lua`. Keeping it wipes every default the new version needs, and the script will not start.
>
> Configuration also moved. In 1.x everything lived in `config.lua`; now feature tuning lives in `default.lua` and is meant to be changed **live from the dashboard**, while `config.lua` holds only server settings (admin command, language, notifications, webhooks). **Your 1.x tuning will not carry over** — set it again from the dashboard, where it will persist to the database and survive future updates.
>
> Delete the old folder, drop in the new one, and re-apply your settings. There is no migration path: 2.0 is effectively a different script.

1. Download or clone this repository into your server's `resources` folder.

2. Add to your `server.cfg` (after your framework and inventory):
   ```cfg
   ensure ox_lib
   ensure ox_inventory      # or qb-inventory
   ensure mbt_malisling
   ```
   > After the first start, **restart the server once** so the sling convar applies cleanly.

3. **(Optional) Register the gun-rack item** if you want players to place racks from inventory.

   **ox_inventory** — `ox_inventory/data/items.lua`:
   ```lua
   ['gunrack'] = {
       label  = 'Gun Rack',
       weight = 8000,
       stack  = false,
       server = { export = 'mbt_malisling.gunrack' },
   },
   ```

   **qb-inventory** — `qb-core/shared/items.lua`:
   ```lua
   ['gunrack'] = { name = 'gunrack', label = 'Gun Rack', weight = 8000, type = 'item',
       image = 'gunrack.png', unique = true, useable = true, shouldClose = true,
       description = 'Wall-mountable weapon rack' },
   ```
   > The item name, the `server.export` suffix, and `MBT.WeaponRack.Placement.Item` in `default.lua` must all match.

4. Restart your server, or run `ensure mbt_malisling` in the live console.

5. Open the admin dashboard in-game with `/mbt_malisling` (admin only) and tune to taste.

---

## Configuration

Configuration is split across two files plus the live dashboard:

- **`default.lua`** — the complete default block for **every** feature (toggles, thresholds, animations, positions). Loaded first. Most values are meant to be tuned **live from the dashboard**, not by hand.
- **`config.lua`** — thin server settings only: `Admin` (command + ACE permission), `QBWeapons`, `Language`, `Debug`, `Notification`, `ReduceMotion`, `VersionCheck`, and the Discord audit **webhooks**. Loaded after `default.lua`, so it can override any default.
- **Dashboard** (`/mbt_malisling`) — toggles and tunes features at runtime; changes persist to the `mbt_malisling_config` database row and survive resource updates.

```lua
-- config.lua
MBT.Language = 'en'      -- 'en', 'it', 'fr'
MBT.Debug    = false     -- debug logs + dev tuning commands

MBT.Admin = {
    Command    = 'mbt_malisling',
    Permission = 'command.mbt_malisling',   -- ACE permission for the dashboard + placement
}
```

> **Notifications:** the notify function in `config.lua` ships presets for **ox_lib**, **ESX**, **QBCore**, **QBox**, and native GTA — uncomment the one that matches your server.

### Discord audit logs

Weapon drops, armory racks and pat-downs can each post to a Discord webhook. The URLs live in `config.lua` and **not** in the dashboard: a webhook is a secret, and the dashboard is rendered on the player's side. They sit behind an `IsDuplicityVersion()` guard so they never reach a client.

```lua
-- config.lua
if IsDuplicityVersion() then
    MBT.WeaponDrop.Logging.Webhook = 'https://discord.com/api/webhooks/...'
    MBT.WeaponRack.Logging.Webhook = ''
    MBT.PatDown.Logging.Webhook    = ''
end
```

Leave a URL empty (the default) and that log stays off. No webhook, no logging — nothing else to switch.

### Update check

At startup the server asks the GitHub Releases API whether a newer version exists, and the dashboard shows a badge if so. It is one plain GET and sends nothing about your server. Set `MBT.VersionCheck = false` in `config.lua` if you'd rather it made no outbound request at all.

---

## Keybinds

Every one of these is a FiveM keymapping, so a player can rebind it in **Settings → Key Bindings → FiveM**. The defaults live in each feature's block in `default.lua` as `Key`.

| Key | Action |
|---|---|
| **I** *(hold)* | Inspect the held weapon |
| **K** *(hold)* | Throw the held weapon (hold to charge, if enabled) |
| **U** | Conceal / reveal the weapon under clothing |
| **END** | Toggle the safety |
| **INSERT** | Charge the weapon (rack the slide) |
| **HOME** | Toggle low ready (chest carry) |
| **G** | Hand your weapon to a nearby player |
| **H** | Share ammo with a nearby player |
| **Y** | Pat down a nearby person (job-gated) |

Drawing a sidearm shows a confirm prompt: its two keys are set in `MBT.HolsterControls`.

## Commands

| Command | Access | Action |
|---|---|---|
| `/mbt_malisling` | Admin (ACE) | Open the live configuration dashboard |
| `/pose` · `/pose <n>` | Anyone | Cycle or pick a showcase pose. **Command only — no default key** |
| `/weaponname` | Anyone | Engrave a name on the held weapon. **Command only — no default key** |
| `/mbt_placerack` · `/mbt_removerack` | Admin (ACE) | Place / remove a runtime weapon rack |
| `/mbt_rackcount` | Anyone | List the racks you have placed, and your limit |
| `/mbt_clearmyracks` | Anyone | Remove all of your own empty placed racks |
| `/mbt_rackcoords` | Anyone | Print a config line for a fixed rack at your position |
| `/mbt_racktune` | Admin / Debug | Live-tune the per-type weapon offsets on a wall rack |
| `/mbt_trunktune` | Near a stowed vehicle | Live-tune the trunk prop offset per vehicle class/model |
| `/mbt_casingzone` | Admin / Debug | Size a no-casing zone in-world (ranges, armories) and print a ready-to-paste `ExcludeZones` line |

Every command name is configurable — each feature's block in `default.lua` has a `Command` field, and the dashboard's is `MBT.Admin.Command` in `config.lua`.

---

## Exports

Client-side, for other resources on your server. These are the supported ones — treat anything else you find in the source as internal and subject to change.

| Export | Returns | Use it for |
|---|---|---|
| `exports.mbt_malisling:ResetWeaponsOnBack()` | — | Re-read the player's inventory and respawn the slung props. Call it after your script changes the ped model or outfit: attached props don't survive a ped swap, so this restores them. |
| `exports.mbt_malisling:dropCurrentWeapon()` | — | Drop the weapon in hand on the ground as a real, lootable object (same path as the drop-on-death and throw features). Useful for surrender/arrest flows. |
| `exports.mbt_malisling:IsWeaponSafetyOn()` | `boolean` | Whether the held weapon's safety is engaged, e.g. to mirror it in your own HUD. |

```lua
-- after applying a new outfit or ped model
exports.mbt_malisling:ResetWeaponsOnBack()
```

---

## Under the hood

For anyone reading the code before trusting it on their server.

- **Server-authoritative.** Inventory contents, serials, ownership and transfers are resolved from the server's own view. A client that claims to hold something it does not hold gets nothing.
- **Per-event rate limiting** on every inbound net event, keyed per server ID.
- **Serials are written only on safe transitions** — never while a weapon is being fired — because writing item metadata mid-fire triggers an inventory refresh that would visibly re-spawn the slung prop.
- **Strict-ready state bags.** Replicated state (concealed, scope, flashlight) is written by the server only, so a client cannot declare itself concealed.
- **Handoff and ammo transfer are atomic**, with rollback. Both sides consent, and a failure halfway leaves the item where it started rather than in neither inventory.
- **Chain of custody lives outside the weapon's metadata**, deliberately: writing it on the equip path would re-trigger the inventory update above.
- **Self-managed persistence.** The optional oxmysql tables are created on first run and prefixed `mbt_malisling_*`. Without oxmysql those features gate themselves off and the rest runs DB-free.
- **The `ox_inventory` patch fails loudly.** It keeps a `.bak`, is idempotent, and refuses to write if a future update moves the anchors it looks for, rather than corrupting the file.

---

## Known limitations

Written down rather than left for you to discover.

**A slung weapon's flashlight follows the weapon in your hands.** Put a rifle with the flashlight component on your back while the light is on, then toggle the light on a *different* weapon, and the slung one changes with it.

This is the engine, not the script: GTA ties a weapon object's flashlight rendering to a **single flashlight state on the ped**, so any `SetFlashLightEnabled` — from us or from any other resource — reaches every weapon object that ped owns, including props on the back. We tried re-asserting the light source per object, blocking the toggle control, monitoring and reverting the state, and drawing a custom light; each either broke the rendering, was bypassable, flickered, or left the physical lens flickering anyway because the engine draws it. Fixing it properly means replacing the whole flashlight system, which is more than this script should be. The flashlight's **saved state** across equip and relog is correct — it is only the live mirroring that bleeds.

**On `qb-inventory`, prompts are a beat less immediate.** `ox_inventory` fires native events we hook directly; qb has no equivalent, so that bridge polls the inventory for changes. Everything works, but expect slightly less snappy holster prompts. **If you have the choice, pair this with `ox_inventory`.**

---

## qb-inventory notes

The `qb-inventory` bridge has full feature parity with `ox_inventory` on all load-bearing paths (stow/retrieve/transfer preserve the serial, no duplication). A few qb-specific notes:

- **qb-weapons:** disable its draw animation (`client/weapdraw.lua`) — it animates every weapon swap through `UNARMED`, which conflicts with any weapon-on-back system. The dashboard surfaces a warning when it's active.
- **Ammo Sharing:** ammo is matched by qb-core's default ammo item names (`pistol_ammo`, `rifle_ammo`, …). If you **renamed** your ammo items, extend the `QB_AMMO` map in `modules/inventory/qb/server.lua`.
- **Equip-on-retrieve** at a rack/trunk is best-effort on qb (the weapon is always returned to the inventory; the auto-equip may occasionally no-op due to a replication-timing window).
- **Forensic casing serials** fall back to the client-reported value on qb (ox resolves them server-side).
- Player-placed racks and other persistence features require **oxmysql**.

---

## FAQ

**Does it work with ESX, QBCore, QBox, and OX?**
Yes — the framework is auto-detected. Inventory is `ox_inventory` first, with a complete `qb-inventory` fallback.

**Do I need oxmysql?**
No. Without it the script runs DB-free; only the persistence features (placed racks, trunk storage, chain of custody, saved positions) are disabled, and everything else works.

**Does it modify ox_inventory?**
It applies a small, automatic patch to `ox_inventory`'s weapon module at startup so the holster prompt can hook the equip/disarm flow. It is re-applied on every start, keeps a `.bak`, and refuses to touch the file if a future `ox_inventory` update moves the anchors it looks for — it fails loudly instead of corrupting anything. If it can't write (read-only or locked-down host), see below.

**The patch failed. How do I apply it manually?**
Both manual installers ship in `tools/` — run the one for your server's OS:

```bash
# Linux / macOS
chmod +x tools/install_ox_patch.sh && ./tools/install_ox_patch.sh
```
```powershell
# Windows
.\tools\install_ox_patch.ps1
```

Each finds `ox_inventory` on its own (or takes the path as an argument), keeps a `.bak`, and is safe to re-run — it restores its own backup first, so the patch is never applied twice. The usual reason to need them is a permissions one: the server process could not write to `ox_inventory`, and running as a user who can fixes it.

If you would rather do it yourself, only one file changes: **`ox_inventory/modules/weapon/client.lua`**.

1. Back it up.
2. Paste the contents of `patches/ox_hook.lua` **immediately before** the line:
   ```lua
   sleep = anim and anim[3] or 1200
   ```
3. Paste the contents of `patches/ox_append.lua` **immediately before the last** `return Weapon` in the file.
4. Restart `ox_inventory`, then `mbt_malisling`.

That is the whole patch — the first block asks malisling whether to holster or keep the weapon in hand, the second lets it register per-weapon holster animations. Re-apply after any `ox_inventory` update.

To stop the resource patching `ox_inventory` on its own — because you applied it yourself, or your host manages that file — put this in `server.cfg`:

```cfg
setr malisling:autopatch false
```

**My weapon doesn't show on my back.**
Make sure `ox_inventory`'s weapon animation convar is enabled (`inventory:weaponanims 1`), and on qb that `qb-weapons`' weapon-draw animation is disabled. Check the F8 console for warnings.

**How do I add a language?**
Copy `locales/en.lua` to e.g. `locales/de.lua`, translate the strings, and set `MBT.Language = 'de'`.

**How do I position the slung weapon / rack weapons?**
Use the dashboard's **Position Editor** for body positions (per type and per job), and `/mbt_racktune` / `/mbt_trunktune` for rack and trunk offsets.

---

## Credits

Developed by the **Malibu Tech Team**.

### Gianmarco — *DarkSideofTheCode*

MalibuTech was founded with my brother Gianmarco. He was the scripter, and Malisling was his — the first commits are from January 2023, and he kept working on it through that June.

Three of his decisions are still load-bearing in 2.0, after everything around them has been rewritten:

**The jamming never polls.** He hung it on `CEventGunShotWhizzedBy`, a game event that only fires when a round passes close by. There is no thread asking "is he shooting yet" — the cost is zero until a shot is actually fired. It is still exactly where he put it.

**`dropCurrentWeapon` is his.** He added it in June 2023 so other resources could make a player drop the gun in their hands. It is still in the export table above, unchanged, and it is what a surrender or arrest script calls today.

**He built the resource to know male peds from female ones**, and gave every carry position a separate value for each — then left the two sets identical, with tuning the female offsets still on his list. The structure he left is the reason the Position Editor in this version can be per body, per weapon type, and per job at all.

The code around all of it has been rewritten many times since. The shape of it is still his.

`DarkSideofTheCode` was his name in the FiveM community. It stays on his work.

---

Thanks to the FiveM community for continuous feedback and testing.

---

## License

This project is licensed under the [PolyForm Noncommercial License 1.0.0](LICENSE.md).

You are free to use and modify this software for **noncommercial purposes only** — personal use, hobby servers, research, and education. Any commercial use, redistribution for profit, or inclusion in paid products is prohibited without written permission from Malibu Tech Team.

---

## Media

- **Showcase:** [YouTube](https://www.youtube.com/watch?v=A5NDT_WTbo0)
- **Cfx release thread:** [forum.cfx.re](https://forum.cfx.re/t/free-esx-ox-qb-mbt-malisling-attached-weapons-flashlights-jamming-weapon-drop-throw/5118366)
- **Documentation:** [malibutechteam.com/docs](https://malibutechteam.com/docs/mbt-malisling/introduction)

Copyright 2023-2026 MalibuTech.
