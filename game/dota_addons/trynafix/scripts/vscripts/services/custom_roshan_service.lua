local MapLocations = require("settings/map_locations")

if CustomRoshanService == nil then CustomRoshanService = {} end

CustomRoshanService.SPAWN_TIMES = { 300, 600, 900 }
CustomRoshanService.WAVES = {
    { health=2500, damageMin=45,  damageMax=55,  armor=3, magicResist=20, gold=200, xp=250, modelScale=0.72 },
    { health=5000, damageMin=70,  damageMax=85,  armor=6, magicResist=25, gold=300, xp=450, modelScale=0.86 },
    { health=8000, damageMin=100, damageMax=120, armor=9, magicResist=30, gold=400, xp=700, modelScale=1.00 }
}

function CustomRoshanService:FindOrCreateMarker()
    local marker = Entities:FindByName(nil, "CustomRoshanSpawn")
    if not marker then
        marker = SpawnEntityFromTableSynchronous("info_target", { targetname="CustomRoshanSpawn" })
    end
    if marker then
        marker:SetAbsOrigin(GetGroundPosition(MapLocations.GetMidCenter(), marker))
    end
    return marker
end

function CustomRoshanService:RemoveSurvivor()
    -- Clear tracking first so forced replacement can never be mistaken for a kill.
    local survivor = self.unit
    self.unit = nil
    if survivor and not survivor:IsNull() then UTIL_Remove(survivor) end
end

function CustomRoshanService:ApplyWaveStats(unit, waveIndex)
    local wave = self.WAVES[waveIndex]
    unit:SetBaseMaxHealth(wave.health)
    unit:SetMaxHealth(wave.health)
    unit:SetHealth(wave.health)
    unit:SetBaseDamageMin(wave.damageMin)
    unit:SetBaseDamageMax(wave.damageMax)
    unit:SetPhysicalArmorBaseValue(wave.armor)
    unit:SetBaseMagicalResistanceValue(wave.magicResist)
    unit:SetMinimumGoldBounty(wave.gold)
    unit:SetMaximumGoldBounty(wave.gold)
    unit:SetDeathXP(wave.xp)
    unit:SetModelScale(wave.modelScale)
    unit:SetIdleAcquire(true)
    unit:SetAcquisitionRange(700)
    local bash = unit:FindAbilityByName("ability_custom_roshan_bash")
    if bash then bash:SetLevel(waveIndex) end
    local slam = unit:FindAbilityByName("ability_custom_roshan_slam")
    if slam then slam:SetLevel(waveIndex) end
end

function CustomRoshanService:SpawnWave(waveIndex)
    if not self.marker or self.marker:IsNull() then self.marker = self:FindOrCreateMarker() end
    if not self.marker then
        print("[CustomRoshanService] CustomRoshanSpawn could not be created.")
        return false
    end
    self:RemoveSurvivor()
    local origin = GetGroundPosition(self.marker:GetAbsOrigin(), self.marker)
    local unit = CreateUnitByName("npc_custom_roshan", origin, true, nil, nil, DOTA_TEAM_NEUTRALS)
    if not unit then
        print("[CustomRoshanService] Failed to spawn wave " .. tostring(waveIndex) .. ".")
        return false
    end
    self.unit = unit
    self.waveIndex = waveIndex
    self:ApplyWaveStats(unit, waveIndex)
    FindClearSpaceForUnit(unit, origin, true)
    GameRules:SendCustomMessage("#custom_roshan_spawn_" .. tostring(waveIndex), 0, 0)
    EmitGlobalSound("RoshanDT.Scream")
    return true
end

function CustomRoshanService:TrySlam()
    local unit = self.unit
    if not unit or unit:IsNull() or not unit:IsAlive() then return end
    local ability = unit:FindAbilityByName("ability_custom_roshan_slam")
    if not ability or ability:GetLevel() <= 0 or not ability:IsFullyCastable() then return end
    local enemies = FindUnitsInRadius(unit:GetTeamNumber(), unit:GetAbsOrigin(), nil, 300,
        DOTA_UNIT_TARGET_TEAM_ENEMY, DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
        DOTA_UNIT_TARGET_FLAG_NONE, FIND_CLOSEST, false)
    if #enemies == 0 then return end
    ExecuteOrderFromTable({ UnitIndex=unit:entindex(), OrderType=DOTA_UNIT_ORDER_CAST_NO_TARGET,
        AbilityIndex=ability:entindex(), Queue=false })
end

function CustomRoshanService:Think()
    if GameRules:State_Get() >= DOTA_GAMERULES_STATE_POST_GAME then return nil end
    if GameRules:State_Get() ~= DOTA_GAMERULES_STATE_GAME_IN_PROGRESS then return 0.25 end
    local scheduledTime = self.SPAWN_TIMES[self.nextWave]
    if scheduledTime and GameRules:GetDOTATime(false, false) >= scheduledTime then
        if self:SpawnWave(self.nextWave) then self.nextWave = self.nextWave + 1 end
    end
    self:TrySlam()
    return 0.25
end

function CustomRoshanService:DropAegis(origin)
    local aegis = CreateItem("item_aegis", nil, nil)
    if not aegis then
        print("[CustomRoshanService] Failed to create item_aegis.")
        return
    end
    if not CreateItemOnPositionSync(origin, aegis) then UTIL_Remove(aegis) end
end

function CustomRoshanService:OnKilled(event)
    if not event or not event.entindex_killed then return end
    local killed = EntIndexToHScript(event.entindex_killed)
    if not killed or killed:IsNull() then return end
    if not self.unit or self.unit:IsNull() or killed ~= self.unit then return end
    local origin = killed:GetAbsOrigin()
    self.unit = nil
    self:DropAegis(origin)
    GameRules:SendCustomMessage("#custom_roshan_killed", 0, 0)
    EmitGlobalSound("Roshan.Death")
end

function CustomRoshanService:Start()
    if self.started then return end
    self.started = true
    self.nextWave = 1
    self.waveIndex = 0
    self.unit = nil
    self.marker = self:FindOrCreateMarker()
    GameRules:GetGameModeEntity():SetContextThink("CustomRoshanServiceThink", function() return self:Think() end, 0.25)
end

function CustomRoshanService:Init()
    ListenToGameEvent("entity_killed", function(event) self:OnKilled(event) end, nil)
    ListenToGameEvent("game_rules_state_change", function()
        if GameRules:State_Get() == DOTA_GAMERULES_STATE_GAME_IN_PROGRESS then self:Start() end
    end, nil)
    if GameRules:State_Get() == DOTA_GAMERULES_STATE_GAME_IN_PROGRESS then self:Start() end
end

return CustomRoshanService
