require("services/bed_utils")
require("services/base_utils")
LinkLuaModifier("modifier_bed_raider_ai","modifiers/modifier_bed_raider_ai",LUA_MODIFIER_MOTION_NONE)

item_bed_raiders=class({})

function item_bed_raiders:FindOwnBed(hero)
    return BedUtils:NearestLivingBed(hero:GetAbsOrigin(),25000,hero:GetTeamNumber())
end

function item_bed_raiders:GetSpawnOrigin(hero)
    local ownBed = self:FindOwnBed(hero)
    if ownBed then return ownBed:GetAbsOrigin() end
    return BaseUtils:GetTeamBasePosition(hero:GetTeamNumber())
end

function item_bed_raiders:CastFilterResultTarget(target)
    if not self:GetSpawnOrigin(self:GetCaster()) then return UF_FAIL_CUSTOM end
    if not target or target:IsNull() or not BedUtils:IsLivingBed(target) then return UF_FAIL_CUSTOM end
    if target:GetTeamNumber()==self:GetCaster():GetTeamNumber() then return UF_FAIL_ENEMY end
    return UF_SUCCESS
end

function item_bed_raiders:GetCustomCastErrorTarget(target)
    if not self:GetSpawnOrigin(self:GetCaster()) then return "#custom_error_base_spawn_missing" end
    return "#hope_shop_error_target_enemy_bed"
end

function item_bed_raiders:OnSpellStart()
    local hero=self:GetCaster()
    local bed=self:GetCursorTarget()
    if self:CastFilterResultTarget(bed)~=UF_SUCCESS then return end
    local spawnOrigin=self:GetSpawnOrigin(hero)
    if not spawnOrigin then return end

    for i=1,3 do
        local angle=math.rad((i-1)*120)
        local origin=spawnOrigin+Vector(math.cos(angle)*100,math.sin(angle)*100,0)
        local creep=CreateUnitByName("npc_dota_creep_badguys_melee",origin,true,nil,nil,hero:GetTeamNumber())
        if creep then
            creep:SetOwner(nil)
            creep:AddNewModifier(hero,self,"modifier_bed_raider_ai",{duration=90,bed_entindex=bed:entindex()})
        end
    end

    local charges=self:GetCurrentCharges()
    if charges>1 then self:SetCurrentCharges(charges-1) else self:Destroy() end
end
