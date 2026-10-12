LinkLuaModifier("modifier_gravity_marble_pull", "items/item_gravity_marble", LUA_MODIFIER_MOTION_HORIZONTAL)
LinkLuaModifier("modifier_gravity_marble_root", "items/item_gravity_marble", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_custom_item_stats", "Modifiers/modifier_custom_item_stats", LUA_MODIFIER_MOTION_NONE)
require("items/pumpkin_item_utils")

item_gravity_marble = class({})

function item_gravity_marble:GetIntrinsicModifierName() return "modifier_custom_item_stats" end

local VACUUM_PARTICLE = "particles/units/heroes/hero_dark_seer/dark_seer_vacuum.vpcf"
local DEFAULT_RADIUS = 425
local DEFAULT_DELAY = 0.45
local DEFAULT_PULL_DURATION = 0.35
local DEFAULT_ROOT_DURATION = 1.25

local function positiveSpecial(ability, name, fallback)
    if not ability or ability:IsNull() then return fallback end
    local value = ability:GetSpecialValueFor(name)
    if not value or value <= 0 then return fallback end
    return value
end

local function validGravityTarget(unit)
    if not unit or unit:IsNull() or not unit:IsAlive() then return false end
    if unit:IsBuilding() or unit:IsMagicImmune() then return false end
    if unit.IsRoshan and unit:IsRoshan() then return false end
    if unit.IsBoss and unit:IsBoss() then return false end
    local name = unit.GetUnitName and unit:GetUnitName() or ""
    return name ~= "npc_custom_roshan"
        and name ~= "npc_island_miniboss"
end

local function createVacuumParticle(point, radius)
    local particle = ParticleManager:CreateParticle(VACUUM_PARTICLE, PATTACH_WORLDORIGIN, nil)
    ParticleManager:SetParticleControl(particle, 0, point)
    ParticleManager:SetParticleControl(particle, 1, Vector(radius, 0, 0))
    ParticleManager:ReleaseParticleIndex(particle)
end

function item_gravity_marble:OnSpellStart()
    if not IsServer() then return end
    local caster = self:GetCaster()
    if not caster or caster:IsNull() or not caster:IsAlive() then return end

    local point = GetGroundPosition(self:GetCursorPosition(), caster)
    local radius = positiveSpecial(self, "radius", DEFAULT_RADIUS)
    PumpkinItemUtils:SpendChargeImmediately(self)

    createVacuumParticle(point, radius)
    local ability = self
    local delay = positiveSpecial(self, "delay", DEFAULT_DELAY)
    GameRules:GetGameModeEntity():SetContextThink(DoUniqueString("GravityMarble"), function()
        if ability and not ability:IsNull() then ability:DetonateGravityMarble(point) end
        return nil
    end, delay)
end

function item_gravity_marble:DetonateGravityMarble(point)
    if not IsServer() then return end
    local caster = self:GetCaster()
    if not caster or caster:IsNull() or not caster:IsAlive() then
        PumpkinItemUtils:FinishImmediateSpend(self)
        return
    end

    -- Keep the item functional after script_reload even when Workshop Tools is
    -- still holding an older copy of npc_items_custom.txt in memory.
    local radius = positiveSpecial(self, "radius", DEFAULT_RADIUS)
    local pullDuration = positiveSpecial(self, "pull_duration", DEFAULT_PULL_DURATION)
    local rootDuration = positiveSpecial(self, "root_duration", DEFAULT_ROOT_DURATION)
    EmitSoundOnLocationWithCaster(point, "Hero_Dark_Seer.Vacuum", caster)
    createVacuumParticle(point, radius)

    local enemies = FindUnitsInRadius(
        caster:GetTeamNumber(),
        point,
        nil,
        radius,
        DOTA_UNIT_TARGET_TEAM_ENEMY,
        DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
        DOTA_UNIT_TARGET_FLAG_NONE,
        FIND_ANY_ORDER,
        false
    )

    local affected = 0
    for _, enemy in ipairs(enemies) do
        if validGravityTarget(enemy) then
            affected = affected + 1
            enemy:InterruptMotionControllers(true)
            local statusResistance = math.max(0, math.min(1, enemy:GetStatusResistance()))
            local adjustedRoot = rootDuration * (1 - statusResistance)

            -- Root is independent of the movement controller. It starts while
            -- the victim is being pulled and remains for the promised duration
            -- after the pull finishes.
            enemy:AddNewModifier(caster, self, "modifier_gravity_marble_root", {
                duration = pullDuration + adjustedRoot
            })

            local pull = enemy:AddNewModifier(caster, self, "modifier_gravity_marble_pull", {
                duration = pullDuration,
                target_x = point.x,
                target_y = point.y,
                target_z = point.z
            })

            -- A unit rejected by another horizontal motion controller must
            -- still receive the promised displacement and root.
            if not pull then
                FindClearSpaceForUnit(enemy, point, true)
            end
        end
    end

    local ability = self
    local consumeDelay = affected > 0 and (pullDuration + rootDuration + 0.1) or 0.05
    GameRules:GetGameModeEntity():SetContextThink(DoUniqueString("GravityMarbleConsume"), function()
        if ability and not ability:IsNull() then PumpkinItemUtils:FinishImmediateSpend(ability) end
        return nil
    end, consumeDelay)
end

modifier_gravity_marble_pull = class({})

function modifier_gravity_marble_pull:IsHidden() return true end
function modifier_gravity_marble_pull:IsDebuff() return true end
function modifier_gravity_marble_pull:IsPurgable() return false end
function modifier_gravity_marble_pull:IgnoreTenacity() return true end

function modifier_gravity_marble_pull:OnCreated(kv)
    if not IsServer() then return end
    local parent = self:GetParent()
    self.startPosition = parent:GetAbsOrigin()
    self.targetPosition = Vector(
        tonumber(kv.target_x) or self.startPosition.x,
        tonumber(kv.target_y) or self.startPosition.y,
        tonumber(kv.target_z) or self.startPosition.z
    )
    self.pullDuration = math.max(FrameTime(), tonumber(kv.duration) or DEFAULT_PULL_DURATION)
    self.elapsed = 0
    self.reachedTarget = false
    self.motionInterrupted = false

    if not self:ApplyHorizontalMotionController() then
        -- Do not silently lose the pull when another controller wins priority.
        FindClearSpaceForUnit(parent, self.targetPosition, true)
        self.reachedTarget = true
        self:Destroy()
    end
end

function modifier_gravity_marble_pull:UpdateHorizontalMotion(parent, deltaTime)
    if not IsServer() then return end
    if not parent or parent:IsNull() or not parent:IsAlive() then
        self:Destroy()
        return
    end

    self.elapsed = self.elapsed + deltaTime
    local progress = math.min(1, self.elapsed / self.pullDuration)
    local nextPosition = self.startPosition + (self.targetPosition - self.startPosition) * progress
    nextPosition = GetGroundPosition(nextPosition, parent)
    parent:SetAbsOrigin(nextPosition)

    if progress >= 1 then
        self.reachedTarget = true
        self:Destroy()
    end
end

function modifier_gravity_marble_pull:OnHorizontalMotionInterrupted()
    if not IsServer() then return end
    self.motionInterrupted = true
    self:Destroy()
end

function modifier_gravity_marble_pull:OnDestroy()
    if not IsServer() then return end
    local parent = self:GetParent()
    if not parent or parent:IsNull() then return end

    parent:RemoveHorizontalMotionController(self)
    if not parent:IsAlive() then return end

    -- Natural expiration can happen between motion-update frames. Snap only
    -- that case to the center; an externally interrupted pull stays put.
    if not self.motionInterrupted and self.targetPosition then
        FindClearSpaceForUnit(parent, self.targetPosition, true)
    else
        ResolveNPCPositions(parent:GetAbsOrigin(), 64)
    end
end

function modifier_gravity_marble_pull:CheckState()
    return {
        [MODIFIER_STATE_STUNNED] = true,
        [MODIFIER_STATE_NO_UNIT_COLLISION] = true
    }
end

modifier_gravity_marble_root = class({})

function modifier_gravity_marble_root:IsDebuff() return true end
function modifier_gravity_marble_root:IsPurgable() return true end
function modifier_gravity_marble_root:IgnoreTenacity() return true end
function modifier_gravity_marble_root:GetTexture() return "item_gravity_marble" end

function modifier_gravity_marble_root:CheckState()
    return { [MODIFIER_STATE_ROOTED] = true }
end
