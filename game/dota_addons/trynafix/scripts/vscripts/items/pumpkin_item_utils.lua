if PumpkinItemUtils == nil then
    PumpkinItemUtils = {}
end

function PumpkinItemUtils:IsValidItem(item)
    return item ~= nil and not item:IsNull()
end

function PumpkinItemUtils:Lock(item)
    if not self:IsValidItem(item) then return false end
    item:SetActivated(false)
    if item.SetDroppable then item:SetDroppable(false) end
    return true
end

function PumpkinItemUtils:Unlock(item)
    if not self:IsValidItem(item) then return false end
    item:SetActivated(true)
    if item.SetDroppable then item:SetDroppable(true) end
    return true
end

function PumpkinItemUtils:SpendCharge(item)
    if not self:IsValidItem(item) then return end

    -- SpendCharge() is inconsistent for item_lua stacks across engine builds:
    -- it may leave ItemPermanent=0 items at one charge, or leave an item that
    -- was locked during an asynchronous effect permanently deactivated.
    local remaining = math.max(0, item:GetCurrentCharges() - 1)
    if remaining > 0 then
        item:SetCurrentCharges(remaining)
        self:Unlock(item)
    elseif self:IsValidItem(item) then
        item:SetCurrentCharges(0)
        UTIL_Remove(item)
    end
end

-- Asynchronous items need their ability handle until their projectile or
-- motion finishes. Debit immediately, keep the empty handle locked, then call
-- FinishImmediateSpend when the effect resolves.
function PumpkinItemUtils:SpendChargeImmediately(item)
    if not self:IsValidItem(item) then return false end
    local remaining = math.max(0, item:GetCurrentCharges() - 1)
    item:SetCurrentCharges(remaining)
    self:Lock(item)
    return true
end

function PumpkinItemUtils:FinishImmediateSpend(item)
    if not self:IsValidItem(item) then return end
    if item:GetCurrentCharges() > 0 then
        self:Unlock(item)
    else
        UTIL_Remove(item)
    end
end

return PumpkinItemUtils
