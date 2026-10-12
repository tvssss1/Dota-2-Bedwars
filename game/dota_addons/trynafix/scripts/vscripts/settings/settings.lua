require("services/base_utils")
local MapLocations = require("settings/map_locations")
local ModeConfig = require("settings/mode_config")

if GameSetup == nil then
  GameSetup = class({})
end

function GameSetup:init()
    LinkLuaModifier("modifier_bushes_slow", "Modifiers/slow.lua", LUA_MODIFIER_MOTION_NONE)
    LinkLuaModifier("modifier_bushes_invise", "Modifiers/invise.lua", LUA_MODIFIER_MOTION_NONE)
    LinkLuaModifier("modifier_no_interaction", "Modifiers/modifier_no_interaction.lua", LUA_MODIFIER_MOTION_NONE)
    LinkLuaModifier("modifier_shopkeeper_interaction", "Modifiers/modifier_shopkeeper_interaction.lua", LUA_MODIFIER_MOTION_NONE)
    LinkLuaModifier("modifier_teleport_to_base", "Modifiers/modifier_teleport_to_base", LUA_MODIFIER_MOTION_NONE)
    LinkLuaModifier("modifier_spawn_purple_money","abilities/ability_purple_money.lua", LUA_MODIFIER_MOTION_NONE)
    LinkLuaModifier("modifier_pregame_stun", "Modifiers/modifier_pregame_stun.lua", LUA_MODIFIER_MOTION_NONE)
    LinkLuaModifier("modifier_structure_spell_immune", "Modifiers/modifier_structure_spell_immune.lua", LUA_MODIFIER_MOTION_NONE)
    LinkLuaModifier("modifier_bed_hit_points", "Modifiers/modifier_bed_hit_points.lua", LUA_MODIFIER_MOTION_NONE)
    LinkLuaModifier("modifier_bed_opening_protection", "Modifiers/modifier_bed_opening_protection.lua", LUA_MODIFIER_MOTION_NONE)
    LinkLuaModifier("modifier_bed_fow_reveal", "Modifiers/modifier_bed_fow_reveal.lua", LUA_MODIFIER_MOTION_NONE)
    LinkLuaModifier("modifier_bed_fountain_regen_aura", "Modifiers/modifier_bed_fountain_regen.lua", LUA_MODIFIER_MOTION_NONE)
    LinkLuaModifier("modifier_base_fountain_regen_aura", "Modifiers/modifier_bed_fountain_regen.lua", LUA_MODIFIER_MOTION_NONE)
    LinkLuaModifier("modifier_bed_fountain_regen", "Modifiers/modifier_bed_fountain_regen.lua", LUA_MODIFIER_MOTION_NONE)
    LinkLuaModifier("modifier_victory_pose", "Modifiers/modifier_victory_pose.lua", LUA_MODIFIER_MOTION_NONE)
    LinkLuaModifier("modifier_custom_item_stats", "Modifiers/modifier_custom_item_stats.lua", LUA_MODIFIER_MOTION_NONE)

    self.respawnDisabledTeams = self.respawnDisabledTeams or {}
    self.participatingTeams = self.participatingTeams or {}
    self.eliminatedTeams = self.eliminatedTeams or {}
    self.bedsByTeam = self.bedsByTeam or {}
    self.victoryStarted = false
    self.openingBedProtectionDuration = 120
    self.spectatorTeams = self.spectatorTeams or {}

    -- Use the same Bed Wars team palette for Dota's native overhead HP bars.
    -- This is team-wide engine state, so it automatically applies to initial
    -- hero spawns, respawns, illusions and other units owned by that team.
    local teamHealthbarColors = {
        [DOTA_TEAM_CUSTOM_1] = { 255, 45, 55 },  -- vivid red    #ff2d37
        [DOTA_TEAM_CUSTOM_2] = { 45, 125, 255 }, -- vivid blue   #2d7dff
        [DOTA_TEAM_CUSTOM_3] = { 35, 220, 85 },  -- vivid green  #23dc55
        [DOTA_TEAM_CUSTOM_4] = { 255, 145, 20 }  -- vivid orange #ff9114
    }
    for team, color in pairs(teamHealthbarColors) do
        SetTeamCustomHealthbarColor(team, color[1], color[2], color[3])
    end

    local bedDefinitions = {
        [DOTA_TEAM_CUSTOM_1] = { unit="npc_bed_red", point="ThroneSpawnPointOne" },
        [DOTA_TEAM_CUSTOM_2] = { unit="npc_bed_blue", point="ThroneSpawnPointTwo" },
        [DOTA_TEAM_CUSTOM_3] = { unit="npc_bed_green", point="ThroneSpawnPointThree" },
        [DOTA_TEAM_CUSTOM_4] = { unit="npc_bed_yellow", point="ThroneSpawnPointFour" }
    }
    local midCenter = MapLocations.GetMidCenter()
    -- The bed model's visual length axis is rotated 90 degrees from the
    -- unit's forward axis. Apply a model-space yaw correction after aiming
    -- the unit at mid.
    local bedModelYawOffset = -90
    for _, team in ipairs(ModeConfig.GetPlayableTeams()) do
        local definition = bedDefinitions[team]
        local point = Entities:FindByName(nil, definition.point)
        local bed = nil
        if point then
            local origin = GetGroundPosition(point:GetAbsOrigin(), point)
            -- Beds are immobile structures. Clear-space spawning can relocate
            -- them hundreds of units when their hull overlaps authored props.
            bed = CreateUnitByName(definition.unit, origin, false, nil, nil, team)
            if bed then
                bed:SetAbsOrigin(origin)
                bed:AddNewModifier(bed, nil, "modifier_structure_spell_immune", {})
                bed:AddNewModifier(bed, nil, "modifier_bed_hit_points", {})
                local facing = midCenter - origin
                facing.z = 0
                if facing:Length2D() > 0 then
                    local facingAngles = VectorToAngles(facing:Normalized())
                    bed:SetAngles(0, facingAngles.y + bedModelYawOffset, 0)
                end
            end
        end
        self:PublishBedState(team, bed ~= nil and not bed:IsNull())
        self.bedsByTeam[team] = bed
    end

    -- Healing belongs to the permanent team base, not to the destructible bed.
    self:CreateBaseAuras()

    -- Keep strategic areas visible without revealing the lanes and enemy
    -- bases. Duo vision is authored explicitly in Hammer. Resolve these
    -- entities on every refresh so moving/parenting a marker also moves vision.
    local duoVisionNames = { "VisionIsland1", "VisionIsland2", "VisionIsland3" }
    local function FindVisionOrigins(names)
        local origins = {}
        for _, name in ipairs(names) do
            local marker = Entities:FindByName(nil, name)
            if marker then table.insert(origins, marker:GetAbsOrigin()) end
        end
        return origins
    end

    local legacyMidVisionPoint = Entities:FindByName(nil, "VisionForAllTeams")
    local function GetMidVisionOrigin()
        if ModeConfig.IsDuo() then
            local marker = Entities:FindByName(nil, "MiddleVision")
            return marker and marker:GetAbsOrigin() or nil
        end
        return legacyMidVisionPoint and legacyMidVisionPoint:GetAbsOrigin()
            or MapLocations.GetMidCenter()
    end

    local function GetIslandVisionOrigins()
        if ModeConfig.IsDuo() then return FindVisionOrigins(duoVisionNames) end
        return MapLocations.GetSideIslandPositions()
    end

    local visionDuration = 30000
    local strategicVisionDuration = ModeConfig.IsDuo() and 6 or visionDuration
    local midVisionRadius = ModeConfig.IsDuo() and 1900 or 1600
    local baseVisionRadius = 1200
    local islandVisionRadius = ModeConfig.IsDuo() and 1750 or 1400
    for _, team in ipairs(ModeConfig.GetPlayableTeams()) do
        local midVisionOrigin = GetMidVisionOrigin()
        if midVisionOrigin then AddFOWViewer(team, midVisionOrigin, midVisionRadius, strategicVisionDuration, false) end
        -- All four shopkeepers are map-authored for Custom Team 4, which made
        -- their side-island vision exclusive to that team. Give every playing
        -- team the same persistent vision without exposing any enemy base.
        for _, islandPosition in ipairs(GetIslandVisionOrigins()) do
            AddFOWViewer(team, islandPosition, islandVisionRadius, strategicVisionDuration, false)
        end
        local basePosition = BaseUtils:GetTeamBasePosition(team)
        if basePosition then
            AddFOWViewer(team, basePosition, baseVisionRadius, visionDuration, false)
        end
    end
    -- The engine clears temporary FOW viewers during setup/state transitions.
    -- Refresh short viewers throughout the match so duo mid/side vision cannot
    -- silently disappear after being created during addon activation.
    GameRules:GetGameModeEntity():SetContextThink("StrategicVisionThink", function()
        if GameRules:State_Get() >= DOTA_GAMERULES_STATE_POST_GAME then return nil end
        for _, team in ipairs(ModeConfig.GetPlayableTeams()) do
            local midVisionOrigin = GetMidVisionOrigin()
            if midVisionOrigin then AddFOWViewer(team, midVisionOrigin, midVisionRadius, 6, false) end
            for _, islandPosition in ipairs(GetIslandVisionOrigins()) do
                AddFOWViewer(team, islandPosition, islandVisionRadius, 6, false)
            end
            local basePosition = BaseUtils:GetTeamBasePosition(team)
            if basePosition then AddFOWViewer(team, basePosition, baseVisionRadius, 6, false) end
        end
        return 5
    end, 0.1)

    -- BW_Solo is a four-player free-for-all: one player per bed/team.
    -- Keep this map-specific so other maps in the addon can define their own
    -- lobby layout without inheriting this four-player cap.
    GameRules:SetCustomGameTeamMaxPlayers(DOTA_TEAM_GOODGUYS, 0)
    GameRules:SetCustomGameTeamMaxPlayers(DOTA_TEAM_BADGUYS, 0)
    local capacity = ModeConfig.GetTeamCapacity()
    GameRules:SetCustomGameTeamMaxPlayers(DOTA_TEAM_CUSTOM_1, capacity)
    GameRules:SetCustomGameTeamMaxPlayers(DOTA_TEAM_CUSTOM_2, capacity)
    GameRules:SetCustomGameTeamMaxPlayers(DOTA_TEAM_CUSTOM_3, capacity)
    GameRules:SetCustomGameTeamMaxPlayers(DOTA_TEAM_CUSTOM_4, ModeConfig.IsDuo() and 0 or capacity)

    GameRules:SetStartingGold(600)
    GameRules:SetGoldTickTime(1.0)
    GameRules:SetGoldPerTick(2)
    -- Native auto-launch recalculates its transition deadline when a player
    -- changes teams. The game uses one server-owned, immutable deadline below.
    GameRules:EnableCustomGameSetupAutoLaunch(false)
    GameRules:SetHeroSelectionTime(20)
    GameRules:SetStrategyTime(15)
    GameRules:SetPreGameTime(5)
    GameRules:SetShowcaseTime(0)
    GameRules:SetPostGameTime(5)

    local GameMode = GameRules:GetGameModeEntity()
    GameMode:SetRecommendedItemsDisabled(false)
    -- Drive the lighting from match time below so both Bed Wars maps always
    -- use an exact five-minute day / five-minute night cycle.
    GameMode:SetDaynightCycleDisabled(true)
    -- Enable the stock Dota HUD controls for custom games. Without explicit
    -- cooldowns the Glyph and Scan buttons are present, but their orders are
    -- not initialized reliably for custom teams.
    GameMode:SetCustomGlyphCooldown(300)
    GameMode:SetCustomScanCooldown(210)
    -- Let the engine own the normal five-second respawn timer. Besides being
    -- authoritative, this keeps the HUD countdown and native respawn sound on
    -- the same schedule. Aegis reincarnation remains an engine-owned 5s flow.
    self.respawnTime = 5
    GameMode:SetFixedRespawnTime(self.respawnTime)
    GameMode:SetExecuteOrderFilter(Dynamic_Wrap(self, "StructureSpellOrderFilter"), self)
    GameMode:SetDamageFilter(Dynamic_Wrap(self, "BedFriendlyDamageFilter"), self)

    GameRules:SetCustomGameAllowHeroPickMusic(false)
    GameRules:SetCustomGameAllowMusicAtGameStart(false)
    GameRules:SetCustomGameAllowBattleMusic(false)

    GameRules:SetSameHeroSelectionEnabled(false)

    if forceHero ~= nil then
      GameMode:SetCustomGameForceHero(forceHero)
    end

    ListenToGameEvent("game_rules_state_change", Dynamic_Wrap(self, "OnStateChange"), self)
    ListenToGameEvent("npc_spawned", Dynamic_Wrap(self, "OnNPCSpawned"), self)

    -- IMPORTANT: bed death + hero death enforcement
    ListenToGameEvent("entity_killed", Dynamic_Wrap(self, "OnEntityKilled"), self)

    self.pregameSequence = 0
    GameRules:GetGameModeEntity():SetContextThink("PregameCountdownThink", function()
        return self:PregameCountdownThink()
    end, 0.05)

    if IsInToolsMode and IsInToolsMode() then
        Convars:RegisterCommand("trynafix_debug_victory", function(_, teamArgument)
            if self.victoryStarted then return end
            local team = tonumber(teamArgument)
            if not ModeConfig.IsPlayableTeam(team) then
                local host = PlayerResource:GetPlayer(0)
                local hero = host and host:GetAssignedHero() or nil
                team = hero and hero:GetTeamNumber() or DOTA_TEAM_CUSTOM_1
            end
            self:BeginVictorySequence(team)
        end, "Preview the victory cutscene. Optional team id: 6, 7, 8, or 9.", FCVAR_CHEAT)
    end
