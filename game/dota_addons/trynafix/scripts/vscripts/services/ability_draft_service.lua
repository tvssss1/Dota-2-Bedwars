local ModeConfig = require("settings/mode_config")

if AbilityDraftService == nil then
    AbilityDraftService = class({})
end

local OFFER_DURATION = 18
local THINK_INTERVAL = 0.25
local LEVEL_TIMER_REDUCTION = 20
local BASIC_OPTIONS_PER_ROLE = 3
local MAX_NATIVE_OPTIONS = 9

-- Ability acquisition and Convergence are deliberately independent systems.
-- These offers are guaranteed by match time; shrine captures continue to
-- grant only Convergence perks through PerkService.
local SLOT_MILESTONES = {
    { time = 0,   kind = "native_basic", maxLevel = 4 },
    { time = 180, kind = "basic",        maxLevel = 4 },
    { time = 360, kind = "basic",        maxLevel = 4 },
    { time = 480, kind = "basic",        maxLevel = 4 }
}
local NATIVE_ULTIMATE_SLOT = #SLOT_MILESTONES + 1

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

local BASIC_ROLES = { "offense", "control", "survival" }

-- Some heroes expose implementation abilities in npc_heroes.txt instead of a
-- set of independent spells. Treat those kits as a unit rather than putting
-- buttons such as "stop", "return" or Kez's empty stance switch in the pool.
local INVOKER_HERO = "npc_dota_hero_invoker"
local INVOKER_ORBS = { "invoker_quas", "invoker_wex", "invoker_exort" }
local INVOKER_ORB_SET = { invoker_quas = true, invoker_wex = true, invoker_exort = true }
local INVOKER_SUPPORTS = {
    "invoker_quas",
    "invoker_wex",
    "invoker_exort",
    "invoker_empty1",
    "invoker_empty2"
}
local INVOKER_SPELLS = {
    "invoker_cold_snap",
    "invoker_ghost_walk",
    "invoker_tornado",
    "invoker_emp",
    "invoker_alacrity",
    "invoker_chaos_meteor",
    "invoker_sun_strike",
    "invoker_forge_spirit",
    "invoker_ice_wall",
    "invoker_deafening_blast"
}

local KEZ_HERO = "npc_dota_hero_kez"
local KEZ_SWITCH_ABILITY = "kez_switch_weapons"
local KEZ_BASIC_PAIRS = {
    kez_echo_slash = "kez_falcon_rush",
    kez_grappling_claw = "kez_talon_toss",
    kez_kazurai_katana = "kez_shodo_sai"
}
local KEZ_NATIVE_BASICS = {
    "kez_echo_slash",
    "kez_grappling_claw",
    "kez_kazurai_katana"
}
local KEZ_PRIMARY_ULTIMATE = "kez_raptor_dance"
local KEZ_ALTERNATE_ULTIMATE = "kez_ravens_veil"

local SPECIAL_KIT_ABILITIES = {
    invoker_quas = true,
    invoker_wex = true,
    invoker_exort = true,
    invoker_invoke = true,
    invoker_empty1 = true,
    invoker_empty2 = true,
    kez_switch_weapons = true,
    kez_shodo_sai_parry_cancel = true
}
local INVOKER_SPELL_SET = {}
for _, abilityName in ipairs(INVOKER_SPELLS) do
    INVOKER_SPELL_SET[abilityName] = true
    SPECIAL_KIT_ABILITIES[abilityName] = true
end
for _, alternateName in pairs(KEZ_BASIC_PAIRS) do
    SPECIAL_KIT_ABILITIES[alternateName] = true
end
SPECIAL_KIT_ABILITIES[KEZ_PRIMARY_ULTIMATE] = true
SPECIAL_KIT_ABILITIES[KEZ_ALTERNATE_ULTIMATE] = true

