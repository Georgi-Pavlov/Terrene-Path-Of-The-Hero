extends Node

# ============================================================
# GAME MANAGER
# ============================================================

# Currently selected zone
var selected_zone: String = ""


# ============================================================
# LEVELING
# ============================================================
# XP required to advance from a given level to the next one, e.g.
# LEVEL_XP_REQUIREMENTS[1] = 240 means level 1 -> 2 costs 240 XP.
# Hero XP (PlayerManager's "hero_xp") tracks progress within the
# current level and resets (carrying over any overflow) each time a
# level is gained - see PlayerManager.check_level_up().

const MAX_LEVEL: int = 30

const LEVEL_XP_REQUIREMENTS: Dictionary = {
	1: 240, 2: 400, 3: 520, 4: 600, 5: 680, 6: 760, 7: 800, 8: 900,
	9: 1000, 10: 1100, 11: 1200, 12: 1300, 13: 1400, 14: 1500,
	15: 1600, 16: 1700, 17: 1800, 18: 1900, 19: 2000, 20: 2200,
	21: 2400, 22: 2600, 23: 2800, 24: 3000, 25: 4000, 26: 5000,
	27: 6000, 28: 7000, 29: 8000, 30: 10000,
}


## XP required to advance from `level` to `level + 1`.
## Returns -1 once `level` is at or past MAX_LEVEL, since there's no
## further level to advance to.
func get_xp_required_for_level(level: int) -> int:
	if level >= MAX_LEVEL:
		return -1
	return int(LEVEL_XP_REQUIREMENTS.get(level, -1))


# ------------------------------------------------------------------
# Skill leveling: every "standard" skill can be leveled 1-4, every
# "ultimate" skill 1-3, each level gated behind a hero level - the
# same schedule for every skill of that type. A skill point is earned
# per hero level gained (see PlayerManager.check_level_up) and spent
# to either learn an unlearned skill (at level 1) or push an already-
# learned one up a level, provided the hero is high enough level.
# ------------------------------------------------------------------

const STANDARD_SKILL_LEVEL_UNLOCKS: Dictionary = {1: 1, 2: 3, 3: 5, 4: 7}
const ULTIMATE_SKILL_LEVEL_UNLOCKS: Dictionary = {1: 6, 2: 12, 3: 18}


func get_max_skill_level(skill_type: String) -> int:
	if skill_type == "ultimate":
		return ULTIMATE_SKILL_LEVEL_UNLOCKS.size()
	return STANDARD_SKILL_LEVEL_UNLOCKS.size()


## Hero level required to put a point into `skill_level` of a skill of
## this type. Returns -1 for an out-of-range skill_level (e.g. level 5
## of a standard skill, which caps at 4).
func get_skill_level_unlock_requirement(skill_type: String, skill_level: int) -> int:
	var table: Dictionary = ULTIMATE_SKILL_LEVEL_UNLOCKS if skill_type == "ultimate" else STANDARD_SKILL_LEVEL_UNLOCKS
	return int(table.get(skill_level, -1))


## Returns the mechanical data for one level of a skill - whatever's
## in that skill's "levels" array at index `level - 1` (distance,
## stun_turns, damage_multiplier, radius, cooldown, etc. - varies per
## skill). Skills that don't have per-level data yet (nothing
## implemented beyond a flat cooldown) fall back to just
## {"cooldown": skill.cooldown}.
func get_skill_level_data(skill: Dictionary, level: int) -> Dictionary:
	var levels: Array = skill.get("levels", [])
	if level >= 1 and level <= levels.size():
		return levels[level - 1]
	return {"cooldown": skill.get("cooldown", 0)}


# ------------------------------------------------------------------
# Derived stats: strength/agility/intelligence are the only stats
# that grow directly from level_up. Everything below is calculated
# from how far a stat has grown past the hero's base value - HP,
# armor, mana and damage are never stored/grown directly.
#   +1 Strength     -> +HP_PER_STRENGTH max HP
#   +1 Agility      -> +ARMOR_PER_AGILITY armor
#   +1 Intelligence -> +MANA_PER_INTELLIGENCE max mana
#   +1 to a hero's main_stat -> +DAMAGE_PER_MAIN_STAT damage (both
#   ends of the min-max range), on top of the strength/agility/
#   intelligence bonuses above (a Strength hero's main stat growth
#   also feeds its HP bonus, for example - the two aren't exclusive).
# ------------------------------------------------------------------
const HP_PER_STRENGTH: float = 22.0
const ARMOR_PER_AGILITY: float = 0.167
const MANA_PER_INTELLIGENCE: float = 12.0
const DAMAGE_PER_MAIN_STAT: float = 1.0


## Computes a hero's effective hp/mana/armor/damage from how far
## strength/agility/intelligence have grown past that hero's base
## stats. `hero_static` is the hero's definition (from get_hero_by_id
## or a zone's "heroes" array) - its "stats" dict supplies the base
## values and "main_stat" decides which attribute feeds damage.
## Returns {hp, mana, armor, damage} ready to drop into a stats dict -
## "damage" comes back as a "min-max" string like the base value.
func compute_derived_stats(hero_static: Dictionary, current_strength: float, current_agility: float, current_intelligence: float) -> Dictionary:
	var base_stats: Dictionary = hero_static.get("stats", {})
	var base_strength: float = float(base_stats.get("strength", 0))
	var base_agility: float = float(base_stats.get("agility", 0))
	var base_intelligence: float = float(base_stats.get("intelligence", 0))

	var bonus_hp: float = (current_strength - base_strength) * HP_PER_STRENGTH
	var bonus_armor: float = (current_agility - base_agility) * ARMOR_PER_AGILITY
	var bonus_mana: float = (current_intelligence - base_intelligence) * MANA_PER_INTELLIGENCE

	var current_main_value: float = current_strength
	var base_main_value: float = base_strength
	match str(hero_static.get("main_stat", "")).to_lower():
		"agility":
			current_main_value = current_agility
			base_main_value = base_agility
		"intelligence":
			current_main_value = current_intelligence
			base_main_value = base_intelligence

	var bonus_damage: float = (current_main_value - base_main_value) * DAMAGE_PER_MAIN_STAT

	var damage_parts: PackedStringArray = str(base_stats.get("damage", "0-0")).split("-")
	var base_damage_min: float = float(damage_parts[0]) if damage_parts.size() > 0 else 0.0
	var base_damage_max: float = float(damage_parts[1]) if damage_parts.size() > 1 else base_damage_min

	return {
		"hp": float(base_stats.get("hp", 0)) + bonus_hp,
		"mana": float(base_stats.get("mana", 0)) + bonus_mana,
		"armor": float(base_stats.get("armor", 0)) + bonus_armor,
		"damage": "%d-%d" % [roundi(base_damage_min + bonus_damage), roundi(base_damage_max + bonus_damage)],
	}


# ============================================================
# ZONE STAGES
# ============================================================
# Every zone's battle plays out over up to MAX_ZONE_STAGE waves in a
# row, fought inside a single Battle scene instance (killing every
# enemy in a stage reloads the next stage's enemies in place rather
# than returning to the Map) - see battle.gd's _handle_victory() and
# _advance_to_next_stage(). A zone that's been fully cleared (all
# stages beaten in one run, no fleeing) is marked via
# PlayerManager.set_zone_cleared() and always reopens on the final
# stage afterward - see PlayerManager.get_zone_start_stage().

const MAX_ZONE_STAGE: int = 3

# How many melee/ranged enemies spawn at each stage. If a zone
# doesn't have that many distinct melee/ranged templates in its
# "enemies" list, battle.gd just cycles through the ones it has.
const STAGE_ENEMY_COUNTS: Dictionary = {
	1: {"mele": 3, "range": 1},
	2: {"mele": 4, "range": 1},
	3: {"mele": 5, "range": 2},
}

# hp/damage bonus each stage adds ON TOP OF the enemy's base stats -
# and, like gold below, it's cumulative: each stage contributes its
# own increment on top of whatever the previous stage already added
# (stage 3 = stage 2's +30/+3 plus its own +45/+4 = +75/+7 over base).
const STAGE_STAT_BONUS_PER_STAGE: Dictionary = {
	1: {"hp": 0, "damage": 0},
	2: {"hp": 30, "damage": 3},
	3: {"hp": 45, "damage": 4},
}

