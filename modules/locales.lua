MBT = MBT or {}

local Locales = {}

--- Translate a key into MBT.Language, falling back to English; extra args go through string.format.
function Translate(key, ...)
    if Locales[MBT.Language] and Locales[MBT.Language][key] then
        if ... then
            return string.format(Locales[MBT.Language][key], ...)
        end
        return Locales[MBT.Language][key]
    end
    if Locales['en'] and Locales['en'][key] then
        if ... then
            return string.format(Locales['en'][key], ...)
        end
        return Locales['en'][key]
    end
    return key
end

--- Register a locale table. Called by each locales/<lang>.lua file.
function RegisterLocale(lang, data)
    Locales[lang] = data
end

-- Expose MBT.Locale['key'] (resolves through Translate) for other MBT scripts.
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
    -- Holster prompt
    'holster_title', 'holster_action', 'holster_confirm', 'holster_cancel',
    -- Jamming
    'jam_title', 'jam_status', 'jam_clear',
    -- Condition pip / carry pose
    'cond_label',
    'pose_title', 'pose_cycle', 'pose_exit',
    -- Inspect overlay (+ chain-of-custody rows)
    'inspect_title', 'inspect_serial', 'inspect_condition', 'inspect_ammo',
    'inspect_custody', 'custody_origin', 'custody_now', 'custody_more',
    -- Safety toggle
    'safety_on', 'safety_off',
    -- Ammo sharing picker
    'ammo_share_title', 'ammo_adjust', 'ammo_give', 'ammo_cancel',
    -- Shell-casing evidence
    'casing_title', 'casing_serial', 'casing_fired', 'casing_ago', 'casing_ago_now',
    -- Weapon handoff
    'handoff_offers', 'handoff_accept', 'handoff_decline',
    -- Pat-down
    'patdown_st_concealed_poor', 'patdown_st_concealed_good', 'patdown_st_carried',
    'patdown_st_visible', 'patdown_wants', 'patdown_allow', 'patdown_refuse', 'patdown_result',
    -- Weapon-rack picker
    'rack_picker_title', 'rack_picker_select', 'rack_picker_take', 'rack_picker_cancel',
}

--- Build the flat locale table sent to the NUI.
function buildNuiLocale()
    local out = {}
    for i = 1, #NUI_LOCALE_KEYS do
        local key = NUI_LOCALE_KEYS[i]
        out[key] = Translate(key)
    end
    return out
end

