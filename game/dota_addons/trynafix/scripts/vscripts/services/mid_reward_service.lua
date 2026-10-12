local MapLocations = require("settings/map_locations")

if MidRewardService == nil then MidRewardService = { started = false } end

MidRewardService.CENTER = MapLocations.MID_CENTER_FALLBACK
MidRewardService.RADIUS = 1600
MidRewardService.INTERVAL = 2
MidRewardService.MIN_XP = 30
MidRewardService.MAX_XP = 50
MidRewardService.MIN_GOLD = 20
MidRewardService.MAX_GOLD = 45

function MidRewardService:IsEligible(hero)
    return hero
        and not hero:IsNull()
        and hero:IsRealHero()
        and hero:IsAlive()
        and (hero:GetAbsOrigin() - self.CENTER):Length2D() <= self.RADIUS
end

function MidRewardService:RewardHeroes()
    for playerID = 0, (DOTA_MAX_PLAYERS - 1) do
        if PlayerResource:IsValidPlayerID(playerID) then
            local hero = PlayerResource:GetSelectedHeroEntity(playerID)
            if self:IsEligible(hero) then
                local xp = RandomInt(self.MIN_XP, self.MAX_XP)
                local gold = RandomInt(self.MIN_GOLD, self.MAX_GOLD)
                hero:AddExperience(xp, DOTA_ModifyXP_Unspecified, false, true)
                PlayerResource:ModifyGold(playerID, gold, true, DOTA_ModifyGold_Unspecified)
            end
        end
    end
end

function MidRewardService:Start()
    if self.started then return end
    self.started = true
    self.CENTER = MapLocations.GetMidCenter()

    print(string.format(
        "[MidRewardService] Reward zone centered at %.0f, %.0f (radius %.0f)",
        self.CENTER.x,
        self.CENTER.y,
        self.RADIUS
    ))

    Timers:CreateTimer(self.INTERVAL, function()
        if GameRules:State_Get() >= DOTA_GAMERULES_STATE_POST_GAME then return nil end
        if GameRules:State_Get() == DOTA_GAMERULES_STATE_GAME_IN_PROGRESS then
            self:RewardHeroes()
        end
        return self.INTERVAL
    end)
end

function MidRewardService:Init()
    -- Refresh this even after a tools-mode script reload, where the service table
    -- and its active timer may already exist.
    self.CENTER = MapLocations.GetMidCenter()

    ListenToGameEvent("game_rules_state_change", function()
        if GameRules:State_Get() == DOTA_GAMERULES_STATE_GAME_IN_PROGRESS then self:Start() end
    end, nil)
    if GameRules:State_Get() == DOTA_GAMERULES_STATE_GAME_IN_PROGRESS then self:Start() end
end

return MidRewardService
