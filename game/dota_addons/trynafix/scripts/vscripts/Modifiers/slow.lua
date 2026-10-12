modifier_bushes_slow = class({})

function modifier_bushes_slow:IsHidden() return false end
function modifier_bushes_slow:IsDebuff() return false end -- Usually slows are debuffs
function modifier_bushes_slow:IsPurgable() return true end

function modifier_bushes_slow:DeclareFunctions()
    return {
        MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE,
    }
end

function modifier_bushes_slow:GetModifierMoveSpeedBonus_Percentage()
    return -50 
end

function modifier_bushes_slow:GetTexture()
    return("bushIcon")
end