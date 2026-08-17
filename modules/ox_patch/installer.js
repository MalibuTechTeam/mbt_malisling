// ─────────────────────────────────────────────────────────────────────────────
// mbt_malisling — automatic ox_inventory patcher (server, cross-platform)
//
// Why JS and not Lua: the FiveM Lua sandbox blocks io.open(write)/os.execute, and
// SaveResourceFile is blocked across resources. The server JS runtime is real
// Node, so `fs` can read/write the file directly — no PowerShell, no .bat, works
// on Windows AND Linux.
//
// On mbt_malisling start:
//   1. Locate ox_inventory/modules/weapon/client.lua (skips silently if ox absent).
//   2. If already patched (markers present) → nothing to do.
//   3. Otherwise: back up the original, inject the two fragments from
//      patches/ox_hook.lua + patches/ox_append.lua, write it back.
//   4. ox uses fxv2_oal (cached bytecode) → reload ox_inventory to recompile the
//      patched source (only when no players are connected).
//
// Safe: idempotent (markers), keeps a .bak, refuses to touch a file whose
// insertion points changed (ox updated) instead of corrupting it, and can be
// disabled with `set malisling:autopatch false`.
//
// NOTE: wrapped in an IIFE — FiveM evaluates server JS in a shared scope, so
// top-level `const`s would otherwise clash ("Identifier already declared").
// ─────────────────────────────────────────────────────────────────────────────

