RegisterLocale('fr', {
    -- Notifications: jamming
    ['jam_jammed_title']        = 'Enrayée !',
    ['jam_jammed_desc']         = 'Votre arme s\'est enrayée ! Vérifiez son état !',
    ['jam_unjammed_title']      = 'Désenrayée !',
    ['jam_unjammed_desc']       = 'Vous avez désenrayé votre arme !',

    -- Notifications: throw
    ['throw_not_allowed_title'] = 'Oups !',
    ['throw_not_allowed_desc']  = 'Vous ne pouvez pas lancer cette arme !',

    -- No-draw zones
    ['no_draw_zone_title']      = 'Armes interdites',
    ['no_draw_zone_desc']       = 'Vous ne pouvez pas sortir une arme ici.',
    ['no_draw_zone_hud']        = 'Armes interdites',

    -- Low ready
    ['low_ready_none_title']    = 'Low Ready',
    ['low_ready_none_desc']     = 'Aucune arme longue à l\'épaule à mettre en low ready.',

    -- Weapon safety
    ['safety_no_weapon_title']  = 'Sécurité',
    ['safety_no_weapon_desc']   = 'Aucune arme à feu en main.',
    ['safety_on']               = 'SÛRETÉ',
    ['safety_off']              = 'FEU',

    -- Charge weapon
    ['charge_no_weapon_title']  = 'Armer l\'arme',
    ['charge_no_weapon_desc']   = 'Aucune arme à feu en main.',

    -- Showcase poses
    ['pose_in_vehicle_title']   = 'Pose',
    ['pose_in_vehicle_desc']    = 'Vous ne pouvez pas poser dans un véhicule.',

    -- Admin
    ['admin_no_perm_title']     = 'Admin',
    ['admin_no_perm_desc']      = 'Vous n\'avez pas la permission d\'ouvrir le panneau de configuration.',

    -- Custom weapon name
    ['wname_dialog_title']      = 'Nommer l\'arme',
    ['wname_dialog_field']      = 'Nom de l\'arme',
    ['wname_no_weapon_title']   = 'Nommer l\'arme',
    ['wname_no_weapon_desc']    = 'Aucune arme à feu en main.',
    ['wname_no_perm_title']     = 'Nommer l\'arme',
    ['wname_no_perm_desc']      = 'Vous ne pouvez pas graver un nom sur une arme.',
    ['wname_done_title']        = 'Arme nommée',
    ['wname_done_desc']         = 'Le nom a été gravé.',
    ['wname_locked_title']      = 'Nommer l\'arme',
    ['wname_locked_desc']       = 'Cette arme a déjà un nom.',

    -- Interaction prompts
    ['pickup_weapon']           = 'Ramasser l\'arme',

    -- Vehicle trunk weapon rack
    ['trunk_stow']              = 'Ranger l\'arme dans le coffre',
    ['trunk_retrieve']          = 'Prendre l\'arme du coffre',
    ['trunk_view']              = 'Ouvrir / fermer le coffre',
    ['trunk_locked_title']      = 'Coffre Verrouillé',
    ['trunk_locked_desc']       = 'Le véhicule est verrouillé.',
    ['trunk_full_title']        = 'Râtelier Plein',
    ['trunk_full_desc']         = 'Plus de place dans ce coffre.',
    ['trunk_no_plate_title']    = 'Coffre',
    ['trunk_no_plate_desc']     = 'Ce véhicule n\'a pas de plaque valide.',
    ['trunk_wrong_type_title']  = 'Coffre',
    ['trunk_wrong_type_desc']   = 'Seules les armes longues vont au coffre.',
    ['trunk_inv_full_title']    = 'Coffre',
    ['trunk_inv_full_desc']     = 'Espace d\'inventaire insuffisant.',

    -- Râtelier d'armes / casier
    ['rack_stow']               = 'Placer l\'arme sur le râtelier',
    ['rack_retrieve']           = 'Prendre l\'arme du râtelier',
    ['rack_full_title']         = 'Râtelier Plein',
    ['rack_full_desc']          = 'Plus de place sur ce râtelier.',
    ['rack_wrong_type_title']   = 'Râtelier',
    ['rack_wrong_type_desc']    = 'Cette arme ne va pas sur le râtelier.',
    ['rack_no_access_title']    = 'Râtelier',
    ['rack_no_access_desc']     = 'Vous n\'avez pas accès à ce râtelier.',
    ['rack_inv_full_title']     = 'Râtelier',
    ['rack_inv_full_desc']      = 'Espace d\'inventaire insuffisant.',
    ['rack_no_cert_title']      = 'Râtelier',
    ['rack_no_cert_desc']       = 'Vous n\'êtes pas certifié pour cette arme.',
    ['rack_picker_title']       = 'RÂTELIER',
    ['rack_picker_select']      = 'Choisir',
    ['rack_picker_take']        = 'Prendre',
    ['rack_picker_cancel']      = 'Annuler',
    ['rack_pickup']             = 'Démonter le râtelier',
    ['rack_place_hint']         = 'GAUCHE/DROITE tourner ~y~·~s~ SHIFT rapide ~y~·~s~ E placer ~y~·~s~ RETOUR annuler',
    ['rack_placed_title']       = 'Râtelier',
    ['rack_placed_desc']        = 'Râtelier installé.',
    ['rack_picked_up_title']    = 'Râtelier',
    ['rack_picked_up_desc']     = 'Râtelier démonté — objet rendu.',
    ['rack_limit_title']        = 'Râtelier',
    ['rack_limit_desc']         = 'Vous avez atteint votre limite de râteliers.',
    ['rack_too_close_title']    = 'Râtelier',
    ['rack_too_close_desc']     = 'Trop proche d\'un autre râtelier.',
    ['rack_not_empty_title']    = 'Râtelier',
    ['rack_not_empty_desc']     = 'Videz le râtelier avant de le démonter.',

    -- Douilles (forensique)
    ['casing_examine']          = 'Examiner la douille',
    ['casing_collect']          = 'Ramasser la douille',
    ['casing_title']            = 'DOUILLE',
    ['casing_serial']           = 'Série',
    ['casing_fired']            = 'Tiré',
    ['casing_ago']              = 'il y a %d min',
    ['casing_ago_now']          = 'à l\'instant',
    ['casing_collected_title']  = 'Preuve',
    ['casing_collected_desc']   = 'Douille ramassée.',

    -- Remise d'arme en main propre
    ['handoff_offers']          = 'vous offre',
    ['handoff_accept']          = 'Accepter',
    ['handoff_decline']         = 'Refuser',
    ['handoff_sent_title']      = 'Remise',
    ['handoff_sent_desc']       = 'Arme offerte — en attente de réponse.',
    ['handoff_done_title']      = 'Remise',
    ['handoff_done_desc']       = 'Arme remise.',
    ['handoff_declined_title']  = 'Remise',
    ['handoff_declined_desc']   = 'L\'offre a été refusée.',
    ['handoff_no_target_title'] = 'Remise',
    ['handoff_no_target_desc']  = 'Personne d\'assez proche pour remettre l\'arme.',
    ['handoff_inv_full_title']  = 'Remise',
    ['handoff_inv_full_desc']   = 'Le receveur n\'a pas de place dans son inventaire.',
    ['handoff_failed_title']    = 'Remise',
    ['handoff_failed_desc']     = 'La remise a échoué.',

    -- Port dissimulé
    ['concealed_on_title']      = 'Port Dissimulé',
    ['concealed_on_desc']       = 'Arme dissimulée.',
    ['concealed_off_title']     = 'Port Dissimulé',
    ['concealed_off_desc']      = 'Arme portée à découvert.',
    ['concealed_bare_title']    = 'Port Dissimulé',
    ['concealed_bare_desc']     = 'Rien pour la cacher — couvrez-vous d\'abord.',
    ['concealed_revealed_title']= 'Port Dissimulé',
    ['concealed_revealed_desc'] = 'Votre arme est de nouveau visible.',
    ['concealed_no_weapon_title']= 'Port Dissimulé',
    ['concealed_no_weapon_desc'] = 'Aucune arme dissimulable dans l\'étui.',

    -- NUI: holster prompt
    ['holster_title']           = 'RANGER L\'ARME',
    ['holster_action']          = 'Ranger',
    ['holster_confirm']         = 'Confirmer',
    ['holster_cancel']          = 'Annuler',

    -- NUI: jam minigame
    ['jam_title']               = 'ARME ENRAYÉE',
    ['jam_status']              = 'ENRAYÉE',
    ['jam_clear']               = 'Désenrayer',

    -- NUI: weapon condition HUD
    ['cond_label']              = 'ÉTAT',

    -- NUI: showcase pose mode
    ['pose_title']              = 'POSE',
    ['pose_cycle']              = 'Changer',
    ['pose_exit']               = 'Quitter',

    -- NUI: weapon inspect
    ['inspect_title']           = 'INSPECTION',
    ['inspect_serial']          = 'Série',
    ['inspect_condition']       = 'État',
    ['inspect_ammo']            = 'Munitions',
    -- Chain of Custody (Forensics)
    ['inspect_custody']         = 'Chaîne de Possession',
    ['custody_origin']          = 'origine',
    ['custody_now']             = 'actuel',
    -- Condition tiers (durability)
    ['cond_pristine']           = 'Impeccable',
    ['cond_good']               = 'Bon',
    ['cond_worn']               = 'Usé',
    ['cond_poor']               = 'Mauvais',
    ['cond_damaged']            = 'Endommagé',
    -- Vague ammo (AmmoMode = 'vague')
    ['ammo_full']               = 'Plein',
    ['ammo_half']               = 'À moitié',
    ['ammo_low']                = 'Presque vide',
    ['ammo_empty']              = 'Vide',
    ['ammo_unknown']            = '—',

    -- NUI: admin config panel
    ['cfg_title']               = 'Configuration MBT',
    ['cfg_general']             = 'Général',
    ['cfg_debug']               = 'Mode débogage',
    ['cfg_drop_death']          = 'Lâcher l\'arme à la mort',
    ['cfg_enable_sling']        = 'Activer le port à l\'épaule',
    ['cfg_enable_flashlight']   = 'Activer la lampe torche',
    ['cfg_interface']           = 'Interface',
    ['cfg_holster_position']    = 'Position de l\'interface',
    ['cfg_jamming']             = 'Enrayement d\'arme',
    ['cfg_enabled']             = 'Activé',
    ['cfg_cooldown']            = 'Délai (secondes)',
    ['cfg_unjam_presses']       = 'Appuis pour désenrayer',
    ['cfg_throw']               = 'Lancer d\'arme',
    ['cfg_throw_key']           = 'Touche de lancer',
    ['cfg_cancel']              = 'Annuler',
    ['cfg_save']                = 'Enregistrer et appliquer',
})