# Gold bonus per enemy works the same cumulative way - each stage adds
# its own increment on top of whatever gold bonus the previous stage
# already had (stage 3 = stage 2's +3 plus its own +4 = +7 over the
# base "gold" range), not the stage's number alone.
const STAGE_GOLD_BONUS_PER_STAGE: Dictionary = {
	1: 0,
	2: 3,
	3: 4,
}


func get_stage_enemy_counts(stage: int) -> Dictionary:
	return STAGE_ENEMY_COUNTS.get(stage, STAGE_ENEMY_COUNTS[1])


## Total hp/damage bonus for `stage`, built by summing every stage's
## own increment from stage 2 up through `stage` (stage 1 is always
## +0) - same cumulative approach as get_stage_cumulative_gold_bonus().
func get_stage_stat_bonus(stage: int) -> Dictionary:
	var total_hp: float = 0.0
	var total_damage: float = 0.0
	for s in range(2, stage + 1):
		var increment: Dictionary = STAGE_STAT_BONUS_PER_STAGE.get(s, {})
		total_hp += float(increment.get("hp", 0))
		total_damage += float(increment.get("damage", 0))
	return {"hp": total_hp, "damage": total_damage}


## Total gold bonus for `stage`, built by summing every stage's own
## increment from stage 2 up through `stage` (stage 1 is always +0).
func get_stage_cumulative_gold_bonus(stage: int) -> int:
	var total: int = 0
	for s in range(2, stage + 1):
		total += int(STAGE_GOLD_BONUS_PER_STAGE.get(s, 0))
	return total


# ============================================================
# ZONE DATA
# ============================================================
# "background" is optional per zone - point it at a texture path
# (e.g. "res://assets/zones/azura.jpg") once you have per-region art.
# Leave it "" to just use the plain background already in Zone.tscn.

