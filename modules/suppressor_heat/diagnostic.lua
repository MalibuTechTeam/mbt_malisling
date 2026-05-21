-- ─────────────────────────────────────────────────────────────────────────────
-- mbt_malisling :: suppressor_heat / diagnostic
-- Temporary dev tool for the Suppressor Heat Glow feature.
--
-- Usage in-game:
--   1. Give yourself a weapon that accepts a suppressor (pistol or rifle/SMG)
--   2. Attach the suppressor component via your inventory
--   3. Holster the weapon (so it spawns as a slung prop on your body)
--   4. Run:  /mbt_supp_bones
--   5. Read the console output and screenshot
--
-- Repeat for each weapon model that supports a suppressor. The goal is to
-- find a bone name that is present (with a sane "muzzle-ish" local offset)
-- on every relevant weapon model.
--
-- DELETE THIS FILE AND ITS fxmanifest ENTRY ONCE CALIBRATION IS DONE.
-- ─────────────────────────────────────────────────────────────────────────────

local CANDIDATE_BONES = {
    "gun_muzzle",
    "gun_barrel",
    "muzzle",
    "bone_muzzle",
    "weapon_muzzle",
    "barrel",
    "gunbarrel",
    "muzzle_1",
    "muzzle_2",
    "comp",
}

local function inspectProp(weaponType, prop)
    if not DoesEntityExist(prop) then
        print(("^8[mbt_supp_bones]^7 %s -> prop %s does not exist"):format(weaponType, tostring(prop)))
        return
    end

    local modelHash = GetEntityModel(prop)
    print(("^3[mbt_supp_bones]^7 ^2%s^7  prop=%d  modelHash=%d"):format(weaponType, prop, modelHash))

    local found = 0
    for i = 1, #CANDIDATE_BONES do
        local name = CANDIDATE_BONES[i]
        local idx = GetEntityBoneIndexByName(prop, name)
        if idx ~= -1 then
            local worldPos = GetWorldPositionOfEntityBone(prop, idx)
            local localOff = GetOffsetFromEntityGivenWorldCoords(prop, worldPos.x, worldPos.y, worldPos.z)
            print(("  - %-16s idx=%-3d  local-offset: %+0.3f %+0.3f %+0.3f"):format(name, idx, localOff.x, localOff.y, localOff.z))
            found = found + 1
        end
    end

    if found == 0 then
        print("  ^8(no candidate bones found)^7")
    end
end

RegisterCommand("mbt_supp_bones", function()
    local list = playersToTrack and playersToTrack[cache.serverId]
    if not list then
        print("^8[mbt_supp_bones]^7 no playersToTrack entry for self yet — wait until weapons sync")
        return
    end

    print("^3=== [mbt_supp_bones] dump ===^7")
    local any = false
    for weaponType, prop in pairs(list) do
        if type(prop) == "number" and prop ~= 0 then
            inspectProp(weaponType, prop)
            any = true
        end
    end
    if not any then
        print("^8[mbt_supp_bones]^7 no slung weapons currently spawned. Equip a weapon and holster it, then re-run.")
    end
    print("^3=== end ===^7")
end, false)
