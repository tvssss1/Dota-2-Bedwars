modifier_convergence_perks = class({})
modifier_convergence_perk_balloon_brigade = class({})
modifier_convergence_perk_temporal_snapback = class({})
modifier_convergence_perk_wild_card = class({})
modifier_convergence_perk_treasure_trickster = class({})
modifier_convergence_perk_holo_hustle = class({})
modifier_convergence_perk_storm_chaser = class({})
modifier_convergence_perk_kaiju_protocol = class({})
modifier_convergence_perk_meteor_contract = class({})
modifier_convergence_capturing = class({})
modifier_convergence_balloon_target = class({})
modifier_perk_wildcard_barrier = class({})
modifier_perk_holo_escape = class({})
modifier_perk_holo_decoy = class({})
modifier_perk_temporal_rupture_slow = class({})
modifier_perk_treasure_rush = class({})
modifier_perk_holo_burst_slow = class({})
modifier_perk_storm_charged = class({})
modifier_perk_kaiju_form = class({})

local BALLOON_MAX = { 1, 2, 3 }
local BALLOON_DURATION = { 15, 20, 25 }
local BALLOON_COOLDOWN = { 40, 35, 30 }
local BALLOON_MOVE_SPEED = { 8, 10, 12 }
local BALLOON_EVASION = { 10, 15, 20 }
local SNAPBACK_RESTORE = { 0.30, 0.40, 0.47 }
local SNAPBACK_COOLDOWN = { 55, 47, 41 }
local SNAPBACK_RUPTURE_DAMAGE = { 80, 130, 180 }
local SNAPBACK_RUPTURE_SLOW = { 20, 30, 40 }
local WILD_COOLDOWN = { 8, 7, 6 }
local WILD_BLINK = { 250, 310, 350 }
local WILD_BARRIER = { 160, 225, 270 }
local WILD_PUSH = { 180, 230, 265 }
local WILD_FIREWORK_DAMAGE = { 110, 170, 230 }
local HOLO_INVIS = { 0.8, 1.1, 1.25 }
local HOLO_MOVE_SPEED = { 20, 25, 28 }
local HOLO_DURATION = { 4, 5, 5.5 }
local HOLO_COOLDOWN = { 40, 34, 30 }
local HOLO_BURST_DAMAGE = { 80, 130, 180 }
local HOLO_BURST_SLOW = { 20, 25, 30 }
local STORM_DISTANCE = { 900, 750, 600 }
local STORM_DAMAGE = { 90, 145, 200 }
local STORM_TARGETS = { 2, 3, 4 }
local KAIJU_HITS_REQUIRED = 5
local KAIJU_DURATION = { 5, 6, 7 }
local KAIJU_COOLDOWN = { 24, 21, 18 }
local KAIJU_BURST_DAMAGE = { 100, 165, 230 }
local KAIJU_MODEL_SCALE = { 20, 30, 40 }
local KAIJU_BONUS_DAMAGE = { 30, 50, 70 }
local KAIJU_ATTACK_SPEED = { 30, 45, 60 }
local KAIJU_DAMAGE_REDUCTION = { 15, 20, 25 }
local KAIJU_STATUS_RESISTANCE = { 20, 25, 30 }
local METEOR_COOLDOWN = { 14, 12, 10 }
local METEOR_DAMAGE = { 120, 180, 240 }
local METEOR_RADIUS = { 250, 275, 300 }
local METEOR_STUN = { 0.4, 0.6, 0.8 }
local BALLOON_MODEL_SCALE = 2.00
local BALLOON_MODEL_SCALE_IN_TIME = 0.38
local BALLOON_VISUAL_Z_DELTA = 180
local BALLOON_MODEL_HEAD_CLEARANCE = 100
local BALLOON_MODEL_MIN_HERO_HEIGHT = 128
local BALLOON_MODEL_MAX_HERO_HEIGHT = 420
local BALLOON_WIND_PARTICLE = "particles/econ/items/windrunner/fluttering_breeze/arcana/fluttering_breeze_arcana_weapon_ambient_wind.vpcf"
local BALLOON_CLOUD_PARTICLE = "particles/econ/items/storm_spirit/storm_spirit_orchid_hat_retro/stormspirit_orchid_retro_ball_trail_cloud.vpcf"

local function configurePerkDisplay(modifierClass, texture)
    function modifierClass:IsHidden() return false end
    function modifierClass:IsDebuff() return false end
    function modifierClass:IsPurgable() return false end
    function modifierClass:RemoveOnDeath() return false end
    function modifierClass:AllowIllusionDuplicate() return false end
    function modifierClass:GetAttributes() return MODIFIER_ATTRIBUTE_PERMANENT end
    function modifierClass:GetTexture() return texture end
    function modifierClass:DeclareFunctions() return { MODIFIER_PROPERTY_TOOLTIP } end
    function modifierClass:OnTooltip() return self:GetStackCount() end

    function modifierClass:OnCreated()
        if not IsServer() then return end
        local ability = self:GetAbility()
        self:SetStackCount(math.max(1, ability and ability:GetLevel() or 1))
        local parent = self:GetParent()
        if parent and not parent:IsNull() and not parent:HasModifier("modifier_convergence_perks") then
            parent:AddNewModifier(parent, ability, "modifier_convergence_perks", {})
        end
        self:StartIntervalThink(0.1)
    end

    function modifierClass:OnRefresh()
        if not IsServer() then return end
        local ability = self:GetAbility()
        self:SetStackCount(math.max(1, ability and ability:GetLevel() or self:GetStackCount()))
    end

    -- Perk abilities are intentionally hidden from the ability bar, so mirror
    -- their live cooldown onto the permanent perk modifier. A small expiry
    -- cushion keeps the modifier from being destroyed between heartbeat ticks;
    -- as soon as the real cooldown ends it returns to infinite duration.
    function modifierClass:OnIntervalThink()
        if not IsServer() then return end
        local ability = self:GetAbility()
        local remaining = ability and not ability:IsNull() and ability:GetCooldownTimeRemaining() or 0
        if remaining > 0 then
            self:SetDuration(remaining + 0.25, true)
        elseif self:GetDuration() >= 0 then
            self:SetDuration(-1, true)
        end
    end
end

configurePerkDisplay(modifier_convergence_perk_balloon_brigade, "consumables/seasonal_ti11_balloon_radiant")
configurePerkDisplay(modifier_convergence_perk_temporal_snapback, "faceless_void_time_walk")
configurePerkDisplay(modifier_convergence_perk_wild_card, "ogre_magi_multicast")
configurePerkDisplay(modifier_convergence_perk_treasure_trickster, "alchemist_goblins_greed")
configurePerkDisplay(modifier_convergence_perk_holo_hustle, "phantom_lancer_doppelwalk")
configurePerkDisplay(modifier_convergence_perk_storm_chaser, "razor_unstable_current")
configurePerkDisplay(modifier_convergence_perk_kaiju_protocol, "primal_beast_uproar")
configurePerkDisplay(modifier_convergence_perk_meteor_contract, "invoker_chaos_meteor")

function modifier_convergence_capturing:IsHidden() return false end
function modifier_convergence_capturing:IsDebuff() return false end
function modifier_convergence_capturing:IsPurgable() return false end
function modifier_convergence_capturing:RemoveOnDeath() return true end
function modifier_convergence_capturing:GetTexture() return "item_tome_of_knowledge" end
function modifier_convergence_capturing:DeclareFunctions() return { MODIFIER_PROPERTY_TOOLTIP } end
function modifier_convergence_capturing:OnTooltip() return self:GetStackCount() end

local function dotaTime()
    return GameRules:GetDOTATime(false, false)
end

