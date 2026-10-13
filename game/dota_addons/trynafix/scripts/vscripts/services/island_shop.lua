require("services/pumpkin_currency")
require("services/custom_courier_service")

if IslandShop == nil then IslandShop = { busy = {}, nearby = {} } end
IslandShop.RADIUS = 450
IslandShop.CATALOG = {
    { slot=1, id="durian", name="#island_shop_durian_name", description="#island_shop_durian_desc", icon="file://{images}/items/ender_pearl.png", price=3, enabled=true, item="item_durian_pearl" },
    { slot=2, id="harvest_tonic", name="#island_shop_tonic_name", description="#island_shop_tonic_desc", icon="file://{images}/items/harvest_tonic.png", price=8, enabled=true, item="item_harvest_tonic" },
    { slot=3, id="skyhook_spool", name="#island_shop_skyhook_name", description="#island_shop_skyhook_desc", icon="file://{images}/items/skyhook_spool.png", price=5, enabled=true, item="item_skyhook_spool" },
    { slot=4, id="gravity_marble", name="#island_shop_gravity_name", description="#island_shop_gravity_desc", icon="file://{images}/items/gravity_marble.png", price=6, enabled=true, item="item_gravity_marble" },
    { slot=5, id="custom_courier", name="#island_shop_courier_name", description="#island_shop_courier_desc", icon="item_courier", price=0, enabled=true, kind="courier" },
    { slot=6, id="overdrive_grenade", name="#island_shop_overdrive_name", description="#island_shop_overdrive_desc", icon="file://{images}/items/overdrive_grenade.png", price=5, enabled=true, item="item_overdrive_grenade", max_charges=6 },
    { slot=7, id="future_07", enabled=false },
    { slot=8, id="future_08", enabled=false },
    { slot=9, id="future_09", enabled=false },
    { slot=10, id="future_10", enabled=false }
}

function IslandShop:GetEntry(entryID)
    for _, entry in ipairs(self.CATALOG) do
        if entry.enabled and entry.id == entryID then return entry end
    end
    return nil
end

local function playerFromEvent(source, data)
    -- Panorama events include an engine-owned PlayerID. Prefer it because the
    -- listener source is not consistently exposed as a player entity index.
    local id = type(data) == "table" and tonumber(data.PlayerID) or nil
    if id and PlayerResource:IsValidPlayerID(id) then
        local player = PlayerResource:GetPlayer(id)
        if player then return player, id end
    end

    local player = source and EntIndexToHScript(source) or nil
    if player and not player:IsNull() and player.GetPlayerID then
        id = player:GetPlayerID()
        if PlayerResource:IsValidPlayerID(id) then return player, id end
    end

    id = tonumber(source)
    if id and PlayerResource:IsValidPlayerID(id) then
        player = PlayerResource:GetPlayer(id)
        if player then return player, id end
    end
    return nil, -1
end

function IslandShop:GetNearestShopkeeper(hero)
    if not hero or hero:IsNull() or not hero:IsAlive() then return nil, nil end
    -- Entity iteration reliably includes invulnerable shopkeepers on every
    -- custom team; FindUnitsInRadius can omit them depending on target flags.
    local nearest, nearestDistance = nil, math.huge
    local units = Entities:FindAllByClassname("npc_dota_creature") or {}
    for _, unit in pairs(units) do
        if unit and not unit:IsNull() and unit:IsAlive()
            and unit:GetUnitName() == "shop_keeper_custom_first" then
            local distance = (unit:GetAbsOrigin() - hero:GetAbsOrigin()):Length2D()
            if distance < nearestDistance then
                nearest, nearestDistance = unit, distance
            end
        end
    end
    return nearest, nearestDistance
end

function IslandShop:IsNearShopkeeper(hero)
    local shopkeeper, distance = self:GetNearestShopkeeper(hero)
    return shopkeeper ~= nil and distance <= self.RADIUS
end

function IslandShop:MarkNearestShopkeeper(hero)
    local shopkeeper = self:GetNearestShopkeeper(hero)
    if not shopkeeper then return end
    local position = shopkeeper:GetAbsOrigin()
    MinimapEvent(hero:GetTeamNumber(), shopkeeper, position.x, position.y, DOTA_MINIMAP_EVENT_HINT_LOCATION, 3)
end

function IslandShop:GetContext(id)
    local hero = PlayerResource:GetSelectedHeroEntity(id)
    return { nearby = self:IsNearShopkeeper(hero), balance = PumpkinCurrency:Get(id) }
end

function IslandShop:Send(player, event, extra)
    local data = self:GetContext(player:GetPlayerID())
    for key, value in pairs(extra or {}) do data[key] = value end
    CustomGameEventManager:Send_ServerToPlayer(player, event, data)
end

