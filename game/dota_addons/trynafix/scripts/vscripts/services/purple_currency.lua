require("services/inventory_currency")

if PurpleCurrency == nil then PurpleCurrency = {} end
PurpleCurrency.balances = PurpleCurrency.balances or {}
PurpleCurrency.lastPublished = PurpleCurrency.lastPublished or {}
PurpleCurrency.ITEM_NAME = "item_purple_money"

function PurpleCurrency:Ensure(id)
    if id == nil or id < 0 then return false end
    if self.balances[id] == nil then self.balances[id] = 0 end
    return true
end

function PurpleCurrency:GetDeposited(id)
    return math.max(0, math.floor(self.balances[id] or 0))
end

function PurpleCurrency:GetCarried(id)
    return InventoryCurrency:Count(id, self.ITEM_NAME)
end

-- Public balance includes deposited currency and stacks carried in slots 0-8.
function PurpleCurrency:Get(id)
    return self:GetDeposited(id) + self:GetCarried(id)
end

function PurpleCurrency:Publish(id, force)
    if not self:Ensure(id) then return end
    local deposited = self:GetDeposited(id)
    local carried = self:GetCarried(id)
    local signature = tostring(deposited) .. ":" .. tostring(carried)
    if not force and self.lastPublished[id] == signature then return end
    self.lastPublished[id] = signature
    CustomNetTables:SetTableValue("purple_currency", tostring(id), {
        balance = deposited + carried,
        deposited = deposited,
        carried = carried
    })
end

function PurpleCurrency:Credit(id, amount)
    amount = math.max(0, math.floor(tonumber(amount) or 0))
    if not self:Ensure(id) or amount == 0 then return false end
    self.balances[id] = self:GetDeposited(id) + amount
    self:Publish(id, true)
    return true
end

function PurpleCurrency:Debit(id, amount)
    amount = math.max(0, math.floor(tonumber(amount) or 0))
    if not self:Ensure(id) or amount == 0 or self:Get(id) < amount then return false end
    local carriedSpent = InventoryCurrency:Consume(id, self.ITEM_NAME, amount)
    self.balances[id] = self:GetDeposited(id) - (amount - carriedSpent)
    self:Publish(id, true)
    return true
end

-- Treasure Trickster now rolls when currency is actually spent. Any refund is
-- credited directly to the balance; the physical coin item remains passive.
function PurpleCurrency:RewardSpend(id, amount)
    if not PerkService or not PerkService.GetCurrencySpendBonus then return 0 end
    local bonus = PerkService:GetCurrencySpendBonus(id, amount, "arcane")
    if bonus > 0 then self:Credit(id, bonus) end
    return bonus
end

function PurpleCurrency:Init()
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
    GameRules:GetGameModeEntity():SetContextThink("PurpleCurrencyInventory", function()
        for id = 0, DOTA_MAX_TEAM_PLAYERS - 1 do
            if PlayerResource:IsValidPlayerID(id) then self:Publish(id, false) end
        end
        return 0.20
    end, 0.20)
end

return PurpleCurrency