local function getPlayerID(parent)
    if not parent or parent:IsNull() or not parent.GetPlayerOwnerID then return -1 end
    return parent:GetPlayerOwnerID()
end

local function rankFor(parent, perkID)
    if not PerkService then return 0 end
    return PerkService:GetRank(getPlayerID(parent), perkID)
end

local function runtimeFor(parent)
    if not PerkService then return nil end
    return PerkService:GetRuntime(getPlayerID(parent))
end

local function validPosition(position)
    if not position or not GridNav then return false end
    if not GridNav:IsTraversable(position) then return false end
    -- Do not use GridNav:IsBlocked here. Recorded positions are occupied by the
    -- hero at capture time and can therefore be reported as dynamically
    -- blocked. FindClearSpaceForUnit resolves occupancy when the rewind fires.
    return true
end

local function releaseBurst(particleName, position)
    local particle = ParticleManager:CreateParticle(particleName, PATTACH_WORLDORIGIN, nil)
    ParticleManager:SetParticleControl(particle, 0, position)
    ParticleManager:ReleaseParticleIndex(particle)
end

function modifier_convergence_perks:IsHidden() return true end
function modifier_convergence_perks:IsDebuff() return false end
function modifier_convergence_perks:IsPurgable() return false end
function modifier_convergence_perks:RemoveOnDeath() return false end
function modifier_convergence_perks:GetAttributes() return MODIFIER_ATTRIBUTE_PERMANENT end

function modifier_convergence_perks:DeclareFunctions()
    return {
        MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE,
        MODIFIER_PROPERTY_EVASION_CONSTANT,
        MODIFIER_PROPERTY_VISUAL_Z_DELTA,
        MODIFIER_PROPERTY_VISUAL_Z_SPEED_BASE_OVERRIDE,
        MODIFIER_EVENT_ON_TAKEDAMAGE,
        MODIFIER_EVENT_ON_ATTACK_LANDED,
        MODIFIER_EVENT_ON_ABILITY_EXECUTED,
        MODIFIER_EVENT_ON_DEATH
    }
end

function modifier_convergence_perks:CheckState()
    local parent = self:GetParent()
    local runtime = runtimeFor(parent)
    if rankFor(parent, "balloon_brigade") > 0 and runtime and (runtime.balloons or 0) > 0 then
        return { [MODIFIER_STATE_FLYING] = true }
    end
    return {}
end

function modifier_convergence_perks:GetVisualZDelta()
    return self:GetStackCount() > 0 and BALLOON_VISUAL_Z_DELTA or 0
end

function modifier_convergence_perks:GetVisualZSpeedBaseOverride()
    return 360
end

function modifier_convergence_perks:DestroyBalloonParticles()
    if self.balloonWindParticle then
        ParticleManager:DestroyParticle(self.balloonWindParticle, false)
        ParticleManager:ReleaseParticleIndex(self.balloonWindParticle)
        self.balloonWindParticle = nil
    end
    if self.balloonCloudParticle then
        ParticleManager:DestroyParticle(self.balloonCloudParticle, false)
        ParticleManager:ReleaseParticleIndex(self.balloonCloudParticle)
        self.balloonCloudParticle = nil
    end
end

function modifier_convergence_perks:DestroyBalloonModel()
    if self.balloonModel and not self.balloonModel:IsNull() then
        UTIL_Remove(self.balloonModel)
    end
    self.balloonModel = nil
end

function modifier_convergence_perks:AnimateBalloonModel(model)
    if not model.SetModelScale then return end

    local initialScale = 0.05
    model:SetModelScale(initialScale)
    if not model.SetContextThink then
        model:SetModelScale(BALLOON_MODEL_SCALE)
        return
    end

    local startedAt = GameRules:GetGameTime()
    model:SetContextThink("ConvergenceBalloonScaleIn", function()
        if not model or model:IsNull() then return nil end

        local progress = math.min(1, math.max(0,
            (GameRules:GetGameTime() - startedAt) / BALLOON_MODEL_SCALE_IN_TIME
        ))
        local shifted = progress - 1
        local eased = 1 + 2.70158 * shifted * shifted * shifted + 1.70158 * shifted * shifted
        model:SetModelScale(initialScale + (BALLOON_MODEL_SCALE - initialScale) * eased)

        if progress >= 1 then
            model:SetModelScale(BALLOON_MODEL_SCALE)
            return nil
        end
        return 0.02
    end, 0)
end

function modifier_convergence_perks:GetBalloonAnchorHeight(parent)
    local heroHeight = BALLOON_MODEL_MIN_HERO_HEIGHT
    if parent and not parent:IsNull() and parent.GetBoundingMaxs then
        local bounds = parent:GetBoundingMaxs()
        if bounds and tonumber(bounds.z) then
            heroHeight = tonumber(bounds.z)
        end
    end

    -- Collision bounds are nearly identical on several visually very different
    -- heroes. The socket's vertical component is still useful even when its X/Y
    -- position and bone rotation are unsuitable for parenting the model.
    if parent and not parent:IsNull()
        and parent.ScriptLookupAttachment and parent.GetAttachmentOrigin then
        local attachmentIndex = parent:ScriptLookupAttachment("attach_head")
        if not attachmentIndex or attachmentIndex <= 0 then
            attachmentIndex = parent:ScriptLookupAttachment("attach_hitloc")
        end
        if attachmentIndex and attachmentIndex > 0 then
            local attachmentOrigin = parent:GetAttachmentOrigin(attachmentIndex)
            local parentOrigin = parent:GetAbsOrigin()
            if attachmentOrigin and parentOrigin then
                -- Attachment origins include the modifier's visual lift. The
                -- root-parented balloon model inherits that lift as well, so
                -- remove it here to avoid applying the 180-unit rise twice.
                local attachmentHeight = attachmentOrigin.z - parentOrigin.z
                    - BALLOON_VISUAL_Z_DELTA
                if attachmentHeight > 0 then
                    heroHeight = math.max(heroHeight, attachmentHeight)
                end
            end
        end
    end

    heroHeight = math.max(
        BALLOON_MODEL_MIN_HERO_HEIGHT,
        math.min(BALLOON_MODEL_MAX_HERO_HEIGHT, heroHeight)
    )
    return heroHeight + BALLOON_MODEL_HEAD_CLEARANCE
end

function modifier_convergence_perks:UpdateBalloonModelAnchor(parent)
    local model = self.balloonModel
    if not model or model:IsNull() or not parent or parent:IsNull() then return end

    -- Hero head attachments vary wildly in both position and rotation. Parenting
    -- to the centered root keeps the cluster directly above every hero; using
    -- the current bounds also follows size-changing forms such as Grow.
    model:SetLocalOrigin(Vector(0, 0, self:GetBalloonAnchorHeight(parent)))
    model:SetLocalAngles(0, 0, 0)
end

function modifier_convergence_perks:CreateBalloonModel(parent)
    if self.balloonModel and not self.balloonModel:IsNull() then return end

    local model = CreateUnitByName(
        "npc_dota_convergence_balloon_target",
        parent:GetAbsOrigin(),
        false,
        nil,
        nil,
        parent:GetTeamNumber()
    )
    if not model or model:IsNull() then return end

    model:SetParent(parent, "")
    self.balloonModel = model
    self:UpdateBalloonModelAnchor(parent)
    if model.SetNeverMoveToClearSpace then model:SetNeverMoveToClearSpace(true) end
    model:AddNewModifier(parent, nil, "modifier_convergence_balloon_target", {
        owner_entindex = parent:entindex()
    })
    self:AnimateBalloonModel(model)
end