-- These are secondary command buttons. They only do something while their
-- owning spell is active, so drafting one by itself can never be useful.
local UNDRAFTABLE_HELPER_ABILITIES = {
    ancient_apparition_ice_blast_release = true,
    bane_nightmare_end = true,
    brewmaster_primal_split_cancel = true,
    dawnbreaker_converge = true,
    elder_titan_return_spirit = true,
    ember_spirit_activate_fire_remnant = true,
    hoodwink_sharpshooter_release = true,
    keeper_of_the_light_illuminate_end = true,
    kunkka_return = true,
    life_stealer_consume = true,
    lone_druid_spirit_bear_return = true,
    monkey_king_primal_spring = true,
    monkey_king_primal_spring_early = true,
    monkey_king_untransform = true,
    naga_siren_song_of_the_siren_cancel = true,
    nyx_assassin_unburrow = true,
    pangolier_gyroshell_stop = true,
    phoenix_icarus_dive_stop = true,
    phoenix_sun_ray_stop = true,
    phoenix_sun_ray_toggle_move = true,
    primal_beast_onslaught_release = true,
    puck_ethereal_jaunt = true,
    pudge_eject = true,
    ringmaster_tame_the_beasts_crack = true,
    rubick_empty1 = true,
    rubick_empty2 = true,
    rubick_telekinesis_land = true,
    rubick_telekinesis_land_self = true,
    sandking_burrowstrike_secondary = true,
    shadow_demon_shadow_poison_release = true,
    shredder_return_chakram = true,
    shredder_return_chakram_2 = true,
    snapfire_spit_creep = true,
    spectre_reality = true,
    techies_reactive_tazer_stop = true,
    templar_assassin_trap_teleport = true,
    tiny_toss_tree = true,
    tusk_launch_snowball = true,
    wisp_tether_break = true,
    wisp_spirits_in = true,
    wisp_spirits_out = true
}

local DRAFT_ABILITY_SUPPORTS = {
    ancient_apparition_ice_blast = { "ancient_apparition_ice_blast_release" },
    bane_nightmare = { "bane_nightmare_end" },
    brewmaster_primal_split = { "brewmaster_primal_split_cancel" },
    dawnbreaker_celestial_hammer = { "dawnbreaker_converge" },
    elder_titan_ancestral_spirit = { "elder_titan_return_spirit" },
    ember_spirit_fire_remnant = { "ember_spirit_activate_fire_remnant" },
    hoodwink_sharpshooter = { "hoodwink_sharpshooter_release" },
    keeper_of_the_light_illuminate = { "keeper_of_the_light_illuminate_end" },
    kunkka_x_marks_the_spot = { "kunkka_return" },
    life_stealer_infest = { "life_stealer_consume" },
    monkey_king_tree_dance = { "monkey_king_primal_spring", "monkey_king_primal_spring_early" },
    monkey_king_mischief = { "monkey_king_untransform" },
    naga_siren_song_of_the_siren = { "naga_siren_song_of_the_siren_cancel" },
    nyx_assassin_burrow = { "nyx_assassin_unburrow" },
    pangolier_gyroshell = { "pangolier_gyroshell_stop" },
    phoenix_icarus_dive = { "phoenix_icarus_dive_stop" },
    phoenix_sun_ray = { "phoenix_sun_ray_stop", "phoenix_sun_ray_toggle_move" },
    primal_beast_onslaught = { "primal_beast_onslaught_release" },
    puck_illusory_orb = { "puck_ethereal_jaunt" },
    pudge_dismember = { "pudge_eject" },
    ringmaster_tame_the_beasts = { "ringmaster_tame_the_beasts_crack" },
    rubick_telekinesis = { "rubick_telekinesis_land", "rubick_telekinesis_land_self" },
    sandking_burrowstrike = { "sandking_burrowstrike_secondary" },
    shadow_demon_shadow_poison = { "shadow_demon_shadow_poison_release" },
    shredder_chakram = { "shredder_return_chakram" },
    shredder_chakram_2 = { "shredder_return_chakram_2" },
    snapfire_gobble_up = { "snapfire_spit_creep" },
    spectre_haunt = { "spectre_reality" },
    techies_reactive_tazer = { "techies_reactive_tazer_stop" },
    templar_assassin_psionic_trap = { "templar_assassin_trap_teleport" },
    tiny_tree_grab = { "tiny_toss_tree" },
    tusk_snowball = { "tusk_launch_snowball" },
    wisp_tether = { "wisp_tether_break" },
    wisp_spirits = { "wisp_spirits_in", "wisp_spirits_out" }
}
for primaryName, alternateName in pairs(KEZ_BASIC_PAIRS) do
    DRAFT_ABILITY_SUPPORTS[primaryName] = { alternateName, KEZ_SWITCH_ABILITY }
