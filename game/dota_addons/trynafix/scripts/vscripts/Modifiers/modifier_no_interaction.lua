modifier_no_interaction = class({})

function modifier_no_interaction:IsHidden() return true end
function modifier_no_interaction:IsDebuff() return false end
function modifier_no_interaction:IsPurgable() return false end

function modifier_no_interaction:CheckState()
    return {
        [MODIFIER_STATE_INVULNERABLE] = true,        -- cannot take damage
        [MODIFIER_STATE_STUNNED] = true,             -- cannot act
        [MODIFIER_STATE_COMMAND_RESTRICTED] = true,
        [MODIFIER_STATE_NO_HEALTH_BAR] = true,
        [MODIFIER_STATE_UNSELECTABLE] = true,
        [MODIFIER_STATE_NOT_ON_MINIMAP] = true,
    }
end

function modifier_no_interaction:DeclareFunctions()
    return {
        MODIFIER_PROPERTY_DISABLE_AUTOATTACK,
    }
end

function modifier_no_interaction:GetDisableAutoAttack()
    return 1
end
