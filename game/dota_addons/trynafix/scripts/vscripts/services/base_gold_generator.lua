local ModeConfig = require("settings/mode_config")
local BaseUtils = require("services/base_utils")

if BaseGoldGenerator == nil then BaseGoldGenerator = {} end

BaseGoldGenerator.CAPACITY = 6000
BaseGoldGenerator.reserves = BaseGoldGenerator.reserves or {}
BaseGoldGenerator.positions = BaseGoldGenerator.positions or {}
BaseGoldGenerator.POSITION_NAMES = {
    [DOTA_TEAM_CUSTOM_1] = "generator_red",
    [DOTA_TEAM_CUSTOM_2] = "generator_blue",
    [DOTA_TEAM_CUSTOM_3] = "generator_green",
    [DOTA_TEAM_CUSTOM_4] = "generator_orange"
}

function BaseGoldGenerator:GetWorldPosition(team)
    team = tonumber(team)
    local markerName = self.POSITION_NAMES[team]
    local marker = markerName and Entities:FindByName(nil, markerName) or nil
    if marker and not marker:IsNull() then
        self.positions[team] = marker:GetAbsOrigin()
        return self.positions[team]
    end
    local cached = self.positions[team]
    if cached then return cached end
    -- The generator is part of the permanent team base. This fallback makes
    -- its label available even on map builds that do not expose trigger
    -- volumes through Entities:FindByName.
    return BaseUtils:GetTeamBasePosition(team)
end

function BaseGoldGenerator:Publish(team)
    local data = {
        remaining = self.reserves[team] or 0,
        capacity = self.CAPACITY
    }
    local position = self:GetWorldPosition(team)
    if position then
        data.x = position.x
        data.y = position.y
        data.z = position.z
    end
    CustomNetTables:SetTableValue("base_gold_generator", tostring(team), data)
    -- Use the exact same registered table as the proven middle-generator
    -- world labels. This also works immediately in Tools Mode without a full
    -- addon restart after adding a new custom-net-table declaration.
    CustomNetTables:SetTableValue("arcane_chests", "gold_generator_" .. tostring(team), data)
end

function BaseGoldGenerator:Ensure(team)
    team = tonumber(team)
    if not team or not ModeConfig.IsPlayableTeam(team) then return 0 end
    if self.reserves[team] == nil then
        self.reserves[team] = self.CAPACITY
        self:Publish(team)
    end
    return self.reserves[team]
end

function BaseGoldGenerator:GetRemaining(team)
    return self:Ensure(team)
end

function BaseGoldGenerator:IsEmpty(team)
    return self:GetRemaining(team) <= 0
end

function BaseGoldGenerator:Take(team, requested)
    team = tonumber(team)
    requested = math.max(0, math.floor(tonumber(requested) or 0))
    local remaining = self:Ensure(team)
    local granted = math.min(remaining, requested)
    if granted > 0 then
        self.reserves[team] = remaining - granted
        self:Publish(team)
    end
    return granted, self.reserves[team] or 0
end

function BaseGoldGenerator:Refill(team)
    team = tonumber(team)
    if not team or not ModeConfig.IsPlayableTeam(team) then return false end
    self.reserves[team] = self.CAPACITY
    self:Publish(team)
    return true
end

function BaseGoldGenerator:Init()
    self.initialized = true
    for _, team in ipairs(ModeConfig.GetPlayableTeams()) do
        self:Ensure(team)
        self:Publish(team)
    end
end

return BaseGoldGenerator
