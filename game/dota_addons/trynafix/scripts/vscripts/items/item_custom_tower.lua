item_custom_tower = item_custom_tower or class({})
require("services/bed_utils")
LinkLuaModifier("modifier_structure_spell_immune", "Modifiers/modifier_structure_spell_immune.lua", LUA_MODIFIER_MOTION_NONE)

local TOWER_BUILD_PARTICLES = {
    "particles/items2_fx/pipe_of_insight_launch.vpcf",
    "particles/econ/events/fall_2021/blink_dagger_fall_2021_end_rays.vpcf"
}

local function PlayTowerBuildEffects(tower)
    local origin = tower:GetAbsOrigin()

    EmitSoundOn("DOTA_Item.RoshansBanner.Cast", tower)
    EmitSoundOn("DOTA_Item.Pipe.Activate", tower)

    for _, particleName in ipairs(TOWER_BUILD_PARTICLES) do
        local particle = ParticleManager:CreateParticle(
            particleName,
            PATTACH_WORLDORIGIN,
            nil
        )
        ParticleManager:SetParticleControl(particle, 0, origin)
        ParticleManager:ReleaseParticleIndex(particle)
    end
end

item_custom_tower.OnSpellStart = function(self)
    local caster = self:GetCaster()
    local point = self:GetCursorPosition()
    local playerID = caster:GetPlayerOwnerID()

    local casterTeam = caster:GetTeamNumber()
    local castRange = (point - caster:GetAbsOrigin()):Length2D()
    local ownLivingBed = BedUtils:NearestLivingBed(point, FIND_UNITS_EVERYWHERE, casterTeam)

    if not ownLivingBed then
        CustomGameEventManager:Send_ServerToPlayer(caster:GetPlayerOwner(), "ShowError", { message = "#hope_shop_error_own_bed" })
        EmitSoundOnClient("General.Cancel", PlayerResource:GetPlayer(playerID))
        return
    end

    -- Validate against the actual living bed. The Hammer spawn marker is only
    -- used to create the bed and can become stale if map groups are moved.
    local distance = (ownLivingBed:GetAbsOrigin() - point):Length2D()

    if distance <= 1000 and castRange <= 300 then
        local spawnUnit = CreateUnitByName("npc_custom_tower", point, true, caster, caster:GetOwner(), caster:GetTeamNumber())
        if not spawnUnit then
            CustomGameEventManager:Send_ServerToPlayer(caster:GetPlayerOwner(), "ShowError", { message = "#hope_shop_result_delivery_failed" })
            EmitSoundOnClient("General.Cancel", PlayerResource:GetPlayer(playerID))
            return
        end
        spawnUnit:AddNewModifier(spawnUnit, nil, "modifier_structure_spell_immune", {})
        PlayTowerBuildEffects(spawnUnit)

        local charges = self:GetCurrentCharges()
        if charges > 1 then self:SetCurrentCharges(charges - 1) else self:Destroy() end
    elseif distance > 1000 and castRange <= 300 then
        CustomGameEventManager:Send_ServerToPlayer(
            caster:GetPlayerOwner(),
            "ShowError",
            {
                message = "#custom_error_tower_near_bed"
            }
        )
        EmitSoundOnClient("General.Cancel", PlayerResource:GetPlayer(playerID))
    elseif castRange > 300 and distance <= 1000 then
        CustomGameEventManager:Send_ServerToPlayer(
            caster:GetPlayerOwner(),
            "ShowError",
             {
                message = "#hope_shop_error_too_far"
            }
        )
        EmitSoundOnClient("General.Cancel", PlayerResource:GetPlayer(playerID))
    elseif castRange > 300 and distance > 1000 then
        CustomGameEventManager:Send_ServerToPlayer(
            caster:GetPlayerOwner(),
            "ShowError",
             {
                message = "#custom_error_tower_near_bed"
            }
        )
        EmitSoundOnClient("General.Cancel", PlayerResource:GetPlayer(playerID))
    end
end