var zones: Dictionary = {

	"azura": {
		"name": "Azura",
		"description": "A frozen land hidden beneath an eternal winter.",
		"music": "azura",
		"heroes": [],
		"unlocked": true,
		"background": ""
	},

	"dark_reef": {
		"name": "Dark Reef",
		"description": "A dark, twisting underwater labyrinth covered by a heavy metallic grid. 
		This inescapable prison, built inside a deep ocean trench, holds the ocean's most dangerous criminals: 
		murderous Slithereen, treacherous Deep Ones, and sociopathic Meranths. Slark is famously the only inmate to ever successfully escape from it.",
		"music": "dark_reef",
		"heroes": [
			{
				"id": "slark",
				"name": "Slark",
				"image": "res://assets/heroes/Slark.png",
				"background": "res://assets/zones/Dark_Reef.png",
				"range_type": "Mele",
				"main_stat": "Agility",
				"stats": {
					"strength": 20,
					"agility": 21,
					"intelligence": 16,
					"range": 150,
					"hp": 560,
					"mana": 260,
					"armor": 1.5,
					"damage": "55-61",
					"speed": 1,
					"XP": 0
				},
				"skills": [
					{
						"id": "essence_shift",
						"name": "Essence Shift",
						"type": "standard",
						"description": "Melee attacks steal a small amount of stats from the enemy hit, weakening them and empowering Slark.",
						"cooldown": 3,
						"mana_cost": 0
					},
					{
						"id": "dark_pact",
						"name": "Dark Pact",
						"type": "standard",
						"description": "Deals damage in a radius around Slark and silences all enemies caught in it.",
						"mana_cost": 65,
						"levels": [
							{"damage_multiplier": 0.75, "radius": 0, "cooldown": 4},
							{"damage_multiplier": 1.0, "radius": 0, "cooldown": 4},
							{"damage_multiplier": 1.25, "radius": 0, "cooldown": 3},
							{"damage_multiplier": 1.5, "radius": 1, "cooldown": 3}
						]
					},
					{
						"id": "pounce",
						"name": "Pounce",
						"type": "standard",
						"description": "Leaps forward, stunning and damaging the first enemy hero hit.",
						"mana_cost": 75,
						"levels": [
							{"distance": 2, "stun_turns": 1, "cooldown": 5},
							{"distance": 3, "stun_turns": 1, "cooldown": 5},
							{"distance": 3, "stun_turns": 2, "cooldown": 4},
							{"distance": 4, "stun_turns": 2, "cooldown": 4}
						]
					},
					{
						"id": "shadow_dance",
						"name": "Shadow Dance",
						"type": "ultimate",
						"description": "Ultimate: grants invisibility and bonus movement speed. Locked until a higher level.",
						"cooldown": 10,
						"mana_cost": 100
					}
				],
				"level_up": {
					"strength": 2.2,
					"agility": 1.3,
					"intelligence": 1.6
				},
			}
		],
		"enemies": [
			{
				"id": "dark_reef_mele",
				"name": "Dark Reef mele creep",
				"image": "res://assets/enemies/Dark_Reef_mele.png",
				"type": "mele",
				"hp": 150,
				"mana": 50,
				"damage": 10,
				"speed": 1,
				"armor": 1.5,
				"XP": 57,
				"gold": "34-39"
			},
			{
				"id": "dark_reef_mele_2",
				"name": "Dark Reef mele creep",
				"image": "res://assets/enemies/Dark_Reef_mele.png",
				"type": "mele",
				"hp": 150,
				"mana": 50,
				"damage": 10,
				"speed": 1,
				"armor": 1.5,
				"XP": 57,
				"gold": "34-39"
			},
			{
				"id": "dark_reef_range",
				"name": "Dark Reef range creep",
				"image": "res://assets/enemies/Dark_Reef_range.png",
				"type": "range",
				"hp": 100,
				"mana": 50,
				"damage": 20,
				"speed": 1,
				"armor": 1,
				"XP": 69,
				"gold": "43-52"
			}
		],
		"unlocked": true,
		"background": "res://assets/zones/Dark_Reef.png",
		"battle_background": "res://assets/battle_areas/Dark_Reef_area.png"
	},

	"northern_pine": {
		"name": "Northern Pine",
		"description": "Onyx Grove also known as 'northern pine' is a dark forest where the exiled hero Sylla,
		the Lone Druid, discovered a shadowy nexus of fierce and strange creatures.",
		"music": "northern_pine",
		"heroes": [
			{
				"id": "lone_druid",
				"name": "Lone Druid",
				"image": "res://assets/heroes/Lone Druid.png",
				"background": "res://assets/zones/Northern_Pine.png",
				"range_type": "Range",
				"main_stat": "Agility",
				"stats": {
					"strength": 17,
					"agility": 24,
					"intelligence": 13,
					"range": 550,
					"hp": 473,
					"mana": 169,
					"armor": 3.4,
					"damage": "38-42",
					"speed": 1,
					"XP": 0
				},
				"skills": [
					{
						"id": "summon_spirit_bear",
						"name": "Summon Spirit Bear",
						"type": "standard",
						"description": "Summon a powerfull spirit companion. If the bear spirit dies druid loose 20% of his max HP.",
						"cooldown": 3,
						"mana_cost": 50
					},
					{
						"id": "entangle",
						"name": "Entangle",
						"type": "standard",
						"description": "When cast applies 2 stacks on each enemy. After 5 accumulated stacks enemies get rooted and take damage over time.",
						"cooldown": 3,
						"mana_cost": 50
					},
					{
						"id": "spirit_link",
						"name": "Spirit Link",
						"type": "standard",
						"description": "The druid and his spirit bear share % of their armor and lestsheal. Increse attack speed.",
						"cooldown": 3,
						"mana_cost": 50
					},
					{
						"id": "savage_roar",
						"name": "Savage Roar",
						"type": "standard",
						"description": "Increase move speed. All enemies are frighten and run away",
						"cooldown": 3,
						"mana_cost": 50
					},
					{
						"id": "true_form",
						"name": "True Form",
						"type": "ultimate",
						"description": "Ultimate: Druid morphs himself into a raging bear gaining bonus armor, health and damage.",
						"cooldown": 3,
						"mana_cost": 50
					}
				],
				"level_up": {
					"strength": 2.2,
					"agility": 1.6,
					"intelligence": 1.6
				},
			}
		],
		"enemies": [
			{
				"id": "northern_pine_mele",
				"name": "Northern Pine mele creep",
				"image": "res://assets/enemies/Northern_Pine_mele.png",
				"type": "mele",
				"hp": 150,
				"mana": 50,
				"damage": 10,
				"speed": 1,
				"armor": 1.5,
				"XP": 57,
				"gold": "34-39"
			},
			{
				"id": "northern_pine_mele_2",
				"name": "Northern Pine mele creep",
				"image": "res://assets/enemies/Northern_Pine_mele.png",
				"type": "mele",
				"hp": 150,
				"mana": 50,
				"damage": 10,
				"speed": 1,
				"armor": 1.5,
				"XP": 57,
				"gold": "34-39"
			},
			{
				"id": "northern_pine_range",
				"name": "Northern Pine range creep",
				"image": "res://assets/enemies/Northern_Pine_range.png",
				"type": "range",
				"hp": 100,
				"mana": 50,
				"damage": 20,
				"speed": 1,
				"armor": 1,
				"XP": 69,
				"gold": "43-52"
			}
		],
		"unlocked": true,
		"background": "res://assets/zones/Northern_Pine.png",
		"battle_background": "res://assets/battle_areas/Northern Pine_area.png"
	},

	"avarice": {
		"name": "Avarice / Avernus",
		"description": "The Realm of Avernus, a mist-shrouded domain became known as 'Avarice' - the greed.
		The kingdom of Slom was ruled by a tyrant whose descent into greed and dark magic brought madness to the throne.
		Abaddon: Abaddon is the current lord of Avernus. Unlike his brethren who trained purely for physical combat, 
		he spent decades meditating within the mist, absorbing its potency until he merged his spirit with it, 
		mastering powers over life and death.",
		"music": "avarice",
		"heroes": [
			{
				"id": "аbaddon",
				"name": "Abaddon",
				"image": "res://assets/heroes/Abaddon.png",
				"background": "res://assets/zones/Avarice.png",
				"range_type": "Mele",
				"main_stat": "Strength",
				"stats": {
					"strength": 22,
					"agility": 23,
					"intelligence": 19,
					"range": 150,
					"hp": 604,
					"mana": 303,
					"armor": 3.8,
					"damage": "40-50",
					"speed": 1,
					"XP": 0
				},
				"skills": [
					{
						"id": "mist_coil",
						"name": "Mist Coil",
						"type": "standard",
						"description": "Abaddon releases a coil of deathly mist that damage an enemy.",
						"cooldown": 3,
						"mana_cost": 50
					},
					{
						"id": "aphotic_shield",
						"name": "Aphotic Shield",
						"type": "standard",
						"description": "Creates a shield that absorbs damage and then explodes. The shield dispels negative effects.",
						"cooldown": 3,
						"mana_cost": 50
					},
					{
						"id": "Curse of Avernus",
						"name": "Curse of Avernus",
						"type": "standard",
						"description": "Passive: the attacks of Abaddon reduce enemy speed and deal damage over time.",
						"cooldown": 3,
						"mana_cost": 50
					},
					{
						"id": "borrowed_time",
						"name": "Borrowed Time",
						"type": "ultimate",
						"description": "Ultimate: Automaticaly activates when HP drop when Abaddon receive damage while his HP is bellow 400: all attacks heal him.",
						"cooldown": 3,
						"mana_cost": 50
					},
				],
				"level_up": {
					"strength": 2.2,
					"agility": 1.3,
					"intelligence": 1.6
				},
			}
		],
		"enemies": [
			{
				"id": "avarice_mele",
				"name": "Avarice mele creep",
				"image": "res://assets/enemies/Avarice_mele.png",
				"type": "mele",
				"hp": 150,
				"mana": 50,
				"damage": 10,
				"speed": 1,
				"armor": 1.5,
				"XP": 57,
				"gold": "34-39"
			},
			{
				"id": "avarice_mele_2",
				"name": "Avarice mele creep",
				"image": "res://assets/enemies/Avarice_mele.png",
				"type": "mele",
				"hp": 150,
				"mana": 50,
				"damage": 10,
				"speed": 1,
				"armor": 1.5,
				"XP": 57,
				"gold": "34-39"
			},
			{
				"id": "avarice_range",
				"name": "Avarice range creep",
				"image": "res://assets/enemies/Avarice_range.png",
				"type": "range",
				"hp": 100,
				"mana": 50,
				"damage": 20,
				"speed": 1,
				"armor": 1,
				"XP": 69,
				"gold": "43-52"
			}
		],
		"unlocked": true,
		"background": "res://assets/zones/Avarice.png",
		"battle_background": "res://assets/battle_areas/Avarice_area.png"
	},

	"cladd_isles": {
		"name": "Cladd Isles",
		"description": "Cladd (or Cladd Isles) is a rugged collection of islands famous for its powerful 
		maritime military, high-quality steel, and tragic history with deep-sea horrors. The proud blue-and-gold 
		naval fleet, known as 'The Claddish Navy', was once commanded by their Admiral: Kunkka.",
		"music": "cladd_isles",
		"heroes": [
			{
				"id": "kunkka",
				"name": "Kunkka",
				"image": "res://assets/heroes/Kunkka.png",
				"background": "res://assets/zones/Cladd_Isles.png",
				"range_type": "Mele",
				"main_stat": "Strength",
				"stats": {
					"strength": 24,
					"agility": 14,
					"intelligence": 18,
					"range": 150,
					"hp": 648,
					"mana": 291,
					"armor": 4.3,
					"damage": "50-60",
					"speed": 1,
					"XP": 0
				},
				"skills": [
					{
						"id": "torrent",
						"name": "Torrent",
						"type": "standard",
						"description": "Summons rising water that deals damage, slows movement, and stuns enemies after a delay.",
						"cooldown": 3,
						"mana_cost": 50
					},
					{
						"id": "tidebringer",
						"name": "Tidebringer",
						"type": "standard",
						"description": "Passive: sword strike that grants bonus damage and a massive cleave attack.",
						"cooldown": 3,
						"mana_cost": 50
					},
					{
						"id": "x_marks_the_spot",
						"name": "X Marks the Spot",
						"type": "standard",
						"description": "Marks a target hero, returning them to the marked location after a delay.",
						"cooldown": 3,
						"mana_cost": 50
					},
					{
						"id": "ghostship",
						"name": "Ghostship",
						"type": "ultimate",
						"description": "Ultimate: Summons a phantom ship that crashes, dealing damage and stunning.",
						"cooldown": 3,
						"mana_cost": 50
					},
				],
				"level_up": {
					"strength": 3.6,
					"agility": 1.6,
					"intelligence": 1.8
				},
			}
		],
		"enemies": [
			{
				"id": "cladd_isles_mele",
				"name": "Cladd Isles mele creep",
				"image": "res://assets/enemies/Cladd Isles_mele.png",
				"type": "mele",
				"hp": 150,
				"mana": 50,
				"damage": 10,
				"speed": 1,
				"armor": 1.5,
				"XP": 57,
				"gold": "34-39"
			},
			{
				"id": "cladd_isles_mele_2",
				"name": "Cladd Isles mele creep",
				"image": "res://assets/enemies/Cladd Isles_mele.png",
				"type": "mele",
				"hp": 150,
				"mana": 50,
				"damage": 10,
				"speed": 1,
				"armor": 1.5,
				"XP": 57,
				"gold": "34-39"
			},
			{
				"id": "cladd_isles_range",
				"name": "Cladd Isles range creep",
				"image": "res://assets/enemies/Cladd Isles_range.png",
				"type": "range",
				"hp": 100,
				"mana": 50,
				"damage": 20,
				"speed": 1,
				"armor": 1,
				"XP": 69,
				"gold": "43-52"
			}
		],
		"unlocked": true,
		"background": "res://assets/zones/Cladd_Isles.png",
		"battle_background": "res://assets/battle_areas/Cladd Isles_area.png"
	},

	"white_spire": {
		"name": "White Spire",
		"description": "A towering frozen region surrounded by ancient ice.",
		"music": "white_spire",
		"heroes": [
			{
				"id": "ancient_apparition",
				"name": "Ancient Apparition",
				"image": "res://assets/heroes/ancient_apparition.png",
				"background": "res://assets/zones/white_spire_ancient_apparition.png",
				"range_type": "Range",
				"main_stat": "Intelligence",
				"stats": {
					"strength": 20,
					"agility": 20,
					"intelligence": 23,
					"range": 675,
					"hp": 530,
					"mana": 299,
					"armor": 2,
					"damage": "44-54",
					"speed": 1,
					"XP": 0
				},
				"skills": [
					{
						"id": "cold_feet",
						"name": "Cold Feet",
						"type": "standard",
						"description": "Freezes an enemy in place",
						"cooldown": 3,
						"mana_cost": 50
					},
					{
						"id": "ice_vortex",
						"name": "Ice Vortex",
						"type": "standard",
						"description": "Damage all enemies around for a period of time",
						"cooldown": 3,
						"mana_cost": 50
					},
					{
						"id": "chilling_touch",
						"name": "Chilling Touch",
						"type": "standard",
						"description": "Blast an enemy with cold magic",
						"cooldown": 3,
						"mana_cost": 50
					},
					{
						"id": "ice_blast",
						"name": "Ice Blast",
						"type": "ultimate",
						"description": "Ultimate: fires an ice sphere that damage enemies based on the distance from the hero and shatters them if they are below a health threshold",
						"cooldown": 3,
						"mana_cost": 50
					},
				],
				"level_up": {
					"strength": 1.9,
					"agility": 2.2,
					"intelligence": 3.1
				},
			},
			{
				"id": "winter_wyvern",
				"name": "Winter Wyvern",
				"image": "res://assets/heroes/Winter_Wyvern.png",
				"background": "res://assets/zones/white_spire_Winter_Wyvern.png",
				"range_type": "Range",
				"main_stat": "Intelligence",
				"stats": {
					"strength": 22,
					"agility": 16,
					"intelligence": 26,
					"range": 450,
					"hp": 560,
					"mana": 387,
					"armor": 3.24,
					"damage": "42-49",
					"speed": 1,
					"XP": 0
				},
				"skills": [
					{
						"id": "arctic_burn",
						"name": "Arctic Burn",
						"type": "standard",
						"description": "Grants bonus attack range, dealing burn damage based on the enemy's current health.",
						"cooldown": 3,
						"mana_cost": 50
					},
					{
						"id": "splinter_blast",
						"name": "Splinter Blast",
						"type": "standard",
						"description": " Launches a floating ball of ice that shatters upon hitting an enemy, dealing area-of-effect damage to surrounding targets.",
						"cooldown": 3,
						"mana_cost": 50
					},
					{
						"id": "cold_embrace",
						"name": "Cold Embrace",
						"type": "standard",
						"description": "Encases themselves in ice, rendering them immune to physical damage and healing them based on missing health plus a base amount",
						"cooldown": 3,
						"mana_cost": 50
					},
					{
						"id": "winter's_curse",
						"name": "Winter's Curse",
						"type": "ultimate",
						"description": "Ultimate: Freezes a target enemy in place, forcing nearby allies of the target to attack it with bonus damage.",
						"cooldown": 3,
						"mana_cost": 50
					},
				],
				"level_up": {
					"strength": 2.2,
					"agility": 1.5,
					"intelligence": 2.8
				},
			}
		],
		"enemies": [
			{
				"id": "white_spire_mele",
				"name": "White Spire mele creep",
				"image": "res://assets/enemies/white_spire_mele.png",
				"type": "mele",
				"hp": 150,
				"mana": 50,
				"damage": 10,
				"speed": 1,
				"armor": 1.5,
				"XP": 57,
				"gold": "34-39"
			},
			{
				"id": "white_spire_mele_2",
				"name": "White Spire mele creep",
				"image": "res://assets/enemies/white_spire_mele.png",
				"type": "mele",
				"hp": 150,
				"mana": 50,
				"damage": 10,
				"speed": 1,
				"armor": 1.5,
				"XP": 57,
				"gold": "34-39"
			},
			{
				"id": "white_spire_range",
				"name": "White Spire range creep",
				"image": "res://assets/enemies/white_spire_range.png",
				"type": "range",
				"hp": 100,
				"mana": 50,
				"damage": 20,
				"speed": 1,
				"armor": 1,
				"XP": 69,
				"gold": "43-52"
			}
		],
		"unlocked": true,
		"background": "res://assets/zones/white_spire_ancient_apparition.png",
		"battle_background": "res://assets/battle_areas/white_spire_area.png"
	},

	"frozen_realm": {
		"name": "Frozen Realm",
		"description": "This bitter, ice-bound region is the origin of frost magic, 
		home to hardy tribes, and the domain of elemental forces of cold and winter.",
		"music": "frozen_realm",
		"heroes": [
			{
				"id": "crystal_maiden",
				"name": "Crystal Maiden",
				"image": "res://assets/heroes/Crystal Maiden.png",
				"background": "res://assets/zones/Frozen_Realm_Crystal_Maiden.png",
				"range_type": "Range",
				"main_stat": "Intelligence",
				"stats": {
					"strength": 17,
					"agility": 16,
					"intelligence": 17,
					"range": 600,
					"hp": 494,
					"mana": 291,
					"armor": 4.3,
					"damage": "48-54",
					"speed": 1,
					"XP": 0
				},
				"skills": [
					{
						"id": "crystal_nova",
						"name": "Crystal Nova",
						"type": "standard",
						"description": "A freezing blast that deals damage and slows enemy movement and attack speed in an area.",
						"cooldown": 3,
						"mana_cost": 50
					},
					{
						"id": "frostbite",
						"name": "Frostbite",
						"type": "standard",
						"description": "Locks an enemy in ice to deal damage over time and prevent movement or attacks.",
						"cooldown": 3,
						"mana_cost": 50
					},
					{
						"id": "arcane_aura",
						"name": "Arcane Aura",
						"type": "standard",
						"description": "Passive: grants mana regeneration bonus.",
						"cooldown": 3,
						"mana_cost": 50
					},
					{
						"id": "freezing_field",
						"name": "Freezing Field",
						"type": "ultimate",
						"description": "Ultimate: spawns random icy explosions around her heavily slowing and damaging enemies.",
						"cooldown": 3,
						"mana_cost": 50
					},
				],
				"level_up": {
					"strength": 2.2,
					"agility": 1.6,
					"intelligence": 3.3
				},
			},
			{
				"id": "tusk",
				"name": "Tusk",
				"image": "res://assets/heroes/Tusk.png",
				"background": "res://assets/zones/Frozen_Realm_Tusk.png",
				"range_type": "Mele",
				"main_stat": "Strength",
				"stats": {
					"strength": 23,
					"agility": 21,
					"intelligence": 18,
					"range": 150,
					"hp": 640,
					"mana": 267,
					"armor": 3.83,
					"damage": "50-54",
					"speed": 1,
					"XP": 0
				},
				"skills": [
					{
						"id": "ice_shards",
						"name": "Ice Shards",
						"type": "standard",
						"description": "Launches a ball of frozen energy that creates a barrier blocking paths and dealing damage.",
						"cooldown": 3,
						"mana_cost": 50
					},
					{
						"id": "snowball",
						"name": "Snowball",
						"type": "standard",
						"description": "Rolls into a snowball, to charge enemies and stun them on impact.",
						"cooldown": 3,
						"mana_cost": 50
					},
					{
						"id": "tag_team",
						"name": "Tag Team",
						"type": "standard",
						"description": "Passive: Creates a frozen aura around Tusk that slows enemies and adds bonus physical attack damage.",
						"cooldown": 3,
						"mana_cost": 50
					},
					{
						"id": "walrus_punch",
						"name": "Walrus Punch",
						"type": "ultimate",
						"description": "Ultimate: Tusk's signature knockout punch, critical striking the target.",
						"cooldown": 3,
						"mana_cost": 50
					},
				],
				"level_up": {
					"strength": 3.9,
					"agility": 2.1,
					"intelligence": 1.7
				},
			}
		],
		"enemies": [
			{
				"id": "frozen_realm_mele",
				"name": "Frozen Realm mele creep",
				"image": "res://assets/enemies/Frozen_Realm_mele.png",
				"type": "mele",
				"hp": 150,
				"mana": 50,
				"damage": 10,
				"speed": 1,
				"armor": 1.5,
				"XP": 57,
				"gold": "34-39"
			},
			{
				"id": "frozen_realm_mele_2",
				"name": "Frozen Realm mele creep",
				"image": "res://assets/enemies/Frozen_Realm_mele.png",
				"type": "mele",
				"hp": 150,
				"mana": 50,
				"damage": 10,
				"speed": 1,
				"armor": 1.5,
				"XP": 57,
				"gold": "34-39"
			},
			{
				"id": "frozen_realm_range",
				"name": "Frozen Realm range creep",
				"image": "res://assets/enemies/Frozen_Realm_range.png",
				"type": "range",
				"hp": 100,
				"mana": 50,
				"damage": 20,
				"speed": 1,
				"armor": 1,
				"XP": 57,
				"gold": "43-52"
			}
		],
		"unlocked": true,
		"background": "res://assets/zones/Frozen_Realm_Crystal_Maiden.png",
		"battle_background": "res://assets/battle_areas/Frozen_Realm_area.png"
	},

	"vale_of_augury": {
		"name": "Vale of Augury",
		"description": "A remote western land near the port city of Augury Bay and the high mountain woods of the Treant Protectors.
		The mountains beyond the vale contain an ancient power source emitting strange, life-altering energy.
		The technologically advanced inhabitants of nearby Augury Bay threatened the natural order, prompting a devastating attack by 
		the ageless Treant Protectors that leveled the city and its surroundings.",
		"music": "vale_of_augury",
		"heroes": [
			{
				"id": "treant_protector",
				"name": "Treant Protector",
				"image": "res://assets/heroes/Treant_Protector.png",
				"background": "res://assets/zones/Vale_of_Augury_Treant_Protector.png",
				"range_type": "Melee",
				"main_stat": "Strength",
				"stats": {
					"strength": 25,
					"agility": 15,
					"intelligence": 20,
					"range": 150,
					"hp": 670,
					"mana": 315,
					"armor": 3.5,
					"damage": "85-93",
					"speed": 1,
					"XP": 0
				},
				"skills": [
					{
						"id": "nature's_guise",
						"name": "Nature's Guise",
						"type": "standard",
						"description": "Grants the ability to walk through trees, gaining bonus movement.",
						"cooldown": 3,
						"mana_cost": 50
					},
					{
						"id": "leech_seed",
						"name": "Leech Seed",
						"type": "standard",
						"description": "Plants a seed in an enemy, draining health to heal himself.",
						"cooldown": 3,
						"mana_cost": 50
					},
					{
						"id": "living_armor",
						"name": "Living Armor",
						"type": "standard",
						"description": "Gives himself bonus armor and health regeneration.",
						"cooldown": 3,
						"mana_cost": 50
					},
					{
						"id": "overgrowth",
						"name": "Overgrowth",
						"type": "ultimate",
						"description": "Ultimate: entangles all nearby enemy units in roots, stopping them from moving or attacking and dealing damage over time.",
						"cooldown": 3,
						"mana_cost": 50
					},
				],
				"level_up": {
					"strength": 3.4,
					"agility": 1.8,
					"intelligence": 1.8
				},
			},
			{
				"id": "timbersaw",
				"name": "Timbersaw",
				"image": "res://assets/heroes/Timbersaw.png",
				"background": "res://assets/zones/Vale_of_Augury_Timbersaw.png",
				"range_type": "Mele",
				"main_stat": "Strength",
				"stats": {
					"strength": 27,
					"agility": 16,
					"intelligence": 24,
					"range": 150,
					"hp": 714,
					"mana": 351,
					"armor": 2.67,
					"damage": "48-52",
					"speed": 1,
					"XP": 0
				},
				"skills": [
					{
						"id": "whirling_death",
						"name": "Whirling Death",
						"type": "standard",
						"description": "Deals pure damage and destroys surrounding trees, reducing enemy primary attributes if a hero is hit.",
						"cooldown": 3,
						"mana_cost": 50
					},
					{
						"id": "timber_chain",
						"name": "Timber Chain",
						"type": "standard",
						"description": "Fires a chain to pull Timbersaw toward the furthest enemy it hits, damaging enemies along the path.",
						"cooldown": 3,
						"mana_cost": 50
					},
					{
						"id": "reactive_armor",
						"name": "Reactive Armor",
						"type": "standard",
						"description": "Passive: grants stackable bonus armor and health regeneration when attacked.",
						"cooldown": 3,
						"mana_cost": 50
					},
					{
						"id": "chakram",
						"name": "Chakram",
						"type": "ultimate",
						"description": "Ultimate: launches a saw blade that spins in place, dealing pure damage to enemies based on missing health.",
						"cooldown": 3,
						"mana_cost": 50
					},
				],
				"level_up": {
					"strength": 3.5,
					"agility": 1.3,
					"intelligence": 2.7
				},
			},
			{
				"id": "snapfire",
				"name": "Snapfire",
				"image": "res://assets/heroes/Snapfire.png",
				"background": "res://assets/zones/Vale_of_Augury_Snapfire.png",
				"range_type": "Range",
				"main_stat": "Strength",
				"stats": {
					"strength": 21,
					"agility": 16,
					"intelligence": 21,
					"range": 500,
					"hp": 582,
					"mana": 327,
					"armor": 3.7,
					"damage": "67-73",
					"speed": 1,
					"XP": 0
				},
				"skills": [
					{
						"id": "scatterblast",
						"name": "Scatterblast",
						"type": "standard",
						"description": "Fires a shotgun blast that deals damage to enemies, with extra effectiveness at point-blank range.",
						"cooldown": 3,
						"mana_cost": 50
					},
					{
						"id": "firesnap_cookie",
						"name": "Firesnap Cookie",
						"type": "standard",
						"description": "Feeds a cookie to Mortimer (her toad) to cause a hop that stuns and damages enemies on landing.",
						"cooldown": 3,
						"mana_cost": 50
					},
					{
						"id": "lil_shredder",
						"name": "Lil' Shredder",
						"type": "standard",
						"description": "Rapidly fires fixed-damage attacks with bonus range that reduce enemy armor.",
						"cooldown": 3,
						"mana_cost": 50
					},
					{
						"id": "mortimer_kisses",
						"name": "Mortimer Kisses",
						"type": "ultimate",
						"description": "Ultimate: launches a barrage of globs of firespit over a long distance, creating burning pools that deal initial and damage over time",
						"cooldown": 3,
						"mana_cost": 50
					},
				],
				"level_up": {
					"strength": 3.2,
					"agility": 1.2,
					"intelligence": 2.1
				},
			}
		],
		"enemies": [
			{
				"id": "vale_of_augury_mele",
				"name": "Vale of Augury mele creep",
				"image": "res://assets/enemies/vale_of_augury_mele.png",
				"type": "mele",
				"hp": 150,
				"mana": 50,
				"damage": 10,
				"speed": 1,
				"armor": 1.5,
				"XP": 57,
				"gold": "34-39"
			},
			{
				"id": "vale_of_augury_mele_2",
				"name": "Vale of Augury mele creep",
				"image": "res://assets/enemies/vale_of_augury_mele.png",
				"type": "mele",
				"hp": 150,
				"mana": 50,
				"damage": 10,
				"speed": 1,
				"armor": 1.5,
				"XP": 57,
				"gold": "34-39"
			},
			{
				"id": "vale_of_augury_range",
				"name": "Vale of Augury range creep",
				"image": "res://assets/enemies/vale_of_augury_range.png",
				"type": "range",
				"hp": 100,
				"mana": 50,
				"damage": 20,
				"speed": 1,
				"armor": 1,
				"XP": 57,
				"gold": "43-52"
			}
		],
		"unlocked": true,
		"background": "res://assets/zones/Vale_of_Augury_Treant_Protector.png",
		"battle_background": "res://assets/battle_areas/Vale_of_Augury.png"
	},

	"wailing_mountains": {
		"name": "Wailing Mountains",
		"description": "Jagged mountains where the wind carries unsettling cries.",
		"music": "wailing_mountains",
		"heroes": [],
		"unlocked": true,
		"background": ""
	},

	"kingdom_of_olympus": {
		"name": "Kingdom of Olympus",
		"description": "A legendary kingdom ruled from the heights of the gods.",
		"music": "kingdom_of_olympus",
		"heroes": [],
		"unlocked": true,
		"background": ""
	},

	"sunken_cities": {
		"name": "Sunken Cities",
		"description": "The Sunken Cities are a vast network of elegant, subaqueous metropolises 
		built by the Naga and guarded by the Deep Ones and the Slithereen Guard. These lightless 
		ocean depths hold ancient golden riches and the Deep Vault, protected from surface thieves 
		and marauding Levianths who seek tribute for the tentacled ancient god, Maelrawn",
		"music": "sunken_cities",
		"heroes": [
			{
				"id": "naga_siren",
				"name": "Naga Siren",
				"image": "res://assets/heroes/Naga Siren.png",
				"background": "res://assets/zones/Sunken_Cities_Naga.png",
				"range_type": "Mele",
				"main_stat": "Agility",
				"stats": {
					"strength": 21,
					"agility": 22,
					"intelligence": 19,
					"range": 150,
					"hp": 582,
					"mana": 303,
					"armor": 4.7,
					"damage": "45-47",
					"speed": 1,
					"XP": 0
				},
				"skills": [
					{
						"id": "mirror_image",
						"name": "Mirror Image",
						"type": "standard",
						"description": "Creates illusions of Naga Siren that deal damage.",
						"cooldown": 3,
						"mana_cost": 50
					},
					{
						"id": "ensnare",
						"name": "Ensnare",
						"type": "standard",
						"description": "Nets an enemy unit, stopping movement and blink abilities.",
						"cooldown": 3,
						"mana_cost": 50
					},
					{
						"id": "rip_tide",
						"name": "Rip Tide",
						"type": "standard",
						"description": "Passive: attacks from Naga and her illusions reduce enemy armor and deal AoE damage.",
						"cooldown": 3,
						"mana_cost": 50
					},
					{
						"id": "song_of_the_siren",
						"name": "Song of the Siren",
						"type": "ultimate",
						"description": "Ultimate: puts all nearby enemies into a deep sleep",
						"cooldown": 3,
						"mana_cost": 50
					},
				],
				"level_up": {
					"strength": 2.4,
					"agility": 3.4,
					"intelligence": 2
				},
			},
			{
				"id": "slardar",
				"name": "Slardar",
				"image": "res://assets/heroes/Slardar.png",
				"background": "res://assets/zones/Sunken_Cities_Slardar.png",
				"range_type": "Mele",
				"main_stat": "Strength ",
				"stats": {
					"strength": 21,
					"agility": 17,
					"intelligence": 15,
					"range": 150,
					"hp": 582,
					"mana": 255,
					"armor": 5.83,
					"damage": "51-59",
					"speed": 1,
					"XP": 0
				},
				"skills": [
					{
						"id": "guardian_sprint",
						"name": "Guardian Sprint",
						"type": "standard",
						"description": "Grants bonus movement speed, phase movement, and slow resistance.",
						"cooldown": 3,
						"mana_cost": 50
					},
					{
						"id": "slithereen_crush",
						"name": "Slithereen Crush",
						"type": "standard",
						"description": "Slams the ground to stun and damage enemies.",
						"cooldown": 3,
						"mana_cost": 50
					},
					{
						"id": "bash_of_the_deep",
						"name": "Bash of the Deep",
						"type": "standard",
						"description": "Passive: triggers a physical bash and bonus damage.",
						"cooldown": 3,
						"mana_cost": 50
					},
					{
						"id": "corrosive_haze",
						"name": "Corrosive Haze",
						"type": "ultimate",
						"description": "Ultimate: reduces enemy armor and provides true sight.",
						"cooldown": 3,
						"mana_cost": 50
					},
				],
				"level_up": {
					"strength": 3.4,
					"agility": 2.1,
					"intelligence": 1.5
				},
			}
		],
		"enemies": [
			{
				"id": "sunken_cities_mele",
				"name": "Sunken Cities mele creep",
				"image": "res://assets/enemies/Sunken Cities_mele.png",
				"type": "mele",
				"hp": 150,
				"mana": 50,
				"damage": 10,
				"speed": 1,
				"armor": 1.5,
				"XP": 57,
				"gold": "34-39"
			},
			{
				"id": "sunken_cities_mele_2",
				"name": "Sunken Cities mele creep",
				"image": "res://assets/enemies/Sunken Cities_mele.png",
				"type": "mele",
				"hp": 150,
				"mana": 50,
				"damage": 10,
				"speed": 1,
				"armor": 1.5,
				"XP": 57,
				"gold": "34-39"
			},
			{
				"id": "sunken_cities_range",
				"name": "Sunken Cities range",
				"image": "res://assets/enemies/Sunken Cities_range.png",
				"type": "range",
				"hp": 100,
				"mana": 50,
				"damage": 20,
				"speed": 1,
				"armor": 1,
				"XP": 69,
				"gold": "43-52"
			}
		],
		"unlocked": true,
		"background": "res://assets/zones/Sunken_Cities_Naga.png",
		"battle_background": "res://assets/battle_areas/Sunken Cities_area.png"
	},

	"nightsilver_woods": {
		"name": "Nightsilver Woods",
		"description": "A sacred, perpetual-night forest dedicated to the Moon Goddess Selemene. 
		Sanctified by a fallen celestial moon shard, it houses holy sites like the Shrine of Selemene 
		and the Temple of Mene, protected fiercely by the zealous Dark Moon Order against poachers and invaders.",
		"music": "nightsilver_woods",
		"heroes": [
			{
				"id": "mirana",
				"name": "Mirana",
				"image": "res://assets/heroes/Mirana.png",
				"background": "res://assets/zones/Nightsilver_Woods_Mirana.png",
				"range_type": "Range",
				"main_stat": "Agility",
				"stats": {
					"strength": 20,
					"agility": 26,
					"intelligence": 22,
					"range": 630,
					"hp": 560,
					"mana": 339,
					"armor": 2,
					"damage": "19-23",
					"speed": 1,
					"XP": 0
				},
				"skills": [
					{
						"id": "starstorm",
						"name": "Starstorm",
						"type": "standard",
						"description": "Calls down meteors to damage nearby enemies.",
						"cooldown": 3,
						"mana_cost": 50
					},
					{
						"id": "sacred_arrow",
						"name": "Sacred Arrow",
						"type": "standard",
						"description": "Fires a long-range arrow that deals damage and stuns an enemy based on distance traveled.",
						"cooldown": 3,
						"mana_cost": 50
					},
					{
						"id": "leap",
						"name": "Leap",
						"type": "standard",
						"description": "Mirana leaps forward, granting temporary attack speed bonus.",
						"cooldown": 3,
						"mana_cost": 50
					},
					{
						"id": "moonlight_shadow",
						"name": "Moonlight Shadow",
						"type": "ultimate",
						"description": "Ultimate: turns invisible. On attack deals bonus damage and reveals herself.",
						"cooldown": 3,
						"mana_cost": 50
					},
				],
				"level_up": {
					"strength": 2.2,
					"agility": 3.1,
					"intelligence": 1.9
				},
			},
			{
				"id": "luna",
				"name": "Luna",
				"image": "res://assets/heroes/Luna.png",
				"background": "res://assets/zones/Nightsilver_Woods_Luna.png",
				"range_type": "Range",
				"main_stat": "Agility",
				"stats": {
					"strength": 21,
					"agility": 24,
					"intelligence": 23,
					"range": 330,
					"hp": 582,
					"mana": 351,
					"armor": 5.83,
					"damage": "50-56",
					"speed": 1,
					"XP": 0
				},
				"skills": [
					{
						"id": "lucent_beam",
						"name": "Lucent Beam",
						"type": "standard",
						"description": "Fires a lunar beam at an enemy that does damage and a brief stun.",
						"cooldown": 3,
						"mana_cost": 50
					},
					{
						"id": "moon_glaives",
						"name": "Moon Glaives",
						"type": "standard",
						"description": "Passive: attacks bounce to nearby enemies with a damage reduction per bounce.",
						"cooldown": 3,
						"mana_cost": 50
					},
					{
						"id": "lunar_blessing",
						"name": "Lunar Blessing",
						"type": "standard",
						"description": "Passive: aura granting bonus attack damage.",
						"cooldown": 3,
						"mana_cost": 50
					},
					{
						"id": "eclipse",
						"name": "Eclipse",
						"type": "ultimate",
						"description": "Ultimate: Unleashes a flurry of Lucent Beams.",
						"cooldown": 3,
						"mana_cost": 50
					},
				],
				"level_up": {
					"strength": 2.2,
					"agility": 3.4,
					"intelligence": 1.9
				},
			}
		],
		"enemies": [
			{
				"id": "nightsilver_woods_mele",
				"name": "Nightsilver Woods mele creep",
				"image": "res://assets/enemies/Nightsilver_Woods_mele.png",
				"type": "mele",
				"hp": 150,
				"mana": 50,
				"damage": 10,
				"speed": 1,
				"armor": 1.5,
				"XP": 57,
				"gold": "34-39"
			},
			{
				"id": "nightsilver_woods_mele_2",
				"name": "Nightsilver Woods mele creep",
				"image": "res://assets/enemies/Nightsilver_Woods_mele.png",
				"type": "mele",
				"hp": 150,
				"mana": 50,
				"damage": 10,
				"speed": 1,
				"armor": 1.5,
				"XP": 57,
				"gold": "34-39"
			},
			{
				"id": "nightsilver_woods_range",
				"name": "Nightsilver Woods range creep",
				"image": "res://assets/enemies/Nightsilver_Woods_range.png",
				"type": "range",
				"hp": 100,
				"mana": 50,
				"damage": 20,
				"speed": 1,
				"armor": 1,
				"XP": 69,
				"gold": "43-52"
			}
		],
		"unlocked": true,
		"background": "res://assets/zones/Nightsilver_Woods_Mirana.png",
		"battle_background": "res://assets/battle_areas/Nightsilver_Woods_area.png"
	},

	"hinterlands": {
		"name": "Hinterlands",
		"description": "A vast wilderness far from the civilized lands.",
		"music": "hinterlands",
		"heroes": [],
		"unlocked": true,
		"background": ""
	},

	"drakken_highlands": {
		"name": "Drakken Highlands",
		"description": "A harsh mountainous region inhabited by powerful creatures.",
		"music": "drakken_highlands",
		"heroes": [],
		"unlocked": true,
		"background": ""
	},

	"jidi_islands": {
		"name": "Jidi Islands",
		"description": "Remote islands surrounded by mysterious waters.",
		"music": "jidi_islands",
		"heroes": [],
		"unlocked": true,
		"background": ""
	},

	"nishai": {
		"name": "Nishai",
		"description": "A wild region scarred by ancient forces.",
		"music": "nishai",
		"heroes": [],
		"unlocked": true,
		"background": ""
	},

	"outlands": {
		"name": "Outlands",
		"description": "A dangerous frontier beyond the known territories.",
		"music": "outlands",
		"heroes": [],
		"unlocked": true,
		"background": ""
	},

	"bronze_empire": {
		"name": "Bronze Empire",
		"description": "The heartland of an ancient and powerful empire.",
		"music": "bronze_empire",
		"heroes": [],
		"unlocked": true,
		"background": ""
	},

	"ruelands": {
		"name": "Ruelands",
		"description": "A battered land shaped by centuries of conflict.",
		"music": "ruelands",
		"heroes": [],
		"unlocked": true,
		"background": ""
	},

	"emauracus": {
		"name": "Emauracus",
		"description": "A remote land surrounded by ancient mysteries.",
		"music": "emauracus",
		"heroes": [],
		"unlocked": true,
		"background": ""
	},

	"ghastly_eyrie": {
		"name": "Ghastly Eyrie",
		"description": "A haunted region hidden among the clouds.",
		"music": "ghastly_eyrie",
		"heroes": [],
		"unlocked": true,
		"background": ""
	},

	"arktura": {
		"name": "Arktura",
		"description": "A remote wilderness at the edge of the known world.",
		"music": "arktura",
		"heroes": [],
		"unlocked": true,
		"background": ""
	},

	"xhacatocail_mountains": {
		"name": "Xhacatocail Mountains",
		"description": "A vast mountain range filled with ancient dangers.",
		"music": "xhacatocail_mountains",
		"heroes": [],
		"unlocked": true,
		"background": ""
	},

	"kalabor": {
		"name": "Kalabor",
		"description": "A harsh land where ancient civilizations once flourished.",
		"music": "kalabor",
		"heroes": [],
		"unlocked": true,
		"background": ""
	},

	"scintillant_waste": {
		"name": "Scintillant Waste",
		"description": "A barren wasteland shimmering beneath an unforgiving sky.",
		"music": "scintillant_waste",
		"heroes": [],
		"unlocked": true,
		"background": ""
	},

	"revtel": {
		"name": "Revtel",
		"description": "An ancient region filled with forgotten ruins.",
		"music": "revtel",
		"heroes": [],
		"unlocked": true,
		"background": ""
	},

	"fields_of_carnage": {
		"name": "Fields of Carnage",
		"description": "Battlefields where countless warriors have fallen.",
		"music": "fields_of_carnage",
		"heroes": [],
		"unlocked": true,
		"background": ""
	},

	"bleeding_hills": {
		"name": "Bleeding Hills",
		"description": "A grim region stained by endless conflict.",
		"music": "bleeding_hills",
		"heroes": [],
		"unlocked": true,
		"background": ""
	},

	"hoven": {
		"name": "Hoven",
		"description": "A mysterious land surrounded by ancient wilderness.",
		"music": "hoven",
		"heroes": [],
		"unlocked": true,
		"background": ""
	},

	"fellstrath": {
		"name": "Fellstrath",
		"description": "A dark and corrupted region.",
		"music": "fellstrath",
		"heroes": [],
		"unlocked": true,
		"background": ""
	},

	"druud": {
		"name": "Druud",
		"description": "A dangerous territory filled with forgotten secrets.",
		"music": "druud",
		"heroes": [],
		"unlocked": true,
		"background": ""
	},

	"hazhadal_barrens": {
		"name": "Hazhadal Barrens",
		"description": "A vast barren region where survival is a constant struggle.",
		"music": "hazhadal_barrens",
		"heroes": [],
		"unlocked": true,
		"background": ""
	},

	"ivory_isles": {
		"name": "Ivory Isles",
		"description": "Beautiful islands hiding dangers beneath their surface.",
		"music": "ivory_isles",
		"heroes": [],
		"unlocked": true,
		"background": ""
	},

	"ashkavor": {
		"name": "Ashkavor",
		"description": "A volcanic region covered in ash and ancient ruins.",
		"music": "ashkavor",
		"heroes": [],
		"unlocked": true,
		"background": ""
	},

	"thousand_tarns": {
		"name": "Thousand Tarns",
		"description": "A land of countless lakes and hidden passages.",
		"music": "thousand_tarns",
		"heroes": [],
		"unlocked": true,
		"background": ""
	},

	"gun_yu": {
		"name": "Gun-Yu",
		"description": "A distant region with its own ancient traditions.",
		"music": "gun_yu",
		"heroes": [],
		"unlocked": true,
		"background": ""
	},

	"new_frontiers": {
		"name": "New Frontiers",
		"description": "Uncharted lands waiting to be explored.",
		"music": "new_frontiers",
		"heroes": [],
		"unlocked": true,
		"background": ""
	},

	"drylands": {
		"name": "Drylands",
		"description": "A vast dry region where water is more valuable than gold.",
		"music": "drylands",
		"heroes": [],
		"unlocked": true,
		"background": ""
	},

	"dezun": {
		"name": "Dezun",
		"description": "A mysterious region at the southern edge of the world.",
		"music": "dezun",
		"heroes": [],
		"unlocked": true,
		"background": ""
	}
}