end
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
    if SPECIAL_KIT_ABILITIES[lowerName]
        or UNDRAFTABLE_HELPER_ABILITIES[lowerName]
        or (self.dynamicHelperAbilities and self.dynamicHelperAbilities[lowerName]) then return false end
    if lowerName == "attribute_bonus" or lowerName == "generic_hidden" then return false end
    if string.find(lowerName, "special_bonus", 1, true) then return false end
    if string.find(lowerName, "empty", 1, true) then return false end
    if string.find(lowerName, "ability_capture", 1, true) then return false end

    local behavior = string.upper(tostring(type(abilityData) == "table" and abilityData.AbilityBehavior or ""))
    local abilityType = string.upper(tostring(type(abilityData) == "table" and abilityData.AbilityType or ""))
    if string.find(behavior, "HIDDEN", 1, true) then return false end
    if string.find(behavior, "NOT_LEARNABLE", 1, true) then return false end
    if string.find(behavior, "INNATE", 1, true) then return false end
    if string.find(abilityType, "INNATE", 1, true) then return false end
    if kvFlag(abilityData, "Innate")
        or kvFlag(abilityData, "IsInnate")
        or kvFlag(abilityData, "AbilityIsInnate") then return false end
    if kvFlag(abilityData, "AbilityDraftDisabled") or kvFlag(abilityData, "ADDisabled") then return false end
    if kvFlag(abilityData, "IsGrantedByScepter") or kvFlag(abilityData, "IsGrantedByShard") then return false end
    return true
end

function AbilityDraftService:ClassifyBasicAbility(abilityName)
    if containsAny(abilityName, SURVIVAL_HINTS) then return "survival" end
    if containsAny(abilityName, CONTROL_HINTS) then return "control" end
    return "offense"
end

function AbilityDraftService:GetAbilityData(abilityName)
    local abilityData = nil
    if type(GetAbilityKeyValuesByName) == "function" then
        abilityData = GetAbilityKeyValuesByName(abilityName)
    end
    if type(abilityData) ~= "table" and type(self.allAbilityKVs) == "table" then
        abilityData = self.allAbilityKVs[abilityName]
    end
    return abilityData
end

function AbilityDraftService:IsUltimateAbility(abilityData, slotIndex)
    local abilityType = string.upper(tostring(type(abilityData) == "table" and abilityData.AbilityType or ""))
    if string.find(abilityType, "ULTIMATE", 1, true) then return true end
    return abilityType == "" and tonumber(slotIndex) == 6
end

function AbilityDraftService:IsNativeUltimateCandidate(abilityName, abilityData, slotIndex)
    if type(abilityName) ~= "string" or abilityName == "" then return false end
    local lowerName = string.lower(abilityName)
    if lowerName == "attribute_bonus" or lowerName == "generic_hidden" then return false end
    if string.find(lowerName, "special_bonus", 1, true) then return false end
    if string.find(lowerName, "empty", 1, true) then return false end
    local behavior = string.upper(tostring(type(abilityData) == "table" and abilityData.AbilityBehavior or ""))
    local abilityType = string.upper(tostring(type(abilityData) == "table" and abilityData.AbilityType or ""))
    if string.find(behavior, "HIDDEN", 1, true) then return false end
    if string.find(behavior, "INNATE", 1, true) or string.find(abilityType, "INNATE", 1, true) then return false end
    if kvFlag(abilityData, "Innate")
        or kvFlag(abilityData, "IsInnate")
        or kvFlag(abilityData, "AbilityIsInnate") then return false end
    return self:IsUltimateAbility(abilityData, slotIndex)
end

