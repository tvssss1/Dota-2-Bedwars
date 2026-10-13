local ModeConfig = require("settings/mode_config")

if PassiveIncomeService == nil then PassiveIncomeService = { started = false } end

PassiveIncomeService.GOLD_PER_TICK = 2
PassiveIncomeService.INTERVAL = 1.0

function PassiveIncomeService:Tick()
    for playerID = 0, (DOTA_MAX_PLAYERS - 1) do
        if PlayerResource:IsValidPlayerID(playerID)
            and ModeConfig.IsPlayableTeam(PlayerResource:GetTeam(playerID)) then
            local hero = PlayerResource:GetSelectedHeroEntity(playerID)
            if hero and not hero:IsNull() then
                PlayerResource:ModifyGold(
                    playerID,
                    self.GOLD_PER_TICK,
                    true,
                    DOTA_ModifyGold_Unspecified
                )
            end
        end
    end
end

function PassiveIncomeService:Start()
    if self.started then return end
    self.started = true
    Timers:CreateTimer(self.INTERVAL, function()
        if GameRules:State_Get() >= DOTA_GAMERULES_STATE_POST_GAME then return nil end
        if GameRules:State_Get() == DOTA_GAMERULES_STATE_GAME_IN_PROGRESS then
            self:Tick()
        end
        return self.INTERVAL
    end)
end

function PassiveIncomeService:Init()
    ListenToGameEvent("game_rules_state_change", function()
        if GameRules:State_Get() == DOTA_GAMERULES_STATE_GAME_IN_PROGRESS then self:Start() end
    end, nil)
    if GameRules:State_Get() == DOTA_GAMERULES_STATE_GAME_IN_PROGRESS then self:Start() end
end

return PassiveIncomeService