end

function GameSetup:StructureSpellOrderFilter(order)
    if not order then return true end

    -- Let the registered player courier reroute Valve's Deliver/Return binds
    -- through this mode's permanent bases and reject absent-shop actions.
    if CustomCourierService and CustomCourierService:OnExecuteOrder(order) == false then
        return false
    end

    -- Glyph is a native team order, but these custom beds use a scripted
    -- hit-count health system. Apply Dota's own fortification modifier to the
    -- issuing custom team's bed as well, then let the engine handle the normal
    -- team cooldown, HUD state, sounds, and any other allied structures.
    if order.order_type == DOTA_UNIT_ORDER_GLYPH then
        local playerID = tonumber(order.issuer_player_id_const)
        local team = playerID and playerID >= 0 and PlayerResource:GetTeam(playerID) or nil
        local bed = team and self.bedsByTeam and self.bedsByTeam[team] or nil
        if ModeConfig.IsPlayableTeam(team) and bed and not bed:IsNull() and bed:IsAlive() then
            bed:AddNewModifier(bed, nil, "modifier_fountain_glyph", { duration = 7 })
        end
        return true
    end

    -- Engine-side buyback flags are reinforced by rejecting the order itself.
    -- This also covers a hero who was already dead when their bed fell.
    if order.order_type == DOTA_UNIT_ORDER_BUYBACK then
        local playerID = tonumber(order.issuer_player_id_const)
        local team = playerID and playerID >= 0 and PlayerResource:GetTeam(playerID) or nil
        return not (team and self.respawnDisabledTeams[team])
    end

    local targetIndex = tonumber(order.entindex_target)
    local target = targetIndex and EntIndexToHScript(targetIndex) or nil
    if not target or target:IsNull() or not target.GetUnitName then return true end

    local bedUnits = {
        npc_bed_red = true,
        npc_bed_blue = true,
        npc_bed_green = true,
        npc_bed_yellow = true
    }

    -- Reject the command itself so allies do not even play an attack against
    -- their own bed. The damage filter below remains the authoritative guard
    -- for forced attacks, scripted damage, and orders issued outside the UI.
    if order.order_type == DOTA_UNIT_ORDER_ATTACK_TARGET and bedUnits[target:GetUnitName()] then
        for _, unitIndex in pairs(order.units or {}) do
            local attacker = EntIndexToHScript(tonumber(unitIndex) or -1)
            if attacker and not attacker:IsNull() and attacker:GetTeamNumber() == target:GetTeamNumber() then
                return false
            end
        end
        return true
    end

    if order.order_type ~= DOTA_UNIT_ORDER_CAST_TARGET then return true end

    local protectedStructures = {
        npc_bed_red = true,
        npc_bed_blue = true,
        npc_bed_green = true,
        npc_bed_yellow = true,
        shop_keeper_custom_first = true,
        npc_custom_tower = true
    }
    local undominatableBosses = {
        npc_island_miniboss = true,
        npc_custom_roshan = true
    }

    local abilityIndex = tonumber(order.entindex_ability)
    local ability = abilityIndex and EntIndexToHScript(abilityIndex) or nil
    local abilityName = ability and not ability:IsNull() and ability:GetAbilityName() or ""
    if undominatableBosses[target:GetUnitName()] then
        local dominationAbilities = {
            item_helm_of_the_dominator = true,
            item_helm_of_the_overlord = true,
            chen_holy_persuasion = true,
            enchantress_enchant = true
        }
        return dominationAbilities[abilityName] ~= true
    end

    if not protectedStructures[target:GetUnitName()] then return true end
    local allowedInteractions = {
        item_bed_raiders = true
    }
    return allowedInteractions[abilityName] == true
