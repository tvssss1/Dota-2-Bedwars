modifier_bed_raider_ai=class({})

function modifier_bed_raider_ai:IsHidden() return true end
function modifier_bed_raider_ai:IsPurgable() return false end

function modifier_bed_raider_ai:OnCreated(kv)
    if not IsServer() then return end
    self.bedEntIndex=tonumber(kv.bed_entindex)
    self:StartIntervalThink(0.25)
    self:OnIntervalThink()
end

function modifier_bed_raider_ai:OnIntervalThink()
    local creep=self:GetParent()
    local bed=self.bedEntIndex and EntIndexToHScript(self.bedEntIndex) or nil
    if not bed or bed:IsNull() or not bed:IsAlive() then
        creep:SetForceAttackTarget(nil)
        creep:ForceKill(false)
        return
    end
    if creep:GetForceAttackTarget()~=bed then
        creep:SetForceAttackTarget(bed)
        ExecuteOrderFromTable({
            UnitIndex=creep:entindex(),
            OrderType=DOTA_UNIT_ORDER_ATTACK_TARGET,
            TargetIndex=bed:entindex(),
            Queue=false
        })
    end
end

function modifier_bed_raider_ai:OnDestroy()
    if IsServer() and self:GetParent() and not self:GetParent():IsNull() then
        self:GetParent():SetForceAttackTarget(nil)
        if self:GetParent():IsAlive() then self:GetParent():ForceKill(false) end
    end
end
