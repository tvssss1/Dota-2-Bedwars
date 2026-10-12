if ConvergenceService == nil then
    ConvergenceService = class({})
end
local ModeConfig = require("settings/mode_config")
local MapLocations = require("settings/map_locations")

local SHRINE_DEFINITIONS = {
    { index = 1, id = "northwest", target = "ConvergenceShrine01", label = "#convergence_shrine_northwest" },
    { index = 2, id = "southeast", target = "ConvergenceShrine02", label = "#convergence_shrine_southeast" }
}

local CYCLE_SECONDS = 60
local WARNING_SECONDS = 8
local CAPTURE_SECONDS = 6
local CAPTURE_RADIUS = 285
local CAPTURE_DECAY_MULTIPLIER = 2
local THINK_INTERVAL = 0.1
local SHRINE_MODEL = "models/props_structures/xp_shrine/xp_shrine.vmdl"
local SHRINE_MODEL_SCALE = 0.62

local function dotaTime()
    return GameRules:GetDOTATime(false, false)
end

local function validPlayerID(playerID)
    return playerID ~= nil and playerID >= 0 and PlayerResource:IsValidPlayerID(playerID)
end

function ConvergenceService:Init()
    if self.initialized then return end
    self.initialized = true
    self.shrines = {}
    self.enabled = true
    self.phase = "idle"
    self.sequence = 0
    self.warningShrine = nil

    for _, definition in ipairs(SHRINE_DEFINITIONS) do
        local marker = Entities:FindByName(nil, definition.target)
        if marker then
            local origin = MapLocations.GetShrinePosition(definition.index, marker)
            marker:SetAbsOrigin(origin)
            table.insert(self.shrines, {
                id = definition.id,
                target = definition.target,
                label = definition.label,
                marker = marker,
                origin = Vector(origin.x, origin.y, origin.z),
                active = false,
                sequence = 0,
                captureProgress = 0,
                captureTeam = nil,
                capturePlayerID = nil,
                contested = false
            })
        else
            print("[trynafix][convergence] Missing shrine marker: " .. definition.target)
        end
    end

    if #self.shrines < 2 then
        self.enabled = false
        self.phase = "disabled"
        print("[trynafix][convergence] Disabled: at least two configured shrine targets are required.")
    else
        self:CreateLandmarks()
    end

    ListenToGameEvent("game_rules_state_change", function() self:OnStateChange() end, nil)
    GameRules:GetGameModeEntity():SetContextThink("ConvergenceThink", function()
        return self:Think()
    end, THINK_INTERVAL)

    if GameRules:State_Get() == DOTA_GAMERULES_STATE_GAME_IN_PROGRESS then
        self:StartMatch()
    else
        self:Publish()
    end
end

function ConvergenceService:CreateLandmarks()
    for _, shrine in ipairs(self.shrines) do
        local displayOrigin = shrine.origin + Vector(0, 0, 4)
        local model = CreateUnitByName(
            "npc_convergence_shrine",
            displayOrigin,
            false,
            nil,
            nil,
            DOTA_TEAM_NEUTRALS
        )
        if model and not model:IsNull() then
            model:SetModel(SHRINE_MODEL)
            model:SetAbsOrigin(displayOrigin)
            if model.SetModelScale then model:SetModelScale(SHRINE_MODEL_SCALE) end
            if model.SetRenderColor then model:SetRenderColor(145, 150, 158) end
            model:AddNewModifier(model, nil, "modifier_no_interaction", {})
            shrine.model = model
        else
            -- Keep a prop fallback for unusual builds that reject the custom
            -- display unit while NPC keyvalues are being hot-reloaded.
            model = SpawnEntityFromTableSynchronous("prop_dynamic", {
                model = SHRINE_MODEL,
                origin = displayOrigin,
                angles = "0 0 0",
                solid = "0"
            })
            if model and not model:IsNull() then
                model:SetModel(SHRINE_MODEL)
                model:SetAbsOrigin(displayOrigin)
                if model.SetModelScale then model:SetModelScale(SHRINE_MODEL_SCALE) end
                shrine.model = model
            else
                print("[trynafix][convergence] Failed to create shrine model: " .. shrine.target)
            end
        end

        local particleOwner = shrine.model or shrine.marker
        local particle = ParticleManager:CreateParticle(
            "particles/base_static/experience_shrine_ambient.vpcf",
            PATTACH_ABSORIGIN_FOLLOW,
            particleOwner
        )
        ParticleManager:SetParticleControl(particle, 0, shrine.origin)
        shrine.landmarkParticle = particle
    end
