if not MBT.Throw["Enabled"] then return end

local utils = require 'utils'

local currentWeapon
local throwAnim = MBT.Throw["Animation"]
local isThrowing = false

AddEventHandler('ox_inventory:currentWeapon', function(data)
    if data then
        currentWeapon = data
        currentWeapon.ObjHash = GetWeapontypeModel(currentWeapon.hash)
    end
end)

local function isAllowedToThrow(weaponGroup)
    utils.mbtDebugger("Is allowed to throw? ", MBT.Throw["Groups"][weaponGroup]["Allowed"])
    return MBT.Throw["Groups"][weaponGroup]["Allowed"]
end

local function throwWeapon(data)
    if isThrowing then return true end
    isThrowing = true
    LocalPlayer.state:set('invBusy', true, false)
    lib.requestAnimDict(throwAnim["Dict"])
    local model = GetWeapontypeModel(data.Hash)
    lib.requestModel(model)
    local bone = 6286
    local forwardCoords = GetWorldPositionOfEntityBone(cache.ped, bone)
    TriggerEvent("ox_inventory:disarm", true)
    equippedWeapon.dropped = true
    TaskPlayAnim(cache.ped, throwAnim["Dict"], throwAnim["Anim"], 8.0, -8.0, -1, 0, 0.0, false, false, false)
    local weaponObj = CreateObject(model, forwardCoords.x, forwardCoords.y, forwardCoords.z, true, true, true)
    local boneIndex = GetPedBoneIndex(cache.ped, bone)
    AttachEntityToEntity(weaponObj, cache.ped, boneIndex, 0, 0, 0, 0, 0, 0, false, false, true, false, 0, false)
    Citizen.Wait(500)
    DetachEntity(weaponObj, true, true)
    local forwardVector = GetEntityForwardVector(cache.ped)
    local multipliers = MBT.Throw["Groups"][data.Group]["Multipliers"] or { ["X"] = 20.0, ["Y"] = 20.0, ["Z"] = 10.0 }
    ApplyForceToEntity(weaponObj, 1, forwardVector.x * multipliers["X"], forwardVector.y * multipliers["Y"], forwardVector.z + multipliers["Z"], 0, 0, 0, 0, false, true, true, false, true)
    Wait(250)
    while IsEntityInAir(weaponObj) do Wait(250); end
    Wait(700)
    local objCoords = GetEntityCoords(weaponObj)
    Wait(100)
    DeleteObject(weaponObj)
    TriggerServerEvent("mbt_malisling:createWeaponDrop", {
        WeaponInfo = currentWeapon,
        Coords = objCoords
    })

    LocalPlayer.state:set('invBusy', false, false)
    isThrowing = false
end

local function attemptThrowWeapon()
    if cache.vehicle then return end
    local hasWeapon, weaponHash = GetCurrentPedWeapon(cache.ped)
    local weaponGroup = GetWeapontypeGroup(weaponHash)
    if not hasWeapon then return end
    if not isAllowedToThrow(weaponGroup) then MBT.Notification(MBT.Labels["no_allowed_throw"]); return; end
    throwWeapon({Hash = weaponHash, Group = weaponGroup})
end

RegisterCommand(MBT.Throw["Command"], attemptThrowWeapon)
RegisterKeyMapping(MBT.Throw["Command"], "[MBT] Throw your current weapon", "keyboard", MBT.Throw["Key"])