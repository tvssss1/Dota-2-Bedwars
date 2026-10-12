if PerkService == nil then
    PerkService = class({})
end

local PERK_IDS = {
    "balloon_brigade",
    "temporal_snapback",
    "wild_card",
    "treasure_trickster",
    "holo_hustle",
    "storm_chaser",
    "kaiju_protocol",
    "meteor_contract"
}

local PERK_ABILITIES = {
    balloon_brigade = "convergence_perk_balloon_brigade",
    temporal_snapback = "convergence_perk_temporal_snapback",
    wild_card = "convergence_perk_wild_card",
    treasure_trickster = "convergence_perk_treasure_trickster",
    holo_hustle = "convergence_perk_holo_hustle",
    storm_chaser = "convergence_perk_storm_chaser",
    kaiju_protocol = "convergence_perk_kaiju_protocol",
    meteor_contract = "convergence_perk_meteor_contract"
}

local PERK_SET = {}
for _, perkID in ipairs(PERK_IDS) do
    PERK_SET[perkID] = true
end

local OFFER_DURATION = 15
local MAX_SLOTS = 3
local MAX_RANK = 3

local function now()
    return GameRules:GetDOTATime(false, false)
end

local function validPlayerID(playerID)
    return playerID ~= nil
        and playerID >= 0
        and PlayerResource:IsValidPlayerID(playerID)
end

local function playerIDFromEvent(source, data)
    -- Panorama supplies PlayerID in the payload. Prefer it: the listener
    -- source is not guaranteed to be an entity index on every engine build.
    local eventPlayerID = type(data) == "table" and tonumber(data.PlayerID) or nil
    if validPlayerID(eventPlayerID) then return eventPlayerID end

    local player = source and EntIndexToHScript(source) or nil
    if player and not player:IsNull() and player.GetPlayerID then
        local sourcePlayerID = player:GetPlayerID()
        if validPlayerID(sourcePlayerID) then return sourcePlayerID end
    end

    local directSourcePlayerID = tonumber(source)
    if validPlayerID(directSourcePlayerID) then return directSourcePlayerID end
    return -1
end

local function copyArray(values)
    local result = {}
    for index, value in ipairs(values or {}) do
        result[index] = value
    end
    return result
end

local function shuffle(values)
    for index = #values, 2, -1 do
        local swapIndex = RandomInt(1, index)
        values[index], values[swapIndex] = values[swapIndex], values[index]
    end
end