end

function ConvergenceService:SetShrineModelState(shrine, state)
    if not shrine or not shrine.model or shrine.model:IsNull() or not shrine.model.SetRenderColor then return end
    if state == "active" then
        shrine.model:SetRenderColor(226, 204, 255)
    elseif state == "warning" then
        shrine.model:SetRenderColor(244, 211, 135)
    else
        shrine.model:SetRenderColor(145, 150, 158)
    end
end

function ConvergenceService:OnStateChange()
    local state = GameRules:State_Get()
    if state == DOTA_GAMERULES_STATE_GAME_IN_PROGRESS then
        self:StartMatch()
    elseif state >= DOTA_GAMERULES_STATE_POST_GAME then
        self.matchStarted = false
        self.warningShrine = nil
        self.currentShrine = nil
        self:DestroyActiveParticle()
    end
end

function ConvergenceService:StartMatch()
    if self.matchStarted then return end
    self.matchStarted = true
    self.phase = self.enabled and "idle" or "disabled"
    self.sequence = 0
    self.currentShrine = nil
    self.warningShrine = nil
    self.lastShrineID = nil
    for _, shrine in ipairs(self.shrines) do
        self:DestroyShrineActiveEffects(shrine)
        shrine.active = false
        shrine.sequence = 0
        shrine.captureProgress = 0
        shrine.captureTeam = nil
        shrine.capturePlayerID = nil
        shrine.contested = false
        self:SetShrineModelState(shrine, "idle")
    end
    self.lastThinkTime = dotaTime()
    local currentTime = math.max(0, dotaTime())
    self.nextActivation = math.max(CYCLE_SECONDS, (math.floor(currentTime / CYCLE_SECONDS) + 1) * CYCLE_SECONDS)
    self:Publish()
end

