LinkLuaModifier("modifier_teleport_to_base", "Modifiers/modifier_teleport_to_base", LUA_MODIFIER_MOTION_NONE)
require("services/base_utils")

item_custom_tp = class({})

function item_custom_tp:OnSpellStart()
    self.caster = self:GetCaster()
    self.casterTeam = self.caster:GetTeam()
    self.targetTpPosition = nil
    self.removeAfterChannel = false

    if self.casterTeam == DOTA_TEAM_CUSTOM_1 then
        self.bedColor = "red"
    elseif self.casterTeam == DOTA_TEAM_CUSTOM_2 then
        self.bedColor = "blue"
    elseif self.casterTeam == DOTA_TEAM_CUSTOM_3 then
        self.bedColor = "green"
    elseif self.casterTeam == DOTA_TEAM_CUSTOM_4 then
        self.bedColor = "orange"
    end

    if not self.bedColor then
        self:EndChannel(true)
        return
    end

    self.targetTpPosition = BaseUtils:GetTeamBasePosition(self.casterTeam)

    if not self.targetTpPosition then
        CustomGameEventManager:Send_ServerToPlayer(
            self.caster:GetPlayerOwner(),
            "ShowError",
            {
                message = "#custom_error_base_spawn_missing"
            }
        )
        EmitSoundOnClient("General.Cancel", PlayerResource:GetPlayer(self.caster:GetPlayerOwnerID()))
        self:EndChannel(true)
        return
    end

    EmitSoundOnLocationWithCaster(self.caster:GetAbsOrigin(), "TeleportSound", self.caster)
    EmitSoundOnLocationWithCaster(self.targetTpPosition, "TeleportSound", self.caster)
    self.tp_particle = ParticleManager:CreateParticle( "particles/econ/events/fall_2021/teleport_end_fall_2021_core.vpcf", PATTACH_ABSORIGIN_FOLLOW, self.caster)
    ParticleManager:SetParticleControl(self.tp_particle, 0, self.caster:GetAbsOrigin())

    self.tp_particleOnBed = ParticleManager:CreateParticle("particles/econ/events/fall_2021/teleport_end_fall_2021_core.vpcf", PATTACH_WORLDORIGIN, nil)
    ParticleManager:SetParticleControl(self.tp_particleOnBed, 0, self.targetTpPosition)

    CustomGameEventManager:Send_ServerToTeam(self.caster:GetTeam(), "OpenChannelBed", {
        bed_color = self.bedColor
    })

    -- Spend the charge as soon as channeling starts. Keep an empty final-charge
    -- item alive only until OnChannelFinish so its removal cannot break the channel.
    local charges = self:GetCurrentCharges()
    self.removeAfterChannel = charges <= 1
    self:SetCurrentCharges(math.max(charges - 1, 0))
end

function item_custom_tp:OnChannelFinish(bInterrupted)
    if self.tp_particle then
        ParticleManager:DestroyParticle(self.tp_particle, false)
        ParticleManager:ReleaseParticleIndex(self.tp_particle)
        self.tp_particle = nil
    end

    if self.tp_particleOnBed then
        ParticleManager:DestroyParticle(self.tp_particleOnBed, false)
        ParticleManager:ReleaseParticleIndex(self.tp_particleOnBed)
        self.tp_particleOnBed = nil
    end
    if not self.caster or self.caster:IsNull() then return end

    if bInterrupted then
        EmitSoundOnLocationWithCaster(self.caster:GetAbsOrigin(), "TeleportSoundEffectBreak", self.caster)
        if self.targetTpPosition then
            EmitSoundOnLocationWithCaster(self.targetTpPosition, "TeleportSoundEffectBreak", self.caster)
        end
        StopGlobalSound("TeleportSound")
    elseif self.targetTpPosition then
        FindClearSpaceForUnit(self.caster, self.targetTpPosition, true)
    else
        CustomGameEventManager:Send_ServerToPlayer(self.caster:GetPlayerOwner(), "ShowError", { message = "#custom_error_base_spawn_missing" })
        EmitSoundOnClient("General.Cancel", PlayerResource:GetPlayer(self.caster:GetPlayerOwnerID()))
    end

    CustomGameEventManager:Send_ServerToTeam(self.caster:GetTeam(), "CloseChannelBed", {})

    if self.removeAfterChannel then
        self:Destroy()
    end
    self.targetTpPosition = nil
end
