modifier_bed_fow_reveal = class({})

function modifier_bed_fow_reveal:IsHidden() return true end
function modifier_bed_fow_reveal:IsDebuff() return false end
function modifier_bed_fow_reveal:IsPurgable() return false end
function modifier_bed_fow_reveal:RemoveOnDeath() return true end
function modifier_bed_fow_reveal:GetAttributes() return MODIFIER_ATTRIBUTE_MULTIPLE end

function modifier_bed_fow_reveal:DeclareFunctions()
    return { MODIFIER_PROPERTY_PROVIDES_FOW_POSITION }
end

-- Track-style reveal: the bed's position is visible through fog to the team of
-- this modifier's caster. GameSetup applies one hidden instance per active team.
function modifier_bed_fow_reveal:GetModifierProvidesFOWVision()
    return 1
end

