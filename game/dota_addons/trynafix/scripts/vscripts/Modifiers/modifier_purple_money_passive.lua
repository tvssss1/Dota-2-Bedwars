modifier_purple_money_passive = class({})

function modifier_purple_money_passive:IsHidden()
    return true
end

function modifier_purple_money_passive:IsPurgable()
    return false
end

function modifier_purple_money_passive:OnCreated()
    if not IsServer() then return end

    self.interval = 30
    self.time_left = self.interval

    -- Партикл таймера
    self.particle = ParticleManager:CreateParticle(
        "particles/ui_mouseactions/range_finder_tower_aoe.vpcf",
        PATTACH_OVERHEAD_FOLLOW,
        self:GetParent()
    )

    -- Первичное значение
    ParticleManager:SetParticleControl(self.particle, 1, Vector(0, self.time_left, 0))

    self:StartIntervalThink(1)
end

function modifier_purple_money_passive:OnIntervalThink()
    if not IsServer() then return end

    self.time_left = self.time_left - 1

    -- Обновляем отображение таймера
    ParticleManager:SetParticleControl(
        self.particle,
        1,
        Vector(0, self.time_left, 0)
    )

    if self.time_left <= 0 then
        self:SpawnMoney()
        self.time_left = self.interval
    end
end

function modifier_purple_money_passive:SpawnMoney()
    local parent = self:GetParent()

    local item = CreateItem("item_purple_money", nil, nil)

    CreateItemOnPositionSync(
        parent:GetAbsOrigin() + RandomVector(150),
        item
    )

    EmitSoundOn("General.Coins", parent)
end

function modifier_purple_money_passive:OnDestroy()
    if not IsServer() then return end

    if self.particle then
        ParticleManager:DestroyParticle(self.particle, false)
        ParticleManager:ReleaseParticleIndex(self.particle)
    end
end