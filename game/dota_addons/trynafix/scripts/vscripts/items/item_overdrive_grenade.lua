require("items/pumpkin_item_utils")

LinkLuaModifier("modifier_overdrive_grenade_flail", "items/item_overdrive_grenade", LUA_MODIFIER_MOTION_NONE)

item_overdrive_grenade = class({})

local PROJECTILE_MODEL_PARTICLE = "particles/econ/events/snowball/snowball_projectile.vpcf"
local GROUNDED_MODEL_PARTICLE = "particles/econ/events/snowball/snowball_projectile_model.vpcf"
local PROJECTILE_TRAIL_PARTICLE = "particles/econ/events/snowball/snowball_projectile_trail.vpcf"
local PROJECTILE_LAUNCH_PARTICLE = "particles/econ/events/snowball/snowball_projectile_launch.vpcf"
local PROJECTILE_EXPLOSION_PARTICLE = "particles/econ/events/snowball/snowball_projectile_explosion.vpcf"
local PROJECTILE_ENDCAP_PARTICLE = "particles/econ/events/snowball/snowball_projectile_ability_endcap.vpcf"
local FUSE_FROST_PARTICLE = "particles/units/heroes/hero_tusk/tusk_snowball_ground_frost.vpcf"
local SNOWBALL_IMPACT_PARTICLE = "particles/units/heroes/hero_tusk/tusk_snowball_impact.vpcf"

local DEFAULT_RADIUS = 325
local DEFAULT_PROJECTILE_SPEED = 1200
local DEFAULT_FUSE_DURATION = 0.55
local DEFAULT_KNOCKBACK_DISTANCE = 1400
local DEFAULT_KNOCKBACK_HEIGHT = 200
local DEFAULT_KNOCKBACK_DURATION = 1.0

local function positiveSpecial(ability, name, fallback)
    if not ability or ability:IsNull() then return fallback end
    local value = ability:GetSpecialValueFor(name)
    if not value or value <= 0 then return fallback end
    return value
end

local function setParticlePosition(particle, point)
    ParticleManager:SetParticleControl(particle, 0, point)
    ParticleManager:SetParticleControl(particle, 3, point)
    ParticleManager:SetParticleControl(particle, 4, point)
end

local function destroyParticle(particle, immediately)
    if not particle then return end
    ParticleManager:DestroyParticle(particle, immediately == true)
    ParticleManager:ReleaseParticleIndex(particle)
end

local function createWorldParticle(name, point, radius)
    local particle = ParticleManager:CreateParticle(name, PATTACH_WORLDORIGIN, nil)
    setParticlePosition(particle, point)
    if radius then
        ParticleManager:SetParticleControl(particle, 1, Vector(radius, 0, 0))
    end
    ParticleManager:ReleaseParticleIndex(particle)
end

local function createTimedWorldParticle(name, point, duration)
    local particle = ParticleManager:CreateParticle(name, PATTACH_WORLDORIGIN, nil)
    setParticlePosition(particle, point)
    GameRules:GetGameModeEntity():SetContextThink(DoUniqueString("OverdriveSnowParticle"), function()
        destroyParticle(particle, false)
        return nil
    end, duration)
end

local function validLaunchTarget(unit)
    if not unit or unit:IsNull() or not unit:IsAlive() then return false end
    if not unit:IsRealHero() or unit:IsIllusion() then return false end
    if unit:IsInvulnerable() or unit:IsMagicImmune() then return false end
    if unit.IsClone and unit:IsClone() then return false end
    if unit.IsTempestDouble and unit:IsTempestDouble() then return false end
    return true
end

function item_overdrive_grenade:GetAOERadius()
    return positiveSpecial(self, "radius", DEFAULT_RADIUS)
end

function item_overdrive_grenade:SetProjectileVisualPosition(point)
    if self._overdriveModelParticle then
        setParticlePosition(self._overdriveModelParticle, point)
    end
    if self._overdriveTrailParticle then
        setParticlePosition(self._overdriveTrailParticle, point)
    end
end

function item_overdrive_grenade:DestroyProjectileVisuals()
    destroyParticle(self._overdriveModelParticle, true)
    destroyParticle(self._overdriveTrailParticle, true)
    destroyParticle(self._overdriveFuseParticle, true)
    self._overdriveModelParticle = nil
    self._overdriveTrailParticle = nil
    self._overdriveFuseParticle = nil
end