(function () {
  'use strict';

  const fs = require('fs');
  const path = require('path');

  const RESOURCE = GetCurrentResourceName();

  // Console logging — mirrors the canonical MBT logger (modules/utils/logger.lua):
  // [SLING] badge + level + timestamp, so these JS boot lines read like the rest of
  // the script. The JS runtime can't call the Lua MBTLog, so the format is replicated.
  const ts = () => new Date().toTimeString().slice(0, 8);
  // INFO is muted by default so a clean boot is quiet (the dashboard + the oxPatchResult
  // event already carry the patch status). Set `setr malisling:debug true` to see the boot
  // lines. WARN always prints — it means the patch actually failed.
  const DEBUG = GetConvar('malisling:debug', 'false') === 'true';
  const line = (m) => { if (DEBUG) console.log(`^4[SLING]^7 ^2[INFO  ${ts()}]^7 ${m}^0`); };
  const warn = (m) => console.log(`^4[SLING]^7 ^3[WARN  ${ts()}]^7 ${m}^0`);

  // Tell the Lua side the outcome so it can notify ACE admins in-game on failure
  // (a console line is easy to miss). Server-local event — clients can't spoof it.
  const report = (ok, reason) => { try { emit('mbt_malisling:oxPatchResult', !!ok, reason || ''); } catch (e) {} };

  const HOOK_MARKER   = 'mbt_malisling:holster_request';
  const APPEND_MARKER = 'mbt_malisling:sendAnim';
  // Bump this, and the line at the top of patches/ox_hook.lua, whenever a fragment
  // changes. Without it the check below sees a marker, says "already patched" and skips
  // — so every existing install keeps running the OLD fragment forever, and a new switch
  // in the dashboard does nothing for anyone but fresh installs, silently.
  // The marker is a HASH OF THE FRAGMENTS, not a counter and not the release version.
  //
  // It used to be a hand-written 'v2', with a comment telling whoever changed a fragment to
  // raise it. The first person to change one (adding `dictOut`) did not — so every server
  // carrying v2 kept running the old fragment and the Police style put the weapon away with
  // the wrong clip, silently, because from here everything looked fine.
  //
  // The release version was the obvious fix and it is the wrong one: it re-patches on every
  // bump even when no fragment moved, and re-patching means restoring the backup and rewriting
  // ox_inventory's source — on a live server the reload is skipped (players connected), so the
  // file on disk would stop matching the code actually running until the next restart. Churn on
  // a risky file, for nothing.
  //
  // The hash asks the only question that matters — did the fragment change — and answers it
  // without anyone remembering anything. Same fragments across ten releases: patched once.
  // One character different: re-patched, automatically.
  //
  // The version still goes into the file, as a second line that is NOT the marker. It answers
  // the support question ("which release patched this ox?") without driving the decision.
  const VERSION = GetResourceMetadata(RESOURCE, 'version', 0) || 'dev';
  const INSERT_POINT  = 'sleep = anim and anim[3] or 1200';
  const RETURN_POINT  = 'return Weapon';

  const readFile = (p) => {
    try { return fs.readFileSync(p, 'utf8'); } catch (e) { return null; }
  };

  function applyPatch() {
    if (GetConvar('malisling:autopatch', 'true') !== 'true') {
      warn('ox_inventory auto-patch disabled (malisling:autopatch=false).');
      return;
    }

    const oxPath = GetResourcePath('ox_inventory');
    // Empty/placeholder path = ox_inventory not on this server (qb-inventory users).
    if (!oxPath || oxPath === '' || oxPath === '/' || oxPath.includes('null')) return;

    const target = path.join(oxPath, 'modules', 'weapon', 'client.lua');
    let content = readFile(target);   // let: the stale-patch path below restores the backup into it
    if (content === null) {
      warn('ox_inventory found but its weapon file could not be read. Patch skipped.');
      report(false, 'cannot read ox_inventory weapon file');
      return;
    }

    // Fragments are read HERE and not further down, because the marker is derived from them:
    // the "is this current?" test below cannot be asked until they have been hashed.
    const self = GetResourcePath(RESOURCE);
    const hookRaw   = readFile(path.join(self, 'patches', 'ox_hook.lua'));
    const appendRaw = readFile(path.join(self, 'patches', 'ox_append.lua'));
    if (!hookRaw || !appendRaw) {
      warn('Patch fragments missing (patches/ox_hook.lua, patches/ox_append.lua). Patch aborted.');
      report(false, 'patch fragments missing');
      return;
    }
    // Hashed BEFORE substitution, so the placeholder — not the stamped version — is what gets
    // measured. Otherwise every release would change the hash and we would be back to
    // re-patching for nothing. 8 hex chars: this distinguishes fragment revisions on one
    // server, it is not a security boundary.
    const FRAGMENT_HASH = require('crypto').createHash('md5')
      .update(hookRaw).update(appendRaw).digest('hex').slice(0, 8);
    const VERSION_MARKER = `mbt_malisling patch ${FRAGMENT_HASH}`;

    const isPatched = content.includes(HOOK_MARKER) || content.includes(APPEND_MARKER);

    if (isPatched && content.includes(VERSION_MARKER)) {
      line('ox_inventory patch already present and current — nothing to do.');
      report(true);
      return;
    }

    // Patched, but by an older mbt_malisling. Restore the pristine backup and fall
    // through to a clean apply — the same thing the manual installers in tools/ do.
    // Patching on top of a patch would nest the old fragment inside the new one.
    if (isPatched) {
      const oldBak = `${target}.bak`;
      if (!fs.existsSync(oldBak)) {
        warn('ox_inventory carries an older mbt_malisling patch and no backup was found next to it.');
        warn(`Reinstall ox_inventory (or restore ${path.basename(target)} yourself), then restart. Leaving the file untouched.`);
        report(false, 'stale patch, no backup to restore');
        return;
      }
      const pristine = readFile(oldBak);
      if (pristine === null) {
        warn(`ox_inventory carries an older patch but its backup could not be read: ${oldBak}`);
        report(false, 'stale patch, backup unreadable');
        return;
      }
      line('ox_inventory carries an older patch — restoring the backup and reapplying.');
      content = pristine;
    }

    // The placeholder becomes the marker the check above searches for, so the string written
    // into ox and the string looked for cannot drift apart — both come from FRAGMENT_HASH on
    // the same run. The release version rides along on its own line, for reading, not testing.
    const stamp = (s) => s
      .replace(/__MBT_PATCH_VERSION__/g, `${FRAGMENT_HASH}\n-- applied by mbt_malisling ${VERSION}`);
    const hook   = stamp(hookRaw);
    const append = stamp(appendRaw);

    // Version guard — if ox changed these anchors, do NOT corrupt the file.
    if (!content.includes(INSERT_POINT) || content.lastIndexOf(RETURN_POINT) === -1) {
      warn('ox_inventory insertion point not found — unsupported or updated version. No changes made.');
      warn('Update mbt_malisling, or patch by hand — see the README (the tools/ installers look for these same anchors, so they will not help here).');
      report(false, 'unsupported ox_inventory version');
      return;
    }

    // Original backup (only the first time).
    const bak = `${target}.bak`;
    try { if (!fs.existsSync(bak)) fs.writeFileSync(bak, content, 'utf8'); }
    catch (e) { warn(`Backup failed (${e.message}). Continuing.`); }

    // 1) hook before the sleep line · 2) append before the LAST `return Weapon`.
    let patched = content.replace(INSERT_POINT, hook + INSERT_POINT);
    const idx = patched.lastIndexOf(RETURN_POINT);
    patched = patched.slice(0, idx) + append + '\n' + patched.slice(idx);

    if (!patched.includes(HOOK_MARKER) || !patched.includes(APPEND_MARKER)) {
      warn('Post-patch verification failed — nothing written.');
      return;
    }

    try {
      fs.writeFileSync(target, patched, 'utf8');
    } catch (e) {
      // Say where the manual installers are: this fires on hosts that block fs writes,
      // where the owner cannot fix the cause and needs the alternative, not a diagnosis.
      warn(`Failed to write ox_inventory (${e.message}).`);
      warn('The holster prompt needs that patch. Run the installer for your OS from this');
      warn('resource\'s tools/ folder — tools/install_ox_patch.sh or tools/install_ox_patch.ps1');
      warn('— then restart ox_inventory. Set `setr malisling:autopatch false` to stop retrying.');
      report(false, 'read-only filesystem / write blocked');
      return;
    }

    line('ox_inventory patched automatically. Backup: modules/weapon/client.lua.bak');
    report(true);

    // fxv2_oal serves cached bytecode → reload ox to recompile the patched source.
    const oxStarted = GetResourceState('ox_inventory') === 'started';
    const players = (typeof GetNumPlayerIndices === 'function') ? GetNumPlayerIndices() : 0;

    if (!oxStarted) {
      line('ox_inventory not started yet — it will load the patched version on its own.');
    } else if (players === 0) {
      line('Reloading ox_inventory to activate the patch...');
      ExecuteCommand('ensure ox_inventory');
    } else {
      warn(`${players} player(s) connected — ox_inventory NOT restarted to avoid disruption.`);
      warn('Restart ox_inventory (or the server) to activate the patch.');
    }
  }

  on('onResourceStart', (res) => {
    if (res !== RESOURCE) return;
    try { applyPatch(); } catch (e) { warn('Auto-patch error: ' + (e && e.message)); }
  });
})();
