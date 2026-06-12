RegisterLocale('en', {
    -- Notifications: jamming
    ['jam_jammed_title']        = 'Jammed!',
    ['jam_jammed_desc']         = 'Your weapon has jammed! Check its state!',
    ['jam_unjammed_title']      = 'Unjammed!',
    ['jam_unjammed_desc']       = 'You have unjammed your weapon!',

    -- Notifications: throw
    ['throw_not_allowed_title'] = 'Ops!',
    ['throw_not_allowed_desc']  = 'You are not able to throw this weapon!',

    -- No-draw zones
    ['no_draw_zone_title']      = 'No Weapons',
    ['no_draw_zone_desc']       = 'You cannot draw a weapon here.',
    ['no_draw_zone_hud']        = 'No weapons allowed',

    -- Low ready
    ['low_ready_none_title']    = 'Low Ready',
    ['low_ready_none_desc']     = 'No slung long gun to bring to low ready.',

    -- Weapon safety
    ['safety_no_weapon_title']  = 'Safety',
    ['safety_no_weapon_desc']   = 'No firearm in hand.',
    ['safety_on']               = 'SAFE',
    ['safety_off']              = 'FIRE',

    -- Charge weapon
    ['charge_no_weapon_title']  = 'Charge Weapon',
    ['charge_no_weapon_desc']   = 'No firearm in hand.',

    -- Showcase poses
    ['pose_in_vehicle_title']   = 'Pose',
    ['pose_in_vehicle_desc']    = 'You cannot pose inside a vehicle.',

    -- Admin
    ['admin_no_perm_title']     = 'Admin',
    ['admin_no_perm_desc']      = 'You do not have permission to open the config panel.',

    -- Custom weapon name
    ['wname_dialog_title']      = 'Name Weapon',
    ['wname_dialog_field']      = 'Weapon name',
    ['wname_no_weapon_title']   = 'Name Weapon',
    ['wname_no_weapon_desc']    = 'No firearm in hand.',
    ['wname_no_perm_title']     = 'Name Weapon',
    ['wname_no_perm_desc']      = "You can't engrave a name on a weapon.",
    ['wname_done_title']        = 'Weapon Named',
    ['wname_done_desc']         = 'The name has been engraved.',
    ['wname_locked_title']      = 'Name Weapon',
    ['wname_locked_desc']       = 'This weapon already has a name.',

    -- Interaction prompts
    ['pickup_weapon']           = 'Pick up weapon',

    -- Vehicle trunk weapon rack
    ['trunk_stow']              = 'Stow weapon in trunk',
    ['trunk_retrieve']          = 'Take weapon from trunk',
    ['trunk_view']              = 'Open / close trunk',
    ['trunk_locked_title']      = 'Trunk Locked',
    ['trunk_locked_desc']       = 'The vehicle is locked.',
    ['trunk_full_title']        = 'Trunk Rack Full',
    ['trunk_full_desc']         = 'No more room in this trunk.',
    ['trunk_no_plate_title']    = 'Trunk',
    ['trunk_no_plate_desc']     = 'This vehicle has no usable plate.',
    ['trunk_wrong_type_title']  = 'Trunk',
    ['trunk_wrong_type_desc']   = 'Only long guns can go in the trunk.',
    ['trunk_inv_full_title']    = 'Trunk',
    ['trunk_inv_full_desc']     = 'Not enough inventory space.',

    -- Weapon rack / gun locker
    ['rack_stow']               = 'Place weapon on rack',
    ['rack_retrieve']           = 'Take weapon from rack',
    ['rack_full_title']         = 'Rack Full',
    ['rack_full_desc']          = 'No more room on this rack.',
    ['rack_wrong_type_title']   = 'Weapon Rack',
    ['rack_wrong_type_desc']    = 'This weapon can\'t go on the rack.',
    ['rack_no_access_title']    = 'Weapon Rack',
    ['rack_no_access_desc']     = 'You don\'t have access to this rack.',
    ['rack_inv_full_title']     = 'Weapon Rack',
    ['rack_inv_full_desc']      = 'Not enough inventory space.',
    ['rack_no_cert_title']      = 'Weapon Rack',
    ['rack_no_cert_desc']       = 'You aren\'t certified for this weapon.',
    ['rack_picker_title']       = 'WEAPON RACK',
    ['rack_picker_select']      = 'Select',
    ['rack_picker_take']        = 'Take',
    ['rack_picker_cancel']      = 'Cancel',
    ['rack_pickup']             = 'Pick up rack',
    ['rack_hint_rotate']        = 'Rotate',
    ['rack_hint_fast']          = 'Fast',
    ['rack_hint_place']         = 'Place',
    ['rack_hint_cancel']        = 'Cancel',
    ['rack_place_hint']         = 'LEFT/RIGHT rotate ~y~·~s~ SHIFT fast ~y~·~s~ E place ~y~·~s~ BACKSPACE cancel',
    ['rack_placed_title']       = 'Gun Rack',
    ['rack_placed_desc']        = 'Rack installed.',
    ['rack_picked_up_title']    = 'Gun Rack',
    ['rack_picked_up_desc']     = 'Rack dismounted — item returned.',
    ['rack_limit_title']        = 'Gun Rack',
    ['rack_limit_desc']         = 'You\'ve reached your rack limit.',
    ['rack_too_close_title']    = 'Gun Rack',
    ['rack_too_close_desc']     = 'Too close to another rack.',
    ['rack_not_empty_title']    = 'Gun Rack',
    ['rack_not_empty_desc']     = 'Empty the rack before picking it up.',

    -- Forensic shell casings
    ['casing_examine']          = 'Examine casing',
    ['casing_collect']          = 'Collect casing',
    ['casing_title']            = 'SHELL CASING',
    ['casing_serial']           = 'Serial',
    ['casing_fired']            = 'Fired',
    ['casing_ago']              = '%d min ago',
    ['casing_ago_now']          = 'moments ago',
    ['casing_collected_title']  = 'Evidence',
    ['casing_collected_desc']   = 'Casing collected.',

    -- Physical weapon handoff
    ['handoff_offers']          = 'offers you',
    ['handoff_accept']          = 'Accept',
    ['handoff_decline']         = 'Decline',
    ['handoff_sent_title']      = 'Handoff',
    ['handoff_sent_desc']       = 'Weapon offered — waiting for an answer.',
    ['handoff_done_title']      = 'Handoff',
    ['handoff_done_desc']       = 'Weapon handed over.',
    ['handoff_declined_title']  = 'Handoff',
    ['handoff_declined_desc']   = 'The offer was declined.',
    ['handoff_no_target_title'] = 'Handoff',
    ['handoff_no_target_desc']  = 'No one close enough to hand the weapon to.',
    ['handoff_inv_full_title']  = 'Handoff',
    ['handoff_inv_full_desc']   = 'The receiver has no inventory space.',
    ['handoff_failed_title']    = 'Handoff',
    ['handoff_failed_desc']     = 'The handoff failed.',

    -- Concealed carry
    ['concealed_on_title']      = 'Concealed Carry',
    ['concealed_on_desc']       = 'Weapon concealed.',
    ['concealed_off_title']     = 'Concealed Carry',
    ['concealed_off_desc']      = 'Weapon carried openly.',
    ['concealed_bare_title']    = 'Concealed Carry',
    ['concealed_bare_desc']     = 'Nothing to hide it under — cover up first.',
    ['concealed_revealed_title']= 'Concealed Carry',
    ['concealed_revealed_desc'] = 'Your weapon is visible again.',
    ['concealed_no_weapon_title']= 'Concealed Carry',
    ['concealed_no_weapon_desc'] = 'No concealable weapon holstered.',

    -- Pat-down (LEO frisk)
    ['patdown_wants']           = 'wants to search you',
    ['patdown_allow']           = 'Allow',
    ['patdown_refuse']          = 'Refuse',
    ['patdown_result']          = 'PAT-DOWN',
    ['patdown_st_visible']      = 'In the open',
    ['patdown_st_carried']      = 'On the back',
    ['patdown_st_concealed_good']= 'Concealed',
    ['patdown_st_concealed_poor']= 'Concealed (poorly)',
    ['patdown_sent_title']      = 'Pat-down',
    ['patdown_sent_desc']       = 'Awaiting consent…',
    ['patdown_declined_title']  = 'Pat-down',
    ['patdown_declined_desc']   = 'They refused the search.',
    ['patdown_none_title']      = 'Pat-down',
    ['patdown_none_desc']       = 'No weapons found.',
    ['patdown_no_target_title'] = 'Pat-down',
    ['patdown_no_target_desc']  = 'No one close enough to search.',
    ['patdown_searched_title']  = 'Pat-down',
    ['patdown_searched_desc']   = 'You were searched by an officer.',

    -- NUI: holster prompt
    ['holster_title']           = 'HOLSTER WEAPON',
    ['holster_action']          = 'Holster',
    ['holster_confirm']         = 'Confirm',
    ['holster_cancel']          = 'Cancel',

    -- NUI: jam minigame
    ['jam_title']               = 'WEAPON JAMMED',
    ['jam_status']              = 'JAMMED',
    ['jam_clear']               = 'Clear Jam',

    -- NUI: weapon condition HUD
    ['cond_label']              = 'COND',

    -- NUI: showcase pose mode
    ['pose_title']              = 'SHOWCASE',
    ['pose_cycle']              = 'Cycle',
    ['pose_exit']               = 'Exit',

    -- NUI: weapon inspect
    ['inspect_title']           = 'INSPECTING',
    ['inspect_serial']          = 'Serial',
    ['inspect_condition']       = 'Condition',
    ['inspect_ammo']            = 'Ammo',
    -- Chain of Custody (Forensics)
    ['inspect_custody']         = 'Chain of Custody',
    ['custody_origin']          = 'origin',
    ['custody_now']             = 'current',
    -- Condition tiers (durability)
    ['cond_pristine']           = 'Pristine',
    ['cond_good']               = 'Good',
    ['cond_worn']               = 'Worn',
    ['cond_poor']               = 'Poor',
    ['cond_damaged']            = 'Damaged',
    -- Vague ammo (AmmoMode = 'vague')
    ['ammo_full']               = 'Full',
    ['ammo_half']               = 'Half',
    ['ammo_low']                = 'Low',
    ['ammo_empty']              = 'Empty',
    ['ammo_unknown']            = '—',

    -- NUI: admin config panel
    ['cfg_title']               = 'MBT Configuration',
    ['cfg_general']             = 'General',
    ['cfg_debug']               = 'Debug Mode',
    ['cfg_drop_death']          = 'Drop Weapon on Death',
    ['cfg_enable_sling']        = 'Enable Sling',
    ['cfg_enable_flashlight']   = 'Enable Flashlight',
    ['cfg_interface']           = 'Interface',
    ['cfg_holster_position']    = 'Holster UI Position',
    ['cfg_jamming']             = 'Weapon Jamming',
    ['cfg_enabled']             = 'Enabled',
    ['cfg_cooldown']            = 'Cooldown (seconds)',
    ['cfg_unjam_presses']       = 'Unjam Key Presses',
    ['cfg_throw']               = 'Weapon Throw',
    ['cfg_throw_key']           = 'Throw Key',
    ['cfg_cancel']              = 'Cancel',
    ['cfg_save']                = 'Save & Apply',
})
