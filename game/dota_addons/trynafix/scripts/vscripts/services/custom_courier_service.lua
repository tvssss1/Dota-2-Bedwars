require("services/base_utils")

if CustomCourierService == nil then
    CustomCourierService = class({})
end

CustomCourierService.UNIT_NAME = "npc_dota_courier"
CustomCourierService.RESPAWN_TIME = 20
CustomCourierService.DELIVERY_RANGE = 225
CustomCourierService.BASE_PICKUP_RANGE = 225
CustomCourierService.STASH_FIRST_SLOT = 9
CustomCourierService.STASH_LAST_SLOT = 14

CustomCourierService.DELIVER_ABILITY = "courier_take_stash_and_transfer_items"
CustomCourierService.RETURN_ABILITY = "courier_return_to_base"
CustomCourierService.PICKUP_ABILITY = "courier_take_stash_items"
CustomCourierService.RETURN_STASH_ABILITY = "courier_return_stash_items"

-- These stock actions depend on Valve's Radiant/Dire fountain or shops, none
-- of which exist in this map. Keep the real courier entity, but never allow
-- those routes to run.
CustomCourierService.UNSUPPORTED_NATIVE_ABILITIES = {
    courier_go_to_secretshop = true,
    courier_go_to_enemy_secretshop = true,
    courier_go_to_sideshop = true,
    courier_go_to_sideshop2 = true,
    courier_transfer_items_to_other_player = true,
    courier_queue_pickup_from_stash = true,
    courier_dequeue_pickup_from_stash = true,
    courier_autodeliver = true
}

local function validPlayerID(playerID)
    return playerID ~= nil
        and playerID >= 0
        and PlayerResource:IsValidPlayerID(playerID)
end

local function validUnit(unit)
    return unit and not unit:IsNull()
end

function CustomCourierService:Init()
    if self.initialized then return end
    self.initialized = true
    self.couriers = self.couriers or {}

    ListenToGameEvent("entity_killed", function(event) self:OnEntityKilled(event) end, nil)
    ListenToGameEvent("npc_spawned", function(event) self:OnNPCSpawned(event) end, nil)
end

function CustomCourierService:GetOwnerHero(playerID)
    if not validPlayerID(playerID) then return nil end
    local hero = PlayerResource:GetSelectedHeroEntity(playerID)
    if validUnit(hero) then return hero end
    local player = PlayerResource:GetPlayer(playerID)
    hero = player and player:GetAssignedHero() or nil
    return validUnit(hero) and hero or nil
end

function CustomCourierService:GetCourier(playerID)
    local data = self.couriers and self.couriers[playerID] or nil
    return data and validUnit(data.unit) and data.unit or nil
end

function CustomCourierService:HasCourier(playerID)
    return self.couriers and self.couriers[playerID] ~= nil
end

function CustomCourierService:SendError(playerID, message)
    if not validPlayerID(playerID) then return end
    local player = PlayerResource:GetPlayer(playerID)
    if player then
        CustomGameEventManager:Send_ServerToPlayer(player, "ShowError", { message=message })
        EmitSoundOnClient("General.Cancel", player)
    end
end

function CustomCourierService:ConfigureCourier(courier, playerID, hero, moveToBase)
    if not validUnit(courier) or not validPlayerID(playerID) then return false end
    hero = validUnit(hero) and hero or self:GetOwnerHero(playerID)
    if not hero then return false end

    courier._trynafixCourierOwnerID = playerID
    courier:SetOwner(hero)
    courier:SetControllableByPlayer(playerID, true)
    if courier.SetUnitCanRespawn then courier:SetUnitCanRespawn(true) end

    -- SpawnCourierAtPosition creates the engine-owned courier that is attached
    -- to the player loadout and recognized by dota_select_courier. Preserve its
    -- normal UI/bind abilities, but hide actions that require absent map shops.
    for abilityName in pairs(self.UNSUPPORTED_NATIVE_ABILITIES) do
        local ability = courier:FindAbilityByName(abilityName)
        if ability and not ability:IsNull() then
            ability:SetActivated(false)
            if ability.SetHidden then ability:SetHidden(true) end
        end
    end

    for _, abilityName in ipairs({
        self.RETURN_ABILITY,
        self.DELIVER_ABILITY,
        self.PICKUP_ABILITY,
        self.RETURN_STASH_ABILITY
    }) do
        local ability = courier:FindAbilityByName(abilityName)
        if not ability then ability = courier:AddAbility(abilityName) end
        if ability and not ability:IsNull() then
            ability:SetLevel(1)
            ability:SetActivated(true)
            -- Valve's global Deliver Items button invokes a hidden unit-target
            -- ability. Return, Retrieve, and Return to Stash stay visible.
            if ability.SetHidden then ability:SetHidden(abilityName == self.DELIVER_ABILITY) end
        end
    end

    if moveToBase then
        local basePosition = BaseUtils:GetTeamBasePosition(courier:GetTeamNumber())
        if basePosition then FindClearSpaceForUnit(courier, basePosition, true) end
    end
    return true
