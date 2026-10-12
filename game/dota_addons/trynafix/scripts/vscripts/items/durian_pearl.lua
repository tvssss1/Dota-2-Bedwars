require("items/pumpkin_item_utils")
LinkLuaModifier("modifier_custom_item_stats", "Modifiers/modifier_custom_item_stats", LUA_MODIFIER_MOTION_NONE)

item_durian_pearl = item_durian_pearl or class({})

function item_durian_pearl:GetIntrinsicModifierName() return "modifier_custom_item_stats" end

function item_durian_pearl:OnSpellStart()
    if not IsServer() then return end

    local caster = self:GetCaster()
    if not caster or caster:IsNull() or not caster:IsAlive() then return end

    local point = self:GetCursorPosition()
    local casterPoint = caster:GetAbsOrigin()
    local offset = point - casterPoint
    offset.z = 0
    if offset:Length2D() < 32 then
        offset = caster:GetForwardVector() * 32
        point = casterPoint + offset
    end

    local destination = GetGroundPosition(point, caster)
    local direction = offset:Normalized()
    -- npc_items_custom.txt is cached by the running tools session. Keep a
    -- real fallback so a Lua hot reload cannot turn a missing KV value into a
    -- nearly stationary 1-unit-per-second projectile.
    local speed = self:GetSpecialValueFor("projectile_speed")
    if not speed or speed <= 0 then speed = 1200 end

    self._durianCaster = caster
    self._durianDestination = destination
    self._durianResolved = false
    PumpkinItemUtils:SpendChargeImmediately(self)

    local particleTwo = ParticleManager:CreateParticle("particles/econ/events/fall_2021/blink_dagger_fall_2021_end_rays.vpcf", PATTACH_ABSORIGIN_FOLLOW, caster)
    ParticleManager:SetParticleControl(particleTwo, 0, casterPoint)
    ParticleManager:ReleaseParticleIndex(particleTwo)
    EmitSoundOn("StartTpEnderPearl", caster)

    local projectile = ProjectileManager:CreateLinearProjectile({
        EffectName = "particles/vengeful_arcana_wave_of_terror_pearl.vpcf",
        Ability = self,
        Source = caster,
        vSpawnOrigin = casterPoint,
        fStartRadius = 200,
        fEndRadius = 200,
        fDistance = (destination - casterPoint):Length2D(),
        iUnitTargetTeam = DOTA_UNIT_TARGET_ENEMY,
        iUnitTargetFlags = DOTA_UNIT_TARGET_FLAG_NONE,
        iUnitTargetType = DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_CREEP,
        vVelocity = direction * speed,
        bProvidesVision = true,
        iVisionTeamNumber = caster:GetTeamNumber(),
        iVisionRadius = 500
    })

    if not projectile then
        self:ResolveDurianPearl(destination)
    end
end

function item_durian_pearl:OnProjectileHit(target, location)
    if not IsServer() then return false end

    -- Units do not block the pearl; only the terminal callback resolves it.
    if target then return false end

    self:ResolveDurianPearl(location or self._durianDestination)
    return true
end

function item_durian_pearl:ResolveDurianPearl(location)
    if self._durianResolved then return end
    self._durianResolved = true

    local caster = self._durianCaster
    if caster and not caster:IsNull() and caster:IsAlive() then
        location = location or self._durianDestination or caster:GetAbsOrigin()
        EmitSoundOn("EndTpEnderPearl", caster)
        FindClearSpaceForUnit(caster, location, true)
        local particle = ParticleManager:CreateParticle("particles/creatures/aghanim/aghanim_blink_arrival.vpcf", PATTACH_ABSORIGIN, caster)
        ParticleManager:SetParticleControl(particle, 0, caster:GetAbsOrigin())
        ParticleManager:ReleaseParticleIndex(particle)
        caster:Stop()
    end

    self._durianCaster = nil
    self._durianDestination = nil
    PumpkinItemUtils:FinishImmediateSpend(self)
end
