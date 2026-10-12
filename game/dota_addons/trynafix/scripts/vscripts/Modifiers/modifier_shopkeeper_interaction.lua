modifier_shopkeeper_interaction = class({})

function modifier_shopkeeper_interaction:IsHidden() return true end
function modifier_shopkeeper_interaction:IsPurgable() return false end
function modifier_shopkeeper_interaction:CheckState()
    return {
        [MODIFIER_STATE_INVULNERABLE] = true,
        [MODIFIER_STATE_ROOTED] = true,
        [MODIFIER_STATE_DISARMED] = true,
        [MODIFIER_STATE_NO_UNIT_COLLISION] = true
    }
end
function modifier_shopkeeper_interaction:DeclareFunctions()
    return { MODIFIER_PROPERTY_DISABLE_AUTOATTACK }
end
function modifier_shopkeeper_interaction:GetDisableAutoAttack() return 1 end