end

function CustomCourierService:PurchaseCourier(playerID, hero)
    if not validPlayerID(playerID) or not validUnit(hero) then return false, "delivery_failed" end
    if self:HasCourier(playerID) then return false, "courier_owned" end

    local basePosition = BaseUtils:GetTeamBasePosition(hero:GetTeamNumber())
    if not basePosition then return false, "courier_base_missing" end

    local player = PlayerResource:GetPlayer(playerID)
    if not player or not player.SpawnCourierAtPosition then return false, "delivery_failed" end

    -- This is Valve's player-courier spawn path. Unlike CreateUnitByName, it
    -- registers the courier for the normal courier keybinds and applies the
    -- courier equipped in this player's Dota loadout.
    local courier = player:SpawnCourierAtPosition(basePosition)
    if not validUnit(courier) then return false, "delivery_failed" end

    self.couriers[playerID] = {
        unit = courier,
        team = hero:GetTeamNumber(),
        respawning = false
    }
    courier._trynafixCourierOwnerID = playerID
    if courier.UpgradeCourier then courier:UpgradeCourier(10) end
    self:ConfigureCourier(courier, playerID, hero, true)
    return true
end

function CustomCourierService:CancelDelivery(courier)
    if not validUnit(courier) then return end
    courier._trynafixDeliverySequence = (courier._trynafixDeliverySequence or 0) + 1
    courier._trynafixDelivering = false
end

function CustomCourierService:IssueOrder(courier, order)
    if not validUnit(courier) then return end
    courier._trynafixInternalOrder = true
    order.UnitIndex = courier:entindex()
    order.Queue = false
    ExecuteOrderFromTable(order)
    courier._trynafixInternalOrder = false
end

function CustomCourierService:ReturnToBase(courier)
    if not validUnit(courier) or not courier:IsAlive() then return false end
    self:CancelDelivery(courier)
    local basePosition = BaseUtils:GetTeamBasePosition(courier:GetTeamNumber())
    if not basePosition then
        self:SendError(courier._trynafixCourierOwnerID, "#custom_error_base_spawn_missing")
        return false
    end
    self:IssueOrder(courier, {
        OrderType = DOTA_UNIT_ORDER_MOVE_TO_POSITION,
        Position = basePosition
    })
    return true
end

function CustomCourierService:CountItems(unit)
    if not validUnit(unit) then return 0 end
    local count = 0
    for slot = 0, 8 do
        if unit:GetItemInSlot(slot) then count = count + 1 end
    end
    return count
end

function CustomCourierService:CountStashItems(hero)
    if not validUnit(hero) then return 0 end
    local count = 0
    for slot = self.STASH_FIRST_SLOT, self.STASH_LAST_SLOT do
        if hero:GetItemInSlot(slot) then count = count + 1 end
    end
    return count
end

function CustomCourierService:FindFreeInventorySlot(unit)
    if not validUnit(unit) then return nil end
    for slot = 0, 8 do
        if unit:GetItemInSlot(slot) == nil then return slot end
    end
    return nil
end