# ============================================================
# ZONE FUNCTIONS
# ============================================================

## Converts a display name like "Xhacatocail Mountains" or "Gun-Yu" into
## the matching dictionary key ("xhacatocail_mountains", "gun_yu").
## Map.gd should use this instead of hand-building the id, so the two
## scripts can never drift out of sync with each other again.
func zone_id_from_name(zone_name: String) -> String:
	return zone_name.to_lower().replace(" ", "_").replace("-", "_")


func select_zone(zone_id: String) -> void:
	if not zones.has(zone_id):
		print("ERROR: Zone does not exist: ", zone_id)
		return

	selected_zone = zone_id


## Convenience wrapper: pass the display name straight from Map.gd,
## e.g. GameManager.select_zone_by_name("Xhacatocail Mountains")
func select_zone_by_name(zone_name: String) -> void:
	select_zone(zone_id_from_name(zone_name))


func get_selected_zone() -> Dictionary:
	if selected_zone == "":
		return {}

	return zones[selected_zone]


func get_zone(zone_id: String) -> Dictionary:
	if not zones.has(zone_id):
		return {}

	return zones[zone_id]


## Searches every zone's hero list for a matching id and returns that
## hero's full static definition (stats, skills, image, etc). Used by
## the Battle scene, which only has the recruited hero's id saved in
## the player's data file and needs the rest looked back up.
func get_hero_by_id(hero_id: String) -> Dictionary:
	for zone_id in zones.keys():
		var heroes: Array = zones[zone_id].get("heroes", [])
		for hero in heroes:
			if hero.get("id", "") == hero_id:
				return hero
	return {}


