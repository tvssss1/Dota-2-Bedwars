local ModeConfig = require("settings/mode_config")

if AbilityDraftService == nil then
    AbilityDraftService = class({})
end

local OFFER_DURATION = 18
local THINK_INTERVAL = 0.25
local LEVEL_TIMER_REDUCTION = 20
local BASIC_OPTIONS_PER_ROLE = 3
local ULTIMATE_OPTION_COUNT = 9

-- Ability acquisition and Convergence are deliberately independent systems.
-- These offers are guaranteed by match time; shrine captures continue to
-- grant only Convergence perks through PerkService.
local SLOT_MILESTONES = {
    { time = 0,   kind = "basic",    maxLevel = 4 },
    { time = 180, kind = "basic",    maxLevel = 4 },
    { time = 360, kind = "basic",    maxLevel = 4 },
    { time = 480, kind = "ultimate", maxLevel = 3 }
}

-- Emergency fallback used only if Valve's runtime hero catalog cannot be read.
local BASIC_POOLS = {
    offense = {
        "lina_dragon_slave",
        "windrunner_powershot",
        "magnataur_shockwave",
        "rubick_fade_bolt",
        "skywrath_mage_arcane_bolt",
        "death_prophet_carrion_swarm",
        "queenofpain_scream_of_pain",
        "jakiro_dual_breath"
    },
    control = {
        "crystal_maiden_frostbite",
        "lion_impale",
        "sven_storm_bolt",
        "vengefulspirit_magic_missile",
        "earthshaker_fissure",
        "sandking_burrowstrike",
        "centaur_hoof_stomp",
        "slardar_slithereen_crush"
    },
    survival = {
        "abaddon_aphotic_shield",
        "omniknight_purification",
        "dazzle_shadow_wave",
        "warlock_shadow_word",
        "weaver_shukuchi",
        "bounty_hunter_wind_walk",
        "faceless_void_time_walk",
        "axe_berserkers_call"
    }
}

local ULTIMATE_POOL = {
    "lina_laguna_blade",
    "lion_finger_of_death",
    "tidehunter_ravage",
    "earthshaker_echo_slam",
    "magnataur_reverse_polarity",
    "queenofpain_sonic_wave",
    "sandking_epicenter",
    "enigma_black_hole",
    "crystal_maiden_freezing_field",
    "sniper_assassinate",
    "sven_gods_strength",
    "ursa_enrage"
}

local BASIC_ROLES = { "offense", "control", "survival" }
local CONTROL_HINTS = {
    "stun", "hex", "impale", "fissure", "root", "ensnare", "sleep",
    "silence", "stomp", "crush", "shackle", "lasso", "grip", "taunt",
    "fear", "terror", "cyclone", "vacuum", "telekinesis", "burrowstrike",
    "frostbite", "disable", "slow", "curse"
}
local SURVIVAL_HINTS = {
    "heal", "shield", "barrier", "armor", "guard", "protection", "grave",
    "invis", "wind_walk", "shukuchi", "time_walk", "blink", "escape",
    "rage", "enrage", "refraction", "blur", "repel", "purification",
    "shadow_wave", "aphotic", "restoration", "mend", "save", "swap"
}
local DRAFT_RANDOM_MODULUS = 2147483647
local draftRandomState = 1

local function seedDraftRandom()
    local seed = RandomInt(1, DRAFT_RANDOM_MODULUS - 1)
    if type(Time) == "function" then
        seed = seed + math.floor((tonumber(Time()) or 0) * 100000)
    end
    if type(GetSystemTimeMS) == "function" then
        seed = seed + math.floor(tonumber(GetSystemTimeMS()) or 0)
    end
    draftRandomState = (math.abs(seed) % (DRAFT_RANDOM_MODULUS - 1)) + 1
end

local function draftRandomInt(minimum, maximum)
    draftRandomState = (draftRandomState * 48271) % DRAFT_RANDOM_MODULUS
    local span = maximum - minimum + 1
    return minimum + (draftRandomState % span)