function modifier_convergence_perks:SyncBalloonVisuals(parent, count)
    count = math.max(0, math.min(3, tonumber(count) or 0))
    self:SetStackCount(count)
    if count <= 0 or not parent or parent:IsNull() then
        self:DestroyBalloonParticles()
        self:DestroyBalloonModel()
        return
    end

    self:CreateBalloonModel(parent)
    if self.balloonModel and not self.balloonModel:IsNull() then
        self:UpdateBalloonModelAnchor(parent)
        local maximum = BALLOON_MAX[rankFor(parent, "balloon_brigade")] or 1
        if self.balloonModel.SetBaseMaxHealth then self.balloonModel:SetBaseMaxHealth(maximum) end
        self.balloonModel:SetMaxHealth(maximum)
        self.balloonModel:SetHealth(math.max(1, math.min(count, maximum)))
    end

    if not self.balloonWindParticle then
        self.balloonWindParticle = ParticleManager:CreateParticle(
            BALLOON_WIND_PARTICLE,
            PATTACH_ABSORIGIN_FOLLOW,
            parent
        )
    end

    if not self.balloonCloudParticle then
        self.balloonCloudParticle = ParticleManager:CreateParticle(
            BALLOON_CLOUD_PARTICLE,
            PATTACH_ABSORIGIN_FOLLOW,
            parent
        )
    end
end

function modifier_convergence_perks:ClearBalloonVisuals()
    self:SetStackCount(0)
    self:DestroyBalloonParticles()
    self:DestroyBalloonModel()
end

