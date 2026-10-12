convergence_perk_balloon_brigade = class({})
convergence_perk_temporal_snapback = class({})
convergence_perk_wild_card = class({})
convergence_perk_treasure_trickster = class({})
convergence_perk_holo_hustle = class({})
convergence_perk_storm_chaser = class({})
convergence_perk_kaiju_protocol = class({})
convergence_perk_meteor_contract = class({})

local DISPLAY_MODIFIERS = {
    convergence_perk_balloon_brigade = "modifier_convergence_perk_balloon_brigade",
    convergence_perk_temporal_snapback = "modifier_convergence_perk_temporal_snapback",
    convergence_perk_wild_card = "modifier_convergence_perk_wild_card",
    convergence_perk_treasure_trickster = "modifier_convergence_perk_treasure_trickster",
    convergence_perk_holo_hustle = "modifier_convergence_perk_holo_hustle",
    convergence_perk_storm_chaser = "modifier_convergence_perk_storm_chaser",
    convergence_perk_kaiju_protocol = "modifier_convergence_perk_kaiju_protocol",
    convergence_perk_meteor_contract = "modifier_convergence_perk_meteor_contract"
}

local function displayModifier(ability)
    return DISPLAY_MODIFIERS[ability:GetAbilityName()]
end

local function updateDisplayRank(ability)
    if not IsServer() then return end
    local caster = ability:GetCaster()
    local modifierName = displayModifier(ability)
    local modifier = caster and modifierName and caster:FindModifierByName(modifierName) or nil
    if modifier then modifier:SetStackCount(math.max(1, ability:GetLevel())) end
end

function convergence_perk_balloon_brigade:GetIntrinsicModifierName() return displayModifier(self) end
function convergence_perk_temporal_snapback:GetIntrinsicModifierName() return displayModifier(self) end
function convergence_perk_wild_card:GetIntrinsicModifierName() return displayModifier(self) end
function convergence_perk_treasure_trickster:GetIntrinsicModifierName() return displayModifier(self) end
function convergence_perk_holo_hustle:GetIntrinsicModifierName() return displayModifier(self) end
function convergence_perk_storm_chaser:GetIntrinsicModifierName() return displayModifier(self) end
function convergence_perk_kaiju_protocol:GetIntrinsicModifierName() return displayModifier(self) end
function convergence_perk_meteor_contract:GetIntrinsicModifierName() return displayModifier(self) end

function convergence_perk_balloon_brigade:OnUpgrade() updateDisplayRank(self) end
function convergence_perk_temporal_snapback:OnUpgrade() updateDisplayRank(self) end
function convergence_perk_wild_card:OnUpgrade() updateDisplayRank(self) end
function convergence_perk_treasure_trickster:OnUpgrade() updateDisplayRank(self) end
function convergence_perk_holo_hustle:OnUpgrade() updateDisplayRank(self) end
function convergence_perk_storm_chaser:OnUpgrade() updateDisplayRank(self) end
function convergence_perk_kaiju_protocol:OnUpgrade() updateDisplayRank(self) end
function convergence_perk_meteor_contract:OnUpgrade() updateDisplayRank(self) end

function convergence_perk_balloon_brigade:IsStealable() return false end
function convergence_perk_temporal_snapback:IsStealable() return false end
function convergence_perk_wild_card:IsStealable() return false end
function convergence_perk_treasure_trickster:IsStealable() return false end
function convergence_perk_holo_hustle:IsStealable() return false end
function convergence_perk_storm_chaser:IsStealable() return false end
function convergence_perk_kaiju_protocol:IsStealable() return false end
function convergence_perk_meteor_contract:IsStealable() return false end
