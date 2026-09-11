extends Node

# ============================================================
# EnemyHeroManager
# ============================================================
# Owns the decision-making for every rival hero's simulated progress:
# leveling up, choosing which skill to spend a point on, buying
# potions, running its stage/hero-fight combat simulation, and - once
# a hero has cleared its own home zone (Step 5) - picking an invasion
# target and grinding/dueling toward it instead. All actual state
# lives in PlayerManager (see its "NPC hero state" section) - this
# autoload is pure logic on top of it, plus the hero-kill XP bounty
# formula used everywhere a hero dies (this file's own zone-mate/
# invasion duels, and GameManager.build_hero_fight_enemy_def() for
# when the player lands the killing blow instead).
#
# Add this script as an autoload singleton named "EnemyHeroManager"
# (Project Settings > Autoload), alongside GameManager and
# PlayerManager.

# One skill point per level, capped at 1 banked at once - same rule
# as the player (see PlayerManager.check_level_up).
const NPC_MAX_BANKED_SKILL_POINTS: int = 1

# Every simulated hero tries to keep exactly this many of each potion
# on hand - see restock_npc_potions().
const NPC_TARGET_POTION_COUNT: int = 3

# Hero-kill XP bounty: 100 + 13% of the victim's total lifetime XP,
# applied uniformly whether the player or another NPC did the killing.
const HERO_KILL_BOUNTY_BASE: float = 100.0
const HERO_KILL_BOUNTY_XP_MULTIPLIER: float = 0.13


# ------------------------------------------------------------------
# XP & bounty
# ------------------------------------------------------------------

## Total XP `hero_id` has ever earned - a running lifetime total,
## computed from their level plus current progress. This is needed
## because PlayerManager.get_npc_xp() (like the player's own hero_xp)
## only tracks progress toward the NEXT level, resetting each time one
## is gained, not a lifetime total by itself.
func get_total_accumulated_xp(hero_id: String) -> float:
	var level: int = PlayerManager.get_npc_level(hero_id)
	var total: float = PlayerManager.get_npc_xp(hero_id)
	for lvl in range(1, level):
		var required: int = GameManager.get_xp_required_for_level(lvl)
		if required > 0:
			total += required
	return total


## XP bounty for killing `victim_hero_id` - see HERO_KILL_BOUNTY_BASE
## / HERO_KILL_BOUNTY_XP_MULTIPLIER above. Applies to both the player
## killing a rival hero and one rival hero killing another.
func get_hero_kill_bounty(victim_hero_id: String) -> float:
	return HERO_KILL_BOUNTY_BASE + HERO_KILL_BOUNTY_XP_MULTIPLIER * get_total_accumulated_xp(victim_hero_id)


# ------------------------------------------------------------------
# Leveling
# ------------------------------------------------------------------

## Grants `amount` XP to `hero_id` and applies any level-ups it earns
## (see _apply_npc_level_ups) - immediately spending the resulting
## skill point, if any, since a simulated hero has no popup to defer
## the choice to. Returns how many levels were gained (0 if none).
func award_npc_xp(hero_id: String, hero_static: Dictionary, amount: float) -> int:
	if amount <= 0.0:
		return 0

	PlayerManager.set_npc_xp(hero_id, PlayerManager.get_npc_xp(hero_id) + amount)
	var levels_gained: int = _apply_npc_level_ups(hero_id, hero_static)

	if levels_gained > 0:
		_spend_npc_skill_point(hero_id, hero_static)

	return levels_gained


## Same mechanics as PlayerManager.check_level_up(), just reading/
## writing this NPC's own state instead of the player's hero: walks
## up through however many levels the banked XP covers, growing
## strength/agility/intelligence per the hero's static level_up dict,
## and banking one skill point per level gained (capped at
## NPC_MAX_BANKED_SKILL_POINTS). Returns how many levels were gained.
func _apply_npc_level_ups(hero_id: String, hero_static: Dictionary) -> int:
	var level: int = PlayerManager.get_npc_level(hero_id)
	var xp: float = PlayerManager.get_npc_xp(hero_id)
	var level_up_growth: Dictionary = hero_static.get("level_up", {})
	var levels_gained: int = 0

	while true:
		var xp_required: int = GameManager.get_xp_required_for_level(level)
		if xp_required <= 0 or xp < float(xp_required):
			break

		xp -= xp_required
		level += 1
		levels_gained += 1

		for stat_key in level_up_growth.keys():
			var growth: float = float(level_up_growth[stat_key])
			var new_value: float = PlayerManager.get_npc_stat(hero_id, stat_key) + growth
			PlayerManager.set_npc_stat(hero_id, stat_key, new_value)

	if levels_gained > 0:
		PlayerManager.set_npc_level(hero_id, level)
		PlayerManager.set_npc_xp(hero_id, xp)
		var points: int = PlayerManager.get_npc_skill_points(hero_id) + levels_gained
		PlayerManager.set_npc_skill_points(hero_id, mini(NPC_MAX_BANKED_SKILL_POINTS, points))

	return levels_gained


# ------------------------------------------------------------------
# Skill choice
# ------------------------------------------------------------------

## True if `skill_id` could have a point spent on it right now for
## this NPC - same eligibility rules as PlayerManager.
## can_spend_skill_point_on(), just against this hero's own simulated
## state instead of the player's.
func _npc_can_spend_skill_point_on(hero_id: String, skill_id: String, hero_static: Dictionary) -> bool:
	if PlayerManager.get_npc_skill_points(hero_id) <= 0:
		return false

	var skill_data: Dictionary = {}
	for skill in hero_static.get("skills", []):
		if skill.get("id", "") == skill_id:
			skill_data = skill
			break
	if skill_data.is_empty():
		return false

	var skill_type: String = skill_data.get("type", "standard")
	var next_level: int = PlayerManager.get_npc_skill_level(hero_id, skill_id) + 1
	if next_level > GameManager.get_max_skill_level(skill_type):
		return false

	var required_level: int = GameManager.get_skill_level_unlock_requirement(skill_type, next_level)
	return required_level >= 0 and PlayerManager.get_npc_level(hero_id) >= required_level


