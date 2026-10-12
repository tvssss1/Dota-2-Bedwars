LinkLuaModifier("modifier_skyhook_spool_motion", "items/item_skyhook_spool", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_skyhook_spool_enemy_burn", "items/item_skyhook_spool", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_skyhook_spool_ally_aura", "items/item_skyhook_spool", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_skyhook_spool_aura_slow", "items/item_skyhook_spool", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_custom_item_stats", "Modifiers/modifier_custom_item_stats", LUA_MODIFIER_MOTION_NONE)

item_skyhook_spool = class({})

function item_skyhook_spool:GetIntrinsicModifierName() return "modifier_custom_item_stats" end

-- The matching chain particle contains the requested hook-head VPCF as a
-- child, so this produces both the chain and the exact Aberrant hook model.
local HOOK_PARTICLE = "particles/econ/items/pudge/aberrant/red_arcana/aberrant_red_arcana_meathook_chain.vpcf"
local ENEMY_FIRE_PARTICLE = "particles/units/heroes/hero_jakiro/jakiro_liquid_fire_debuff.vpcf"
local ALLY_FIRE_PARTICLE = "particles/units/heroes/hero_ember_spirit/ember_spirit_flameguard.vpcf"
local HOOK_TICK = 0.03
local HOOK_CAST_RANGE = 1100

local function positiveSpecial(ability, name, fallback)
    local value = ability:GetSpecialValueFor(name)
    if not value or value <= 0 then return fallback end
    return value
end

local function numberOrFallback(value, fallback)
    local result = tonumber(value)
    if not result then return fallback end
    return result
end

local function isTree(target)
    if not target or target:IsNull() then return false end
    local className = target.GetClassname and target:GetClassname() or ""
    return className == "ent_dota_tree" or (target.IsStanding ~= nil and target.IsAlive == nil)
end

local function isStandingTree(target)
    if not isTree(target) then return false end
    return not target.IsStanding or target:IsStanding()
end

local function isValidUnit(target)
    return target and not target:IsNull() and target.IsAlive and target:IsAlive()
end

local function canMoveHookTarget(target)
    if not isValidUnit(target) then return false end
    if target:IsBuilding() then return false end
    if target.IsWard and target:IsWard() then return false end
    if target.IsBoss and target:IsBoss() then return false end
    if target.IsRoshan and target:IsRoshan() then return false end

    local name = target.GetUnitName and target:GetUnitName() or ""
    return name ~= "npc_custom_roshan"
        and name ~= "npc_island_miniboss"
end

local function validAbility(ability)
    if ability and not ability:IsNull() then return ability end
    return nil
end

-- Direct targeting only: units and tree entities are both clicked directly.
function item_skyhook_spool:GetBehavior()
    return DOTA_ABILITY_BEHAVIOR_UNIT_TARGET
end

function item_skyhook_spool:GetCastRange(_location, _target)
    return HOOK_CAST_RANGE
end

function item_skyhook_spool:DestroyHookParticle()
    if not self._skyhookParticle then return end
    ParticleManager:DestroyParticle(self._skyhookParticle, false)
    ParticleManager:ReleaseParticleIndex(self._skyhookParticle)
    self._skyhookParticle = nil
end

function item_skyhook_spool:ClearSkyhookState()
    self:DestroyHookParticle()
    self._skyhookCaster = nil
    self._skyhookOrigin = nil
    self._skyhookDestination = nil
    self._skyhookCurrentPosition = nil
    self._skyhookTarget = nil
    self._skyhookTree = nil
    self._skyhookMode = nil
    self._skyhookResolved = nil
    self._skyhookInFlight = false
end

