#!/usr/bin/env bash
# =============================================================================
#  mbt_malisling — apply the ox_inventory patch by hand (Linux / macOS)
#
#  The resource patches ox_inventory itself at startup. Run this only when that
#  failed — typically because the server process could not write to
#  ox_inventory (read-only mount, restrictive ownership), in which case running
#  this as a user who CAN write fixes it.
#
#  It will not help if ox_inventory was updated and moved the anchors: this
#  script looks for the same two, and stops rather than guess. Patch by hand
#  then (steps in the README) or wait for a malisling update.
#
#  Usage:
#     ./install_ox_patch.sh                       # find ox_inventory automatically
#     ./install_ox_patch.sh /path/to/ox_inventory # or point straight at it
#
#  Safe to re-run: it restores its own backup first, so the patch is never
#  applied twice.
# =============================================================================
set -euo pipefail

RED=$'\033[31m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'; CYAN=$'\033[36m'; GRAY=$'\033[90m'; OFF=$'\033[0m'
err()  { printf '%s[ERROR]%s %s\n' "$RED" "$OFF" "$1" >&2; }
info() { printf '%s%s%s\n' "$CYAN" "$1" "$OFF"; }
warn() { printf '%s%s%s\n' "$YELLOW" "$1" "$OFF"; }
ok()   { printf '%s%s%s\n' "$GREEN" "$1" "$OFF"; }
dim()  { printf '%s%s%s\n' "$GRAY" "$1" "$OFF"; }

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# The scripts live in tools/, the fragments one level up in patches/.
RES_DIR="$(dirname -- "$SCRIPT_DIR")"
HOOK_FILE="$RES_DIR/patches/ox_hook.lua"
APPEND_FILE="$RES_DIR/patches/ox_append.lua"

HOOK_MARKER='mbt_malisling:holster_request'
APPEND_MARKER='mbt_malisling:sendAnim'
INSERT_POINT='sleep = anim and anim[3] or 1200'
RETURN_POINT='return Weapon'

# --- Locate ox_inventory -----------------------------------------------------
OX_PATH="${1:-}"

