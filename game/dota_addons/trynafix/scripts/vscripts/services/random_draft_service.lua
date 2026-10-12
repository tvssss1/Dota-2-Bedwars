if RandomDraftService == nil then RandomDraftService = {} end
local ModeConfig = require("settings/mode_config")

RandomDraftService.HEROES_PER_ATTRIBUTE = 12
RandomDraftService.ATTRIBUTE_KEYS = {
    DOTA_ATTRIBUTE_STRENGTH = "strength",
    DOTA_ATTRIBUTE_AGILITY = "agility",
    DOTA_ATTRIBUTE_INTELLECT = "intelligence",
    DOTA_ATTRIBUTE_ALL = "universal",
    ["0"] = "strength",
    ["1"] = "agility",
    ["2"] = "intelligence",
    ["3"] = "universal"
}

local function shuffle(values)
    for index = #values, 2, -1 do
        local swapIndex = RandomInt(1, index)
        values[index], values[swapIndex] = values[swapIndex], values[index]
    end
end

function RandomDraftService:LoadRoster()
    local data = LoadKeyValues("scripts/npc/npc_heroes.txt") or {}
    return data.DOTAHeroes or data
end

function RandomDraftService:BuildPool()
    local roster = self:LoadRoster()
    local groups = { strength={}, agility={}, intelligence={}, universal={} }

    for heroName, heroData in pairs(roster) do
        if type(heroName) == "string"
            and string.match(heroName, "^npc_dota_hero_")
            and heroName ~= "npc_dota_hero_base"
            and type(heroData) == "table" then
            local attribute = self.ATTRIBUTE_KEYS[tostring(heroData.AttributePrimary)]
                or self.ATTRIBUTE_KEYS[heroData.AttributePrimary]
            local enabled = tostring(heroData.Enabled or "1") ~= "0"
            if attribute and enabled then
                table.insert(groups[attribute], heroName)
            end
        end
    end

    local allowed = {}
    local attributes = {}
    for _, attribute in ipairs({ "strength", "agility", "intelligence", "universal" }) do
        local heroes = groups[attribute]
        shuffle(heroes)
        if #heroes < self.HEROES_PER_ATTRIBUTE then
            print("[RandomDraftService] Not enough " .. attribute .. " heroes: " .. tostring(#heroes))
            return nil
        end
        for index = 1, self.HEROES_PER_ATTRIBUTE do
            local heroName = heroes[index]
            allowed[heroName] = true
            attributes[heroName] = attribute
        end
    end

    return allowed, attributes
end

function RandomDraftService:Init()
    local allowed, attributes = self:BuildPool()
    if not allowed then
        print("[RandomDraftService] Draft pool was not applied.")
        return
    end

    self.allowed = allowed
    self.attributes = attributes
    GameRules:ClearHeroWhitelist()
    GameRules:SetHideBlacklistedHeroes(true)
    for heroName in pairs(allowed) do GameRules:AddHeroToWhitelist(heroName) end

    local published = {}
    for heroName in pairs(allowed) do table.insert(published, heroName) end
    table.sort(published)
    CustomNetTables:SetTableValue("random_draft", "pool", {
        heroes=published,
        attributes=attributes,
        count=#published
    })

    if not self.pickListenerRegistered then
        self.pickListenerRegistered = true
        CustomGameEventManager:RegisterListener("random_draft_select_hero", function(_, data)
            self:OnSelectHero(data)
        end)
    end
    self:StartSelectionPublisher()
    print("[RandomDraftService] Applied balanced 48-hero draft pool (12 per attribute).")

    -- The native -createhero cheat also checks the hero whitelist. Keep the
    -- random pool intact throughout hero selection, then make every enabled
    -- hero legal once the match begins in Workshop Tools. Published games keep
    -- the random whitelist for the whole match.
    if IsInToolsMode and IsInToolsMode() then
        ListenToGameEvent("game_rules_state_change", function()
            self:EnableToolsHeroSpawning()
            self:PrepareDebugHeroes()
        end, nil)
        self:EnableToolsHeroSpawning()
    end
end

function RandomDraftService:GetTeamPlayerIDs(team)
    local players = {}
    for playerID = 0, (DOTA_MAX_PLAYERS - 1) do
        if PlayerResource:IsValidPlayerID(playerID) and PlayerResource:GetTeam(playerID) == team then
            table.insert(players, playerID)
        end
    end
    table.sort(players)
    return players
end

function RandomDraftService:PublishSelections(force)
    self.publishedSelections = self.publishedSelections or {}
    for _, team in ipairs(ModeConfig.GetPlayableTeams()) do
        local playerIDs = self:GetTeamPlayerIDs(team)
        local teamPlayers = {}
        local teamSignatureParts = {}
        for slot, playerID in ipairs(playerIDs) do
            local heroName = PlayerResource:GetSelectedHeroName(playerID) or ""
            teamPlayers[slot] = {
                player_id = playerID,
                hero_name = heroName
            }
            table.insert(teamSignatureParts, tostring(playerID) .. ":" .. heroName)

            local playerKey = "player_" .. tostring(playerID)
            local playerSignature = tostring(team) .. ":" .. heroName
            if force or self.publishedSelections[playerKey] ~= playerSignature then
                self.publishedSelections[playerKey] = playerSignature
                CustomNetTables:SetTableValue("random_draft", playerKey, {
                    team_id = team,
                    player_id = playerID,
                    hero_name = heroName
                })
            end
        end

        local teamKey = "team_" .. tostring(team)
        local signature = table.concat(teamSignatureParts, "|")
        if force or self.publishedSelections[teamKey] ~= signature then
            self.publishedSelections[teamKey] = signature
            CustomNetTables:SetTableValue("random_draft", "team_" .. tostring(team), {
                team_id = team,
                player_count = #playerIDs,
                players = teamPlayers,
                -- Preserve the original first-player fields for any legacy
                -- strategy overlay while duo-aware UIs consume every slot.
                player_id = playerIDs[1] or -1,
                hero_name = teamPlayers[1] and teamPlayers[1].hero_name or ""
            })
        end
    end
end

function RandomDraftService:StartSelectionPublisher()
    if self.selectionPublisherStarted then return end
    self.selectionPublisherStarted = true
    self:PublishSelections(true)

    GameRules:GetGameModeEntity():SetContextThink("RandomDraftSelectionPublisher", function()
        self:PublishSelections(false)
        if GameRules:State_Get() >= DOTA_GAMERULES_STATE_PRE_GAME then
            self:PublishSelections(true)
            return nil
        end
        return 0.1
    end, 0.1)
end

function RandomDraftService:SendPickResult(player, success, reason, heroName)
    if not player then return end
    CustomGameEventManager:Send_ServerToPlayer(player, "random_draft_pick_result", {
        success = success and 1 or 0,
        reason = reason or "",
        hero_name = heroName or ""
    })
end

function RandomDraftService:OnSelectHero(data)
    data = data or {}
    local playerID = tonumber(data.PlayerID)
    local heroName = tostring(data.hero_name or "")
    if playerID == nil or not PlayerResource:IsValidPlayerID(playerID) then return end

    local player = PlayerResource:GetPlayer(playerID)
    if not player then return end
    if GameRules:State_Get() ~= DOTA_GAMERULES_STATE_HERO_SELECTION then
        self:SendPickResult(player, false, "#draft_pick_closed", heroName)
        return
    end

    local team = PlayerResource:GetTeam(playerID)
    if not ModeConfig.IsPlayableTeam(team) then
        self:SendPickResult(player, false, "#draft_pick_wrong_team", heroName)
        return
    end

    if PlayerResource:HasSelectedHero(playerID) then
        self:SendPickResult(player, false, "#draft_pick_already_locked", heroName)
        return
    end

    if not self.allowed or not self.allowed[heroName] then
        self:SendPickResult(player, false, "#draft_pick_unavailable", heroName)
        return
    end

    for otherID = 0, (DOTA_MAX_PLAYERS - 1) do
        if otherID ~= playerID and PlayerResource:IsValidPlayerID(otherID)
            and PlayerResource:GetSelectedHeroName(otherID) == heroName then
            self:SendPickResult(player, false, "#draft_pick_taken", heroName)
            return
        end
    end

    player:SetSelectedHero(heroName)
    self:PublishSelections(true)
    self:SendPickResult(player, true, "", heroName)
    print("[RandomDraftService] Player " .. tostring(playerID) .. " selected " .. heroName .. " from the custom picker.")
end

function RandomDraftService:EnableToolsHeroSpawning()
    if self.toolsHeroSpawningEnabled then return end
    if GameRules:State_Get() < DOTA_GAMERULES_STATE_PRE_GAME then return end

    -- This mode normally has one slot on each FFA team and no Radiant/Dire
    -- slots. -createhero uses those team capacities for its bot heroes, so a
    -- player's team is already full as soon as the match starts. Selection is
    -- over at PRE_GAME, making it safe to expand the capacities for local
    -- testing without changing the lobby or the published four-player mode.
    local debugTeams = { DOTA_TEAM_GOODGUYS, DOTA_TEAM_BADGUYS }
    for _, team in ipairs(ModeConfig.GetPlayableTeams()) do table.insert(debugTeams, team) end
    for _, team in ipairs(debugTeams) do
        GameRules:SetCustomGameTeamMaxPlayers(team, 24)
    end
    GameRules:SetSameHeroSelectionEnabled(true)

    local roster = self:LoadRoster()
    local added = 0
    for heroName, heroData in pairs(roster) do
        if type(heroName) == "string"
            and string.match(heroName, "^npc_dota_hero_")
            and heroName ~= "npc_dota_hero_base"
            and type(heroData) == "table"
            and tostring(heroData.Enabled or "1") ~= "0" then
            GameRules:AddHeroToWhitelist(heroName)
            added = added + 1
        end
    end

    self.toolsHeroSpawningEnabled = true
    print("[RandomDraftService] Enabled native Tools Mode hero spawning for " .. tostring(added) .. " heroes, including duplicates and expanded debug team capacity.")

    -- A local Tools launch normally has only its human team. Fill every empty
    -- Bed Wars team with one controllable bot so eliminations and the victory
    -- cutscene can be exercised without four clients.
    if not self.debugTeamsFilled then
        self.debugTeamsFilled = true
        self.debugHeroes = self.debugHeroes or {}
        local heroes = { "npc_dota_hero_axe", "npc_dota_hero_drow_ranger", "npc_dota_hero_lina", "npc_dota_hero_juggernaut" }
        local teams = ModeConfig.GetPlayableTeams()
        for index, team in ipairs(teams) do
            local occupied = false
            for playerID = 0, (DOTA_MAX_PLAYERS - 1) do
                if PlayerResource:IsValidPlayerID(playerID) and PlayerResource:GetTeam(playerID) == team then
                    occupied = true
                    break
                end
            end
            if not occupied then
                local hero = GameRules:AddBotPlayerWithEntityScript(heroes[index], "Debug " .. tostring(index), team, "", true)
                if hero and not hero:IsNull() then
                    self.debugHeroes[hero:entindex()] = true
                end
            end
        end
        print("[RandomDraftService] Tools Mode debug heroes added to every empty Bed Wars team.")
    end
end

function RandomDraftService:IsDebugHero(hero)
    return hero and not hero:IsNull() and self.debugHeroes
        and self.debugHeroes[hero:entindex()] == true
end

function RandomDraftService:PrepareDebugHeroes()
    if not self.debugTeamsFilled or self.debugHeroesPrepared then return end
    if GameRules:State_Get() ~= DOTA_GAMERULES_STATE_GAME_IN_PROGRESS then return end
    self.debugHeroesPrepared = true

    local centerMarker = Entities:FindByName(nil, "VisionForAllTeams")
    local center = centerMarker and centerMarker:GetAbsOrigin() or Vector(0, 0, 256)
    local offsets = {
        [DOTA_TEAM_CUSTOM_1] = Vector(-850, 0, 0),
        [DOTA_TEAM_CUSTOM_2] = Vector(0, 850, 0),
        [DOTA_TEAM_CUSTOM_3] = Vector(850, 0, 0),
        [DOTA_TEAM_CUSTOM_4] = Vector(0, -850, 0)
    }

    for entindex in pairs(self.debugHeroes) do
        local hero = EntIndexToHScript(entindex)
        if hero and not hero:IsNull() then
            -- Bots created during PRE_GAME can retain engine/setup protection
            -- on custom teams. Explicitly normalize them into ordinary combat
            -- heroes and separate their spawn points so they are easy targets.
            hero:RemoveModifierByName("modifier_invulnerable")
            hero:RemoveModifierByName("modifier_pregame_stun")
            hero:RemoveModifierByName("modifier_bed_fountain_regen")
            local offset = offsets[hero:GetTeamNumber()] or RandomVector(850)
            FindClearSpaceForUnit(hero, GetGroundPosition(center + offset, hero), true)
        end
    end
    print("[RandomDraftService] Debug heroes normalized, separated, and made killable.")
end

return RandomDraftService