function item_skyhook_spool:CreateHookParticle(caster, origin)
    local raisedOrigin = origin + Vector(0, 0, 80)
    local particle = ParticleManager:CreateParticle(HOOK_PARTICLE, PATTACH_CUSTOMORIGIN, nil)
    self._skyhookParticle = particle
    ParticleManager:SetParticleAlwaysSimulate(particle)

    -- CP0 follows the caster. CP3/CP6 are the moving hook end; the particle's
    -- child is the exact aberrant_red_arcana_meathook_hook.vpcf requested.
    ParticleManager:SetParticleControlEnt(
        particle,
        0,
        caster,
        PATTACH_POINT_FOLLOW,
        "attach_hitloc",
        raisedOrigin,
        true
    )
    ParticleManager:SetParticleControl(particle, 3, raisedOrigin)
    ParticleManager:SetParticleControl(particle, 4, Vector(1, 0, 0))
    ParticleManager:SetParticleControl(particle, 5, Vector(1, 0, 0))
    ParticleManager:SetParticleControl(particle, 6, raisedOrigin)
    ParticleManager:SetParticleControl(particle, 7, raisedOrigin)
end

function item_skyhook_spool:UpdateHookParticle(position)
    if self._skyhookParticle and position then
        local raisedPosition = position + Vector(0, 0, 80)
        ParticleManager:SetParticleControl(self._skyhookParticle, 3, raisedPosition)
        ParticleManager:SetParticleControl(self._skyhookParticle, 6, raisedPosition)
        ParticleManager:SetParticleControl(self._skyhookParticle, 7, raisedPosition)
    end
end

function item_skyhook_spool:OnSpellStart()
    if not IsServer() then return end

    local caster = self:GetCaster()
    if not isValidUnit(caster) or self._skyhookInFlight then return end

    local selectedTarget = self:GetCursorTarget()
    local mode = nil
    local destination = nil

    if isStandingTree(selectedTarget) then
        mode = "tree"
        destination = selectedTarget:GetAbsOrigin()
    elseif isValidUnit(selectedTarget) then
        mode = "unit"
        destination = selectedTarget:GetAbsOrigin()
    else
        return
    end

    local origin = caster:GetAbsOrigin()
    self._skyhookCaster = caster
    self._skyhookOrigin = origin
    self._skyhookDestination = GetGroundPosition(destination, caster)
    self._skyhookCurrentPosition = origin
    self._skyhookTarget = mode == "unit" and selectedTarget or nil
    self._skyhookTree = mode == "tree" and selectedTarget or nil
    self._skyhookMode = mode
    self._skyhookResolved = false
    self._skyhookInFlight = true

    EmitSoundOn("Hero_Pudge.AttackHookExtend", caster)
    self:CreateHookParticle(caster, origin)
    self:LaunchHookFlight()
end

function item_skyhook_spool:LaunchHookFlight()
    local ability = self
    local speed = positiveSpecial(self, "hook_speed", 1600)
    local lastThinkTime = GameRules:GetGameTime()
    local expireTime = lastThinkTime + 30

    GameRules:GetGameModeEntity():SetContextThink(DoUniqueString("SkyhookFlight"), function()
        if not ability or ability:IsNull() or ability._skyhookResolved then return nil end

        local caster = ability._skyhookCaster
        if not isValidUnit(caster) then
            ability:ResolveSkyhook(nil, ability._skyhookDestination)
            return nil
        end

        local destination = ability._skyhookDestination
        local target = ability._skyhookTarget
        if ability._skyhookMode == "unit" and isValidUnit(target) then
            destination = target:GetAbsOrigin()
            ability._skyhookDestination = GetGroundPosition(destination, caster)
        elseif ability._skyhookMode == "tree" and isStandingTree(ability._skyhookTree) then
            destination = ability._skyhookTree:GetAbsOrigin()
            ability._skyhookDestination = GetGroundPosition(destination, caster)
        end

        local now = GameRules:GetGameTime()
        local deltaTime = math.max(HOOK_TICK, math.min(0.1, now - lastThinkTime))
        lastThinkTime = now

        local current = ability._skyhookCurrentPosition or caster:GetAbsOrigin()
        local offset = destination - current
        local remainingDistance = offset:Length2D()
        local step = speed * deltaTime

        if remainingDistance <= step + 24 or now >= expireTime then
            ability._skyhookCurrentPosition = destination
            ability:UpdateHookParticle(destination)
            ability:ResolveSkyhook(isValidUnit(target) and target or nil, destination)
            return nil
        end

        local nextPosition = current + offset:Normalized() * step
        nextPosition.z = GetGroundHeight(nextPosition, caster)
        ability._skyhookCurrentPosition = nextPosition
        ability:UpdateHookParticle(nextPosition)
        return HOOK_TICK
    end, HOOK_TICK)