end

local function now()
    return math.max(0, GameRules:GetDOTATime(false, false))
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

local function shuffle(values)
    for index = #values, 2, -1 do
        local swapIndex = draftRandomInt(1, index)
        values[index], values[swapIndex] = values[swapIndex], values[index]
    end
end

local function copyArray(values)
    local result = {}
    for index, value in ipairs(values or {}) do result[index] = value end
    return result
end

local function kvFlag(data, key)
    if type(data) ~= "table" then return false end
    local value = data[key]
    return value == 1 or value == true or tostring(value or "") == "1"
end

local function containsAny(value, hints)
    value = string.lower(tostring(value or ""))
    for _, hint in ipairs(hints) do
        if string.find(value, hint, 1, true) then return true end
    end
    return false
end

local function unwrapKV(data, rootKey)
    if type(data) ~= "table" then return {} end
    return type(data[rootKey]) == "table" and data[rootKey] or data
end

local function isDraftHero(hero)
    if not hero or hero:IsNull() or not hero.IsRealHero or not hero:IsRealHero() then return false end
    if hero.IsIllusion and hero:IsIllusion() then return false end
    if hero.IsClone and hero:IsClone() then return false end
    if hero.IsTempestDouble and hero:IsTempestDouble() then return false end
    local playerID = hero:GetPlayerOwnerID()
    return validPlayerID(playerID) and ModeConfig.IsPlayableTeam(hero:GetTeamNumber())
end

function AbilityDraftService:Init()
    if self.initialized then return end
    self.initialized = true
    self.players = {}
    self.sequence = 0
    self.matchStarted = false
    seedDraftRandom()
    self:BuildAbilityCatalog()

    CustomGameEventManager:RegisterListener("ability_draft_choose", function(source, data)
        self:OnChoose(source, data)
    end)
    CustomGameEventManager:RegisterListener("ability_draft_request_context", function(source, data)
        self:OnRequestContext(source, data)
    end)
    CustomGameEventManager:RegisterListener("ability_draft_offer_seen", function(source, data)
        self:OnOfferSeen(source, data)
    end)

    ListenToGameEvent("npc_spawned", function(event) self:OnNPCSpawned(event) end, nil)
    ListenToGameEvent("player_connect_full", function(event) self:OnPlayerConnected(event) end, nil)
    ListenToGameEvent("dota_player_learned_ability", function(event) self:OnPlayerLearnedAbility(event) end, nil)
    ListenToGameEvent("game_rules_state_change", function() self:OnStateChange() end, nil)

    for playerID = 0, DOTA_MAX_PLAYERS - 1 do
        if validPlayerID(playerID) then self:EnsurePlayer(playerID) end
    end

    GameRules:GetGameModeEntity():SetContextThink("AbilityDraftThink", function()
        return self:Think()
    end, THINK_INTERVAL)

    if GameRules:State_Get() == DOTA_GAMERULES_STATE_GAME_IN_PROGRESS then
        self:StartMatch()
    end
end

function AbilityDraftService:IsDraftableAbility(abilityName, abilityData)
    if type(abilityName) ~= "string" or abilityName == "" then return false end
    local lowerName = string.lower(abilityName)
    if lowerName == "attribute_bonus" or lowerName == "generic_hidden" then return false end
    if string.find(lowerName, "special_bonus", 1, true) then return false end
    if string.find(lowerName, "empty", 1, true) then return false end
    if string.find(lowerName, "ability_capture", 1, true) then return false end

    local behavior = string.upper(tostring(type(abilityData) == "table" and abilityData.AbilityBehavior or ""))
    if string.find(behavior, "HIDDEN", 1, true) then return false end
    if string.find(behavior, "NOT_LEARNABLE", 1, true) then return false end
    if kvFlag(abilityData, "AbilityDraftDisabled") or kvFlag(abilityData, "ADDisabled") then return false end
    if kvFlag(abilityData, "IsGrantedByScepter") or kvFlag(abilityData, "IsGrantedByShard") then return false end
    return true