end

function GameSetup:CreateBaseAuras()
    self.baseRegenRadius = 700
    -- A nil-caster aura thinker can lose its friendly-team relationship after
    -- a custom-team structure dies. Maintain the buff directly from permanent
    -- info_player_start_dota positions, which are independent of every bed.
    GameRules:GetGameModeEntity():SetContextThink("PermanentBaseRegenThink", function()
        return self:PermanentBaseRegenThink()
    end, 0.1)
end

function GameSetup:PermanentBaseRegenThink()
    if GameRules:State_Get() >= DOTA_GAMERULES_STATE_POST_GAME then return nil end

    -- Ward-style custom units are not guaranteed to reach entity_killed on all
    -- engine builds. The lethal-hit modifier reports destruction directly, and
    -- this reference check is the final fallback if the unit vanished by some
    -- other script or engine operation.
    for _, team in ipairs(ModeConfig.GetPlayableTeams()) do
        local bed = self.bedsByTeam[team]
        if bed and not self.respawnDisabledTeams[team]
            and (bed:IsNull() or not bed:IsAlive()) then
            self:HandleBedDestroyed(team)
        end
    end

    for playerID = 0, DOTA_MAX_PLAYERS - 1 do
        if PlayerResource:IsValidPlayerID(playerID) then
            local hero = PlayerResource:GetSelectedHeroEntity(playerID)
            if (not hero) or hero:IsNull() then
                local player = PlayerResource:GetPlayer(playerID)
                hero = player and player:GetAssignedHero() or nil
            end

            if hero and not hero:IsNull() then
                local team = hero:GetTeamNumber()
                local isCustomTeam = ModeConfig.IsPlayableTeam(team)

                -- Keep dead heroes permanently locked, but never put the
                -- respawn-disabled engine state on a living hero: that state
                -- also blocks inventory and pickup orders.
                if self.respawnDisabledTeams[team] then
                    if hero:IsAlive() then
                        self:MaintainLivingHeroAfterBedLoss(hero)
                    elseif not self:IsHeroReincarnating(hero) then
                        self:ApplyRespawnLock(hero)
                    end
                end

                local nearBase = hero:IsAlive() and isCustomTeam
                    and BaseUtils:IsNearTeamBase(hero, self.baseRegenRadius)
                local isDebugHero = IsInToolsMode and IsInToolsMode()
                    and RandomDraftService and RandomDraftService.IsDebugHero
                    and RandomDraftService:IsDebugHero(hero)
                local shouldHaveRegen = nearBase and not isDebugHero
                local hasRegen = hero:HasModifier("modifier_bed_fountain_regen")

                -- Add and remove only on boundary transitions. Giving this
                -- visible modifier a short refreshed duration made its HUD icon
                -- and overhead effect visibly blink on every watchdog tick.
                if shouldHaveRegen and not hasRegen then
                    hero:AddNewModifier(hero, nil, "modifier_bed_fountain_regen", {})
                elseif not shouldHaveRegen and hasRegen then
                    hero:RemoveModifierByName("modifier_bed_fountain_regen")
                end
            end
        end
    end

    -- Eliminated teams keep their original team assignment so scoreboards,
    -- victory detection and duo membership remain stable. Refreshing a large,
    -- unobstructed viewer gives their permanently dead players observer-like
    -- full-map vision while retaining normal dead-player camera/selection.
    for team in pairs(self.spectatorTeams or {}) do
        AddFOWViewer(team, MapLocations.GetMidCenter(), 50000, 1.5, false)
    end

    -- Event callbacks handle the normal path, while this lightweight watchdog
    -- closes races where a bed and the final teammate die on the same frame.
    self:CheckForVictory()
    return 0.25