function CustomCourierService:FindFreeStashSlot(hero)
    if not validUnit(hero) then return nil end
    for slot = self.STASH_FIRST_SLOT, self.STASH_LAST_SLOT do
        if hero:GetItemInSlot(slot) == nil then return slot end
    end
    return nil
end

function CustomCourierService:CloneItemForUnit(source, recipient, fallbackPurchaser)
    if not source or source:IsNull() or not validUnit(recipient) then return nil end
    local purchaser = source.GetPurchaser and source:GetPurchaser() or nil
    if not validUnit(purchaser) then purchaser = fallbackPurchaser end
    local clone = CreateItem(source:GetAbilityName(), recipient, purchaser or recipient)
    if not clone then return nil end

    if source.GetLevel and clone.SetLevel then clone:SetLevel(source:GetLevel()) end
    if source.GetCurrentCharges and clone.SetCurrentCharges then
        clone:SetCurrentCharges(source:GetCurrentCharges())
    end
    if source.GetSecondaryCharges and clone.SetSecondaryCharges then
        clone:SetSecondaryCharges(source:GetSecondaryCharges())
    end
    if source.GetPurchaseTime and clone.SetPurchaseTime then
        clone:SetPurchaseTime(source:GetPurchaseTime())
    end
    if source.IsCombineLocked and clone.SetCombineLocked then
        clone:SetCombineLocked(source:IsCombineLocked())
    end
    if source.IsDroppable and clone.SetDroppable then
        clone:SetDroppable(source:IsDroppable())
    end
    if source.IsSellable and clone.SetSellable then
        clone:SetSellable(source:IsSellable())
    end
    local cooldown = source.GetCooldownTimeRemaining and source:GetCooldownTimeRemaining() or 0
    if cooldown > 0 then clone:StartCooldown(cooldown) end
    if validUnit(purchaser) then clone:SetPurchaser(purchaser) end

    local added = recipient:AddItem(clone)
    if not added then
        UTIL_Remove(clone)
        return nil
    end
    return added
end

function CustomCourierService:TransferStashItems(hero, courier)
    local moved = 0
    -- Home-shop purchases live in the owner's stash (slots 9-14). Recreate
    -- them on the courier only while it is at this mode's permanent base,
    -- then remove the original stash handles after each successful add.
    for slot = self.STASH_LAST_SLOT, self.STASH_FIRST_SLOT, -1 do
        if self:FindFreeInventorySlot(courier) == nil then break end
        local item = hero:GetItemInSlot(slot)
        if item and not item:IsNull() then
            local pickedUp = self:CloneItemForUnit(item, courier, hero)
            if pickedUp then
                hero:RemoveItem(item)
                moved = moved + 1
            end
        end
    end
    return moved, self:CountStashItems(hero)
end

function CustomCourierService:TransferItemsToHero(courier, hero)
    local moved = 0
    -- Iterate backwards because destroying the delivered source handle can
    -- compact a courier inventory on some engine versions.
    for slot = 8, 0, -1 do
        if self:FindFreeInventorySlot(hero) == nil then break end
        local item = courier:GetItemInSlot(slot)
        if item and not item:IsNull() then
            local delivered = self:CloneItemForUnit(item, hero, hero)
            if delivered then
                courier:RemoveItem(item)
                moved = moved + 1
            end
        end
    end
    return moved, self:CountItems(courier)
end

function CustomCourierService:TransferCourierItemsToStash(courier, hero)
    local moved = 0
    for slot = 8, 0, -1 do
        local stashSlot = self:FindFreeStashSlot(hero)
        if stashSlot == nil then break end
        local item = courier:GetItemInSlot(slot)
        if item and not item:IsNull() then
            local returned = self:CloneItemForUnit(item, hero, hero)
            if returned then
                -- AddItem normally chooses the first open hero slot. Move the
                -- returned handle into the specific free stash slot so this
                -- action retains Dota's Return Items to Stash semantics.
                if not returned:IsNull() then
                    local returnedSlot = nil
                    for heroSlot = 0, 16 do
                        if hero:GetItemInSlot(heroSlot) == returned then
                            returnedSlot = heroSlot
                            break
                        end
                    end
                    if returnedSlot and returnedSlot ~= stashSlot then
                        hero:SwapItems(returnedSlot, stashSlot)
                    end
                end
                courier:RemoveItem(item)
                moved = moved + 1
            end
        end
    end
    return moved, self:CountItems(courier)