end

function AbilityDraftService:ClassifyBasicAbility(abilityName)
    if containsAny(abilityName, SURVIVAL_HINTS) then return "survival" end
    if containsAny(abilityName, CONTROL_HINTS) then return "control" end
    return "offense"
end

function AbilityDraftService:BuildAbilityCatalog()
    self.basicPools = { offense = {}, control = {}, survival = {} }
    self.ultimatePool = {}
    self.abilitySources = {}
    self.precachedSourceHeroes = {}

    local heroes = unwrapKV(LoadKeyValues("scripts/npc/npc_heroes.txt"), "DOTAHeroes")
    local allAbilities = unwrapKV(LoadKeyValues("scripts/npc/npc_abilities.txt"), "DOTAAbilities")
    local seen = {}

    local function addAbility(heroName, abilityName, slotIndex)
        if seen[abilityName] then return end
        local abilityData = nil
        if type(GetAbilityKeyValuesByName) == "function" then
            abilityData = GetAbilityKeyValuesByName(abilityName)
        end
        if type(abilityData) ~= "table" then abilityData = allAbilities[abilityName] end
        if not self:IsDraftableAbility(abilityName, abilityData) then return end

        seen[abilityName] = true
        self.abilitySources[abilityName] = heroName
        local abilityType = string.upper(tostring(type(abilityData) == "table" and abilityData.AbilityType or ""))
        local isUltimate = string.find(abilityType, "ULTIMATE", 1, true) ~= nil
        if abilityType == "" and tonumber(slotIndex) == 6 then isUltimate = true end

        if isUltimate then
            table.insert(self.ultimatePool, abilityName)
        else
            local role = self:ClassifyBasicAbility(abilityName)
            table.insert(self.basicPools[role], abilityName)
        end
    end

    for heroName, heroData in pairs(heroes) do
        if type(heroName) == "string"
            and string.sub(heroName, 1, 14) == "npc_dota_hero_"
            and heroName ~= "npc_dota_hero_base"
            and type(heroData) == "table" then
            for key, value in pairs(heroData) do
                local slotIndex = type(key) == "string" and string.match(key, "^Ability(%d+)$") or nil
                if slotIndex and type(value) == "string" then addAbility(heroName, value, tonumber(slotIndex)) end
            end
            if type(heroData.Abilities) == "table" then
                for key, value in pairs(heroData.Abilities) do
                    if type(value) == "string" then addAbility(heroName, value, tonumber(key)) end
                end
            end
        end
    end

    local basicCount = #self.basicPools.offense + #self.basicPools.control + #self.basicPools.survival
    if basicCount < 9 or #self.ultimatePool < ULTIMATE_OPTION_COUNT then
        self.basicPools = BASIC_POOLS
        self.ultimatePool = ULTIMATE_POOL
        basicCount = #BASIC_POOLS.offense + #BASIC_POOLS.control + #BASIC_POOLS.survival
        print("[AbilityDraft] Runtime catalog unavailable; using fallback pool.")
    else
        print(string.format(
            "[AbilityDraft] Loaded %d draftable basics and %d ultimates from Dota's hero catalog.",
            basicCount,
            #self.ultimatePool
        ))
    end

    CustomNetTables:SetTableValue("ability_draft", "catalog", {
        basic_count = basicCount,
        ultimate_count = #self.ultimatePool,
        total_count = basicCount + #self.ultimatePool
    })
end

function AbilityDraftService:PrecacheOffer(options, playerID)
    if type(PrecacheUnitByNameAsync) ~= "function" then return end
    for _, option in ipairs(options or {}) do
        local heroName = self.abilitySources and self.abilitySources[option.name] or nil
        if heroName and not self.precachedSourceHeroes[heroName] then
            self.precachedSourceHeroes[heroName] = true
            PrecacheUnitByNameAsync(heroName, function() end, playerID)
        end
    end