## Spends this NPC's one banked skill point (if any) on a random
## eligible skill - an eligible ULTIMATE is always chosen over any
## eligible standard skill, per design; among ties within whichever
## pool is used, the pick is random. Returns true if a point was spent.
func _spend_npc_skill_point(hero_id: String, hero_static: Dictionary) -> bool:
	if PlayerManager.get_npc_skill_points(hero_id) <= 0:
		return false

	var eligible_ultimates: Array = []
	var eligible_standards: Array = []
	for skill in hero_static.get("skills", []):
		var skill_id: String = skill.get("id", "")
		if not _npc_can_spend_skill_point_on(hero_id, skill_id, hero_static):
			continue
		if skill.get("type", "standard") == "ultimate":
			eligible_ultimates.append(skill_id)
		else:
			eligible_standards.append(skill_id)

	var pool: Array = eligible_ultimates if not eligible_ultimates.is_empty() else eligible_standards
	if pool.is_empty():
		return false

	var chosen_skill_id: String = pool[randi() % pool.size()]
	var next_level: int = PlayerManager.get_npc_skill_level(hero_id, chosen_skill_id) + 1
	PlayerManager.set_npc_skill_level(hero_id, chosen_skill_id, next_level)
	PlayerManager.set_npc_skill_points(hero_id, PlayerManager.get_npc_skill_points(hero_id) - 1)
	return true


# ------------------------------------------------------------------
# Shopping
# ------------------------------------------------------------------

## Spends `hero_id`'s gold restocking Health/Mana potions back up to
## NPC_TARGET_POTION_COUNT each - never buying beyond that target,
## never buying anything else. Stops early (per potion type) once
## gold runs out.
func restock_npc_potions(hero_id: String) -> void:
	_restock_npc_potion(hero_id, "health")
	_restock_npc_potion(hero_id, "mana")


func _restock_npc_potion(hero_id: String, potion_id: String) -> void:
	var cost: int = int(GameManager.get_item(potion_id).get("cost", 0))
	if cost <= 0:
		return

	var count: int = PlayerManager.get_npc_potion_count(hero_id, potion_id)
	while count < NPC_TARGET_POTION_COUNT and PlayerManager.get_npc_gold(hero_id) >= cost:
		PlayerManager.add_npc_gold(hero_id, -cost)
		count += 1
		PlayerManager.set_npc_potion_count(hero_id, potion_id, count)


# ------------------------------------------------------------------
# Combat simulation
# ------------------------------------------------------------------
# A lightweight, positionless stand-in for a real Battle scene fight -
# no grid/columns, no reinforcements, no hero-vs-hero yet (that's
# Step 5's invasion duels). Known simplifications, called out because
# they make simulated combat meaningfully different from a real fight:
#   - Pounce always targets the lowest-HP enemy (no "nearest along a
#     column" concept) but still applies its real stun duration.
#   - Dark Pact hits EVERY living enemy regardless of level's radius
#     field, since there are no columns to restrict it to.
#   - _apply_armor_reduction() below is verified to exactly match
#     battle.gd's own formula (as of Step 4) - if that formula ever
#     changes there, this copy needs updating too, since it isn't
#     shared code.
# ------------------------------------------------------------------

# Loss/stalemate cap - if the fight hasn't resolved by this many turns,
# it's treated as a loss (HP resets next attempt, no stage progress,
# but XP/gold/potions already spent this attempt are kept).
const MAX_SIMULATED_TURNS: int = 30

# Drink a Health Potion once HP falls to (or below) this fraction of max.
const LOW_HP_POTION_THRESHOLD: float = 0.2

# Every ACTIVE skill across Slark and Lone Druid, the only two heroes
# with any simulated skill logic today - anything else a hero knows
# just never gets cast here. Checked in this order when more than one
# is ready, worth casting (see _npc_skill_worth_casting), and
# affordable in the same turn: direct damage/control first, buffs
# after (so an NPC always prefers hitting something over refreshing a
# buff it doesn't strictly need yet).
# Savage Roar (Lone Druid's passive) isn't in this list - it's never
# "cast", it just turns itself on/off automatically off the hero's own
# HP%, same as the player's own copy - see
# _update_npc_savage_roar_state().
const KNOWN_ACTIVE_SKILL_IDS: Array[String] = [
	"dark_pact", "pounce", "essence_shift", "shadow_dance",
	"entangle", "summon_spirit_bear", "spirit_link", "true_form",
]


## Runs one simulated attempt for `hero_id` against whichever zone/
## stage they're currently tracked at (PlayerManager.
## get_npc_current_zone/get_npc_current_stage), applies any XP/gold
## gained, and advances or resets their stage progress based on the
## result. Returns {"result": "win"/"loss"/"stalemate", "xp_gained":
## float, "gold_gained": int} for the caller (e.g. Step 6's kill/
## progress messaging) to react to.
## This does not yet know about zone-mate hero fights or becoming
## "freed" to invade (Step 5) - clearing the final stage here just
## caps at the final stage rather than advancing past it.
func simulate_npc_stage_attempt(hero_id: String, hero_static: Dictionary) -> Dictionary:
	var zone_id: String = PlayerManager.get_npc_current_zone(hero_id)
	var stage: int = PlayerManager.get_npc_current_stage(hero_id)

	var enemies: Array = _build_simulated_stage_enemies(zone_id, stage)
	var fight: Dictionary = _run_stage_fight(hero_id, hero_static, enemies)

	if fight["xp_gained"] > 0.0:
		award_npc_xp(hero_id, hero_static, fight["xp_gained"])
	if fight["gold_gained"] > 0:
		PlayerManager.add_npc_gold(hero_id, fight["gold_gained"])

	if fight["result"] == "win":
		PlayerManager.set_npc_current_stage(hero_id, mini(stage + 1, GameManager.MAX_ZONE_STAGE))
	else:
		# Loss, stalemate, or anything less than a full clear - reset to
		# stage 1, mirroring the player's own reset-on-failure rule.
		PlayerManager.set_npc_current_stage(hero_id, 1)

	restock_npc_potions(hero_id)

	return fight


## The full per-hero simulation step, called once per hero per player
## Battle-scene load (see battle.gd) - Step 4's actual "tick":
## initializes a never-before-seen hero, runs one stage attempt, and
## - if that attempt just fully cleared their home zone's final stage
## - follows up with a fight against a zone-mate, if one is still
## alive (exactly mirroring the player's own post-stage-3 hero fight,
## just from this hero's perspective). A hero with no living zone-mate
## left is marked freed, at which point every future tick is handed
## off to _tick_freed_npc_hero() (Step 5) instead of grinding home.
func tick_npc_hero(hero_id: String, hero_static: Dictionary) -> void:
	if not PlayerManager.npc_is_initialized(hero_id):
		PlayerManager.initialize_npc_hero(hero_static, GameManager.get_zone_id_for_hero(hero_id))

	if PlayerManager.is_npc_freed(hero_id):
		_tick_freed_npc_hero(hero_id, hero_static)
		return

	var stage_before: int = PlayerManager.get_npc_current_stage(hero_id)
	var fight: Dictionary = simulate_npc_stage_attempt(hero_id, hero_static)

	if fight["result"] == "win" and stage_before >= GameManager.MAX_ZONE_STAGE:
		_try_npc_zone_mate_fight(hero_id, hero_static)