end

function CustomCourierService:BeginPickupFromStash(courier)
    if not validUnit(courier) or not courier:IsAlive() then return false end
    local playerID = courier._trynafixCourierOwnerID
    if not validPlayerID(playerID) then return false end
    local hero = self:GetOwnerHero(playerID)
    if not validUnit(hero) then return false end
    if self:CountStashItems(hero) <= 0 then
        self:SendError(playerID, "#custom_courier_error_stash_empty")
        return false
    end
    if self:FindFreeInventorySlot(courier) == nil then
        self:SendError(playerID, "#custom_courier_error_courier_full")
        return false
    end

    local basePosition = BaseUtils:GetTeamBasePosition(courier:GetTeamNumber())
    if not basePosition then
        self:SendError(playerID, "#custom_error_base_spawn_missing")
        return false
    end

    self:CancelDelivery(courier)
    local sequence = courier._trynafixDeliverySequence
    courier._trynafixDelivering = true
    local thinkName = "TrynafixCourierBaseAction_" .. tostring(courier:entindex())
    courier:SetContextThink(thinkName, function()
        if not validUnit(courier) or not courier:IsAlive()
            or courier._trynafixDeliverySequence ~= sequence then return nil end

        basePosition = BaseUtils:GetTeamBasePosition(courier:GetTeamNumber())
        if not basePosition then
            courier._trynafixDelivering = false
            self:SendError(playerID, "#custom_error_base_spawn_missing")
            return nil
        end
        if (courier:GetAbsOrigin() - basePosition):Length2D() > self.BASE_PICKUP_RANGE then
            self:IssueOrder(courier, {
                OrderType = DOTA_UNIT_ORDER_MOVE_TO_POSITION,
                Position = basePosition
            })
            return 0.25
        end

        local moved, remaining = self:TransferStashItems(hero, courier)
        courier._trynafixDelivering = false
        if moved <= 0 then
            self:SendError(playerID, "#custom_courier_error_courier_full")
        elseif remaining > 0 then
            self:SendError(playerID, "#custom_courier_error_pickup_partial")
        end
        return nil
    end, 0)
    return true
end

function CustomCourierService:BeginReturnItemsToStash(courier)
    if not validUnit(courier) or not courier:IsAlive() then return false end
    local playerID = courier._trynafixCourierOwnerID
    if not validPlayerID(playerID) then return false end
    local hero = self:GetOwnerHero(playerID)
    if not validUnit(hero) then return false end
    if self:CountItems(courier) <= 0 then
        self:SendError(playerID, "#custom_courier_error_empty")
        return false
    end
    if self:FindFreeStashSlot(hero) == nil then
        self:SendError(playerID, "#custom_courier_error_stash_full")
        return false
    end

    local basePosition = BaseUtils:GetTeamBasePosition(courier:GetTeamNumber())
    if not basePosition then
        self:SendError(playerID, "#custom_error_base_spawn_missing")
        return false
    end

    self:CancelDelivery(courier)
    local sequence = courier._trynafixDeliverySequence
    courier._trynafixDelivering = true
    local thinkName = "TrynafixCourierBaseAction_" .. tostring(courier:entindex())
    courier:SetContextThink(thinkName, function()
        if not validUnit(courier) or not courier:IsAlive()
            or courier._trynafixDeliverySequence ~= sequence then return nil end

        basePosition = BaseUtils:GetTeamBasePosition(courier:GetTeamNumber())
        if not basePosition then
            courier._trynafixDelivering = false
            self:SendError(playerID, "#custom_error_base_spawn_missing")
            return nil
        end
        if (courier:GetAbsOrigin() - basePosition):Length2D() > self.BASE_PICKUP_RANGE then
            self:IssueOrder(courier, {
                OrderType = DOTA_UNIT_ORDER_MOVE_TO_POSITION,
                Position = basePosition
            })
            return 0.25
        end

        local moved, remaining = self:TransferCourierItemsToStash(courier, hero)
        courier._trynafixDelivering = false
        if moved <= 0 then
            self:SendError(playerID, "#custom_courier_error_stash_full")
        elseif remaining > 0 then
            self:SendError(playerID, "#custom_courier_error_stash_partial")
        end
        return nil
    end, 0)
    return true
