LinkLuaModifier("modifier_custom_roshan_bash", "abilities/custom_roshan_abilities", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_custom_roshan_slam_slow", "abilities/custom_roshan_abilities", LUA_MODIFIER_MOTION_NONE)

ability_custom_roshan_bash = class({})

function ability_custom_roshan_bash:GetIntrinsicModifierName()
    return "modifier_custom_roshan_bash"
end

modifier_custom_roshan_bash = class({})

function modifier_custom_roshan_bash:IsHidden() return true end
function modifier_custom_roshan_bash:IsPurgable() return false end
function modifier_custom_roshan_bash:DeclareFunctions()
    return { MODIFIER_EVENT_ON_ATTACK_LANDED }
end

function modifier_custom_roshan_bash:OnAttackLanded(event)
    if not IsServer() or event.attacker ~= self:GetParent() then return end
    local target = event.target
    if not target or target:IsNull() or target:IsBuilding() or target:IsMagicImmune() then return end
    if not RollPseudoRandomPercentage(15, DOTA_PSEUDO_RANDOM_CUSTOM_GAME_1, self:GetParent()) then return end

    local level = math.max(1, self:GetAbility():GetLevel())
    local bonusDamage = ({ 25, 50, 75 })[level] or 75
    ApplyDamage({
        victim = target,
        attacker = self:GetParent(),
        damage = bonusDamage,
        damage_type = DAMAGE_TYPE_PHYSICAL,
        ability = self:GetAbility()
    })
    target:AddNewModifier(self:GetParent(), self:GetAbility(), "modifier_stunned", { duration = 1.0 })
    EmitSoundOn("Roshan.Bash", target)
end

ability_custom_roshan_slam = class({})

function ability_custom_roshan_slam:OnSpellStart()
    if not IsServer() then return end
    local caster = self:GetCaster()
    local level = math.max(1, self:GetLevel())
    local damage = ({ 80, 140, 220 })[level] or 220
    local origin = caster:GetAbsOrigin()

    EmitSoundOn("Roshan.Slam", caster)
    local particle = ParticleManager:CreateParticle("particles/neutral_fx/roshan_slam.vpcf", PATTACH_ABSORIGIN, caster)
    ParticleManager:SetParticleControl(particle, 0, origin)
    ParticleManager:ReleaseParticleIndex(particle)

    local enemies = FindUnitsInRadius(
        caster:GetTeamNumber(), origin, nil, 300,
        DOTA_UNIT_TARGET_TEAM_ENEMY,
        DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
        DOTA_UNIT_TARGET_FLAG_NONE,
        FIND_ANY_ORDER, false
    )
    for _, enemy in ipairs(enemies) do
        ApplyDamage({ victim=enemy, attacker=caster, damage=damage, damage_type=DAMAGE_TYPE_MAGICAL, ability=self })
        enemy:AddNewModifier(caster, self, "modifier_custom_roshan_slam_slow", { duration=2.0 })
    end
end

modifier_custom_roshan_slam_slow = class({})
function modifier_custom_roshan_slam_slow:IsDebuff() return true end
function modifier_custom_roshan_slam_slow:IsPurgable() return true end
function modifier_custom_roshan_slam_slow:DeclareFunctions()
    return { MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE }
end
function modifier_custom_roshan_slam_slow:GetModifierMoveSpeedBonus_Percentage() return -20 end