## After fully clearing their own home zone's final stage, fights a
## random undefeated zone-mate if one exists - the exact same
## one-sided "hero as a single tough enemy" model the player fights
## via GameManager.build_hero_fight_enemy_def(), just simulated. If no
## zone-mate is left alive, this hero is now free.
## Winning uses the XP bounty formula (get_hero_kill_bounty) rather
## than the enemy_def's own built-in XP field, since that field is
## sized for a flat creep-style reward, not a hero kill - gold still
## comes from the enemy_def as normal, since only the XP formula was
## asked to change for hero kills.
func _try_npc_zone_mate_fight(hero_id: String, hero_static: Dictionary) -> void:
	var home_zone_id: String = GameManager.get_zone_id_for_hero(hero_id)
	var zone_mates: Array = []
	for hero in GameManager.get_zone(home_zone_id).get("heroes", []):
		var mate_id: String = hero.get("id", "")
		if mate_id == hero_id or PlayerManager.is_hero_defeated(mate_id):
			continue
		zone_mates.append(hero)

	if zone_mates.is_empty():
		PlayerManager.set_npc_freed(hero_id)
		return

	var opponent_static: Dictionary = zone_mates[randi() % zone_mates.size()]
	var opponent_id: String = opponent_static.get("id", "")

	var enemy_def: Dictionary = GameManager.build_hero_fight_enemy_def(opponent_static)
	var enemies: Array = [{"static": enemy_def, "current_hp": float(enemy_def.get("hp", 1))}]
	var fight: Dictionary = _run_stage_fight(hero_id, hero_static, enemies)

	if fight["gold_gained"] > 0:
		PlayerManager.add_npc_gold(hero_id, fight["gold_gained"])

	if fight["result"] == "win":
		PlayerManager.mark_hero_defeated(opponent_id)
		award_npc_xp(hero_id, hero_static, get_hero_kill_bounty(opponent_id))

	# A loss/stalemate here leaves current_stage at MAX_ZONE_STAGE
	# (set by simulate_npc_stage_attempt just before this ran) with no
	# other persisted penalty - next tick just re-clears the home
	# zone's creeps again and retries this same fight, same as
	# reaching 0 HP anywhere else in simulation.
	restock_npc_potions(hero_id)


# ------------------------------------------------------------------
# Freedom + invasion (Step 5): once a hero has cleared its own home
# zone and beaten (or outlived) every zone-mate, is_npc_freed() is
# true and tick_npc_hero() routes here instead. A freed hero commits
# to one random invasion target - any hero in the game except the
# player's own and itself - grinds that target's home zone the exact
# same way it ground its own, and duels the target on that zone's
# final stage. If the target dies to someone else first, the next
# tick notices and picks a fresh target before doing anything else.
# ------------------------------------------------------------------

## A freed hero's tick: makes sure there's a live invasion target
## (picking/committing to a new one if there isn't), then runs one
## stage attempt against that target's zone and - once its final
## stage is cleared - the actual duel against the target hero.
func _tick_freed_npc_hero(hero_id: String, hero_static: Dictionary) -> void:
	var target_id: String = PlayerManager.get_npc_invasion_target(hero_id)

	if target_id == "" or PlayerManager.is_hero_defeated(target_id):
		target_id = _pick_invasion_target(hero_id)
		if target_id == "":
			# Nobody left to invade (every other hero is already
			# dead) - nothing more this freed hero can do right now.
			return
		PlayerManager.set_npc_invasion_target(hero_id, target_id)
		PlayerManager.set_npc_current_zone(hero_id, GameManager.get_zone_id_for_hero(target_id))
		PlayerManager.set_npc_current_stage(hero_id, 1)

	var stage_before: int = PlayerManager.get_npc_current_stage(hero_id)
	var fight: Dictionary = simulate_npc_stage_attempt(hero_id, hero_static)

	if fight["result"] == "win" and stage_before >= GameManager.MAX_ZONE_STAGE:
		_try_npc_invasion_duel(hero_id, hero_static, target_id)


## One random undefeated hero from anywhere in the game, excluding
## `hero_id` itself and the player's own recruited hero - "" if no
## such hero remains. Doesn't need to be in a different zone from any
## other freed hero; several rivals can invade (or even duel) the
## same target independently.
func _pick_invasion_target(hero_id: String) -> String:
	var player_hero_id: String = PlayerManager.get_recruited_hero().get("id", "")
	var candidates: Array = []

	for zone_id in GameManager.zones.keys():
		for hero in GameManager.zones[zone_id].get("heroes", []):
			var candidate_id: String = hero.get("id", "")
			if candidate_id == "" or candidate_id == hero_id or candidate_id == player_hero_id:
				continue
			if PlayerManager.is_hero_defeated(candidate_id):
				continue
			candidates.append(candidate_id)

	if candidates.is_empty():
		return ""
	return candidates[randi() % candidates.size()]


## The invasion duel itself, once `hero_id` has cleared `target_id`'s
## zone's final stage - the same one-sided "hero as a single tough
## enemy" fight as _try_npc_zone_mate_fight, just against a committed
## invasion target instead of a random zone-mate. Uses the shared
## hero-kill bounty formula on a win, same as every other hero kill.
func _try_npc_invasion_duel(hero_id: String, hero_static: Dictionary, target_id: String) -> void:
	if PlayerManager.is_hero_defeated(target_id):
		# The target died to someone else first while this hero was
		# still grinding toward the duel - clear it so next tick picks
		# a fresh target instead of fighting a hero that's already gone.
		PlayerManager.set_npc_invasion_target(hero_id, "")
		return

	var target_static: Dictionary = GameManager.get_hero_by_id(target_id)
	var enemy_def: Dictionary = GameManager.build_hero_fight_enemy_def(target_static)
	var enemies: Array = [{"static": enemy_def, "current_hp": float(enemy_def.get("hp", 1))}]
	var fight: Dictionary = _run_stage_fight(hero_id, hero_static, enemies)

	if fight["gold_gained"] > 0:
		PlayerManager.add_npc_gold(hero_id, fight["gold_gained"])

	if fight["result"] == "win":
		PlayerManager.mark_hero_defeated(target_id)
		award_npc_xp(hero_id, hero_static, get_hero_kill_bounty(target_id))
		# The target is gone - clear it so the next tick commits to a
		# fresh one rather than re-fighting a hero that no longer exists.
		PlayerManager.set_npc_invasion_target(hero_id, "")

	# A loss/stalemate leaves current_stage at MAX_ZONE_STAGE (set by
	# simulate_npc_stage_attempt just before this ran) and the target
	# unchanged, so next tick just re-clears the target's zone again
	# and retries this same duel - identical to the home-zone-mate
	# fight's own retry behavior.
	restock_npc_potions(hero_id)


