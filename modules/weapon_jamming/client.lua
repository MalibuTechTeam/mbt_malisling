-- Load if the feature block exists; Enabled is checked where a jam can START
-- (the gunshot handler) so the admin menu can toggle it live.
if not MBT.Jamming then return end

local jammed = GetGameTimer()
local currentWeapon

local jamAnim = MBT.Jamming["Animation"]
local isJammed = false
local jammedSlots = {}
LocalPlayer.state:set('JammedState', false, false)

AddEventHandler('ox_inventory:currentWeapon', function(data)
    currentWeapon = data
    if data then
        Utils.mbtDebugger("currentWeapon ~ slot:", data.slot, "jammed:", data.metadata and data.metadata.jammed, "sessionJam:", jammedSlots[data.slot])
        local slotJammed = jammedSlots[data.slot] or (data.metadata and data.metadata.jammed)
        if slotJammed and not isJammed then
            LocalPlayer.state:set('JammedState', true, false)
        end
    end
end)

local function unjamMinigame()
    local unjamCfg   = MBT.Jamming["Unjam"]
    local control    = unjamCfg["Control"]
    local total      = unjamCfg["Presses"]
    local presses    = 0
    local jammedSlot = currentWeapon and currentWeapon.slot or nil

    SendNUIMessage({
        action = 'showJam',
        data   = {
            weaponLabel = currentWeapon and currentWeapon.name or 'WEAPON',
            presses     = 0,
            total       = total,
            key         = unjamCfg["Display"],
            locale      = buildNuiLocale(),
        }
    })

    while presses < total do
        if not currentWeapon then
            -- Weapon removed from inventory — cancel jam silently
            SendNUIMessage({ action = 'hideJam', data = {} })
            LocalPlayer.state:set('JammedState', false, false)
            return
        end
        if IsControlJustPressed(0, control) then
            presses = presses + 1
            SendNUIMessage({ action = 'updateJam', data = { presses = presses } })
        end
        Wait(10)
    end

    SendNUIMessage({ action = 'hideJam', data = {} })
    LocalPlayer.state:set('JammedState', false, false)
    MBT.NotifyLabel("has_unjammed")

    if jammedSlot then
        jammedSlots[jammedSlot] = nil
        TriggerServerEvent("mbt_malisling:setWeaponJammed", jammedSlot, false)
    end
end

local function disableFiring()
    while isJammed do
        DisablePlayerFiring(cache.playerId, true)
        DisableControlAction(0, 25, true)
        Wait(5)
    end
end

local function jammedAnim()
    lib.requestAnimDict(jamAnim["Dict"])
    while isJammed do
        TaskPlayAnim(cache.ped, jamAnim["Dict"], jamAnim["Anim"], 2.0, 2.0, 750, 48, 0.0, false, false, false)
        Wait(800)   -- the fire-block is enforced every frame by disableFiring(); no need to repeat it here
    end
    ClearPedTasks(cache.ped)
    RemoveAnimDict(jamAnim["Dict"])
end

AddStateBagChangeHandler('JammedState', nil, function(bagName, key, value)
    if type(value) ~= "boolean" then return end
    isJammed = value
    Utils.mbtDebugger("isJammed has been set to ", isJammed)
    if isJammed then MBT.NotifyLabel("has_jammed") end

    if isJammed then
        Citizen.CreateThread(function()
            disableFiring()
        end)
        Citizen.CreateThread(function()
            jammedAnim()
        end)
        Citizen.CreateThread(function()
            unjamMinigame()
        end)
    end
end)

if MBT.Debug then
    RegisterCommand('testjam', function()
        if currentWeapon and currentWeapon.slot then
            jammedSlots[currentWeapon.slot] = true
            TriggerServerEvent("mbt_malisling:setWeaponJammed", currentWeapon.slot, true)
        end
        LocalPlayer.state:set('JammedState', true, false)
    end, false)
end

AddEventHandler("CEventGunShotWhizzedBy", function(entities, eventEntity, args)
    if not MBT.Jamming["Enabled"] then return end
    if currentWeapon and not isJammed then
        Utils.mbtDebugger("currentWeapon.metadata.durability ", currentWeapon.metadata.durability)
        if (GetGameTimer() - jammed) <= (MBT.Jamming["Cooldown"] * 1000) then return end

        -- The companion combat resource (if registered) may OVERRIDE the jam
        -- decision (advanced malfunctions live there, escrowed); when it has no
        -- opinion (nil) we fall back to malisling's base durability-chance roll.
        local override = MBT.ShootingBridge and MBT.ShootingBridge.OnJamCheck(
            GetSelectedPedWeapon(cache.ped),
            Utils.durabilityToTier(currentWeapon.metadata.durability))

        local shouldJam
        local source
        if override ~= nil then
            shouldJam = override and true or false
            source    = 'bridge override'
        else
            shouldJam = Utils.getJammingChance(currentWeapon.metadata.durability)
            source    = 'base durability chance'
        end
        Utils.mbtDebugger("WeaponJamming ~ shouldJam:", shouldJam, "| source:", source)

        if shouldJam then
            jammed = GetGameTimer()
            if currentWeapon.slot then
                jammedSlots[currentWeapon.slot] = true
                TriggerServerEvent("mbt_malisling:setWeaponJammed", currentWeapon.slot, true)
            end
            LocalPlayer.state:set('JammedState', true, false)
        end
    end
end)