end

function GameSetup:IsBed(unit)
    if not unit or unit:IsNull() or not unit.GetUnitName then return false end
    local name = unit:GetUnitName()
    return name == "npc_bed_red" or name == "npc_bed_blue"
        or name == "npc_bed_green" or name == "npc_bed_yellow"
end

function GameSetup:GetOpeningBedProtectionRemaining()
    local elapsed = math.max(0, GameRules:GetDOTATime(false, false))
    return math.max(0, (self.openingBedProtectionDuration or 90) - elapsed)
end

function GameSetup:ApplyOpeningBedProtection()
    local remaining = self:GetOpeningBedProtectionRemaining()
    if remaining <= 0 then return end

    for _, bed in pairs(self.bedsByTeam or {}) do
        if bed and not bed:IsNull() and bed:IsAlive()
            and not bed:HasModifier("modifier_bed_opening_protection") then
            bed:AddNewModifier(bed, nil, "modifier_bed_opening_protection", {
                duration = remaining
            })
        end
    end
end

function GameSetup:RevealBedToViewerTeam(bed, viewer)
    if not self:IsBed(bed) or not viewer or viewer:IsNull() then return end
    local team = viewer:GetTeamNumber()
    if not ModeConfig.IsPlayableTeam(team) then return end

    bed._trynafixFOWTeams = bed._trynafixFOWTeams or {}
    if bed._trynafixFOWTeams[team] then return end
    local modifier = bed:AddNewModifier(viewer, nil, "modifier_bed_fow_reveal", {})
    if modifier then bed._trynafixFOWTeams[team] = true end
end

function GameSetup:RevealAllBedsToViewer(viewer)
    for _, bed in pairs(self.bedsByTeam or {}) do
        if bed and not bed:IsNull() and bed:IsAlive() then
            self:RevealBedToViewerTeam(bed, viewer)
        end
    end
end

function GameSetup:RevealBedToAllTeams(bed)
    for playerID = 0, DOTA_MAX_PLAYERS - 1 do
        if PlayerResource:IsValidPlayerID(playerID) then
            local hero = PlayerResource:GetSelectedHeroEntity(playerID)
            if hero and not hero:IsNull() then self:RevealBedToViewerTeam(bed, hero) end
        end
    end
end

function GameSetup:BedFriendlyDamageFilter(damage)
    if not damage then return true end

    local victimIndex = tonumber(damage.entindex_victim_const)
    local victim = victimIndex and EntIndexToHScript(victimIndex) or nil
    if not victim or victim:IsNull() then return true end

    local bedUnits = {
        npc_bed_red = true,
        npc_bed_blue = true,
        npc_bed_green = true,
        npc_bed_yellow = true
    }
    if not victim.GetUnitName or not bedUnits[victim:GetUnitName()] then return true end

    -- modifier_bed_hit_points owns the entire hit-point system through
    -- OnAttackLanded. Reject the engine damage here so one attack cannot apply
    -- both the scripted pip loss and one additional native damage.
    return false
end

function GameSetup:PublishBedState(team, alive)
    local aliveValue = alive == true and 1 or 0
    CustomNetTables:SetTableValue("team_status", tostring(team), {
        -- Net table numbers have identical representations in Lua and
        -- Panorama, unlike booleans on some Source 2 builds.
        bed_alive = aliveValue
    })
    CustomGameEventManager:Send_ServerToAllClients("team_bed_state_changed", {
        team_id = team,
        bed_alive = aliveValue
    })
end

function GameSetup:AnnounceBedDestroyed(team)
    local messageTokens = {
        [DOTA_TEAM_CUSTOM_1] = "#bed_destroyed_team_red",
        [DOTA_TEAM_CUSTOM_2] = "#bed_destroyed_team_blue",
        [DOTA_TEAM_CUSTOM_3] = "#bed_destroyed_team_green",
        [DOTA_TEAM_CUSTOM_4] = "#bed_destroyed_team_orange"
    }
    local token = messageTokens[team]
    if token then
        GameRules:SendCustomMessage(token, 0, 0)
    end
end

function GameSetup:HandleBedDestroyed(team)
    team = tonumber(team)
    if not ModeConfig.IsPlayableTeam(team) then return false end

    -- The direct lethal-hit callback, entity_killed, and the watchdog may all
    -- observe the same destruction. Only the first one performs match effects.
    if self.respawnDisabledTeams[team] then return false end

    self:DisableTeamRespawns(team)
    self:PublishBedState(team, false)
    self:AnnounceBedDestroyed(team)
    self:ScheduleVictoryCheck()
    return true
end

function GameSetup:SetPregameLocked(locked)
    for playerID = 0, (DOTA_MAX_PLAYERS - 1) do
        if PlayerResource:IsValidPlayerID(playerID) then
            local hero = PlayerResource:GetSelectedHeroEntity(playerID)
            if hero and not hero:IsNull() then
                if locked then
                    if not hero:HasModifier("modifier_pregame_stun") then
                        hero:AddNewModifier(hero, nil, "modifier_pregame_stun", {})
                    end
                else
                    hero:RemoveModifierByName("modifier_pregame_stun")
                end
            end
        end
    end
end

function GameSetup:PregameCountdownThink()
    local state = GameRules:State_Get()

    if state >= DOTA_GAMERULES_STATE_PRE_GAME and state < DOTA_GAMERULES_STATE_GAME_IN_PROGRESS then
        self:SetPregameLocked(true)
    elseif state == DOTA_GAMERULES_STATE_GAME_IN_PROGRESS then
        self:SetPregameLocked(false)
        return nil
    end

    return 0.05
end

