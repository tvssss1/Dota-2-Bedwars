modifier_pregame_stun = class({})

function modifier_pregame_stun:IsHidden() return true end
function modifier_pregame_stun:IsDebuff() return true end
function modifier_pregame_stun:IsPurgable() return false end
function modifier_pregame_stun:RemoveOnDeath() return false end

function modifier_pregame_stun:CheckState()
    return {
        [MODIFIER_STATE_STUNNED] = true
    }
end

function modifier_pregame_stun:DeclareFunctions()
    return { MODIFIER_PROPERTY_OVERRIDE_ANIMATION }
end

function modifier_pregame_stun:GetOverrideAnimation()
    return ACT_DOTA_DISABLED
end