## Every hero in the game except `exclude_hero_id` (the player's own
## recruited hero) - the full tick pool for battle.gd's per-Battle-
## load simulation pass.
func get_all_npc_hero_ids(exclude_hero_id: String) -> Array:
	var ids: Array = []
	for zone_id in GameManager.zones.keys():
		for hero in GameManager.zones[zone_id].get("heroes", []):
			var hero_id: String = hero.get("id", "")
			if hero_id != "" and hero_id != exclude_hero_id:
				ids.append(hero_id)
	return ids


## Runs tick_npc_hero() for every hero in the game except the
## player's own and anyone already defeated. Call this once per
## player Battle-scene load (see battle.gd's _ready()) - "every
## player attempt" is the agreed trigger, not just full zone clears,
## so background progress can't be avoided by fleeing early.
## Runs tick_npc_hero() for every rival hero in the game (skipping any
## already-defeated one), then flushes PlayerManager's data cache
## exactly once. Every individual tick's field reads/writes hit that
## in-memory cache only - see PlayerManager's "Data cache" section -
## so a full pass over dozens of heroes costs one disk read (already
## paid for by the time this runs) and one disk write here, instead
## of dozens of each.
func tick_all_npc_heroes(player_hero_id: String) -> void:
	for hero_id in get_all_npc_hero_ids(player_hero_id):
		if PlayerManager.is_hero_defeated(hero_id):
			continue
		tick_npc_hero(hero_id, GameManager.get_hero_by_id(hero_id))
	PlayerManager.flush_player_data()


## Builds this stage's enemy list the same way battle.gd's
## _load_enemies()/_build_stage_enemy_def() do for the real game:
## cycling through the zone's own melee/ranged templates per
## GameManager.get_stage_enemy_counts(), with this stage's hp/damage/
## gold bonuses baked into a duplicated copy of each template (the
## zone's template dictionaries themselves are never mutated).
func _build_simulated_stage_enemies(zone_id: String, stage: int) -> Array:
	var zone_data: Dictionary = GameManager.get_zone(zone_id)
	var enemy_defs: Array = zone_data.get("enemies", [])

	var mele_templates: Array = []
	var range_templates: Array = []
	for enemy_def in enemy_defs:
		if enemy_def.get("type", "") == "range":
			range_templates.append(enemy_def)
		else:
			mele_templates.append(enemy_def)

	var counts: Dictionary = GameManager.get_stage_enemy_counts(stage)
	var enemies: Array = []
	enemies.append_array(_build_stage_enemy_batch(mele_templates, int(counts.get("mele", 0)), stage))
	enemies.append_array(_build_stage_enemy_batch(range_templates, int(counts.get("range", 0)), stage))
	return enemies


func _build_stage_enemy_batch(templates: Array, count: int, stage: int) -> Array:
	var result: Array = []
	if templates.is_empty():
		return result
	for i in range(count):
		var template: Dictionary = templates[i % templates.size()]
		var staged: Dictionary = _apply_stage_bonus(template, stage)
		result.append({
			"static": staged,
			"current_hp": float(staged.get("hp", 1)),
			# Needed for Slark's Essence Shift (see
			# _apply_npc_essence_shift_steal()) - mirrors the field
			# battle.gd's own _spawn_enemy() seeds every enemy with.
			"current_main_stat_value": float(staged.get("main_stat_value", 0)),
		})
	return result


func _apply_stage_bonus(base_def: Dictionary, stage: int) -> Dictionary:
	if stage <= 1:
		return base_def

	var staged: Dictionary = base_def.duplicate()
	var stat_bonus: Dictionary = GameManager.get_stage_stat_bonus(stage)
	staged["hp"] = float(base_def.get("hp", 0)) + float(stat_bonus.get("hp", 0))
	staged["damage"] = float(base_def.get("damage", 0)) + float(stat_bonus.get("damage", 0))

	var gold_bonus: int = GameManager.get_stage_cumulative_gold_bonus(stage)
	if gold_bonus != 0:
		var gold_parts: PackedStringArray = str(base_def.get("gold", "0-0")).split("-")
		var gold_min: float = float(gold_parts[0]) if gold_parts.size() > 0 else 0.0
		var gold_max: float = float(gold_parts[1]) if gold_parts.size() > 1 else gold_min
		staged["gold"] = "%d-%d" % [int(gold_min + gold_bonus), int(gold_max + gold_bonus)]

	return staged


## The hero's own effective combat stats (hp/mana/armor/damage),
## derived from their current strength/agility/intelligence exactly
## like the player's own hero - see GameManager.compute_derived_stats.
## NPCs never buy equipment (only potions), so there's no equivalent
## of the player's inventory stat bonus to add on top here.
func _get_npc_combat_stats(hero_id: String, hero_static: Dictionary) -> Dictionary:
	return GameManager.compute_derived_stats(
		hero_static,
		PlayerManager.get_npc_stat(hero_id, "strength"),
		PlayerManager.get_npc_stat(hero_id, "agility"),
		PlayerManager.get_npc_stat(hero_id, "intelligence")
	)