if [[ -z "$OX_PATH" ]]; then
    info 'Searching for ox_inventory...'
    # Walk up from the resource until a directory named resources appears, then
    # look for ox_inventory under it. Mirrors what the PowerShell version does.
    search_root=''
    d="$RES_DIR"
    for _ in $(seq 1 10); do
        [[ -z "$d" || "$d" == '/' ]] && break
        if [[ "$(basename -- "$d")" == 'resources' ]]; then search_root="$d"; break; fi
        if [[ -d "$d/resources" ]]; then search_root="$d/resources"; break; fi
        parent="$(dirname -- "$d")"
        [[ "$parent" == "$d" ]] && break
        d="$parent"
    done

    if [[ -n "$search_root" ]]; then
        dim "Searching in: $search_root"
        mapfile -t hits < <(find "$search_root" -type f -name fxmanifest.lua -path '*/ox_inventory/*' \
                              -exec dirname -- {} \; 2>/dev/null | sort -u)
        if [[ ${#hits[@]} -eq 1 ]]; then
            OX_PATH="${hits[0]}"
            ok "Found: $OX_PATH"
        elif [[ ${#hits[@]} -gt 1 ]]; then
            warn "Found ${#hits[@]} ox_inventory installs:"
            for i in "${!hits[@]}"; do printf '  [%d] %s\n' "$((i+1))" "${hits[$i]}"; done
            read -r -p 'Choose the number: ' choice
            idx=$((choice-1))
            if [[ "$idx" -ge 0 && "$idx" -lt ${#hits[@]} ]]; then OX_PATH="${hits[$idx]}"
            else err 'Invalid choice.'; exit 1; fi
        fi
    fi

    if [[ -z "$OX_PATH" ]]; then
        warn 'ox_inventory not found automatically.'
        dim 'Example: /home/fivem/server-data/resources/[ox]/ox_inventory'
        read -r -p 'Enter the full path to ox_inventory: ' OX_PATH
    fi
fi

TARGET="$OX_PATH/modules/weapon/client.lua"
BAK="$TARGET.bak"
info "Target: $TARGET"

[[ -f "$TARGET" ]]      || { err "File not found: $TARGET"; exit 1; }
[[ -f "$HOOK_FILE" ]]   || { err "Patch file not found: $HOOK_FILE"; exit 1; }
[[ -f "$APPEND_FILE" ]] || { err "Patch file not found: $APPEND_FILE"; exit 1; }

# Fail on permissions here rather than half-way through the rewrite.
if [[ ! -w "$TARGET" ]]; then
    err "No write permission on $TARGET"
    dim 'That is usually the same reason the automatic patch failed.'
    dim 'Re-run as the user that owns ox_inventory, or with sudo.'
    exit 1
fi

# --- Already patched? Restore the backup and start clean ---------------------
if grep -qF "$HOOK_MARKER" "$TARGET" || grep -qF "$APPEND_MARKER" "$TARGET"; then
    if [[ ! -f "$BAK" ]]; then
        err "Patch already present but no backup found: $BAK"
        warn 'Restore the original ox_inventory file manually, then re-run.'
        exit 1
    fi
    warn 'Patch already present. Restoring backup and reapplying...'
    cp -- "$BAK" "$TARGET"
fi

# --- Anchors -----------------------------------------------------------------
sleep_ln="$(grep -nF -- "$INSERT_POINT" "$TARGET" | head -n1 | cut -d: -f1 || true)"
if [[ -z "$sleep_ln" ]]; then
    err 'Insertion point not found — unsupported or updated ox_inventory version.'
    dim 'Nothing was written. Patch by hand (see the README) or update mbt_malisling.'
    exit 1
fi

ret_ln="$(grep -nF -- "$RETURN_POINT" "$TARGET" | tail -n1 | cut -d: -f1 || true)"
if [[ -z "$ret_ln" ]]; then
    err "'$RETURN_POINT' not found — unsupported or updated ox_inventory version."
    dim 'Nothing was written.'
    exit 1
fi

# --- Build the patched file --------------------------------------------------
# The fragments carry __MBT_PATCH_VERSION__, which becomes the marker the auto-patcher tests
# against: an MD5 of the two fragment files, hashed BEFORE substitution, hook first. It must be
# computed exactly the way modules/ox_patch/installer.js computes it — otherwise this installer
# writes a marker the auto-patcher does not recognise and ox gets re-patched on every start.
if command -v md5sum >/dev/null 2>&1; then
    FRAGMENT_HASH="$(cat -- "$HOOK_FILE" "$APPEND_FILE" | md5sum | cut -c1-8)"
elif command -v md5 >/dev/null 2>&1; then          # BSD/macOS
    FRAGMENT_HASH="$(cat -- "$HOOK_FILE" "$APPEND_FILE" | md5 -q | cut -c1-8)"
elif command -v openssl >/dev/null 2>&1; then
    FRAGMENT_HASH="$(cat -- "$HOOK_FILE" "$APPEND_FILE" | openssl dgst -md5 -r | cut -c1-8)"
else
    err 'No md5sum, md5 or openssl found — cannot compute the patch marker.'
    err 'Install one of them, or let the resource auto-patch ox_inventory on start instead.'
    exit 1
fi
PATCH_VERSION="$(sed -nE "s/^[[:space:]]*version[[:space:]]+'([^']+)'.*/\1/p" "$RES_DIR/fxmanifest.lua" | head -1)"
[[ -n "$PATCH_VERSION" ]] || PATCH_VERSION='dev'
STAMP="$FRAGMENT_HASH\\n-- applied by mbt_malisling $PATCH_VERSION"
HOOK_TMP="$(mktemp)"; APPEND_TMP="$(mktemp)"
sed "s/__MBT_PATCH_VERSION__/$STAMP/g" "$HOOK_FILE"   > "$HOOK_TMP"
sed "s/__MBT_PATCH_VERSION__/$STAMP/g" "$APPEND_FILE" > "$APPEND_TMP"

# Hook goes before the sleep line, sendAnim before the LAST 'return Weapon'.
TMP="$(mktemp)"
trap 'rm -f -- "$TMP" "$HOOK_TMP" "$APPEND_TMP"' EXIT

awk -v hook="$HOOK_TMP" -v append="$APPEND_TMP" -v sl="$sleep_ln" -v rl="$ret_ln" '
    NR == sl { while ((getline line < hook)   > 0) print line; close(hook) }
    NR == rl { while ((getline line < append) > 0) print line; close(append) }
    { print }
' "$TARGET" > "$TMP"

# --- Verify before touching the original -------------------------------------
if ! grep -qF "$HOOK_MARKER" "$TMP" || ! grep -qF "$APPEND_MARKER" "$TMP"; then
    err 'Post-patch verification failed — nothing written.'
    exit 1
fi

cp -- "$TARGET" "$BAK"
warn "Backup: $BAK"
cat -- "$TMP" > "$TARGET"   # preserves the original file's owner and mode

ok '[OK] Patch applied successfully!'
info 'Restart ox_inventory, then mbt_malisling.'