end

function item_skyhook_spool:ApplyTargetEffect(target)
    if not isValidUnit(target) then return end

    local caster = self._skyhookCaster or self:GetCaster()
    if not caster or caster:IsNull() then return end

    if target:GetTeamNumber() == caster:GetTeamNumber() then
        target:AddNewModifier(caster, self, "modifier_skyhook_spool_ally_aura", {
            duration = positiveSpecial(self, "ally_aura_duration", 8),
            radius = positiveSpecial(self, "ally_aura_radius", 350),
            damage_per_second = positiveSpecial(self, "ally_aura_dps", 45),
            slow_pct = positiveSpecial(self, "ally_aura_slow_pct", 25),
            magic_resistance = positiveSpecial(self, "ally_magic_resistance", 15)
        })
        return
    end

    target:AddNewModifier(caster, self, "modifier_skyhook_spool_enemy_burn", {
        duration = positiveSpecial(self, "enemy_burn_duration", 6),
        damage_per_second = positiveSpecial(self, "enemy_burn_dps", 60),
        slow_pct = positiveSpecial(self, "enemy_burn_slow_pct", 30)
    })
end

function item_skyhook_spool:ResolveSkyhook(target, location)
    if self._skyhookResolved then return end
    self._skyhookResolved = true

    local caster = self._skyhookCaster or self:GetCaster()
    if not isValidUnit(caster) then
        if caster and not caster:IsNull() then
            StopSoundOn("Hero_Pudge.AttackHookExtend", caster)
            StopSoundOn("Hero_Pudge.AttackHookRetract", caster)
        end
        self:ClearSkyhookState()
        return
    end

    StopSoundOn("Hero_Pudge.AttackHookExtend", caster)

    local start = self._skyhookOrigin or caster:GetAbsOrigin()
    local endpoint = GetGroundPosition(location or self._skyhookDestination or start, caster)
    local moveTarget = isValidUnit(target) and canMoveHookTarget(target)

    if isValidUnit(target) then
        EmitSoundOn("Hero_Pudge.AttackHookImpact", target)
        self:ApplyTargetEffect(target)

        local targetPosition = target:GetAbsOrigin()
        if moveTarget then
            local meetingPointPct = positiveSpecial(self, "meeting_point_pct", 70)
            local meetingFraction = math.max(0, math.min(1, meetingPointPct / 100))
            endpoint = GetGroundPosition(start + (targetPosition - start) * meetingFraction, caster)
        else
            endpoint = GetGroundPosition(targetPosition, caster)
        end
    elseif self._skyhookMode == "tree" then
        endpoint = GetGroundPosition(self._skyhookDestination or endpoint, caster)
    end

    local reelDuration = positiveSpecial(self, "reel_duration", 0.55)
    EmitSoundOn("Hero_Pudge.AttackHookRetract", caster)

    if moveTarget then
        target:InterruptMotionControllers(true)
        local targetMotion = target:AddNewModifier(caster, self, "modifier_skyhook_spool_motion", {
            duration = reelDuration,
            target_x = endpoint.x,
            target_y = endpoint.y,
            target_z = endpoint.z
        })
        if not targetMotion then FindClearSpaceForUnit(target, endpoint, true) end
    end

    caster:InterruptMotionControllers(true)
    local casterMotion = caster:AddNewModifier(caster, self, "modifier_skyhook_spool_motion", {
        duration = reelDuration,
        target_x = endpoint.x,
        target_y = endpoint.y,
        target_z = endpoint.z
    })
    if not casterMotion then FindClearSpaceForUnit(caster, endpoint, true) end

    local ability = self
    local reelStart = GameRules:GetGameTime()
    GameRules:GetGameModeEntity():SetContextThink(DoUniqueString("SkyhookReel"), function()
        if not ability or ability:IsNull() then return nil end

        local visualEndpoint = endpoint
        if isValidUnit(target) then visualEndpoint = target:GetAbsOrigin() end
        ability:UpdateHookParticle(visualEndpoint)

        if GameRules:GetGameTime() - reelStart < reelDuration then return HOOK_TICK end

        if caster and not caster:IsNull() then
            StopSoundOn("Hero_Pudge.AttackHookRetract", caster)
        end
        ability:ClearSkyhookState()
        return nil
    end, HOOK_TICK)
