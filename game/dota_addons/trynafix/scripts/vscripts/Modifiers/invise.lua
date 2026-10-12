modifier_bushes_invise = class({})

function modifier_bushes_invise:IsHidden() return true end
function modifier_bushes_invise:IsDebuff() return false end -- Usually slows are debuffs
function modifier_bushes_invise:IsPurgable() return true end


function modifier_bushes_invise:CheckState()
    return {
        [MODIFIER_STATE_INVISIBLE] = true,
    }
end

function modifier_bushes_invise:DeclareFunctions()
    return {
        MODIFIER_PROPERTY_INVISIBILITY_LEVEL,
        MODIFIER_EVENT_ON_ATTACK,
        MODIFIER_EVENT_ON_ABILITY_EXECUTED
    }
end

function modifier_bushes_invise:GetModifierInvisibilityLevel()
    return 1
end

    function modifier_bushes_invise:GetTexture(  )
        return("bushIcon")
    end

function modifier_bushes_invise:OnAttack(params)
	if IsServer() then
		if params.attacker == self:GetParent() then
			self:Destroy()
		end
	end
end

function modifier_bushes_invise:OnAbilityExecuted(params)
    if IsServer() then
        if params.unit == self:GetParent() then
            self:Destroy()
        end
    end
end