-- Notification labels. Text is resolved from locales/<lang>.lua via titleKey/descKey;
-- only presentation (type, icon) lives here. Fired through MBT.NotifyLabel(key).
MBT.Labels             = {
    ["trunk_locked"] = {
        ["titleKey"] = "trunk_locked_title",
        ["descKey"]  = "trunk_locked_desc",
        ["type"]     = "error",
        ["icon"]     = "fa-solid fa-lock",
    },
    ["trunk_full"] = {
        ["titleKey"] = "trunk_full_title",
        ["descKey"]  = "trunk_full_desc",
        ["type"]     = "inform",
        ["icon"]     = "fa-solid fa-box-archive",
    },
    ["trunk_no_plate"] = {
        ["titleKey"] = "trunk_no_plate_title",
        ["descKey"]  = "trunk_no_plate_desc",
        ["type"]     = "error",
        ["icon"]     = "fa-solid fa-car",
    },
    ["trunk_wrong_type"] = {
        ["titleKey"] = "trunk_wrong_type_title",
        ["descKey"]  = "trunk_wrong_type_desc",
        ["type"]     = "inform",
        ["icon"]     = "fa-solid fa-gun",
    },
    ["trunk_inv_full"] = {
        ["titleKey"] = "trunk_inv_full_title",
        ["descKey"]  = "trunk_inv_full_desc",
        ["type"]     = "error",
        ["icon"]     = "fa-solid fa-box-archive",
    },
    ["rack_full"] = {
        ["titleKey"] = "rack_full_title",
        ["descKey"]  = "rack_full_desc",
        ["type"]     = "inform",
        ["icon"]     = "fa-solid fa-box-archive",
    },
    ["rack_wrong_type"] = {
        ["titleKey"] = "rack_wrong_type_title",
        ["descKey"]  = "rack_wrong_type_desc",
        ["type"]     = "inform",
        ["icon"]     = "fa-solid fa-gun",
    },
    ["rack_no_access"] = {
        ["titleKey"] = "rack_no_access_title",
        ["descKey"]  = "rack_no_access_desc",
        ["type"]     = "error",
        ["icon"]     = "fa-solid fa-lock",
    },
    ["rack_inv_full"] = {
        ["titleKey"] = "rack_inv_full_title",
        ["descKey"]  = "rack_inv_full_desc",
        ["type"]     = "error",
        ["icon"]     = "fa-solid fa-box-archive",
    },
    ["rack_no_cert"] = {
        ["titleKey"] = "rack_no_cert_title",
        ["descKey"]  = "rack_no_cert_desc",
        ["type"]     = "error",
        ["icon"]     = "fa-solid fa-id-card",
    },
    ["rack_placed"] = {
        ["titleKey"] = "rack_placed_title",
        ["descKey"]  = "rack_placed_desc",
        ["type"]     = "success",
        ["icon"]     = "fa-solid fa-screwdriver-wrench",
    },
    ["rack_picked_up"] = {
        ["titleKey"] = "rack_picked_up_title",
        ["descKey"]  = "rack_picked_up_desc",
        ["type"]     = "success",
        ["icon"]     = "fa-solid fa-screwdriver-wrench",
    },
    ["rack_limit"] = {
        ["titleKey"] = "rack_limit_title",
        ["descKey"]  = "rack_limit_desc",
        ["type"]     = "error",
        ["icon"]     = "fa-solid fa-ban",
    },
    ["rack_too_close"] = {
        ["titleKey"] = "rack_too_close_title",
        ["descKey"]  = "rack_too_close_desc",
        ["type"]     = "error",
        ["icon"]     = "fa-solid fa-ruler",
    },
    ["rack_not_empty"] = {
        ["titleKey"] = "rack_not_empty_title",
        ["descKey"]  = "rack_not_empty_desc",
        ["type"]     = "error",
        ["icon"]     = "fa-solid fa-box-archive",
    },
    ["casing_collected"] = {
        ["titleKey"] = "casing_collected_title",
        ["descKey"]  = "casing_collected_desc",
        ["type"]     = "success",
        ["icon"]     = "fa-solid fa-magnifying-glass",
    },
    ["handoff_sent"] = {
        ["titleKey"] = "handoff_sent_title",
        ["descKey"]  = "handoff_sent_desc",
        ["type"]     = "inform",
        ["icon"]     = "fa-solid fa-hand-holding",
    },
    ["handoff_done"] = {
        ["titleKey"] = "handoff_done_title",
        ["descKey"]  = "handoff_done_desc",
        ["type"]     = "success",
        ["icon"]     = "fa-solid fa-hand-holding",
    },
    ["handoff_declined"] = {
        ["titleKey"] = "handoff_declined_title",
        ["descKey"]  = "handoff_declined_desc",
        ["type"]     = "inform",
        ["icon"]     = "fa-solid fa-hand",
    },
    ["handoff_no_target"] = {
        ["titleKey"] = "handoff_no_target_title",
        ["descKey"]  = "handoff_no_target_desc",
        ["type"]     = "inform",
        ["icon"]     = "fa-solid fa-person-circle-question",
    },
    ["handoff_inv_full"] = {
        ["titleKey"] = "handoff_inv_full_title",
        ["descKey"]  = "handoff_inv_full_desc",
        ["type"]     = "error",
        ["icon"]     = "fa-solid fa-box-archive",
    },
    ["handoff_failed"] = {
        ["titleKey"] = "handoff_failed_title",
        ["descKey"]  = "handoff_failed_desc",
        ["type"]     = "error",
        ["icon"]     = "fa-solid fa-hand",
    },
    ["concealed_on"] = {
        ["titleKey"] = "concealed_on_title",
        ["descKey"]  = "concealed_on_desc",
        ["type"]     = "success",
        ["icon"]     = "fa-solid fa-user-secret",
    },
    ["concealed_off"] = {
        ["titleKey"] = "concealed_off_title",
        ["descKey"]  = "concealed_off_desc",
        ["type"]     = "inform",
        ["icon"]     = "fa-solid fa-eye",
    },
    ["concealed_bare"] = {
        ["titleKey"] = "concealed_bare_title",
        ["descKey"]  = "concealed_bare_desc",
        ["type"]     = "error",
        ["icon"]     = "fa-solid fa-shirt",
    },
    ["concealed_revealed"] = {
        ["titleKey"] = "concealed_revealed_title",
        ["descKey"]  = "concealed_revealed_desc",
        ["type"]     = "inform",
        ["icon"]     = "fa-solid fa-eye",
    },
    ["concealed_no_weapon"] = {
        ["titleKey"] = "concealed_no_weapon_title",
        ["descKey"]  = "concealed_no_weapon_desc",
        ["type"]     = "inform",
        ["icon"]     = "fa-solid fa-gun",
    },
    ["patdown_sent"] = {
        ["titleKey"] = "patdown_sent_title",
        ["descKey"]  = "patdown_sent_desc",
        ["type"]     = "inform",
        ["icon"]     = "fa-solid fa-hands",
    },
    ["patdown_declined"] = {
        ["titleKey"] = "patdown_declined_title",
        ["descKey"]  = "patdown_declined_desc",
        ["type"]     = "inform",
        ["icon"]     = "fa-solid fa-hand",
    },
    ["patdown_none"] = {
        ["titleKey"] = "patdown_none_title",
        ["descKey"]  = "patdown_none_desc",
        ["type"]     = "success",
        ["icon"]     = "fa-solid fa-hands",
    },
    ["patdown_no_target"] = {
        ["titleKey"] = "patdown_no_target_title",
        ["descKey"]  = "patdown_no_target_desc",
        ["type"]     = "inform",
        ["icon"]     = "fa-solid fa-person-circle-question",
    },
    ["patdown_searched"] = {
        ["titleKey"] = "patdown_searched_title",
        ["descKey"]  = "patdown_searched_desc",
        ["type"]     = "inform",
        ["icon"]     = "fa-solid fa-hands",
    },
    ["ammo_sent"] = {
        ["titleKey"] = "ammo_sent_title",
        ["descKey"]  = "ammo_sent_desc",
        ["type"]     = "inform",
        ["icon"]     = "fa-solid fa-boxes-stacked",
    },
    ["ammo_done"] = {
        ["titleKey"] = "ammo_done_title",
        ["descKey"]  = "ammo_done_desc",
        ["type"]     = "success",
        ["icon"]     = "fa-solid fa-boxes-stacked",
    },
    ["ammo_declined"] = {
        ["titleKey"] = "ammo_declined_title",
        ["descKey"]  = "ammo_declined_desc",
        ["type"]     = "inform",
        ["icon"]     = "fa-solid fa-hand",
    },
    ["ammo_none"] = {
        ["titleKey"] = "ammo_none_title",
        ["descKey"]  = "ammo_none_desc",
        ["type"]     = "inform",
        ["icon"]     = "fa-solid fa-boxes-stacked",
    },
    ["ammo_no_target"] = {
        ["titleKey"] = "ammo_no_target_title",
        ["descKey"]  = "ammo_no_target_desc",
        ["type"]     = "inform",
        ["icon"]     = "fa-solid fa-person-circle-question",
    },
    ["ammo_full"] = {
        ["titleKey"] = "ammo_full_title",
        ["descKey"]  = "ammo_full_desc",
        ["type"]     = "error",
        ["icon"]     = "fa-solid fa-box-archive",
    },
    ["has_jammed"] = {
        ["titleKey"] = "jam_jammed_title",
        ["descKey"]  = "jam_jammed_desc",
        ["type"]     = "error",
        ["icon"]     = "fa-solid fa-triangle-exclamation",
    },
    ["has_unjammed"] = {
        ["titleKey"] = "jam_unjammed_title",
        ["descKey"]  = "jam_unjammed_desc",
        ["type"]     = "success",
        ["icon"]     = "fa-solid fa-person-rifle",
    },
    ["no_allowed_throw"] = {
        ["titleKey"] = "throw_not_allowed_title",
        ["descKey"]  = "throw_not_allowed_desc",
        ["type"]     = "error",
        ["icon"]     = "fa-solid fa-hand-fist",
    },
    ["no_draw_zone"] = {
        ["titleKey"] = "no_draw_zone_title",
        ["descKey"]  = "no_draw_zone_desc",
        ["type"]     = "error",
        ["icon"]     = "fa-solid fa-ban",
    },
    ["low_ready_none"] = {
        ["titleKey"] = "low_ready_none_title",
        ["descKey"]  = "low_ready_none_desc",
        ["type"]     = "inform",
        ["icon"]     = "fa-solid fa-person-rifle",
    },
    ["safety_no_weapon"] = {
        ["titleKey"] = "safety_no_weapon_title",
        ["descKey"]  = "safety_no_weapon_desc",
        ["type"]     = "inform",
        ["icon"]     = "fa-solid fa-shield-halved",
    },
    ["wname_no_weapon"] = {
        ["titleKey"] = "wname_no_weapon_title",
        ["descKey"]  = "wname_no_weapon_desc",
        ["type"]     = "inform",
        ["icon"]     = "fa-solid fa-pen",
    },
    ["wname_no_perm"] = {
        ["titleKey"] = "wname_no_perm_title",
        ["descKey"]  = "wname_no_perm_desc",
        ["type"]     = "error",
        ["icon"]     = "fa-solid fa-lock",
    },
    ["wname_done"] = {
        ["titleKey"] = "wname_done_title",
        ["descKey"]  = "wname_done_desc",
        ["type"]     = "success",
        ["icon"]     = "fa-solid fa-pen",
    },
    ["wname_locked"] = {
        ["titleKey"] = "wname_locked_title",
        ["descKey"]  = "wname_locked_desc",
        ["type"]     = "error",
        ["icon"]     = "fa-solid fa-lock",
    },
    ["charge_no_weapon"] = {
        ["titleKey"] = "charge_no_weapon_title",
        ["descKey"]  = "charge_no_weapon_desc",
        ["type"]     = "inform",
        ["icon"]     = "fa-solid fa-gun",
    },
    ["pose_in_vehicle"] = {
        ["titleKey"] = "pose_in_vehicle_title",
        ["descKey"]  = "pose_in_vehicle_desc",
        ["type"]     = "inform",
        ["icon"]     = "fa-solid fa-camera",
    },
    ["admin_no_perm"] = {
        ["titleKey"] = "admin_no_perm_title",
        ["descKey"]  = "admin_no_perm_desc",
        ["type"]     = "error",
        ["icon"]     = "fa-solid fa-lock",
    },
}

--- Fire a localized notification from an MBT.Labels entry (presentation + locale keys).
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