function PerkService:Init()
    if self.initialized then return end
    self.initialized = true
    self.players = {}

    LinkLuaModifier("modifier_convergence_perks", "Modifiers/modifier_convergence_perks.lua", LUA_MODIFIER_MOTION_NONE)
    LinkLuaModifier("modifier_convergence_perk_balloon_brigade", "Modifiers/modifier_convergence_perks.lua", LUA_MODIFIER_MOTION_NONE)
    LinkLuaModifier("modifier_convergence_perk_temporal_snapback", "Modifiers/modifier_convergence_perks.lua", LUA_MODIFIER_MOTION_NONE)
    LinkLuaModifier("modifier_convergence_perk_wild_card", "Modifiers/modifier_convergence_perks.lua", LUA_MODIFIER_MOTION_NONE)
    LinkLuaModifier("modifier_convergence_perk_treasure_trickster", "Modifiers/modifier_convergence_perks.lua", LUA_MODIFIER_MOTION_NONE)
    LinkLuaModifier("modifier_convergence_perk_holo_hustle", "Modifiers/modifier_convergence_perks.lua", LUA_MODIFIER_MOTION_NONE)
    LinkLuaModifier("modifier_convergence_perk_storm_chaser", "Modifiers/modifier_convergence_perks.lua", LUA_MODIFIER_MOTION_NONE)
    LinkLuaModifier("modifier_convergence_perk_kaiju_protocol", "Modifiers/modifier_convergence_perks.lua", LUA_MODIFIER_MOTION_NONE)
    LinkLuaModifier("modifier_convergence_perk_meteor_contract", "Modifiers/modifier_convergence_perks.lua", LUA_MODIFIER_MOTION_NONE)
    LinkLuaModifier("modifier_convergence_capturing", "Modifiers/modifier_convergence_perks.lua", LUA_MODIFIER_MOTION_NONE)
    LinkLuaModifier("modifier_convergence_balloon_target", "Modifiers/modifier_convergence_perks.lua", LUA_MODIFIER_MOTION_NONE)
    LinkLuaModifier("modifier_perk_wildcard_barrier", "Modifiers/modifier_convergence_perks.lua", LUA_MODIFIER_MOTION_NONE)
    LinkLuaModifier("modifier_perk_holo_escape", "Modifiers/modifier_convergence_perks.lua", LUA_MODIFIER_MOTION_NONE)
    LinkLuaModifier("modifier_perk_holo_decoy", "Modifiers/modifier_convergence_perks.lua", LUA_MODIFIER_MOTION_NONE)
    LinkLuaModifier("modifier_perk_temporal_rupture_slow", "Modifiers/modifier_convergence_perks.lua", LUA_MODIFIER_MOTION_NONE)
    LinkLuaModifier("modifier_perk_treasure_rush", "Modifiers/modifier_convergence_perks.lua", LUA_MODIFIER_MOTION_NONE)
    LinkLuaModifier("modifier_perk_holo_burst_slow", "Modifiers/modifier_convergence_perks.lua", LUA_MODIFIER_MOTION_NONE)
    LinkLuaModifier("modifier_perk_storm_charged", "Modifiers/modifier_convergence_perks.lua", LUA_MODIFIER_MOTION_NONE)
    LinkLuaModifier("modifier_perk_kaiju_form", "Modifiers/modifier_convergence_perks.lua", LUA_MODIFIER_MOTION_NONE)

    CustomGameEventManager:RegisterListener("convergence_choose_perk", function(source, data)
        self:OnChoosePerk(source, data)
    end)
    CustomGameEventManager:RegisterListener("convergence_request_context", function(source, data)
        self:OnRequestContext(source, data)
    end)
    CustomGameEventManager:RegisterListener("convergence_offer_seen", function(source, data)
        self:OnOfferSeen(source, data)
    end)

    ListenToGameEvent("npc_spawned", function(event) self:OnNPCSpawned(event) end, nil)
    ListenToGameEvent("entity_killed", function(event) self:OnEntityKilled(event) end, nil)
    ListenToGameEvent("player_connect_full", function(event) self:OnPlayerConnected(event) end, nil)

    for playerID = 0, (DOTA_MAX_PLAYERS - 1) do
        if PlayerResource:IsValidPlayerID(playerID) then
            self:EnsurePlayer(playerID)
        end
    end
end

function PerkService:EnsurePlayer(playerID)
    if not validPlayerID(playerID) then return nil end
    if not self.players[playerID] then
        self.players[playerID] = {
            slots = {},
            ranks = {},
            runtime = {
                alive = 0,
                balloons = 0,
                balloon_next = 0,
                balloon_expires = 0,
                last_balloon_pop = 0,
                snapback_ready = 0,
                history = {},
                wild_count = 0,
                wild_ready = 0,
                holo_ready = 0,
                storm_distance = 0,
                storm_charged = 0,
                storm_last_position = nil,
                kaiju_stacks = 0,
                kaiju_ready = 0,
                kaiju_last_stack = 0,
                meteor_ready = 0
            },
            pending = nil
        }
    end
    self:Publish(playerID)
    return self.players[playerID]
end

function PerkService:GetPlayerState(playerID)
    if not validPlayerID(playerID) then return nil end
    return self.players[playerID] or self:EnsurePlayer(playerID)
end

function PerkService:GetRank(playerID, perkID)
    local state = self:GetPlayerState(playerID)
    if not state then return 0 end
    return tonumber(state.ranks[perkID]) or 0
end

function PerkService:GetRuntime(playerID)
    local state = self:GetPlayerState(playerID)
    return state and state.runtime or nil
end

function PerkService:GetAbilityName(perkID)
    return PERK_ABILITIES[perkID]
end

function PerkService:StartAbilityCooldown(hero, perkID, duration)
    if not hero or hero:IsNull() then return end
    local abilityName = PERK_ABILITIES[perkID]
    local ability = abilityName and hero:FindAbilityByName(abilityName) or nil
    if not ability or ability:IsNull() then return end
    ability:EndCooldown()
    if (tonumber(duration) or 0) > 0 then
        ability:StartCooldown(tonumber(duration))
    end
end