## Runs the actual turn loop for one stage attempt against `enemies`
## (as built by _build_simulated_stage_enemies). Mutates `enemies` in
## place (current_hp, stun_turns_left) but doesn't touch stage
## progress itself - see simulate_npc_stage_attempt() for that.
func _run_stage_fight(hero_id: String, hero_static: Dictionary, enemies: Array) -> Dictionary:
	var combat_stats: Dictionary = _get_npc_combat_stats(hero_id, hero_static)
	var max_hp: float = float(combat_stats.get("hp", 1))
	var max_mana: float = float(combat_stats.get("mana", 0))
	var base_armor: float = float(combat_stats.get("armor", 0))
	var damage_range: String = str(combat_stats.get("damage", "0-0"))

	var current_hp: float = max_hp
	var current_mana: float = max_mana
	var cooldowns: Dictionary = {}
	var xp_gained: float = 0.0
	var gold_gained: int = 0
	var counted_dead: Dictionary = {}
	var result: String = "stalemate"

	# Every buff/debuff-carrying skill's running state, fresh for this
	# one attempt only - see _new_npc_combat_state(). Nothing here
	# persists between attempts, mirroring how the player's own copies
	# of this state (in battle.gd) reset every time the Battle scene is
	# left and re-entered.
	var state: Dictionary = _new_npc_combat_state()

	for turn_index in range(MAX_SIMULATED_TURNS):
		for skill_id in cooldowns.keys():
			cooldowns[skill_id] = maxi(0, cooldowns[skill_id] - 1)

		_tick_npc_essence_shift(state["essence_shift"])
		_tick_npc_shadow_dance(state["shadow_dance"])
		_tick_npc_spirit_link(state["spirit_link"])
		_tick_npc_true_form(state["true_form"])
		_tick_npc_entangle_effects(enemies)
		var kills: Dictionary = _collect_npc_kills(enemies, counted_dead)
		xp_gained += kills["xp"]
		gold_gained += kills["gold"]

		var effective_max_hp: float = _npc_effective_max_hp(max_hp, state)
		_update_npc_savage_roar_state(hero_id, hero_static, state["savage_roar"], current_hp, effective_max_hp)

		var living: Array = _living_enemies(enemies)
		if living.is_empty():
			result = "win"
			break

		# --- Hero's turn: potion, skill, or basic attack - in that
		# priority, one action per turn, same as the player. ---
		var acted_with: String = ""
		if current_hp <= effective_max_hp * LOW_HP_POTION_THRESHOLD and PlayerManager.get_npc_potion_count(hero_id, "health") > 0:
			PlayerManager.set_npc_potion_count(hero_id, "health", PlayerManager.get_npc_potion_count(hero_id, "health") - 1)
			current_hp = minf(effective_max_hp, current_hp + float(GameManager.get_item("health").get("value", 0)))
		else:
			var ready_skill_id: String = _pick_ready_skill(hero_id, hero_static, cooldowns, current_mana, state)
			if ready_skill_id != "":
				_cast_skill(hero_id, hero_static, ready_skill_id, cooldowns, damage_range, living, state)
				current_mana -= _npc_skill_mana_cost(hero_id, hero_static, ready_skill_id)
				acted_with = ready_skill_id
			elif _has_unaffordable_ready_skill(hero_id, hero_static, cooldowns, current_mana, state) and PlayerManager.get_npc_potion_count(hero_id, "mana") > 0:
				PlayerManager.set_npc_potion_count(hero_id, "mana", PlayerManager.get_npc_potion_count(hero_id, "mana") - 1)
				current_mana = minf(max_mana + state["essence_shift"]["bonus"].get("mana", 0.0), current_mana + float(GameManager.get_item("mana").get("value", 0)))
			else:
				var target: Dictionary = _lowest_hp_enemy(living)
				var shadow_bonus: float = state["shadow_dance"]["bonus_damage"] if state["shadow_dance"]["active"] else 0.0
				var dmg: float = _npc_roll_damage(damage_range, state, shadow_bonus)
				var mitigated: float = _apply_damage_to_enemy(target, dmg)
				_apply_npc_essence_shift_steal(target, state["essence_shift"], hero_static)
				current_hp = minf(effective_max_hp, current_hp + _npc_spirit_link_lifesteal(state["spirit_link"], mitigated))
				acted_with = "attack"

		# Shadow Dance only breaks from attacking or casting ANOTHER
		# skill, never from a cast/recast of Shadow Dance itself and
		# never from drinking a potion - exactly mirroring
		# battle.gd's _on_skill_pressed()/_apply_hero_attack().
		if state["shadow_dance"]["active"] and acted_with != "" and acted_with != "shadow_dance":
			_end_npc_shadow_dance(state["shadow_dance"])

		kills = _collect_npc_kills(enemies, counted_dead)
		xp_gained += kills["xp"]
		gold_gained += kills["gold"]

		living = _living_enemies(enemies)
		if living.is_empty():
			result = "win"
			break

		# --- The Spirit Bear (if summoned) acts automatically, same as
		# for the player - see battle.gd's _bear_turn(). Simplified vs.
		# the real fight: with no columns/positions here the bear
		# always swings at the lowest-HP living enemy, and - since
		# nothing in this abstract sim ever targets the bear
		# specifically - it never takes damage or dies from it; only
		# losing the real fight (a loss/stalemate) can end its tenure,
		# same as any other equipment-free NPC advantage in this sim. ---
		if not state["bear"].is_empty():
			var bear_target: Dictionary = _lowest_hp_enemy(living)
			_apply_damage_to_enemy(bear_target, _npc_roll_bear_damage(state["bear"]))

			kills = _collect_npc_kills(enemies, counted_dead)
			xp_gained += kills["xp"]
			gold_gained += kills["gold"]

			living = _living_enemies(enemies)
			if living.is_empty():
				result = "win"
				break

		# --- Enemies retaliate, skipping anyone Pounce just stunned or
		# while Shadow Dance is hiding the hero entirely (mirrors
		# battle.gd's _is_hero_hidden() check in _enemy_turn()). ---
		if not state["shadow_dance"]["active"]:
			var effective_armor: float = _npc_effective_armor(base_armor, state)
			for enemy in living:
				var stun_left: int = enemy.get("stun_turns_left", 0)
				if stun_left > 0:
					enemy["stun_turns_left"] = stun_left - 1
					continue
				var enemy_damage: float = float(enemy["static"].get("damage", 0))
				var reduced: float = _apply_armor_reduction(enemy_damage, effective_armor)
				reduced *= (1.0 - float(state["savage_roar"].get("damage_reduction_pct", 0.0)))
				current_hp -= reduced
				if current_hp <= 0:
					break

		if current_hp <= 0:
			result = "loss"
			break

	return {"result": result, "xp_gained": xp_gained, "gold_gained": gold_gained}


## Fresh per-attempt state for every buff/debuff-carrying skill -
## mirrors the shape (and defaults) of battle.gd's own
## _essence_shift_*/_shadow_dance_*/_spirit_link_*/_true_form_*/_bear
## instance variables, just bundled into one Dictionary here since this
## state only needs to live for the duration of one _run_stage_fight()
## call rather than the whole scene's lifetime.
func _new_npc_combat_state() -> Dictionary:
	return {
		"essence_shift": {
			"active": false, "attacks_remaining": 0, "turns_remaining": 0,
			"duration_pending_start": false, "stolen": [],
			"bonus": {"damage": 0.0, "hp": 0.0, "mana": 0.0, "armor": 0.0},
		},
		"shadow_dance": {"active": false, "bonus_damage": 0.0, "turns_remaining": 0, "duration_pending_start": false},
		"spirit_link": {"active": false, "lifesteal_pct": 0.0, "bonus_armor": 0.0, "turns_remaining": 0, "duration_pending_start": false},
		"true_form": {"active": false, "bonus_hp": 0.0, "bonus_damage": 0.0, "turns_remaining": 0, "duration_pending_start": false},
		"bear": {},
		"savage_roar": {"active": false, "damage_reduction_pct": 0.0},
	}