## Which zone a given hero id originally belongs to (i.e. shows up in
## that zone's "heroes" list) - "" if not found. Used to tell whether
## a hero fight is happening in the player's own recruited hero's home
## zone (in which case that one hero is excluded from the fight pool)
## or a foreign one (where every hero in it is eligible).
func get_zone_id_for_hero(hero_id: String) -> String:
	if hero_id == "":
		return ""
	for zone_id in zones.keys():
		var heroes: Array = zones[zone_id].get("heroes", [])
		for hero in heroes:
			if hero.get("id", "") == hero_id:
				return zone_id
	return ""


# ------------------------------------------------------------------
# Hero fights: clearing every stage of a zone without it being fully
# cleared before can trigger a fight against one of that zone's other
# heroes (or, in a foreign zone, any of its heroes) - see battle.gd's
# _try_start_hero_fight(). A rival hero doesn't have creep-style
# hp/damage/XP/gold fields of its own, so build_hero_fight_enemy_def()
# derives them from the hero's own stats; tune the gold multipliers
# below to rebalance that reward without touching battle.gd.
#
# The XP field used to be a flat hp-based multiplier (hp * 0.5) - as
# of Step 5 it's the same hero-kill bounty formula EnemyHeroManager
# uses for an NPC-kills-NPC duel (see EnemyHeroManager.
# get_hero_kill_bounty), so a hero's death is worth the same XP no
# matter who lands the killing blow. Routing it through here rather
# than through battle.gd means both cases share one formula for free,
# since battle.gd just reads whatever XP this enemy_def declares.
# ------------------------------------------------------------------

