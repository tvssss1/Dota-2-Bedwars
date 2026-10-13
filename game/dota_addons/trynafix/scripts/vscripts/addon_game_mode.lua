require("settings/settings")
require("settings/SpawnBeds")
require("BushModifiers")
require("services/base_gold_generator")
require("GamePlay/TriggerGold")
require("timers")
require("services/purple_currency")
require("services/hope_shop")
require("services/pumpkin_currency")
require("services/custom_courier_service")
require("services/island_shop")
require("services/island_boss_service")
require("services/custom_roshan_service")
require("services/mid_reward_service")
require("services/passive_income_service")
require("services/random_draft_service")
require("services/strategy_shop")
require("services/ability_draft_service")
require("services/perk_service")
require("services/convergence_service")

if CAddonTemplateGameMode == nil then
	CAddonTemplateGameMode = class({})
end

function Precache( context )
	-- Drafted stock abilities are added to heroes that do not normally own
	-- them. Precache each source hero so those abilities bring their complete
	-- particle, projectile and sound dependencies into the custom game.
	local draftAbilitySourceHeroes = {
		"npc_dota_hero_abaddon",
		"npc_dota_hero_axe",
		"npc_dota_hero_bounty_hunter",
		"npc_dota_hero_centaur",
		"npc_dota_hero_crystal_maiden",
		"npc_dota_hero_dazzle",
		"npc_dota_hero_death_prophet",
		"npc_dota_hero_earthshaker",
		"npc_dota_hero_enigma",
		"npc_dota_hero_faceless_void",
		"npc_dota_hero_jakiro",
		"npc_dota_hero_lina",
		"npc_dota_hero_lion",
		"npc_dota_hero_magnataur",
		"npc_dota_hero_omniknight",
		"npc_dota_hero_queenofpain",
		"npc_dota_hero_rubick",
		"npc_dota_hero_sand_king",
		"npc_dota_hero_skywrath_mage",
		"npc_dota_hero_slardar",
		"npc_dota_hero_sniper",
		"npc_dota_hero_sven",
		"npc_dota_hero_tidehunter",
		"npc_dota_hero_ursa",
		"npc_dota_hero_vengefulspirit",
		"npc_dota_hero_warlock",
		"npc_dota_hero_weaver",
		"npc_dota_hero_windrunner"
	}
	for _, heroName in ipairs(draftAbilitySourceHeroes) do
		PrecacheUnitByNameSync(heroName, context)
	end

	PrecacheUnitByNameSync("npc_island_miniboss", context)
	PrecacheUnitByNameSync("npc_custom_roshan", context)
	PrecacheUnitByNameSync("npc_dota_convergence_balloon_target", context)
	PrecacheUnitByNameSync("npc_convergence_shrine", context)
	-- SpawnCourierAtPosition uses this stock player-owned unit and applies each
	-- player's equipped courier cosmetic/loadout.
	PrecacheUnitByNameSync("npc_dota_courier", context)
	PrecacheResource("model", "models/creeps/roshan/roshan.vmdl", context)
	PrecacheResource("model", "bed/models/bed.vmdl", context)
	PrecacheResource("model", "bed/models/bed_green.vmdl", context)
	PrecacheResource("model", "bed/models/bed_yellow.vmdl", context)
	PrecacheResource("model", "bed/models/bed_blue.vmdl", context)
	PrecacheResource("model", "models/items/witchdoctor/wd_ti8_immortal_bonkers/wd_ti8_immortal_durian.vmdl", context)
	PrecacheResource("model", "models/props_generic/chest_treasure_03.vmdl", context)
	PrecacheResource("model", "models/props_gameplay/npc/shopkeeper_the_lost_meepo/shopkeeper_the_lost_meepo.vmdl", context)
	PrecacheResource("model", "models/props_gameplay/gold_coin001.vmdl", context)
	PrecacheResource("model", "models/props_gameplay/gold_coin001b.vmdl", context)
	PrecacheResource("model", "models/creeps/lane_creeps/creep_bad_melee_diretide/creep_bad_melee_diretide.vmdl", context)
	PrecacheResource("model", "models/props_gameplay/pumpkin_rune.vmdl", context)
	PrecacheResource("model", "models/props_structures/tower_good.vmdl", context)
	PrecacheResource("model", "models/baloons.vmdl", context)
	PrecacheResource("particle", "particles/econ/courier/courier_flopjaw_gold/flopjaw_death_coins_gold.vpcf", context)
	PrecacheResource("particle", "particles/purple_money_gold.vpcf", context)
	PrecacheResource("particle", "particles/flopjaw_rocks_money.vpcf", context)
	PrecacheResource("particle", "particles/pumpkin_glow.vpcf", context)
	PrecacheResource("particle", "particles/basic_explosion/basic_explosion.vpcf", context)
	PrecacheResource("particle", "particles/neutral_fx/roshan_slam.vpcf", context)
	PrecacheResource("particle", "particles/basic_explosion/basic_explosion_flash.vpcf", context)
	PrecacheResource("particle", "particles/basic_projectile/basic_projectile_launch.vpcf", context)
	PrecacheResource("particle", "particles/basic_projectile/basic_projectile.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_lina/lina_base_attack.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_lina/lina_base_attack_explosion.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_lina/lina_spell_light_strike_array.vpcf", context)
	PrecacheResource("particle", "particles/base_attacks/generic_projectile_launch.vpcf", context)
	-- Base attack particles contain several child trail and explosion systems.
	PrecacheResource("particle_folder", "particles/units/heroes/hero_lina", context)
	PrecacheResource("particle", "particles/basic_ambient/basic_ambient.vpcf", context)
	PrecacheResource("particle", "particles/harvest_tonic/harvest_tonic_cast.vpcf", context)
	PrecacheResource("particle", "particles/harvest_tonic/harvest_tonic_ring.vpcf", context)
	PrecacheResource("particle", "particles/harvest_tonic/harvest_tonic_motes.vpcf", context)
	PrecacheResource("particle", "particles/harvest_tonic/harvest_tonic_bloom.vpcf", context)
	PrecacheResource("particle", "particles/vengeful_arcana_wave_of_terror_pearl.vpcf", context)
	PrecacheResource("particle", "particles/econ/events/spring_2021/force_staff_spring_2021_glow.vpcf", context)
	PrecacheResource("particle", "particles/econ/events/snowball/snowball_projectile.vpcf", context)
	PrecacheResource("particle", "particles/econ/events/snowball/snowball_projectile_model.vpcf", context)
	PrecacheResource("particle", "particles/econ/events/snowball/snowball_projectile_trail.vpcf", context)
	PrecacheResource("particle", "particles/econ/events/snowball/snowball_projectile_launch.vpcf", context)
	PrecacheResource("particle", "particles/econ/events/snowball/snowball_projectile_explosion.vpcf", context)
	PrecacheResource("particle", "particles/econ/events/snowball/snowball_projectile_ability_endcap.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_tusk/tusk_snowball_ground_frost.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_tusk/tusk_snowball_impact.vpcf", context)
	PrecacheResource("particle", "particles/econ/items/templar_assassin/ta_2022_immortal/ta_2022_immortal_trap_gold_flower_pattern.vpcf", context)
	PrecacheResource("particle", "particles/econ/creeps/creep_2021_radiant/creep_2021_radiant_siege_death_smoke.vpcf", context)
	PrecacheResource("particle", "particles/econ/events/fall_2021/teleport_end_fall_2021_core.vpcf", context)
	PrecacheResource("particle", "particles/courier_drodo_ambient_death_overall.vpcf", context)
	PrecacheResource("particle", "particles/msg_fx/msg_lasthitcounter_tens.vpcf", context)
	PrecacheResource("particle", "particles/items_fx/generic_item_spell_caster_core_clarity_mango.vpcf", context)
	PrecacheResource("particle", "particles/items2_fx/pipe_of_insight.vpcf", context)
	PrecacheResource("particle", "particles/items2_fx/vanguard_active.vpcf", context)
	PrecacheResource("model", "models/props_structures/xp_shrine/xp_shrine.vmdl", context)
	PrecacheResource("particle", "particles/base_static/experience_shrine_ambient.vpcf", context)
	PrecacheResource("particle", "particles/base_static/experience_shrine_active.vpcf", context)
	PrecacheResource("particle", "particles/base_static/experience_shrine_crack_glow_vertical.vpcf", context)
	PrecacheResource("particle", "particles/base_static/experience_shrine_crack_glow_burst.vpcf", context)
	PrecacheResource("particle", "particles/dev/library/base_aoe_ring_simple.vpcf", context)
	PrecacheResource("particle", "particles/generic_gameplay/effigy_channel/effigy_channel.vpcf", context)
	PrecacheResource("particle", "particles/world_outpost/world_outpost_channel_finish.vpcf", context)
	PrecacheResource("particle", "particles/econ/items/windrunner/fluttering_breeze/arcana/fluttering_breeze_arcana_weapon_ambient_wind.vpcf", context)
	PrecacheResource("particle", "particles/econ/items/storm_spirit/storm_spirit_orchid_hat_retro/stormspirit_orchid_retro_ball_trail_cloud.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_faceless_void/faceless_void_time_walk_preimage.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_weaver/weaver_timelapse.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_ogre_magi/ogre_magi_multicast.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_ogre_magi/ogre_magi_multicast_counter.vpcf", context)
	PrecacheResource("particle", "particles/items_fx/blink_dagger_start.vpcf", context)
	PrecacheResource("particle", "particles/items_fx/blink_dagger_end.vpcf", context)
	PrecacheResource("particle", "particles/items4_fx/cyclonic_barrier.vpcf", context)
	PrecacheResource("particle", "particles/econ/generic/generic_aoe_shockwave_1/generic_aoe_shockwave_1.vpcf", context)
	PrecacheResource("particle", "particles/econ/items/alchemist/alchemist_midas_knuckles/alch_hand_of_midas.vpcf", context)
	PrecacheResource("particle", "particles/econ/items/alchemist/alchemist_midas_knuckles/alch_knuckles_lasthit_coins.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_phantom_lancer/phantom_lancer_spawn_illusion.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_phantom_lancer/phantomlancer_doppelwalk.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_phantom_lancer/phantomlancer_illusion_destroy.vpcf", context)
	PrecacheResource("particle", "particles/items2_fx/manta_phase.vpcf", context)
	PrecacheResource("particle", "particles/status_fx/status_effect_phantom_lancer_illusion.vpcf", context)
	PrecacheResource("particle", "particles/items3_fx/lotus_orb_shield.vpcf", context)
	PrecacheResource("particle", "particles/econ/events/spring_2021/mjollnir_shield_spring_2021.vpcf", context)
	PrecacheResource("particle", "particles/items2_fx/pipe_of_insight_launch.vpcf", context)
	PrecacheResource("particle", "particles/econ/items/drow/drow_arcana/drow_arcana_item_force_staff_smoke.vpcf", context)
	PrecacheResource("particle", "particles/creatures/aghanim/aghanim_blink_arrival.vpcf", context)
	PrecacheResource("particle", "particles/econ/events/fall_2021/blink_dagger_fall_2021_end_rays.vpcf", context)
	PrecacheResource("particle", "particles/econ/items/witch_doctor/wd_ti8_immortal_bonkers/wd_ti8_immortal_bonkers_cask.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_faceless_void/faceless_dust_hit.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_snapfire/hero_snapfire_cookie_landing.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_bounty_hunter/bounty_hunter_windwalk.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_arc_warden/arc_warden_wraith_prj_burst.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_razor/razor_unstable_current.vpcf", context)
	PrecacheResource("particle", "particles/items_fx/chain_lightning.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_primal_beast/primal_beast_uproar_counter.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_primal_beast/primal_beast_uproar_active.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_primal_beast/primal_beast_roar_aoe.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_invoker/invoker_sun_strike_team.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_invoker/invoker_sun_strike.vpcf", context)
	PrecacheResource("particle", "particles/econ/items/pudge/aberrant/red_arcana/aberrant_red_arcana_meathook_hook.vpcf", context)
	PrecacheResource("particle", "particles/econ/items/pudge/aberrant/red_arcana/aberrant_red_arcana_meathook_chain.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_jakiro/jakiro_liquid_fire_debuff.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_ember_spirit/ember_spirit_flameguard.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_dark_seer/dark_seer_vacuum.vpcf", context)
	PrecacheResource("soundfile", "soundevents/bush.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/purple_money.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/ender_pearl.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/teleport.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/pregame_announcer.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/game_sounds.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/convergence_perks.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/harvest_tonic.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/overdrive_grenade.vsndevts", context)
	-- Stock announcer manifest used for the one-time bed-under-attack warning.
	PrecacheResource("soundfile", "soundevents/voscripts/game_sounds_vo_announcer.vsndevts", context)
	-- MortimerBlob.Launch and MortimerBlob.Impact live in this stock hero manifest.
	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_snapfire.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_razor.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_bounty_hunter.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_arc_warden.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_primal_beast.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_invoker.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_pudge.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_dark_seer.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_tusk.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_lion.vsndevts", context)
