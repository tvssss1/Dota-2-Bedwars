local MapLocations = {}
local ModeConfig = require("settings/mode_config")

-- The playable map is offset from Source's world origin. The two convergence
-- shrines sit on opposite sides of the central island, so their midpoint is the
-- island's geometric center. Boss markers can be moved accidentally together
-- with collapsed Hammer groups and are intentionally not trusted here.
MapLocations.MID_CENTER_FALLBACK = Vector(2108, 0, 256)
MapLocations.DUO_SHRINE_POSITIONS = {
    Vector(1258, 0, 256),
    Vector(2958, 0, 256)
}
function MapLocations.GetShrinePosition(index, marker)
    if ModeConfig.IsDuo() and MapLocations.DUO_SHRINE_POSITIONS[index] then
        return GetGroundPosition(MapLocations.DUO_SHRINE_POSITIONS[index], marker)
    end
    return marker and GetGroundPosition(marker:GetAbsOrigin(), marker) or nil
end

function MapLocations.GetChestPosition(index, marker)
    return marker and GetGroundPosition(marker:GetAbsOrigin(), marker) or nil
end

function MapLocations.GetMidCenter()
    local firstShrine = Entities:FindByName(nil, "ConvergenceShrine01")
    local secondShrine = Entities:FindByName(nil, "ConvergenceShrine02")
    if firstShrine and secondShrine then
        local firstOrigin = firstShrine:GetAbsOrigin()
        local secondOrigin = secondShrine:GetAbsOrigin()
        return Vector(
            (firstOrigin.x + secondOrigin.x) * 0.5,
            (firstOrigin.y + secondOrigin.y) * 0.5,
            MapLocations.MID_CENTER_FALLBACK.z
        )
    end

    return MapLocations.MID_CENTER_FALLBACK
end

function MapLocations.GetMidBossPositions()
    local center = MapLocations.GetMidCenter()
    return {
        center + Vector(0, 220, 0),
        center + Vector(220, 0, 0),
        center + Vector(0, -220, 0),
        center + Vector(-220, 0, 0)
    }
end

-- BW_Duo contains only one legacy ShopSpawn marker. Its three side
-- islands lie between the three team bases, so derive stable vision anchors
-- from the permanent base markers instead of depending on missing entities.
function MapLocations.GetSideIslandPositions()
    local positions = {}
    local firstDuoIsland = nil
    for _, name in ipairs({ "ShopSpawnOne", "ShopSpawnTwo", "ShopSpawnThree", "ShopSpawnFour" }) do
        local marker = Entities:FindByName(nil, name)
        if marker then
            local origin = GetGroundPosition(marker:GetAbsOrigin(), marker)
            table.insert(positions, origin)
            if name == "ShopSpawnOne" then firstDuoIsland = origin end
        end
    end

    if ModeConfig.IsDuo() then
        if firstDuoIsland then
            -- The duo arena is three-way rotationally symmetric. Hammer has
            -- only the first legacy shop marker, so rotate it by 120/240 deg.
            local center = MapLocations.GetMidCenter()
            local relative = firstDuoIsland - center
            for _, degrees in ipairs({ 120, 240 }) do
                local radians = math.rad(degrees)
                local rotated = Vector(
                    relative.x * math.cos(radians) - relative.y * math.sin(radians),
                    relative.x * math.sin(radians) + relative.y * math.cos(radians),
                    0
                )
                local candidate = center + rotated
                table.insert(positions, GetGroundPosition(candidate, nil))
            end
        else
            -- Defensive fallback for a future map revision with no shop marker.
            local bases = {}
            for _, team in ipairs(ModeConfig.GetPlayableTeams()) do
                for _, spawn in pairs(Entities:FindAllByClassname("info_player_start_dota") or {}) do
                    if spawn:GetTeamNumber() == team then table.insert(bases, spawn:GetAbsOrigin()); break end
                end
            end
            if #bases == 3 then
                for first = 1, 3 do
                    local second = (first % 3) + 1
                    table.insert(positions, GetGroundPosition((bases[first] + bases[second]) * 0.5, nil))
                end
            end
        end
    end
    return positions
end

return MapLocations
