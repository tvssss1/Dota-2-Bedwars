require("services/inventory_currency")

if PumpkinCurrency == nil then PumpkinCurrency = {} end
PumpkinCurrency.balances = PumpkinCurrency.balances or {}
PumpkinCurrency.lastPublished = PumpkinCurrency.lastPublished or {}
PumpkinCurrency.ITEM_NAME = "item_pumpkin_coin"

function PumpkinCurrency:Ensure(id)
    if id == nil or id < 0 then return false end
    if self.balances[id] == nil then self.balances[id] = 0 end
    return true
end

function PumpkinCurrency:GetDeposited(id)
    return math.max(0, math.floor(self.balances[id] or 0))
end

function PumpkinCurrency:GetCarried(id)
    return InventoryCurrency:Count(id, self.ITEM_NAME)
end

function PumpkinCurrency:Get(id)
    return self:GetDeposited(id) + self:GetCarried(id)
end

function PumpkinCurrency:Publish(id, force)
    if not self:Ensure(id) then return end
    local deposited = self:GetDeposited(id)
    local carried = self:GetCarried(id)
    local data = {
        balance = deposited + carried,
        deposited = deposited,
        carried = carried
    }
    local signature = tostring(deposited) .. ":" .. tostring(carried)
    if not force and self.lastPublished[id] == signature then return end
    self.lastPublished[id] = signature
    CustomNetTables:SetTableValue("pumpkin_currency", tostring(id), data)
    local player = PlayerResource and PlayerResource:GetPlayer(id) or nil
    if player then CustomGameEventManager:Send_ServerToPlayer(player, "pumpkin_currency_changed", data) end
end

function PumpkinCurrency:Credit(id, amount)
    amount = math.max(0, math.floor(tonumber(amount) or 0))
    if not self:Ensure(id) or amount == 0 then return false end
    self.balances[id] = self:GetDeposited(id) + amount
    self:Publish(id, true)
    return true
end

function PumpkinCurrency:Debit(id, amount)
    amount = math.max(0, math.floor(tonumber(amount) or 0))
    if not self:Ensure(id) or amount == 0 or self:Get(id) < amount then return false end
    local carriedSpent = InventoryCurrency:Consume(id, self.ITEM_NAME, amount)
    self.balances[id] = self:GetDeposited(id) - (amount - carriedSpent)
    self:Publish(id, true)
    return true
end

function PumpkinCurrency:RewardSpend(id, amount)
    if not PerkService or not PerkService.GetCurrencySpendBonus then return 0 end
    local bonus = PerkService:GetCurrencySpendBonus(id, amount, "pumpkin")
    if bonus > 0 then self:Credit(id, bonus) end
    return bonus
end

function PumpkinCurrency:Init()
    InventoryCurrency:Init()
    ListenToGameEvent("player_connect_full", function(event)
        local id = tonumber(event.PlayerID)
        if id and PlayerResource:IsValidPlayerID(id) then
            self:Ensure(id)
            self:Publish(id, true)
        end
    end, nil)
    for id = 0, DOTA_MAX_TEAM_PLAYERS - 1 do
        if PlayerResource:IsValidPlayerID(id) then
            self:Ensure(id)
            self:Publish(id, true)
        end
    end
    GameRules:GetGameModeEntity():SetContextThink("PumpkinCurrencyInventory", function()
        for id = 0, DOTA_MAX_TEAM_PLAYERS - 1 do
            if PlayerResource:IsValidPlayerID(id) then self:Publish(id, false) end
        end
        return 0.20
    end, 0.20)
end

return PumpkinCurrency
