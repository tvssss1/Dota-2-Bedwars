modifier_harvest_tonic_speed = class({})

function modifier_harvest_tonic_speed:IsDebuff() return false end
function modifier_harvest_tonic_speed:IsPurgable() return false end
function modifier_harvest_tonic_speed:RemoveOnDeath() return true end
function modifier_harvest_tonic_speed:GetTexture() return "harvest_tonic" end
function modifier_harvest_tonic_speed:OnCreated(kv)
    local ability = self:GetAbility()
    self.moveSpeed = tonumber(kv and kv.move_speed_pct)
        or (ability and ability:GetSpecialValueFor("active_move_speed_pct")) or 30
    self.attackSpeed = tonumber(kv and kv.attack_speed)
        or (ability and ability:GetSpecialValueFor("active_attack_speed")) or 60
    self.lifesteal = tonumber(kv and kv.lifesteal_pct)
        or (ability and ability:GetSpecialValueFor("active_lifesteal_pct")) or 20
    self.takedownHeal = tonumber(kv and kv.takedown_heal)
        or (ability and ability:GetSpecialValueFor("takedown_heal")) or 250
    self.takedownExtension = tonumber(kv and kv.takedown_extension)
        or (ability and ability:GetSpecialValueFor("takedown_extension")) or 3
    self.maxDuration = tonumber(kv and kv.max_duration)
        or (ability and ability:GetSpecialValueFor("max_duration")) or 14
    if IsServer() then self.absoluteEndTime = GameRules:GetGameTime() + self.maxDuration end
end
function modifier_harvest_tonic_speed:OnRefresh(kv) self:OnCreated(kv) end
function modifier_harvest_tonic_speed:DeclareFunctions()
    return {
        MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE,
        MODIFIER_PROPERTY_ATTACKSPEED_BONUS_CONSTANT,
        MODIFIER_EVENT_ON_TAKEDAMAGE,
        MODIFIER_EVENT_ON_DEATH
    }
end
function modifier_harvest_tonic_speed:GetModifierMoveSpeedBonus_Percentage() return self.moveSpeed or 30 end
function modifier_harvest_tonic_speed:GetModifierAttackSpeedBonus_Constant() return self.attackSpeed or 60 end

function modifier_harvest_tonic_speed:OnTakeDamage(event)
    if not IsServer() then return end
    local parent = self:GetParent()
    local victim = event.unit
    if event.attacker ~= parent or not victim or victim:IsNull()
        or victim:GetTeamNumber() == parent:GetTeamNumber()
        or victim:IsBuilding() or (event.damage or 0) <= 0
        or event.damage_category ~= DOTA_DAMAGE_CATEGORY_ATTACK then return end

    local ability = self:GetAbility()
    if ability and ability:IsNull() then ability = nil end
    parent:Heal(event.damage * (self.lifesteal or 20) / 100, ability)
end

function modifier_harvest_tonic_speed:OnDeath(event)
    if not IsServer() then return end
    local parent = self:GetParent()
    local victim = event.unit
    if event.attacker ~= parent or not victim or victim:IsNull()
        or not victim:IsRealHero() or victim:GetTeamNumber() == parent:GetTeamNumber()
        or (victim.IsReincarnating and victim:IsReincarnating()) then return end

    local heal = self.takedownHeal or 250
    local ability = self:GetAbility()
    if ability and ability:IsNull() then ability = nil end
    parent:Heal(heal, ability)
    SendOverheadEventMessage(nil, OVERHEAD_ALERT_HEAL, parent, heal, nil)

    local capRemaining = math.max(0, (self.absoluteEndTime or GameRules:GetGameTime()) - GameRules:GetGameTime())
    local extended = math.min(capRemaining,
        math.max(0, self:GetRemainingTime()) + (self.takedownExtension or 3))
    self:SetDuration(extended, true)
end
