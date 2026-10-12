modifier_bed_hit_points = class({})

function modifier_bed_hit_points:IsHidden() return true end
function modifier_bed_hit_points:IsDebuff() return false end
function modifier_bed_hit_points:IsPurgable() return false end
function modifier_bed_hit_points:RemoveOnDeath() return false end
function modifier_bed_hit_points:GetAttributes() return MODIFIER_ATTRIBUTE_PERMANENT end

function modifier_bed_hit_points:DeclareFunctions()
    return {
        MODIFIER_EVENT_ON_ATTACK_LANDED,
        MODIFIER_PROPERTY_ABSOLUTE_NO_DAMAGE_PHYSICAL,
        MODIFIER_PROPERTY_ABSOLUTE_NO_DAMAGE_MAGICAL,
        MODIFIER_PROPERTY_ABSOLUTE_NO_DAMAGE_PURE,
        MODIFIER_PROPERTY_DISABLE_HEALING
    }
end

function modifier_bed_hit_points:GetAbsoluteNoDamagePhysical() return 1 end
function modifier_bed_hit_points:GetAbsoluteNoDamageMagical() return 1 end
function modifier_bed_hit_points:GetAbsoluteNoDamagePure() return 1 end
function modifier_bed_hit_points:GetDisableHealing() return 1 end

function modifier_bed_hit_points:OnAttackLanded(params)
    if not IsServer() then return end

    local bed = self:GetParent()
    if not params or params.target ~= bed or not bed:IsAlive() then return end

    local attacker = params.attacker
    if not attacker or attacker:IsNull()
        or attacker:GetTeamNumber() == bed:GetTeamNumber() then return end

    if bed:HasModifier("modifier_bed_opening_protection") then return end

    -- Native Glyph applies this modifier to allied structures. Bed damage is
    -- a scripted one-pip system, so explicitly honor Glyph before consuming a
    -- shield block or bed hit point.
    if bed:HasModifier("modifier_fountain_glyph") then return end

    local barrier = bed:FindModifierByName("modifier_home_bed_barrier")
    if barrier and barrier.ConsumeAttack and barrier:ConsumeAttack() then return end

    local health = bed:GetHealth()
    if health <= 1 then
        -- Report the lethal hit before killing this ward-style unit. Some
        -- Source 2 builds do not emit entity_killed reliably for this base
        -- class, which previously left the HUD, respawns, and buyback alive.
        if GameSetup and GameSetup.HandleBedDestroyed then
            GameSetup:HandleBedDestroyed(bed:GetTeamNumber())
        end
        bed:Kill(nil, attacker)
        -- Kill normally bypasses damage filters. Keep a forced fallback so a
        -- future engine change cannot let the fifth pip survive the filter.
        if bed:IsAlive() then bed:ForceKill(false) end
        return
    end

    bed:SetHealth(health - 1)
end