function GameSetup:PlayBattleBeginVoice()
    if self.battleBeginVoicePlayed then return end
    self.battleBeginVoicePlayed = true
    EmitGlobalSound("Trynafix.BattleBegin")
end

function GameSetup:BeginPregameCountdown()
    self.pregameSequence = (self.pregameSequence or 0) + 1
    local sequence = self.pregameSequence

    -- PRE_GAME is configured to last five seconds. Start the visible count
    -- after two seconds so the final three beats are deterministic and do not
    -- depend on GetDOTATime exposing negative values in this custom game.
    for count = 3, 1, -1 do
        local emittedCount = count
        local delay = 5 - emittedCount
        Timers:CreateTimer(delay, function()
            if self.pregameSequence ~= sequence then return end
            if GameRules:State_Get() ~= DOTA_GAMERULES_STATE_PRE_GAME then return end
            if emittedCount == 3 then self:PlayBattleBeginVoice() end
            CustomGameEventManager:Send_ServerToAllClients("pregame_countdown", { count = emittedCount })
        end)
    end
end

function GameSetup:StartDayNightCycle()
    if self.dayNightCycleStarted then return end
    self.dayNightCycleStarted = true

    local fullCycleDuration = 600
    local dawnTimeOfDay = 0.25
    GameRules:GetGameModeEntity():SetContextThink("BedWarsDayNightCycle", function()
        if GameRules:State_Get() >= DOTA_GAMERULES_STATE_POST_GAME then return nil end

        local elapsed = math.max(0, GameRules:GetDOTATime(false, false))
        local timeOfDay = (dawnTimeOfDay + (elapsed % fullCycleDuration) / fullCycleDuration) % 1
        GameRules:SetTimeOfDay(timeOfDay)
        return 1
    end, 0)
end

function GameSetup:Shops()
    local shopTeam = ModeConfig.IsDuo() and DOTA_TEAM_NEUTRALS or DOTA_TEAM_CUSTOM_4
    local shopSpawnOne = Entities:FindByName(nil, "ShopSpawnOne")
    if shopSpawnOne then
        local unitOne = CreateUnitByName("shop_keeper_custom_first", shopSpawnOne:GetAbsOrigin(), true, nil, nil, shopTeam) -- leftTop

        unitOne:AddNewModifier(unitOne, nil, "modifier_shopkeeper_interaction", {})
        unitOne:AddNewModifier(unitOne, nil, "modifier_structure_spell_immune", {})
        unitOne:SetForwardVector(Vector(0, 1, 0))
    end

    local shopSpawnTwo = Entities:FindByName(nil, "ShopSpawnTwo")
    if shopSpawnTwo then
        local unitTwo = CreateUnitByName("shop_keeper_custom_first", shopSpawnTwo:GetAbsOrigin(), true, nil, nil, shopTeam) -- leftBott

        unitTwo:AddNewModifier(unitTwo, nil, "modifier_shopkeeper_interaction", {})
        unitTwo:AddNewModifier(unitTwo, nil, "modifier_structure_spell_immune", {})
        unitTwo:SetForwardVector(Vector(-45, 1, 0))
    end

    local shopSpawnThree = Entities:FindByName(nil, "ShopSpawnThree")
    if shopSpawnThree then
        local unitThree = CreateUnitByName("shop_keeper_custom_first", shopSpawnThree:GetAbsOrigin(), true, nil, nil, shopTeam) -- rightBott

        unitThree:AddNewModifier(unitThree, nil, "modifier_shopkeeper_interaction", {})
        unitThree:AddNewModifier(unitThree, nil, "modifier_structure_spell_immune", {})
        unitThree:SetForwardVector(Vector(-90, -90, 0)) 
    end

    local shopSpawnFour = Entities:FindByName(nil, "ShopSpawnFour")
    if shopSpawnFour then
        local unitFour = CreateUnitByName("shop_keeper_custom_first", shopSpawnFour:GetAbsOrigin(), true, nil, nil, shopTeam) -- leftBott

        unitFour:AddNewModifier(unitFour, nil, "modifier_shopkeeper_interaction", {})
        unitFour:AddNewModifier(unitFour, nil, "modifier_structure_spell_immune", {})
        unitFour:SetForwardVector(Vector(90, 1, 0))
    end

    local chestSpawnOne = Entities:FindByName(nil, "SpawnChestOne")
    if chestSpawnOne then
        local chestOrigin = MapLocations.GetChestPosition(1, chestSpawnOne)
        chestSpawnOne:SetAbsOrigin(chestOrigin)
        local chestOne = CreateUnitByName("npc_chest_default", chestOrigin, false, nil, nil, DOTA_TEAM_NEUTRALS)
        if chestOne then
            chestOne:SetAbsOrigin(chestOrigin)
            chestOne:AddNewModifier(chestOne, nil, "modifier_no_interaction", {})
            chestOne:SetForwardVector(Vector(-1, -1, 0):Normalized())
            local visual = SpawnEntityFromTableSynchronous("prop_dynamic", {
                model = "models/props_generic/chest_treasure_03.vmdl",
                origin = chestOrigin,
                angles = "0 225 0",
                solid = "0"
            })
            if visual and not visual:IsNull() then
                visual:SetModel("models/props_generic/chest_treasure_03.vmdl")
                visual:SetAbsOrigin(chestOrigin)
                chestOne:AddNoDraw()
            end
            local chestOneOrigin = chestOne:GetAbsOrigin()
            CustomNetTables:SetTableValue("arcane_chests", "chest_1", {
                unit_name = chestOne:GetUnitName(),
                x = chestOneOrigin.x,
                y = chestOneOrigin.y,
                z = chestOneOrigin.z
            })
        end
    end


    local chestSpawnTwo = Entities:FindByName(nil, "SpawnChestTwo")
    if chestSpawnTwo then
        local chestOrigin = MapLocations.GetChestPosition(2, chestSpawnTwo)
        chestSpawnTwo:SetAbsOrigin(chestOrigin)
        local chestTwo = CreateUnitByName("npc_chest_default", chestOrigin, false, nil, nil, DOTA_TEAM_NEUTRALS)
        if chestTwo then
            chestTwo:SetAbsOrigin(chestOrigin)
            chestTwo:AddNewModifier(chestTwo, nil, "modifier_no_interaction", {})
            chestTwo:SetForwardVector(Vector(1, 1, 0):Normalized())
            local visual = SpawnEntityFromTableSynchronous("prop_dynamic", {
                model = "models/props_generic/chest_treasure_03.vmdl",
                origin = chestOrigin,
                angles = "0 45 0",
                solid = "0"
            })
            if visual and not visual:IsNull() then
                visual:SetModel("models/props_generic/chest_treasure_03.vmdl")
                visual:SetAbsOrigin(chestOrigin)
                chestTwo:AddNoDraw()
            end
            local chestTwoOrigin = chestTwo:GetAbsOrigin()
            CustomNetTables:SetTableValue("arcane_chests", "chest_2", {
                unit_name = chestTwo:GetUnitName(),
                x = chestTwoOrigin.x,
                y = chestTwoOrigin.y,
                z = chestTwoOrigin.z
            })
        end
    end
