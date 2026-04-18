-- mbt_malisling: aggiorna Items[name].anim con le animazioni custom del sling.
-- Triggered come evento locale da core/client.lua di mbt_malisling.
-- Deve girare in questo contesto per accedere alla tabella Items di ox_inventory.
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
                Items[k]['anim']  = { animInfo.dict, animInfo.animIn, animInfo.sleep, animInfo.dict, animInfo.animOut, animInfo.sleepOut }
            end
        end
    end
end)
