modifier_victory_pose = class({})

function modifier_victory_pose:IsHidden() return true end
function modifier_victory_pose:IsPurgable() return false end
function modifier_victory_pose:RemoveOnDeath() return true end

function modifier_victory_pose:CheckState()
    return {
        [MODIFIER_STATE_COMMAND_RESTRICTED] = true,
        [MODIFIER_STATE_ROOTED] = true,
        [MODIFIER_STATE_DISARMED] = true,
        [MODIFIER_STATE_INVULNERABLE] = true,
        [MODIFIER_STATE_NO_UNIT_COLLISION] = true
    }
end

function modifier_victory_pose:DeclareFunctions()
    return { MODIFIER_PROPERTY_OVERRIDE_ANIMATION }
end

function modifier_victory_pose:GetOverrideAnimation()
    return ACT_DOTA_VICTORY
end