func _cast_skill(hero_id: String, hero_static: Dictionary, skill_id: String, cooldowns: Dictionary, damage_range: String, living: Array, state: Dictionary) -> void:
	var skill: Dictionary = _find_skill(hero_static, skill_id)
	var level: int = PlayerManager.get_npc_skill_level(hero_id, skill_id)
	var level_data: Dictionary = GameManager.get_skill_level_data(skill, level)
	cooldowns[skill_id] = int(level_data.get("cooldown", 0))

	match skill_id:
		"dark_pact":
			var multiplier: float = float(level_data.get("damage_multiplier", 0.75))
			var dmg: float = _npc_roll_damage(damage_range, state) * multiplier
			for enemy in living:
				_apply_damage_to_enemy(enemy, dmg)
		"pounce":
			var target: Dictionary = _lowest_hp_enemy(living)
			_apply_damage_to_enemy(target, _npc_roll_damage(damage_range, state))
			if target["current_hp"] > 0:
				target["stun_turns_left"] = int(level_data.get("stun_turns", 1))
		"essence_shift":
			_activate_npc_essence_shift(state["essence_shift"], level_data)
		"shadow_dance":
			_activate_npc_shadow_dance(state["shadow_dance"], level_data)
		"entangle":
			# No separate "pick a target" step here (there's no player
			# to click one) - roots/silences/DoTs whichever enemy the
			# hero would otherwise have attacked this turn.
			_apply_npc_root(_lowest_hp_enemy(living), level_data)
		"summon_spirit_bear":
			state["bear"] = {
				"damage_min": float(level_data.get("damage_min", 0)),
				"damage_max": float(level_data.get("damage_max", 0)),
			}
		"spirit_link":
			_activate_npc_spirit_link(state["spirit_link"], level_data)
		"true_form":
			_activate_npc_true_form(state["true_form"], level_data)


## The mana cost of `skill_id` at this NPC's current level - unlike a
## flat top-level "mana_cost" field (which none of these skills
## actually have), this reads the correct per-level value the same way
## GameManager.get_skill_level_data()/battle.gd's own cast paths do.
func _npc_skill_mana_cost(hero_id: String, hero_static: Dictionary, skill_id: String) -> float:
	var skill: Dictionary = _find_skill(hero_static, skill_id)
	var level: int = PlayerManager.get_npc_skill_level(hero_id, skill_id)
	return float(GameManager.get_skill_level_data(skill, level).get("mana_cost", 0))


## False for a buff/summon skill that's already active and wouldn't do
## anything new right now (recasting Essence Shift/Shadow Dance/Spirit
## Link/True Form just restarts their duration from the same values,
## and a Spirit Bear that's already out doesn't need replacing) - so
## the NPC doesn't burn mana refreshing something with no benefit
## instead of attacking. Dark Pact/Pounce/Entangle always report true;
## they only ever get checked once a living target is already
## confirmed to exist by the caller.
func _npc_skill_worth_casting(skill_id: String, state: Dictionary) -> bool:
	match skill_id:
		"essence_shift":
			return not state["essence_shift"]["active"]
		"shadow_dance":
			return not state["shadow_dance"]["active"]
		"spirit_link":
			return not state["spirit_link"]["active"]
		"true_form":
			return not state["true_form"]["active"]
		"summon_spirit_bear":
			return state["bear"].is_empty()
		_:
			return true


## The first known, off-cooldown, currently-worthwhile, currently-
## affordable active skill, in KNOWN_ACTIVE_SKILL_IDS priority order -
## "" if none qualify right now.
func _pick_ready_skill(hero_id: String, hero_static: Dictionary, cooldowns: Dictionary, current_mana: float, state: Dictionary) -> String:
	for skill_id in KNOWN_ACTIVE_SKILL_IDS:
		if PlayerManager.get_npc_skill_level(hero_id, skill_id) <= 0:
			continue
		if cooldowns.get(skill_id, 0) > 0:
			continue
		if not _npc_skill_worth_casting(skill_id, state):
			continue
		if current_mana >= _npc_skill_mana_cost(hero_id, hero_static, skill_id):
			return skill_id
	return ""


## True if there's a known, off-cooldown, currently-worthwhile active
## skill that's just short on mana right now - the trigger for
## drinking a Mana Potion instead of attacking this turn.
func _has_unaffordable_ready_skill(hero_id: String, hero_static: Dictionary, cooldowns: Dictionary, current_mana: float, state: Dictionary) -> bool:
	for skill_id in KNOWN_ACTIVE_SKILL_IDS:
		if PlayerManager.get_npc_skill_level(hero_id, skill_id) <= 0:
			continue
		if cooldowns.get(skill_id, 0) > 0:
			continue
		if not _npc_skill_worth_casting(skill_id, state):
			continue
		if current_mana < _npc_skill_mana_cost(hero_id, hero_static, skill_id):
			return true
	return false


# ------------------------------------------------------------------
# Slark's Essence Shift - mirrors battle.gd's own
# _activate_essence_shift/_apply_essence_shift_steal/_tick_essence_
# shift/_end_essence_shift, just against this sim's flat enemy list
# and NPC-local state Dictionary instead of instance variables.
# ------------------------------------------------------------------

func _activate_npc_essence_shift(es: Dictionary, level_data: Dictionary) -> void:
	if es["active"]:
		_end_npc_essence_shift(es)
	es["active"] = true
	es["attacks_remaining"] = int(level_data.get("attacks", 0))
	es["turns_remaining"] = int(level_data.get("duration", 0))
	es["duration_pending_start"] = true


func _apply_npc_essence_shift_steal(target: Dictionary, es: Dictionary, hero_static: Dictionary) -> void:
	if not es["active"] or es["attacks_remaining"] <= 0:
		return

	var stat_name: String = str(target["static"].get("main_stat", "")).to_lower()
	if stat_name == "":
		return

	var current_value: float = float(target.get("current_main_stat_value", 0.0))
	if current_value <= GameManager.ESSENCE_SHIFT_MIN_ENEMY_MAIN_STAT:
		return

	target["current_main_stat_value"] = current_value - 1.0
	es["attacks_remaining"] -= 1
	es["stolen"].append({"enemy": target, "amount": 1.0})

	var contribution: Dictionary = _essence_shift_contribution_for(stat_name, hero_static)
	for stat_key in contribution.keys():
		es["bonus"][stat_key] = es["bonus"].get(stat_key, 0.0) + contribution[stat_key]


## Same conversion table as battle.gd's own
## _essence_shift_contribution_for(): strength -> hp, agility -> armor,
## intelligence -> mana, at GameManager's per-point rates, plus damage
## on top if the stolen stat happens to be this hero's own main stat.
func _essence_shift_contribution_for(stat_name: String, hero_static: Dictionary) -> Dictionary:
	var contribution: Dictionary = {"damage": 0.0, "hp": 0.0, "mana": 0.0, "armor": 0.0}

	match stat_name:
		"strength":
			contribution["hp"] = GameManager.HP_PER_STRENGTH
		"agility":
			contribution["armor"] = GameManager.ARMOR_PER_AGILITY
		"intelligence":
			contribution["mana"] = GameManager.MANA_PER_INTELLIGENCE

	if stat_name == str(hero_static.get("main_stat", "")).to_lower():
		contribution["damage"] = GameManager.DAMAGE_PER_MAIN_STAT

	return contribution


