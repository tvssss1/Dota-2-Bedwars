modifier_custom_item_stats = class({})

function modifier_custom_item_stats:IsHidden() return true end
function modifier_custom_item_stats:IsPurgable() return false end
function modifier_custom_item_stats:RemoveOnDeath() return false end
function modifier_custom_item_stats:GetAttributes() return MODIFIER_ATTRIBUTE_MULTIPLE end

local ITEM_STATS = {
    item_durian_pearl = { agility="bonus_agility", moveSpeed="bonus_movement_speed" },
    item_harvest_tonic = { strength="bonus_strength", healthRegen="bonus_health_regen" },
    item_skyhook_spool = { damage="bonus_damage", armor="bonus_armor" },
    item_gravity_marble = { intellect="bonus_intellect", manaRegen="bonus_mana_regen" }
}

function modifier_custom_item_stats:OnCreated()
    local ability = self:GetAbility()
    self.strength, self.agility, self.intellect = 0, 0, 0
    self.damage, self.armor, self.attackSpeed = 0, 0, 0
    self.moveSpeed, self.healthRegen, self.manaRegen = 0, 0, 0
    if not ability or ability:IsNull() then return end

    self.itemName = ability:GetAbilityName()
    local stats = ITEM_STATS[self.itemName]
    if not stats then return end
    for field, specialName in pairs(stats) do
        self[field] = ability:GetSpecialValueFor(specialName) or 0
    end
end

function modifier_custom_item_stats:GetActiveStat(field)
    local ability = self:GetAbility()
    if not ability or ability:IsNull() then return 0 end
    -- Skyhook is the sole cooldown item. Every other custom item is a
    -- consumable, so its held stats stop the instant its final charge is paid.
    if self.itemName ~= "item_skyhook_spool" and ability:GetCurrentCharges() <= 0 then return 0 end
    return self[field] or 0
end

function modifier_custom_item_stats:OnRefresh() self:OnCreated() end

function modifier_custom_item_stats:DeclareFunctions()
    return {
        MODIFIER_PROPERTY_STATS_STRENGTH_BONUS,
        MODIFIER_PROPERTY_STATS_AGILITY_BONUS,
        MODIFIER_PROPERTY_STATS_INTELLECT_BONUS,
        MODIFIER_PROPERTY_PREATTACK_BONUS_DAMAGE,
        MODIFIER_PROPERTY_PHYSICAL_ARMOR_BONUS,
        MODIFIER_PROPERTY_ATTACKSPEED_BONUS_CONSTANT,
        MODIFIER_PROPERTY_MOVESPEED_BONUS_CONSTANT,
        MODIFIER_PROPERTY_HEALTH_REGEN_CONSTANT,
        MODIFIER_PROPERTY_MANA_REGEN_CONSTANT
    }
end

function modifier_custom_item_stats:GetModifierBonusStats_Strength() return self:GetActiveStat("strength") end
function modifier_custom_item_stats:GetModifierBonusStats_Agility() return self:GetActiveStat("agility") end
function modifier_custom_item_stats:GetModifierBonusStats_Intellect() return self:GetActiveStat("intellect") end
function modifier_custom_item_stats:GetModifierPreAttack_BonusDamage() return self:GetActiveStat("damage") end
function modifier_custom_item_stats:GetModifierPhysicalArmorBonus() return self:GetActiveStat("armor") end
function modifier_custom_item_stats:GetModifierAttackSpeedBonus_Constant() return self:GetActiveStat("attackSpeed") end
function modifier_custom_item_stats:GetModifierMoveSpeedBonus_Constant() return self:GetActiveStat("moveSpeed") end
function modifier_custom_item_stats:GetModifierConstantHealthRegen() return self:GetActiveStat("healthRegen") end
function modifier_custom_item_stats:GetModifierConstantManaRegen() return self:GetActiveStat("manaRegen") end