end

modifier_skyhook_spool_motion = class({})

function modifier_skyhook_spool_motion:IsHidden() return true end
function modifier_skyhook_spool_motion:IsPurgable() return false end

function modifier_skyhook_spool_motion:OnCreated(kv)
    if not IsServer() then return end
    self.startPosition = self:GetParent():GetAbsOrigin()
    self.targetPosition = Vector(
        numberOrFallback(kv.target_x, self.startPosition.x),
        numberOrFallback(kv.target_y, self.startPosition.y),
        numberOrFallback(kv.target_z, self.startPosition.z)
    )
    self.motionDuration = math.max(0.03, numberOrFallback(kv.duration, 0.55))
    self.startTime = GameRules:GetGameTime()
    self:StartIntervalThink(HOOK_TICK)
end

function modifier_skyhook_spool_motion:OnIntervalThink()
    if not IsServer() then return end
    local parent = self:GetParent()
    if not isValidUnit(parent) then
        self:Destroy()
        return
    end

    local progress = math.min(1, (GameRules:GetGameTime() - self.startTime) / self.motionDuration)
    local nextPosition = self.startPosition + (self.targetPosition - self.startPosition) * progress
    nextPosition.z = GetGroundHeight(nextPosition, parent)
    parent:SetAbsOrigin(nextPosition)
    if progress >= 1 then self:Destroy() end
end

function modifier_skyhook_spool_motion:OnDestroy()
    if not IsServer() then return end
    local parent = self:GetParent()
    if isValidUnit(parent) then
        FindClearSpaceForUnit(parent, parent:GetAbsOrigin(), true)
        parent:Stop()
    end
end

function modifier_skyhook_spool_motion:CheckState()
    return {
        [MODIFIER_STATE_STUNNED] = true,
        [MODIFIER_STATE_NO_UNIT_COLLISION] = true
    }
end

modifier_skyhook_spool_enemy_burn = class({})

function modifier_skyhook_spool_enemy_burn:IsDebuff() return true end
function modifier_skyhook_spool_enemy_burn:IsPurgable() return true end
function modifier_skyhook_spool_enemy_burn:GetEffectName() return ENEMY_FIRE_PARTICLE end
function modifier_skyhook_spool_enemy_burn:GetEffectAttachType() return PATTACH_ABSORIGIN_FOLLOW end

function modifier_skyhook_spool_enemy_burn:OnCreated(kv)
    self.damagePerSecond = numberOrFallback(kv.damage_per_second, 60)
    self.slowPct = numberOrFallback(kv.slow_pct, 30)
    self.damageInterval = 0.5
    if IsServer() then self:StartIntervalThink(self.damageInterval) end
end

function modifier_skyhook_spool_enemy_burn:OnRefresh(kv)
    self.damagePerSecond = numberOrFallback(kv.damage_per_second, self.damagePerSecond or 60)
    self.slowPct = numberOrFallback(kv.slow_pct, self.slowPct or 30)
end

function modifier_skyhook_spool_enemy_burn:DeclareFunctions()
    return { MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE }
end

function modifier_skyhook_spool_enemy_burn:GetModifierMoveSpeedBonus_Percentage()
    return -(self.slowPct or 30)
end

function modifier_skyhook_spool_enemy_burn:OnIntervalThink()
    if not IsServer() then return end
    local parent = self:GetParent()
    if not isValidUnit(parent) then return end

    local caster = self:GetCaster()
    local attacker = caster and not caster:IsNull() and caster or parent
    ApplyDamage({
        victim = parent,
        attacker = attacker,
        damage = (self.damagePerSecond or 60) * self.damageInterval,
        damage_type = DAMAGE_TYPE_MAGICAL,
        ability = validAbility(self:GetAbility())
    })
