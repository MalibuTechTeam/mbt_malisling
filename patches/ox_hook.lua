if (anim == anims[`GROUP_PISTOL`] or data.type == 'side')
           and GetConvar('malisling:enable_sling', 'false') == 'true' then
            lib.requestAnimDict('reaction@intimidation@cop@unarmed')
            while not IsEntityPlayingAnim(playerPed, 'reaction@intimidation@cop@unarmed', 'intro', 3) do
                TaskPlayAnim(playerPed, 'reaction@intimidation@cop@unarmed', 'intro', 8.0, 2.0, -1, 50, 2.0, 1, 1, 0)
                Citizen.Wait(10)
            end
            LocalPlayer.state:set('malisling_holster_result', nil, false)
            TriggerEvent('mbt_malisling:holster_request', { weaponLabel = data.model or 'WEAPON' })
            local _deadline = GetGameTimer() + 15000
            while LocalPlayer.state.malisling_holster_result == nil and GetGameTimer() < _deadline do
                Citizen.Wait(50)
            end
            local _confirmed = LocalPlayer.state.malisling_holster_result
            LocalPlayer.state:set('malisling_holster_result', nil, false)
            if not _confirmed then
                ClearPedSecondaryTask(playerPed)
                return
            end
            coords = GetEntityCoords(playerPed, true)
        end
