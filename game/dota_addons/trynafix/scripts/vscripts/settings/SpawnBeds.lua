if SpawnBeds == nil then
  SpawnBeds = class({})
end
local ModeConfig = require("settings/mode_config")

function SpawnBeds:SpawnThrones()
    local beds = {
        { unit = "npc_bed_red", point = "ThroneSpawnPointOne", team = DOTA_TEAM_CUSTOM_1 },
        { unit = "npc_bed_blue", point = "ThroneSpawnPointTwo", team = DOTA_TEAM_CUSTOM_2 },
        { unit = "npc_bed_green", point = "ThroneSpawnPointThree", team = DOTA_TEAM_CUSTOM_3 },
        { unit = "npc_bed_yellow", point = "ThroneSpawnPointFour", team = DOTA_TEAM_CUSTOM_4 },
    }

    for _, bed in ipairs(beds) do
        if ModeConfig.IsPlayableTeam(bed.team) then
            local point = Entities:FindByName(nil, bed.point)
            if point then
                CreateUnitByName(bed.unit, point:GetAbsOrigin(), false, nil, nil, bed.team)
            end
        end
    end
end
