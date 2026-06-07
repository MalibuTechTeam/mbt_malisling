// ─────────────────────────────────────────────────────────────────────────────
// mbt_malisling — automatic ox_inventory patcher (server, cross-platform)
//
// Why JS and not Lua: the FiveM Lua sandbox blocks io.open(write)/os.execute, and
// SaveResourceFile is blocked across resources. The server JS runtime is real
// Node, so `fs` can read/write the file directly — no PowerShell, no .bat, works
// on Windows AND Linux.
//
// What it does, on mbt_malisling start:
//   1. Locate ox_inventory/modules/weapon/client.lua (skips silently if ox absent).
//   2. If already patched (markers present) → nothing to do.
//   3. Otherwise: back up the pristine file, inject the two patch fragments from
//      patches/ox_hook.lua + patches/ox_append.lua, write it back.
//   4. ox uses fxv2_oal (cached bytecode) so the running copy won't see the edit —
//      reload ox_inventory to recompile the patched source (only when no players
//      are connected; otherwise log and ask for a restart so we never disrupt a
//      live server).
//
// Safe by design: idempotent (marker-guarded), keeps a .bak, refuses to touch a
// file whose insertion points changed (ox updated) instead of corrupting it, and
// can be turned off with `set malisling:autopatch false`.
// ─────────────────────────────────────────────────────────────────────────────

const fs = require('fs');
const path = require('path');

const RESOURCE = GetCurrentResourceName();

const log  = (m) => console.log(`^2[mbt_malisling]^7 ${m}`);
const warn = (m) => console.log(`^3[mbt_malisling]^7 ${m}`);
const err  = (m) => console.log(`^1[mbt_malisling]^7 ${m}`);

const HOOK_MARKER   = 'mbt_malisling:holster_request';
const APPEND_MARKER = 'mbt_malisling:sendAnim';
const INSERT_POINT  = 'sleep = anim and anim[3] or 1200';
const RETURN_POINT  = 'return Weapon';

function read(p) {
  try { return fs.readFileSync(p, 'utf8'); } catch (e) { return null; }
}

function applyPatch() {
  if (GetConvar('malisling:autopatch', 'true') !== 'true') {
    warn('Auto-patch ox_inventory disabilitato (malisling:autopatch=false).');
    return;
  }

  const oxPath = GetResourcePath('ox_inventory');
  // Empty/placeholder path = ox_inventory not on this server (qb-inventory users).
  if (!oxPath || oxPath === '' || oxPath === '/' || oxPath.includes('null')) return;

  const target = path.join(oxPath, 'modules', 'weapon', 'client.lua');
  const content = read(target);
  if (content === null) {
    warn(`ox_inventory rilevato ma non riesco a leggere ${target}. Patch saltata.`);
    return;
  }

  if (content.includes(HOOK_MARKER) && content.includes(APPEND_MARKER)) {
    log('Patch ox_inventory gia\' presente. OK.');
    return;
  }

  // Patch fragments live in our own resource — single source of truth.
  const self = GetResourcePath(RESOURCE);
  const hook   = read(path.join(self, 'patches', 'ox_hook.lua'));
  const append = read(path.join(self, 'patches', 'ox_append.lua'));
  if (!hook || !append) {
    err('File patch mancanti (patches/ox_hook.lua, patches/ox_append.lua). Patch annullata.');
    return;
  }

  // Version guard — if ox_inventory changed these anchors, do NOT corrupt the file.
  if (!content.includes(INSERT_POINT) || content.lastIndexOf(RETURN_POINT) === -1) {
    warn('Punto di inserimento ox_inventory non trovato (versione non supportata o aggiornata). ' +
         'Nessuna modifica fatta — aggiorna mbt_malisling o applica la patch manualmente.');
    return;
  }

  // Pristine backup (only the first time).
  const bak = `${target}.bak`;
  try { if (!fs.existsSync(bak)) fs.writeFileSync(bak, content, 'utf8'); }
  catch (e) { warn(`Backup non riuscito (${e.message}). Procedo.`); }

  // 1) hook before the sleep line · 2) append before the LAST `return Weapon`.
  let patched = content.replace(INSERT_POINT, hook + INSERT_POINT);
  const idx = patched.lastIndexOf(RETURN_POINT);
  patched = patched.slice(0, idx) + append + '\n' + patched.slice(idx);

  if (!patched.includes(HOOK_MARKER) || !patched.includes(APPEND_MARKER)) {
    err('Verifica post-patch fallita — niente scritto.');
    return;
  }

  try {
    fs.writeFileSync(target, patched, 'utf8');
  } catch (e) {
    err(`Scrittura ox_inventory fallita (${e.message}). Filesystem read-only? ` +
        'Applica la patch manualmente (install_ox_patch.ps1) o abilita la scrittura.');
    return;
  }

  log(`Patch ox_inventory applicata. Backup: ${path.basename(bak)}`);

  // fxv2_oal serves cached bytecode → reload ox to recompile the patched source.
  const oxStarted = GetResourceState('ox_inventory') === 'started';
  const players = (typeof GetNumPlayerIndices === 'function') ? GetNumPlayerIndices() : 0;

  if (!oxStarted) {
    log('ox_inventory non ancora avviato: caricherà la versione patchata da solo.');
  } else if (players === 0) {
    log('Ricarico ox_inventory per attivare la patch...');
    ExecuteCommand('ensure ox_inventory');
  } else {
    warn(`Patch scritta, ma ${players} player connessi: NON riavvio ox_inventory ora. ` +
         'Riavvia ox_inventory (o il server) per attivarla.');
  }
}

on('onResourceStart', (res) => {
  if (res !== RESOURCE) return;
  try { applyPatch(); } catch (e) { err('Auto-patch errore: ' + (e && e.message)); }
});
