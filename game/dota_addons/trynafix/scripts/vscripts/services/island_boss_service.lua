if IslandBossService == nil then IslandBossService = { slots = {}, bossUnits = {}, started = false } end

IslandBossService.WAVE_INTERVAL = 60
IslandBossService.RETRY_DELAY = 10
IslandBossService.DROP_CHANCE = 50
IslandBossService.DROP_LIFETIME = 120
-- Each mid zombie must be a realistic solo target even for low-damage heroes
-- such as Chen. Capped scaling prevents a surviving wave from becoming an
-- unkillable wall later in the match.
IslandBossService.BASE_HEALTH = 325
IslandBossService.HEALTH_PER_MINUTE = 50
IslandBossService.MAX_HEALTH = 1000
IslandBossService.BASE_DAMAGE_MIN = 12
IslandBossService.BASE_DAMAGE_MAX = 18
IslandBossService.DAMAGE_PER_MINUTE = 2
IslandBossService.MAX_DAMAGE_BONUS = 20
IslandBossService.BASE_ARMOR = 0
IslandBossService.ARMOR_EVERY_MINUTES = 10
IslandBossService.MAX_ARMOR = 2
IslandBossService.BASE_XP = 50
IslandBossService.XP_PER_MINUTE = 8
IslandBossService.BASE_MODEL_SCALE = 1.1
IslandBossService.MODEL_SCALE_PER_MINUTE = 0.025
IslandBossService.MAX_MODEL_SCALE = 2

function IslandBossService:ApplyMinuteScaling(unit, minute)
    if not unit or unit:IsNull() or not unit:IsAlive() then return end

    minute = math.max(0, math.floor(minute or 0))
    local oldMaxHealth = math.max(1, unit:GetMaxHealth())
    local healthPercent = math.max(0.01, unit:GetHealth() / oldMaxHealth)
    local maxHealth = math.min(self.MAX_HEALTH, self.BASE_HEALTH + minute * self.HEALTH_PER_MINUTE)
    local damageBonus = math.min(self.MAX_DAMAGE_BONUS, minute * self.DAMAGE_PER_MINUTE)

    unit:SetBaseMaxHealth(maxHealth)
    unit:SetMaxHealth(maxHealth)
    unit:SetHealth(math.max(1, math.floor(maxHealth * healthPercent)))
    unit:SetBaseDamageMin(self.BASE_DAMAGE_MIN + damageBonus)
    unit:SetBaseDamageMax(self.BASE_DAMAGE_MAX + damageBonus)
    unit:SetPhysicalArmorBaseValue(math.min(
        self.MAX_ARMOR,
        self.BASE_ARMOR + math.floor(minute / self.ARMOR_EVERY_MINUTES)
    ))
    unit:SetDeathXP(self.BASE_XP + minute * self.XP_PER_MINUTE)
    unit:SetModelScale(math.min(
        self.MAX_MODEL_SCALE,
        self.BASE_MODEL_SCALE + minute * self.MODEL_SCALE_PER_MINUTE
    ))
    unit._islandScaleMinute = minute
end

function IslandBossService:SpawnAtSlot(slot, minute)
    if not slot or not slot.marker or slot.marker:IsNull() then return end

    local boss = CreateUnitByName(
        "npc_island_miniboss",
        slot.marker:GetAbsOrigin(),
        true,
        nil,
        nil,
        DOTA_TEAM_NEUTRALS
    )
    if not boss then
        print("[IslandBossService] Failed to create creep for " .. slot.name .. "; retrying.")
        Timers:CreateTimer(self.RETRY_DELAY, function()
            if GameRules:State_Get() < DOTA_GAMERULES_STATE_POST_GAME then self:SpawnAtSlot(slot, minute) end
        end)
        return
    end

    -- Let CDOTA_BaseNPC_Creep_Neutral own aggro, combat and its native leash.
    boss:SetIdleAcquire(true)
    -- Slots are 220 units from the center. This radius lets a hero pull one
    -- zombie from the outside without automatically aggroing the whole pack.
    boss:SetAcquisitionRange(275)
    self:ApplyMinuteScaling(boss, minute)

    self.bossUnits[boss:entindex()] = {
        unit = boss,
        home = slot.marker:GetAbsOrigin()
    }
end

function IslandBossService:HasLivingWave()
    local living = false
    for entindex, data in pairs(self.bossUnits) do
        local unit = data.unit
        if unit and not unit:IsNull() and unit:IsAlive() then
            living = true
        else
            self.bossUnits[entindex] = nil
        end
    end
    return living
end

function IslandBossService:SpawnWave()
    if GameRules:State_Get() >= DOTA_GAMERULES_STATE_POST_GAME then return nil end
    local minute = self.currentMinute or 0

    -- Existing survivors become stronger at the same minute boundary as spawning.
    for _, data in pairs(self.bossUnits) do
        self:ApplyMinuteScaling(data.unit, minute)
    end

    -- Never stack waves: even one survivor keeps the next group from spawning.
    if not self:HasLivingWave() then
        for _, slot in ipairs(self.slots) do self:SpawnAtSlot(slot, minute) end
    end
    self.currentMinute = minute + 1
    return self.WAVE_INTERVAL
end

function IslandBossService:DropPumpkinCoin(origin)
    local item = CreateItem("item_pumpkin_coin", nil, nil)
    if not item then return end
    item:SetActivated(true)
    item:SetCurrentCharges(1)

    local container = CreateItemOnPositionForLaunch(origin, item)
    if not container or container:IsNull() then
        UTIL_Remove(item)
        return
    end

    container:SetModel("models/props_gameplay/pumpkin_rune.vmdl")
    item:LaunchLootInitialHeight(
        false,
        0.0,
        200.0,
        0.5,
        origin + RandomVector(RandomInt(100, 150))
    )

    Timers:CreateTimer(self.DROP_LIFETIME, function()
        if container and not container:IsNull() then UTIL_Remove(container) end
    end)
end

function IslandBossService:OnKilled(event)
    local killed = event.entindex_killed and EntIndexToHScript(event.entindex_killed)
    if not killed or killed:IsNull() then return end

    local entindex = killed:entindex()
    if not self.bossUnits[entindex] then return end
    self.bossUnits[entindex] = nil

    if RandomInt(1, 100) <= self.DROP_CHANCE then
        self:DropPumpkinCoin(killed:GetAbsOrigin())
    end
end

function IslandBossService:Start()
    if self.started then return end
    self.started = true
    self.slots = {}
    self.currentMinute = 0

    for index = 1, 4 do
        local name = "IslandMiniBossSpawn" .. index
        local marker = Entities:FindByName(nil, name)
        if marker then
            table.insert(self.slots, { name=name, marker=marker })
        else
            print("[IslandBossService] Missing marker " .. name .. "; wave slot disabled.")
        end
    end

    -- GAME_IN_PROGRESS begins at 00:00, so the first callback is the 00:00 wave.
    Timers:CreateTimer(function() return self:SpawnWave() end)
end

function IslandBossService:Init()
    self.bossUnits = self.bossUnits or {}
    ListenToGameEvent("entity_killed", function(event) self:OnKilled(event) end, nil)
    ListenToGameEvent("game_rules_state_change", function()
        if GameRules:State_Get() == DOTA_GAMERULES_STATE_GAME_IN_PROGRESS then self:Start() end
    end, nil)
    if GameRules:State_Get() == DOTA_GAMERULES_STATE_GAME_IN_PROGRESS then self:Start() end
end

return IslandBossService