end

-- Create the game mode when we activate
function Activate()
	GameRules.AddonTemplate = CAddonTemplateGameMode()
	GameRules.AddonTemplate:InitGameMode()
end

function CAddonTemplateGameMode:InitGameMode()
	GameRules:GetGameModeEntity():SetThink( "OnThink", self, "GlobalThink", 2 )
	GameSetup:init()
	RandomDraftService:Init()
	StrategyShop:Init()
	AbilityDraftService:Init()
	GameSetup:Shops()
	GameSetup:MidSpawners()
	BaseGoldGenerator:Init()
	PurpleCurrency:Init()
	HopeShop:Init()
	PumpkinCurrency:Init()
	CustomCourierService:Init()
	IslandShop:Init()
	IslandBossService:Init()
	CustomRoshanService:Init()
	MidRewardService:Init()
	PassiveIncomeService:Init()
	PerkService:Init()
	ConvergenceService:Init()
end

-- Evaluate the state of the game
function CAddonTemplateGameMode:OnThink()
	if GameRules:State_Get() == DOTA_GAMERULES_STATE_GAME_IN_PROGRESS then
		--print( "Template addon script is running." )
	elseif GameRules:State_Get() >= DOTA_GAMERULES_STATE_POST_GAME then
		return nil
	end
	return 1
end