function item_overdrive_grenade:OnSpellStart()
    if not IsServer() then return end

    local caster = self:GetCaster()
    if not caster or caster:IsNull() or not caster:IsAlive() then return end

    local casterOrigin = caster:GetAbsOrigin()
    local cursorPoint = self:GetCursorPosition()
    local offset = cursorPoint - casterOrigin
    offset.z = 0
    if offset:Length2D() < 32 then
        offset = caster:GetForwardVector() * 32
        cursorPoint = casterOrigin + offset
    end

    local landingPoint = GetGroundPosition(cursorPoint, caster)
    local incomingDirection = offset:Normalized()

    if not PumpkinItemUtils:SpendChargeImmediately(self) then return end
    EmitSoundOn("OverdriveGrenade.Throw", caster)

    local projectileSpeed = positiveSpecial(self, "projectile_speed", DEFAULT_PROJECTILE_SPEED)
    local distance = (landingPoint - casterOrigin):Length2D()
    local spawnPoint = casterOrigin + Vector(0, 0, 64)
    self:DestroyProjectileVisuals()
    self._overdriveLandingPoint = landingPoint
    self._overdriveIncomingDirection = incomingDirection
    self._overdriveLanded = false
    self._overdriveResolved = false

    self._overdriveModelParticle = ParticleManager:CreateParticle(PROJECTILE_MODEL_PARTICLE, PATTACH_WORLDORIGIN, nil)
    self:SetProjectileVisualPosition(spawnPoint)

    local projectile = ProjectileManager:CreateLinearProjectile({
        Ability = self,
        Source = caster,
        vSpawnOrigin = spawnPoint,
        fStartRadius = 16,
        fEndRadius = 16,
        fDistance = distance,
        iUnitTargetTeam = DOTA_UNIT_TARGET_TEAM_BOTH,
        iUnitTargetFlags = DOTA_UNIT_TARGET_FLAG_NONE,
        iUnitTargetType = DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
        vVelocity = incomingDirection * projectileSpeed,
        bHasFrontalCone = false,
        bReplaceExisting = false,
        bDeleteOnHit = false,
        bProvidesVision = false,
        fExpireTime = GameRules:GetGameTime() + distance / projectileSpeed + 1
    })

    if not projectile then
        self:LandOverdriveGrenade(landingPoint)
    end
end

function item_overdrive_grenade:OnProjectileThink(location)
    if not IsServer() or self._overdriveResolved or self._overdriveLanded then return end
    if location then self:SetProjectileVisualPosition(location) end
end

function item_overdrive_grenade:OnProjectileHit(target, location)
    if not IsServer() then return false end
    if target then return false end
    if self._overdriveResolved or self._overdriveLanded then return true end

    local caster = self:GetCaster()
    local landingPoint = self._overdriveLandingPoint or location
    if caster and not caster:IsNull() then
        landingPoint = GetGroundPosition(landingPoint or caster:GetAbsOrigin(), caster)
        EmitSoundOnLocationWithCaster(landingPoint, "OverdriveGrenade.Land", caster)
        EmitSoundOnLocationWithCaster(landingPoint, "Hero_Tusk.Snowball.ProjectileHit", caster)
    end

    self:LandOverdriveGrenade(landingPoint, true)
    return true
end

function item_overdrive_grenade:LandOverdriveGrenade(point, landingSoundStarted)
    if self._overdriveLanded or self._overdriveResolved then return end
    self._overdriveLanded = true

    local caster = self:GetCaster()
    if not caster or caster:IsNull() then
        self._overdriveResolved = true
        self:DestroyProjectileVisuals()
        PumpkinItemUtils:FinishImmediateSpend(self)
        return
    end

    point = GetGroundPosition(point or caster:GetAbsOrigin(), caster)
    self._overdriveLandingPoint = point
    local fuseDuration = positiveSpecial(self, "fuse_duration", DEFAULT_FUSE_DURATION)
    local fusePoint = point + Vector(0, 0, 32)
    destroyParticle(self._overdriveModelParticle, true)
    self._overdriveModelParticle = ParticleManager:CreateParticle(GROUNDED_MODEL_PARTICLE, PATTACH_WORLDORIGIN, nil)
    self:SetProjectileVisualPosition(fusePoint)
    self._overdriveFuseParticle = ParticleManager:CreateParticle(FUSE_FROST_PARTICLE, PATTACH_WORLDORIGIN, nil)
    setParticlePosition(self._overdriveFuseParticle, point)
    if not landingSoundStarted then
        EmitSoundOnLocationWithCaster(point, "OverdriveGrenade.Land", caster)
        EmitSoundOnLocationWithCaster(point, "Hero_Tusk.Snowball.ProjectileHit", caster)
    end

    local ability = self
    local modelParticle = self._overdriveModelParticle
    local trailParticle = self._overdriveTrailParticle
    local fuseParticle = self._overdriveFuseParticle
    GameRules:GetGameModeEntity():SetContextThink(DoUniqueString("OverdriveGrenadeFuse"), function()
        if ability and not ability:IsNull() then
            ability:ResolveOverdriveGrenadeFuse()
        else
            destroyParticle(modelParticle, true)
            destroyParticle(trailParticle, true)
            destroyParticle(fuseParticle, true)
        end
        return nil
    end, fuseDuration)
