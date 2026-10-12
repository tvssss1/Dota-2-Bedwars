modifier_bed_fountain_regen_aura = class({})
modifier_base_fountain_regen_aura = class({})

local FOUNTAIN_RADIUS = 600

function modifier_bed_fountain_regen_aura:IsHidden() return true end
function modifier_bed_fountain_regen_aura:IsPurgable() return false end
function modifier_bed_fountain_regen_aura:RemoveOnDeath() return true end
function modifier_bed_fountain_regen_aura:IsAura() return true end
function modifier_bed_fountain_regen_aura:GetAuraRadius() return FOUNTAIN_RADIUS end
function modifier_bed_fountain_regen_aura:GetAuraSearchTeam() return DOTA_UNIT_TARGET_TEAM_FRIENDLY end
function modifier_bed_fountain_regen_aura:GetAuraSearchType() return DOTA_UNIT_TARGET_HERO end
function modifier_bed_fountain_regen_aura:GetAuraSearchFlags() return DOTA_UNIT_TARGET_FLAG_NONE end
function modifier_bed_fountain_regen_aura:GetModifierAura() return "modifier_bed_fountain_regen" end

function modifier_bed_fountain_regen_aura:GetAuraEntityReject(target)
    if not target or target:IsNull() or not target:IsRealHero() then return true end
    -- Tools Mode opponents are disposable victory-test targets. Keeping them
    -- outside the 6%/second bed regeneration prevents a level-one attacker
    -- from seeing an apparently unkillable debug hero.
    if IsInToolsMode and IsInToolsMode() and RandomDraftService
        and RandomDraftService.IsDebugHero
        and RandomDraftService:IsDebugHero(target) then
        return true
    end
    return false
end

-- Permanent team-base source. It intentionally uses the same regeneration
-- buff as the legacy bed aura so existing HUD styling and balance stay intact.
function modifier_base_fountain_regen_aura:IsHidden() return true end
function modifier_base_fountain_regen_aura:IsPurgable() return false end
function modifier_base_fountain_regen_aura:RemoveOnDeath() return false end
function modifier_base_fountain_regen_aura:IsAura() return true end
function modifier_base_fountain_regen_aura:GetAuraRadius() return FOUNTAIN_RADIUS end
function modifier_base_fountain_regen_aura:GetAuraSearchTeam() return DOTA_UNIT_TARGET_TEAM_FRIENDLY end
function modifier_base_fountain_regen_aura:GetAuraSearchType() return DOTA_UNIT_TARGET_HERO end
function modifier_base_fountain_regen_aura:GetAuraSearchFlags() return DOTA_UNIT_TARGET_FLAG_NONE end
function modifier_base_fountain_regen_aura:GetModifierAura() return "modifier_bed_fountain_regen" end
function modifier_base_fountain_regen_aura:GetAuraEntityReject(target)
    return modifier_bed_fountain_regen_aura.GetAuraEntityReject(self, target)
end

modifier_bed_fountain_regen = class({})

function modifier_bed_fountain_regen:IsHidden() return false end
function modifier_bed_fountain_regen:IsDebuff() return false end
function modifier_bed_fountain_regen:IsPurgable() return false end
function modifier_bed_fountain_regen:RemoveOnDeath() return true end
function modifier_bed_fountain_regen:GetTexture() return "fountain_aura" end

function modifier_bed_fountain_regen:DeclareFunctions()
    return {
        MODIFIER_PROPERTY_HEALTH_REGEN_PERCENTAGE,
        MODIFIER_PROPERTY_MANA_REGEN_TOTAL_PERCENTAGE
    }
end

-- Matches the health- and mana-regeneration components of the standard Dota fountain.
function modifier_bed_fountain_regen:GetModifierHealthRegenPercentage()
    return 6
end

function modifier_bed_fountain_regen:GetModifierTotalPercentageManaRegen()
    return 6
end
