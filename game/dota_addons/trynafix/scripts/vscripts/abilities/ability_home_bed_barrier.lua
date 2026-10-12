LinkLuaModifier("modifier_home_bed_barrier","modifiers/modifier_home_bed_barrier",LUA_MODIFIER_MOTION_NONE)

ability_home_bed_barrier=class({})

function ability_home_bed_barrier:ApplyBarrier(bed)
    if not IsServer() or not bed or bed:IsNull() or not bed:IsAlive() then return false end
    bed:AddNewModifier(self:GetCaster(),self,"modifier_home_bed_barrier",{duration=30,blocks=4})
    return bed:HasModifier("modifier_home_bed_barrier")
end
