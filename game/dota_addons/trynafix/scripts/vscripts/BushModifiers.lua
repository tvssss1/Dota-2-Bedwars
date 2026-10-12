
function SlowBush(event)
    local activator = event.activator
    if not activator or activator:IsNull() then return end

    activator:AddNewModifier(activator, nil, "modifier_bushes_slow", {})
    activator:AddNewModifier(activator, nil, "modifier_bushes_invise", {})
    local particle = ParticleManager:CreateParticle("particles/courier_drodo_ambient_death_overall.vpcf", PATTACH_ABSORIGIN_FOLLOW, activator)
    ParticleManager:SetParticleControl(particle, 0, activator:GetAbsOrigin())
    ParticleManager:ReleaseParticleIndex(particle)
    local particleTwo = ParticleManager:CreateParticle("particles/econ/creeps/creep_2021_radiant/creep_2021_radiant_siege_death_smoke.vpcf", PATTACH_WORLDORIGIN, nil)
    ParticleManager:SetParticleControl(particleTwo, 0, activator:GetAbsOrigin())
    ParticleManager:ReleaseParticleIndex(particleTwo)
    EmitSoundOnLocationWithCaster(activator:GetAbsOrigin(), "BushSoundEffect", activator)
end

function DeleteSlowBush(event)
    local unit = event.activator
    if not unit or unit:IsNull() then return end

    unit:RemoveModifierByName( "modifier_bushes_slow" )
    unit:RemoveModifierByName( "modifier_bushes_invise" )
    local particle = ParticleManager:CreateParticle("particles/courier_drodo_ambient_death_overall.vpcf", PATTACH_ABSORIGIN_FOLLOW, unit)
    ParticleManager:SetParticleControl(particle, 0, unit:GetAbsOrigin())
    ParticleManager:ReleaseParticleIndex(particle)
end
