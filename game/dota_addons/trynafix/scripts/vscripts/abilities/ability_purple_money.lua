

ability_spawn_purple = class({})

LinkLuaModifier(
    "modifier_spawn_purple_money",
    "abilities/ability_purple_money",
    LUA_MODIFIER_MOTION_NONE
)

function ability_spawn_purple:GetIntrinsicModifierName()
    return "modifier_spawn_purple_money"
end

--------------------------------------------------------------------------------

modifier_spawn_purple_money = class({})

function modifier_spawn_purple_money:IsHidden()
    return true
end

function modifier_spawn_purple_money:IsPurgable()
    return false
end

function modifier_spawn_purple_money:RemoveOnDeath()
    return false
end

function modifier_spawn_purple_money:OnCreated()
    if not IsServer() then return end

    self.nextSpawnTime = 30
    self:PublishNextSpawnTime()
    self:StartIntervalThink(0.25)
end

-- Panorama reads this server-owned timestamp, so the label and the actual
-- generator can never drift onto different 30-second cycles.
function modifier_spawn_purple_money:PublishNextSpawnTime()
    CustomNetTables:SetTableValue("arcane_chests", "timing", {
        next_spawn_time = self.nextSpawnTime,
        interval = 30
    })
end

function modifier_spawn_purple_money:OnIntervalThink()
    if not IsServer() then return end

    if GameRules:State_Get() ~= DOTA_GAMERULES_STATE_GAME_IN_PROGRESS then return end
    local dotaTime = GameRules:GetDOTATime(false, false)
    if dotaTime < self.nextSpawnTime then return end

    -- Stay locked to 00:30, 01:00, 01:30, etc. instead of counting from
    -- chest creation during pregame.
    self.nextSpawnTime = (math.floor(dotaTime / 30) + 1) * 30
    self:PublishNextSpawnTime()

    local parent = self:GetParent()

    local newItem = CreateItem("item_purple_money", nil, nil)
    if not newItem then return end
    newItem:SetActivated(true)
    newItem:SetCurrentCharges(1)
    local spawnpoint = parent:GetAbsOrigin()
    local drop = CreateItemOnPositionForLaunch(spawnpoint, newItem)
    if not drop or drop:IsNull() then UTIL_Remove(newItem); return end
    drop:SetModel("models/props_gameplay/rune_arcane.vmdl")

    newItem:LaunchLootInitialHeight(false, 0.0, 200.0, 0.5, spawnpoint + RandomVector(RandomInt(100, 150)))
end