function ConvergenceService:ChooseShrine()
    local candidates = {}
    for _, shrine in ipairs(self.shrines) do
        if not shrine.active and shrine.id ~= self.lastShrineID then
            table.insert(candidates, shrine)
        end
    end
    if #candidates == 0 then
        for _, shrine in ipairs(self.shrines) do
            if not shrine.active then table.insert(candidates, shrine) end
        end
    end
    if #candidates == 0 then return nil end
    return candidates[RandomInt(1, #candidates)]
end

function ConvergenceService:AdvanceSchedule(currentTime)
    self.nextActivation = (self.nextActivation or CYCLE_SECONDS) + CYCLE_SECONDS
    while self.nextActivation <= (currentTime or dotaTime()) do
        self.nextActivation = self.nextActivation + CYCLE_SECONDS
    end
end

function ConvergenceService:RevealShrine(shrine, duration)
    if not shrine then return end
    for _, team in ipairs(ModeConfig.GetPlayableTeams()) do
        AddFOWViewer(team, shrine.origin, 450, duration, false)
        MinimapEvent(team, nil, shrine.origin.x, shrine.origin.y, DOTA_MINIMAP_EVENT_HINT_LOCATION, duration)
    end
end

function ConvergenceService:BeginWarning()
    local shrine = self:ChooseShrine()
    if not shrine then
        -- Both landmarks already hold unclaimed shrines. Consume this minute's
        -- spawn slot without replacing or stacking either one.
        self:AdvanceSchedule(dotaTime())
        self.phase = "idle"
        self.currentShrine = nil
        self.warningShrine = nil
        self:Publish()
        return false
    end

    self.phase = "warning"
    self.currentShrine = shrine
    self.warningShrine = shrine
    self.sequence = self.sequence + 1
    shrine.sequence = self.sequence
    shrine.captureProgress = 0
    shrine.captureTeam = nil
    shrine.capturePlayerID = nil
    shrine.contested = false
    self:RevealShrine(shrine, WARNING_SECONDS + 12)
    self:SetShrineModelState(self.currentShrine, "warning")
    self.warningParticle = ParticleManager:CreateParticle(
        "particles/base_static/experience_shrine_crack_glow_vertical.vpcf",
        PATTACH_ABSORIGIN_FOLLOW,
        self.currentShrine.model or self.currentShrine.marker
    )
    ParticleManager:SetParticleControl(self.warningParticle, 0, self.currentShrine.origin)
    CustomGameEventManager:Send_ServerToAllClients("convergence_warning", {
        sequence = self.sequence,
        shrine_id = self.currentShrine.id,
        activates_at = self.nextActivation
    })
    self:Publish()
    return true
end

function ConvergenceService:Activate()
    local shrine = self.warningShrine or self.currentShrine
    if not shrine or shrine.active then
        self.warningShrine = nil
        self.currentShrine = nil
        self.phase = "idle"
        self:AdvanceSchedule(dotaTime())
        self:Publish()
        return
    end
    if self.warningParticle then
        ParticleManager:DestroyParticle(self.warningParticle, false)
        ParticleManager:ReleaseParticleIndex(self.warningParticle)
        self.warningParticle = nil
    end
    self.phase = "idle"
    shrine.active = true
    shrine.captureProgress = 0
    shrine.captureTeam = nil
    shrine.capturePlayerID = nil
    shrine.contested = false
    self.lastShrineID = shrine.id
    self:SetShrineModelState(shrine, "active")
    shrine.activeParticle = ParticleManager:CreateParticle(
        "particles/base_static/experience_shrine_active.vpcf",
        PATTACH_ABSORIGIN_FOLLOW,
        shrine.model or shrine.marker
    )
    ParticleManager:SetParticleControl(shrine.activeParticle, 0, shrine.origin)
    ParticleManager:SetParticleControl(shrine.activeParticle, 1, Vector(CAPTURE_RADIUS, 0, 0))
    shrine.captureRingParticle = ParticleManager:CreateParticle(
        "particles/dev/library/base_aoe_ring_simple.vpcf",
        PATTACH_WORLDORIGIN,
        nil
    )
    ParticleManager:SetParticleControl(shrine.captureRingParticle, 0, shrine.origin)
    ParticleManager:SetParticleControl(shrine.captureRingParticle, 1, Vector(CAPTURE_RADIUS, 0, 0))
    local activationBurst = ParticleManager:CreateParticle(
        "particles/base_static/experience_shrine_crack_glow_burst.vpcf",
        PATTACH_WORLDORIGIN,
        nil
    )
    ParticleManager:SetParticleControl(activationBurst, 0, shrine.origin)
    ParticleManager:ReleaseParticleIndex(activationBurst)
    EmitGlobalSound("Outpost.Captured.Notification")
    EmitSoundOnLocationWithCaster(shrine.origin, "Shrine.Cast", shrine.marker)
    CustomGameEventManager:Send_ServerToAllClients("convergence_activated", {
        sequence = shrine.sequence,
        shrine_id = shrine.id,
        persistent = 1
    })
    self.warningShrine = nil
    self.currentShrine = nil
    self:AdvanceSchedule(dotaTime())
    self:Publish()
end

function ConvergenceService:DestroyCaptureFeedback(shrine)
    if not shrine then return end
    if shrine.captureChannelParticle then
        ParticleManager:DestroyParticle(shrine.captureChannelParticle, false)
        ParticleManager:ReleaseParticleIndex(shrine.captureChannelParticle)
        shrine.captureChannelParticle = nil
    end
    if shrine.captureChannelHero and not shrine.captureChannelHero:IsNull() then
        StopSoundOn("Outpost.Channel", shrine.captureChannelHero)
        shrine.captureChannelHero:RemoveModifierByName("modifier_convergence_capturing")
    end
    shrine.captureChannelHero = nil
    shrine.captureChannelPlayerID = nil
end

function ConvergenceService:UpdateCaptureFeedback(shrine, playerID)
    if not shrine then return end
    local progressRatio = math.max(0, math.min(1, (shrine.captureProgress or 0) / CAPTURE_SECONDS))
    if shrine.activeParticle then
        ParticleManager:SetParticleControl(
            shrine.activeParticle,
            1,
            Vector(CAPTURE_RADIUS, progressRatio * 100, 0)
        )
    end

    if not validPlayerID(playerID) then
        self:DestroyCaptureFeedback(shrine)
        return
    end

    local hero = PlayerResource:GetSelectedHeroEntity(playerID)
    if not self:IsEligibleHero(hero) then
        self:DestroyCaptureFeedback(shrine)
        return
    end

    if shrine.captureChannelPlayerID ~= playerID or shrine.captureChannelHero ~= hero then
        self:DestroyCaptureFeedback(shrine)
        local shrineEntity = shrine.model or shrine.marker
        if shrineEntity and not shrineEntity:IsNull() then
            shrine.captureChannelParticle = ParticleManager:CreateParticle(
                "particles/generic_gameplay/effigy_channel/effigy_channel.vpcf",
                PATTACH_ABSORIGIN_FOLLOW,
                shrineEntity
            )
            ParticleManager:SetParticleControlEnt(
                shrine.captureChannelParticle,
                0,
                shrineEntity,
                PATTACH_POINT_FOLLOW,
                "attach_fx",
                shrine.origin,
                true
            )
            ParticleManager:SetParticleControlEnt(
                shrine.captureChannelParticle,
                1,
                hero,
                PATTACH_POINT_FOLLOW,
                "attach_hitloc",
                hero:GetAbsOrigin(),
                true
            )
        end
        EmitSoundOn("Outpost.Channel", hero)
        shrine.captureChannelHero = hero
        shrine.captureChannelPlayerID = playerID
    end

    local modifier = hero:FindModifierByName("modifier_convergence_capturing")
    if not modifier then
        modifier = hero:AddNewModifier(hero, nil, "modifier_convergence_capturing", { duration = 0.3 })
    elseif modifier.SetDuration then
        modifier:SetDuration(0.3, true)
    end
    if modifier then
        modifier:SetStackCount(math.max(1, math.floor(progressRatio * 100 + 0.5)))
    end
end

function ConvergenceService:DestroyShrineActiveEffects(shrine)
    if not shrine then return end
    self:DestroyCaptureFeedback(shrine)
    if shrine.activeParticle then
        ParticleManager:DestroyParticle(shrine.activeParticle, false)
        ParticleManager:ReleaseParticleIndex(shrine.activeParticle)
        shrine.activeParticle = nil
    end
    if shrine.captureRingParticle then
        ParticleManager:DestroyParticle(shrine.captureRingParticle, false)
        ParticleManager:ReleaseParticleIndex(shrine.captureRingParticle)
        shrine.captureRingParticle = nil
    end
end

function ConvergenceService:DestroyActiveParticle()
    if self.warningParticle then
        ParticleManager:DestroyParticle(self.warningParticle, false)
        ParticleManager:ReleaseParticleIndex(self.warningParticle)
        self.warningParticle = nil
    end
    for _, shrine in ipairs(self.shrines or {}) do
        self:DestroyShrineActiveEffects(shrine)
    end
end

function ConvergenceService:EndActive(shrine, reason)
    if not shrine then return end
    self:DestroyShrineActiveEffects(shrine)
    shrine.active = false
    shrine.captureProgress = 0
    shrine.captureTeam = nil
    shrine.capturePlayerID = nil
    shrine.contested = false
    self:SetShrineModelState(shrine, "idle")
    CustomGameEventManager:Send_ServerToAllClients("convergence_ended", {
        sequence = shrine.sequence or 0,
        shrine_id = shrine.id,
        reason = tostring(reason or "claimed")
    })
    self:Publish()
end

function ConvergenceService:IsEligibleHero(hero)
    if not hero or hero:IsNull() or not hero:IsAlive() then return false end
    if not hero.IsRealHero or not hero:IsRealHero() then return false end
    if hero.IsIllusion and hero:IsIllusion() then return false end
    if hero.IsClone and hero:IsClone() then return false end
    if hero.IsTempestDouble and hero:IsTempestDouble() then return false end
    if hero:HasModifier("modifier_perk_holo_decoy") then return false end
    local playerID = hero:GetPlayerOwnerID()
    if not validPlayerID(playerID) then return false end
    if PlayerResource:GetConnectionState(playerID) ~= DOTA_CONNECTION_STATE_CONNECTED then return false end
    local team = hero:GetTeamNumber()
    return ModeConfig.IsPlayableTeam(team)
end

function ConvergenceService:GetPresentTeams(shrine)
    local present = {}
    if not shrine or not shrine.active then return present end
    -- Enumerating real heroes avoids neutral-team relationship filtering, which
    -- can omit custom teams on maps without Radiant/Dire player slots.
    for _, hero in pairs(HeroList:GetAllHeroes()) do
        if self:IsEligibleHero(hero)
            and (hero:GetAbsOrigin() - shrine.origin):Length2D() <= CAPTURE_RADIUS then
            local team = hero:GetTeamNumber()
            if not present[team] then
                present[team] = hero:GetPlayerOwnerID()
            end
        end
    end
    return present
end

function ConvergenceService:Claim(shrine, team, playerID)
    if not shrine or not shrine.active or not validPlayerID(playerID) then return end
    self:UpdateCaptureFeedback(shrine, playerID)
    local finishParticle = ParticleManager:CreateParticle(
        "particles/world_outpost/world_outpost_channel_finish.vpcf",
        PATTACH_WORLDORIGIN,
        nil
    )
    ParticleManager:SetParticleControl(finishParticle, 0, shrine.origin)
    ParticleManager:ReleaseParticleIndex(finishParticle)
    EmitSoundOnLocationWithCaster(shrine.origin, "Outpost.Captured", shrine.marker)
    if PerkService then PerkService:GrantClaimReward(playerID, shrine.sequence) end
    CustomGameEventManager:Send_ServerToAllClients("convergence_claimed", {
        sequence = shrine.sequence,
        shrine_id = shrine.id,
        team_id = team,
        player_id = playerID,
        player_name = PlayerResource:GetPlayerName(playerID) or ""
    })
    self:EndActive(shrine, "claimed")
end

function ConvergenceService:UpdateCapture(shrine, delta)
    if not shrine or not shrine.active then return end
    local present = self:GetPresentTeams(shrine)
    local teamCount = 0
    local soleTeam = nil
    local solePlayerID = nil
    for team, playerID in pairs(present) do
        teamCount = teamCount + 1
        soleTeam = team
        solePlayerID = playerID
    end

    if teamCount >= 2 then
        shrine.contested = true
        self:UpdateCaptureFeedback(shrine, nil)
        return
    elseif teamCount == 0 then
        shrine.contested = false
        shrine.captureProgress = math.max(0, shrine.captureProgress - delta * CAPTURE_DECAY_MULTIPLIER)
        if shrine.captureProgress <= 0 then
            shrine.captureTeam = nil
            shrine.capturePlayerID = nil
        end
        self:UpdateCaptureFeedback(shrine, nil)
    elseif shrine.captureTeam == nil or shrine.captureTeam == soleTeam then
        shrine.contested = false
        shrine.captureTeam = soleTeam
        shrine.capturePlayerID = solePlayerID
        shrine.captureProgress = math.min(CAPTURE_SECONDS, shrine.captureProgress + delta)
        self:UpdateCaptureFeedback(shrine, solePlayerID)
        if shrine.captureProgress >= CAPTURE_SECONDS then
            self:Claim(shrine, soleTeam, solePlayerID)
            return
        end
    else
        shrine.contested = false
        shrine.captureProgress = math.max(0, shrine.captureProgress - delta * CAPTURE_DECAY_MULTIPLIER)
        if shrine.captureProgress <= 0 then
            shrine.captureTeam = soleTeam
            shrine.capturePlayerID = solePlayerID
        end
        self:UpdateCaptureFeedback(shrine, nil)
    end
end

function ConvergenceService:UpdateCaptures(delta)
    local hasActiveShrine = false
    for _, shrine in ipairs(self.shrines) do
        if shrine.active then
            hasActiveShrine = true
            self:UpdateCapture(shrine, delta)
        end
    end
    if hasActiveShrine then self:Publish() end
end

function ConvergenceService:Publish()
    local activeCount = 0
    local firstActive = nil
    for _, shrine in ipairs(self.shrines or {}) do
        if shrine.active then
            activeCount = activeCount + 1
            if not firstActive then firstActive = shrine end
        end

        CustomNetTables:SetTableValue("convergence_state", "shrine_" .. shrine.id, {
            shrine_id = shrine.id,
            shrine_label = shrine.label,
            active = shrine.active and 1 or 0,
            warning = self.warningShrine == shrine and 1 or 0,
            sequence = shrine.sequence or 0,
            capture_team = shrine.captureTeam or -1,
            capture_progress = shrine.captureProgress or 0,
            capture_required = CAPTURE_SECONDS,
            contested = shrine.contested and 1 or 0,
            radius = CAPTURE_RADIUS,
            x = shrine.origin.x,
            y = shrine.origin.y,
            z = shrine.origin.z
        })
    end

    local focusedShrine = self.warningShrine or firstActive
    local publishedPhase = not self.enabled and "disabled"
        or (self.warningShrine and "warning"
        or (activeCount > 0 and "active" or "idle"))
    local data = {
        enabled = self.enabled and 1 or 0,
        sequence = focusedShrine and focusedShrine.sequence or self.sequence or 0,
        phase = publishedPhase,
        next_activation = self.nextActivation or CYCLE_SECONDS,
        activates_at = self.nextActivation or CYCLE_SECONDS,
        active_count = activeCount,
        capacity = #self.shrines,
        spawn_blocked = activeCount >= #self.shrines and 1 or 0,
        persistent = 1,
        capture_team = focusedShrine and focusedShrine.captureTeam or -1,
        capture_progress = focusedShrine and focusedShrine.captureProgress or 0,
        capture_required = CAPTURE_SECONDS,
        contested = focusedShrine and focusedShrine.contested and 1 or 0,
        radius = CAPTURE_RADIUS
    }
    if focusedShrine then
        data.shrine_id = focusedShrine.id
        data.shrine_label = focusedShrine.label
        data.x = focusedShrine.origin.x
        data.y = focusedShrine.origin.y
        data.z = focusedShrine.origin.z
    end
    CustomNetTables:SetTableValue("convergence_state", "current", data)
end

function ConvergenceService:Think()
    if not self.initialized then return THINK_INTERVAL end
    if not self.matchStarted or not self.enabled then return THINK_INTERVAL end
    if GameRules:State_Get() ~= DOTA_GAMERULES_STATE_GAME_IN_PROGRESS then return THINK_INTERVAL end

    local currentTime = dotaTime()
    local delta = math.max(0, math.min(0.25, currentTime - (self.lastThinkTime or currentTime)))
    self.lastThinkTime = currentTime

    if not self.warningShrine and currentTime >= self.nextActivation - WARNING_SECONDS then
        self:BeginWarning()
    end
    if self.warningShrine and currentTime >= self.nextActivation then
        self:Activate()
    end
    self:UpdateCaptures(delta)
    return THINK_INTERVAL
end

return ConvergenceService
