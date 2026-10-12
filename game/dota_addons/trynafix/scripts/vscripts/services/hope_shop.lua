require("services/purple_currency")
require("services/bed_utils")
require("services/base_utils")

if HopeShop == nil then HopeShop = { busy = {} } end
HopeShop.CHECKOUT_RADIUS = 900
HopeShop.CATALOG = {
    tower={name="#hope_shop_tower_name",description="#hope_shop_tower_desc",icon="file://{images}/tower_png.png",price=8,delivery="item",item="item_custom_tower"},
    recall={name="#hope_shop_recall_name",description="#hope_shop_recall_desc",icon="item_tpscroll",price=3,delivery="item",item="item_custom_tp"},
    raid={name="#hope_shop_raid_name",description="#hope_shop_raid_desc",icon="file://{images}/bed_raiders.png",price=5,delivery="item",item="item_bed_raiders"},
    repair={name="#hope_shop_repair_name",description="#hope_shop_repair_desc",icon="item_repair_kit",price=5,delivery="service"},
    shield={name="#hope_shop_shield_name",description="#hope_shop_shield_desc",icon="item_crimson_guard",price=7,delivery="service"}
}

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
function HopeShop:GetContext(id)
    local hero=PlayerResource:GetSelectedHeroEntity(id)
    local nearBase=hero and hero:IsAlive() and BaseUtils:IsNearTeamBase(hero,self.CHECKOUT_RADIUS) or false
    return {can_checkout=nearBase==true,nearby_base=nearBase==true,balance=PurpleCurrency:Get(id)}
end
function HopeShop:Send(player,event,extra)
    local data=self:GetContext(player:GetPlayerID()); for k,v in pairs(extra or {}) do data[k]=v end
    CustomGameEventManager:Send_ServerToPlayer(player,event,data)
end
function HopeShop:DeliverItem(hero,itemName)
    local item=CreateItem(itemName,hero,hero); if not item then return false end
    item:SetActivated(true)
    if item:GetCurrentCharges()<=0 then item:SetCurrentCharges(1) end
    local free=false; for slot=0,8 do if hero:GetItemInSlot(slot)==nil then free=true; break end end
    if free then hero:AddItem(item); return true end
    local container=CreateItemOnPositionSync(hero:GetAbsOrigin(),item)
    if container then return true end
    UTIL_Remove(item)
    return false
end
function HopeShop:ApplyService(entry,bed,hero)
    if entry=="repair" then
        if bed:GetHealth()>=bed:GetMaxHealth() then return false,"bed_full" end
        bed:SetHealth(math.min(bed:GetMaxHealth(),bed:GetHealth()+1)); return true
    end
    if entry=="shield" then
        if bed:HasModifier("modifier_home_bed_barrier") then return false,"shield_active" end
        local ability=hero:FindAbilityByName("ability_home_bed_barrier") or hero:AddAbility("ability_home_bed_barrier")
        if not ability then return false,"delivery_failed" end
        ability:SetLevel(1)
        return ability:ApplyBarrier(bed),"delivery_failed"
    end
    return false,"invalid_entry"
end
function HopeShop:Purchase(source,data)
    local player,id=playerFromEvent(source,data); if not player or self.busy[id] then return end
    self.busy[id]=true
    local entryID=type(data)=="table" and tostring(data.entry_id or "") or ""
    local entry=self.CATALOG[entryID]; local hero=PlayerResource:GetSelectedHeroEntity(id)
    local nearBase=hero and hero:IsAlive() and BaseUtils:IsNearTeamBase(hero,self.CHECKOUT_RADIUS) or false
    local code=nil
    if not entry then code="invalid_entry" elseif not hero or hero:IsNull() or not hero:IsAlive() then code="hero_dead"
    elseif not nearBase then code="no_base"
    elseif PurpleCurrency:Get(id)<entry.price then code="insufficient_funds" end
    if code then self:Send(player,"hope_shop_result",{success=false,code=code}); self.busy[id]=nil; return end
    if not PurpleCurrency:Debit(id,entry.price) then self:Send(player,"hope_shop_result",{success=false,code="insufficient_funds"}); self.busy[id]=nil; return end
    local ok,fail
    local callOK
    callOK,ok,fail=pcall(function()
        if entry.delivery=="item" then return self:DeliverItem(hero,entry.item),"delivery_failed" end
        local ownBed=BedUtils:NearestLivingBed(hero:GetAbsOrigin(),FIND_UNITS_EVERYWHERE,hero:GetTeamNumber())
        if not ownBed then return false,"own_bed_destroyed" end
        return self:ApplyService(entryID,ownBed,hero)
    end)
    if not callOK then ok=false; fail="delivery_failed" end
    if ok then
        PurpleCurrency:RewardSpend(id,entry.price)
    else
        PurpleCurrency:Credit(id,entry.price)
    end
    self:Send(player,"hope_shop_result",{success=ok==true,code=ok and "success" or fail,entry_id=entryID})
    self.busy[id]=nil
end
function HopeShop:Init()
    for id,entry in pairs(self.CATALOG) do
        CustomNetTables:SetTableValue("hope_shop_catalog",id,{name=entry.name,description=entry.description,icon=entry.icon,price=entry.price,delivery=entry.delivery})
    end
    CustomGameEventManager:RegisterListener("hope_shop_request_context",function(source,data) local p=playerFromEvent(source,data); if p then self:Send(p,"hope_shop_context",{}) end end)
    CustomGameEventManager:RegisterListener("hope_shop_purchase",function(source,data) self:Purchase(source,data) end)
end
return HopeShop