function AbilityDraftService:BuildAbilityCatalog()
    self.basicPools = { offense = {}, control = {}, survival = {} }
    self.ultimatePool = {}
    self.abilitySources = {}
    self.precachedSourceHeroes = {}
    self.heroBasicAbilities = {}
    self.nativeUltimates = {}
    self.dynamicHelperAbilities = {}
    self.dynamicAbilitySupports = {}

    local heroes = unwrapKV(LoadKeyValues("scripts/npc/npc_heroes.txt"), "DOTAHeroes")
    local allAbilities = unwrapKV(LoadKeyValues("scripts/npc/npc_abilities.txt"), "DOTAAbilities")
    self.allAbilityKVs = allAbilities

    -- New heroes regularly add recast/secondary buttons. Consume Valve's
    -- association and Ability Draft pre/post metadata so future helper buttons
    -- are bundled with their parent without another hard-code.
    local function associate(primaryName, helperName, isExplicitAssociation)
        if type(primaryName) ~= "string" or primaryName == ""
            or type(helperName) ~= "string" or helperName == ""
            or SPECIAL_KIT_ABILITIES[helperName] then return end
        if not isExplicitAssociation and not UNDRAFTABLE_HELPER_ABILITIES[helperName] then
            local helperData = allAbilities[helperName]
            local behavior = string.upper(tostring(type(helperData) == "table" and helperData.AbilityBehavior or ""))
            if not string.find(behavior, "HIDDEN", 1, true)
                and not string.find(behavior, "NOT_LEARNABLE", 1, true) then return end
        end
        self.dynamicHelperAbilities[helperName] = true
        self.dynamicAbilitySupports[primaryName] = self.dynamicAbilitySupports[primaryName] or {}
        table.insert(self.dynamicAbilitySupports[primaryName], helperName)
    end
    local function visitNames(names, callback)
        if type(names) == "string" then
            for abilityName in string.gmatch(names, "[%w_]+") do callback(abilityName) end
        elseif type(names) == "table" then
            for key, value in pairs(names) do
                if type(value) == "string" then
                    callback(value)
                elseif type(key) == "string" then
                    callback(key)
                end
            end
        end
    end
    local function associateHelper(helperName, primaryNames)
        visitNames(primaryNames, function(primaryName) associate(primaryName, helperName, true) end)
    end
    local function associateSupports(primaryName, supportNames)
        visitNames(supportNames, function(helperName) associate(primaryName, helperName, false) end)
    end
    for abilityName, abilityData in pairs(allAbilities) do
        if type(abilityName) == "string" and type(abilityData) == "table" then
            associateHelper(abilityName, abilityData.AssociatedPrimaryAbilities)
            associateSupports(abilityName, abilityData.AbilityDraftPreAbility)
            associateSupports(abilityName, abilityData.AbilityDraftPostAbility)
        end
    end
    local seen = {}
    local heroSeen = {}

    local function addAbility(heroName, abilityName, slotIndex)
        local abilityData = self:GetAbilityData(abilityName)
        heroSeen[heroName] = heroSeen[heroName] or {}
        if heroSeen[heroName][abilityName] then return end
        heroSeen[heroName][abilityName] = true

        local numericSlot = tonumber(slotIndex) or 99
        local isUltimate = self:IsUltimateAbility(abilityData, numericSlot)
        if self:IsNativeUltimateCandidate(abilityName, abilityData, numericSlot) then
            local current = self.nativeUltimates[heroName]
            if not current or numericSlot < current.slot then
                self.nativeUltimates[heroName] = { name = abilityName, slot = numericSlot }
            end
        end

        if not self:IsDraftableAbility(abilityName, abilityData) then return end
        if not isUltimate then
            self.heroBasicAbilities[heroName] = self.heroBasicAbilities[heroName] or {}
            table.insert(self.heroBasicAbilities[heroName], { name = abilityName, slot = numericSlot })
        end

        if seen[abilityName] then return end
        seen[abilityName] = true
        self.abilitySources[abilityName] = heroName

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

    for heroName, abilities in pairs(self.heroBasicAbilities) do
        table.sort(abilities, function(left, right)
            if left.slot == right.slot then return left.name < right.name end
            return left.slot < right.slot
        end)
        local ordered = {}
        for _, entry in ipairs(abilities) do table.insert(ordered, entry.name) end
        self.heroBasicAbilities[heroName] = ordered
    end
    for heroName, entry in pairs(self.nativeUltimates) do
        self.nativeUltimates[heroName] = entry.name
    end

    -- Valve lists Invoker's orbs and Kez's currently active discipline in the
    -- normal hero slots. Replace those raw entries with useful draft choices,
    -- while keeping their required controls as support abilities at runtime.
    self.heroBasicAbilities[INVOKER_HERO] = copyArray(INVOKER_SPELLS)
    self.nativeUltimates[INVOKER_HERO] = "invoker_invoke"
    for _, abilityName in ipairs(INVOKER_SPELLS) do
        self.abilitySources[abilityName] = INVOKER_HERO
    end
    for _, abilityName in ipairs(INVOKER_ORBS) do
        self.abilitySources[abilityName] = INVOKER_HERO
    end
    self.abilitySources.invoker_empty1 = INVOKER_HERO
    self.abilitySources.invoker_empty2 = INVOKER_HERO
    self.abilitySources.invoker_invoke = INVOKER_HERO

    self.heroBasicAbilities[KEZ_HERO] = copyArray(KEZ_NATIVE_BASICS)
    self.nativeUltimates[KEZ_HERO] = KEZ_PRIMARY_ULTIMATE
    for _, primaryName in ipairs(KEZ_NATIVE_BASICS) do
        self.abilitySources[primaryName] = KEZ_HERO
        self.abilitySources[KEZ_BASIC_PAIRS[primaryName]] = KEZ_HERO
    end
    self.abilitySources[KEZ_SWITCH_ABILITY] = KEZ_HERO
    self.abilitySources[KEZ_PRIMARY_ULTIMATE] = KEZ_HERO
    self.abilitySources[KEZ_ALTERNATE_ULTIMATE] = KEZ_HERO

    local basicCount = #self.basicPools.offense + #self.basicPools.control + #self.basicPools.survival
    if basicCount < 9 then
        self.basicPools = BASIC_POOLS
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
            nativeBasicPool = {},
            nativeUltimate = nil,
            nativeHeroName = nil,
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