end

modifier_skyhook_spool_ally_aura = class({})

function modifier_skyhook_spool_ally_aura:IsDebuff() return false end
function modifier_skyhook_spool_ally_aura:IsPurgable() return true end
function modifier_skyhook_spool_ally_aura:GetEffectName() return ALLY_FIRE_PARTICLE end
function modifier_skyhook_spool_ally_aura:GetEffectAttachType() return PATTACH_ABSORIGIN_FOLLOW end

function modifier_skyhook_spool_ally_aura:OnCreated(kv)
    self.radius = numberOrFallback(kv.radius, 350)
    self.damagePerSecond = numberOrFallback(kv.damage_per_second, 45)
    self.slowPct = numberOrFallback(kv.slow_pct, 25)
    self.magicResistance = numberOrFallback(kv.magic_resistance, 15)
    self.damageInterval = 0.5
    if IsServer() then self:StartIntervalThink(self.damageInterval) end
end

function modifier_skyhook_spool_ally_aura:OnRefresh(kv)
    self.radius = numberOrFallback(kv.radius, self.radius or 350)
    self.damagePerSecond = numberOrFallback(kv.damage_per_second, self.damagePerSecond or 45)
    self.slowPct = numberOrFallback(kv.slow_pct, self.slowPct or 25)
    self.magicResistance = numberOrFallback(kv.magic_resistance, self.magicResistance or 15)
end

function modifier_skyhook_spool_ally_aura:DeclareFunctions()
    return { MODIFIER_PROPERTY_MAGICAL_RESISTANCE_BONUS }
end

function modifier_skyhook_spool_ally_aura:GetModifierMagicalResistanceBonus()
    return self.magicResistance or 15
end

function modifier_skyhook_spool_ally_aura:OnIntervalThink()
    if not IsServer() then return end
    local parent = self:GetParent()
    if not isValidUnit(parent) then return end

    local caster = self:GetCaster()
    local attacker = caster and not caster:IsNull() and caster or parent
    local ability = validAbility(self:GetAbility())
    local enemies = FindUnitsInRadius(
        parent:GetTeamNumber(),
        parent:GetAbsOrigin(),
        nil,
        self.radius or 350,
        DOTA_UNIT_TARGET_TEAM_ENEMY,
        DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
        DOTA_UNIT_TARGET_FLAG_MAGIC_IMMUNE_ENEMIES,
        FIND_ANY_ORDER,
        false
    )

    for _, enemy in ipairs(enemies) do
        if isValidUnit(enemy) then
            ApplyDamage({
                victim = enemy,
                attacker = attacker,
                damage = (self.damagePerSecond or 45) * self.damageInterval,
                damage_type = DAMAGE_TYPE_MAGICAL,
                ability = ability
            })
            enemy:AddNewModifier(attacker, ability, "modifier_skyhook_spool_aura_slow", {
                duration = self.damageInterval + 0.2,
                slow_pct = self.slowPct or 25
            })
        end
    end
end

modifier_skyhook_spool_aura_slow = class({})

function modifier_skyhook_spool_aura_slow:IsDebuff() return true end
function modifier_skyhook_spool_aura_slow:IsPurgable() return true end
function modifier_skyhook_spool_aura_slow:GetEffectName() return ENEMY_FIRE_PARTICLE end
function modifier_skyhook_spool_aura_slow:GetEffectAttachType() return PATTACH_ABSORIGIN_FOLLOW end

function modifier_skyhook_spool_aura_slow:OnCreated(kv)
    self.slowPct = numberOrFallback(kv.slow_pct, 25)
end

function modifier_skyhook_spool_aura_slow:OnRefresh(kv)
    self.slowPct = numberOrFallback(kv.slow_pct, self.slowPct or 25)
end

function modifier_skyhook_spool_aura_slow:DeclareFunctions()
    return { MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE }
end

function modifier_skyhook_spool_aura_slow:GetModifierMoveSpeedBonus_Percentage()
    return -(self.slowPct or 25)
end
