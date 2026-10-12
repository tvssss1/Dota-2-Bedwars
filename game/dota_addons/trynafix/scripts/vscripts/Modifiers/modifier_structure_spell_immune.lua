modifier_structure_spell_immune = class({})

function modifier_structure_spell_immune:IsHidden() return true end
function modifier_structure_spell_immune:IsPurgable() return false end
function modifier_structure_spell_immune:RemoveOnDeath() return false end

function modifier_structure_spell_immune:CheckState()
    return {
        [MODIFIER_STATE_MAGIC_IMMUNE] = true
    }
end

function modifier_structure_spell_immune:DeclareFunctions()
    return {
        MODIFIER_PROPERTY_INCOMING_DAMAGE_PERCENTAGE
    }
end

function modifier_structure_spell_immune:GetModifierIncomingDamage_Percentage(params)
    -- Normal attacks have no inflictor. Any damage carrying an ability or
    -- item handle is spell damage, regardless of whether it is magical,
    -- physical, or pure.
    if params and params.inflictor then return -100 end
    return 0
end
