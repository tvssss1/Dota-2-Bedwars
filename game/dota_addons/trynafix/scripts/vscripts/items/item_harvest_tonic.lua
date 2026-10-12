LinkLuaModifier("modifier_harvest_tonic_speed", "Modifiers/modifier_harvest_tonic_speed", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_custom_item_stats", "Modifiers/modifier_custom_item_stats", LUA_MODIFIER_MOTION_NONE)
require("items/pumpkin_item_utils")

item_harvest_tonic = class({})

function item_harvest_tonic:GetIntrinsicModifierName() return "modifier_custom_item_stats" end

function item_harvest_tonic:OnSpellStart()
    if not IsServer() then return end
    local caster = self:GetCaster()
    if not caster or caster:IsNull() or not caster:IsAlive() then return end

    local healAmount = self:GetSpecialValueFor("heal_amount")
    local duration = self:GetSpecialValueFor("duration")
    local moveSpeed = self:GetSpecialValueFor("active_move_speed_pct")
    local attackSpeed = self:GetSpecialValueFor("active_attack_speed")
    local lifesteal = self:GetSpecialValueFor("active_lifesteal_pct")
    local takedownHeal = self:GetSpecialValueFor("takedown_heal")
    local takedownExtension = self:GetSpecialValueFor("takedown_extension")
    local maxDuration = self:GetSpecialValueFor("max_duration")

    caster:Purge(false, true, false, false, false)
    caster:Heal(healAmount, self)
    caster:AddNewModifier(caster, self, "modifier_harvest_tonic_speed", {
        duration = duration,
        move_speed_pct = moveSpeed,
        attack_speed = attackSpeed,
        lifesteal_pct = lifesteal,
        takedown_heal = takedownHeal,
        takedown_extension = takedownExtension,
        max_duration = maxDuration
    })
    EmitSoundOn("Trynafix.Item.HarvestTonic.Activate", caster)
    local castParticle = ParticleManager:CreateParticle(
        "particles/harvest_tonic/harvest_tonic_cast.vpcf",
        PATTACH_ABSORIGIN_FOLLOW,
        caster
    )
    ParticleManager:ReleaseParticleIndex(castParticle)

    PumpkinItemUtils:SpendCharge(self)
end