end

function item_overdrive_grenade:ResolveOverdriveGrenadeFuse()
    if self._overdriveResolved then return end
    self._overdriveResolved = true

    local point = self._overdriveLandingPoint
    local incomingDirection = self._overdriveIncomingDirection
    self._overdriveLandingPoint = nil
    self._overdriveIncomingDirection = nil
    self:DetonateOverdriveGrenade(point, incomingDirection)
    self:DestroyProjectileVisuals()
end

function item_overdrive_grenade:DetonateOverdriveGrenade(point, incomingDirection)
    if not IsServer() then return end

    local caster = self:GetCaster()
    if not caster or caster:IsNull() then
        PumpkinItemUtils:FinishImmediateSpend(self)
        return
    end

    point = GetGroundPosition(point or caster:GetAbsOrigin(), caster)
    incomingDirection = incomingDirection or caster:GetForwardVector()
    incomingDirection.z = 0
    if incomingDirection:Length2D() <= 0.01 then
        incomingDirection = Vector(1, 0, 0)
    else
        incomingDirection = incomingDirection:Normalized()
    end

    local radius = positiveSpecial(self, "radius", DEFAULT_RADIUS)
    local knockbackDistance = positiveSpecial(self, "knockback_distance", DEFAULT_KNOCKBACK_DISTANCE)
    local knockbackHeight = positiveSpecial(self, "knockback_height", DEFAULT_KNOCKBACK_HEIGHT)
    local knockbackDuration = positiveSpecial(self, "knockback_duration", DEFAULT_KNOCKBACK_DURATION)

    createWorldParticle(PROJECTILE_EXPLOSION_PARTICLE, point)
    createWorldParticle(PROJECTILE_ENDCAP_PARTICLE, point)
    createWorldParticle(SNOWBALL_IMPACT_PARTICLE, point)

    local heroes = FindUnitsInRadius(
        caster:GetTeamNumber(),
        point,
        nil,
        radius,
        DOTA_UNIT_TARGET_TEAM_BOTH,
        DOTA_UNIT_TARGET_HERO,
        DOTA_UNIT_TARGET_FLAG_NONE,
        FIND_ANY_ORDER,
        false
    )

    for _, hero in ipairs(heroes) do
        if validLaunchTarget(hero) then
            local heroOrigin = hero:GetAbsOrigin()
            local launchDirection = heroOrigin - point
            launchDirection.z = 0
            if launchDirection:Length2D() <= 0.01 then
                launchDirection = incomingDirection
            else
                launchDirection = launchDirection:Normalized()
            end

            hero:InterruptMotionControllers(true)
            local center = heroOrigin - launchDirection
            hero:AddNewModifier(caster, self, "modifier_knockback", {
                should_stun = 0,
                duration = knockbackDuration,
                knockback_duration = knockbackDuration,
                knockback_distance = knockbackDistance,
                knockback_height = knockbackHeight,
                center_x = center.x,
                center_y = center.y,
                center_z = center.z
            })
            if hero == caster then
                hero:AddNewModifier(caster, self, "modifier_overdrive_grenade_flail", {
                    duration = knockbackDuration
                })
            end

            local trail = ParticleManager:CreateParticle(PROJECTILE_TRAIL_PARTICLE, PATTACH_ABSORIGIN_FOLLOW, hero)
            ParticleManager:SetParticleControlEnt(
                trail,
                3,
                hero,
                PATTACH_POINT_FOLLOW,
                "attach_hitloc",
                heroOrigin,
                true
            )

            local launchedHero = hero
            GameRules:GetGameModeEntity():SetContextThink(DoUniqueString("OverdriveGrenadeLanding"), function()
                destroyParticle(trail, false)
                if launchedHero and not launchedHero:IsNull() and launchedHero:IsAlive()
                    and not launchedHero:HasModifier("modifier_knockback") then
                    FindClearSpaceForUnit(launchedHero, launchedHero:GetAbsOrigin(), true)
                end
                return nil
            end, knockbackDuration + 0.05)
        end
    end

    PumpkinItemUtils:FinishImmediateSpend(self)
end

modifier_overdrive_grenade_flail = class({})

function modifier_overdrive_grenade_flail:IsHidden() return true end
function modifier_overdrive_grenade_flail:IsPurgable() return false end
function modifier_overdrive_grenade_flail:IgnoreTenacity() return true end
function modifier_overdrive_grenade_flail:GetPriority() return MODIFIER_PRIORITY_HIGH end

function modifier_overdrive_grenade_flail:DeclareFunctions()
    return { MODIFIER_PROPERTY_OVERRIDE_ANIMATION }
end

function modifier_overdrive_grenade_flail:GetOverrideAnimation()
    return ACT_DOTA_FLAIL
end
