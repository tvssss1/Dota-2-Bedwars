if BaseUtils == nil then BaseUtils = { cachedSpawns = {} } end

-- These are the permanent info_player_start_dota entities in BW_Solo.
-- The fourth spawn kept its original map-editor name for compatibility.
BaseUtils.SPAWN_NAMES = {
    [DOTA_TEAM_CUSTOM_1] = "red_spawn",
    [DOTA_TEAM_CUSTOM_2] = "blue_spawn",
    [DOTA_TEAM_CUSTOM_3] = "green_spawn",
    [DOTA_TEAM_CUSTOM_4] = "green_spawn1"
}

BaseUtils.FALLBACK_NAMES = {
    [DOTA_TEAM_CUSTOM_1] = "ThroneSpawnPointOne",
    [DOTA_TEAM_CUSTOM_2] = "ThroneSpawnPointTwo",
    [DOTA_TEAM_CUSTOM_3] = "ThroneSpawnPointThree",
    [DOTA_TEAM_CUSTOM_4] = "ThroneSpawnPointFour"
}

local function validEntity(entity)
    return entity and not entity:IsNull()
end

function BaseUtils:GetTeamBaseEntity(team)
    team = tonumber(team)
    local cached = self.cachedSpawns[team]
    if validEntity(cached) then return cached end

    -- Prefer the entity's team assignment, so a renamed spawn in a later map
    -- revision still resolves without changing gameplay code.
    for _, spawn in pairs(Entities:FindAllByClassname("info_player_start_dota") or {}) do
        if validEntity(spawn) and spawn.GetTeamNumber and spawn:GetTeamNumber() == team then
            self.cachedSpawns[team] = spawn
            return spawn
        end
    end

    local spawnName = self.SPAWN_NAMES[team]
    local spawn = spawnName and Entities:FindByName(nil, spawnName) or nil
    if validEntity(spawn) then
        self.cachedSpawns[team] = spawn
        return spawn
    end

    -- A missing player spawn should never make the mode unusable in Tools
    -- Mode. The bed marker is only a defensive map-authoring fallback.
    local fallbackName = self.FALLBACK_NAMES[team]
    local fallback = fallbackName and Entities:FindByName(nil, fallbackName) or nil
    if validEntity(fallback) then
        print("[BaseUtils] Missing team base spawn for team " .. tostring(team)
            .. "; using " .. fallbackName .. " as a fallback.")
        self.cachedSpawns[team] = fallback
        return fallback
    end
    return nil
end

function BaseUtils:GetTeamBasePosition(team)
    local spawn = self:GetTeamBaseEntity(team)
    if not spawn then return nil end
    return spawn:GetAbsOrigin()
end

function BaseUtils:IsNearTeamBase(unit, radius)
    if not validEntity(unit) then return false, nil end
    local position = self:GetTeamBasePosition(unit:GetTeamNumber())
    if not position then return false, nil end
    return (unit:GetAbsOrigin() - position):Length2D() <= (tonumber(radius) or 0), position
end

return BaseUtils
