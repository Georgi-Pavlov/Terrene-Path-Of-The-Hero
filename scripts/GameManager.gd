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


## Turns one level's worth of a skill's raw mechanical fields (damage,
## mana_cost, cooldown, dot_damage, stun_turns, radius, ... - the exact
## set varies per skill, see get_skill_level_data()) into a human-
## readable, one-stat-per-line summary, e.g. "Damage: 100\nMana Cost:
## 50\nCooldown: 5". Used wherever a skill's description is shown for
## the player to pick from (zone.gd's starting-skill picker, battle.gd's
## learn/upgrade popup) so the numbers behind the flavor text are
## visible before committing. Field order follows however each skill's
## own "levels" entry was written (Dictionary keys preserve insertion
## order in GDScript), which is already the sensible reading order
## every skill definition above was authored in. A "_pct" suffixed key
## is shown as a percentage of its raw 0..1 fraction instead, with
## "Pct" dropped from the label.
func format_skill_level_stats(level_data: Dictionary) -> String:
	var lines: PackedStringArray = []
	for key in level_data.keys():
		var raw_value = level_data[key]
		if str(key).ends_with("_pct"):
			var label: String = str(key).trim_suffix("_pct").capitalize()
			lines.append("%s: %d%%" % [label, roundi(float(raw_value) * 100.0)])
		else:
			lines.append("%s: %s" % [str(key).capitalize(), _format_skill_stat_value(raw_value)])
	return "\n".join(lines)


## A whole-number float (the overwhelming majority of skill level
## fields - GDScript dictionary literals like {"damage": 100} still
## store 100 as a float) prints as "100", not "100.0"; a genuinely
## fractional one (e.g. a 0.75 damage_multiplier not caught by the
## "_pct" convention above) keeps one decimal place. Anything else
## (int, String) just stringifies as-is.
func _format_skill_stat_value(raw_value) -> String:
	if typeof(raw_value) == TYPE_FLOAT:
		if is_equal_approx(raw_value, roundf(raw_value)):
			return str(int(raw_value))
		return "%.1f" % raw_value
	return str(raw_value)


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

# Veyrik's Leeching Hunger (see battle.gd's _apply_leeching_hunger_steal):
# an enemy's main_stat_value is never drained below this floor, so a
# long fight can't leave an enemy sitting at 0 or negative stats.
const LEECHING_HUNGER_MIN_ENEMY_MAIN_STAT: int = 5


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
# PlayerManager.set_zone_cleared(), but every new entry still starts
# back at stage 1 - see PlayerManager.get_zone_start_stage().

const MAX_ZONE_STAGE: int = 3

# How many melee/ranged enemies spawn at each stage. If a zone
# doesn't have that many distinct melee/ranged templates in its
# "enemies" list, battle.gd just cycles through the ones it has.
const STAGE_ENEMY_COUNTS: Dictionary = {
	1: {"melee": 3, "range": 1},
	2: {"melee": 4, "range": 1},
	3: {"melee": 5, "range": 2},
}