function PerkService:Publish(playerID)
    local state = self.players and self.players[playerID]
    if not state then return end

    local runtime = state.runtime
    local data = {
        slot_count = #state.slots,
        balloons = runtime.balloons or 0,
        balloon_next = runtime.balloon_next or 0,
        balloon_expires = runtime.balloon_expires or 0,
        snapback_ready = runtime.snapback_ready or 0,
        wild_count = runtime.wild_count or 0,
        wild_ready = runtime.wild_ready or 0,
        holo_ready = runtime.holo_ready or 0,
        storm_distance = runtime.storm_distance or 0,
        storm_charged = runtime.storm_charged or 0,
        kaiju_stacks = runtime.kaiju_stacks or 0,
        kaiju_ready = runtime.kaiju_ready or 0,
        meteor_ready = runtime.meteor_ready or 0
    }

    for slotIndex = 1, MAX_SLOTS do
        local perkID = state.slots[slotIndex]
        if perkID then
            data["slot_" .. slotIndex] = {
                id = perkID,
                rank = state.ranks[perkID] or 1
            }
        end
    end

    CustomNetTables:SetTableValue("convergence_perks", tostring(playerID), data)
end

function PerkService:ResetLifeRuntime(playerID, alive)
    local state = self:GetPlayerState(playerID)
    if not state then return end
    local runtime = state.runtime
    runtime.alive = alive and 1 or 0
    runtime.balloons = 0
    runtime.balloon_expires = 0
    runtime.last_balloon_pop = 0
    runtime.history = {}
    runtime.wild_count = 0
    runtime.storm_distance = 0
    runtime.storm_charged = 0
    runtime.storm_last_position = nil
    runtime.kaiju_stacks = 0
    runtime.kaiju_last_stack = 0
    if alive and self:GetRank(playerID, "balloon_brigade") > 0 then
        -- Respawning begins a fresh balloon cycle immediately.
        runtime.balloon_next = now()
    else
        runtime.balloon_next = 0
    end
    self:Publish(playerID)
end

function PerkService:ApplyToHero(hero)
    if not hero or hero:IsNull() or not hero.IsRealHero or not hero:IsRealHero() then return end
    if hero.IsIllusion and hero:IsIllusion() then return end
    if hero.IsClone and hero:IsClone() then return end
    if hero.IsTempestDouble and hero:IsTempestDouble() then return end

    local playerID = hero:GetPlayerOwnerID()
    if not validPlayerID(playerID) then return end
    local state = self:EnsurePlayer(playerID)
    if not state then return end

    for _, perkID in ipairs(state.slots) do
        local abilityName = PERK_ABILITIES[perkID]
        local rank = math.max(1, math.min(MAX_RANK, tonumber(state.ranks[perkID]) or 1))
        if abilityName then
            local ability = hero:FindAbilityByName(abilityName) or hero:AddAbility(abilityName)
            if ability and not ability:IsNull() then
                ability:SetLevel(rank)
                if ability.SetHidden then ability:SetHidden(true) end

                local readyAt = 0
                if perkID == "temporal_snapback" then readyAt = state.runtime.snapback_ready or 0 end
                if perkID == "wild_card" then readyAt = state.runtime.wild_ready or 0 end
                if perkID == "holo_hustle" then readyAt = state.runtime.holo_ready or 0 end
                if perkID == "balloon_brigade" then readyAt = state.runtime.balloon_next or 0 end
                if perkID == "kaiju_protocol" then readyAt = state.runtime.kaiju_ready or 0 end
                if perkID == "meteor_contract" then readyAt = state.runtime.meteor_ready or 0 end
                local remaining = math.max(0, readyAt - now())
                ability:EndCooldown()
                if remaining > 0 then ability:StartCooldown(remaining) end
            end
        end
    end
end

function PerkService:OnNPCSpawned(event)
    if not event or not event.entindex then return end
    local unit = EntIndexToHScript(event.entindex)
    self:ApplyToHero(unit)
end

function PerkService:OnEntityKilled(event)
    if not event or not event.entindex_killed then return end
    local unit = EntIndexToHScript(event.entindex_killed)
    if not unit or unit:IsNull() or not unit.IsRealHero or not unit:IsRealHero() then return end
    if unit.IsIllusion and unit:IsIllusion() then return end
    local playerID = unit:GetPlayerOwnerID()
    if validPlayerID(playerID) then
        self:ResetLifeRuntime(playerID, false)
    end
end

function PerkService:OnPlayerConnected(event)
    local playerID = tonumber(event and event.PlayerID)
    if not validPlayerID(playerID) then return end
    self:EnsurePlayer(playerID)
    Timers:CreateTimer(0.25, function()
        local hero = PlayerResource:GetSelectedHeroEntity(playerID)
        self:ApplyToHero(hero)
        self:SendPendingOffer(playerID)
    end)
end

