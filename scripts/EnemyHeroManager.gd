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

# The only skills with real mechanical effects to simulate - anything
# else a hero knows just never gets cast here. Checked in this order
# when more than one is ready and affordable in the same turn.
const KNOWN_ACTIVE_SKILL_IDS: Array[String] = ["dark_pact", "pounce"]


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
		result.append({"static": staged, "current_hp": float(staged.get("hp", 1))})
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
	var armor: float = float(combat_stats.get("armor", 0))
	var damage_range: String = str(combat_stats.get("damage", "0-0"))

	var current_hp: float = max_hp
	var current_mana: float = max_mana
	var cooldowns: Dictionary = {}
	var xp_gained: float = 0.0
	var gold_gained: int = 0
	var counted_dead: Dictionary = {}
	var result: String = "stalemate"

	for turn_index in range(MAX_SIMULATED_TURNS):
		for skill_id in cooldowns.keys():
			cooldowns[skill_id] = maxi(0, cooldowns[skill_id] - 1)

		var living: Array = _living_enemies(enemies)
		if living.is_empty():
			result = "win"
			break

		# --- Hero's turn: potion, skill, or basic attack - in that
		# priority, one action per turn, same as the player. ---
		if current_hp <= max_hp * LOW_HP_POTION_THRESHOLD and PlayerManager.get_npc_potion_count(hero_id, "health") > 0:
			PlayerManager.set_npc_potion_count(hero_id, "health", PlayerManager.get_npc_potion_count(hero_id, "health") - 1)
			current_hp = minf(max_hp, current_hp + float(GameManager.get_item("health").get("value", 0)))
		else:
			var ready_skill_id: String = _pick_ready_skill(hero_id, hero_static, cooldowns, current_mana)
			if ready_skill_id != "":
				_cast_skill(hero_id, hero_static, ready_skill_id, cooldowns, damage_range, living)
				current_mana -= float(_find_skill(hero_static, ready_skill_id).get("mana_cost", 0))
			elif _has_unaffordable_ready_skill(hero_id, hero_static, cooldowns, current_mana) and PlayerManager.get_npc_potion_count(hero_id, "mana") > 0:
				PlayerManager.set_npc_potion_count(hero_id, "mana", PlayerManager.get_npc_potion_count(hero_id, "mana") - 1)
				current_mana = minf(max_mana, current_mana + float(GameManager.get_item("mana").get("value", 0)))
			else:
				_apply_damage_to_enemy(_lowest_hp_enemy(living), _roll_damage(damage_range))

		# --- Award XP/gold for anything that just died, exactly once. ---
		for i in range(enemies.size()):
			if enemies[i]["current_hp"] <= 0 and not counted_dead.get(i, false):
				counted_dead[i] = true
				xp_gained += float(enemies[i]["static"].get("XP", 0))
				gold_gained += _roll_gold(str(enemies[i]["static"].get("gold", "0-0")))

		living = _living_enemies(enemies)
		if living.is_empty():
			result = "win"
			break

		# --- Enemies retaliate, skipping anyone Pounce just stunned. ---
		for enemy in living:
			var stun_left: int = enemy.get("stun_turns_left", 0)
			if stun_left > 0:
				enemy["stun_turns_left"] = stun_left - 1
				continue
			var enemy_damage: float = float(enemy["static"].get("damage", 0))
			current_hp -= _apply_armor_reduction(enemy_damage, armor)
			if current_hp <= 0:
				break

		if current_hp <= 0:
			result = "loss"
			break

	return {"result": result, "xp_gained": xp_gained, "gold_gained": gold_gained}


func _cast_skill(hero_id: String, hero_static: Dictionary, skill_id: String, cooldowns: Dictionary, damage_range: String, living: Array) -> void:
	var skill: Dictionary = _find_skill(hero_static, skill_id)
	var level: int = PlayerManager.get_npc_skill_level(hero_id, skill_id)
	var level_data: Dictionary = GameManager.get_skill_level_data(skill, level)
	cooldowns[skill_id] = int(level_data.get("cooldown", 0))

	if skill_id == "dark_pact":
		var multiplier: float = float(level_data.get("damage_multiplier", 0.75))
		var dmg: float = _roll_damage(damage_range) * multiplier
		for enemy in living:
			_apply_damage_to_enemy(enemy, dmg)
	else:  # pounce
		var target: Dictionary = _lowest_hp_enemy(living)
		_apply_damage_to_enemy(target, _roll_damage(damage_range))
		if target["current_hp"] > 0:
			target["stun_turns_left"] = int(level_data.get("stun_turns", 1))


## The first known, off-cooldown, currently-affordable active skill,
## in KNOWN_ACTIVE_SKILL_IDS priority order - "" if none qualify right now.
func _pick_ready_skill(hero_id: String, hero_static: Dictionary, cooldowns: Dictionary, current_mana: float) -> String:
	for skill_id in KNOWN_ACTIVE_SKILL_IDS:
		if PlayerManager.get_npc_skill_level(hero_id, skill_id) <= 0:
			continue
		if cooldowns.get(skill_id, 0) > 0:
			continue
		var mana_cost: float = float(_find_skill(hero_static, skill_id).get("mana_cost", 0))
		if current_mana >= mana_cost:
			return skill_id
	return ""


## True if there's a known, off-cooldown active skill that's just
## short on mana right now - the trigger for drinking a Mana Potion
## instead of attacking this turn.
func _has_unaffordable_ready_skill(hero_id: String, hero_static: Dictionary, cooldowns: Dictionary, current_mana: float) -> bool:
	for skill_id in KNOWN_ACTIVE_SKILL_IDS:
		if PlayerManager.get_npc_skill_level(hero_id, skill_id) <= 0:
			continue
		if cooldowns.get(skill_id, 0) > 0:
			continue
		if current_mana < float(_find_skill(hero_static, skill_id).get("mana_cost", 0)):
			return true
	return false


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


func _apply_damage_to_enemy(enemy: Dictionary, amount: float) -> void:
	var mitigated: float = _apply_armor_reduction(amount, float(enemy["static"].get("armor", 0)))
	enemy["current_hp"] -= mitigated


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