function AbilityDraftService:GetDraftSupportNames(abilityName)
    local result = {}
    local seen = {}
    local function append(values)
        for _, supportName in ipairs(values or {}) do
            if not seen[supportName] then
                seen[supportName] = true
                table.insert(result, supportName)
            end
        end
    end
    append(DRAFT_ABILITY_SUPPORTS[abilityName])
    append(self.dynamicAbilitySupports and self.dynamicAbilitySupports[abilityName])
    return result
end

function AbilityDraftService:GetDraftSupportLevel(abilityName, supportName, abilityLevel)
    if KEZ_BASIC_PAIRS[abilityName] == supportName then return abilityLevel end
    return 1
end

function AbilityDraftService:GetNativeSupportNames(heroName, ultimateName)
    local result = {}
    local seen = {}
    local function add(abilityName)
        if abilityName and not seen[abilityName] then
            seen[abilityName] = true
            table.insert(result, abilityName)
        end
    end
    if heroName == INVOKER_HERO then
        for _, abilityName in ipairs(INVOKER_SUPPORTS) do add(abilityName) end
    elseif heroName == KEZ_HERO then
        add(KEZ_ALTERNATE_ULTIMATE)
        add(KEZ_SWITCH_ABILITY)
    end
    for _, abilityName in ipairs(self:GetDraftSupportNames(ultimateName)) do add(abilityName) end
    return result
end

function AbilityDraftService:CaptureSupportAbility(hero, abilityName)
    local ability = hero and hero:FindAbilityByName(abilityName) or nil
    local isHelper = UNDRAFTABLE_HELPER_ABILITIES[abilityName]
        or (self.dynamicHelperAbilities and self.dynamicHelperAbilities[abilityName])
    local level = 0
    local maxLevel = 1
    local hidden = isHelper == true
    if ability and not ability:IsNull() then
        level = math.max(0, ability:GetLevel())
        if ability.GetMaxLevel then maxLevel = math.max(1, ability:GetMaxLevel()) end
        if ability.IsHidden then hidden = ability:IsHidden() end
        if INVOKER_ORB_SET[abilityName] and level == 0 then level = 1 end
        if isHelper and level == 0 then level = 1 end
    elseif abilityName == KEZ_SWITCH_ABILITY or isHelper then
        level = 1
    end
    return { name = abilityName, level = math.min(maxLevel, level), maxLevel = maxLevel, hidden = hidden }
end

function AbilityDraftService:AddTrackedAbility(hero, entry, forcedLevel)
    if not hero or hero:IsNull() or not entry or not entry.name then return nil end
    local ability = hero:FindAbilityByName(entry.name) or hero:AddAbility(entry.name)
    if not ability or ability:IsNull() then
        print("[AbilityDraft] Failed to add required ability " .. tostring(entry.name)
            .. " to " .. tostring(hero:GetUnitName()) .. ".")
        return nil
    end
    local maxLevel = entry.maxLevel or 1
    if ability.GetMaxLevel then maxLevel = math.max(1, ability:GetMaxLevel()) end
    local desiredLevel = forcedLevel
    if desiredLevel == nil then desiredLevel = entry.level or 0 end
    ability:SetLevel(math.max(0, math.min(maxLevel, desiredLevel)))
    if ability.SetHidden then ability:SetHidden(entry.hidden == true) end
    return ability
