-- ─────────────────────────────────────────────────────────────────────────────
-- Sling prop position editor (command-based).
--
-- /mbt_propedit [WEAPON_NAME]  — spawns the weapon prop on the player's back
-- bone and lets you nudge its position/rotation live with the arrow keys, then
-- dumps a config-ready Pos/Rot snippet to the F8 console.
--
-- Interim tool for the planned NUI /sling_edit feature. Run the command again
-- to close the editor.
-- ─────────────────────────────────────────────────────────────────────────────

local FIELDS  = { 'posX', 'posY', 'posZ', 'rotX', 'rotY', 'rotZ' }
local editing = false

local function drawText(x, y, scale, text, r, g, b)
    SetTextFont(4)
    SetTextScale(scale, scale)
    SetTextColour(r, g, b, 255)
    SetTextOutline()
    SetTextEntry("STRING")
    AddTextComponentSubstringPlayerName(text)
    DrawText(x, y)
end

local function startEditor(weaponName)
    local weaponHash = joaat(weaponName)
    lib.requestWeaponAsset(weaponHash, 1000, 31, 1)

    local ped    = cache.ped
    local coords = GetEntityCoords(ped)
    local prop   = CreateWeaponObject(weaponHash, 50, coords.x, coords.y, coords.z, true, 1.0, 0)
    if not prop or not DoesEntityExist(prop) then
        print("^8[mbt_propedit] failed to create weapon object for " .. weaponName .. "^7")
        return
    end

    editing = true
    local boneIndex = GetPedBoneIndex(ped, MBT.Bones["Back"])
    local v   = { posX = 0.0, posY = -0.18, posZ = 0.1, rotX = 0.0, rotY = 0.0, rotZ = 0.0 }
    local sel = 1

    local function reattach()
        AttachEntityToEntity(prop, ped, boneIndex,
            v.posX, v.posY, v.posZ, v.rotX, v.rotY, v.rotZ,
            true, true, false, false, 2, true)
    end
    reattach()

    print("^2[mbt_propedit] editor open for " .. weaponName .. " — Enter dumps, Backspace exits^7")

    CreateThread(function()
        while editing do
            -- Keys used by the editor (block their default actions).
            DisableControlAction(0, 172, true) -- Arrow Up
            DisableControlAction(0, 173, true) -- Arrow Down
            DisableControlAction(0, 174, true) -- Arrow Left
            DisableControlAction(0, 175, true) -- Arrow Right
            DisableControlAction(0, 191, true) -- Enter
            DisableControlAction(0, 177, true) -- Backspace

            -- Cycle selected field.
            if IsDisabledControlJustPressed(0, 172) then
                sel = sel - 1; if sel < 1 then sel = #FIELDS end
            elseif IsDisabledControlJustPressed(0, 173) then
                sel = sel + 1; if sel > #FIELDS then sel = 1 end
            end

            -- Adjust selected field (continuous while held).
            local field = FIELDS[sel]
            local isRot = field:sub(1, 3) == 'rot'
            local step  = isRot and 1.0 or 0.004
            if IsDisabledControlPressed(0, 174) then
                v[field] = v[field] - step
                reattach()
            elseif IsDisabledControlPressed(0, 175) then
                v[field] = v[field] + step
                reattach()
            end

            -- Dump a config-ready snippet to F8.
            if IsDisabledControlJustPressed(0, 191) then
                print(("^2[mbt_propedit] %s ─────────────────────────────^7"):format(weaponName))
                print(('["Pos"] = { ["male"] = { ["x"] = %.3f, ["y"] = %.3f, ["z"] = %.3f }, ["female"] = { ["x"] = %.3f, ["y"] = %.3f, ["z"] = %.3f } },')
                    :format(v.posX, v.posY, v.posZ, v.posX, v.posY, v.posZ))
                print(('["Rot"] = { ["male"] = { ["x"] = %.1f, ["y"] = %.1f, ["z"] = %.1f }, ["female"] = { ["x"] = %.1f, ["y"] = %.1f, ["z"] = %.1f } },')
                    :format(v.rotX, v.rotY, v.rotZ, v.rotX, v.rotY, v.rotZ))
            end

            -- Exit.
            if IsDisabledControlJustPressed(0, 177) then
                editing = false
            end

            -- HUD.
            drawText(0.35, 0.32, 0.5, "MBT Prop Editor — " .. weaponName, 255, 220, 0)
            for i = 1, #FIELDS do
                local f        = FIELDS[i]
                local selected = (i == sel)
                local line     = ("%s %s : %.3f"):format(selected and ">" or "  ", f, v[f])
                if selected then
                    drawText(0.35, 0.345 + i * 0.026, 0.42, line, 255, 220, 0)
                else
                    drawText(0.35, 0.345 + i * 0.026, 0.42, line, 230, 230, 230)
                end
            end
            drawText(0.35, 0.53, 0.34,
                "Up/Down: select   Left/Right: adjust   Enter: dump to F8   Backspace: exit",
                190, 190, 190)

            Wait(0)
        end

        if DoesEntityExist(prop) then DeleteEntity(prop) end
        print("^2[mbt_propedit] editor closed^7")
    end)
end

RegisterCommand('mbt_propedit', function(_, args)
    if editing then
        editing = false
        return
    end
    local weaponName = (args[1] or 'WEAPON_FIREEXTINGUISHER'):upper()
    if weaponName:sub(1, 7) ~= 'WEAPON_' then
        weaponName = 'WEAPON_' .. weaponName
    end
    startEditor(weaponName)
end, false)