end

function CustomCourierService:BeginDelivery(courier)
    if not validUnit(courier) or not courier:IsAlive() then return false end
    local playerID = courier._trynafixCourierOwnerID
    if not validPlayerID(playerID) then return false end
    local hero = self:GetOwnerHero(playerID)
    if not validUnit(hero) or not hero:IsAlive() then
        self:SendError(playerID, "#custom_courier_error_owner_dead")
        self:ReturnToBase(courier)
        return false
    end

    local courierItems = self:CountItems(courier)
    local stashItems = self:CountStashItems(hero)
    if courierItems <= 0 and stashItems <= 0 then
        self:SendError(playerID, "#custom_courier_error_empty")
        self:ReturnToBase(courier)
        return false
    end

    local basePosition = BaseUtils:GetTeamBasePosition(courier:GetTeamNumber())
    if not basePosition and stashItems > 0 then
        self:SendError(playerID, "#custom_error_base_spawn_missing")
        return false
    end

    self:CancelDelivery(courier)
    local sequence = courier._trynafixDeliverySequence
    courier._trynafixDelivering = true
    -- This reproduces Dota's normal Deliver Items shortcut without relying on
    -- its hardcoded fountain: collect the owner's ordinary shop purchases at
    -- the permanent team base, then fly them to the owner.
    local stage = stashItems > 0 and self:FindFreeInventorySlot(courier) ~= nil
        and "pickup" or "deliver"
    local thinkName = "TrynafixCourierDelivery_" .. tostring(courier:entindex())
    courier:SetContextThink(thinkName, function()
        if not validUnit(courier) or not courier:IsAlive()
            or courier._trynafixDeliverySequence ~= sequence then return nil end

        local ownerHero = self:GetOwnerHero(playerID)
        if not validUnit(ownerHero) or not ownerHero:IsAlive() then
            courier._trynafixDelivering = false
            self:SendError(playerID, "#custom_courier_error_owner_dead")
            self:ReturnToBase(courier)
            return nil
        end

        if stage == "pickup" then
            basePosition = BaseUtils:GetTeamBasePosition(courier:GetTeamNumber())
            if not basePosition then
                courier._trynafixDelivering = false
                self:SendError(playerID, "#custom_error_base_spawn_missing")
                return nil
            end

            local hasRoom = self:FindFreeInventorySlot(courier) ~= nil
            if self:CountStashItems(ownerHero) <= 0 or not hasRoom then
                stage = "deliver"
            elseif (courier:GetAbsOrigin() - basePosition):Length2D() <= self.BASE_PICKUP_RANGE then
                self:TransferStashItems(ownerHero, courier)
                stage = "deliver"
            else
                self:IssueOrder(courier, {
                    OrderType = DOTA_UNIT_ORDER_MOVE_TO_POSITION,
                    Position = basePosition
                })
                return 0.25
            end
        end

        if self:CountItems(courier) <= 0 then
            self:SendError(playerID, "#custom_courier_error_empty")
            self:ReturnToBase(courier)
            return nil
        end

        if (courier:GetAbsOrigin() - ownerHero:GetAbsOrigin()):Length2D() <= self.DELIVERY_RANGE then
            local moved, remaining = self:TransferItemsToHero(courier, ownerHero)
            if moved <= 0 and remaining > 0 then
                self:SendError(playerID, "#custom_courier_error_inventory_full")
                self:ReturnToBase(courier)
            elseif remaining > 0 then
                self:SendError(playerID, "#custom_courier_error_partial")
                self:ReturnToBase(courier)
            elseif self:CountStashItems(ownerHero) > 0 then
                stage = "pickup"
                return 0
            else
                -- Clear the last MOVE_TO_TARGET order immediately. Without a
                -- new order it keeps tracking the hero after handing items off.
                self:ReturnToBase(courier)
            end
            return nil
        end

        self:IssueOrder(courier, {
            OrderType = DOTA_UNIT_ORDER_MOVE_TO_TARGET,
            TargetIndex = ownerHero:entindex()
        })
        return 0.25
    end, 0)
    return true