# How many melee/ranged enemies a reinforcement wave spawns - battle.gd's
# _spawn_reinforcements(), triggered every REINFORCEMENT_INTERVAL turns
# the current stage/fight is still going. Deliberately smaller than that
# same stage's own STAGE_ENEMY_COUNTS above (a late top-up, not a second
# full wave), but built the same way - see _build_stage_enemy_def() -
# using whichever stage is CURRENTLY loaded when reinforcements arrive,
# so they come in scaled to match everything else already on the field.
const REINFORCEMENT_ENEMY_COUNTS: Dictionary = {
	1: {"melee": 2, "range": 1},
	2: {"melee": 2, "range": 2},
	3: {"melee": 3, "range": 2},
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


func get_reinforcement_enemy_counts(stage: int) -> Dictionary:
	return REINFORCEMENT_ENEMY_COUNTS.get(stage, REINFORCEMENT_ENEMY_COUNTS[1])


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

	"the_veiled_reach": {
		"name": "The Veiled Reach",
		"description": "A frozen land hidden beneath an eternal winter.",
		"music": "the_veiled_reach",
		"heroes": [],
		"unlocked": true,
		"background": ""
	},

	"the_iron_abyss": {
		"name": "The Iron Abyss",
		"description": "The Iron Abyss is a vast prison buried within the deepest reaches of the ocean, its labyrinthine corridors sealed behind layers of iron and ancient machinery.  
		Built into a bottomless trench, the prison was created to contain creatures too violent, cunning, or unnatural to ever walk the surface again. Its flooded cells hold killers, raiders, and things that no longer resemble the beings they once were.  
		Few prisoners have ever escaped the Abyss. Fewer still survived the journey to the surface. Among them is a single fugitive whose name has become a whispered legend among the creatures of the deep.",
		"music": "the_iron_abyss",
		"heroes": [
			{
				"id": "veyrik",
				"name": "Veyrik",
				"image": "res://assets/heroes/Veyrik.png",
				"background": "res://assets/zones/the_iron_abyss.jpg",
				"range_type": "Melee",
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
						"id": "leeching_hunger",
						"name": "Leeching Hunger",
						"type": "standard",
						"description": "Veyrik awakens a ravenous hunger within himself. For several turns, his next melee attacks tear a fragment of the target's main attribute from them, weakening the victim and feeding Veyrik's strength.",
						"levels": [
							{"attacks": 2, "steal_per_hit": 1, "duration": 4, "mana_cost": 30, "cooldown": 3},
							{"attacks": 3, "steal_per_hit": 1, "duration": 4, "mana_cost": 35, "cooldown": 3},
							{"attacks": 3, "steal_per_hit": 1, "duration": 5, "mana_cost": 40, "cooldown": 3},
							{"attacks": 4, "steal_per_hit": 1, "duration": 6, "mana_cost": 45, "cooldown": 3}
						]
					},
					{
						"id": "abyssal_spasm",
						"name": "Abyssal Spasm",
						"type": "standard",
						"description": "Veyrik violently convulses, releasing a burst of unnatural force around himself. Enemies caught within it suffer damage and are silenced.",
						"levels": [
							{"damage_multiplier": 0.75, "radius": 0, "mana_cost": 65, "cooldown": 4},
							{"damage_multiplier": 1.0, "radius": 0, "mana_cost": 70, "cooldown": 4},
							{"damage_multiplier": 1.25, "radius": 0, "mana_cost": 75, "cooldown": 3},
							{"damage_multiplier": 1.5, "radius": 1, "mana_cost": 80, "cooldown": 3}
						]
					},
					{
						"id": "barbed_lunge",
						"name": "Barbed Lunge",
						"type": "standard",
						"description": "Veyrik launches himself forward with violent speed, impaling the first enemy hero he reaches and leaving them stunned.",
						"levels": [
							{"distance": 2, "stun_turns": 1, "mana_cost": 75, "cooldown": 5},
							{"distance": 3, "stun_turns": 1, "mana_cost": 80, "cooldown": 5},
							{"distance": 3, "stun_turns": 2, "mana_cost": 90, "cooldown": 4},
							{"distance": 4, "stun_turns": 2, "mana_cost": 100, "cooldown": 4}
						]
					},
					{
						"id": "depthsveil",
						"name": "Depthsveil",
						"type": "ultimate",
						"description": "Ultimate: Veyrik slips beneath a veil of unnatural darkness, becoming invisible and untouchable. His next attack while concealed tears into his victim with increased force and ends the veil early. If he does not attack, the effect eventually fades.",
						"levels": [
							{"duration": 2, "bonus_damage": 20, "mana_cost": 80, "cooldown": 8},
							{"duration": 3, "bonus_damage": 35, "mana_cost": 90, "cooldown": 7},
							{"duration": 4, "bonus_damage": 50, "mana_cost": 100, "cooldown": 6}
						]
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
				"id": "the_iron_abyss_melee",
				"name": "Iron Abyss melee creep",
				"image": "res://assets/enemies/Dark_Reef_mele.png",
				"type": "melee",
				"main_stat": "strength",
				"main_stat_value": 10,
				"hp": 150,
				"mana": 50,
				"damage": 10,
				"speed": 1,
				"armor": 1.5,
				"XP": 57,
				"gold": "34-39"
			},
			{
				"id": "the_iron_abyss_melee_2",
				"name": "Iron Abyss melee creep",
				"image": "res://assets/enemies/Dark_Reef_mele.png",
				"type": "melee",
				"main_stat": "strength",
				"main_stat_value": 10,
				"hp": 150,
				"mana": 50,
				"damage": 10,
				"speed": 1,
				"armor": 1.5,
				"XP": 57,
				"gold": "34-39"
			},
			{
				"id": "the_iron_abyss_range",
				"name": "Iron Abyss range creep",
				"image": "res://assets/enemies/Dark_Reef_range.png",
				"type": "range",
				"main_stat": "agility",
				"main_stat_value": 10,
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
		"background": "res://assets/zones/the_iron_abyss.jpg",
		"battle_background": "res://assets/battle_areas/the_iron_abyss_area.png"
	},

	"the_elderwild": {
		"name": "The Elderwild",
		"description": "The Elderwild is an ancient forest hidden beyond the northern reaches, where towering pines blot out the sky and the light rarely reaches the forest floor. No kingdom claims the land, and few travelers willingly venture beyond its outer paths.  
		Deep within the woods, the boundary between nature and something far older begins to fade. Those who enter the Elderwild often speak of hearing movement between the trees, even when nothing is there. Some claim the forest watches them. Others never return to tell their story.",
		"music": "the_elderwild",
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
						"description": "Summons a Spirit Bear that fights alongside Sylla until it's killed - it acts automatically every turn, attacking any enemy sharing its column or closing in on the nearest one otherwise. If the bear dies, Sylla loses 20% of his max HP (never enough to knock him out on its own). Recasting replaces the current bear with a fresh one at the skill's current level.",
						"levels": [
							{"hp": 300, "damage_min": 25, "damage_max": 30, "armor": 3.0, "speed": 1, "mana_cost": 80, "cooldown": 8},
							{"hp": 400, "damage_min": 32, "damage_max": 38, "armor": 4.0, "speed": 1, "mana_cost": 90, "cooldown": 7},
							{"hp": 525, "damage_min": 40, "damage_max": 47, "armor": 5.5, "speed": 1, "mana_cost": 100, "cooldown": 6},
							{"hp": 675, "damage_min": 50, "damage_max": 58, "armor": 7.0, "speed": 2, "mana_cost": 110, "cooldown": 5}
						]
					},
					{
						"id": "entangle",
						"name": "Entangle",
						"type": "standard",
						"description": "Roots a targeted enemy in place - it can't move (though it can still attack if something is in range), and it's silenced so it can't cast skills while rooted. Also deals damage over time for the rooted duration.",
						"levels": [
							{"root_turns": 1, "silence_turns": 1, "dot_damage": 15, "dot_duration": 2, "mana_cost": 50, "cooldown": 3},
							{"root_turns": 1, "silence_turns": 1, "dot_damage": 25, "dot_duration": 2, "mana_cost": 55, "cooldown": 3},
							{"root_turns": 2, "silence_turns": 2, "dot_damage": 30, "dot_duration": 3, "mana_cost": 60, "cooldown": 4},
							{"root_turns": 2, "silence_turns": 2, "dot_damage": 50, "dot_duration": 3, "mana_cost": 65, "cooldown": 4}
						]
					},
					{
						"id": "spirit_link",
						"name": "Spirit Link",
						"type": "standard",
						"description": "The druid gains bonus armor and lifesteal for the duration - lifesteal converts a percentage of Attack damage into HP after the target's armor has reduced it. Only Attacks trigger it; skill damage never does.",
						"levels": [
							{"lifesteal_pct": 0.05, "bonus_armor": 2, "duration": 3, "mana_cost": 50, "cooldown": 5},
							{"lifesteal_pct": 0.08, "bonus_armor": 3, "duration": 3, "mana_cost": 55, "cooldown": 5},
							{"lifesteal_pct": 0.11, "bonus_armor": 4, "duration": 4, "mana_cost": 60, "cooldown": 4},
							{"lifesteal_pct": 0.14, "bonus_armor": 5, "duration": 4, "mana_cost": 65, "cooldown": 4}
						]
					},
					{
						"id": "savage_roar",
						"name": "Savage Roar",
						"type": "passive",
						"description": "Passive: while the druid's HP is below 50%, he and his spirit bear move extra columns and take reduced damage. Wears off once his HP climbs back to 80% or higher.",
						"levels": [
							{"bonus_movement": 1, "damage_reduction_pct": 0.05},
							{"bonus_movement": 1, "damage_reduction_pct": 0.10},
							{"bonus_movement": 2, "damage_reduction_pct": 0.15},
							{"bonus_movement": 2, "damage_reduction_pct": 0.20}
						]
					},
					{
						"id": "true_form",
						"name": "True Form",
						"type": "ultimate",
						"description": "Ultimate: the druid morphs into a raging bear for the duration, gaining bonus HP (added immediately, then taken back off when it ends) and bonus damage - but he fights at melee range for as long as the transformation lasts, whatever his normal range.",
						"levels": [
							{"bonus_hp": 150, "bonus_damage": 15, "duration": 4, "mana_cost": 100, "cooldown": 10},
							{"bonus_hp": 250, "bonus_damage": 25, "duration": 5, "mana_cost": 110, "cooldown": 9},
							{"bonus_hp": 350, "bonus_damage": 35, "duration": 6, "mana_cost": 120, "cooldown": 8}
						]
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
				"id": "the_elderwild_melee",
				"name": "Elderwild melee creep",
				"image": "res://assets/enemies/Northern_Pine_mele.png",
				"type": "melee",
				"main_stat": "strength",
				"main_stat_value": 10,
				"hp": 150,
				"mana": 50,
				"damage": 10,
				"speed": 1,
				"armor": 1.5,
				"XP": 57,
				"gold": "34-39"
			},
			{
				"id": "the_elderwild_melee_2",
				"name": "Elderwild melee creep",
				"image": "res://assets/enemies/Northern_Pine_mele.png",
				"type": "melee",
				"main_stat": "strength",
				"main_stat_value": 10,
				"hp": 150,
				"mana": 50,
				"damage": 10,
				"speed": 1,
				"armor": 1.5,
				"XP": 57,
				"gold": "34-39"
			},
			{
				"id": "the_elderwild_range",
				"name": "Elderwild range creep",
				"image": "res://assets/enemies/Northern_Pine_range.png",
				"type": "range",
				"main_stat": "agility",
				"main_stat_value": 10,
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

	"kingdom_of_morvain": {
		"name": "Kingdom of Morvain",
		"description": "The Kingdom of Morvain was once a prosperous realm, hidden beneath a veil of unnatural mist that slowly crept in from the surrounding valleys. As the years passed, the mist grew thicker, and so did the ambitions of the kingdom's rulers.
		The last king became obsessed with the strange power within the mist, believing it could grant him dominion over life and death. His pursuit of forbidden magic consumed the royal court, leaving the kingdom fractured by madness, betrayal, and bloodshed.
		Now Morvain is a forsaken kingdom, its ruined halls and forgotten villages swallowed by the mist. Those who still wander its roads speak of figures moving within the fog and voices calling from places where no living soul should remain.
		Deep within the heart of Morvain, the mist has taken on a will of its own. Some say it remembers the kingdom that created it. Others believe the kingdom was never its master to begin with.",
		"music": "kingdom_of_morvain",
		"heroes": [
			{
				"id": "аbaddon",
				"name": "Abaddon",
				"image": "res://assets/heroes/Abaddon.png",
				"background": "res://assets/zones/Avarice.png",
				"range_type": "Melee",
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
						"description": "Abaddon releases a coil of deathly mist - cast on an enemy it deals damage, cast on Abaddon himself it costs HP but heals him for more.",
						"levels": [
							{"heal": 80, "damage": 80, "hp_cost": 30, "mana_cost": 35, "cooldown": 3},
							{"heal": 120, "damage": 120, "hp_cost": 40, "mana_cost": 40, "cooldown": 3},
							{"heal": 160, "damage": 160, "hp_cost": 50, "mana_cost": 45, "cooldown": 2},
							{"heal": 200, "damage": 200, "hp_cost": 60, "mana_cost": 50, "cooldown": 2}
						]
					},
					{
						"id": "aphotic_shield",
						"name": "Aphotic Shield",
						"type": "standard",
						"description": "Creates a shield that absorbs damage in Abaddon's place until it either wears off or is broken, dispelling every negative effect on him. If it's broken by damage, it explodes, damaging nearby enemies.",
						"levels": [
							{"shield_hp": 100, "aoe_damage": 50, "radius": 0, "duration": 3, "mana_cost": 50, "cooldown": 5},
							{"shield_hp": 150, "aoe_damage": 75, "radius": 0, "duration": 3, "mana_cost": 55, "cooldown": 5},
							{"shield_hp": 200, "aoe_damage": 100, "radius": 1, "duration": 4, "mana_cost": 60, "cooldown": 4},
							{"shield_hp": 250, "aoe_damage": 125, "radius": 1, "duration": 4, "mana_cost": 65, "cooldown": 4}
						]
					},
					{
						"id": "curse_of_avernus",
						"name": "Curse of Avernus",
						"type": "passive",
						"description": "Passive: Abaddon's attacks stack a curse onto their target. Once enough stacks land, the target is cursed - silenced and taking damage over time. Stacks are lost if the target goes 3 turns without being hit.",
						"levels": [
							{"hits_to_activate": 3, "silence_turns": 1, "dot_damage": 5, "dot_duration": 2},
							{"hits_to_activate": 3, "silence_turns": 1, "dot_damage": 10, "dot_duration": 2},
							{"hits_to_activate": 2, "silence_turns": 2, "dot_damage": 10, "dot_duration": 3},
							{"hits_to_activate": 2, "silence_turns": 2, "dot_damage": 15, "dot_duration": 3}
						]
					},
					{
						"id": "borrowed_time",
						"name": "Borrowed Time",
						"type": "ultimate",
						"auto_activate": true,
						"description": "Ultimate: Not cast - automatically activates once Abaddon's HP falls to this level's threshold. While active, every attack that would damage him heals him instead.",
						"levels": [
							{"auto_activate_hp_pct": 0.3, "duration": 3, "heal_conversion_pct": 1.0, "mana_cost": 0, "cooldown": 10},
							{"auto_activate_hp_pct": 0.3, "duration": 4, "heal_conversion_pct": 1.0, "mana_cost": 0, "cooldown": 9},
							{"auto_activate_hp_pct": 0.3, "duration": 5, "heal_conversion_pct": 1.0, "mana_cost": 0, "cooldown": 8}
						]
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
				"id": "kingdom_of_morvain_melee",
				"name": "Kingdom of Morvain melee creep",
				"image": "res://assets/enemies/Avarice_mele.png",
				"type": "melee",
				"main_stat": "strength",
				"main_stat_value": 10,
				"hp": 150,
				"mana": 50,
				"damage": 10,
				"speed": 1,
				"armor": 1.5,
				"XP": 57,
				"gold": "34-39"
			},
			{
				"id": "kingdom_of_morvain_melee_2",
				"name": "Kingdom of Morvain melee creep",
				"image": "res://assets/enemies/Avarice_mele.png",
				"type": "melee",
				"main_stat": "strength",
				"main_stat_value": 10,
				"hp": 150,
				"mana": 50,
				"damage": 10,
				"speed": 1,
				"armor": 1.5,
				"XP": 57,
				"gold": "34-39"
			},
			{
				"id": "kingdom_of_morvain_range",
				"name": "Kingdom of Morvain range creep",
				"image": "res://assets/enemies/Avarice_range.png",
				"type": "range",
				"main_stat": "agility",
				"main_stat_value": 10,
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

	"the_ironbound_isles": {
		"name": "The Ironbound Isles",
		"description": "The Ironbound Isles are a rugged chain of islands surrounded by treacherous seas, where iron and salt have shaped the lives of their people for generations. Their shipyards and forges produce some of the finest steel in the known world, while their formidable fleet guards the narrow waters between the islands.
		For centuries, the islanders believed the open sea belonged to them. That belief ended when something ancient began rising from the depths. Ships vanished without a trace, coastal settlements were found abandoned, and survivors spoke of shapes moving beneath the waves.
		The islands endured, but their people were changed by the horrors they witnessed. Their once-proud navy now patrols waters that few sailors willingly cross, armed not only against rival kingdoms, but against whatever waits beneath the black surface.",
		"music": "the_ironbound_isles",
		"heroes": [
			{
				"id": "kunkka",
				"name": "Kunkka",
				"image": "res://assets/heroes/Kunkka.png",
				"background": "res://assets/zones/Cladd_Isles.png",
				"range_type": "Melee",
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
						"description": "Summons a column of rising water at range, damaging and stunning the target. At its max level, the torrent also splashes nearby enemies for damage.",
						"levels": [
							{"damage": 60, "stun_turns": 1, "range": 3, "radius": 0, "mana_cost": 50, "cooldown": 5},
							{"damage": 90, "stun_turns": 1, "range": 3, "radius": 0, "mana_cost": 55, "cooldown": 5},
							{"damage": 120, "stun_turns": 2, "range": 3, "radius": 0, "mana_cost": 65, "cooldown": 4},
							{"damage": 150, "stun_turns": 2, "range": 3, "radius": 1, "mana_cost": 75, "cooldown": 4}
						]
					},
					{
						"id": "tidebringer",
						"name": "Tidebringer",
						"type": "passive",
						"description": "Passive: every few Attacks, Kunkka's sword strike hits harder and cleaves nearby enemies for a percentage of that attack's total damage.",
						"levels": [
							{"hits_to_activate": 3, "bonus_damage": 15, "cleave_columns": 1, "cleave_damage_pct": 0.5},
							{"hits_to_activate": 3, "bonus_damage": 25, "cleave_columns": 1, "cleave_damage_pct": 0.6},
							{"hits_to_activate": 2, "bonus_damage": 35, "cleave_columns": 1, "cleave_damage_pct": 0.7},
							{"hits_to_activate": 2, "bonus_damage": 45, "cleave_columns": 2, "cleave_damage_pct": 0.75}
						]
					},
					{
						"id": "x_marks_the_spot",
						"name": "X Marks the Spot",
						"type": "standard",
						"description": "Marks an enemy at range. On Kunkka's next turn he teleports onto wherever that enemy is by then, for free - it doesn't cost him his turn, and the teleport itself deals no damage.",
						"levels": [
							{"range": 2, "mana_cost": 40, "cooldown": 5},
							{"range": 3, "mana_cost": 45, "cooldown": 5},
							{"range": 4, "mana_cost": 50, "cooldown": 4},
							{"range": 5, "mana_cost": 55, "cooldown": 4}
						]
					},
					{
						"id": "ghostship",
						"name": "Ghostship",
						"type": "ultimate",
						"description": "Ultimate: marks a target at range, then sails a phantom ship from Kunkka straight to it, damaging every enemy caught in its path.",
						"levels": [
							{"damage": 200, "range": 4, "mana_cost": 100, "cooldown": 10},
							{"damage": 300, "range": 5, "mana_cost": 110, "cooldown": 9},
							{"damage": 400, "range": 6, "mana_cost": 120, "cooldown": 8}
						]
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
				"id": "the_ironbound_isles_melee",
				"name": "Ironbound Isles melee creep",
				"image": "res://assets/enemies/Cladd Isles_mele.png",
				"type": "melee",
				"main_stat": "strength",
				"main_stat_value": 10,
				"hp": 150,
				"mana": 50,
				"damage": 10,
				"speed": 1,
				"armor": 1.5,
				"XP": 57,
				"gold": "34-39"
			},
			{
				"id": "the_ironbound_isles_melee_2",
				"name": "Ironbound Isles melee creep",
				"image": "res://assets/enemies/Cladd Isles_mele.png",
				"type": "melee",
				"main_stat": "strength",
				"main_stat_value": 10,
				"hp": 150,
				"mana": 50,
				"damage": 10,
				"speed": 1,
				"armor": 1.5,
				"XP": 57,
				"gold": "34-39"
			},
			{
				"id": "the_ironbound_isles_range",
				"name": "Ironbound Isles range creep",
				"image": "res://assets/enemies/Cladd Isles_range.png",
				"type": "range",
				"main_stat": "agility",
				"main_stat_value": 10,
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

	"frostspire": {
		"name": "Frostspire",
		"description": "Frostspire is a vast frozen region where towering mountains and ancient glaciers rise beyond the reach of the sun. Jagged peaks of blue-white ice stretch across the horizon, while deep crevasses disappear beneath layers of snow that have remained untouched for centuries.
		The oldest parts of Frostspire are said to contain ice far older than any known kingdom. Within its frozen depths lie traces of something that existed long before the region became a land of eternal winter.",
		"music": "frostspire",
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
						"description": "Casts a freezing curse on an enemy at range, dealing damage over time for the duration.",
						"levels": [
							{"damage": 15, "duration": 3, "range": 2, "mana_cost": 40, "cooldown": 4},
							{"damage": 25, "duration": 3, "range": 3, "mana_cost": 45, "cooldown": 4},
							{"damage": 35, "duration": 4, "range": 3, "mana_cost": 50, "cooldown": 3},
							{"damage": 45, "duration": 4, "range": 4, "mana_cost": 55, "cooldown": 3}
						]
					},
					{
						"id": "ice_vortex",
						"name": "Ice Vortex",
						"type": "standard",
						"description": "Casts a freezing vortex at a fixed range, dealing damage over time to every enemy caught within its radius.",
						"levels": [
							{"damage": 15, "radius": 1, "duration": 3, "mana_cost": 40, "cooldown": 5},
							{"damage": 25, "radius": 1, "duration": 3, "mana_cost": 45, "cooldown": 5},
							{"damage": 35, "radius": 1, "duration": 4, "mana_cost": 50, "cooldown": 4},
							{"damage": 45, "radius": 2, "duration": 4, "mana_cost": 55, "cooldown": 4}
						]
					},
					{
						"id": "chilling_touch",
						"name": "Chilling Touch",
						"type": "standard",
						"description": "Blasts an enemy within normal attack range for the hero's own attack damage plus a flat bonus.",
						"levels": [
							{"bonus_damage": 80, "mana_cost": 50, "cooldown": 6},
							{"bonus_damage": 120, "mana_cost": 55, "cooldown": 6},
							{"bonus_damage": 160, "mana_cost": 60, "cooldown": 5},
							{"bonus_damage": 200, "mana_cost": 65, "cooldown": 5}
						]
					},
					{
						"id": "ice_blast",
						"name": "Ice Blast",
						"type": "ultimate",
						"description": "Ultimate: targets any enemy on the field, dealing damage to it and every enemy around it, then damage over time for the duration. Any enemy hit has a percentage of its max HP reserved for that same duration - if its HP ever drops to or below that reserved amount, it dies outright.",
						"levels": [
							{"damage": 150, "dot_damage": 20, "dot_duration": 3, "stun_turns": 1, "execute_pct": 0.20, "radius": 1, "mana_cost": 100, "cooldown": 10},
							{"damage": 225, "dot_damage": 30, "dot_duration": 3, "stun_turns": 1, "execute_pct": 0.25, "radius": 1, "mana_cost": 110, "cooldown": 9},
							{"damage": 300, "dot_damage": 40, "dot_duration": 4, "stun_turns": 2, "execute_pct": 0.30, "radius": 2, "mana_cost": 120, "cooldown": 8}
						]
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
						"description": "Grants bonus attack damage and range for a number of Attacks, or until the effect's own duration runs out - whichever comes first.",
						"levels": [
							{"bonus_damage": 30, "bonus_range": 2, "attacks": 2, "duration": 3, "mana_cost": 40, "cooldown": 5},
							{"bonus_damage": 50, "bonus_range": 2, "attacks": 3, "duration": 3, "mana_cost": 50, "cooldown": 5},
							{"bonus_damage": 70, "bonus_range": 3, "attacks": 3, "duration": 4, "mana_cost": 60, "cooldown": 4},
							{"bonus_damage": 90, "bonus_range": 3, "attacks": 4, "duration": 4, "mana_cost": 70, "cooldown": 4}
						]
					},
					{
						"id": "splinter_blast",
						"name": "Splinter Blast",
						"type": "standard",
						"description": "Launches a floating ball of ice at an enemy within normal attack range, dealing damage to it - every other enemy within a splinter range of it takes separate, lighter splinter damage.",
						"levels": [
							{"damage": 100, "splinter_damage": 60, "splinter_range": 1, "mana_cost": 50, "cooldown": 5},
							{"damage": 150, "splinter_damage": 90, "splinter_range": 1, "mana_cost": 55, "cooldown": 5},
							{"damage": 200, "splinter_damage": 120, "splinter_range": 1, "mana_cost": 60, "cooldown": 4},
							{"damage": 250, "splinter_damage": 150, "splinter_range": 2, "mana_cost": 65, "cooldown": 4}
						]
					},
					{
						"id": "cold_embrace",
						"name": "Cold Embrace",
						"type": "standard",
						"description": "Encases the hero in ice, becoming immune to all damage and healing every turn for the duration - but unable to move or attack while it lasts. Casting it clears every other effect currently on the hero, good or bad.",
						"levels": [
							{"heal": 75, "duration": 2, "mana_cost": 50, "cooldown": 6},
							{"heal": 110, "duration": 2, "mana_cost": 55, "cooldown": 6},
							{"heal": 135, "duration": 3, "mana_cost": 60, "cooldown": 5},
							{"heal": 180, "duration": 3, "mana_cost": 65, "cooldown": 5}
						]
					},
					{
						"id": "winter's_curse",
						"name": "Winter's Curse",
						"type": "ultimate",
						"description": "Ultimate: Freezes an enemy within normal attack range in place for the duration. Every OTHER enemy within curse_range columns of it ignores the hero for as long as the freeze holds, piling onto the frozen target instead - moving toward it or attacking it for bonus damage - while anything outside that range keeps targeting the hero as normal. The hero's own damage against the frozen target isn't boosted.",
						"levels": [
							{"duration": 2, "curse_range": 2, "bonus_damage_pct": 0.10, "mana_cost": 100, "cooldown": 10},
							{"duration": 3, "curse_range": 2, "bonus_damage_pct": 0.15, "mana_cost": 110, "cooldown": 9},
							{"duration": 4, "curse_range": 3, "bonus_damage_pct": 0.20, "mana_cost": 120, "cooldown": 8}
						]
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
				"id": "frostspire_melee",
				"name": "Frostspire melee creep",
				"image": "res://assets/enemies/white_spire_mele.png",
				"type": "melee",
				"main_stat": "strength",
				"main_stat_value": 10,
				"hp": 150,
				"mana": 50,
				"damage": 10,
				"speed": 1,
				"armor": 1.5,
				"XP": 57,
				"gold": "34-39"
			},
			{
				"id": "frostspire_melee_2",
				"name": "Frostspire melee creep",
				"image": "res://assets/enemies/white_spire_mele.png",
				"type": "melee",
				"main_stat": "strength",
				"main_stat_value": 10,
				"hp": 150,
				"mana": 50,
				"damage": 10,
				"speed": 1,
				"armor": 1.5,
				"XP": 57,
				"gold": "34-39"
			},
			{
				"id": "frostspire_range",
				"name": "Frostspire range creep",
				"image": "res://assets/enemies/white_spire_range.png",
				"type": "range",
				"main_stat": "agility",
				"main_stat_value": 10,
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

	"the_everfrost": {
		"name": "The Everfrost",
		"description": "The Everfrost is a vast land locked in an endless winter, where snow and ice cover the mountains, forests, and valleys beneath a sky that rarely clears.
		Hardy tribes have survived in the region for generations, adapting to a land where warmth and food are scarce. Each tribe carries its own traditions, but all share a deep respect for the ancient forces that rule the frozen wilderness.",
		"music": "the_everfrost",
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
						"description": "A freezing blast cast on an enemy within normal attack range, dealing damage to it - at later levels, every other enemy within its own radius of the target takes that same damage too.",
						"levels": [
							{"damage": 100, "radius": 0, "mana_cost": 70, "cooldown": 3},
							{"damage": 160, "radius": 0, "mana_cost": 100, "cooldown": 3},
							{"damage": 230, "radius": 1, "mana_cost": 135, "cooldown": 4},
							{"damage": 310, "radius": 2, "mana_cost": 170, "cooldown": 4}
						]
					},
					{
						"id": "frostbite",
						"name": "Frostbite",
						"type": "standard",
						"description": "Locks an enemy within normal attack range in ice, stunning it for the duration and dealing damage over time on top.",
						"levels": [
							{"stun_turns": 1, "dot_damage": 30, "dot_duration": 2, "mana_cost": 80, "cooldown": 4},
							{"stun_turns": 1, "dot_damage": 55, "dot_duration": 2, "mana_cost": 110, "cooldown": 4},
							{"stun_turns": 2, "dot_damage": 70, "dot_duration": 3, "mana_cost": 145, "cooldown": 5},
							{"stun_turns": 2, "dot_damage": 90, "dot_duration": 4, "mana_cost": 180, "cooldown": 5}
						]
					},
					{
						"id": "arcane_aura",
						"name": "Arcane Aura",
						"type": "passive",
						"description": "Passive: adds a flat bonus to the hero's own passive mana regeneration every turn.",
						"levels": [
							{"bonus_mana_regen": 1},
							{"bonus_mana_regen": 2},
							{"bonus_mana_regen": 3},
							{"bonus_mana_regen": 4}
						]
					},
					{
						"id": "freezing_field",
						"name": "Freezing Field",
						"type": "ultimate",
						"description": "Ultimate: cast on herself, dealing damage to every enemy within a radius of her own position at the start of each turn for the duration.",
						"levels": [
							{"damage": 90, "duration": 3, "radius": 2, "mana_cost": 200, "cooldown": 8},
							{"damage": 130, "duration": 3, "radius": 2, "mana_cost": 260, "cooldown": 9},
							{"damage": 185, "duration": 4, "radius": 3, "mana_cost": 330, "cooldown": 10}
						]
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
				"range_type": "Melee",
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
						"description": "Launches a ball of frozen energy at an enemy within range, dealing damage to it and freezing a line of columns - starting on Tusk's own column and continuing toward the target - for the duration. Enemies already inside a frozen column can't move at all, and none can move into one; they can still attack in range, cast skills, and use items.",
						"levels": [
							{"damage": 70, "blocked_columns": 2, "duration": 2, "range": 4, "mana_cost": 70, "cooldown": 4},
							{"damage": 110, "blocked_columns": 3, "duration": 2, "range": 4, "mana_cost": 95, "cooldown": 4},
							{"damage": 150, "blocked_columns": 3, "duration": 3, "range": 4, "mana_cost": 120, "cooldown": 5},
							{"damage": 200, "blocked_columns": 4, "duration": 3, "range": 4, "mana_cost": 150, "cooldown": 5}
						]
					},
					{
						"id": "snowball",
						"name": "Snowball",
						"type": "standard",
						"description": "Rolls into a snowball and charges an enemy within range, dealing damage and stunning it on impact.",
						"levels": [
							{"damage": 85, "stun_turns": 1, "range": 2, "mana_cost": 90, "cooldown": 5},
							{"damage": 130, "stun_turns": 1, "range": 3, "mana_cost": 115, "cooldown": 5},
							{"damage": 175, "stun_turns": 2, "range": 3, "mana_cost": 145, "cooldown": 6},
							{"damage": 230, "stun_turns": 2, "range": 4, "mana_cost": 175, "cooldown": 6}
						]
					},
					{
						"id": "tag_team",
						"name": "Tag Team",
						"type": "standard",
						"description": "Adds bonus damage to the hero's own Attacks for the duration.",
						"levels": [
							{"bonus_damage": 30, "duration": 3, "mana_cost": 60, "cooldown": 5},
							{"bonus_damage": 50, "duration": 3, "mana_cost": 80, "cooldown": 5},
							{"bonus_damage": 75, "duration": 4, "mana_cost": 105, "cooldown": 6},
							{"bonus_damage": 105, "duration": 4, "mana_cost": 130, "cooldown": 6}
						]
					},
					{
						"id": "walrus_punch",
						"name": "Walrus Punch",
						"type": "ultimate",
						"description": "Ultimate: a critical-strike punch on an enemy at melee range, dealing a multiple of the hero's own Attack damage and knocking it back. If the knockback is cut short by the edge of the board or another enemy in the way, it takes 50% bonus damage on top for slamming into it - then it's stunned in place either way.",
						"levels": [
							{"damage_multiplier": 2.0, "knockback": 2, "stun_turns": 1, "mana_cost": 150, "cooldown": 8},
							{"damage_multiplier": 2.5, "knockback": 3, "stun_turns": 1, "mana_cost": 200, "cooldown": 9},
							{"damage_multiplier": 3.0, "knockback": 4, "stun_turns": 2, "mana_cost": 250, "cooldown": 10}
						]
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
				"id": "the_everfrost_melee",
				"name": "Everfrost melee creep",
				"image": "res://assets/enemies/Frozen_Realm_mele.png",
				"type": "melee",
				"main_stat": "strength",
				"main_stat_value": 10,
				"hp": 150,
				"mana": 50,
				"damage": 10,
				"speed": 1,
				"armor": 1.5,
				"XP": 57,
				"gold": "34-39"
			},
			{
				"id": "the_everfrost_melee_2",
				"name": "Everfrost melee creep",
				"image": "res://assets/enemies/Frozen_Realm_mele.png",
				"type": "melee",
				"main_stat": "strength",
				"main_stat_value": 10,
				"hp": 150,
				"mana": 50,
				"damage": 10,
				"speed": 1,
				"armor": 1.5,
				"XP": 57,
				"gold": "34-39"
			},
			{
				"id": "the_everfrost_range",
				"name": "Everfrost range creep",
				"image": "res://assets/enemies/Frozen_Realm_range.png",
				"type": "range",
				"main_stat": "agility",
				"main_stat_value": 10,
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

	"the_verdant_scar": {
		"name": "The Verdant Scar",
		"description": "The Verdant Scar is a remote valley where nature and ruin have grown together into something neither entirely alive nor truly dead. Once home to the prosperous city of Augury Bay, the region was transformed when its inhabitants uncovered an ancient source of energy buried deep within the surrounding mountains.
		The energy promised limitless power, but its influence reached far beyond machinery. Plants grew with unnatural speed, animals changed in disturbing ways, and living things exposed to it began to develop strange and unpredictable traits.
		Over the years the city lost the battle against the nature, its towers and machines swallowed beneath roots, vines, and centuries of unchecked growth.
		Today, the ruins lie scattered beneath an enormous living wilderness. The ancient energy still pulses somewhere beneath the mountains, slowly changing everything that grows near it.",
		"music": "the_verdant_scar",
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
						"description": "Turns the hero invisible - enemies can't target or chase him while it holds, and he moves 2 columns per move instead of 1. Ends early the moment he attacks or casts another skill; attacking from stealth also roots the target in place (it can still do everything else).",
						"levels": [
							{"duration": 3, "root_turns": 1, "mana_cost": 60, "cooldown": 5},
							{"duration": 3, "root_turns": 1, "mana_cost": 75, "cooldown": 5},
							{"duration": 4, "root_turns": 2, "mana_cost": 95, "cooldown": 6},
							{"duration": 4, "root_turns": 2, "mana_cost": 115, "cooldown": 6}
						]
					},
					{
						"id": "leech_seed",
						"name": "Leech Seed",
						"type": "standard",
						"description": "Plants a seed in an enemy within range, dealing damage over time for the duration - the hero heals for his own amount every one of those same turns.",
						"levels": [
							{"dot_damage": 25, "heal_per_turn": 15, "duration": 3, "range": 2, "mana_cost": 70, "cooldown": 5},
							{"dot_damage": 40, "heal_per_turn": 25, "duration": 3, "range": 2, "mana_cost": 90, "cooldown": 5},
							{"dot_damage": 55, "heal_per_turn": 35, "duration": 4, "range": 2, "mana_cost": 115, "cooldown": 6},
							{"dot_damage": 75, "heal_per_turn": 50, "duration": 4, "range": 2, "mana_cost": 145, "cooldown": 6}
						]
					},
					{
						"id": "living_armor",
						"name": "Living Armor",
						"type": "standard",
						"description": "Cast on himself, granting bonus armor and bonus HP regeneration every turn for the duration.",
						"levels": [
							{"bonus_armor": 3, "bonus_hp_regen": 2, "duration": 4, "mana_cost": 60, "cooldown": 5},
							{"bonus_armor": 5, "bonus_hp_regen": 3, "duration": 5, "mana_cost": 80, "cooldown": 5},
							{"bonus_armor": 7, "bonus_hp_regen": 4, "duration": 6, "mana_cost": 100, "cooldown": 6},
							{"bonus_armor": 9, "bonus_hp_regen": 5, "duration": 7, "mana_cost": 120, "cooldown": 6}
						]
					},
					{
						"id": "overgrowth",
						"name": "Overgrowth",
						"type": "ultimate",
						"description": "Ultimate: roots every enemy within radius of the hero in place - they can't move, but can still attack and cast skills - and deals damage over time to each of them for the same duration.",
						"levels": [
							{"dot_damage": 65, "root_duration": 2, "radius": 1, "mana_cost": 180, "cooldown": 9},
							{"dot_damage": 100, "root_duration": 3, "radius": 2, "mana_cost": 240, "cooldown": 10},
							{"dot_damage": 150, "root_duration": 3, "radius": 2, "mana_cost": 300, "cooldown": 11}
						]
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
				"range_type": "Melee",
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
						"description": "Deals damage around the hero, reducing enemy primary attributes if a hero is hit.",
						"levels": [
							{"damage": 100, "radius": 1, "mana_cost": 70, "cooldown": 4},
							{"damage": 150, "radius": 1, "mana_cost": 90, "cooldown": 4},
							{"damage": 200, "radius": 2, "mana_cost": 115, "cooldown": 5},
							{"damage": 260, "radius": 2, "mana_cost": 140, "cooldown": 5}
						]
					},
					{
						"id": "timber_chain",
						"name": "Timber Chain",
						"type": "standard",
						"description": "Marks an enemy within range and chains toward it, dealing damage to every enemy caught in the path and to the marked enemy itself.",
						"levels": [
							{"damage": 70, "range": 3, "mana_cost": 60, "cooldown": 4},
							{"damage": 95, "range": 3, "mana_cost": 80, "cooldown": 4},
							{"damage": 130, "range": 4, "mana_cost": 105, "cooldown": 5},
							{"damage": 185, "range": 5, "mana_cost": 130, "cooldown": 5}
						]
					},
					{
						"id": "reactive_armor",
						"name": "Reactive Armor",
						"type": "passive",
						"description": "Passive: every hit taken adds a stack of bonus armor and health regeneration, up to a max, each stack fading after its own duration.",
						"levels": [
							{"bonus_armor_per_stack": 0.8, "bonus_hp_regen_per_stack": 3, "max_stacks": 5, "duration": 4},
							{"bonus_armor_per_stack": 1.1, "bonus_hp_regen_per_stack": 4, "max_stacks": 6, "duration": 4},
							{"bonus_armor_per_stack": 1.4, "bonus_hp_regen_per_stack": 5, "max_stacks": 7, "duration": 5},
							{"bonus_armor_per_stack": 1.7, "bonus_hp_regen_per_stack": 6, "max_stacks": 8, "duration": 5}
						]
					},
					{
						"id": "chakram",
						"name": "Chakram",
						"type": "ultimate",
						"description": "Ultimate: marks a target within range, striking it and every enemy around it, then leaves the chakram planted there, dealing damage to everything in range of it each turn for the duration.",
						"levels": [
							{"cast_damage": 150, "damage_per_turn": 80, "duration": 2, "radius": 1, "range": 5, "mana_cost": 200, "cooldown": 10},
							{"cast_damage": 225, "damage_per_turn": 120, "duration": 3, "radius": 1, "range": 6, "mana_cost": 275, "cooldown": 11},
							{"cast_damage": 325, "damage_per_turn": 170, "duration": 3, "radius": 2, "range": 7, "mana_cost": 350, "cooldown": 12}
						]
					},
				],
				"level_up": {
					"strength": 3.5,
					"agility": 1.3,
					"intelligence": 2.7
				},
			},
		],
		"enemies": [
			{
				"id": "the_verdant_scar_melee",
				"name": "Verdant Scar melee creep",
				"image": "res://assets/enemies/vale_of_augury_mele.png",
				"type": "melee",
				"main_stat": "strength",
				"main_stat_value": 10,
				"hp": 150,
				"mana": 50,
				"damage": 10,
				"speed": 1,
				"armor": 1.5,
				"XP": 57,
				"gold": "34-39"
			},
			{
				"id": "the_verdant_scar_melee_2",
				"name": "Verdant Scar melee creep",
				"image": "res://assets/enemies/vale_of_augury_mele.png",
				"type": "melee",
				"main_stat": "strength",
				"main_stat_value": 10,
				"hp": 150,
				"mana": 50,
				"damage": 10,
				"speed": 1,
				"armor": 1.5,
				"XP": 57,
				"gold": "34-39"
			},
			{
				"id": "the_verdant_scar_range",
				"name": "Verdant Scar range creep",
				"image": "res://assets/enemies/vale_of_augury_range.png",
				"type": "range",
				"main_stat": "agility",
				"main_stat_value": 10,
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

	"the_sundered_peaks": {
		"name": "The Sundered Peaks",
		"description": "The Sundered Peaks are a remote mountain range scarred by an ancient event whose true nature has long since been forgotten. Jagged summits rise above deep valleys filled with ruined temples, abandoned fortresses, and monuments built by civilizations that vanished centuries ago.
		Hidden among the highest peaks are the remains of ancient orders that devoted generations to understanding the nature of existence itself. Their surviving writings speak of a forgotten force that once sundered reality, leaving behind echoes that still linger in the mountains.",
		"music": "the_sundered_peaks",
		"heroes": [],
		"unlocked": true,
		"background": ""
	},

	"the_fall_of_empyrean": {
		"name": "The Fall of Empyrean",
		"description": "The Fall of Empyrean is a vast region scarred by the remains of an ancient celestial civilization that once stood above the mortal world. Whatever Empyrean was, it did not simply vanish. Something brought it down.
		Enormous fragments of impossible architecture lie scattered across the land, half-buried in the earth and surrounded by strange crystalline formations.
		Broken structures still hum with an unfamiliar energy, while pieces of the fallen realm remain suspended in the air as if gravity itself has forgotten them.
		No surviving record explains what destroyed Empyrean. Some believe it was a war between celestial beings. Others claim the realm was punished for interfering with the mortal world.",
		"music": "the_fall_of_empyrean",
		"heroes": [],
		"unlocked": true,
		"background": ""
	},

	"drowned_empire": {
		"name": "Drowned Empire",
		"description": "The Drowned Empire lies far beneath the surface, where vast cities of pale stone and forgotten metal rise from the darkness of the deep. Once the heart of a powerful civilization, its towers, plazas, and temples now stand silent beneath the weight of the ocean.
		The empire's people built their cities around enormous vaults containing treasures, relics, and knowledge gathered over countless generations. When the empire fell, the sea claimed everything, sealing its secrets behind miles of dark water.
		Strange guardians still patrol the drowned streets, protecting places that have not been disturbed for centuries. Ancient creatures have made their homes among the ruins, while enormous shapes can sometimes be seen moving beyond the limits of the city's fading light.",
		"music": "drowned_empire",
		"heroes": [
			{
				"id": "naga_siren",
				"name": "Naga Siren",
				"image": "res://assets/heroes/Naga Siren.png",
				"background": "res://assets/zones/Sunken_Cities_Naga.png",
				"range_type": "Melee",
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
						"description": "Creates 3 illusions of herself in the columns in front of and behind her - each enemy attacking her has a chance to hit an illusion instead, and every turn all surviving illusions strike the same random enemy in her own attack range.",
						"levels": [
							{"illusions": 3, "hp_pct": 0.35, "damage_pct": 0.25, "hit_chance_pct": 0.20, "duration": 2, "mana_cost": 70, "cooldown": 5},
							{"illusions": 3, "hp_pct": 0.40, "damage_pct": 0.3, "hit_chance_pct": 0.25, "duration": 3, "mana_cost": 90, "cooldown": 5},
							{"illusions": 3, "hp_pct": 0.45, "damage_pct": 0.35, "hit_chance_pct": 0.35, "duration": 3, "mana_cost": 115, "cooldown": 6},
							{"illusions": 3, "hp_pct": 0.50, "damage_pct": 0.4, "hit_chance_pct": 0.45, "duration": 4, "mana_cost": 140, "cooldown": 6}
						]
					},
					{
						"id": "ensnare",
						"name": "Ensnare",
						"type": "standard",
						"description": "Nets an enemy within range, damaging it and rooting it in place - it can still attack and cast skills, just not move or jump.",
						"levels": [
							{"damage": 60, "range": 3, "root_turns": 1, "mana_cost": 60, "cooldown": 4},
							{"damage": 100, "range": 4, "root_turns": 2, "mana_cost": 80, "cooldown": 4},
							{"damage": 145, "range": 5, "root_turns": 2, "mana_cost": 105, "cooldown": 5},
							{"damage": 200, "range": 6, "root_turns": 3, "mana_cost": 130, "cooldown": 5}
						]
					},
					{
						"id": "rip_tide",
						"name": "Rip Tide",
						"type": "passive",
						"description": "Passive: her own Attacks splash AoE damage to nearby enemies, and boosts Mirror Image's illusions - more damage at every level, +1 turn of duration from level 3, and one extra illusion at level 4.",
						"levels": [
							{"aoe_damage_pct": 0.15, "radius": 1, "illusion_damage_bonus_pct": 0.02, "illusion_duration_bonus": 0, "extra_illusion": 0},
							{"aoe_damage_pct": 0.20, "radius": 1, "illusion_damage_bonus_pct": 0.03, "illusion_duration_bonus": 0, "extra_illusion": 0},
							{"aoe_damage_pct": 0.25, "radius": 1, "illusion_damage_bonus_pct": 0.04, "illusion_duration_bonus": 1, "extra_illusion": 0},
							{"aoe_damage_pct": 0.30, "radius": 1, "illusion_damage_bonus_pct": 0.05, "illusion_duration_bonus": 1, "extra_illusion": 1}
						]
					},
					{
						"id": "song_of_the_siren",
						"name": "Song of the Siren",
						"type": "ultimate",
						"description": "Ultimate: stuns every enemy within radius of Naga and reduces their armor for the stun's duration - she and her illusions can still move and attack normally while it holds.",
						"levels": [
							{"stun_turns": 3, "radius": 3, "armor_reduction": 5, "mana_cost": 200, "cooldown": 9},
							{"stun_turns": 3, "radius": 3, "armor_reduction": 8, "mana_cost": 260, "cooldown": 10},
							{"stun_turns": 4, "radius": 4, "armor_reduction": 12, "mana_cost": 330, "cooldown": 11}
						]
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
				"range_type": "Melee",
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
						"description": "Grants bonus movement for the duration - if an enemy is in the way when she moves, she stops on it and deals damage.",
						"levels": [
							{"bonus_movement": 1, "duration": 1, "charge_damage_pct": 0.40, "mana_cost": 50, "cooldown": 4},
							{"bonus_movement": 2, "duration": 2, "charge_damage_pct": 0.55, "mana_cost": 70, "cooldown": 4},
							{"bonus_movement": 2, "duration": 2, "charge_damage_pct": 0.70, "mana_cost": 90, "cooldown": 5},
							{"bonus_movement": 3, "duration": 3, "charge_damage_pct": 0.90, "mana_cost": 110, "cooldown": 5}
						]
					},
					{
						"id": "slithereen_crush",
						"name": "Slithereen Crush",
						"type": "standard",
						"description": "Slams the ground, damaging and stunning every enemy within radius of Slardar.",
						"levels": [
							{"damage": 90, "radius": 1, "stun_turns": 1, "mana_cost": 70, "cooldown": 4},
							{"damage": 140, "radius": 1, "stun_turns": 1, "mana_cost": 95, "cooldown": 4},
							{"damage": 200, "radius": 1, "stun_turns": 2, "mana_cost": 125, "cooldown": 5},
							{"damage": 270, "radius": 1, "stun_turns": 2, "mana_cost": 155, "cooldown": 5}
						]
					},
					{
						"id": "bash_of_the_deep",
						"name": "Bash of the Deep",
						"type": "passive",
						"description": "Passive: every few Attacks, the next one deals bonus damage and knocks the target back.",
						"levels": [
							{"attacks_required": 3, "bonus_damage_pct": 0.40, "knockback": 1},
							{"attacks_required": 3, "bonus_damage_pct": 0.60, "knockback": 1},
							{"attacks_required": 2, "bonus_damage_pct": 0.80, "knockback": 1},
							{"attacks_required": 2, "bonus_damage_pct": 1.00, "knockback": 1}
						]
					},
					{
						"id": "corrosive_haze",
						"name": "Corrosive Haze",
						"type": "ultimate",
						"description": "Ultimate: marks a target within range, reducing its armor and increasing the damage it takes from her own attacks and skills for the duration.",
						"levels": [
							{"armor_reduction": 6, "bonus_damage_pct": 0.10, "duration": 4, "range": 4, "mana_cost": 150, "cooldown": 8},
							{"armor_reduction": 9, "bonus_damage_pct": 0.15, "duration": 5, "range": 5, "mana_cost": 200, "cooldown": 9},
							{"armor_reduction": 12, "bonus_damage_pct": 0.20, "duration": 6, "range": 6, "mana_cost": 250, "cooldown": 10}
						]
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
				"id": "drowned_empire_melee",
				"name": "Drowned Empire melee creep",
				"image": "res://assets/enemies/Sunken Cities_mele.png",
				"type": "melee",
				"main_stat": "strength",
				"main_stat_value": 10,
				"hp": 150,
				"mana": 50,
				"damage": 10,
				"speed": 1,
				"armor": 1.5,
				"XP": 57,
				"gold": "34-39"
			},
			{
				"id": "drowned_empire_melee_2",
				"name": "Drowned Empire melee creep",
				"image": "res://assets/enemies/Sunken Cities_mele.png",
				"type": "melee",
				"main_stat": "strength",
				"main_stat_value": 10,
				"hp": 150,
				"mana": 50,
				"damage": 10,
				"speed": 1,
				"armor": 1.5,
				"XP": 57,
				"gold": "34-39"
			},
			{
				"id": "drowned_empire_range",
				"name": "Drowned Empire range",
				"image": "res://assets/enemies/Sunken Cities_range.png",
				"type": "range",
				"main_stat": "agility",
				"main_stat_value": 10,
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

	"the_blackbloom": {
		"name": "The Blackbloom",
		"description": "The Blackbloom is a vast forest where night has endured for centuries. The trees grow beneath a sky that never brightens, their twisted branches forming a canopy that hides the stars and keeps the forest floor in perpetual darkness.
		Long ago, something fell from the heavens and buried itself deep within the heart of the forest. No one knows what it was, but its arrival changed the land forever. Strange black flowers began to grow throughout the woods, blooming without sunlight and feeding on the unseen energy spreading through the soil.
		Ancient shrines and forgotten temples stand among the trees, remnants of a civilization that once worshipped the celestial object as a gift from the heavens. Their descendants still guard the deepest parts of the forest, convinced that the fallen relic is sacred and must never be disturbed.",
		"music": "the_blackbloom",
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
						"description": "Calls down meteors, dealing damage to every enemy within radius of Mirana.",
						"levels": [
							{"damage": 90, "radius": 1, "mana_cost": 65, "cooldown": 4},
							{"damage": 140, "radius": 1, "mana_cost": 90, "cooldown": 4},
							{"damage": 200, "radius": 2, "mana_cost": 120, "cooldown": 5},
							{"damage": 270, "radius": 2, "mana_cost": 150, "cooldown": 5}
						]
					},
					{
						"id": "sacred_arrow",
						"name": "Sacred Arrow",
						"type": "standard",
						"description": "Marks a target within range with a long-range arrow, dealing more damage the further it traveled, and stuns it.",
						"levels": [
							{"base_damage": 80, "bonus_per_column": 20, "range": 4, "stun_turns": 1, "mana_cost": 70, "cooldown": 5},
							{"base_damage": 120, "bonus_per_column": 30, "range": 5, "stun_turns": 2, "mana_cost": 100, "cooldown": 5},
							{"base_damage": 170, "bonus_per_column": 40, "range": 6, "stun_turns": 2, "mana_cost": 135, "cooldown": 6},
							{"base_damage": 230, "bonus_per_column": 50, "range": 7, "stun_turns": 3, "mana_cost": 170, "cooldown": 6}
						]
					},
					{
						"id": "leap",
						"name": "Leap",
						"type": "standard",
						"description": "Leaps in the direction she's facing, sailing clean over any enemy in the way.",
						"levels": [
							{"jump_distance": 2, "mana_cost": 50, "cooldown": 4},
							{"jump_distance": 3, "mana_cost": 65, "cooldown": 4},
							{"jump_distance": 4, "mana_cost": 80, "cooldown": 5},
							{"jump_distance": 5, "mana_cost": 100, "cooldown": 5}
						]
					},
					{
						"id": "moonlight_shadow",
						"name": "Moonlight Shadow",
						"type": "ultimate",
						"description": "Ultimate: turns invisible for the duration - enemies can't attack or chase her while it holds. Her next Attack from stealth deals bonus damage and reveals her.",
						"levels": [
							{"duration": 2, "bonus_damage_pct": 0.75, "mana_cost": 180, "cooldown": 9},
							{"duration": 3, "bonus_damage_pct": 1.10, "mana_cost": 240, "cooldown": 10},
							{"duration": 4, "bonus_damage_pct": 1.50, "mana_cost": 300, "cooldown": 11}
						]
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
						"description": "Fires a lunar beam at an enemy within range, dealing damage and stunning it.",
						"levels": [
							{"damage": 100, "stun_turns": 1, "range": 4, "mana_cost": 60, "cooldown": 4},
							{"damage": 160, "stun_turns": 1, "range": 5, "mana_cost": 85, "cooldown": 4},
							{"damage": 230, "stun_turns": 2, "range": 6, "mana_cost": 115, "cooldown": 5},
							{"damage": 310, "stun_turns": 2, "range": 7, "mana_cost": 145, "cooldown": 5}
						]
					},
					{
						"id": "moon_glaives",
						"name": "Moon Glaives",
						"type": "passive",
						"description": "Passive: Luna's attacks bounce to nearby enemies for reduced damage.",
						"levels": [
							{"bounces": 2, "bounce_damage_pct": 0.75, "bounce_range": 0},
							{"bounces": 3, "bounce_damage_pct": 0.65, "bounce_range": 1},
							{"bounces": 4, "bounce_damage_pct": 0.55, "bounce_range": 1},
							{"bounces": 5, "bounce_damage_pct": 0.45, "bounce_range": 2}
						]
					},
					{
						"id": "lunar_blessing",
						"name": "Lunar Blessing",
						"type": "passive",
						"description": "Passive: grants Luna bonus Attack damage.",
						"levels": [
							{"bonus_damage_pct": 0.15},
							{"bonus_damage_pct": 0.25},
							{"bonus_damage_pct": 0.35},
							{"bonus_damage_pct": 0.50}
						]
					},
					{
						"id": "eclipse",
						"name": "Eclipse",
						"type": "ultimate",
						"description": "Ultimate: darkens the sky - for the duration, lunar beams strike random enemies within radius of Luna, moving with her, until every beam has landed.",
						"levels": [
							{"beams": 4, "damage": 130, "radius": 2, "mana_cost": 200, "cooldown": 9},
							{"beams": 6, "damage": 175, "radius": 3, "mana_cost": 275, "cooldown": 10},
							{"beams": 8, "damage": 230, "radius": 4, "mana_cost": 350, "cooldown": 11}
						]
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
				"id": "the_blackbloom_melee",
				"name": "Blackbloom melee creep",
				"image": "res://assets/enemies/Nightsilver_Woods_mele.png",
				"type": "melee",
				"main_stat": "strength",
				"main_stat_value": 10,
				"hp": 150,
				"mana": 50,
				"damage": 10,
				"speed": 1,
				"armor": 1.5,
				"XP": 57,
				"gold": "34-39"
			},
			{
				"id": "the_blackbloom_melee_2",
				"name": "Blackbloom melee creep",
				"image": "res://assets/enemies/Nightsilver_Woods_mele.png",
				"type": "melee",
				"main_stat": "strength",
				"main_stat_value": 10,
				"hp": 150,
				"mana": 50,
				"damage": 10,
				"speed": 1,
				"armor": 1.5,
				"XP": 57,
				"gold": "34-39"
			},
			{
				"id": "the_blackbloom_range",
				"name": "Blackbloom range creep",
				"image": "res://assets/enemies/Nightsilver_Woods_range.png",
				"type": "range",
				"main_stat": "agility",
				"main_stat_value": 10,
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

	"the_wildreach": {
		"name": "The Wildreach",
		"description": "The Wildreach is a vast frontier stretching far beyond the borders of the great kingdoms. Forests, plains, and rugged valleys cover the region, broken by scattered settlements whose inhabitants live far from the protection of any crown or army.
		No single power rules the Wildreach. Small communities survive on their own, connected by old roads that disappear into the wilderness and forgotten watchtowers that stand as the last remnants of a more civilized age.
		The farther one travels from the settled lands, the less reliable the old maps become.",
		"music": "the_wildreach",
		"heroes": [],
		"unlocked": true,
		"background": ""
	},

	"wyrmfall": {
		"name": "Wyrmfall",
		"description": "Wyrmfall is a vast highland region surrounded by jagged peaks, deep ravines, and windswept valleys. The land is littered with enormous bones and fragments of ancient scales, remnants of creatures whose size and age defy anything known to exist in the modern world.
		Local legends claim that the great Wyrms once ruled these mountains, nesting among the highest peaks and treating the valleys below as their hunting grounds.",
		"music": "wyrmfall",
		"heroes": [],
		"unlocked": true,
		"background": ""
	},

	"the_rotbloom": {
		"name": "The Rotbloom",
		"description": "The Rotbloom is a hostile chain of islands where life has grown wild, poisonous, and strangely beautiful.
		Dense jungles cover the land, their twisted roots and enormous leaves saturated with corrosive sap. Pools of acidic water collect beneath the canopy, while clouds of luminous spores drift through the humid air.
		Many of the creatures of the islands have by carry venom strong enough to kill within moments, while others have developed bizarre forms to survive among the poisonous vegetation.
		Few outsiders willingly venture into the deepest parts of the jungle. Those who do often return changed, their bodies bearing strange growths or their memories clouded by the spores they inhaled.",
		"music": "the_rotbloom",
		"heroes": [],
		"unlocked": true,
		"background": ""
	},

	"the_stonewake": {
		"name": "The Stonewake",
		"description": "The Stonewake is a vast mountain region where the earth itself seems restless. Jagged peaks rise from a landscape fractured by deep ravines, unstable cliffs, and enormous seams of mineral buried beneath the rock.
		The region has suffered countless upheavals throughout its history. Mountains have shifted, rivers have changed their course overnight, and entire valleys have disappeared beneath landslides and collapsing stone. No settlement has ever remained unchanged for long.
		The oldest legends speak of a time when the mountains were silent and something beneath them was asleep. Then, during a season of violent earthquakes, the Stonewake shook with such force that entire peaks were torn apart.",
		"music": "the_stonewake",
		"heroes": [],
		"unlocked": true,
		"background": ""
	},

	"scorchlands": {
		"name": "Scorchlands",
		"description": "The Scorchlands are a vast desert frontier where relentless heat has stripped the land down to sand, stone, and bone. Endless dunes stretch between jagged rock formations, dry riverbeds, and isolated oases that serve as the only refuge for travelers crossing the wastes.
		No kingdom has ever managed to hold the Scorchlands for long. Scattered settlements survive along the old trade routes, populated by merchants, outlaws, wanderers, and people who have learned to rely on their own hands rather than distant rulers. Every settlement is a small island of civilization surrounded by miles of unforgiving wilderness.
		The desert is also home to countless predators and creatures adapted to its brutal conditions.",
		"music": "scorchlands",
		"heroes": [
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
						"description": "Fires a shotgun blast in the direction she's facing, dealing damage to every enemy within range.",
						"levels": [
							{"damage": 70, "range": 2, "mana_cost": 80, "cooldown": 6},
							{"damage": 100, "range": 2, "mana_cost": 105, "cooldown": 6},
							{"damage": 170, "range": 3, "mana_cost": 135, "cooldown": 7},
							{"damage": 230, "range": 3, "mana_cost": 160, "cooldown": 7}
						]
					},
					{
						"id": "firesnap_cookie",
						"name": "Firesnap Cookie",
						"type": "standard",
						"description": "Feeds a cookie to Mortimer (her pet) to cause a hop in the direction she's facing, damaging and stunning enemies around where he lands.",
						"levels": [
							{"jump_distance": 2, "damage": 60, "radius": 1, "stun_turns": 1, "mana_cost": 70, "cooldown": 5},
							{"jump_distance": 2, "damage": 90, "radius": 1, "stun_turns": 1, "mana_cost": 90, "cooldown": 5},
							{"jump_distance": 3, "damage": 120, "radius": 1, "stun_turns": 2, "mana_cost": 115, "cooldown": 6},
							{"jump_distance": 3, "damage": 160, "radius": 1, "stun_turns": 2, "mana_cost": 140, "cooldown": 6}
						]
					},
					{
						"id": "lil_shredder",
						"name": "Lil' Shredder",
						"type": "standard",
						"description": "Marks a target within normal attack range and fires 3 shots at it, each dealing a percentage of her own attack damage and shredding armor - the shredded armor returns after a duration.",
						"levels": [
							{"shots": 3, "damage_pct": 0.45, "armor_reduction_per_shot": 1, "duration": 1, "mana_cost": 80, "cooldown": 5},
							{"shots": 3, "damage_pct": 0.55, "armor_reduction_per_shot": 2, "duration": 1, "mana_cost": 105, "cooldown": 5},
							{"shots": 3, "damage_pct": 0.65, "armor_reduction_per_shot": 3.5, "duration": 2, "mana_cost": 130, "cooldown": 6},
							{"shots": 3, "damage_pct": 0.75, "armor_reduction_per_shot": 5, "duration": 2, "mana_cost": 155, "cooldown": 6}
						]
					},
					{
						"id": "mortimer_kisses",
						"name": "Mortimer Kisses",
						"type": "ultimate",
						"description": "Ultimate: marks a target within normal attack range, then channels for 3 turns - unable to move, act, or use items - firing one shot a turn that tracks the target (or its last known column, if it dies), dealing damage and burn to whoever it hits plus splash to the columns around it.",
						"levels": [
							{"hits": 3, "main_damage": 180, "splash_damage": 90, "burn_per_turn": 35, "burn_duration": 5, "mana_cost": 200, "cooldown": 10},
							{"hits": 3, "main_damage": 260, "splash_damage": 130, "burn_per_turn": 50, "burn_duration": 5, "mana_cost": 270, "cooldown": 11},
							{"hits": 3, "main_damage": 350, "splash_damage": 175, "burn_per_turn": 70, "burn_duration": 6, "mana_cost": 350, "cooldown": 12}
						]
					},
				],
				"level_up": {
					"strength": 3.2,
					"agility": 1.2,
					"intelligence": 2.1
				},
			},
		],
		"enemies": [
			{
				"id": "scorchlands_melee",
				"name": "Scorchlands melee creep",
				"image": "res://assets/enemies/vale_of_augury_mele.png",
				"type": "melee",
				"main_stat": "strength",
				"main_stat_value": 10,
				"hp": 150,
				"mana": 50,
				"damage": 10,
				"speed": 1,
				"armor": 1.5,
				"XP": 57,
				"gold": "34-39"
			},
			{
				"id": "scorchlands_melee_2",
				"name": "Scorchlands melee creep",
				"image": "res://assets/enemies/vale_of_augury_mele.png",
				"type": "melee",
				"main_stat": "strength",
				"main_stat_value": 10,
				"hp": 150,
				"mana": 50,
				"damage": 10,
				"speed": 1,
				"armor": 1.5,
				"XP": 57,
				"gold": "34-39"
			},
			{
				"id": "scorchlands_range",
				"name": "Scorchlands range creep",
				"image": "res://assets/enemies/vale_of_augury_range.png",
				"type": "range",
				"main_stat": "agility",
				"main_stat_value": 10,
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
		"background": "res://assets/zones/Vale_of_Augury_Snapfire.png",
		"battle_background": "res://assets/battle_areas/Vale_of_Augury.png"
	},

	"the_bronze_dominion": {
		"name": "The Bronze Dominion",
		"description": "The Bronze Dominion was once the greatest human empire in the known world, built upon immense cities, fortified roads, and an army whose discipline became legendary.
		Its rulers believed that order was the foundation of civilization, and for centuries their banners marked the borders of a realm that seemed impossible to challenge.
		At the heart of the Dominion stood its capital, a vast city of stone towers, monumental gates, and bronze-clad fortresses.
		What remains of the empire is a scarred collection of fortified settlements and abandoned roads, guarded by soldiers who refuse to accept that their war is over.",
		"music": "the_bronze_dominion",
		"heroes": [],
		"unlocked": true,
		"background": ""
	},

	"the_hollowlands": {
		"name": "The Hollowlands",
		"description": "The Hollowlands were once the borderlands between three powerful kingdoms, a harsh region of rocky hills and barren valleys that held little value beyond the legends surrounding it.
		For generations, stories spread of an immense treasure buried somewhere beneath the land. No one knew who had hidden it or how it came to be there, but the rumors grew with every retelling until the kingdoms became convinced that whoever claimed the riches would possess enough wealth to dominate the others.
		Armies marched across the valleys while sorcerers tore apart the land in search of the treasure. Entire fortresses were destroyed, and thousands died beneath the banners of kingdoms that believed victory would make the sacrifice worthwhile.
		",
		"music": "the_hollowlands",
		"heroes": [],
		"unlocked": true,
		"background": ""
	},

	"aureth": {
		"name": "Aureth",
		"description": "Aureth is an ancient city built among towering cliffs and immense natural formations of stone. At its heart stands a colossal temple carved directly into the mountainside, its foundations descending into caverns that reach far beneath the surface.
		What began as a small settlement around the temple grew into one of the greatest religious centers of the ancient world.
		Pilgrims traveled from distant kingdoms to worship within its halls, while generations of priests, scholars, and holy warriors were trained within the city's many sanctuaries.
		At its height, Aureth was a thriving city of monumental stairways, stone bridges, crowded markets, libraries, monasteries, and fortified temples built into the cliffs. Its wealth came from the countless pilgrims who passed through its gates, and its influence extended far beyond the mountains surrounding it.
		Until one of the city's most devoted knights returned from war having lost his faith and descended beneath the temple seeking answers.",
		"music": "aureth",
		"heroes": [],
		"unlocked": true,
		"background": ""
	},

	"vaelith": {
		"name": "Vaelith",
		"description": "Vaelith is an ancient city built upon a chain of enormous mountain peaks, far above the valleys below. Its towers, bridges, and palaces cling to sheer cliffs, connected by vast stone arches that disappear into the clouds.
		The city was built in isolation, deliberately separated from the kingdoms of the lowlands. Over centuries, Vaelith became a center of arcane study and political power, ruled by an ancient royal dynasty whose authority extended across the surrounding mountains.
		At the highest point of the city stands the Crownspire, the seat of the ruling dynasty. From there, the entire mountain range can be seen stretching beyond the clouds.
		But the isolation that protected Vaelith from the outside world also allowed its rulers to hide their own conflicts.
		Beneath the magnificent towers, rival factions fought for control of the Crownspire, while ancient magical oaths bound the city's most powerful guardians to whoever occupied the throne.",
		"music": "vaelith",
		"heroes": [],
		"unlocked": true,
		"background": ""
	},

	"kharuun": {
		"name": "Kharuun",
		"description": "Kharuun is a remote, mountainous island rising far above the surrounding sea. Steep cliffs, mist-covered valleys, and ancient forests divide the island, while narrow paths lead toward settlements hidden among the highlands.
		For centuries, the people of Kharuun have lived apart from the great kingdoms of the mainland. Their isolation allowed them to develop a unique understanding of magic, treating it not as a weapon or a divine gift, but as a discipline that must be studied, practiced, and passed from one generation to the next.
		Deep within the highest mountains lie sealed chambers containing records of magical experiments that predate the oldest known civilizations.
		Outsiders often mistake the people of Kharuun for simple mystics. In truth, their traditions are far more precise than the rituals practiced in most kingdoms.",
		"music": "kharuun",
		"heroes": [],
		"unlocked": true,
		"background": ""
	},

	"kharazhul": {
		"name": "Kharazhul",
		"description": "Kharazhul is a vast mountain range hidden beneath perpetual mist, where jagged peaks rise above narrow valleys and ancient forests cling to the steep slopes.
		The mountains are home to enormous predators and creatures found nowhere else in the world, forcing the people who live there to become hunters of extraordinary skill.
		The oldest settlements are built around ancient temples carved directly into the mountainsides. Their walls are covered with depictions of two figures whose faces have been deliberately erased from every surviving carving. The people call them the Hunger Below.
		According to the oldest traditions, the Hunger Below must be fed. Blood spilled in battle, during ritual hunts, and at sacred ceremonies is collected and carried into the highest temples, where it is offered to whatever sleeps beneath the mountains.",
		"music": "kharazhul",
		"heroes": [],
		"unlocked": true,
		"background": ""
	},

	"the_sandgrave": {
		"name": "The Sandgrave",
		"description": "The Sandgrave is a vast desert where the horizon stretches unbroken in every direction. Endless dunes move with the wind, burying old roads, ruins, and entire settlements beneath layers of shifting sand.
		The region receives almost no rain, and the brutal heat makes travel across the open desert dangerous even for experienced wanderers. Scattered outposts mark the few routes that cross the wasteland, each separated by days of difficult travel.
		The sand itself is alive with movement. Enormous creatures burrow through the depths, sensing footsteps from far below before erupting from the ground without warning.
		Some are little more than predators. Others are large enough to swallow entire caravans.",
		"music": "the_sandgrave",
		"heroes": [],
		"unlocked": true,
		"background": ""
	},

	"qadaris": {
		"name": "Qadaris",
		"description": "Qadaris is a vast expanse of golden dunes stretching across the eastern reaches of the world. From a distance, it appears to be an ordinary desert, barren and silent beneath the endless sun.
		The sands of Qadaris are part of something far greater than any living creature. Beneath the dunes lies a vast consciousness that extends across the entire region, aware of every movement upon its surface and every change within its depths.
		No single creature can comprehend such a mind. Its thoughts move slowly, measured not in moments or years, but in generations. Entire mountains may rise and disappear before one of its thoughts reaches completion.
		The inhabitants of the surrounding lands know nothing of this. To them, the shifting dunes are simply the result of wind and weather.
		Every few generations, the desert gathers a fragment of itself and gives it form. These beings serve as its eyes, its hands, and its voice among the smaller creatures of the world.",
		"music": "qadaris",
		"heroes": [],
		"unlocked": true,
		"background": ""
	},

	"carthane": {
		"name": "Carthane",
		"description": "Carthane is a wealthy city-state built upon trade, contracts, and the relentless pursuit of profit. Its towering districts rise around enormous markets where goods from nearly every corner of the world can be bought, sold, exchanged, or quietly acquired.
		Carthane has no great royal dynasty and little interest in ancient notions of honor. Its most powerful figures are merchants, financiers, guildmasters, and those wealthy enough to make laws work in their favor.
		Here, almost anything can be bought. Information has a price. Protection has a price. Loyalty has a price. Even justice can sometimes be negotiated, provided the buyer can afford the right contract.
		Despite its reputation, Carthane is not lawless. Its laws are among the most complicated in the world, designed to protect commerce above all else. Clever merchants can exploit them for generations, while those who fail to understand the fine print may lose everything without a single law being broken.
		Beneath the city lies an enormous network of abandoned tunnels and forgotten passages. Generations ago, Carthane's merchant houses attempted to establish trade routes through the deep earth, seeking rare minerals and resources untouched by the surface kingdoms.
		But the expeditions were eventually abandoned, and the official records were sealed.",
		"music": "carthane",
		"heroes": [],
		"unlocked": true,
		"background": ""
	},

	"the_wargrave": {
		"name": "The Wargrave",
		"description": "The Wargrave is a vast battlefield stretching across the southern lands, where generations of armies have fought over territory, borders, and causes long forgotten. What was once a fertile region has become an endless expanse of ruined fortifications, broken weapons, and countless dead.
		But the dead of the Wargrave do not return to the earth. The bodies left upon the battlefield do not decay. Flesh remains preserved long after life has left it, buried beneath newer layers of corpses as battle after battle adds to the growing mass.
		Over the centuries, the battlefield has become a landscape of its own. Hills formed from fallen soldiers rise beside abandoned trenches, while old roads disappear beneath layers of armor, bones, and preserved remains. Entire armies lie beneath the ground, their names and banners forgotten.",
		"music": "the_wargrave",
		"heroes": [],
		"unlocked": true,
		"background": ""
	},

	"the_blackveins": {
		"name": "The Blackveins",
		"description": "The Blackveins are a bleak highland region where dark streams of an unknown substance flow from the hills and disappear into the forests below.
		The thick, tar-like liquid stains the stone black and gathers in stagnant pools along the lower valleys.
		The hills are home to scattered clans who have learned to survive among the harsh terrain and the strange substance that flows through it. They avoid the deepest valleys, where the pools are thickest and the air carries an unpleasant metallic smell.
		Travelers have long called the region the Blackveins because the dark streams resemble enormous veins running through the mountains.",
		"music": "the_blackveins",
		"heroes": [],
		"unlocked": true,
		"background": ""
	},

	"gloamwood": {
		"name": "Gloamwood",
		"description": "Gloamwood is an immense forest stretching for hundreds of miles beneath the slopes of the Blackveins. Its ancient trees form an almost continuous canopy, turning the forest floor into a world of permanent twilight.
		For centuries, the Gloamwood was one of the most prosperous wilderness regions in the world. Hidden settlements flourished beneath the trees, connected by ancient paths and protected by powerful wardens who kept the peace between the many creatures that called the forest home.
		That peace ended when the dark substance flowing from the Blackveins began to spread into the woodland.
		It collected in stagnant pools between the roots, staining the soil and slowly changing the forest.
		The oldest inhabitants remember a time when the forest was ruled by a powerful king-mage who maintained its fragile balance for generations. His reign ended when a creature from beyond the mortal world entered the Gloamwood, seeking to consume the forest and claim it as its own.
		The creature was defeated, but the battle left parts of the forest permanently scarred. The fires ignited by its death spread through the black pools, creating flames that burned long after there was nothing left to consume.
		Deep within the forest, travelers occasionally find a skeletal figure standing motionless among the roots, bow still in hand, as though waiting for a battle that ended centuries ago.",
		"music": "gloamwood",
		"heroes": [],
		"unlocked": true,
		"background": ""
	},

	"the_stonewild": {
		"name": "The Stonewild",
		"description": "The Stonewild is an immense jungle where ancient ruins disappear beneath layers of roots, vines, and moss.
		Towering trees block out much of the sky, while enormous stone structures rise from the vegetation, remnants of a civilization that vanished long ago.
		Strange energy moves through the oldest parts of the jungle, causing ancient mechanisms to activate and stone figures to move when no living creature is near them.
		Beneath the deepest layers of the jungle lie enormous chambers. Within them are traces of creatures that once dominated the region long before humans built their first temples.
		Two of the largest chambers remain sealed.",
		"music": "the_stonewild",
		"heroes": [],
		"unlocked": true,
		"background": ""
	},

	"thundersteppe": {
		"name": "Thundersteppe",
		"description": "The Thundersteppe is a vast highland expanse of red earth, barren plateaus, and endless winds.
		Stretching beneath an open sky, the region offers little shelter from the violent storms that sweep across the land throughout the year.
		Scattered clans travel between settlements and seasonal camps, following the rains that bring life to the otherwise unforgiving land.
		Ancient structures lay scattered across the plateaus. Ruined towers and strange metal frameworks stand on the highest ridges, positioned precisely where the storms strike most often.
		Some clans believe these structures were built by their ancestors to communicate with the storms. Others believe they were built to control them.
		The most ambitious among them have begun restoring the ancient devices, combining old designs with their own inventions to capture the power of lightning.",
		"music": "thundersteppe",
		"heroes": [],
		"unlocked": true,
		"background": ""
	},

	"glasslands": {
		"name": "Glasslands",
		"description": "The Glasslands are a barren expanse of cracked earth, scorched rock, and narrow valleys where water is worth more than gold.
		Rain falls only a few times each year, and entire communities survive by collecting every drop before the dry winds return.
		The people who inhabit the region have developed strange ways of surviving its relentless climate. Ancient burrowing creatures roam beneath the surface, and some settlements have learned to guide them through the earth, using their unusual abilities to create networks of hollow glass tunnels beneath the desert.
		When the rare rains arrive, water flows through these underground channels and collects in hidden reservoirs. A single intact system can sustain a settlement for months.
		The Glasslands are also home to scattered outlaw communities that have existed beyond the reach of distant kingdoms for generations.
		Religious orders from the surrounding lands have repeatedly attempted to eradicate these tribes traditions, declaring them dangerous and unnatural.
		Hidden among the barren hills are the remains of an old academy whose purpose has been deliberately erased from surviving records. Its sealed chambers contain evidence of generations of experiments involving magic, bloodlines, and the suppression of supernatural abilities.",
		"music": "glasslands",
		"heroes": [],
		"unlocked": true,
		"background": ""
	},

	"veyraku": {
		"name": "Veyraku",
		"description": "Veyraku was once a secluded island civilization renowned for its mastery of the blade, intricate craftsmanship, and traditions that had been preserved for countless generations.
		Every warrior of Veyraku carried a mask carved by hand and bound to their lineage.
		It represented the identity of its wearer, their family, their achievements, and their place within society.
		The island's greatest masters devoted their entire lives to perfecting the art of the sword. Duels were treated as sacred rituals, and the techniques developed in Veyraku were guarded with extraordinary discipline.
		For centuries, the islands prospered in isolation. Then, in a single night, everything ended. Fires spread across the settlements while the sea surrounding the islands began to rise in unnatural waves.
		No surviving record explains what caused the catastrophe. Some believe the ruling houses attempted to harness a power they could not control. Others claim the destruction began when the island's oldest traditions were broken.
		By dawn, Veyraku had ceased to exist as a civilization.",
		"music": "veyraku",
		"heroes": [],
		"unlocked": true,
		"background": ""
	},

	"velashan": {
		"name": "Velashan",
		"description": "Velashan was once a renowned city of scholars, artists, and sacred artisans, built around a tradition of mystical calligraphy unlike any practiced elsewhere in the world.
		The people of Velashan believed that written symbols possessed power beyond their physical form. Every line, curve, and mark carried meaning, and master calligraphers spent decades studying the relationship between ink, thought, and spirit.
		At the center of the city stood an ancient temple containing a sacred runestone. Once in a generation, a chosen guardian would perform the Binding, painting a series of symbols upon the stone with specially prepared temple ink.
		The ritual connected the guardian to the people of Velashan, allowing them to share strength, pain, and life itself. The guardian became both protector and vessel, carrying the collective spirit of the city within a single soul.
		For centuries, the ritual was performed without failure. Then one guardian attempted to improve it. The ink had been altered before the ceremony, contaminated with a substance whose origin was never discovered.
		When the first symbol was painted, the ritual twisted upon itself. The guardian survived by forcing the corruption outward through the bond.
		Every other soul connected to the ritual received it instead.",
		"music": "velashan",
		"heroes": [],
		"unlocked": true,
		"background": ""
	},

	"the_drowned_marches": {
		"name": "The Drowned Marches",
		"description": "The Drowned Marches are a vast expanse of flooded lowlands, shallow lakes, muddy islands, and winding waterways stretching across the eastern frontier.
		Thousands of small tarns cover the region, separated by narrow strips of land that disappear beneath the water whenever the rains arrive.
		For generations, the people of the Marches lived under rulers they believed to be divine guardians of their land. The truth was far darker.
		Those who claimed to speak for the old gods were creatures that had taken control of the region from within, manipulating its people through fear, ritual, and carefully maintained superstition.
		When an invading army finally entered the Marches, what followed became one of the longest wars in the region's history.
		The conflict lasted seven years. Battles were fought across islands, flooded villages, narrow causeways, and endless stretches of mud. Armies disappeared beneath the water, entire settlements changed hands repeatedly, and thousands of soldiers died without their bodies ever being recovered.
		The people of the Marches still tell stories of lights moving across the water at night, far from any settlement.
		Some believe they are the spirits of those who died during the war.",
		"music": "the_drowned_marches",
		"heroes": [],
		"unlocked": true,
		"background": ""
	},

	"yun_shai": {
		"name": "Yun-Shai",
		"description": "Yun-Shai is an ancient land shaped by water, where enormous rivers once carved their way through fertile valleys before a catastrophic flood swallowed entire civilizations beneath the waves.
		Long before the modern kingdoms existed, the people of Yun-Shai built vast systems of canals, reservoirs, stone embankments, and enormous floodgates to control the waters. Their engineers became renowned for their ability to redirect rivers and hold back floods that would have destroyed lesser civilizations.
		Then came the Great Deluge. For months, the waters continued to rise despite every attempt to contain them. Rivers changed their courses, mountainsides collapsed, and entire cities disappeared beneath the expanding inland sea.
		The people of Yun-Shai eventually constructed a colossal network of channels designed to drain the flooded valleys and return the waters to the ocean.
		Today, Yun-Shai is a vast region of ancient riverbeds, enormous stone channels, ruined dams, and half-buried cities. Some waterways still flow through structures built thousands of years ago, following courses determined by engineers whose names have long been forgotten.",
		"music": "yun_shai",
		"heroes": [],
		"unlocked": true,
		"background": ""
	},

	"the_last_horizon": {
		"name": "The Last Horizon",
		"description": "The Last Horizon is a vast frontier at the farthest edge of the known world, where the roads of the great kingdoms gradually disappear into untouched wilderness.
		Few permanent settlements exist beyond the old borders, and the maps of most kingdoms simply end at the beginning of the region.
		For centuries, explorers believed there was little beyond the distant mountains and endless plains. Those who ventured farther rarely returned, and their reports were dismissed as the exaggerations of exhausted travelers.
		That changed when new paths began appearing across the frontier.
		Ancient roads emerged from beneath the soil. Stone markers were discovered deep within forests. Ruined structures stood in places no known civilization had ever settled. Even the oldest maps began proving incomplete.",
		"music": "the_last_horizon",
		"heroes": [],
		"unlocked": true,
		"background": ""
	},

	"the_sunscar": {
		"name": "The Sunscar",
		"description": "The Sunscar is a vast stretch of barren land where the heat of the sun has reduced once-fertile valleys to cracked earth and dust.
		But the region was not always this way. Centuries ago, The Sunscar endured a period of drought so severe that crops failed across entire kingdoms. Season after season passed without meaningful rain, and desperation slowly replaced reason.
		Communities abandoned their homes, settlements fought over wells, and travelers were blamed for the misfortune that had fallen upon the land.
		Among the most persecuted were wandering mages.
		Their presence was blamed for the failing rains, the dying crops, and the endless heat. Villages turned on anyone suspected of practicing magic, and entire groups were driven into the wilderness. Some were captured and publicly executed, while others disappeared into the desert, carrying their knowledge with them.
		The descendants of those who survived formed scattered communities across The Sunscar, relying on ancient wells, underground cisterns, and carefully preserved knowledge of the land. Some still refuse to speak of magic. Others secretly practice the very arts their ancestors were once killed for.
		",
		"music": "the_sunscar",
		"heroes": [],
		"unlocked": true,
		"background": ""
	},

	"the_veilbound": {
		"name": "The Veilbound",
		"description": "The Veilbound is an isolated land dominated by an ancient religious order that has spent generations studying the boundary between the physical world and something that exists beyond it.
		The order's temples are built around strange natural formations where reality appears unusually thin.
		Shadows move incorrectly, sounds travel without a source, and objects occasionally appear to exist in two places at once. The Veilbound believe these places are sacred gateways to a realm inhabited by beings they call the Ascended.
		Children chosen by the order begin their training at an early age. They study meditation, ritual magic, ancient texts, and the strange phenomena surrounding the Veil.
		Only a handful are eventually permitted to attempt the Rite of Crossing, the final trial required to become a full member of the order.
		During the ritual, the initiate must pass through the Veil and survive in the realm beyond it.
		Those who return are never quite the same. Their perception changes. Some develop the ability to see things hidden from ordinary eyes. Others return with memories of places that cannot exist in the physical world. A few come back unable to recognize their own reflections.",
		"music": "the_veilbound",
		"heroes": [],
		"unlocked": true,
		"background": ""
	}
}


# ============================================================
# ZONE FUNCTIONS
# ============================================================

## Converts a zone's display name into its dictionary key - lowercase,
## spaces and hyphens as underscores (e.g. "The Verdant Scar" ->
## "the_verdant_scar", "Yun-Shai" -> "yun_shai"). Zone ids are derived
## from their names this way, so a zone renamed later should get its id
## (and PlayerManager.LEGACY_ZONE_IDS, for old saves) updated to match.
## The map itself links its labels to zones by id (Map.gd's REGIONS).
func zone_id_from_name(zone_name: String) -> String:
	return zone_name.to_lower().replace(" ", "_").replace("-", "_")


func select_zone(zone_id: String) -> void:
	if not zones.has(zone_id):
		print("ERROR: Zone does not exist: ", zone_id)
		return

	selected_zone = zone_id


## Convenience wrapper: select a zone by its display name, e.g.
## GameManager.select_zone_by_name("The Verdant Scar").
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
## than rolling a range. "range_type" ("Range"/"Melee"/"Melee", not
## always consistently capitalized) maps to the "melee"/"range" type
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
		"type": "range" if is_ranged else "melee",
		"hp": hp,
		"damage": flat_damage,
		"armor": float(stats.get("armor", 0)),
		"XP": roundi(EnemyHeroManager.get_hero_kill_bounty(hero_id)),
		"gold": "%d-%d" % [roundi(hp * HERO_FIGHT_GOLD_MIN_MULTIPLIER), roundi(hp * HERO_FIGHT_GOLD_MAX_MULTIPLIER)],
		# Hero portraits are drawn facing right; battle.gd's
		# _spawn_enemy() uses this to mirror the art when it's placed
		# on the enemy side, so it faces the player's hero instead.
		"is_hero_fight": true,
		# Distinguishes the actual rival hero from a regular creep (and
		# from its own summoned Spirit Bear ally, which also sets
		# "is_hero_fight" for the same art-flipping reason but isn't
		# the boss) - see battle.gd's _enemy_turn()/_get_hero_fight_boss().
		"is_hero_fight_boss": true,
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
# A "passive" item can carry the same "stat"/"value" pair on top of
# its passive (Cleaver's +10 damage) - get_inventory_stat_bonus() counts
# any item with a "stat" field, whatever its effect.

# ============================================================
# SHOP DATA
# ============================================================
# Which item ids are currently sold in the Shop scene, and which of
# them have limited stock per visit (everything else is unlimited). Kept separate from `items` so the
# full item catalog (including ones not sold yet, like the stat
# boosts) doesn't have to be filtered down at runtime.

const SHOP_ITEM_IDS: Array[String] = ["health", "mana", "gauntlets_of_strength", "mantle_of_intelligence",
"slippers_of_agility", "circlet", "blades_of_attack", "cleaver", "hunters_bow", "morbid_mask", "broadsword", "claymore"]
const SHOP_LIMITED_STOCK_IDS: Array[String] = ["health", "mana"]
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
	"cleaver": {
		"id": "cleaver",
		"name": "Cleaver",
		"image": "res://assets/items/cleaver.png",
		"description": "Adds +10 damage. Passive (melee heroes only): Attacks cleave for 30% Cleave Damage to enemies within 1 column on either side.",
		"effect": "passive",
		"stat": "damage",
		"value": 10,
		"cost": 850
	},
	"hunters_bow": {
		"id": "hunters_bow",
		"name": "Hunter's Bow",
		"image": "res://assets/items/hunters_bow.png",
		"description": "Adds +10 damage. Passive (ranged heroes only): every 3rd Attack splits, also hitting another enemy within 2 columns of the target for full damage.",
		"effect": "passive",
		"stat": "damage",
		"value": 10,
		"cost": 900
	},
	"morbid_mask": {
		"id": "morbid_mask",
		"name": "Morbid Mask",
		"image": "res://assets/items/morbid mask.png",
		"description": "Passive: Heals for 10% of the damage dealt by your Attacks. No other stats.",
		"effect": "passive",
		"cost": 700
	},
	"broadsword": {
		"id": "broadsword",
		"name": "Broadsword",
		"image": "res://assets/items/broadsword.png",
		"description": "Add +15 damage",
		"effect": "stat",
		"stat": "damage",
		"value": 15,
		"cost": 1000
	},
	"claymore": {
		"id": "claymore",
		"name": "Claymore",
		"image": "res://assets/items/claymore.png",
		"description": "Add +20 damage",
		"effect": "stat",
		"stat": "damage",
		"value": 20,
		"cost": 1350
	},
}


func get_item(item_id: String) -> Dictionary:
	return items.get(item_id, {})
