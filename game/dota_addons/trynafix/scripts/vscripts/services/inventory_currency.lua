if InventoryCurrency == nil then InventoryCurrency = {} end

InventoryCurrency.FIRST_SLOT = 0
InventoryCurrency.LAST_BACKPACK_SLOT = 8

InventoryCurrency.ITEM_NAMES = {
    item_purple_money = true,
    item_pumpkin_coin = true
}

function InventoryCurrency:MergeStacks(hero, itemName)
    if not hero or hero:IsNull() or not self.ITEM_NAMES[itemName] then return end

    local primary = nil
    local totalCharges = 0
    local duplicates = {}
    for slot = self.FIRST_SLOT, self.LAST_BACKPACK_SLOT do
        local item = hero:GetItemInSlot(slot)
        if item and not item:IsNull() and item:GetAbilityName() == itemName then
            item:SetPurchaser(hero)
            item:SetOwner(hero)
            totalCharges = totalCharges + math.max(0, item:GetCurrentCharges())
            if not primary then
                primary = item
            else
                table.insert(duplicates, item)
            end
        end
    end

    if not primary then return end
    primary:SetCurrentCharges(totalCharges)
    for _, item in ipairs(duplicates) do
        if item and not item:IsNull() then UTIL_Remove(item) end
    end
end

function InventoryCurrency:OnItemPickedUp(event)
    if not event or not self.ITEM_NAMES[tostring(event.itemname or "")] then return end
    local heroIndex = tonumber(event.HeroEntityIndex)
    local hero = heroIndex and EntIndexToHScript(heroIndex) or nil
    if not hero or hero:IsNull() then return end

    -- The pickup event can fire before the inventory has settled. Merge on the
    -- next frame after normalizing the picked-up stack to its new owner.
    local itemName = tostring(event.itemname)
    Timers:CreateTimer(0, function()
        if hero and not hero:IsNull() then self:MergeStacks(hero, itemName) end
    end)
end

function InventoryCurrency:Init()
    if self.initialized then return end
    self.initialized = true
    ListenToGameEvent("dota_item_picked_up", function(event) self:OnItemPickedUp(event) end, nil)
end

function InventoryCurrency:GetHero(playerID)
    if not PlayerResource or not PlayerResource:IsValidPlayerID(playerID) then return nil end
    local hero = PlayerResource:GetSelectedHeroEntity(playerID)
    if hero and not hero:IsNull() then return hero end
    local player = PlayerResource:GetPlayer(playerID)
    hero = player and player:GetAssignedHero() or nil
    return hero and not hero:IsNull() and hero or nil
end

function InventoryCurrency:Count(playerID, itemName)
    local hero = self:GetHero(playerID)
    if not hero then return 0 end

    local total = 0
    for slot = self.FIRST_SLOT, self.LAST_BACKPACK_SLOT do
        local item = hero:GetItemInSlot(slot)
        if item and not item:IsNull() and item:GetAbilityName() == itemName then
            total = total + math.max(0, item:GetCurrentCharges())
        end
    end
    return total
end

function InventoryCurrency:Consume(playerID, itemName, amount)
    local hero = self:GetHero(playerID)
    local remaining = math.max(0, math.floor(tonumber(amount) or 0))
    if not hero or remaining <= 0 then return 0 end

    local requested = remaining
    -- Spend backpack stacks before active inventory stacks.
    for slot = self.LAST_BACKPACK_SLOT, self.FIRST_SLOT, -1 do
        local item = hero:GetItemInSlot(slot)
        if item and not item:IsNull() and item:GetAbilityName() == itemName then
            local charges = math.max(0, item:GetCurrentCharges())
            local spent = math.min(charges, remaining)
            if spent > 0 then
                if spent >= charges then
                    item:SetCurrentCharges(0)
                    UTIL_Remove(item)
                else
                    item:SetCurrentCharges(charges - spent)
                end
                remaining = remaining - spent
                if remaining <= 0 then break end
            end
        end
    end
    return requested - remaining
end

return InventoryCurrency