end

function AbilityDraftService:EnsurePlayer(playerID)
    if not validPlayerID(playerID) then return nil end
    if not self.players[playerID] then
        self.players[playerID] = {
            abilities = {},
            pending = nil,
            nextOfferAt = 0,
            lastHeroLevel = nil
        }
    end
    return self.players[playerID]
end

function AbilityDraftService:GetHero(playerID)
    if not validPlayerID(playerID) then return nil end
    local hero = PlayerResource:GetSelectedHeroEntity(playerID)
    if hero and not hero:IsNull() then return hero end
    local player = PlayerResource:GetPlayer(playerID)
    hero = player and player:GetAssignedHero() or nil
    return hero and not hero:IsNull() and hero or nil
end

function AbilityDraftService:GetOwnedSet(state)
    local owned = {}
    for _, entry in ipairs(state and state.abilities or {}) do
        owned[entry.name] = true
    end
    return owned
end

function AbilityDraftService:BuildOffer(state, kind)
    local owned = self:GetOwnedSet(state)
    local options = {}

    if kind == "ultimate" then
        local candidates = {}
        for _, abilityName in ipairs(self.ultimatePool or ULTIMATE_POOL) do
            if not owned[abilityName] then table.insert(candidates, abilityName) end
        end
        shuffle(candidates)
        for index = 1, math.min(ULTIMATE_OPTION_COUNT, #candidates) do
            table.insert(options, { name = candidates[index], role = "ultimate" })
        end
        return options
    end

    for _, role in ipairs(BASIC_ROLES) do
        local candidates = {}
        local rolePool = self.basicPools and self.basicPools[role] or BASIC_POOLS[role]
        for _, abilityName in ipairs(rolePool) do
            if not owned[abilityName] then table.insert(candidates, abilityName) end
        end
        shuffle(candidates)
        for index = 1, math.min(BASIC_OPTIONS_PER_ROLE, #candidates) do
            table.insert(options, { name = candidates[index], role = role })
        end
    end
    shuffle(options)
    return options
end

function AbilityDraftService:CreateOffer(playerID, slotIndex)
    local state = self:EnsurePlayer(playerID)
    local milestone = SLOT_MILESTONES[slotIndex]
    if not state or not milestone or state.abilities[slotIndex] or state.pending then return false end

    local options = self:BuildOffer(state, milestone.kind)
    if #options == 0 then return false end
    self:PrecacheOffer(options, playerID)

    self.sequence = self.sequence + 1
    state.pending = {
        sequence = self.sequence,
        slot = slotIndex,
        kind = milestone.kind,
        maxLevel = milestone.maxLevel,
        options = options,
        delivered = false,
        expiresAt = -1
    }
    self:Publish(playerID)
    self:SendPendingOffer(playerID)
    return true
end

function AbilityDraftService:SendPendingOffer(playerID)
    local state = self:EnsurePlayer(playerID)
    local pending = state and state.pending or nil
    if not pending then return end
    if pending.delivered and now() >= pending.expiresAt then
        self:ResolvePendingRandomly(playerID, pending.sequence)
        return
    end

    local player = PlayerResource:GetPlayer(playerID)
    if not player then return end
    local payload = {
        sequence = pending.sequence,
        slot = pending.slot,
        kind = pending.kind,
        duration = OFFER_DURATION,
        expires_at = pending.delivered and pending.expiresAt or (now() + OFFER_DURATION),
        option_count = #pending.options
    }
    for index, option in ipairs(pending.options) do
        payload["option_" .. index] = option.name
        payload["role_" .. index] = option.role
    end
    CustomGameEventManager:Send_ServerToPlayer(player, "ability_draft_offer", payload)
end

function AbilityDraftService:IsSystemAbility(abilityName)
    if not abilityName or abilityName == "" then return false end
    return string.sub(abilityName, 1, 17) == "convergence_perk_"
        or abilityName == "ability_home_bed_barrier"
end

function AbilityDraftService:StripNativeAbilities(hero, state)
    if not isDraftHero(hero) then return end
    state = state or self:EnsurePlayer(hero:GetPlayerOwnerID())
    local keep = self:GetOwnedSet(state)
    local remove = {}

    -- Current hero entities expose slots 0-18. Querying 19-23 produces a
    -- VScript warning on every spawn without finding additional abilities.
    for abilityIndex = 0, 18 do
        local ability = hero:GetAbilityByIndex(abilityIndex)
        if ability and not ability:IsNull() then
            local abilityName = ability:GetAbilityName()
            if abilityName and abilityName ~= ""
                and not keep[abilityName]
                and not self:IsSystemAbility(abilityName) then
                table.insert(remove, abilityName)
            end
        end
    end

    for _, abilityName in ipairs(remove) do
        hero:RemoveAbility(abilityName)
    end
end

function AbilityDraftService:ApplyToHero(hero)
    if not isDraftHero(hero) then return end
    local playerID = hero:GetPlayerOwnerID()
    local state = self:EnsurePlayer(playerID)
    self:StripNativeAbilities(hero, state)

    for _, entry in ipairs(state.abilities) do
        local ability = hero:FindAbilityByName(entry.name) or hero:AddAbility(entry.name)
        if ability and not ability:IsNull() then
            ability:SetLevel(math.max(0, math.min(entry.maxLevel, entry.level)))
            if ability.SetHidden then ability:SetHidden(false) end
        end
    end
end

function AbilityDraftService:GrantAbility(playerID, pending, abilityName)
    local state = self:EnsurePlayer(playerID)
    if not state or not pending or state.abilities[pending.slot] then return false end

    local offered = false
    local selectedRole = pending.kind == "ultimate" and "ultimate" or "basic"
    for _, option in ipairs(pending.options) do
        if option.name == abilityName then
            offered = true
            selectedRole = option.role
            break
        end
    end
    if not offered then return false end

    local hero = self:GetHero(playerID)
    if not isDraftHero(hero) then return false end
    local ability = hero:FindAbilityByName(abilityName) or hero:AddAbility(abilityName)
    if not ability or ability:IsNull() then return false end

    -- Drafting unlocks the spell without learning it. Hero levels provide the
    -- normal points and the player chooses every upgrade through the native HUD.
    ability:SetLevel(0)
    if ability.SetHidden then ability:SetHidden(false) end
    state.abilities[pending.slot] = {
        name = abilityName,
        kind = pending.kind,
        role = selectedRole,
        level = 0,
        maxLevel = pending.maxLevel
    }
    state.pending = nil
    local nextMilestone = SLOT_MILESTONES[pending.slot + 1]
    if nextMilestone then
        local currentMilestone = SLOT_MILESTONES[pending.slot]
        local interval = math.max(0, nextMilestone.time - currentMilestone.time)
        state.nextOfferAt = now() + interval
    else
        state.nextOfferAt = -1
    end
    self:Publish(playerID)

    local player = PlayerResource:GetPlayer(playerID)
    if player then
        CustomGameEventManager:Send_ServerToPlayer(player, "ability_draft_selected", {
            ability_name = abilityName,
            slot = pending.slot
        })
    end
    return true
end

function AbilityDraftService:ResolvePendingRandomly(playerID, sequence)
    local state = self:EnsurePlayer(playerID)
    local pending = state and state.pending or nil
    if not pending or pending.sequence ~= sequence then return false end

    local options = copyArray(pending.options)
    shuffle(options)
    for _, option in ipairs(options) do
        if self:GrantAbility(playerID, pending, option.name) then return true end
    end
    return false
end

function AbilityDraftService:SyncNativeProgress(playerID)
    local state = self:EnsurePlayer(playerID)
    local hero = self:GetHero(playerID)
    if not state or not isDraftHero(hero) then return end

    local changed = false
    for _, entry in ipairs(state.abilities) do
        local ability = hero:FindAbilityByName(entry.name)
        if ability and not ability:IsNull() then
            local level = math.max(0, math.min(entry.maxLevel, ability:GetLevel()))
            if entry.level ~= level then
                entry.level = level
                changed = true
            end
        end
    end

    if changed then self:Publish(playerID) end
end

function AbilityDraftService:GetNextSlot(state)
    if not state then return nil end
    for slotIndex = 1, #SLOT_MILESTONES do
        if not state.abilities[slotIndex] then return slotIndex end
    end
    return nil
end

function AbilityDraftService:UpdateLevelTimer(playerID)
    local state = self:EnsurePlayer(playerID)
    local hero = self:GetHero(playerID)
    if not state or not isDraftHero(hero) then return false end

    local currentLevel = math.max(1, tonumber(hero:GetLevel()) or 1)
    if state.lastHeroLevel == nil then
        state.lastHeroLevel = currentLevel
        return false
    end
    if currentLevel < state.lastHeroLevel then
        state.lastHeroLevel = currentLevel
        return false
    end

    local levelsGained = currentLevel - state.lastHeroLevel
    state.lastHeroLevel = currentLevel
    if levelsGained <= 0 or state.pending then return false end
    if not state.nextOfferAt or state.nextOfferAt < 0 then return false end

    state.nextOfferAt = math.max(now(), state.nextOfferAt - levelsGained * LEVEL_TIMER_REDUCTION)
    return true
end

function AbilityDraftService:Publish(playerID)
    local state = self.players and self.players[playerID]
    if not state then return end
    local hero = self:GetHero(playerID)
    local nextSlot = self:GetNextSlot(state)
    local data = {
        points = hero and hero.GetAbilityPoints and hero:GetAbilityPoints() or 0,
        ability_count = #state.abilities,
        pending = state.pending and 1 or 0,
        next_slot = nextSlot or 0,
        next_unlock_at = (not state.pending and nextSlot and state.nextOfferAt) or -1,
        level_timer_reduction = LEVEL_TIMER_REDUCTION
    }
    for slotIndex = 1, #SLOT_MILESTONES do
        local entry = state.abilities[slotIndex]
        if entry then
            data["ability_" .. slotIndex] = {
                name = entry.name,
                kind = entry.kind,
                level = entry.level,
                max_level = entry.maxLevel
            }
        else
            data["ability_" .. slotIndex] = {
                name = "",
                kind = SLOT_MILESTONES[slotIndex].kind,
                level = 0,
                max_level = SLOT_MILESTONES[slotIndex].maxLevel,
                unlock_at = SLOT_MILESTONES[slotIndex].time
            }
        end
    end
    CustomNetTables:SetTableValue("ability_draft", tostring(playerID), data)
end

function AbilityDraftService:StartMatch()
    if self.matchStarted then return end
    self.matchStarted = true
    for playerID = 0, DOTA_MAX_PLAYERS - 1 do
        if validPlayerID(playerID) and ModeConfig.IsPlayableTeam(PlayerResource:GetTeam(playerID)) then
            local state = self:EnsurePlayer(playerID)
            local hero = self:GetHero(playerID)
            self:ApplyToHero(hero)
            if hero and not hero:IsNull() then state.lastHeroLevel = hero:GetLevel() end
            self:Publish(playerID)
            if not state.abilities[1] and not state.pending then self:CreateOffer(playerID, 1) end
        end
    end
end

function AbilityDraftService:Think()
    if GameRules:State_Get() >= DOTA_GAMERULES_STATE_POST_GAME then return nil end
    if GameRules:State_Get() ~= DOTA_GAMERULES_STATE_GAME_IN_PROGRESS then return THINK_INTERVAL end
    if not self.matchStarted then self:StartMatch() end

    local matchTime = now()
    for playerID = 0, DOTA_MAX_PLAYERS - 1 do
        if validPlayerID(playerID) and ModeConfig.IsPlayableTeam(PlayerResource:GetTeam(playerID)) then
            local state = self:EnsurePlayer(playerID)
            if self:UpdateLevelTimer(playerID) then self:Publish(playerID) end
            self:SyncNativeProgress(playerID)

            if state.pending and state.pending.delivered and matchTime >= state.pending.expiresAt then
                self:ResolvePendingRandomly(playerID, state.pending.sequence)
            end
            if not state.pending then
                local nextSlot = self:GetNextSlot(state)
                if nextSlot and matchTime >= (state.nextOfferAt or 0) then
                    self:CreateOffer(playerID, nextSlot)
                end
            end
        end
    end
    return THINK_INTERVAL
end

function AbilityDraftService:OnStateChange()
    if GameRules:State_Get() == DOTA_GAMERULES_STATE_GAME_IN_PROGRESS then self:StartMatch() end
end

function AbilityDraftService:OnNPCSpawned(event)
    if not event or not event.entindex then return end
    local hero = EntIndexToHScript(event.entindex)
    if not isDraftHero(hero) then return end
    self:ApplyToHero(hero)
    self:Publish(hero:GetPlayerOwnerID())
end

function AbilityDraftService:OnPlayerLearnedAbility(event)
    local playerID = tonumber(event and (event.player_id or event.PlayerID))
    if not validPlayerID(playerID) then return end
    Timers:CreateTimer(0, function() self:SyncNativeProgress(playerID) end)
end

function AbilityDraftService:OnPlayerConnected(event)
    local playerID = tonumber(event and event.PlayerID)
    if not validPlayerID(playerID) then return end
    self:EnsurePlayer(playerID)
    Timers:CreateTimer(0.25, function()
        self:ApplyToHero(self:GetHero(playerID))
        self:Publish(playerID)
        self:SendPendingOffer(playerID)
    end)
end

function AbilityDraftService:OnChoose(source, data)
    local playerID = playerIDFromEvent(source, data)
    if not validPlayerID(playerID) then return end
    local state = self:EnsurePlayer(playerID)
    local pending = state and state.pending or nil
    if not pending or pending.sequence ~= (tonumber(data and data.sequence) or -1) then return end
    local abilityName = tostring(data and data.ability_name or "")
    if not self:GrantAbility(playerID, pending, abilityName) then
        local player = PlayerResource:GetPlayer(playerID)
        if player then
            CustomGameEventManager:Send_ServerToPlayer(player, "ability_draft_error", { code = "grant_failed" })
        end
    end
end

function AbilityDraftService:OnOfferSeen(source, data)
    local playerID = playerIDFromEvent(source, data)
    if not validPlayerID(playerID) then return end
    local state = self:EnsurePlayer(playerID)
    local pending = state and state.pending or nil
    if not pending or pending.sequence ~= (tonumber(data and data.sequence) or -1) then return end
    if pending.delivered then return end

    pending.delivered = true
    pending.expiresAt = now() + OFFER_DURATION
    self:Publish(playerID)

    local expectedSequence = pending.sequence
    Timers:CreateTimer(OFFER_DURATION + 0.05, function()
        local current = self.players and self.players[playerID]
        local currentPending = current and current.pending or nil
        if currentPending and currentPending.delivered and currentPending.sequence == expectedSequence then
            self:ResolvePendingRandomly(playerID, expectedSequence)
        end
    end)
end

function AbilityDraftService:OnRequestContext(source, data)
    local playerID = playerIDFromEvent(source, data)
    if not validPlayerID(playerID) then return end
    local state = self:EnsurePlayer(playerID)
    self:Publish(playerID)
    if self.matchStarted and state and not state.pending then
        local matchTime = now()
        local nextSlot = self:GetNextSlot(state)
        if nextSlot and matchTime >= (state.nextOfferAt or 0) then
            self:CreateOffer(playerID, nextSlot)
            return
        end
    end
    self:SendPendingOffer(playerID)
end

return AbilityDraftService