end

function GameSetup:MidSpawners()
    -- Re-anchor the named spawn markers around the stable map-center marker.
    -- Their Hammer transforms may have moved along with collapsed map groups.
    local positions = MapLocations.GetMidBossPositions()
    for index, position in ipairs(positions) do
        local name = "IslandMiniBossSpawn" .. index
        local marker = Entities:FindByName(nil, name)
        if not marker then marker = SpawnEntityFromTableSynchronous("info_target", { targetname=name }) end
        if marker then marker:SetAbsOrigin(GetGroundPosition(position, marker)) end
    end

end

-- Disable future respawns for a team. Living heroes remain fully controllable;
-- their permanent respawn lock begins only when entity_killed fires.
function GameSetup:ApplyBuybackLock(hero)
    if not hero or hero:IsNull() then return end
    if hero.SetBuyBackDisabledByReapersScythe then
        hero:SetBuyBackDisabledByReapersScythe(true)
    end
end

function GameSetup:ApplyRespawnLock(hero)
    if not hero or hero:IsNull() then return end
    if self:IsHeroReincarnating(hero) then return end

    -- This is the authoritative engine flag. The timer assignment below keeps
    -- the HUD from displaying a normal countdown on engine builds that update
    -- the death timer after entity_killed listeners have executed.
    if hero.SetRespawnsDisabled then hero:SetRespawnsDisabled(true) end
    if hero.SetUnitCanRespawn then hero:SetUnitCanRespawn(false) end
    self:ApplyBuybackLock(hero)
    if not hero:IsAlive() and hero.SetTimeUntilRespawn then
        hero:SetTimeUntilRespawn(-1)
    end
end

function GameSetup:IsHeroReincarnating(hero)
    return hero and not hero:IsNull() and hero.IsReincarnating and hero:IsReincarnating()
end

-- SetRespawnsDisabled/SetUnitCanRespawn also suppress inventory orders on a
-- living hero in current Source 2 builds. A player whose bed is gone must keep
-- full control until their next death, so only buyback is disabled while they
-- are alive; the permanent respawn lock is applied by entity_killed.
function GameSetup:MaintainLivingHeroAfterBedLoss(hero)
    if not hero or hero:IsNull() or not hero:IsAlive() then return end
    if hero.SetRespawnsDisabled then hero:SetRespawnsDisabled(false) end
    if hero.SetUnitCanRespawn then hero:SetUnitCanRespawn(true) end
    self:ApplyBuybackLock(hero)
end

function GameSetup:DisableTeamRespawns(team)
    if not team then return end
    if self.respawnDisabledTeams[team] then return end
    self.respawnDisabledTeams[team] = true

    -- apply immediately to any currently existing hero on that team
    for playerID = 0, (DOTA_MAX_PLAYERS - 1) do
        if PlayerResource:IsValidPlayerID(playerID) and PlayerResource:GetTeam(playerID) == team then
            local hero = PlayerResource:GetSelectedHeroEntity(playerID)
            if (not hero) or hero:IsNull() then
                local player = PlayerResource:GetPlayer(playerID)
                if player then hero = player:GetAssignedHero() end
            end

            if hero and (not hero:IsNull()) then
                -- Buyback ends immediately with the bed, including when the
                -- hero died shortly before the bed was destroyed.
                -- Destruction is immediate: living heroes lose their next
                -- respawn, and heroes already dead lose the current one too.
                if hero:IsAlive() then
                    self:MaintainLivingHeroAfterBedLoss(hero)
                elseif not self:IsHeroReincarnating(hero) then
                    self:ApplyRespawnLock(hero)
                end
            end
        end
    end
end

function GameSetup:OnEntityKilled(keys)
    if not keys or not keys.entindex_killed then return end

    local killed = EntIndexToHScript(keys.entindex_killed)
    if not killed or killed:IsNull() then return end

    -- 1) If a bed died => disable respawns for that bed's team
    if self:IsBed(killed) then
        self:HandleBedDestroyed(killed:GetTeamNumber())
        return
    end

    -- 2) Custom item_lua currencies do not consistently honor the native
    -- ItemDropOnDeath KV flag (notably for deaths caused by -suicide), so
    -- explicitly drop the original item handles and preserve their charges.
    if killed.IsRealHero and killed:IsRealHero() then
        -- Aegis deaths are reincarnations, not ordinary deaths. Do not drop
        -- currency, apply the permanent bed-loss lock, run elimination, or
        -- overwrite the engine's five-second reincarnation timer.
        if self:IsHeroReincarnating(killed) then return end

        self:DropDeathCurrencies(killed)

        local team = killed:GetTeamNumber()
        if self.respawnDisabledTeams[team] then
            self:ApplyRespawnLock(killed)

            -- The engine calculates its normal death timer after some kill
            -- listeners. Reassert once on the following frame so that value
            -- cannot replace the permanent lock or show a false countdown.
            local deadHero = killed
            Timers:CreateTimer(0.03, function()
                if deadHero and not deadHero:IsNull()
                    and self.respawnDisabledTeams[deadHero:GetTeamNumber()] then
                    self:ApplyRespawnLock(deadHero)
                end
            end)
        end
        self:ScheduleVictoryCheck()
    end
end

-- A team only leaves the match after its bed is gone and every one of its
-- real heroes is dead. This supports both the normal solo teams and extra
-- Tools Mode heroes without declaring a winner during an ordinary respawn.
function GameSetup:IsTeamEliminated(team)
    if not self.respawnDisabledTeams[team] then return false end

    local foundHero = false
    local heroes = HeroList:GetAllHeroes()
    for _, hero in pairs(heroes) do
        if hero and not hero:IsNull() and hero:IsRealHero()
            and hero:GetTeamNumber() == team then
            foundHero = true
            if hero:IsAlive() or self:IsHeroReincarnating(hero) then return false end
        end
    end
    return foundHero
end

function GameSetup:EnterSpectatorMode(team)
    if not ModeConfig.IsPlayableTeam(team) or self.spectatorTeams[team] then return end
    self.spectatorTeams[team] = true
    AddFOWViewer(team, MapLocations.GetMidCenter(), 50000, 1.5, false)

    for playerID = 0, DOTA_MAX_PLAYERS - 1 do
        if PlayerResource:IsValidPlayerID(playerID) and PlayerResource:GetTeam(playerID) == team then
            local player = PlayerResource:GetPlayer(playerID)
            if player then
                CustomGameEventManager:Send_ServerToPlayer(player, "ShowError", {
                    message = "#spectator_mode_enabled"
                })
            end
        end
    end