end

function AbilityDraftService:CacheNativeKit(hero, state)
    if not isDraftHero(hero) or not state then return end
    local heroName = hero:GetUnitName()
    local expectedUltimateName = self.nativeUltimates and self.nativeUltimates[heroName]
        or (state.nativeUltimate and state.nativeUltimate.name)
    local supportCount = state.nativeUltimate and #(state.nativeUltimate.supports or {}) or 0
    local expectedSupportCount = #self:GetNativeSupportNames(heroName, expectedUltimateName)
    if state.nativeHeroName == heroName
        and state.nativeUltimate
        and supportCount >= expectedSupportCount
        and #(state.nativeBasicPool or {}) > 0 then return end

    state.nativeHeroName = heroName
    state.nativeBasicPool = copyArray(self.heroBasicAbilities and self.heroBasicAbilities[heroName] or {})
    state.nativeUltimate = nil

    local nativeUltimateName = self.nativeUltimates and self.nativeUltimates[heroName] or nil
    local scannedBasics = {}
    for abilityIndex = 0, 18 do
        local ability = hero:GetAbilityByIndex(abilityIndex)
        if ability and not ability:IsNull() then
            local abilityName = ability:GetAbilityName()
            local abilityData = self:GetAbilityData(abilityName)
            local isInnate = ability.IsInnateAbility and ability:IsInnateAbility()
            if not isInnate then
                if self:IsNativeUltimateCandidate(abilityName, abilityData, abilityIndex + 1) then
                    nativeUltimateName = nativeUltimateName or abilityName
                elseif self:IsDraftableAbility(abilityName, abilityData) then
                    table.insert(scannedBasics, abilityName)
                end
            end
        end
    end
    if #state.nativeBasicPool == 0 then state.nativeBasicPool = scannedBasics end

    if nativeUltimateName then
        local ability = hero:FindAbilityByName(nativeUltimateName)
        local maxLevel = 3
        local level = 0
        if ability and not ability:IsNull() then
            level = math.max(0, ability:GetLevel())
            if ability.GetMaxLevel then maxLevel = math.max(1, ability:GetMaxLevel()) end
        end
        state.nativeUltimate = {
            name = nativeUltimateName,
            kind = "native_ultimate",
            role = "ultimate",
            level = math.min(maxLevel, level),
            maxLevel = maxLevel,
            supports = {}
        }
        for _, supportName in ipairs(self:GetNativeSupportNames(heroName, nativeUltimateName)) do
            table.insert(state.nativeUltimate.supports, self:CaptureSupportAbility(hero, supportName))
        end
    else
        print("[AbilityDraft] Could not find a native ultimate for " .. tostring(heroName) .. ".")
    end
end

function AbilityDraftService:GetOwnedSet(state)
    local owned = {}
    for _, entry in ipairs(state and state.abilities or {}) do
        owned[entry.name] = true
        for _, supportName in ipairs(self:GetDraftSupportNames(entry.name)) do
            owned[supportName] = true
        end
    end
    if state and state.nativeUltimate then
        owned[state.nativeUltimate.name] = true
        for _, support in ipairs(state.nativeUltimate.supports or {}) do
            owned[support.name] = true
        end
    end
    return owned
end