end

function CustomCourierService:OnExecuteOrder(order)
    if not order or not order.units then return true end
    for _, unitIndex in pairs(order.units) do
        local courier = EntIndexToHScript(tonumber(unitIndex) or -1)
        local playerID = validUnit(courier) and courier._trynafixCourierOwnerID or nil
        local data = validPlayerID(playerID) and self.couriers[playerID] or nil
        if data and data.unit == courier and not courier._trynafixInternalOrder then
            local abilityIndex = tonumber(order.entindex_ability)
            local ability = abilityIndex and EntIndexToHScript(abilityIndex) or nil
            local abilityName = ability and not ability:IsNull() and ability:GetAbilityName() or ""

            -- The normal Dota courier buttons and dota_courier_deliver bind
            -- still cast their stock abilities. Deliver is a unit-target cast;
            -- Return is no-target, so route by ability name rather than order.
            if abilityName == self.DELIVER_ABILITY then
                self:BeginDelivery(courier)
                return false
            elseif abilityName == self.RETURN_ABILITY then
                self:ReturnToBase(courier)
                return false
            elseif abilityName == self.PICKUP_ABILITY then
                self:BeginPickupFromStash(courier)
                return false
            elseif abilityName == self.RETURN_STASH_ABILITY then
                self:BeginReturnItemsToStash(courier)
                return false
            elseif self.UNSUPPORTED_NATIVE_ABILITIES[abilityName] then
                return false
            elseif abilityName == "" and courier._trynafixDelivering then
                self:CancelDelivery(courier)
            elseif courier._trynafixDelivering then
                -- Burst, Shield, and manual Transfer should not interrupt the
                -- route; ordinary player movement/attack orders should.
                local routeSafeAbilities = {
                    courier_burst = true,
                    courier_shield = true,
                    courier_transfer_items = true
                }
                if not routeSafeAbilities[abilityName] then self:CancelDelivery(courier) end
            end
        end
    end
    return true
end

function CustomCourierService:OnEntityKilled(event)
    local killed = event and event.entindex_killed and EntIndexToHScript(event.entindex_killed) or nil
    if not validUnit(killed) then return end
    local playerID = killed._trynafixCourierOwnerID
    local data = validPlayerID(playerID) and self.couriers[playerID] or nil
    if not data or data.unit ~= killed then return end

    self:CancelDelivery(killed)
    data.respawning = true
    if killed.SetTimeUntilRespawn then killed:SetTimeUntilRespawn(self.RESPAWN_TIME) end
    local expectedUnit = killed
    Timers:CreateTimer(self.RESPAWN_TIME, function()
        if GameRules:State_Get() >= DOTA_GAMERULES_STATE_POST_GAME then return nil end
        if data.unit ~= expectedUnit or not validUnit(expectedUnit) or expectedUnit:IsAlive() then return nil end
        if GameSetup and GameSetup.IsTeamEliminated and GameSetup:IsTeamEliminated(data.team) then return nil end

        expectedUnit:RespawnUnit()
        data.respawning = false
        Timers:CreateTimer(0, function()
            if validUnit(expectedUnit) then
                self:ConfigureCourier(expectedUnit, playerID, self:GetOwnerHero(playerID), true)
            end
        end)
        return nil
    end)
end

function CustomCourierService:OnNPCSpawned(event)
    local unit = event and event.entindex and EntIndexToHScript(event.entindex) or nil
    if not validUnit(unit) then return end
    local playerID = unit._trynafixCourierOwnerID
    if not validPlayerID(playerID) then return end
    local data = self.couriers[playerID]
    if data and data.unit == unit then
        data.unit = unit
        data.respawning = false
        self:ConfigureCourier(unit, playerID, self:GetOwnerHero(playerID), true)
    end
end

return CustomCourierService