end

function GameSetup:ScheduleVictoryCheck()
    if self.victoryStarted then return end
    self.victoryCheckSequence = (self.victoryCheckSequence or 0) + 1
    local sequence = self.victoryCheckSequence
    Timers:CreateTimer(0.12, function()
        if self.victoryStarted or sequence ~= self.victoryCheckSequence then return end
        self:CheckForVictory()
    end)
end

function GameSetup:CheckForVictory()
    if self.victoryStarted or GameRules:State_Get() ~= DOTA_GAMERULES_STATE_GAME_IN_PROGRESS then return end

    local remaining = {}
    local participantCount = 0
    for team in pairs(self.participatingTeams) do
        participantCount = participantCount + 1
        if self:IsTeamEliminated(team) then
            self.eliminatedTeams[team] = true
            self:EnterSpectatorMode(team)
        elseif not self.eliminatedTeams[team] then
            table.insert(remaining, team)
        end
    end

    if participantCount >= 2 and #remaining == 1 then
        self:BeginVictorySequence(remaining[1])
    end
end

function GameSetup:GetVictoryHero(team)
    local fallback = nil
    for _, hero in pairs(HeroList:GetAllHeroes()) do
        if hero and not hero:IsNull() and hero:IsRealHero() and hero:GetTeamNumber() == team then
            fallback = fallback or hero
            if hero:IsAlive() then return hero end
        end
    end
    return fallback
end

function GameSetup:BeginVictorySequence(team)
    if self.victoryStarted then return end
    self.victoryStarted = true

    local hero = self:GetVictoryHero(team)
    for _, winnerHero in pairs(HeroList:GetAllHeroes()) do
        if winnerHero and not winnerHero:IsNull() and winnerHero:IsRealHero()
            and winnerHero:GetTeamNumber() == team and winnerHero:IsAlive() then
            winnerHero:Stop()
            winnerHero:AddNewModifier(winnerHero, nil, "modifier_victory_pose", { duration = 10 })
        end
    end
    local playerID = hero and hero:GetPlayerOwnerID() or -1
    local playerName = playerID >= 0 and PlayerResource:GetPlayerName(playerID) or ""
    if ModeConfig.IsDuo() then
        local winnerNames = {}
        for id = 0, DOTA_MAX_PLAYERS - 1 do
            if PlayerResource:IsValidPlayerID(id) and PlayerResource:GetTeam(id) == team then
                local name = PlayerResource:GetPlayerName(id)
                if name and name ~= "" then table.insert(winnerNames, name) end
            end
        end
        if #winnerNames > 0 then playerName = table.concat(winnerNames, " & ") end
    end
    CustomGameEventManager:Send_ServerToAllClients("trynafix_victory", {
        team_id = team,
        hero_entindex = hero and hero:entindex() or -1,
        hero_name = hero and hero:GetUnitName() or "",
        player_name = playerName,
        duration = 10
    })

    -- Let Panorama finish its camera sweep and title reveal before the native
    -- post-game screen takes ownership of the camera.
    Timers:CreateTimer(10, function()
        GameRules:SetGameWinner(team)
    end)
end

function GameSetup:DropDeathCurrencies(hero)
    if not hero or hero:IsNull() then return end

    local deathCurrencies = {
        item_purple_money = true,
        item_pumpkin_coin = true
    }
    local origin = hero:GetAbsOrigin()

    -- Iterate backwards so removing an item cannot cause a later slot to be
    -- skipped if the engine compacts part of the inventory.
    for slot = 16, 0, -1 do
        local item = hero:GetItemInSlot(slot)
        if item and not item:IsNull() and deathCurrencies[item:GetAbilityName()] then
            item:SetDroppable(true)
            hero:DropItemAtPositionImmediate(item, origin + RandomVector(RandomFloat(20, 65)))
            if item and not item:IsNull() then
                item:SetPurchaser(nil)
                item:SetOwner(nil)
            end
        end
    end
end

function GameSetup:PlaceDuoHeroAtBase(hero)
    if not ModeConfig.IsDuo() or not hero or hero:IsNull() then return end
    if (hero.IsIllusion and hero:IsIllusion())
        or (hero.IsClone and hero:IsClone())
        or (hero.IsTempestDouble and hero:IsTempestDouble()) then return end
    local team = hero:GetTeamNumber()
    if not ModeConfig.IsPlayableTeam(team) then return end

    local playerID = hero:GetPlayerOwnerID()
    local playerIDs = {}
    for id = 0, DOTA_MAX_PLAYERS - 1 do
        if PlayerResource:IsValidPlayerID(id) and PlayerResource:GetTeam(id) == team then
            table.insert(playerIDs, id)
        end
    end
    table.sort(playerIDs)
    local slot = 1
    for index, id in ipairs(playerIDs) do
        if id == playerID then slot = index; break end
    end

    local base = BaseUtils:GetTeamBasePosition(team)
    if not base then return end
    local inward = MapLocations.GetMidCenter() - base
    inward = Vector(inward.x, inward.y, 0)
    if inward:Length2D() <= 0 then inward = Vector(0, -1, 0) end
    inward = inward:Normalized()
    local sideways = Vector(-inward.y, inward.x, 0)
    local sideOffset = slot == 1 and -110 or 110
    local destination = GetGroundPosition(base + inward * 100 + sideways * sideOffset, hero)

    -- npc_spawned fires before every initial spawn and respawn. Defer one frame
    -- so this placement wins over the engine's single-marker spawn resolution.
    Timers:CreateTimer(0, function()
        if hero and not hero:IsNull() and hero:IsAlive() then
            FindClearSpaceForUnit(hero, destination, true)
        end
    end)
end