func _tick_npc_essence_shift(es: Dictionary) -> void:
	if not es["active"]:
		return
	if es["duration_pending_start"]:
		es["duration_pending_start"] = false
		return
	es["turns_remaining"] -= 1
	if es["turns_remaining"] <= 0:
		_end_npc_essence_shift(es)


## Hands back every currently-borrowed point to whichever donor enemies
## are still alive (dead ones just forfeit theirs, same as
## battle.gd's own _is_enemy_still_active() check accomplishes there).
func _end_npc_essence_shift(es: Dictionary) -> void:
	for entry in es["stolen"]:
		var donor: Dictionary = entry["enemy"]
		if donor.get("current_hp", 0) > 0:
			donor["current_main_stat_value"] = float(donor.get("current_main_stat_value", 0.0)) + float(entry["amount"])

	es["stolen"].clear()
	es["bonus"] = {"damage": 0.0, "hp": 0.0, "mana": 0.0, "armor": 0.0}
	es["active"] = false
	es["attacks_remaining"] = 0
	es["turns_remaining"] = 0
	es["duration_pending_start"] = false


# ------------------------------------------------------------------
# Slark's Shadow Dance - mirrors battle.gd's _activate_shadow_dance/
# _tick_shadow_dance/_end_shadow_dance. There's no visibility/targeting
# system in this sim, so "hidden" just means enemies skip their
# retaliation entirely for the turn (see _run_stage_fight()).
# ------------------------------------------------------------------

func _activate_npc_shadow_dance(sd: Dictionary, level_data: Dictionary) -> void:
	sd["active"] = true
	sd["bonus_damage"] = float(level_data.get("bonus_damage", 0))
	sd["turns_remaining"] = int(level_data.get("duration", 0))
	sd["duration_pending_start"] = true


func _tick_npc_shadow_dance(sd: Dictionary) -> void:
	if not sd["active"]:
		return
	if sd["duration_pending_start"]:
		sd["duration_pending_start"] = false
		return
	sd["turns_remaining"] -= 1
	if sd["turns_remaining"] <= 0:
		_end_npc_shadow_dance(sd)


func _end_npc_shadow_dance(sd: Dictionary) -> void:
	sd["active"] = false
	sd["bonus_damage"] = 0.0
	sd["turns_remaining"] = 0
	sd["duration_pending_start"] = false


# ------------------------------------------------------------------
# Lone Druid's Entangle - mirrors battle.gd's _apply_root/
# _tick_entangle_effects. Root/silence have no real effect in this
# columnless, creeps-never-cast-skills sim (tracked anyway for parity
# with the real fight) - only the damage-over-time actually matters.
# ------------------------------------------------------------------

func _apply_npc_root(target: Dictionary, level_data: Dictionary) -> void:
	target["root_turns_left"] = int(level_data.get("root_turns", 0))
	target["silence_turns_left"] = int(level_data.get("silence_turns", 0))
	target["entangle_dot_damage"] = float(level_data.get("dot_damage", 0))
	target["entangle_dot_turns_left"] = int(level_data.get("dot_duration", 0))


func _tick_npc_entangle_effects(enemies: Array) -> void:
	for enemy in enemies:
		if enemy.get("root_turns_left", 0) > 0:
			enemy["root_turns_left"] -= 1
		if enemy.get("silence_turns_left", 0) > 0:
			enemy["silence_turns_left"] -= 1

		if enemy.get("entangle_dot_turns_left", 0) > 0:
			enemy["entangle_dot_turns_left"] -= 1
			var dot_damage: float = float(enemy.get("entangle_dot_damage", 0))
			if dot_damage > 0.0 and enemy.get("current_hp", 0) > 0:
				_apply_damage_to_enemy(enemy, dot_damage)


# ------------------------------------------------------------------
# Lone Druid's Spirit Link - mirrors battle.gd's _activate_spirit_link/
# _tick_spirit_link/_end_spirit_link/_apply_spirit_link_lifesteal.
# ------------------------------------------------------------------

func _activate_npc_spirit_link(sl: Dictionary, level_data: Dictionary) -> void:
	sl["active"] = true
	sl["lifesteal_pct"] = float(level_data.get("lifesteal_pct", 0.0))
	sl["bonus_armor"] = float(level_data.get("bonus_armor", 0))
	sl["turns_remaining"] = int(level_data.get("duration", 0))
	sl["duration_pending_start"] = true


func _tick_npc_spirit_link(sl: Dictionary) -> void:
	if not sl["active"]:
		return
	if sl["duration_pending_start"]:
		sl["duration_pending_start"] = false
		return
	sl["turns_remaining"] -= 1
	if sl["turns_remaining"] <= 0:
		_end_npc_spirit_link(sl)


func _end_npc_spirit_link(sl: Dictionary) -> void:
	sl["active"] = false
	sl["lifesteal_pct"] = 0.0
	sl["bonus_armor"] = 0.0
	sl["turns_remaining"] = 0
	sl["duration_pending_start"] = false


## Only ever called for the plain basic-attack branch of the hero's
## turn - like the real fight, skill damage (Dark Pact, Pounce,
## Entangle's DoT, the bear's own hits) never triggers lifesteal.
## Returns the HP to heal (already scaled by the damage actually
## dealt), 0.0 while inactive.
func _npc_spirit_link_lifesteal(sl: Dictionary, mitigated_attack_damage: float) -> float:
	if not sl["active"] or mitigated_attack_damage <= 0.0:
		return 0.0
	return mitigated_attack_damage * sl["lifesteal_pct"]


# ------------------------------------------------------------------
# Lone Druid's ultimate, True Form - mirrors battle.gd's
# _activate_true_form/_tick_true_form/_end_true_form. There's no
# portrait or forced-melee-range concept in this sim (no columns to
# force anything onto), so only the bonus hp/damage carry over.
# ------------------------------------------------------------------

func _activate_npc_true_form(tf: Dictionary, level_data: Dictionary) -> void:
	if tf["active"]:
		_end_npc_true_form(tf)
	tf["active"] = true
	tf["bonus_hp"] = float(level_data.get("bonus_hp", 0))
	tf["bonus_damage"] = float(level_data.get("bonus_damage", 0))
	tf["turns_remaining"] = int(level_data.get("duration", 0))
	tf["duration_pending_start"] = true


func _tick_npc_true_form(tf: Dictionary) -> void:
	if not tf["active"]:
		return
	if tf["duration_pending_start"]:
		tf["duration_pending_start"] = false
		return
	tf["turns_remaining"] -= 1
	if tf["turns_remaining"] <= 0:
		_end_npc_true_form(tf)


func _end_npc_true_form(tf: Dictionary) -> void:
	tf["active"] = false
	tf["bonus_hp"] = 0.0
	tf["bonus_damage"] = 0.0
	tf["turns_remaining"] = 0
	tf["duration_pending_start"] = false