function modifier_convergence_perks:GetModifierMoveSpeedBonus_Percentage()
    local parent = self:GetParent()
    local rank = rankFor(parent, "balloon_brigade")
    local runtime = runtimeFor(parent)
    if rank > 0 and runtime and (runtime.balloons or 0) > 0 then
        return BALLOON_MOVE_SPEED[rank] or BALLOON_MOVE_SPEED[#BALLOON_MOVE_SPEED]
    end
    return 0
end

function modifier_convergence_perks:GetModifierEvasion_Constant()
    local parent = self:GetParent()
    local rank = rankFor(parent, "balloon_brigade")
    local runtime = runtimeFor(parent)
    if rank > 0 and runtime and (runtime.balloons or 0) > 0 then
        return BALLOON_EVASION[rank] or BALLOON_EVASION[#BALLOON_EVASION]
    end
    return 0
end

function modifier_convergence_perks:UpdateStormCharge(parent, runtime, rank)
    if rank <= 0 then
        runtime.storm_distance = 0
        runtime.storm_charged = 0
        runtime.storm_last_position = nil
        parent:RemoveModifierByName("modifier_perk_storm_charged")
        return false
    end

    local position = parent:GetAbsOrigin()
    local lastPosition = runtime.storm_last_position
    runtime.storm_last_position = Vector(position.x, position.y, position.z)
    if (runtime.storm_charged or 0) == 1 then
        if not parent:HasModifier("modifier_perk_storm_charged") then
            parent:AddNewModifier(parent, nil, "modifier_perk_storm_charged", {})
        end
        return false
    end
    if not lastPosition then return false end

    local dx = position.x - lastPosition.x
    local dy = position.y - lastPosition.y
    local travelled = math.sqrt(dx * dx + dy * dy)
    -- Ignore teleports and forced long-distance relocations.
    if travelled <= 180 then
        runtime.storm_distance = (runtime.storm_distance or 0) + travelled
    end

    if runtime.storm_distance >= STORM_DISTANCE[rank] then
        runtime.storm_distance = STORM_DISTANCE[rank]
        runtime.storm_charged = 1
        parent:AddNewModifier(parent, nil, "modifier_perk_storm_charged", {})
        EmitSoundOn("Hero_Razor.UnstableCurrent.Target", parent)
        return true
    end
    return false
end

function modifier_convergence_perks:OnCreated()
    if not IsServer() then return end
    self.wasAlive = false
    self:StartIntervalThink(0.25)
end

function modifier_convergence_perks:OnDestroy()
    if not IsServer() then return end
    self:ClearBalloonVisuals()
end

function modifier_convergence_perks:OnIntervalThink()
    local parent = self:GetParent()
    if not parent or parent:IsNull() then return end

    -- Holo Hustle no longer applies this legacy escape modifier. Remove any
    -- copy left on a hero by an older/hot-reloaded version of the perk.
    if parent:HasModifier("modifier_perk_holo_escape") then
        parent:RemoveModifierByName("modifier_perk_holo_escape")
    end

    local playerID = getPlayerID(parent)
    local runtime = runtimeFor(parent)
    if not runtime then return end

    if not parent:IsAlive() then
        self:ClearBalloonVisuals()
        if self.wasAlive then
            self.wasAlive = false
            PerkService:ResetLifeRuntime(playerID, false)
        end
        return
    end

    if not self.wasAlive or runtime.alive ~= 1 then
        self.wasAlive = true
        PerkService:ResetLifeRuntime(playerID, true)
        runtime = runtimeFor(parent)
    end

    local currentTime = dotaTime()
    local publish = false
    local balloonRank = rankFor(parent, "balloon_brigade")
    if balloonRank > 0 then
        local maximum = BALLOON_MAX[balloonRank]
        local duration = BALLOON_DURATION[balloonRank]
        local cooldown = BALLOON_COOLDOWN[balloonRank]

        if (runtime.balloons or 0) > 0
            and (runtime.balloon_expires or 0) > 0
            and currentTime >= runtime.balloon_expires then
            runtime.balloons = 0
            runtime.balloon_expires = 0
            publish = true
            self:SyncBalloonVisuals(parent, 0)
            FindClearSpaceForUnit(parent, GetGroundPosition(parent:GetAbsOrigin(), parent), true)
            EmitSoundOn("Trynafix.Perk.BalloonPop", parent)
        end

        -- Legacy/hot-reload safety for an already-active balloon pack.
        if (runtime.balloons or 0) > 0 and (runtime.balloon_expires or 0) <= 0 then
            runtime.balloon_expires = currentTime + duration
            if (runtime.balloon_next or 0) <= currentTime then
                runtime.balloon_next = currentTime + cooldown
                PerkService:StartAbilityCooldown(parent, "balloon_brigade", cooldown)
            end
            publish = true
        elseif (runtime.balloons or 0) <= 0
            and currentTime >= (runtime.balloon_next or 0) then
            -- Each activation creates the full rank-based pack. Its cooldown is
            -- measured from this moment, even if the balloons expire or are
            -- shot down early.
            runtime.balloons = maximum
            runtime.balloon_expires = currentTime + duration
            runtime.balloon_next = currentTime + cooldown
            publish = true
            self:SyncBalloonVisuals(parent, runtime.balloons)
            PerkService:StartAbilityCooldown(parent, "balloon_brigade", cooldown)
            EmitSoundOn("Trynafix.Perk.BalloonInflate", parent)
        end
    else
        if (runtime.balloons or 0) ~= 0
            or (runtime.balloon_next or 0) ~= 0
            or (runtime.balloon_expires or 0) ~= 0 then
            publish = true
        end
        runtime.balloons = 0
        runtime.balloon_next = 0
        runtime.balloon_expires = 0
    end

    self:SyncBalloonVisuals(parent, runtime.balloons or 0)

    if self:UpdateStormCharge(parent, runtime, rankFor(parent, "storm_chaser")) then
        publish = true
    end

    if rankFor(parent, "temporal_snapback") > 0 then
        local position = parent:GetAbsOrigin()
        if validPosition(position) then
            table.insert(runtime.history, {
                time = currentTime,
                position = Vector(position.x, position.y, position.z),
                health = parent:GetHealth()
            })
        end
        while #runtime.history > 0 and runtime.history[1].time < currentTime - 4.25 do
            table.remove(runtime.history, 1)
        end

        -- Source 2 does not deliver every damage source consistently through a
        -- modifier's OnTakeDamage callback. Health is authoritative, so check
        -- the threshold here as well. This heartbeat already runs server-side
        -- every 0.25 seconds and makes Snapback independent of event quirks.
        if self:TrySnapback(
            parent,
            runtime,
            rankFor(parent, "temporal_snapback"),
            currentTime
        ) then
            publish = true
        end
    else
        runtime.history = {}
    end

    if publish then PerkService:Publish(playerID) end
end

function modifier_convergence_perks:OnDeath(params)
    if not IsServer() or params.unit ~= self:GetParent() then return end
    self.wasAlive = false
    self:ClearBalloonVisuals()
    PerkService:ResetLifeRuntime(getPlayerID(self:GetParent()), false)
end

function modifier_convergence_perks:PopBalloon(parent, runtime)
    if (runtime.balloons or 0) <= 0 then return end
    runtime.balloons = math.max(0, runtime.balloons - 1)
    self:SyncBalloonVisuals(parent, runtime.balloons)
    if runtime.balloons == 0 then
        runtime.balloon_expires = 0
        FindClearSpaceForUnit(parent, GetGroundPosition(parent:GetAbsOrigin(), parent), true)
    end
    EmitSoundOn("Trynafix.Perk.BalloonPop", parent)
end

function modifier_convergence_balloon_target:IsHidden() return true end
function modifier_convergence_balloon_target:IsDebuff() return false end
function modifier_convergence_balloon_target:IsPurgable() return false end
function modifier_convergence_balloon_target:RemoveOnDeath() return true end

function modifier_convergence_balloon_target:OnCreated(kv)
    if not IsServer() then return end
    self.ownerEntIndex = tonumber(kv and kv.owner_entindex) or -1
end

function modifier_convergence_balloon_target:DeclareFunctions()
    return {
        MODIFIER_EVENT_ON_ATTACK_LANDED,
        MODIFIER_PROPERTY_ABSOLUTE_NO_DAMAGE_PHYSICAL,
        MODIFIER_PROPERTY_ABSOLUTE_NO_DAMAGE_MAGICAL,
        MODIFIER_PROPERTY_ABSOLUTE_NO_DAMAGE_PURE
    }
end

function modifier_convergence_balloon_target:CheckState()
    return {
        [MODIFIER_STATE_ROOTED] = true,
        [MODIFIER_STATE_DISARMED] = true,
        [MODIFIER_STATE_SILENCED] = true,
        [MODIFIER_STATE_MUTED] = true,
        [MODIFIER_STATE_COMMAND_RESTRICTED] = true,
        [MODIFIER_STATE_MAGIC_IMMUNE] = true,
        [MODIFIER_STATE_NO_UNIT_COLLISION] = true,
        [MODIFIER_STATE_NOT_ON_MINIMAP] = true
    }
end

function modifier_convergence_balloon_target:GetAbsoluteNoDamagePhysical() return 1 end
function modifier_convergence_balloon_target:GetAbsoluteNoDamageMagical() return 1 end
function modifier_convergence_balloon_target:GetAbsoluteNoDamagePure() return 1 end

function modifier_convergence_balloon_target:OnAttackLanded(params)
    if not IsServer() or params.target ~= self:GetParent() then return end
    local attacker = params.attacker
    if not attacker or attacker:IsNull() or not attacker.IsRealHero or not attacker:IsRealHero() then return end
    if attacker.IsIllusion and attacker:IsIllusion() then return end

    local owner = self.ownerEntIndex >= 0 and EntIndexToHScript(self.ownerEntIndex) or nil
    if not owner or owner:IsNull() or not owner:IsAlive() then return end
    if attacker:GetTeamNumber() == owner:GetTeamNumber() then return end

    local controller = owner:FindModifierByName("modifier_convergence_perks")
    local runtime = runtimeFor(owner)
    if not controller or not runtime or (runtime.balloons or 0) <= 0 then return end

    controller:PopBalloon(owner, runtime)
    if PerkService then PerkService:Publish(getPlayerID(owner)) end
end

function modifier_convergence_perks:TrySnapback(parent, runtime, rank, currentTime)
    if rank <= 0 or currentTime < (runtime.snapback_ready or 0) then return false end
    if parent:GetHealth() > parent:GetMaxHealth() * 0.30 or not parent:IsAlive() then return false end

    local snapshot = nil
    local targetTime = currentTime - 3
    for index = #runtime.history, 1, -1 do
        local candidate = runtime.history[index]
        -- The history is sampled by an interval think, whose exact cadence can
        -- drift slightly under load. Accept the closest snapshot at least 2.75
        -- seconds old instead of silently failing for a few missing frames.
        if candidate.time <= targetTime + 0.25 and validPosition(candidate.position) then
            snapshot = candidate
            break
        end
    end
    if not snapshot then return false end

    local oldPosition = parent:GetAbsOrigin()
    local lostHealth = math.max(0, snapshot.health - parent:GetHealth())
    runtime.snapback_ready = currentTime + SNAPBACK_COOLDOWN[rank]
    PerkService:StartAbilityCooldown(parent, "temporal_snapback", SNAPBACK_COOLDOWN[rank])
    FindClearSpaceForUnit(parent, GetGroundPosition(snapshot.position, parent), true)
    if lostHealth > 0 then
        local restored = math.floor(lostHealth * SNAPBACK_RESTORE[rank] + 0.5)
        parent:SetHealth(math.min(parent:GetMaxHealth(), parent:GetHealth() + restored))
    end
    ProjectileManager:ProjectileDodge(parent)
    releaseBurst("particles/units/heroes/hero_faceless_void/faceless_void_time_walk_preimage.vpcf", oldPosition)
    local timeLapse = ParticleManager:CreateParticle(
        "particles/units/heroes/hero_weaver/weaver_timelapse.vpcf",
        PATTACH_ABSORIGIN_FOLLOW,
        parent
    )
    ParticleManager:SetParticleControl(timeLapse, 0, parent:GetAbsOrigin())
    ParticleManager:ReleaseParticleIndex(timeLapse)

    -- The abandoned timeline ruptures where the hero was standing, punishing
    -- enemies that committed to the low-health chase.
    local ability = parent:FindAbilityByName("convergence_perk_temporal_snapback")
    local rupturePosition = GetGroundPosition(oldPosition, parent)
    local enemies = FindUnitsInRadius(
        parent:GetTeamNumber(), rupturePosition, nil, 325,
        DOTA_UNIT_TARGET_TEAM_ENEMY, DOTA_UNIT_TARGET_HERO,
        DOTA_UNIT_TARGET_FLAG_NONE, FIND_ANY_ORDER, false
    )
    for _, enemy in ipairs(enemies) do
        if enemy and not enemy:IsNull() and enemy:IsAlive() then
            ApplyDamage({
                victim = enemy,
                attacker = parent,
                ability = ability,
                damage = SNAPBACK_RUPTURE_DAMAGE[rank],
                damage_type = DAMAGE_TYPE_MAGICAL
            })
            enemy:AddNewModifier(parent, ability, "modifier_perk_temporal_rupture_slow", {
                duration = 2.5,
                slow = SNAPBACK_RUPTURE_SLOW[rank]
            })
        end
    end
    releaseBurst("particles/units/heroes/hero_faceless_void/faceless_dust_hit.vpcf", rupturePosition)
    EmitSoundOn("Trynafix.Perk.Snapback", parent)
    return true
end

function modifier_convergence_perks:TryHolo(parent, runtime, rank, currentTime, previousHealth)
    if rank <= 0 or currentTime < (runtime.holo_ready or 0) then return end
    local threshold = parent:GetMaxHealth() * 0.50
    if previousHealth <= threshold or parent:GetHealth() > threshold or not parent:IsAlive() then return end

    runtime.holo_ready = currentTime + HOLO_COOLDOWN[rank]
    PerkService:StartAbilityCooldown(parent, "holo_hustle", HOLO_COOLDOWN[rank])
    local duration = HOLO_DURATION[rank]

    local ability = parent:FindAbilityByName("convergence_perk_holo_hustle")
    parent:Heal(150, ability)

    local illusions = CreateIllusions(parent, parent, {
        outgoing_damage = -75,
        incoming_damage = 200,
        bounty_base = 0,
        bounty_growth = 0,
        duration = duration
    }, 2, 96, true, true)

    for _, illusion in ipairs(illusions or {}) do
        illusion:SetControllableByPlayer(getPlayerID(parent), true)
    end
end

function modifier_convergence_perks:TryKaiju(parent, runtime, rank, currentTime)
    if rank <= 0 or not parent:IsAlive() then return end
    if currentTime < (runtime.kaiju_ready or 0) then return end
    if parent:HasModifier("modifier_perk_kaiju_form") then return end
    if currentTime < (runtime.kaiju_last_stack or 0) + 0.75 then return end

    runtime.kaiju_last_stack = currentTime
    runtime.kaiju_stacks = math.min(KAIJU_HITS_REQUIRED, (runtime.kaiju_stacks or 0) + 1)
    local counter = ParticleManager:CreateParticle(
        "particles/units/heroes/hero_primal_beast/primal_beast_uproar_counter.vpcf",
        PATTACH_OVERHEAD_FOLLOW,
        parent
    )
    ParticleManager:SetParticleControl(counter, 1, Vector(runtime.kaiju_stacks, 0, 0))
    ParticleManager:ReleaseParticleIndex(counter)
    if runtime.kaiju_stacks < KAIJU_HITS_REQUIRED then return end

    runtime.kaiju_stacks = 0
    runtime.kaiju_ready = currentTime + KAIJU_COOLDOWN[rank]
    local ability = parent:FindAbilityByName("convergence_perk_kaiju_protocol")
    PerkService:StartAbilityCooldown(parent, "kaiju_protocol", KAIJU_COOLDOWN[rank])
    parent:AddNewModifier(parent, ability, "modifier_perk_kaiju_form", {
        duration = KAIJU_DURATION[rank],
        model_scale = KAIJU_MODEL_SCALE[rank],
        bonus_damage = KAIJU_BONUS_DAMAGE[rank],
        attack_speed = KAIJU_ATTACK_SPEED[rank],
        damage_reduction = KAIJU_DAMAGE_REDUCTION[rank],
        status_resistance = KAIJU_STATUS_RESISTANCE[rank]
    })

    local origin = parent:GetAbsOrigin()
    local enemies = FindUnitsInRadius(
        parent:GetTeamNumber(), origin, nil, 350,
        DOTA_UNIT_TARGET_TEAM_ENEMY,
        DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
        DOTA_UNIT_TARGET_FLAG_NONE,
        FIND_ANY_ORDER, false
    )
    for _, enemy in ipairs(enemies) do
        if enemy and not enemy:IsNull() and enemy:IsAlive() then
            ApplyDamage({
                victim = enemy,
                attacker = parent,
                ability = ability,
                damage = KAIJU_BURST_DAMAGE[rank],
                damage_type = DAMAGE_TYPE_MAGICAL
            })
            enemy:AddNewModifier(parent, ability, "modifier_knockback", {
                should_stun = 0,
                duration = 0.35,
                knockback_duration = 0.35,
                knockback_distance = 175,
                knockback_height = 40,
                center_x = origin.x,
                center_y = origin.y,
                center_z = origin.z
            })
        end
    end
    releaseBurst("particles/units/heroes/hero_primal_beast/primal_beast_roar_aoe.vpcf", origin)
    EmitSoundOn("Hero_PrimalBeast.Uproar.Cast", parent)
end

function modifier_convergence_perks:OnTakeDamage(params)
    if not IsServer() or params.unit ~= self:GetParent() or not params.damage or params.damage <= 0 then return end
    local parent = self:GetParent()
    if not PerkService:IsEnemyPlayerDamage(parent, params.attacker) then return end

    local playerID = getPlayerID(parent)
    local runtime = runtimeFor(parent)
    if not runtime then return end
    local currentTime = dotaTime()
    local healthAfterDamage = parent:GetHealth()
    local previousHealth = math.min(parent:GetMaxHealth(), healthAfterDamage + params.damage)

    if parent:HasModifier("modifier_perk_holo_escape") then
        parent:RemoveModifierByName("modifier_perk_holo_escape")
    end

    self:TryKaiju(parent, runtime, rankFor(parent, "kaiju_protocol"), currentTime)
    self:TryHolo(parent, runtime, rankFor(parent, "holo_hustle"), currentTime, previousHealth)
    self:TrySnapback(parent, runtime, rankFor(parent, "temporal_snapback"), currentTime)
    PerkService:Publish(playerID)
end

function modifier_convergence_perks:IsEligibleWildAbility(ability)
    if not ability or ability:IsNull() or ability:IsItem() then return false end
    if ability.IsToggle and ability:IsToggle() then return false end
    if ability.IsHidden and ability:IsHidden() then return false end
    local name = ability:GetAbilityName() or ""
    if name == "" or string.find(name, "special_bonus", 1, true) == 1 then return false end
    if string.find(name, "convergence_", 1, true) == 1 then return false end
    return true
end

function modifier_convergence_perks:WildBlink(parent, rank)
    if parent:IsRooted() or (parent.IsLeashed and parent:IsLeashed()) then return false end
    local distance = WILD_BLINK[rank]
    local destination = GetGroundPosition(parent:GetAbsOrigin() + parent:GetForwardVector() * distance, parent)
    if not validPosition(destination) then return false end
    local origin = parent:GetAbsOrigin()
    releaseBurst("particles/items_fx/blink_dagger_start.vpcf", origin)
    FindClearSpaceForUnit(parent, destination, true)
    ProjectileManager:ProjectileDodge(parent)
    releaseBurst("particles/items_fx/blink_dagger_end.vpcf", parent:GetAbsOrigin())
    EmitSoundOn("Trynafix.Perk.WildBlink", parent)
    return true
end

function modifier_convergence_perks:WildBarrier(parent, rank)
    parent:AddNewModifier(parent, nil, "modifier_perk_wildcard_barrier", {
        duration = 3,
        barrier = WILD_BARRIER[rank]
    })
end

function modifier_convergence_perks:WildShockwave(parent, rank)
    local origin = parent:GetAbsOrigin()
    local enemies = FindUnitsInRadius(
        parent:GetTeamNumber(), origin, nil, 325,
        DOTA_UNIT_TARGET_TEAM_ENEMY, DOTA_UNIT_TARGET_HERO,
        DOTA_UNIT_TARGET_FLAG_MAGIC_IMMUNE_ENEMIES,
        FIND_ANY_ORDER, false
    )
    for _, enemy in ipairs(enemies) do
        if enemy and not enemy:IsNull() and enemy:IsAlive() then
            enemy:AddNewModifier(parent, nil, "modifier_knockback", {
                should_stun = 0,
                duration = 0.35,
                knockback_duration = 0.35,
                knockback_distance = WILD_PUSH[rank],
                knockback_height = 45,
                center_x = origin.x,
                center_y = origin.y,
                center_z = origin.z
            })
        end
    end
    local shockwave = ParticleManager:CreateParticle(
        "particles/econ/generic/generic_aoe_shockwave_1/generic_aoe_shockwave_1.vpcf",
        PATTACH_WORLDORIGIN,
        nil
    )
    ParticleManager:SetParticleControl(shockwave, 0, origin)
    ParticleManager:SetParticleControl(shockwave, 1, Vector(325, 0, 0))
    ParticleManager:ReleaseParticleIndex(shockwave)
    EmitSoundOn("Trynafix.Perk.WildShockwave", parent)
end

function modifier_convergence_perks:WildFirework(parent, rank)
    local origin = parent:GetAbsOrigin()
    local ability = parent:FindAbilityByName("convergence_perk_wild_card")
    local enemies = FindUnitsInRadius(
        parent:GetTeamNumber(), origin, nil, 350,
        DOTA_UNIT_TARGET_TEAM_ENEMY,
        DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
        DOTA_UNIT_TARGET_FLAG_NONE,
        FIND_ANY_ORDER, false
    )
    for _, enemy in ipairs(enemies) do
        ApplyDamage({
            victim = enemy,
            attacker = parent,
            ability = ability,
            damage = WILD_FIREWORK_DAMAGE[rank],
            damage_type = DAMAGE_TYPE_MAGICAL
        })
    end
    local firework = ParticleManager:CreateParticle(
        "particles/units/heroes/hero_snapfire/hero_snapfire_cookie_landing.vpcf",
        PATTACH_WORLDORIGIN,
        nil
    )
    ParticleManager:SetParticleControl(firework, 0, origin)
    ParticleManager:ReleaseParticleIndex(firework)
    EmitSoundOn("Hero_Snapfire.FeedCookie.Impact", parent)
end

function modifier_convergence_perks:TriggerWildCard(parent, rank)
    local rollParticle = ParticleManager:CreateParticle(
        "particles/units/heroes/hero_ogre_magi/ogre_magi_multicast.vpcf",
        PATTACH_OVERHEAD_FOLLOW,
        parent
    )
    ParticleManager:SetParticleControl(rollParticle, 1, Vector(3, 0, 0))
    ParticleManager:ReleaseParticleIndex(rollParticle)
    EmitSoundOn("Trynafix.Perk.WildRoll", parent)
    local effect = RandomInt(1, 4)
    if effect == 1 and not self:WildBlink(parent, rank) then
        effect = RandomInt(2, 4)
    end
    if effect == 2 then
        self:WildBarrier(parent, rank)
    elseif effect == 3 then
        self:WildShockwave(parent, rank)
    elseif effect == 4 then
        self:WildFirework(parent, rank)
    end
end

function modifier_convergence_perks:TriggerStormChain(parent, target, runtime, rank)
    local ability = parent:FindAbilityByName("convergence_perk_storm_chaser")
    local targets = { target }
    local visited = { [target:entindex()] = true }
    local nearby = FindUnitsInRadius(
        parent:GetTeamNumber(), target:GetAbsOrigin(), nil, 600,
        DOTA_UNIT_TARGET_TEAM_ENEMY, DOTA_UNIT_TARGET_HERO,
        DOTA_UNIT_TARGET_FLAG_NONE, FIND_CLOSEST, false
    )
    for _, enemy in ipairs(nearby) do
        if #targets >= STORM_TARGETS[rank] then break end
        if enemy and not enemy:IsNull() and enemy:IsAlive()
            and enemy.IsRealHero and enemy:IsRealHero()
            and not (enemy.IsIllusion and enemy:IsIllusion())
            and not visited[enemy:entindex()] then
            visited[enemy:entindex()] = true
            table.insert(targets, enemy)
        end
    end

    local source = parent
    for _, enemy in ipairs(targets) do
        local lightning = ParticleManager:CreateParticle(
            "particles/items_fx/chain_lightning.vpcf",
            PATTACH_CUSTOMORIGIN,
            nil
        )
        ParticleManager:SetParticleControlEnt(
            lightning, 0, source, PATTACH_POINT_FOLLOW,
            "attach_hitloc", source:GetAbsOrigin(), true
        )
        ParticleManager:SetParticleControlEnt(
            lightning, 1, enemy, PATTACH_POINT_FOLLOW,
            "attach_hitloc", enemy:GetAbsOrigin(), true
        )
        ParticleManager:ReleaseParticleIndex(lightning)
        ApplyDamage({
            victim = enemy,
            attacker = parent,
            ability = ability,
            damage = STORM_DAMAGE[rank],
            damage_type = DAMAGE_TYPE_MAGICAL
        })
        source = enemy
    end

    runtime.storm_charged = 0
    runtime.storm_distance = 0
    runtime.storm_last_position = parent:GetAbsOrigin()
    parent:RemoveModifierByName("modifier_perk_storm_charged")
    EmitSoundOn("Item.Maelstrom.Chain_Lightning", parent)
    PerkService:Publish(getPlayerID(parent))
end

function modifier_convergence_perks:OnAttackLanded(params)
    if not IsServer() or params.attacker ~= self:GetParent() then return end
    local parent = self:GetParent()
    local target = params.target
    if not target or target:IsNull() or target:GetTeamNumber() == parent:GetTeamNumber() then return end
    if not target.IsRealHero or not target:IsRealHero() then return end
    if target.IsIllusion and target:IsIllusion() then return end

    local rank = rankFor(parent, "storm_chaser")
    local runtime = runtimeFor(parent)
    if rank <= 0 or not runtime or (runtime.storm_charged or 0) ~= 1 then return end
    self:TriggerStormChain(parent, target, runtime, rank)
end

function modifier_convergence_perks:TryMeteor(parent, runtime, rank, currentTime)
    if rank <= 0 or currentTime < (runtime.meteor_ready or 0) then return false end
    local enemies = FindUnitsInRadius(
        parent:GetTeamNumber(), parent:GetAbsOrigin(), nil, 900,
        DOTA_UNIT_TARGET_TEAM_ENEMY, DOTA_UNIT_TARGET_HERO,
        DOTA_UNIT_TARGET_FLAG_NONE, FIND_CLOSEST, false
    )
    local target = nil
    for _, enemy in ipairs(enemies) do
        if enemy and not enemy:IsNull() and enemy:IsAlive()
            and enemy.IsRealHero and enemy:IsRealHero()
            and not (enemy.IsIllusion and enemy:IsIllusion()) then
            target = enemy
            break
        end
    end
    if not target then return false end

    runtime.meteor_ready = currentTime + METEOR_COOLDOWN[rank]
    PerkService:StartAbilityCooldown(parent, "meteor_contract", METEOR_COOLDOWN[rank])
    local impactPosition = GetGroundPosition(target:GetAbsOrigin(), target)
    local warning = ParticleManager:CreateParticle(
        "particles/units/heroes/hero_invoker/invoker_sun_strike_team.vpcf",
        PATTACH_WORLDORIGIN,
        nil
    )
    ParticleManager:SetParticleControl(warning, 0, impactPosition)
    ParticleManager:ReleaseParticleIndex(warning)
    EmitSoundOnLocationWithCaster(impactPosition, "Hero_Invoker.SunStrike.Charge", parent)

    local caster = parent
    Timers:CreateTimer(0.8, function()
        if not caster or caster:IsNull() then return nil end
        local ability = caster:FindAbilityByName("convergence_perk_meteor_contract")
        local impact = ParticleManager:CreateParticle(
            "particles/units/heroes/hero_invoker/invoker_sun_strike.vpcf",
            PATTACH_WORLDORIGIN,
            nil
        )
        ParticleManager:SetParticleControl(impact, 0, impactPosition)
        ParticleManager:ReleaseParticleIndex(impact)
        EmitSoundOnLocationWithCaster(impactPosition, "Hero_Invoker.SunStrike.Ignite", caster)

        local victims = FindUnitsInRadius(
            caster:GetTeamNumber(), impactPosition, nil, METEOR_RADIUS[rank],
            DOTA_UNIT_TARGET_TEAM_ENEMY,
            DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
            DOTA_UNIT_TARGET_FLAG_NONE,
            FIND_ANY_ORDER, false
        )
        for _, victim in ipairs(victims) do
            if victim and not victim:IsNull() and victim:IsAlive() then
                ApplyDamage({
                    victim = victim,
                    attacker = caster,
                    ability = ability,
                    damage = METEOR_DAMAGE[rank],
                    damage_type = DAMAGE_TYPE_MAGICAL
                })
                victim:AddNewModifier(caster, ability, "modifier_stunned", {
                    duration = METEOR_STUN[rank]
                })
            end
        end
        return nil
    end)
    return true
end

function modifier_convergence_perks:OnAbilityExecuted(params)
    if not IsServer() or params.unit ~= self:GetParent() then return end
    local parent = self:GetParent()
    if parent:HasModifier("modifier_perk_holo_escape") then
        parent:RemoveModifierByName("modifier_perk_holo_escape")
    end

    if not self:IsEligibleWildAbility(params.ability) then return end
    local runtime = runtimeFor(parent)
    local currentTime = dotaTime()
    if not runtime then return end

    self:TryMeteor(parent, runtime, rankFor(parent, "meteor_contract"), currentTime)

    local rank = rankFor(parent, "wild_card")
    if rank <= 0 or currentTime < (runtime.wild_ready or 0) then
        PerkService:Publish(getPlayerID(parent))
        return
    end

    runtime.wild_count = (runtime.wild_count or 0) + 1
    if runtime.wild_count >= 3 then
        runtime.wild_count = 0
        runtime.wild_ready = currentTime + WILD_COOLDOWN[rank]
        PerkService:StartAbilityCooldown(parent, "wild_card", WILD_COOLDOWN[rank])
        self:TriggerWildCard(parent, rank)
    else
        local counterParticle = ParticleManager:CreateParticle(
            "particles/units/heroes/hero_ogre_magi/ogre_magi_multicast_counter.vpcf",
            PATTACH_OVERHEAD_FOLLOW,
            parent
        )
        ParticleManager:SetParticleControl(counterParticle, 1, Vector(runtime.wild_count, 0, 0))
        ParticleManager:ReleaseParticleIndex(counterParticle)
    end
    PerkService:Publish(getPlayerID(parent))
end

function modifier_perk_wildcard_barrier:IsHidden() return false end
function modifier_perk_wildcard_barrier:IsDebuff() return false end
function modifier_perk_wildcard_barrier:IsPurgable() return false end
function modifier_perk_wildcard_barrier:RemoveOnDeath() return true end
function modifier_perk_wildcard_barrier:GetTexture() return "aeon_disk" end
function modifier_perk_wildcard_barrier:DeclareFunctions()
    return { MODIFIER_PROPERTY_INCOMING_DAMAGE_CONSTANT }
end

function modifier_perk_wildcard_barrier:OnCreated(kv)
    self.maxBarrier = tonumber(kv and kv.barrier) or 160
    if not IsServer() then return end
    self:SetStackCount(self.maxBarrier)
    local particle = ParticleManager:CreateParticle(
        "particles/items4_fx/cyclonic_barrier.vpcf",
        PATTACH_ABSORIGIN_FOLLOW,
        self:GetParent()
    )
    self:AddParticle(particle, false, false, -1, false, false)
    EmitSoundOn("Trynafix.Perk.WildBarrier", self:GetParent())
end

function modifier_perk_wildcard_barrier:OnRefresh(kv)
    self.maxBarrier = tonumber(kv and kv.barrier) or self.maxBarrier or 160
    if IsServer() then self:SetStackCount(self.maxBarrier) end
end

function modifier_perk_wildcard_barrier:GetModifierIncomingDamageConstant(params)
    if IsClient() then
        if params and params.report_max then return self.maxBarrier end
        return self:GetStackCount()
    end
    if not params or not params.damage or params.damage <= 0 then return 0 end
    local blocked = math.min(self:GetStackCount(), params.damage)
    self:SetStackCount(self:GetStackCount() - blocked)
    if self:GetStackCount() <= 0 then self:Destroy() end
    return -blocked
end

function modifier_perk_holo_escape:IsHidden() return false end
function modifier_perk_holo_escape:IsDebuff() return false end
function modifier_perk_holo_escape:IsPurgable() return false end
function modifier_perk_holo_escape:RemoveOnDeath() return true end
function modifier_perk_holo_escape:GetTexture() return "manta" end
function modifier_perk_holo_escape:DeclareFunctions()
    return {
        MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE,
        MODIFIER_PROPERTY_INVISIBILITY_LEVEL,
        MODIFIER_EVENT_ON_ATTACK,
        MODIFIER_EVENT_ON_ABILITY_EXECUTED
    }
end

function modifier_perk_holo_escape:OnCreated(kv)
    self.moveSpeed = tonumber(kv and kv.move_speed) or 20
    self.invisibleUntil = dotaTime() + (tonumber(kv and kv.invis_duration) or 0.8)
    if IsServer() then
        local particle = ParticleManager:CreateParticle(
            "particles/items2_fx/manta_phase.vpcf",
            PATTACH_ABSORIGIN_FOLLOW,
            self:GetParent()
        )
        ParticleManager:ReleaseParticleIndex(particle)
    end
end

function modifier_perk_holo_escape:GetStatusEffectName()
    return "particles/status_fx/status_effect_phantom_lancer_illusion.vpcf"
end

function modifier_perk_holo_escape:StatusEffectPriority() return 12 end

function modifier_perk_holo_escape:CheckState()
    if dotaTime() < (self.invisibleUntil or 0) then
        return { [MODIFIER_STATE_INVISIBLE] = true }
    end
    return {}
end

function modifier_perk_holo_escape:GetModifierMoveSpeedBonus_Percentage() return self.moveSpeed or 20 end
function modifier_perk_holo_escape:GetModifierInvisibilityLevel()
    return dotaTime() < (self.invisibleUntil or 0) and 1 or 0
end
function modifier_perk_holo_escape:OnAttack(params)
    if IsServer() and params.attacker == self:GetParent() then self:Destroy() end
end
function modifier_perk_holo_escape:OnAbilityExecuted(params)
    if IsServer() and params.unit == self:GetParent() then self:Destroy() end
end

function modifier_perk_holo_decoy:IsHidden() return true end
function modifier_perk_holo_decoy:IsDebuff() return false end
function modifier_perk_holo_decoy:IsPurgable() return false end
function modifier_perk_holo_decoy:RemoveOnDeath() return true end
function modifier_perk_holo_decoy:OnCreated(kv)
    if not IsServer() then return end
    self.rank = math.max(1, math.min(3, tonumber(kv and kv.rank) or 1))
    self.ownerEntIndex = tonumber(kv and kv.owner_entindex) or -1
    self.explode = tonumber(kv and kv.explode) == 1
end
function modifier_perk_holo_decoy:GetStatusEffectName()
    return "particles/status_fx/status_effect_phantom_lancer_illusion.vpcf"
end
function modifier_perk_holo_decoy:StatusEffectPriority() return 12 end
function modifier_perk_holo_decoy:OnDestroy()
    if not IsServer() then return end
    local parent = self:GetParent()
    if parent and not parent:IsNull() then
        local position = parent:GetAbsOrigin()
        releaseBurst(
            "particles/units/heroes/hero_phantom_lancer/phantomlancer_illusion_destroy.vpcf",
            position
        )
        if not self.explode then return end
        releaseBurst(
            "particles/units/heroes/hero_arc_warden/arc_warden_wraith_prj_burst.vpcf",
            position
        )
        local owner = self.ownerEntIndex and self.ownerEntIndex >= 0
            and EntIndexToHScript(self.ownerEntIndex) or nil
        local attacker = owner and not owner:IsNull() and owner or parent
        local ability = attacker and not attacker:IsNull()
            and attacker:FindAbilityByName("convergence_perk_holo_hustle") or self:GetAbility()
        local enemies = FindUnitsInRadius(
            parent:GetTeamNumber(), position, nil, 275,
            DOTA_UNIT_TARGET_TEAM_ENEMY,
            DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
            DOTA_UNIT_TARGET_FLAG_NONE,
            FIND_ANY_ORDER, false
        )
        for _, enemy in ipairs(enemies) do
            if enemy and not enemy:IsNull() and enemy:IsAlive() then
                ApplyDamage({
                    victim = enemy,
                    attacker = attacker,
                    ability = ability,
                    damage = HOLO_BURST_DAMAGE[self.rank],
                    damage_type = DAMAGE_TYPE_MAGICAL
                })
                enemy:AddNewModifier(attacker, ability, "modifier_perk_holo_burst_slow", {
                    duration = 2,
                    slow = HOLO_BURST_SLOW[self.rank]
                })
            end
        end
        EmitSoundOnLocationWithCaster(position, "Hero_ArcWarden.SparkWraith.Damage", attacker)
    end
end
function modifier_perk_holo_decoy:CheckState()
    return {
        [MODIFIER_STATE_NO_HEALTH_BAR] = true,
        [MODIFIER_STATE_NO_UNIT_COLLISION] = true
    }
end

function modifier_perk_temporal_rupture_slow:IsHidden() return false end
function modifier_perk_temporal_rupture_slow:IsDebuff() return true end
function modifier_perk_temporal_rupture_slow:IsPurgable() return true end
function modifier_perk_temporal_rupture_slow:GetTexture() return "faceless_void_time_dilation" end
function modifier_perk_temporal_rupture_slow:OnCreated(kv)
    self.slow = tonumber(kv and kv.slow) or 20
end
function modifier_perk_temporal_rupture_slow:OnRefresh(kv)
    self.slow = tonumber(kv and kv.slow) or self.slow or 20
end
function modifier_perk_temporal_rupture_slow:DeclareFunctions()
    return { MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE }
end
function modifier_perk_temporal_rupture_slow:GetModifierMoveSpeedBonus_Percentage()
    return -(self.slow or 20)
end

function modifier_perk_treasure_rush:IsHidden() return false end
function modifier_perk_treasure_rush:IsDebuff() return false end
function modifier_perk_treasure_rush:IsPurgable() return false end
function modifier_perk_treasure_rush:RemoveOnDeath() return true end
function modifier_perk_treasure_rush:GetTexture() return "bounty_hunter_jinada" end
function modifier_perk_treasure_rush:GetEffectName()
    return "particles/units/heroes/hero_bounty_hunter/bounty_hunter_windwalk.vpcf"
end
function modifier_perk_treasure_rush:GetEffectAttachType() return PATTACH_ABSORIGIN_FOLLOW end
function modifier_perk_treasure_rush:OnCreated(kv)
    self.moveSpeed = tonumber(kv and kv.move_speed) or 500
    self.bonusDamage = tonumber(kv and kv.bonus_damage) or 20
    if IsServer() then EmitSoundOn("Hero_BountyHunter.WindWalk", self:GetParent()) end
end
function modifier_perk_treasure_rush:OnRefresh(kv)
    self.moveSpeed = tonumber(kv and kv.move_speed) or self.moveSpeed or 500
    self.bonusDamage = tonumber(kv and kv.bonus_damage) or self.bonusDamage or 20
end
function modifier_perk_treasure_rush:DeclareFunctions()
    return {
        MODIFIER_PROPERTY_MOVESPEED_ABSOLUTE,
        MODIFIER_PROPERTY_PREATTACK_BONUS_DAMAGE
    }
end
function modifier_perk_treasure_rush:GetModifierMoveSpeed_Absolute()
    return self.moveSpeed or 500
end
function modifier_perk_treasure_rush:GetModifierPreAttack_BonusDamage()
    return self.bonusDamage or 20
end

function modifier_perk_holo_burst_slow:IsHidden() return false end
function modifier_perk_holo_burst_slow:IsDebuff() return true end
function modifier_perk_holo_burst_slow:IsPurgable() return true end
function modifier_perk_holo_burst_slow:GetTexture() return "arc_warden_spark_wraith" end
function modifier_perk_holo_burst_slow:OnCreated(kv)
    self.slow = tonumber(kv and kv.slow) or 20
end
function modifier_perk_holo_burst_slow:OnRefresh(kv)
    self.slow = tonumber(kv and kv.slow) or self.slow or 20
end
function modifier_perk_holo_burst_slow:DeclareFunctions()
    return { MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE }
end
function modifier_perk_holo_burst_slow:GetModifierMoveSpeedBonus_Percentage()
    return -(self.slow or 20)
end

function modifier_perk_storm_charged:IsHidden() return false end
function modifier_perk_storm_charged:IsDebuff() return false end
function modifier_perk_storm_charged:IsPurgable() return false end
function modifier_perk_storm_charged:RemoveOnDeath() return true end
function modifier_perk_storm_charged:GetTexture() return "item_maelstrom" end
function modifier_perk_storm_charged:GetEffectName()
    return "particles/units/heroes/hero_razor/razor_unstable_current.vpcf"
end
function modifier_perk_storm_charged:GetEffectAttachType() return PATTACH_ABSORIGIN_FOLLOW end

function modifier_perk_kaiju_form:IsHidden() return false end
function modifier_perk_kaiju_form:IsDebuff() return false end
function modifier_perk_kaiju_form:IsPurgable() return false end
function modifier_perk_kaiju_form:RemoveOnDeath() return true end
function modifier_perk_kaiju_form:GetTexture() return "primal_beast_uproar" end
function modifier_perk_kaiju_form:GetEffectName()
    return "particles/units/heroes/hero_primal_beast/primal_beast_uproar_active.vpcf"
end
function modifier_perk_kaiju_form:GetEffectAttachType() return PATTACH_ABSORIGIN_FOLLOW end
function modifier_perk_kaiju_form:OnCreated(kv)
    self.modelScale = tonumber(kv and kv.model_scale) or 20
    self.bonusDamage = tonumber(kv and kv.bonus_damage) or 30
    self.attackSpeed = tonumber(kv and kv.attack_speed) or 30
    self.damageReduction = tonumber(kv and kv.damage_reduction) or 15
    self.statusResistance = tonumber(kv and kv.status_resistance) or 20
end
function modifier_perk_kaiju_form:OnRefresh(kv)
    self:OnCreated(kv)
end
function modifier_perk_kaiju_form:DeclareFunctions()
    return {
        MODIFIER_PROPERTY_MODEL_SCALE,
        MODIFIER_PROPERTY_PREATTACK_BONUS_DAMAGE,
        MODIFIER_PROPERTY_ATTACKSPEED_BONUS_CONSTANT,
        MODIFIER_PROPERTY_INCOMING_DAMAGE_PERCENTAGE,
        MODIFIER_PROPERTY_STATUS_RESISTANCE_STACKING
    }
end
function modifier_perk_kaiju_form:GetModifierModelScale() return self.modelScale or 20 end
function modifier_perk_kaiju_form:GetModifierPreAttack_BonusDamage() return self.bonusDamage or 30 end
function modifier_perk_kaiju_form:GetModifierAttackSpeedBonus_Constant() return self.attackSpeed or 30 end
function modifier_perk_kaiju_form:GetModifierIncomingDamage_Percentage()
    return -(self.damageReduction or 15)
end
function modifier_perk_kaiju_form:GetModifierStatusResistanceStacking()
    return self.statusResistance or 20
end