function GameSetup:OnNPCSpawned(keys)
    if not keys or not keys.entindex then return end
    local unit = EntIndexToHScript(keys.entindex)
    if not unit or unit:IsNull() then return end

    local spellImmuneStructures = {
        npc_bed_red = true,
        npc_bed_blue = true,
        npc_bed_green = true,
        npc_bed_yellow = true,
        shop_keeper_custom_first = true,
        npc_custom_tower = true
    }
    if unit.GetUnitName and spellImmuneStructures[unit:GetUnitName()]
        and not unit:HasModifier("modifier_structure_spell_immune") then
        unit:AddNewModifier(unit, nil, "modifier_structure_spell_immune", {})
    end

    local bedUnits = {
        npc_bed_red = true,
        npc_bed_blue = true,
        npc_bed_green = true,
        npc_bed_yellow = true
    }
    if unit.GetUnitName and bedUnits[unit:GetUnitName()]
        and not unit:HasModifier("modifier_bed_hit_points") then
        unit:AddNewModifier(unit, nil, "modifier_bed_hit_points", {})
    end
    if unit.GetUnitName and bedUnits[unit:GetUnitName()] then
        self.bedsByTeam[unit:GetTeamNumber()] = unit
        self:RevealBedToAllTeams(unit)
        if GameRules:State_Get() == DOTA_GAMERULES_STATE_GAME_IN_PROGRESS then
            self:ApplyOpeningBedProtection()
        end
    end

    -- Re-apply on spawn (covers reconnects / re-creations / some custom flows)
    if unit.IsRealHero and unit:IsRealHero() then
        -- One hidden Track-style instance per viewer team keeps every living
        -- bed visible through fog without revealing the surrounding base.
        self:RevealAllBedsToViewer(unit)

        -- Town Portal Scrolls are disabled in this game. Remove starting,
        -- respawn-granted, or otherwise injected copies from every inventory.
        for slot = 0, 16 do
            local item = unit:GetItemInSlot(slot)
            if item and not item:IsNull() and item:GetAbilityName() == "item_tpscroll" then
                UTIL_Remove(item)
            end
        end

        local team = unit:GetTeamNumber()
        if ModeConfig.IsPlayableTeam(team) then
            self.participatingTeams[team] = true
        end
        self:PlaceDuoHeroAtBase(unit)
        local state = GameRules:State_Get()
        if state >= DOTA_GAMERULES_STATE_PRE_GAME and state < DOTA_GAMERULES_STATE_GAME_IN_PROGRESS then
            if not unit:HasModifier("modifier_pregame_stun") then
                unit:AddNewModifier(unit, nil, "modifier_pregame_stun", {})
            end
        else
            unit:RemoveModifierByName("modifier_pregame_stun")
        end

        if self.respawnDisabledTeams and self.respawnDisabledTeams[team] then
            if unit:IsAlive() then
                self:MaintainLivingHeroAfterBedLoss(unit)
            else
                self:ApplyRespawnLock(unit)
            end
        end
    end

    -- keep your existing npc_spawned logic below (if you had any)
end

-- keep your existing implementation (or remove this stub if you already have it elsewhere)
function GameSetup:OnStateChange(keys)
    local state = GameRules:State_Get()
    if state == DOTA_GAMERULES_STATE_CUSTOM_GAME_SETUP then
        self:BeginTeamSelectionCountdown()
    elseif state == DOTA_GAMERULES_STATE_STRATEGY_TIME then
        self:RandomlyPickMissingHeroes()
    elseif state == DOTA_GAMERULES_STATE_PRE_GAME then
        self:SetPregameLocked(true)
        self:BeginPregameCountdown()
    elseif state == DOTA_GAMERULES_STATE_GAME_IN_PROGRESS then
        self.pregameSequence = (self.pregameSequence or 0) + 1
        self:SetPregameLocked(false)
        self:StartDayNightCycle()
        self:ApplyOpeningBedProtection()
        CustomGameEventManager:Send_ServerToAllClients("pregame_countdown", { count = 0 })
    end
end

-- STRATEGY_TIME begins immediately after the hero-pick deadline. It is the
-- engine-supported window for filling any players who did not make a choice.
function GameSetup:RandomlyPickMissingHeroes()
    for playerID = 0, (DOTA_MAX_PLAYERS - 1) do
        if PlayerResource:IsValidPlayerID(playerID)
            and PlayerResource:GetConnectionState(playerID) == DOTA_CONNECTION_STATE_CONNECTED
            and not PlayerResource:HasSelectedHero(playerID) then
            local player = PlayerResource:GetPlayer(playerID)
            if player then player:MakeRandomHeroSelection() end
        end
    end
end

-- The engine owns the visible setup transition and starts it only once all
-- lobby participants have loaded. Assign just before that transition so
-- players retain the full selection window while nobody reaches hero select
-- without a valid custom team.
function GameSetup:BeginTeamSelectionCountdown()
    -- A team change can cause setup-related engine events, but it must never
    -- create a fresh selection window.
    if self.teamSelectionActive then return end
    self.teamSelectionActive = true
    self.teamSelectionSequence = (self.teamSelectionSequence or 0) + 1
    local sequence = self.teamSelectionSequence
    local duration = 20
    local deadline = GameRules:GetGameTime() + duration

    CustomNetTables:SetTableValue("team_selection", "countdown", {
        start_time = GameRules:GetGameTime(),
        end_time = deadline,
        duration = duration
    })

    Timers:CreateTimer(duration, function()
        if self.teamSelectionSequence ~= sequence then return end
        if GameRules:State_Get() ~= DOTA_GAMERULES_STATE_CUSTOM_GAME_SETUP then return end
        self:RandomlyAssignUnselectedPlayers()
        GameRules:LockCustomGameSetupTeamAssignment(true)
        GameRules:FinishCustomGameSetup()
    end)
end

function GameSetup:RandomlyAssignUnselectedPlayers()
    local playableTeams = ModeConfig.GetPlayableTeams()
    local occupied = {}
    local unassigned = {}

    for playerID = 0, (DOTA_MAX_PLAYERS - 1) do
        if PlayerResource:IsValidPlayerID(playerID)
            and PlayerResource:GetConnectionState(playerID) == DOTA_CONNECTION_STATE_CONNECTED then
            local team = tonumber(PlayerResource:GetTeam(playerID)) or DOTA_TEAM_NOTEAM
            if ModeConfig.IsPlayableTeam(team) then
                occupied[team] = (occupied[team] or 0) + 1
            else
                table.insert(unassigned, playerID)
            end
        end
    end

    local freeTeams = {}
    local capacity = ModeConfig.GetTeamCapacity()
    for _, team in ipairs(playableTeams) do
        for _ = (occupied[team] or 0) + 1, capacity do
            table.insert(freeTeams, team)
        end
    end

    -- Fisher-Yates keeps the fallback genuinely random without changing any
    -- choice already made by a player.
    for index = #freeTeams, 2, -1 do
        local swapIndex = RandomInt(1, index)
        freeTeams[index], freeTeams[swapIndex] = freeTeams[swapIndex], freeTeams[index]
    end
    for index = #unassigned, 2, -1 do
        local swapIndex = RandomInt(1, index)
        unassigned[index], unassigned[swapIndex] = unassigned[swapIndex], unassigned[index]
    end

    for index, playerID in ipairs(unassigned) do
        local team = freeTeams[index]
        if not team then break end
        PlayerResource:SetCustomTeamAssignment(playerID, team)
    end
end
