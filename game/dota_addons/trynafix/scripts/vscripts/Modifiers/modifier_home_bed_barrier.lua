modifier_home_bed_barrier=class({})

function modifier_home_bed_barrier:IsHidden() return false end
function modifier_home_bed_barrier:IsDebuff() return false end
function modifier_home_bed_barrier:IsPurgable() return false end
function modifier_home_bed_barrier:GetTexture() return "item_crimson_guard" end
function modifier_home_bed_barrier:DeclareFunctions()
    return {MODIFIER_PROPERTY_TOOLTIP}
end

function modifier_home_bed_barrier:OnCreated(kv)
    self.maxBlocks=tonumber(kv.blocks) or 4
    if not IsServer() then return end
    self:SetStackCount(self.maxBlocks)

    local bed=self:GetParent()
    EmitSoundOn("DOTA_Item.Pipe.Activate",bed)

    local burst=ParticleManager:CreateParticle(
        "particles/items2_fx/pipe_of_insight_launch.vpcf",
        PATTACH_WORLDORIGIN,
        nil
    )
    ParticleManager:SetParticleControl(burst,0,bed:GetAbsOrigin())
    ParticleManager:ReleaseParticleIndex(burst)

    self.barrierParticle=ParticleManager:CreateParticle(
        "particles/items3_fx/lotus_orb_shield.vpcf",
        PATTACH_WORLDORIGIN,
        nil
    )
    ParticleManager:SetParticleControl(self.barrierParticle,0,bed:GetAbsOrigin()+Vector(0,0,80))
    self:AddParticle(self.barrierParticle,false,false,-1,false,false)
end

function modifier_home_bed_barrier:OnTooltip()
    return self:GetStackCount()
end

function modifier_home_bed_barrier:ConsumeAttack()
    if not IsServer() or self:GetStackCount()<=0 then return false end
    self:SetStackCount(self:GetStackCount()-1)
    if self:GetStackCount()<=0 then self:Destroy() end
    return true
end