const HERO_FIGHT_GOLD_MIN_MULTIPLIER: float = 0.3
const HERO_FIGHT_GOLD_MAX_MULTIPLIER: float = 0.4


## Converts a hero's definition into an enemy-shaped Dictionary so it
## can be fought through the same _spawn_enemy()/_enemy_turn() path as
## regular creeps. Damage collapses from the hero's "min-max" range to
## a flat average, since enemies deal one flat number per hit rather
## than rolling a range. "range_type" ("Range"/"Melee"/"Mele", not
## always consistently capitalized) maps to the "mele"/"range" type
## regular enemies use.
func build_hero_fight_enemy_def(hero_static: Dictionary) -> Dictionary:
	var stats: Dictionary = hero_static.get("stats", {})
	var hp: float = float(stats.get("hp", 1))
	var hero_id: String = hero_static.get("id", "")

	var damage_parts: PackedStringArray = str(stats.get("damage", "0-0")).split("-")
	var damage_min: float = float(damage_parts[0]) if damage_parts.size() > 0 else 0.0
	var damage_max: float = float(damage_parts[1]) if damage_parts.size() > 1 else damage_min
	var flat_damage: float = roundi((damage_min + damage_max) / 2.0)

	var is_ranged: bool = str(hero_static.get("range_type", "")).to_lower().begins_with("range")

	return {
		"id": hero_id,
		"name": hero_static.get("name", "Rival Hero"),
		"image": hero_static.get("image", ""),
		"type": "range" if is_ranged else "mele",
		"hp": hp,
		"damage": flat_damage,
		"armor": float(stats.get("armor", 0)),
		"XP": roundi(EnemyHeroManager.get_hero_kill_bounty(hero_id)),
		"gold": "%d-%d" % [roundi(hp * HERO_FIGHT_GOLD_MIN_MULTIPLIER), roundi(hp * HERO_FIGHT_GOLD_MAX_MULTIPLIER)],
		# Hero portraits are drawn facing right; battle.gd's
		# _spawn_enemy() uses this to mirror the art when it's placed
		# on the enemy side, so it faces the player's hero instead.
		"is_hero_fight": true,
	}