function AbilityDraftService:BuildOffer(state, kind, playerID)
    local owned = self:GetOwnedSet(state)
    local options = {}

    if kind == "native_basic" then
        self:CacheNativeKit(self:GetHero(playerID), state)
        for _, abilityName in ipairs(state.nativeBasicPool or {}) do
            if not owned[abilityName] then
                table.insert(options, {
                    name = abilityName,
                    role = self:ClassifyBasicAbility(abilityName)
                })
            end
        end
        if #options > MAX_NATIVE_OPTIONS then
            shuffle(options)
            while #options > MAX_NATIVE_OPTIONS do table.remove(options) end
        end
        if #options > 0 then return options end
        print("[AbilityDraft] Native basic pool unavailable; using the global pool for player " .. tostring(playerID) .. ".")
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

    local options = self:BuildOffer(state, milestone.kind, playerID)
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
    self:CacheNativeKit(hero, state)
    self:StripNativeAbilities(hero, state)

    for _, entry in ipairs(state.abilities) do
        self:AddTrackedAbility(hero, entry)
        for _, supportName in ipairs(self:GetDraftSupportNames(entry.name)) do
            local supportLevel = self:GetDraftSupportLevel(entry.name, supportName, entry.level)
            self:AddTrackedAbility(hero, {
                name = supportName,
                level = supportLevel,
                hidden = supportName ~= KEZ_SWITCH_ABILITY
            }, supportLevel)
        end
    end

    local nativeUltimate = state.nativeUltimate
    if nativeUltimate then
        self:AddTrackedAbility(hero, nativeUltimate)
        for _, support in ipairs(nativeUltimate.supports or {}) do
            self:AddTrackedAbility(hero, support)
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
    local actualMaxLevel = pending.maxLevel
    if ability.GetMaxLevel then actualMaxLevel = math.max(1, ability:GetMaxLevel()) end
    local maxLevel = math.max(1, math.min(pending.maxLevel, actualMaxLevel))
    -- Invoked spells are normally level-one, non-learnable abilities whose
    -- strength comes from Quas/Wex/Exort. Unlock the selected spell immediately;
    -- the retained orbs remain the progression and recipe controls for Invoke.
    local startingLevel = INVOKER_SPELL_SET[abilityName] and 1 or 0
    ability:SetLevel(math.min(maxLevel, startingLevel))
    if ability.SetHidden then ability:SetHidden(false) end
    local draftedEntry = {
        name = abilityName,
        kind = pending.kind,
        role = selectedRole,
        level = math.min(maxLevel, startingLevel),
        maxLevel = maxLevel
    }
    state.abilities[pending.slot] = draftedEntry
    for _, supportName in ipairs(self:GetDraftSupportNames(abilityName)) do
        local supportLevel = self:GetDraftSupportLevel(abilityName, supportName, draftedEntry.level)
        self:AddTrackedAbility(hero, {
            name = supportName,
            level = supportLevel,
            hidden = supportName ~= KEZ_SWITCH_ABILITY
        }, supportLevel)
    end
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
            local pairedName = KEZ_BASIC_PAIRS[entry.name]
            local pairedAbility = pairedName and hero:FindAbilityByName(pairedName) or nil
            if pairedAbility and not pairedAbility:IsNull() then
                level = math.max(level, math.min(entry.maxLevel, pairedAbility:GetLevel()))
                if ability:GetLevel() ~= level then ability:SetLevel(level) end
                if pairedAbility:GetLevel() ~= level then pairedAbility:SetLevel(level) end
            end
            if entry.level ~= level then
                entry.level = level
                changed = true
            end
        end
    end
    local nativeUltimate = state.nativeUltimate
    if nativeUltimate then
        local ability = hero:FindAbilityByName(nativeUltimate.name)
        if ability and not ability:IsNull() then
            local level = math.max(0, math.min(nativeUltimate.maxLevel, ability:GetLevel()))
            if state.nativeHeroName == KEZ_HERO then
                local alternate = hero:FindAbilityByName(KEZ_ALTERNATE_ULTIMATE)
                if alternate and not alternate:IsNull() then
                    level = math.max(level, math.min(nativeUltimate.maxLevel, alternate:GetLevel()))
                    if ability:GetLevel() ~= level then ability:SetLevel(level) end
                    if alternate:GetLevel() ~= level then alternate:SetLevel(level) end
                end
            end
            if nativeUltimate.level ~= level then
                nativeUltimate.level = level
                changed = true
            end
        end
        for _, support in ipairs(nativeUltimate.supports or {}) do
            local supportAbility = hero:FindAbilityByName(support.name)
            if supportAbility and not supportAbility:IsNull() then
                local supportLevel = math.max(0, math.min(support.maxLevel, supportAbility:GetLevel()))
                if support.level ~= supportLevel then
                    support.level = supportLevel
                    changed = true
                end
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
        ability_count = #state.abilities + (state.nativeUltimate and 1 or 0),
        drafted_ability_count = #state.abilities,
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
    local nativeUltimate = state.nativeUltimate
    data["ability_" .. NATIVE_ULTIMATE_SLOT] = nativeUltimate and {
        name = nativeUltimate.name,
        kind = nativeUltimate.kind,
        level = nativeUltimate.level,
        max_level = nativeUltimate.maxLevel,
        locked = 1
    } or {
        name = "",
        kind = "native_ultimate",
        level = 0,
        max_level = 3,
        locked = 1
    }
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
