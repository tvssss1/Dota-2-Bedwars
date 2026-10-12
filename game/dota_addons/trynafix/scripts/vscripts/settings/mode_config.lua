local ModeConfig = {}

ModeConfig.SOLO_MAP = "bw_solo"
ModeConfig.DUO_MAP = "bw_duo"

function ModeConfig.GetMapName()
    return string.lower(GetMapName() or "")
end

function ModeConfig.IsDuo()
    return ModeConfig.GetMapName() == ModeConfig.DUO_MAP
end

function ModeConfig.GetPlayableTeams()
    if ModeConfig.IsDuo() then
        return {
            DOTA_TEAM_CUSTOM_1,
            DOTA_TEAM_CUSTOM_2,
            DOTA_TEAM_CUSTOM_3
        }
    end
    return {
        DOTA_TEAM_CUSTOM_1,
        DOTA_TEAM_CUSTOM_2,
        DOTA_TEAM_CUSTOM_3,
        DOTA_TEAM_CUSTOM_4
    }
end

function ModeConfig.IsPlayableTeam(team)
    team = tonumber(team)
    if not team then return false end
    if ModeConfig.IsDuo() then
        return team >= DOTA_TEAM_CUSTOM_1 and team <= DOTA_TEAM_CUSTOM_3
    end
    return team >= DOTA_TEAM_CUSTOM_1 and team <= DOTA_TEAM_CUSTOM_4
end

function ModeConfig.GetTeamCapacity()
    return ModeConfig.IsDuo() and 2 or 1
end

function ModeConfig.GetMaxPlayers()
    return ModeConfig.IsDuo() and 6 or 4
end

return ModeConfig