function IslandShop:Deliver(hero, itemName)
    local item = CreateItem(itemName, hero, hero)
    if not item then return false end
    item:SetActivated(true)
    if itemName ~= "item_skyhook_spool" and item:GetCurrentCharges() <= 0 then
        item:SetCurrentCharges(1)
    end
    for slot = 0, 8 do
        if hero:GetItemInSlot(slot) == nil then
            hero:AddItem(item)
            return true
        end
    end
    local container = CreateItemOnPositionSync(hero:GetAbsOrigin(), item)
    if container then return true end
    UTIL_Remove(item)
    return false
end

function IslandShop:HasItem(hero, itemName)
    if not hero or hero:IsNull() then return false end
    for slot = 0, 16 do
        local item = hero:GetItemInSlot(slot)
        if item and not item:IsNull() and item:GetAbilityName() == itemName then return true end
    end
    return false
end

function IslandShop:GetHeldItemCharges(hero, itemName)
    if not hero or hero:IsNull() then return 0, nil end
    local total = 0
    local firstItem = nil
    for slot = 0, 16 do
        local item = hero:GetItemInSlot(slot)
        if item and not item:IsNull() and item:GetAbilityName() == itemName then
            firstItem = firstItem or item
            total = total + math.max(0, item:GetCurrentCharges())
        end
    end
    return total, firstItem
end

function IslandShop:DeliverCharge(hero, itemName, maxCharges)
    local total, item = self:GetHeldItemCharges(hero, itemName)
    if total >= maxCharges then return false, "max_charges" end
    if item then
        item:SetCurrentCharges(item:GetCurrentCharges() + 1)
        return true
    end
    return self:Deliver(hero, itemName)
end

function IslandShop:Purchase(source, data)
    local player, id = playerFromEvent(source, data)
    if not player or self.busy[id] then return end
    self.busy[id] = true
    local entryID = type(data) == "table" and tostring(data.entry_id or "") or ""
    local entry = self:GetEntry(entryID)
    local hero = PlayerResource:GetSelectedHeroEntity(id)
    local code
    if not entry then code = "invalid_entry"
    elseif not hero or hero:IsNull() or not hero:IsAlive() then code = "hero_dead"
    elseif not self:IsNearShopkeeper(hero) then code = "not_nearby"
    elseif entry.item == "item_skyhook_spool" and self:HasItem(hero, entry.item) then code = "already_owned"
    elseif entry.max_charges and self:GetHeldItemCharges(hero, entry.item) >= entry.max_charges then code = "max_charges"
    elseif PumpkinCurrency:Get(id) < entry.price then code = "insufficient_funds" end
    if code then
        if code == "not_nearby" then self:MarkNearestShopkeeper(hero) end
        self:Send(player, "island_shop_result", { success=false, code=code })
        self.busy[id] = nil
        return
    end
    if not PumpkinCurrency:Debit(id, entry.price) then
        self:Send(player, "island_shop_result", { success=false, code="insufficient_funds" })
        self.busy[id] = nil
        return
    end
    local called, ok, failureCode = pcall(function()
        if entry.kind == "courier" then
            if CustomCourierService:HasCourier(id) then return true end
            return CustomCourierService:PurchaseCourier(id, hero)
        end
        if entry.max_charges then
            return self:DeliverCharge(hero, entry.item, entry.max_charges)
        end
        return self:Deliver(hero, entry.item), "delivery_failed"
    end)
    ok = called and ok == true
    if ok then
        PumpkinCurrency:RewardSpend(id, entry.price)
    else
        PumpkinCurrency:Credit(id, entry.price)
    end
    self:Send(player, "island_shop_result", {
        success=ok,
        code=ok and "success" or (called and failureCode or "delivery_failed"),
        entry_id=entryID
    })
    self.busy[id] = nil
end

function IslandShop:CheckProximity()
    for id = 0, DOTA_MAX_TEAM_PLAYERS - 1 do
        if PlayerResource:IsValidPlayerID(id) then
            local player = PlayerResource:GetPlayer(id)
            local current = self:GetContext(id).nearby
            if player and self.nearby[id] ~= current then
                self.nearby[id] = current
                self:Send(player, "island_shop_proximity", { nearby=current })
            end
        end
    end
    return 0.25
end

function IslandShop:Init()
    for _, entry in ipairs(self.CATALOG) do
        local key = string.format("slot_%02d", entry.slot)
        CustomNetTables:SetTableValue("island_shop_catalog", key, {
            slot=entry.slot,
            entry_id=entry.id,
            name=entry.name or "#island_shop_coming_soon",
            description=entry.description or "#island_shop_coming_soon_desc",
            icon=entry.icon or "file://{images}/items/pumpkin_coin.png",
            price=entry.price or 0,
            max_charges=entry.max_charges or 0,
            enabled=entry.enabled == true
        })
    end
    CustomGameEventManager:RegisterListener("island_shop_request_context", function(source, data)
        local player = playerFromEvent(source, data)
        if player then self:Send(player, "island_shop_context", {}) end
    end)
    CustomGameEventManager:RegisterListener("island_shop_purchase", function(source, data) self:Purchase(source, data) end)
    GameRules:GetGameModeEntity():SetContextThink("IslandShopProximity", function() return self:CheckProximity() end, 0.25)
end

return IslandShop
