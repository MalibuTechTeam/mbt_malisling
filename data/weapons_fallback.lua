---Minimal weapon data fallback for qb-inventory installs that do not run ox_inventory.
---Provides the same table structure as ox_inventory/data/weapons.lua so that
---loadWeaponsInfo() in core/server.lua can operate without ox_inventory present.
---
---Notes:
---  - Weapon entries are populated dynamically from data/weapons.lua (the type assignments).
---  - Component attachment visuals on sling props are limited to the entries below.
---  - Flashlight state persistence requires ox_inventory and is disabled in this mode.

return {
    Weapons = {},   -- populated at runtime by loadWeaponsInfo() from data/weapons.lua

    Components = {
        ['at_flashlight'] = {
            label  = 'Flashlight',
            weight = 30,
            client = {
                component = {
                    `COMPONENT_AT_AR_FLSH`,
                    `COMPONENT_AT_PI_FLSH`,
                    `COMPONENT_AT_PI_FLSH_02`,
                    `COMPONENT_AT_PI_FLSH_03`,
                }
            }
        },
        ['at_ar_supp_02'] = {
            label  = 'Suppressor',
            weight = 100,
            client = { component = { `COMPONENT_AT_AR_SUPP_02` } }
        },
        ['at_pi_supp_02'] = {
            label  = 'Suppressor',
            weight = 100,
            client = { component = { `COMPONENT_AT_PI_SUPP_02` } }
        },
        ['at_scope_macro'] = {
            label  = 'Scope',
            weight = 100,
            client = { component = { `COMPONENT_AT_SCOPE_MACRO` } }
        },
        ['at_scope_medium'] = {
            label  = 'Scope',
            weight = 100,
            client = { component = { `COMPONENT_AT_SCOPE_MEDIUM` } }
        },
        ['at_scope_large'] = {
            label  = 'Scope',
            weight = 100,
            client = { component = { `COMPONENT_AT_SCOPE_LARGE` } }
        },
        ['at_scope_max'] = {
            label  = 'Scope',
            weight = 100,
            client = { component = { `COMPONENT_AT_SCOPE_MAX` } }
        },
        ['at_ar_extclip'] = {
            label  = 'Extended Clip',
            weight = 30,
            client = { component = { `COMPONENT_AT_AR_EXTCLIP`, `COMPONENT_AT_AR_EXTCLIP2` } }
        },
        ['at_pi_extclip'] = {
            label  = 'Extended Clip',
            weight = 30,
            client = { component = { `COMPONENT_AT_PI_EXTCLIP`, `COMPONENT_AT_PI_EXTCLIP2` } }
        },
    }
}
