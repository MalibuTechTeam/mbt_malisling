MBT = MBT or {}

local Locales = {}

--- Translate a key into the active language (MBT.Language), falling back to English.
--- Extra arguments are passed through string.format.
---@param key string
---@param ... any
---@return string
function Translate(key, ...)
    if Locales[MBT.Language] and Locales[MBT.Language][key] then
        if ... then
            return string.format(Locales[MBT.Language][key], ...)
        end
        return Locales[MBT.Language][key]
    end
    -- Fallback to English
    if Locales['en'] and Locales['en'][key] then
        if ... then
            return string.format(Locales['en'][key], ...)
        end
        return Locales['en'][key]
    end
    return key
end

--- Register a locale table for a language. Called by each locales/<lang>.lua file.
---@param lang string
---@param data table<string, string>
function RegisterLocale(lang, data)
    Locales[lang] = data
end

-- Expose the Locale table on MBT for compatibility with other MBT scripts:
-- MBT.Locale['key'] resolves through Translate().
CreateThread(function()
    Wait(0)
    MBT.Locale = setmetatable({}, {
        __index = function(_, key)
            return Translate(key)
        end
    })
end)

-- Keys exposed to the NUI. buildNuiLocale() (core/client.lua) iterates this list
-- and ships the translated strings to the React app inside each show/open message.
NUI_LOCALE_KEYS = {
    'holster_title',
    'jam_title',
    'jam_clear',
    'inspect_title',
    'inspect_serial',
    'inspect_condition',
    'inspect_ammo',
    'safety_on',
    'safety_off',
    'cfg_title',
    'cfg_general',
    'cfg_debug',
    'cfg_drop_death',
    'cfg_enable_sling',
    'cfg_enable_flashlight',
    'cfg_interface',
    'cfg_holster_position',
    'cfg_jamming',
    'cfg_enabled',
    'cfg_cooldown',
    'cfg_unjam_presses',
    'cfg_throw',
    'cfg_throw_key',
    'cfg_cancel',
    'cfg_save',
}

--- Build the flat locale table sent to the NUI.
---@return table<string, string>
function buildNuiLocale()
    local out = {}
    for i = 1, #NUI_LOCALE_KEYS do
        local key = NUI_LOCALE_KEYS[i]
        out[key] = Translate(key)
    end
    return out
end

--- Build and fire a localized notification from an MBT.Labels entry.
--- The label entry holds presentation (type/icon) + locale keys (titleKey/descKey).
---@param key string
function MBT.NotifyLabel(key)
    local label = MBT.Labels and MBT.Labels[key]
    if not label then return end
    MBT.Notification({
        title       = Translate(label.titleKey),
        description = Translate(label.descKey),
        type        = label.type,
        icon        = label.icon,
    })
end