# ============================================================
# ITEM DATA
# ============================================================
# effect "heal" and "mana" are the only consumables - used from the
# battle item grid, they restore current_hp/current_mana directly and
# are removed from the inventory.
# effect "stat" items (damage, armor, strength, agility, intelligence,
# or a list of several, like Circlet) are passive equipment instead:
# PlayerManager.get_inventory_stat_bonus() sums their "value" for
# every copy currently owned, so the bonus applies only as long as the
# item stays in the inventory and disappears the moment it's sold.

# ============================================================
# SHOP DATA
# ============================================================
# Which item ids are currently sold in the Shop scene, and how many
# of each are in stock per visit. Kept separate from `items` so the
# full item catalog (including ones not sold yet, like the stat
# boosts) doesn't have to be filtered down at runtime.

const SHOP_ITEM_IDS: Array[String] = ["health", "mana", "gauntlets_of_strength", "mantle_of_intelligence", 
"slippers_of_agility", "circlet", "blades_of_attack"]
const SHOP_STOCK_PER_ITEM: int = 3


var items: Dictionary = {
	"health": {
		"id": "health",
		"name": "Health Potion",
		"image": "res://assets/items/health.png",
		"description": "Heals 350 hp",
		"effect": "heal",
		"value": 350,
		"cost": 100,
		"stackable": true
	},
	"mana": {
		"id": "mana",
		"name": "Mana Potion",
		"image": "res://assets/items/mana.png",
		"description": "Restores 150 mana",
		"effect": "mana",
		"value": 150,
		"cost": 60,
		"stackable": true
	},
	"blades_of_attack": {
		"id": "blades_of_attack",
		"name": "Blades of аttack",
		"image": "res://assets/items/Blades_of_Attack.png",
		"description": "Add +9 damage",
		"effect": "stat",
		"stat": "damage",
		"value": 9,
		"cost": 450
	},
	"gauntlets_of_strength": {
		"id": "gauntlets_of_strength",
		"name": "Gauntlets of strength",
		"image": "res://assets/items/gauntlets_of_strength.png",
		"description": "Adds +3 strength",
		"effect": "stat",
		"stat": "strength",
		"value": 3,
		"cost": 140
	},
	"slippers_of_agility": {
		"id": "slippers_of_agility",
		"name": "Slippers of agility",
		"image": "res://assets/items/slippers_of_agility.png",
		"description": "Adds +3 agility",
		"effect": "stat",
		"stat": "agility",
		"value": 3,
		"cost": 140
	},
	"mantle_of_intelligence": {
		"id": "mantle_of_intelligence",
		"name": "Mantle of intelligence",
		"image": "res://assets/items/mantle_of_intelligence.png",
		"description": "Adds +3 intelligence",
		"effect": "stat",
		"stat": "intelligence",
		"value": 3,
		"cost": 140
	},
	"circlet": {
		"id": "circlet",
		"name": "Circlet",
		"image": "res://assets/items/circlet.png",
		"description": "Adds +1.5 to all attributes",
		"effect": "stat",
		"stat": ["strength", "agility", "intelligence"],
		"value": 1.5,
		"cost": 155
	},
}


func get_item(item_id: String) -> Dictionary:
	return items.get(item_id, {})