function PerkService:IsEnemyPlayerDamage(parent, attacker)
    if not parent or parent:IsNull() or not attacker or attacker:IsNull() then return false end
    local attackerPlayerID = attacker.GetPlayerOwnerID and attacker:GetPlayerOwnerID() or -1
    if not validPlayerID(attackerPlayerID) and attacker.GetOwnerEntity then
        local owner = attacker:GetOwnerEntity()
        if owner and not owner:IsNull() and owner.GetPlayerOwnerID then
            attackerPlayerID = owner:GetPlayerOwnerID()
        end
    end
    if not validPlayerID(attackerPlayerID) then return false end
    return PlayerResource:GetTeam(attackerPlayerID) ~= parent:GetTeamNumber()
end

function PerkService:BuildOffer(playerID)
    local state = self:GetPlayerState(playerID)
    if not state then return nil, nil end

    if #state.slots < MAX_SLOTS then
        local unowned = {}
        for _, perkID in ipairs(PERK_IDS) do
            if not state.ranks[perkID] then
                table.insert(unowned, perkID)
            end
        end
        shuffle(unowned)
        local options = {}
        for index = 1, math.min(3, #unowned) do
            options[index] = unowned[index]
        end
        return "unlock", options
    end

    local options = {}
    for _, perkID in ipairs(state.slots) do
        if (state.ranks[perkID] or 0) < MAX_RANK then
            table.insert(options, perkID)
        end
    end
    return "upgrade", options
end

function PerkService:IsFullyMaxed(playerID)
    local state = self:GetPlayerState(playerID)
    if not state or #state.slots < MAX_SLOTS then return false end
    for _, perkID in ipairs(state.slots) do
        if (state.ranks[perkID] or 0) < MAX_RANK then return false end
    end
    return true
end

function PerkService:SendPendingOffer(playerID)
    local state = self:GetPlayerState(playerID)
    local pending = state and state.pending or nil
    if not pending then return end
    if pending.delivered and now() >= pending.expires_at then
        self:ResolvePendingRandomly(playerID, pending.sequence)
        return
    end

    local player = PlayerResource:GetPlayer(playerID)
    if not player then return end
    local payload = {
        sequence = pending.sequence,
        mode = pending.mode,
        expires_at = pending.delivered and pending.expires_at or (now() + OFFER_DURATION),
        duration = OFFER_DURATION,
        option_count = #pending.options,
        options = copyArray(pending.options)
    }
    for index, perkID in ipairs(pending.options) do
        payload["option_" .. index] = perkID
        payload["rank_" .. index] = pending.mode == "unlock" and 1 or ((state.ranks[perkID] or 0) + 1)
    end
    CustomGameEventManager:Send_ServerToPlayer(player, "convergence_offer", payload)
end

function PerkService:GrantClaimReward(playerID, sequence)
    local state = self:GetPlayerState(playerID)
    if not state then return false end

    if state.pending then
        -- Never replace or auto-select an offer the client has not handled.
        self:SendPendingOffer(playerID)
        return true
    end

    if self:IsFullyMaxed(playerID) then
        self:AwardOverflowCache(playerID)
        return true
    end

    local mode, options = self:BuildOffer(playerID)
    if not options or #options == 0 then
        self:AwardOverflowCache(playerID)
        return true
    end

    state.pending = {
        sequence = tonumber(sequence) or 0,
        mode = mode,
        options = copyArray(options),
        delivered = false,
        expires_at = -1
    }
    self:SendPendingOffer(playerID)
    return true
end

function PerkService:ResolvePendingRandomly(playerID, sequence)
    local state = self:GetPlayerState(playerID)
    local pending = state and state.pending or nil
    if not pending or pending.sequence ~= sequence or #pending.options == 0 then return false end
    local perkID = pending.options[RandomInt(1, #pending.options)]
    return self:ApplyPendingChoice(playerID, sequence, perkID)
end

function PerkService:ApplyPendingChoice(playerID, sequence, perkID)
    local state = self:GetPlayerState(playerID)
    local pending = state and state.pending or nil
    if not pending or pending.sequence ~= sequence or not PERK_SET[perkID] then return false end

    local offered = false
    for _, optionID in ipairs(pending.options) do
        if optionID == perkID then offered = true break end
    end
    if not offered then return false end

    state.pending = nil
    if pending.mode == "unlock" then
        if state.ranks[perkID] or #state.slots >= MAX_SLOTS then return false end
        table.insert(state.slots, perkID)
        state.ranks[perkID] = 1
    else
        local currentRank = state.ranks[perkID] or 0
        if currentRank <= 0 or currentRank >= MAX_RANK then return false end
        state.ranks[perkID] = currentRank + 1
    end

    local hero = PlayerResource:GetSelectedHeroEntity(playerID)
    self:ApplyToHero(hero)
    if perkID == "balloon_brigade" and hero and not hero:IsNull() and hero:IsAlive()
        and (state.runtime.balloon_next or 0) <= 0 then
        state.runtime.balloon_next = now()
    end
    self:Publish(playerID)

    local player = PlayerResource:GetPlayer(playerID)
    if player then
        CustomGameEventManager:Send_ServerToPlayer(player, "convergence_perk_selected", {
            perk_id = perkID,
            rank = state.ranks[perkID]
        })
    end
    return true
end

function PerkService:OnChoosePerk(source, data)
    local playerID = playerIDFromEvent(source, data)
    if not validPlayerID(playerID) then return end
    self:ApplyPendingChoice(playerID, tonumber(data and data.sequence) or -1, tostring(data and data.perk_id or ""))
end

function PerkService:OnOfferSeen(source, data)
    local playerID = playerIDFromEvent(source, data)
    if not validPlayerID(playerID) then return end
    local state = self:GetPlayerState(playerID)
    local pending = state and state.pending or nil
    if not pending or pending.sequence ~= (tonumber(data and data.sequence) or -1) then return end
    if pending.delivered then return end

    pending.delivered = true
    pending.expires_at = now() + OFFER_DURATION
    local expectedSequence = pending.sequence
    Timers:CreateTimer(OFFER_DURATION + 0.05, function()
        local current = self.players and self.players[playerID]
        local currentPending = current and current.pending or nil
        if currentPending and currentPending.delivered and currentPending.sequence == expectedSequence then
            self:ResolvePendingRandomly(playerID, expectedSequence)
        end
    end)
end

function PerkService:OnRequestContext(source, data)
    local playerID = playerIDFromEvent(source, data)
    if not validPlayerID(playerID) then return end
    self:EnsurePlayer(playerID)
    self:SendPendingOffer(playerID)
end

function PerkService:AwardOverflowCache(playerID)
    if PurpleCurrency then PurpleCurrency:Credit(playerID, 1) end
    if PumpkinCurrency then PumpkinCurrency:Credit(playerID, 1) end
    PlayerResource:ModifyGold(playerID, 200, true, DOTA_ModifyGold_Unspecified)

    local player = PlayerResource:GetPlayer(playerID)
    if player then
        CustomGameEventManager:Send_ServerToPlayer(player, "convergence_cache_awarded", {
            arcane = 1,
            pumpkin = 1,
            gold = 200
        })
    end
end

function PerkService:GetCurrencySpendBonus(playerID, amountSpent, currency)
    local rank = self:GetRank(playerID, "treasure_trickster")
    if rank <= 0 then return 0 end
    local hero = PlayerResource:GetSelectedHeroEntity(playerID)
    local chances = { 20, 28, 34 }
    local chance = chances[rank] or chances[#chances]
    local charges = math.max(0, math.floor(tonumber(amountSpent) or 0))
    local bonus = 0
    for _ = 1, charges do
        if RandomInt(1, 100) <= chance then bonus = bonus + 1 end
    end

    if bonus > 0 then
        local player = PlayerResource:GetPlayer(playerID)
        if hero and not hero:IsNull() and hero:IsAlive() then
            local rushDamage = { 20, 35, 50 }
            hero:AddNewModifier(hero, hero:FindAbilityByName("convergence_perk_treasure_trickster"), "modifier_perk_treasure_rush", {
                duration = 6,
                move_speed = 500,
                bonus_damage = rushDamage[rank]
            })
            local midasParticle = ParticleManager:CreateParticle(
                "particles/econ/items/alchemist/alchemist_midas_knuckles/alch_hand_of_midas.vpcf",
                PATTACH_ABSORIGIN_FOLLOW,
                hero
            )
            ParticleManager:SetParticleControlEnt(
                midasParticle,
                1,
                hero,
                PATTACH_POINT_FOLLOW,
                "attach_hitloc",
                hero:GetAbsOrigin(),
                true
            )
            ParticleManager:ReleaseParticleIndex(midasParticle)
            local coinParticle = ParticleManager:CreateParticle(
                "particles/econ/items/alchemist/alchemist_midas_knuckles/alch_knuckles_lasthit_coins.vpcf",
                PATTACH_ABSORIGIN_FOLLOW,
                hero
            )
            ParticleManager:ReleaseParticleIndex(coinParticle)
            EmitSoundOn("Trynafix.Perk.TreasureBonus", hero)
        end
        if player then
            CustomGameEventManager:Send_ServerToPlayer(player, "convergence_currency_bonus", {
                currency = tostring(currency or ""),
                amount = bonus
            })
        end
    end
    return bonus
end

return PerkService
