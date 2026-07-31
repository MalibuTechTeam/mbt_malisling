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

<p align="center">
  <img src="https://dunb17ur4ymx4.cloudfront.net/packages/images/280c2cbddfa31ba913a1345362fbaafbf6f570fd.png" alt="MBT Malisling" />
</p>

**mbt_malisling** turns the weapon into a physical, visible object in the world. Guns ride on the player's back, hip, or a tactical sling; holstering plays gender-specific animations; weapons can jam, be thrown, dropped on death, inspected, named, marked with a serial, concealed under clothing, handed to another player, and stored on wall racks or in a vehicle trunk — all driven by a live React admin dashboard. Built for serious RP servers that want immersion and forensics without touching combat balance.

Free and open source — the discovery tier of the MBT weapon ecosystem.

---

## Features

### Carry & Sling

- **Visual sling** — the weapon shows on the player's body in **6 configurable positions** (back, secondary back, hip/side, melee slots), attached per weapon type
- **Tactical Sling prop** — optional realistic sling/rig prop with **multiple variants** and **per-job** assignment (e.g. police carry differently), positions tuned live in the dashboard
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
- **Synced attachments & flashlight** — scope/suppressor/flashlight show on the slung prop, and the flashlight state stays in sync (and works on the back)

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

- **Live React dashboard** (`/mbtsling`) — a premium NUI control panel to toggle and tune every feature in real time, organized by category (Core, Handling, Interaction, Forensics, World), persisted to the database
- **Two interface styles** — every on-screen prompt and HUD ships in **Standard** (fixed on screen) and **Cinematic** (filmic, anchored beside the weapon in the world). One switch in the dashboard changes all of them; nothing else about the script changes
- **NUI Position Editor** — a live, in-world editor (orbit camera, preview prop, button controls) to set each weapon type's sling position **per type and per job**, saved to the database
- **Dev tuning commands** — `/mbt_propedit`, `/mbt_racktune` and `/mbt_trunktune` print/copy ready-to-paste offset lines for fine placement (admin / debug only)

### Reliability & Security

- **Multi-framework** — auto-detects ESX, QBCore, QBox, or OX
- **Dual inventory** — `ox_inventory` (primary) with a full `qb-inventory` bridge fallback
- **Server-authoritative** — inventory, serials, ownership and transfers are validated on the server; clients are never trusted
- **Rate-limited net events** — every accepted NetEvent is throttled per server ID
- **Strict-ready state bags** — replicated state (concealed, scope, flashlight) is written only by the server
- **Self-managed persistence** — optional oxmysql tables are auto-created and feature-gated; without oxmysql the script runs DB-free (persistence features degrade gracefully)

### Localization

Built-in translations for **English, Italian, and French**. Add your own by creating a new file in the `locales/` folder.

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

5. Open the admin dashboard in-game with `/mbtsling` (admin only) and tune to taste.

---

## Configuration

Configuration is split across two files plus the live dashboard:

- **`default.lua`** — the complete default block for **every** feature (toggles, thresholds, animations, positions). Loaded first. Most values are meant to be tuned **live from the dashboard**, not by hand.
- **`config.lua`** — thin server settings only: `Admin` (command + ACE permission), `QBWeapons`, `Language`, `Debug`, `Notification`, `ReduceMotion`, `VersionCheck`, and the Discord audit **webhooks**. Loaded after `default.lua`, so it can override any default.
- **Dashboard** (`/mbtsling`) — toggles and tunes features at runtime; changes persist to the `mbt_malisling_config` database row and survive resource updates.

```lua
-- config.lua
MBT.Language = 'en'      -- 'en', 'it', 'fr'
MBT.Debug    = false     -- debug logs + dev tuning commands

MBT.Admin = {
    Command    = 'mbtsling',
    Permission = 'command.mbtsling',   -- ACE permission for the dashboard + placement
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

## Commands

| Command | Access | Action |
|---|---|---|
| `/mbtsling` | Admin (ACE) | Open the live configuration dashboard |
| `/mbt_placerack` · `/mbt_removerack` | Admin (ACE) | Place / remove a runtime weapon rack |
| `/mbt_rackcoords` | Anyone | Print a config line for a fixed rack at your position |
| `/mbt_racktune` | Admin / Debug | Live-tune the per-type weapon offsets on a wall rack |
| `/mbt_trunktune` | Near a stowed vehicle | Live-tune the trunk prop offset per vehicle class/model |
| `/mbt_propedit` | Debug | Live-tune a weapon type's body position (prints a config line) |

Holster confirm / cancel keys and feature keybinds are configurable in `default.lua` (per feature block).

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

## Media

- **Showcase:** [YouTube](https://www.youtube.com/watch?v=A5NDT_WTbo0)
- **Cfx release thread:** [forum.cfx.re](https://forum.cfx.re/t/free-esx-ox-qb-mbt-malisling-attached-weapons-flashlights-jamming-weapon-drop-throw/5118366)

---

## Credits

Developed by **Malibu Tech Team**.

In loving memory of **Gianmarco (DarkSideofTheCode)**, co-founder of MalibuTech. The original weapon-on-back work is his — this project only tries to improve it and carry it forward.

---

## License

This project is licensed under the [PolyForm Noncommercial License 1.0.0](LICENSE.md).

You are free to use and modify this software for **noncommercial purposes only** — personal use, hobby servers, research, and education. Any commercial use, redistribution for profit, or inclusion in paid products is prohibited without written permission from Malibu Tech Team.

> Required Notice: Copyright Malibu Tech Team (https://github.com/MalibuTechTeam)
