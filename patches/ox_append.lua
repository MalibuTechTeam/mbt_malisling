-- mbt_malisling: updates Items[name].anim with the sling's custom animations.
-- Fired as a local event from mbt_malisling's core/client.lua.
-- Must run in this context to reach ox_inventory's Items table.
AddEventHandler('mbt_malisling:sendAnim', function(data)
    if not data or not data.WeaponData or not data.HolsterData then return end
    local wInfo = data.WeaponData['Weapons']
    local Items = require 'modules.items.shared'
    for k in pairs(wInfo) do
        local itemType = wInfo[k]['type']
        if itemType and data.HolsterData[itemType] and data.HolsterData[itemType]['HolsterAnim'] then
            local animInfo = data.HolsterData[itemType]['HolsterAnim']
            if Items[k] then
                Items[k]['type']  = itemType
                -- ox's format is { dictIn, clipIn, msIn, dictOut, clipOut, msOut }: two dicts,
                -- and we were passing the same one twice. `dictOut` lets a style draw from one
                -- clip and put away with another — which is how a police draw reads different
                -- going out and the same going back.
                Items[k]['anim']  = { animInfo.dict, animInfo.animIn, animInfo.sleep,
                                      animInfo.dictOut or animInfo.dict, animInfo.animOut, animInfo.sleepOut }
            end
        end
    end
end)