# ------------------------------------------------------------------
# Lone Druid's Savage Roar (passive) - mirrors battle.gd's
# _get_savage_roar_level_data/_update_savage_roar_state, hysteresis
# and all: switches on once HP drops below 50%, stays on through the
# climb back up until HP reaches 80%, same as the player's own copy.
# ------------------------------------------------------------------

func _get_npc_savage_roar_level_data(hero_id: String, hero_static: Dictionary) -> Dictionary:
	var level: int = PlayerManager.get_npc_skill_level(hero_id, "savage_roar")
	if level <= 0:
		return {}
	var skill: Dictionary = _find_skill(hero_static, "savage_roar")
	if skill.is_empty():
		return {}
	return GameManager.get_skill_level_data(skill, level)


func _update_npc_savage_roar_state(hero_id: String, hero_static: Dictionary, sr: Dictionary, current_hp: float, effective_max_hp: float) -> void:
	var level_data: Dictionary = _get_npc_savage_roar_level_data(hero_id, hero_static)

	if level_data.is_empty():
		sr["active"] = false
	else:
		var hp_pct: float = current_hp / effective_max_hp if effective_max_hp > 0.0 else 0.0
		if sr["active"]:
			if hp_pct >= 0.8:
				sr["active"] = false
		elif hp_pct < 0.5:
			sr["active"] = true

	sr["damage_reduction_pct"] = float(level_data.get("damage_reduction_pct", 0.0)) if sr["active"] else 0.0


# ------------------------------------------------------------------
# Shared combat-math helpers that fold every active buff's bonus in.
# ------------------------------------------------------------------

## Base max HP plus Essence Shift's borrowed hp plus True Form's bonus
## hp while each is active - mirrors battle.gd's _hero_max_hp().
func _npc_effective_max_hp(max_hp: float, state: Dictionary) -> float:
	return max_hp + state["essence_shift"]["bonus"].get("hp", 0.0) + state["true_form"]["bonus_hp"]


## Base armor plus Essence Shift's borrowed armor plus Spirit Link's
## flat bonus while each is active - mirrors battle.gd's _hero_armor().
func _npc_effective_armor(base_armor: float, state: Dictionary) -> float:
	return base_armor + state["essence_shift"]["bonus"].get("armor", 0.0) + state["spirit_link"]["bonus_armor"]


## Rolls damage from `damage_range`, adding Essence Shift's ongoing
## borrowed damage, True Form's bonus damage while active, and (for the
## single hit that triggers it) Shadow Dance's one-shot `extra_bonus` -
## mirrors battle.gd's _roll_hero_damage().
func _npc_roll_damage(damage_range: String, state: Dictionary, extra_bonus: float = 0.0) -> float:
	var parts: PackedStringArray = damage_range.split("-")
	var min_dmg: float = float(parts[0]) if parts.size() > 0 else 0.0
	var max_dmg: float = float(parts[1]) if parts.size() > 1 else min_dmg

	var bonus_damage: float = state["essence_shift"]["bonus"].get("damage", 0.0) + state["true_form"]["bonus_damage"] + extra_bonus
	min_dmg += bonus_damage
	max_dmg += bonus_damage

	return randi_range(int(min_dmg), int(max_dmg))


func _npc_roll_bear_damage(bear: Dictionary) -> float:
	return randi_range(int(bear.get("damage_min", 0)), int(bear.get("damage_max", 0)))


## Scans every enemy for anything that died since the last check
## (tracked by index in `counted_dead`, since dead enemies stay in the
## array here rather than being removed like battle.gd's _enemies)
## and returns the XP/gold it's worth, exactly once per enemy. Called
## after every damage-dealing step in a turn (the hero's action, the
## bear's action, Entangle's DoT tick) so a kill from any of them is
## credited immediately.
func _collect_npc_kills(enemies: Array, counted_dead: Dictionary) -> Dictionary:
	var xp: float = 0.0
	var gold: int = 0
	for i in range(enemies.size()):
		if enemies[i]["current_hp"] <= 0 and not counted_dead.get(i, false):
			counted_dead[i] = true
			xp += float(enemies[i]["static"].get("XP", 0))
			gold += _roll_gold(str(enemies[i]["static"].get("gold", "0-0")))
	return {"xp": xp, "gold": gold}


func _find_skill(hero_static: Dictionary, skill_id: String) -> Dictionary:
	for skill in hero_static.get("skills", []):
		if skill.get("id", "") == skill_id:
			return skill
	return {}


func _living_enemies(enemies: Array) -> Array:
	var living: Array = []
	for enemy in enemies:
		if enemy["current_hp"] > 0:
			living.append(enemy)
	return living


func _lowest_hp_enemy(living_enemies: Array) -> Dictionary:
	var lowest: Dictionary = living_enemies[0]
	for enemy in living_enemies:
		if enemy["current_hp"] < lowest["current_hp"]:
			lowest = enemy
	return lowest


## Returns the mitigated damage actually dealt, so callers that need it
## (Spirit Link's lifesteal, via the hero's basic-attack branch) don't
## have to re-derive it - mirrors battle.gd's _deal_fixed_damage_to_enemy().
func _apply_damage_to_enemy(enemy: Dictionary, amount: float) -> float:
	var mitigated: float = _apply_armor_reduction(amount, float(enemy["static"].get("armor", 0)))
	enemy["current_hp"] -= mitigated
	return mitigated


func _roll_damage(damage_range: String) -> float:
	var parts: PackedStringArray = damage_range.split("-")
	var min_dmg: float = float(parts[0]) if parts.size() > 0 else 0.0
	var max_dmg: float = float(parts[1]) if parts.size() > 1 else min_dmg
	return randi_range(int(min_dmg), int(max_dmg))


func _roll_gold(gold_range: String) -> int:
	var parts: PackedStringArray = gold_range.split("-")
	var min_gold: int = int(parts[0]) if parts.size() > 0 else 0
	var max_gold: int = int(parts[1]) if parts.size() > 1 else min_gold
	return randi_range(min_gold, max_gold)


## Best-effort reimplementation of a Dota-style diminishing-returns
## armor curve - see the note at the top of this section about
## reconciling this with battle.gd's actual formula in Step 4.
## Exactly matches battle.gd's own _apply_armor_reduction/
## _damage_reduction - verified against the real source rather than
## assumed. Negative armor increases damage taken (via the same
## formula, not a separate branch); the result is clamped to 0 so it
## can never flip a hit into a heal.
func _apply_armor_reduction(damage: float, armor: float) -> float:
	var reduction: float = (0.06 * armor) / (1.0 + 0.06 * armor)
	return maxf(0.0, damage * (1.0 - reduction))
