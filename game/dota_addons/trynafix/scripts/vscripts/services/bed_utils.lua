if BedUtils == nil then BedUtils = {} end
BedUtils.NAMES = { npc_bed_red=true, npc_bed_blue=true, npc_bed_green=true, npc_bed_yellow=true }
function BedUtils:IsLivingBed(unit)
    return unit and not unit:IsNull() and self.NAMES[unit:GetUnitName()] == true and unit:IsAlive()
end
function BedUtils:IsOwnLivingBed(unit, hero)
    return self:IsLivingBed(unit) and hero and unit:GetTeamNumber() == hero:GetTeamNumber()
end
function BedUtils:NearestLivingBed(origin, radius, team)
    radius = tonumber(radius) or 0
    if radius < 0 or radius == FIND_UNITS_EVERYWHERE then radius = math.huge end
    local best, bestDistance = nil, radius + 0.001

    local function consider(bed)
        if self:IsLivingBed(bed) and (not team or bed:GetTeamNumber() == team) then
            local distance = (bed:GetAbsOrigin() - origin):Length2D()
            if distance <= bestDistance then best, bestDistance = bed, distance end
        end
    end

    -- GameSetup owns the spawned bed handles and is the most reliable source.
    -- Beds use npc_dota_base_additive, so a creature-only entity scan misses
    -- them even while their models and health bars are plainly visible.
    if team and GameSetup and GameSetup.bedsByTeam then
        consider(GameSetup.bedsByTeam[team])
        if best then return best, bestDistance end
    end

    -- Keep a fallback for tools-mode reloads and any callers without a team.
    for _, className in ipairs({ "npc_dota_base_additive", "npc_dota_creature" }) do
        local units = Entities:FindAllByClassname(className) or {}
        for _, bed in pairs(units) do consider(bed) end
    end

    return best, bestDistance
end
return BedUtils
