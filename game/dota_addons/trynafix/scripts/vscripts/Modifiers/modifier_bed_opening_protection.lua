modifier_bed_opening_protection = class({})

function modifier_bed_opening_protection:IsHidden() return false end
function modifier_bed_opening_protection:IsDebuff() return false end
function modifier_bed_opening_protection:IsPurgable() return false end
function modifier_bed_opening_protection:RemoveOnDeath() return true end
function modifier_bed_opening_protection:GetTexture() return "item_mjollnir" end

function modifier_bed_opening_protection:CheckState()
    return {
        [MODIFIER_STATE_INVULNERABLE] = true,
        [MODIFIER_STATE_ATTACK_IMMUNE] = true
    }
end

function modifier_bed_opening_protection:OnCreated()
    if not IsServer() then return end

    local bed = self:GetParent()
    local particle = ParticleManager:CreateParticle(
        "particles/econ/events/spring_2021/mjollnir_shield_spring_2021.vpcf",
        PATTACH_ABSORIGIN_FOLLOW,
        bed
    )
    ParticleManager:SetParticleControlEnt(
        particle,
        0,
        bed,
        PATTACH_ABSORIGIN_FOLLOW,
        "attach_hitloc",
        bed:GetAbsOrigin(),
        true
    )
    self:AddParticle(particle, false, false, -1, false, false)
end
