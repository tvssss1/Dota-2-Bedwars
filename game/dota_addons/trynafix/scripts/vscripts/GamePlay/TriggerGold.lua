function StartGoldTick(event)
    local activator = event.activator
    if not activator or activator:IsNull() or not activator:IsRealHero() then return end

    activator.goldTickID = (activator.goldTickID or 0) + 1
    local currentID = activator.goldTickID

    activator.goldTickActive = true

    Timers:CreateTimer(function()
        if not activator or activator:IsNull() then return nil end
        if activator.goldTickID ~= currentID then
            return nil
        end

        if not activator:IsAlive() then
            return nil
        end

        if not activator.goldTickActive then
            return nil
        end

        local gold = RandomInt(10, 24)
        local xp = RandomInt(15, 35)

        PlayerResource:ModifyGold( activator:GetPlayerOwnerID(), gold, true, DOTA_ModifyGold_Unspecified )
        activator:AddExperience(xp, DOTA_ModifyXP_Unspecified, false, true)
        

        local particle = ParticleManager:CreateParticle("particles/econ/items/templar_assassin/ta_2022_immortal/ta_2022_immortal_trap_gold_flower_pattern.vpcf", PATTACH_ABSORIGIN_FOLLOW, activator)
        ParticleManager:SetParticleControl(particle, 0, activator:GetAbsOrigin())
        ParticleManager:ReleaseParticleIndex(particle)

        local particleTwo = ParticleManager:CreateParticle("particles/econ/courier/courier_flopjaw_gold/flopjaw_death_coins_gold.vpcf", PATTACH_ABSORIGIN_FOLLOW, activator)
        ParticleManager:SetParticleControl(particleTwo, 0, activator:GetAbsOrigin())
        ParticleManager:ReleaseParticleIndex(particleTwo)

        local player = PlayerResource:GetPlayer(activator:GetPlayerOwnerID())
        if player then
            EmitSoundOnClient("General.Coins", player)
        end
        return 1.0
    end)
end

function EndGoldTick(event)
    local hero = event.activator
    if not hero or hero:IsNull() then return end
    hero.goldTickActive = false
end
