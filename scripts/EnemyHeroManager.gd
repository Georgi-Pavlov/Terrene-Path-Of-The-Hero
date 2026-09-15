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
# no grid/columns, though it does now have both reinforcements (see
# _spawn_npc_reinforcements()) and hero-vs-hero fights (zone-mate
# fights via _try_npc_zone_mate_fight(), invasion duels via
# _try_npc_invasion_duel()). Known simplifications, called out because
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

# Reinforcements - mirrors battle.gd's own REINFORCEMENT_INTERVAL/
# REINFORCEMENT_REPEAT_INTERVAL (kept in sync by hand, same as every
# other simulated number in this file that isn't shared code - see
# _run_stage_fight()/_spawn_npc_reinforcements()): the first wave is
# due after this many turns, every wave after that after another
# REINFORCEMENT_REPEAT_INTERVAL on top, for as long as the fight goes
# on unresolved.
const REINFORCEMENT_INTERVAL: int = 13
const REINFORCEMENT_REPEAT_INTERVAL: int = 10

# Drink a Health Potion once HP falls to (or below) this fraction of
# max. Should stay ABOVE FLEE_HP_THRESHOLD so a hero gets a real chance
# to heal through a fight before it ever gives up on it - previously
# this was 0.2 against a 0.35 flee threshold, so the flee check in
# _run_stage_fight (below LOW_HP_POTION_THRESHOLD's own check in the
# turn loop) always fired first and the potion branch never actually
# triggered during a stage fight. That silently wasted every rival
# hero's 3 banked Health Potions and cut its stage clears - and the
# XP/gold/levels that come with them - far short of what it should
# have earned.
const LOW_HP_POTION_THRESHOLD: float = 0.35

# Flee a stage fight (creeps only - never a hero-vs-hero fight, see
# _try_npc_zone_mate_fight/_try_npc_invasion_duel) once HP falls to (or
# below) this fraction of max - but only once the hero is also out of
# Health Potions (see the explicit potion-count check alongside this
# threshold in _run_stage_fight), so it exhausts its own healing before
# giving up. Kept low and below LOW_HP_POTION_THRESHOLD so a hero only
# disengages once it's both nearly dead and out of options, not the
# moment it dips below a comfortable cushion.
const FLEE_HP_THRESHOLD: float = 0.15

# How much HP/mana a hero recovers when starting a brand new stage-1
# simulation attempt (see simulate_npc_stage_attempt) - a partial
# recovery on top of whatever HP/mana it ended its last attempt with,
# not a full heal. Continuing to a later stage within the SAME attempt
# does not apply this - see simulate_npc_stage_attempt's stage <= 1
# check, mirroring battle.gd's own _advance_to_next_stage() comment
# that stages within one encounter carry HP/mana over as-is.
const NEW_SIM_HP_RESTORE_PCT: float = 0.30
const NEW_SIM_MANA_RESTORE_PCT: float = 0.40

# Every ACTIVE skill across Slark, Lone Druid, Abaddon, Kunkka, Ancient
# Apparition, Winter Wyvern, Crystal Maiden, and Tusk, the only eight
# heroes with any simulated skill logic today - anything else a hero
# knows just never gets cast here. This is the full candidate pool
# _pick_ready_skill() checks for cooldown/worth-casting/mana before
# handing survivors to EnemySkillAI to score and pick from - no longer
# a priority order (see EnemySkillAI.HERO_TIE_BREAK for each hero's own
# tie-break fallback order, only consulted when two skills' scores are
# too close to call outright).
# Savage Roar (Lone Druid's passive), Curse of Avernus and Borrowed
# Time (both Abaddon's), Tidebringer (Kunkka's), and Arcane Aura
# (Crystal Maiden's) aren't in this list - none of them are ever "cast"
# or scored: Savage Roar and Borrowed Time turn themselves on/off
# automatically off the hero's own HP%, same as the player's own copies
# - see _update_npc_savage_roar_state()/_maybe_auto_activate_npc_
# borrowed_time() - Curse of Avernus/Tidebringer only ever build off the
# hero's own plain Attacks - see _apply_npc_curse_of_avernus_stack()/
# _maybe_consume_npc_tidebringer_stack() - and Arcane Aura just
# regenerates mana passively; there's nowhere in this sim's own mana
# bookkeeping for it to hook into yet (see _get_npc_combat_stats()/
# _npc_estimate_damage() for where a future hook would go), so for now
# a simulated Crystal Maiden simply doesn't regenerate mana beyond
# whatever NEW_SIM_MANA_RESTORE_PCT already grants at the start of a
# fresh attempt - same "no benefit invented that doesn't already exist"
# rule this whole file follows elsewhere.
# X Marks the Spot (Kunkka's own other skill) isn't here for a
# different reason: it's purely a positioning tool (mark now, teleport
# onto the target next turn, no damage) with nothing else to it, and
# this sim has no positions at all - every attack already reaches
# "the lowest HP enemy" with no travel cost to begin with, so a
# guaranteed teleport would have literally nothing to accomplish here.
# It's simulated in the real fight (battle.gd's own _enemy_hero_turn())
# since that one has real columns for it to matter on. Tusk's Ice
# Shards is a similar story: its whole "wall off columns" mechanic has
# nothing to act on here (nothing in this sim moves at all - creeps are
# a pure HP pool the hero attacks each turn, never a flee/positioning
# decision of their own), so its sim copy is just a flat hit to the
# primary target, same as every other single-target damage skill's own
# copy (see this file's "ice_shards" case in _cast_skill() below) -
# EnemySkillAI's own _tusk_ice_shards_modifier() already accounts for
# this by falling back to a generic "more living enemies, more a
# control effect is worth" proxy rather than any real column math here.
# Walrus Punch's own knockback/collision is approximated the same way -
# no real destination to walk out, so its sim copy never adds the 50%
# collision bonus at all (see _tusk_walrus_punch_modifier()'s own
# sim-side proxy for how the AI still accounts for the POSSIBILITY of
# one without the actual cast ever guaranteeing it).
# Ghostship (Kunkka's ultimate) IS in this list, unlike X Marks the
# Spot - its whole "everyone the ship's path crosses" concept has no
# columns to work out a path along here, so it falls back to the same
# "no columns, hit everyone" simplification Dark Pact's own sim copy
# already uses (see this file's "dark_pact" case in _cast_skill()
# below). Ice Vortex and Ice Blast (both Ancient Apparition's) use that
# exact same "no columns, hit everyone" fallback for their own AoE, so
# both ARE in this list, same reasoning as Ghostship's. Splinter Blast
# and Winter's Curse (both Winter Wyvern's) use it too - Splinter
# Blast's splash lands on every other living enemy, and Winter's Curse
# redirects every OTHER living enemy's own retaliation onto its frozen
# target instead of the hero (see _cast_skill()'s own "splinter_blast"/
# "winter's_curse" cases and _run_stage_fight()'s own retaliation loop).
const KNOWN_ACTIVE_SKILL_IDS: Array[String] = [
	"dark_pact", "pounce", "essence_shift", "shadow_dance",
	"entangle", "summon_spirit_bear", "spirit_link", "true_form",
	"mist_coil", "aphotic_shield", "torrent", "ghostship",
	"cold_feet", "ice_vortex", "chilling_touch", "ice_blast",
	"arctic_burn", "splinter_blast", "cold_embrace", "winter's_curse",
	"crystal_nova", "frostbite", "freezing_field",
	"ice_shards", "snowball", "tag_team", "walrus_punch",
]

# How many full turns a target can go without being hit by the hero's
# Attack before its un-activated Curse of Avernus stacks are lost (see
# _tick_npc_curse_of_avernus_effects()) - mirrors battle.gd's own
# CURSE_OF_AVERNUS_STACK_DECAY_TURNS.
const CURSE_OF_AVERNUS_STACK_DECAY_TURNS := 3


## Runs one simulated attempt for `hero_id` against whichever zone/
## stage they're currently tracked at (PlayerManager.
## get_npc_current_zone/get_npc_current_stage), applies any XP/gold
## gained, persists the hero's ending HP/mana, and advances or resets
## their stage progress based on the result. Returns {"result":
## "win"/"loss"/"stalemate"/"flee", "xp_gained": float, "gold_gained":
## int} for the caller (e.g. Step 6's kill/progress messaging) to
## react to.
## Stage 1 is treated as the start of a brand new simulation attempt -
## HP/mana partially recover from wherever the hero ended its last
## attempt (NEW_SIM_HP_RESTORE_PCT/NEW_SIM_MANA_RESTORE_PCT), same as a
## real player starting a fresh Battle-scene visit. Any later stage
## (2, 3, ...) is treated as continuing that same attempt - no
## restore, HP/mana just carry over as-is, mirroring battle.gd's own
## _advance_to_next_stage().
## This does not yet know about zone-mate hero fights or becoming
## "freed" to invade (Step 5) - clearing the final stage here just
## caps at the final stage rather than advancing past it.
func simulate_npc_stage_attempt(hero_id: String, hero_static: Dictionary) -> Dictionary:
	var zone_id: String = PlayerManager.get_npc_current_zone(hero_id)
	var stage: int = PlayerManager.get_npc_current_stage(hero_id)

	var combat_stats: Dictionary = _get_npc_combat_stats(hero_id, hero_static)
	var max_hp: float = float(combat_stats.get("hp", 1))
	var max_mana: float = float(combat_stats.get("mana", 0))

	var starting_hp: float
	var starting_mana: float
	if stage <= 1:
		starting_hp = minf(PlayerManager.get_npc_current_hp(hero_id) + max_hp * NEW_SIM_HP_RESTORE_PCT, max_hp)
		starting_mana = minf(PlayerManager.get_npc_current_mana(hero_id) + max_mana * NEW_SIM_MANA_RESTORE_PCT, max_mana)
	else:
		starting_hp = PlayerManager.get_npc_current_hp(hero_id)
		starting_mana = PlayerManager.get_npc_current_mana(hero_id)

	var enemies: Array = _build_simulated_stage_enemies(zone_id, stage)
	var fight: Dictionary = _run_stage_fight(hero_id, hero_static, enemies, starting_hp, starting_mana, true, zone_id, stage)

	PlayerManager.set_npc_current_hp(hero_id, fight["ending_hp"])
	PlayerManager.set_npc_current_mana(hero_id, fight["ending_mana"])

	if fight["xp_gained"] > 0.0:
		award_npc_xp(hero_id, hero_static, fight["xp_gained"])
	if fight["gold_gained"] > 0:
		PlayerManager.add_npc_gold(hero_id, fight["gold_gained"])

	if fight["result"] == "win":
		PlayerManager.set_npc_current_stage(hero_id, mini(stage + 1, GameManager.MAX_ZONE_STAGE))
	else:
		# Loss, stalemate, or a flee - reset to stage 1, mirroring the
		# player's own reset-on-failure rule. HP/mana were already
		# persisted just above, so the next fresh attempt's restore
		# picks up from wherever this one left off (a flee keeps far
		# more of that pool than dying to 0 HP does).
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
## via GameManager.build_hero_fight_enemy_def(), just simulated. The
## player's own recruited hero is excluded from the candidate pool even
## if they share this zone (mirrors battle.gd's own _get_eligible_hero_
## fight_heroes() exclusion, and _pick_invasion_target()'s below) - the
## player controls that hero directly, so a background sim killing them
## off would surface as their own hero getting "slain" out from under
## them mid-playthrough. If no OTHER zone-mate is left alive, this hero
## is now free.
## Winning uses the XP bounty formula (get_hero_kill_bounty) rather
## than the enemy_def's own built-in XP field, since that field is
## sized for a flat creep-style reward, not a hero kill - gold still
## comes from the enemy_def as normal, since only the XP formula was
## asked to change for hero kills.
func _try_npc_zone_mate_fight(hero_id: String, hero_static: Dictionary) -> void:
	var home_zone_id: String = GameManager.get_zone_id_for_hero(hero_id)
	var player_hero_id: String = PlayerManager.get_recruited_hero().get("id", "")
	var zone_mates: Array = []
	for hero in GameManager.get_zone(home_zone_id).get("heroes", []):
		var mate_id: String = hero.get("id", "")
		if mate_id == hero_id or mate_id == player_hero_id or PlayerManager.is_hero_defeated(mate_id):
			continue
		zone_mates.append(hero)

	if zone_mates.is_empty():
		PlayerManager.set_npc_freed(hero_id)
		return

	var opponent_static: Dictionary = zone_mates[randi() % zone_mates.size()]
	var opponent_id: String = opponent_static.get("id", "")

	var enemy_def: Dictionary = GameManager.build_hero_fight_enemy_def(opponent_static)
	var enemies: Array = [{"static": enemy_def, "current_hp": float(enemy_def.get("hp", 1))}]

	# Hero-vs-hero fights always start both sides at full HP/mana with
	# whatever items they have - no partial-recovery carryover from the
	# creep grind, and no flee option (allow_flee = false): it's a
	# fight to the death, or a stalemate if 30 turns pass with neither
	# hero dead. This deliberately doesn't touch the hero's persisted
	# grind HP/mana (PlayerManager.get/set_npc_current_hp/mana) - those
	# pick back up exactly where the creep grind left them next time.
	var combat_stats: Dictionary = _get_npc_combat_stats(hero_id, hero_static)
	var max_hp: float = float(combat_stats.get("hp", 1))
	var max_mana: float = float(combat_stats.get("mana", 0))
	var fight: Dictionary = _run_stage_fight(hero_id, hero_static, enemies, max_hp, max_mana, false, home_zone_id, GameManager.MAX_ZONE_STAGE)

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

	# Same rules as _try_npc_zone_mate_fight: full HP/mana for both
	# sides, no flee, fight to the death or a 30-turn stalemate - and
	# this doesn't touch the hero's persisted grind HP/mana either.
	# Reinforcements (if the duel runs long enough to trigger any) pull
	# from the TARGET's own zone roster, same as the duel itself being
	# staged there.
	var combat_stats: Dictionary = _get_npc_combat_stats(hero_id, hero_static)
	var max_hp: float = float(combat_stats.get("hp", 1))
	var max_mana: float = float(combat_stats.get("mana", 0))
	var fight: Dictionary = _run_stage_fight(hero_id, hero_static, enemies, max_hp, max_mana, false, GameManager.get_zone_id_for_hero(target_id), GameManager.MAX_ZONE_STAGE)

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


## Appends a reinforcement wave straight into `enemies` in place -
## called from _run_stage_fight() once every REINFORCEMENT_INTERVAL/
## REINFORCEMENT_REPEAT_INTERVAL turns, mirroring battle.gd's own
## _spawn_reinforcements(). `allow_flee` doubles as "is this a normal
## creep stage fight" (see _run_stage_fight()'s own doc on what that
## flag distinguishes): a stage fight gets the smaller
## GameManager.REINFORCEMENT_ENEMY_COUNTS top-up for `stage`, while a
## hero-vs-hero duel (allow_flee == false) always gets the FULL stage 3
## GameManager.STAGE_ENEMY_COUNTS composition instead, regardless of
## `stage` - a boss fight already means business, so its own
## reinforcements hit as hard as an entire fresh stage 3 wave rather
## than a token trickle, exactly matching battle.gd's own hero-fight
## exception in _spawn_reinforcements(). Built via
## _build_stage_enemy_batch(), the same helper _build_simulated_stage_
## enemies() uses for a fight's opening wave, so reinforcements come in
## scaled to whichever stage they're actually sized at.
func _spawn_npc_reinforcements(enemies: Array, zone_id: String, stage: int, allow_flee: bool) -> void:
	var zone_data: Dictionary = GameManager.get_zone(zone_id)
	var enemy_defs: Array = zone_data.get("enemies", [])

	var mele_templates: Array = []
	var range_templates: Array = []
	for enemy_def in enemy_defs:
		if enemy_def.get("type", "") == "range":
			range_templates.append(enemy_def)
		else:
			mele_templates.append(enemy_def)

	var reinforcement_stage: int = stage if allow_flee else GameManager.MAX_ZONE_STAGE
	var counts: Dictionary = (
		GameManager.get_reinforcement_enemy_counts(reinforcement_stage) if allow_flee
		else GameManager.get_stage_enemy_counts(reinforcement_stage)
	)

	enemies.append_array(_build_stage_enemy_batch(mele_templates, int(counts.get("mele", 0)), reinforcement_stage))
	enemies.append_array(_build_stage_enemy_batch(range_templates, int(counts.get("range", 0)), reinforcement_stage))


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
## `starting_hp`/`starting_mana` are whatever the hero has going into
## this fight (see call sites for how that's worked out) rather than
## always a full heal, and the fight's ending HP/mana come back out in
## the result so the caller can persist them. `allow_flee` gates
## FLEE_HP_THRESHOLD - only ever true for stage fights against creeps;
## hero-vs-hero fights (_try_npc_zone_mate_fight/
## _try_npc_invasion_duel) pass false, since those have no flee option.
## `zone_id`/`stage` are only used for reinforcements (see
## _spawn_npc_reinforcements()) - `zone_id` says whose enemy roster to
## pull from, `stage` says how strong a creep-fight's own top-up should
## be (ignored in favor of a flat MAX_ZONE_STAGE for a hero-vs-hero
## fight, which always throws the full stage 3 composition instead -
## see _spawn_npc_reinforcements()'s own doc).
func _run_stage_fight(hero_id: String, hero_static: Dictionary, enemies: Array, starting_hp: float, starting_mana: float, allow_flee: bool, zone_id: String, stage: int) -> Dictionary:
	var combat_stats: Dictionary = _get_npc_combat_stats(hero_id, hero_static)
	var max_hp: float = float(combat_stats.get("hp", 1))
	var max_mana: float = float(combat_stats.get("mana", 0))
	var base_armor: float = float(combat_stats.get("armor", 0))
	var damage_range: String = str(combat_stats.get("damage", "0-0"))

	var current_hp: float = clampf(starting_hp, 0.0, max_hp)
	var current_mana: float = clampf(starting_mana, 0.0, max_mana)
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

	# Reinforcements - mirrors battle.gd's own _turn_count/
	# _next_reinforcement_turn pair: the first wave is due after
	# REINFORCEMENT_INTERVAL turns, every wave after that after another
	# REINFORCEMENT_REPEAT_INTERVAL on top, for as long as this attempt
	# keeps going. turn_index is 0-based, so "+1" turns it into the same
	# 1-based turn count battle.gd's own _turn_count tracks.
	var next_reinforcement_turn: int = REINFORCEMENT_INTERVAL

	for turn_index in range(MAX_SIMULATED_TURNS):
		if turn_index + 1 >= next_reinforcement_turn:
			_spawn_npc_reinforcements(enemies, zone_id, stage, allow_flee)
			next_reinforcement_turn += REINFORCEMENT_REPEAT_INTERVAL

		for skill_id in cooldowns.keys():
			cooldowns[skill_id] = maxi(0, cooldowns[skill_id] - 1)

		_tick_npc_essence_shift(state["essence_shift"])
		_tick_npc_shadow_dance(state["shadow_dance"])
		_tick_npc_spirit_link(state["spirit_link"])
		_tick_npc_true_form(state["true_form"])
		_tick_npc_aphotic_shield(state["aphotic_shield"])
		_tick_npc_borrowed_time(state["borrowed_time"])
		_tick_npc_tag_team(state["tag_team"])
		_tick_npc_entangle_effects(enemies)
		_tick_npc_curse_of_avernus_effects(enemies, turn_index)
		_tick_npc_cold_feet_effects(enemies)
		_tick_npc_ice_vortex_effects(enemies)
		_tick_npc_ice_blast_effects(enemies)
		_tick_npc_frostbite_effects(enemies)
		_tick_npc_freezing_field(state["freezing_field"], enemies)
		var kills: Dictionary = _collect_npc_kills(enemies, counted_dead)
		xp_gained += kills["xp"]
		gold_gained += kills["gold"]

		var effective_max_hp: float = _npc_effective_max_hp(max_hp, state)
		current_hp = _tick_npc_cold_embrace(state["cold_embrace"], current_hp, effective_max_hp)
		_update_npc_savage_roar_state(hero_id, hero_static, state["savage_roar"], current_hp, effective_max_hp)

		var living: Array = _living_enemies(enemies)
		if living.is_empty():
			result = "win"
			break

		if allow_flee and current_hp <= effective_max_hp * FLEE_HP_THRESHOLD and PlayerManager.get_npc_potion_count(hero_id, "health") <= 0:
			result = "flee"
			break

		# --- Hero's turn: potion, skill, or basic attack - in that
		# priority, one action per turn, same as the player. ---
		var acted_with: String = ""
		if state["cold_embrace"]["active"]:
			# Encased in ice - can't move, attack, cast another skill, or
			# drink a potion, matching battle.gd's own copy (both the
			# player's and a duel boss's) which locks every action the
			# same way for the duration; its immunity/heal-per-turn
			# already run via _tick_npc_cold_embrace() and the
			# retaliation guard below regardless of what this turn does.
			pass
		elif current_hp <= effective_max_hp * LOW_HP_POTION_THRESHOLD and PlayerManager.get_npc_potion_count(hero_id, "health") > 0:
			PlayerManager.set_npc_potion_count(hero_id, "health", PlayerManager.get_npc_potion_count(hero_id, "health") - 1)
			current_hp = minf(effective_max_hp, current_hp + float(GameManager.get_item("health").get("value", 0)))
		else:
			var ai_context: Dictionary = _build_npc_ai_context(hero_id, hero_static, current_hp, effective_max_hp, current_mana, max_mana, damage_range, state, living)
			var ready_skill_id: String = _pick_ready_skill(hero_id, hero_static, cooldowns, current_mana, state, ai_context)
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
				var tidebringer_level_data: Dictionary = _maybe_consume_npc_tidebringer_stack(hero_id, hero_static, state)
				var tidebringer_bonus: float = float(tidebringer_level_data.get("bonus_damage", 0.0))
				var dmg: float = _npc_roll_damage(damage_range, state, shadow_bonus + tidebringer_bonus)
				var mitigated: float = _apply_damage_to_enemy(target, dmg)
				_apply_npc_essence_shift_steal(target, state["essence_shift"], hero_static)
				_apply_npc_curse_of_avernus_stack(hero_id, hero_static, target, turn_index)
				if not tidebringer_level_data.is_empty():
					_apply_npc_tidebringer_cleave(target, dmg, tidebringer_level_data, living)
				_apply_npc_arctic_burn_attack(state["arctic_burn"])
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

		# --- Enemies retaliate, skipping anyone Pounce just stunned,
		# while Shadow Dance is hiding the hero entirely (mirrors
		# battle.gd's _is_hero_hidden() check in _enemy_turn()), or while
		# Cold Embrace makes the hero fully immune (mirrors battle.gd's
		# own _deal_fixed_damage_to_enemy() check - skipping this whole
		# block is equivalent, since nothing else in this sim can damage
		# the hero). While Winter's Curse is active, every OTHER living
		# enemy piles onto its frozen target instead of the hero, for
		# bonus_damage_pct extra damage - see KNOWN_ACTIVE_SKILL_IDS's
		# own "no columns, redirect everyone" comment. curse_target/
		# curse_active are captured once here, before the loop, mirroring
		# battle.gd's own _enemy_turn(): the target's own stun_turns_left
		# (what curse_active is actually derived from) ticks down
		# partway through this same loop once its turn comes up, so
		# every enemy this pass needs to see the same answer regardless
		# of iteration order. ---
		if not state["shadow_dance"]["active"] and not state["cold_embrace"]["active"]:
			var effective_armor: float = _npc_effective_armor(base_armor, state)
			var curse_target: Dictionary = state["winters_curse"].get("target_ref", {})
			var curse_active: bool = not curse_target.is_empty() and int(curse_target.get("stun_turns_left", 0)) > 0
			var curse_multiplier: float = 1.0 + float(state["winters_curse"].get("bonus_damage_pct", 0.0))

			for enemy in living:
				var stun_left: int = enemy.get("stun_turns_left", 0)
				if stun_left > 0:
					enemy["stun_turns_left"] = stun_left - 1
					continue

				var enemy_damage: float = float(enemy["static"].get("damage", 0))

				if curse_active and not is_same(enemy, curse_target):
					_apply_damage_to_enemy(curse_target, enemy_damage * curse_multiplier)
					continue

				var reduced: float = _apply_armor_reduction(enemy_damage, effective_armor)
				reduced *= (1.0 - float(state["savage_roar"].get("damage_reduction_pct", 0.0)))
				current_hp = _apply_reduced_damage_to_npc(hero_id, hero_static, state, cooldowns, current_hp, effective_max_hp, reduced, living)
				if current_hp <= 0:
					break

		if current_hp <= 0:
			result = "loss"
			break

	return {
		"result": result,
		"xp_gained": xp_gained,
		"gold_gained": gold_gained,
		"ending_hp": maxf(current_hp, 0.0),
		"ending_mana": current_mana,
	}


## Fresh per-attempt state for every buff/debuff-carrying skill -
## mirrors the shape (and defaults) of battle.gd's own
## _essence_shift_*/_shadow_dance_*/_spirit_link_*/_true_form_*/
## _aphotic_shield_*/_borrowed_time_*/_bear instance variables, just
## bundled into one Dictionary here since this state only needs to live
## for the duration of one _run_stage_fight() call rather than the
## whole scene's lifetime.
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
		"aphotic_shield": {"active": false, "hp": 0.0, "aoe_damage": 0.0, "turns_remaining": 0, "duration_pending_start": false},
		"borrowed_time": {"active": false, "heal_conversion_pct": 0.0, "turns_remaining": 0, "duration_pending_start": false},
		"bear": {},
		"savage_roar": {"active": false, "damage_reduction_pct": 0.0},
		"tidebringer_attack_count": 0,
		"arctic_burn": {"active": false, "bonus_damage": 0.0, "bonus_range": 0, "attacks_remaining": 0, "turns_remaining": 0, "duration_pending_start": false},
		"cold_embrace": {"active": false, "heal_per_turn": 0.0, "turns_remaining": 0, "duration_pending_start": false},
		"winters_curse": {"target_ref": {}, "bonus_damage_pct": 0.0},
		"freezing_field": {"active": false, "damage_per_turn": 0.0, "turns_remaining": 0, "duration_pending_start": false},
		"tag_team": {"active": false, "bonus_damage": 0.0, "turns_remaining": 0, "duration_pending_start": false},
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
		"mist_coil":
			_apply_damage_to_enemy(_lowest_hp_enemy(living), float(level_data.get("damage", 0)))
		"aphotic_shield":
			_activate_npc_aphotic_shield(state["aphotic_shield"], level_data)
		"torrent":
			var target: Dictionary = _lowest_hp_enemy(living)
			var damage: float = float(level_data.get("damage", 0))
			_apply_damage_to_enemy(target, damage)
			if target["current_hp"] > 0:
				target["stun_turns_left"] = int(level_data.get("stun_turns", 1))
			# Level 4's small splash radius has no columns to be
			# "around the target" in this positionless sim, so it
			# falls back to the same "no columns, hit everyone else"
			# simplification Dark Pact/Aphotic Shield's own explosion
			# already use here (see this match's "dark_pact" case
			# above and _end_npc_aphotic_shield()).
			if int(level_data.get("radius", 0)) > 0:
				for enemy in living:
					if is_same(enemy, target):
						continue
					_apply_damage_to_enemy(enemy, damage)
		"ghostship":
			# The real ship travels a straight line from the hero to
			# one marked target, damaging everyone caught in between -
			# no columns here to work that path out along, so (see
			# KNOWN_ACTIVE_SKILL_IDS's own comment above) it falls back
			# to hitting every living enemy, same as Dark Pact.
			var ghostship_damage: float = float(level_data.get("damage", 0))
			for enemy in living:
				_apply_damage_to_enemy(enemy, ghostship_damage)
		"cold_feet":
			var cold_feet_target: Dictionary = _lowest_hp_enemy(living)
			cold_feet_target["cold_feet_dot_damage"] = float(level_data.get("damage", 0))
			cold_feet_target["cold_feet_dot_turns_left"] = int(level_data.get("duration", 0))
		"ice_vortex":
			# No columns to center an AoE on a specific position here -
			# same "no columns, hit everyone" fallback Dark Pact's/
			# Torrent's/Ghostship's own sim copies already use (see
			# KNOWN_ACTIVE_SKILL_IDS's own comment above), so the DoT
			# lands on every living enemy instead of just whichever one
			# would've been at its center.
			var vortex_damage: float = float(level_data.get("damage", 0))
			var vortex_duration: int = int(level_data.get("duration", 0))
			for enemy in living:
				enemy["ice_vortex_dot_damage"] = vortex_damage
				enemy["ice_vortex_dot_turns_left"] = vortex_duration
		"chilling_touch":
			var chilling_touch_target: Dictionary = _lowest_hp_enemy(living)
			var chilling_touch_damage: float = _npc_roll_damage(damage_range, state) + float(level_data.get("bonus_damage", 0))
			_apply_damage_to_enemy(chilling_touch_target, chilling_touch_damage)
		"ice_blast":
			# Same "no columns, hit everyone" fallback as Ghostship/Ice
			# Vortex above - every living enemy is within its own AoE
			# radius here, so there's no separate "pick the best
			# target/position" step the way the real fight's own
			# _cast_enemy_ice_blast() (which only ever has the player to
			# hit anyway) or the player's own multi-enemy _resolve_ice_
			# blast_cast() need one. Only the stun singles out one
			# target, the same "primary target only" rule Torrent's own
			# sim copy uses for its own stun.
			var blast_damage: float = float(level_data.get("damage", 0))
			var blast_dot_damage: float = float(level_data.get("dot_damage", 0))
			var blast_dot_duration: int = int(level_data.get("dot_duration", 0))
			var blast_execute_pct: float = float(level_data.get("execute_pct", 0.0))
			var blast_primary: Dictionary = _lowest_hp_enemy(living)
			for enemy in living:
				_apply_damage_to_enemy(enemy, blast_damage)
				if enemy["current_hp"] > 0:
					enemy["ice_blast_dot_damage"] = blast_dot_damage
					enemy["ice_blast_dot_turns_left"] = blast_dot_duration
					enemy["ice_blast_execute_pct"] = blast_execute_pct
			if blast_primary["current_hp"] > 0:
				blast_primary["stun_turns_left"] = int(level_data.get("stun_turns", 1))
		"arctic_burn":
			_activate_npc_arctic_burn(state["arctic_burn"], level_data)
		"splinter_blast":
			# No columns to single out "every OTHER enemy within
			# splinter_range" here - same "no columns, hit everyone"
			# fallback Torrent's/Ice Vortex's own sim copies already use
			# (see KNOWN_ACTIVE_SKILL_IDS's own comment above), so the
			# primary target takes the full hit and every other living
			# enemy takes the (lighter) splinter hit.
			var splinter_primary: Dictionary = _lowest_hp_enemy(living)
			_apply_damage_to_enemy(splinter_primary, float(level_data.get("damage", 0)))
			var splinter_damage: float = float(level_data.get("splinter_damage", 0))
			for enemy in living:
				if is_same(enemy, splinter_primary):
					continue
				_apply_damage_to_enemy(enemy, splinter_damage)
		"cold_embrace":
			_dispel_all_npc_effects(state)
			_activate_npc_cold_embrace(state["cold_embrace"], level_data)
		"winter's_curse":
			# No columns to check curse_range against here - same "no
			# columns, redirect everyone" fallback the AoE skills above
			# use, so EVERY other living enemy (not just ones within some
			# range of the frozen target) piles onto it instead of the
			# hero for as long as the freeze holds - see
			# _run_stage_fight()'s own retaliation loop, which reads
			# state["winters_curse"] every turn.
			var curse_target: Dictionary = _lowest_hp_enemy(living)
			curse_target["stun_turns_left"] = int(level_data.get("duration", 0))
			state["winters_curse"] = {
				"target_ref": curse_target,
				"bonus_damage_pct": float(level_data.get("bonus_damage_pct", 0.0)),
			}
		"crystal_nova":
			# No columns to check radius against here - same "no columns,
			# hit everyone else" fallback Torrent's level-4 splash uses
			# (see this match's "torrent" case above) once Crystal Nova's
			# own radius actually exists (level 3+); at levels 1-2
			# (radius 0) it's a single-target nuke same as everywhere else.
			var nova_primary: Dictionary = _lowest_hp_enemy(living)
			var nova_damage: float = float(level_data.get("damage", 0))
			_apply_damage_to_enemy(nova_primary, nova_damage)
			if int(level_data.get("radius", 0)) > 0:
				for enemy in living:
					if is_same(enemy, nova_primary):
						continue
					_apply_damage_to_enemy(enemy, nova_damage)
		"frostbite":
			# Single-target control, same "whichever enemy the hero would
			# attack anyway" target as Cold Feet/Torrent's own primary hit.
			var frostbite_target: Dictionary = _lowest_hp_enemy(living)
			frostbite_target["frostbite_dot_damage"] = float(level_data.get("dot_damage", 0))
			frostbite_target["frostbite_dot_turns_left"] = int(level_data.get("dot_duration", 0))
			if frostbite_target["current_hp"] > 0:
				frostbite_target["stun_turns_left"] = int(level_data.get("stun_turns", 1))
		"freezing_field":
			_activate_npc_freezing_field(state["freezing_field"], level_data)
		"ice_shards":
			# The wall itself has nothing to act on here - nothing in this
			# sim moves at all (see KNOWN_ACTIVE_SKILL_IDS's own comment
			# above) - so this is just a flat hit to the primary target,
			# same as Mist Coil/Chilling Touch's own sim copies.
			_apply_damage_to_enemy(_lowest_hp_enemy(living), float(level_data.get("damage", 0)))
		"snowball":
			var snowball_target: Dictionary = _lowest_hp_enemy(living)
			_apply_damage_to_enemy(snowball_target, float(level_data.get("damage", 0)))
			if snowball_target["current_hp"] > 0:
				snowball_target["stun_turns_left"] = int(level_data.get("stun_turns", 1))
		"tag_team":
			_activate_npc_tag_team(state["tag_team"], level_data)
		"walrus_punch":
			# No real knockback/collision to resolve here (see
			# KNOWN_ACTIVE_SKILL_IDS's own comment above) - just the base
			# hero_damage x damage_multiplier hit, same "no columns" honesty
			# every other position-dependent skill's own sim copy has.
			var punch_target: Dictionary = _lowest_hp_enemy(living)
			var punch_multiplier: float = float(level_data.get("damage_multiplier", 1.0))
			var punch_dmg: float = _npc_roll_damage(damage_range, state) * punch_multiplier
			_apply_damage_to_enemy(punch_target, punch_dmg)
			if punch_target["current_hp"] > 0:
				punch_target["stun_turns_left"] = int(level_data.get("stun_turns", 1))


func _get_npc_skill_level_data(hero_id: String, hero_static: Dictionary, skill_id: String) -> Dictionary:
	var skill: Dictionary = _find_skill(hero_static, skill_id)
	var level: int = PlayerManager.get_npc_skill_level(hero_id, skill_id)
	return GameManager.get_skill_level_data(skill, level)


## The mana cost of `skill_id` at this NPC's current level - unlike a
## flat top-level "mana_cost" field (which none of these skills
## actually have), this reads the correct per-level value the same way
## GameManager.get_skill_level_data()/battle.gd's own cast paths do.
func _npc_skill_mana_cost(hero_id: String, hero_static: Dictionary, skill_id: String) -> float:
	return float(_get_npc_skill_level_data(hero_id, hero_static, skill_id).get("mana_cost", 0))


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
		"aphotic_shield":
			return not state["aphotic_shield"]["active"]
		"arctic_burn":
			return not state["arctic_burn"]["active"]
		"cold_embrace":
			return not state["cold_embrace"]["active"]
		"freezing_field":
			return not state["freezing_field"]["active"]
		"tag_team":
			return not state["tag_team"]["active"]
		_:
			return true


## Every known, off-cooldown, currently-worthwhile, currently-
## affordable skill in KNOWN_ACTIVE_SKILL_IDS, PLUS a plain Attack for
## whichever heroes EnemySkillAI.basic_attack_participates() opts in
## (today: only Kunkka, whose Tidebringer can make a plain Attack the
## better play), is scored by EnemySkillAI.evaluate_skill()/
## evaluate_basic_attack() against `ai_context`, and the highest-scoring
## one wins (ties resolved by EnemySkillAI - see pick_best_skill()) -
## "" if none qualify right now, or if the plain-Attack candidate won
## (either way the caller's own existing basic-attack fallback takes
## over unchanged). This replaces the old "first match in
## KNOWN_ACTIVE_SKILL_IDS wins" rule; the array is still every skill
## this AI ever considers, it's just no longer the order they're
## preferred in - see battle.gd's own _pick_enemy_ready_skill() for the
## real-fight mirror of this same scoring, shared through EnemySkillAI
## rather than duplicated.
func _pick_ready_skill(hero_id: String, hero_static: Dictionary, cooldowns: Dictionary, current_mana: float, state: Dictionary, ai_context: Dictionary) -> String:
	var candidates: Array = []

	for skill_id in KNOWN_ACTIVE_SKILL_IDS:
		if PlayerManager.get_npc_skill_level(hero_id, skill_id) <= 0:
			continue
		if cooldowns.get(skill_id, 0) > 0:
			continue
		if not _npc_skill_worth_casting(skill_id, state):
			continue
		var level_data: Dictionary = _get_npc_skill_level_data(hero_id, hero_static, skill_id)
		if current_mana < float(level_data.get("mana_cost", 0)):
			continue
		candidates.append({"id": skill_id, "score": EnemySkillAI.evaluate_skill(skill_id, level_data, ai_context)})

	var archetype: String = str(ai_context.get("archetype", ""))
	if EnemySkillAI.basic_attack_participates(archetype):
		candidates.append({"id": EnemySkillAI.BASIC_ATTACK_ID, "score": EnemySkillAI.evaluate_basic_attack(ai_context)})

	var chosen_id: String = EnemySkillAI.pick_best_skill(archetype, candidates, str(hero_static.get("name", hero_id)))
	return "" if chosen_id == EnemySkillAI.BASIC_ATTACK_ID else chosen_id


## Builds the AI context EnemySkillAI scores every candidate skill
## against for this NPC's turn - the simulation counterpart of
## battle.gd's own _build_enemy_ai_context(). Simplified versus the
## real fight the same way the rest of this sim already is: no
## positions, so no target_distance (and no "kunkka_torrent_combo_
## ready"/"kunkka_ghostship_combo_ready" - X Marks the Spot isn't even a
## candidate here, see KNOWN_ACTIVE_SKILL_IDS's own comment, so nothing
## ever reads those two), and `target` is always whichever living enemy
## the hero would attack anyway (_lowest_hp_enemy()), since that's the
## only target this sim's basic attack (and most of its skills) ever
## considers. `living_target_hps`/`living_target_max_hps` are every
## living enemy's own current/max HP, for EnemySkillAI's shared multi-
## kill/execute scoring (see Ghostship's/Torrent's own modifiers, which
## need to know how many OTHER targets a hit would also kill, not just
## the primary one `target_hp` covers, and Ancient Apparition's own Ice
## Blast modifier, which needs each target's own max HP to work out its
## execute threshold).
##
## Winter Wyvern's own fields:
##   - in_attack_range_now/in_attack_range_with_arctic_burn_bonus: always
##     true here - this sim's basic attack already reaches whichever
##     living enemy it targets with no travel cost at all (same reason
##     X Marks the Spot isn't even a candidate here), so there's no
##     "can't reach the target" case to model the way battle.gd's real
##     columns have one.
##   - arctic_burn_active: mirrors battle.gd's own field, just reading
##     `state` instead of an instance var.
##   - has_harmful_debuff: always false - nothing in this sim ever
##     debuffs the simulated hero itself (only ITS OWN skills debuff the
##     enemies it's fighting - see _tick_npc_entangle_effects() and
##     friends), so Cold Embrace never has a harmful effect on the hero
##     to dispel here, unlike a real hero fight where the player's own
##     skills can land on the rival boss.
##   - redirect_candidate_count/avg_enemy_damage: for Winter Wyvern's own
##     Winter's Curse - every OTHER living enemy is a redirect candidate
##     here (see _run_stage_fight()'s own retaliation loop, which
##     redirects all of them, not just ones "in range" - there are no
##     columns to check a curse_range against), and their average damage
##     stat, for estimating the bonus damage the curse would generate.
func _build_npc_ai_context(hero_id: String, hero_static: Dictionary, current_hp: float, effective_max_hp: float, current_mana: float, max_mana: float, damage_range: String, state: Dictionary, living: Array) -> Dictionary:
	var target: Dictionary = {} if living.is_empty() else _lowest_hp_enemy(living)

	var tidebringer_level_data: Dictionary = _get_npc_tidebringer_level_data(hero_id, hero_static)
	var tidebringer_ready: bool = not tidebringer_level_data.is_empty() \
		and (int(state.get("tidebringer_attack_count", 0)) + 1) >= int(tidebringer_level_data.get("hits_to_activate", 1))

	var total_enemy_damage: float = 0.0
	for enemy in living:
		total_enemy_damage += float(enemy["static"].get("damage", 0))
	var avg_enemy_damage: float = total_enemy_damage / float(living.size()) if not living.is_empty() else 0.0

	return {
		"game_mode": "simulation",
		"archetype": EnemySkillAI.resolve_hero_archetype(hero_static),
		"hero_hp": current_hp,
		"hero_max_hp": effective_max_hp,
		"hero_hp_ratio": (current_hp / effective_max_hp) if effective_max_hp > 0.0 else 0.0,
		"hero_mana": current_mana,
		"hero_max_mana": max_mana,
		"hero_damage": _npc_estimate_damage(damage_range, state),
		"enemy_count": living.size(),
		"target_hp": float(target.get("current_hp", 0.0)) if not target.is_empty() else 0.0,
		"target_max_hp": float(target.get("static", {}).get("hp", 0.0)) if not target.is_empty() else 0.0,
		"bear_active": not state["bear"].is_empty(),
		"living_target_hps": living.map(func(e): return float(e.get("current_hp", 0.0))),
		"living_target_max_hps": living.map(func(e): return float(e["static"].get("hp", 1))),
		"tidebringer_ready": tidebringer_ready,
		"tidebringer_bonus_damage": float(tidebringer_level_data.get("bonus_damage", 0.0)),
		"tidebringer_cleave_targets": maxi(living.size() - 1, 0) if tidebringer_ready else 0,
		"in_attack_range_now": true,
		"in_attack_range_with_arctic_burn_bonus": true,
		"arctic_burn_active": bool(state["arctic_burn"]["active"]),
		"has_harmful_debuff": false,
		"redirect_candidate_count": maxi(living.size() - 1, 0),
		"avg_enemy_damage": avg_enemy_damage,
	}


## A deterministic (no randi_range) midpoint damage estimate for AI
## scoring only - actual damage still rolls randomly via
## _npc_roll_damage() when a skill/attack actually lands. Keeps skill
## scoring reproducible instead of jittering on every single evaluation
## on top of EnemySkillAI's own controlled randomness.
func _npc_estimate_damage(damage_range: String, state: Dictionary) -> float:
	var parts: PackedStringArray = damage_range.split("-")
	var min_dmg: float = float(parts[0]) if parts.size() > 0 else 0.0
	var max_dmg: float = float(parts[1]) if parts.size() > 1 else min_dmg
	var bonus_damage: float = state["essence_shift"]["bonus"].get("damage", 0.0) + state["true_form"]["bonus_damage"] + state["tag_team"]["bonus_damage"]
	return (min_dmg + max_dmg) / 2.0 + bonus_damage


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
# Ancient Apparition's Cold Feet/Ice Vortex - both plain damage-over-
# time, so both mirror _tick_npc_entangle_effects()'s own DoT half
# exactly, just against their own dedicated per-enemy fields (see
# battle.gd's _resolve_cold_feet_cast()/_resolve_ice_vortex_cast() for
# why they're kept separate from Entangle's own DoT fields).
# ------------------------------------------------------------------

func _tick_npc_cold_feet_effects(enemies: Array) -> void:
	for enemy in enemies:
		if enemy.get("cold_feet_dot_turns_left", 0) > 0:
			enemy["cold_feet_dot_turns_left"] -= 1
			var dot_damage: float = float(enemy.get("cold_feet_dot_damage", 0))
			if dot_damage > 0.0 and enemy.get("current_hp", 0) > 0:
				_apply_damage_to_enemy(enemy, dot_damage)


func _tick_npc_ice_vortex_effects(enemies: Array) -> void:
	for enemy in enemies:
		if enemy.get("ice_vortex_dot_turns_left", 0) > 0:
			enemy["ice_vortex_dot_turns_left"] -= 1
			var dot_damage: float = float(enemy.get("ice_vortex_dot_damage", 0))
			if dot_damage > 0.0 and enemy.get("current_hp", 0) > 0:
				_apply_damage_to_enemy(enemy, dot_damage)


## Ticks Ice Blast's damage-over-time down by one turn for every enemy
## currently carrying it, then - if it survived that hit - checks its
## execute threshold: an enemy whose current_hp has dropped to or below
## execute_pct of its own max HP dies outright, regardless of how much
## literal HP it has left, mirroring battle.gd's own _tick_ice_blast_
## effects(). Setting current_hp to 0 is enough to register as a kill
## here - _collect_npc_kills() (called right after this, in
## _run_stage_fight()'s own top-of-turn block) credits XP/gold off
## current_hp <= 0 by index, so no separate kill helper is needed the
## way battle.gd's own _kill_enemy() is.
func _tick_npc_ice_blast_effects(enemies: Array) -> void:
	for enemy in enemies:
		if enemy.get("ice_blast_dot_turns_left", 0) <= 0:
			continue
		if enemy.get("current_hp", 0) <= 0:
			continue

		enemy["ice_blast_dot_turns_left"] -= 1
		var dot_damage: float = float(enemy.get("ice_blast_dot_damage", 0))
		if dot_damage > 0.0:
			_apply_damage_to_enemy(enemy, dot_damage)

		if enemy.get("current_hp", 0) > 0:
			var execute_pct: float = float(enemy.get("ice_blast_execute_pct", 0.0))
			var max_hp: float = float(enemy["static"].get("hp", 1))
			if execute_pct > 0.0 and enemy["current_hp"] <= max_hp * execute_pct:
				enemy["current_hp"] = 0.0

		if enemy.get("ice_blast_dot_turns_left", 0) <= 0:
			enemy["ice_blast_execute_pct"] = 0.0


# ------------------------------------------------------------------
# Winter Wyvern's Arctic Burn - mirrors battle.gd's own
# _activate_arctic_burn()/_apply_arctic_burn_attack()/_tick_arctic_
# burn()/_end_arctic_burn(). _apply_npc_arctic_burn_attack() is called
# from _run_stage_fight()'s own basic-attack branch, right after the
# attack lands, the same way _maybe_consume_npc_tidebringer_stack()'s
# result is used there.
# ------------------------------------------------------------------

func _activate_npc_arctic_burn(ab: Dictionary, level_data: Dictionary) -> void:
	ab["active"] = true
	ab["bonus_damage"] = float(level_data.get("bonus_damage", 0))
	ab["bonus_range"] = int(level_data.get("bonus_range", 0))
	ab["attacks_remaining"] = int(level_data.get("attacks", 0))
	ab["turns_remaining"] = int(level_data.get("duration", 0))
	ab["duration_pending_start"] = true


func _apply_npc_arctic_burn_attack(ab: Dictionary) -> void:
	if not ab["active"] or ab["attacks_remaining"] <= 0:
		return
	ab["attacks_remaining"] -= 1
	if ab["attacks_remaining"] <= 0:
		_end_npc_arctic_burn(ab)


func _tick_npc_arctic_burn(ab: Dictionary) -> void:
	if not ab["active"]:
		return
	if ab["duration_pending_start"]:
		ab["duration_pending_start"] = false
		return
	ab["turns_remaining"] -= 1
	if ab["turns_remaining"] <= 0:
		_end_npc_arctic_burn(ab)


func _end_npc_arctic_burn(ab: Dictionary) -> void:
	ab["active"] = false
	ab["bonus_damage"] = 0.0
	ab["bonus_range"] = 0
	ab["attacks_remaining"] = 0
	ab["turns_remaining"] = 0
	ab["duration_pending_start"] = false


# ------------------------------------------------------------------
# Winter Wyvern's Cold Embrace - mirrors battle.gd's own
# _activate_cold_embrace()/_dispel_all_hero_effects()/_tick_cold_
# embrace()/_end_cold_embrace(). Damage immunity and the move/attack
# lockout are both enforced directly in _run_stage_fight() (the
# retaliation loop's own guard, and the basic-attack branch's own
# early-out) rather than here, the same split battle.gd uses between
# this section and _deal_fixed_damage_to_enemy()/_enemy_hero_turn().
# ------------------------------------------------------------------

func _activate_npc_cold_embrace(ce: Dictionary, level_data: Dictionary) -> void:
	ce["active"] = true
	ce["heal_per_turn"] = float(level_data.get("heal", 0))
	ce["turns_remaining"] = int(level_data.get("duration", 0))
	ce["duration_pending_start"] = true


## Ticks Cold Embrace's duration down once per turn, healing the hero
## for its own heal_per_turn on every tick that counts against the
## duration - mirrors battle.gd's own _tick_cold_embrace(). Called from
## _run_stage_fight() right after `effective_max_hp` is computed for the
## turn (needed to clamp the heal), returning the hero's updated
## current_hp the same way _apply_reduced_damage_to_npc() does.
func _tick_npc_cold_embrace(ce: Dictionary, current_hp: float, effective_max_hp: float) -> float:
	if not ce["active"]:
		return current_hp
	if ce["duration_pending_start"]:
		ce["duration_pending_start"] = false
		return current_hp

	current_hp = minf(effective_max_hp, current_hp + ce["heal_per_turn"])
	ce["turns_remaining"] -= 1
	if ce["turns_remaining"] <= 0:
		_end_npc_cold_embrace(ce)
	return current_hp


func _end_npc_cold_embrace(ce: Dictionary) -> void:
	ce["active"] = false
	ce["heal_per_turn"] = 0.0
	ce["turns_remaining"] = 0
	ce["duration_pending_start"] = false


## Dispels every other self-buff currently active on the hero, right
## before Cold Embrace establishes its own state - the simulation's own
## mirror of battle.gd's _dispel_all_hero_effects()/_dispel_all_enemy_
## hero_effects(). Simplified versus both of those: this sim has no
## concept of a debuff landing ON the simulated hero in the first place
## (creeps only ever deal flat retaliation damage here - see
## _run_stage_fight()'s own retaliation loop), so there's nothing
## harmful to clear, only these seven self-buffs.
func _dispel_all_npc_effects(state: Dictionary) -> void:
	if state["arctic_burn"]["active"]:
		_end_npc_arctic_burn(state["arctic_burn"])
	if state["essence_shift"]["active"]:
		_end_npc_essence_shift(state["essence_shift"])
	if state["shadow_dance"]["active"]:
		_end_npc_shadow_dance(state["shadow_dance"])
	if state["spirit_link"]["active"]:
		_end_npc_spirit_link(state["spirit_link"])
	if state["true_form"]["active"]:
		_end_npc_true_form(state["true_form"])
	if state["aphotic_shield"]["active"]:
		_end_npc_aphotic_shield(state["aphotic_shield"], false, [])
	if state["borrowed_time"]["active"]:
		_end_npc_borrowed_time(state["borrowed_time"])


# ------------------------------------------------------------------
# Crystal Maiden's Frostbite - mirrors _tick_npc_cold_feet_effects()'/
# _tick_npc_ice_vortex_effects()'s own DoT tick exactly, just against
# Frostbite's own dedicated per-enemy fields (see battle.gd's
# _resolve_frostbite_cast() for why it's kept separate from every other
# skill's own DoT fields). The stun itself needs no separate tick here -
# it shares stun_turns_left, the same generic per-enemy field Pounce's/
# Torrent's own stun already decrements in _run_stage_fight()'s own
# retaliation loop.
# ------------------------------------------------------------------

func _tick_npc_frostbite_effects(enemies: Array) -> void:
	for enemy in enemies:
		if enemy.get("frostbite_dot_turns_left", 0) > 0:
			enemy["frostbite_dot_turns_left"] -= 1
			var dot_damage: float = float(enemy.get("frostbite_dot_damage", 0))
			if dot_damage > 0.0 and enemy.get("current_hp", 0) > 0:
				_apply_damage_to_enemy(enemy, dot_damage)


# ------------------------------------------------------------------
# Crystal Maiden's ultimate, Freezing Field - mirrors battle.gd's own
# _activate_freezing_field()/_tick_freezing_field()/_end_freezing_
# field(). No columns to check radius against here - same "no columns,
# hit everyone" fallback Ice Vortex's own sim copy already uses (see
# this file's own KNOWN_ACTIVE_SKILL_IDS header comment), so every tick
# that counts against the duration hits every still-living enemy, not
# just whichever ones would really be within radius of the hero's own
# position in a real fight.
# ------------------------------------------------------------------

func _activate_npc_freezing_field(ff: Dictionary, level_data: Dictionary) -> void:
	ff["active"] = true
	ff["damage_per_turn"] = float(level_data.get("damage", 0))
	ff["turns_remaining"] = int(level_data.get("duration", 0))
	ff["duration_pending_start"] = true


func _tick_npc_freezing_field(ff: Dictionary, enemies: Array) -> void:
	if not ff["active"]:
		return
	if ff["duration_pending_start"]:
		ff["duration_pending_start"] = false
		return

	var damage: float = float(ff["damage_per_turn"])
	if damage > 0.0:
		for enemy in enemies:
			if enemy.get("current_hp", 0) > 0:
				_apply_damage_to_enemy(enemy, damage)

	ff["turns_remaining"] -= 1
	if ff["turns_remaining"] <= 0:
		_end_npc_freezing_field(ff)


func _end_npc_freezing_field(ff: Dictionary) -> void:
	ff["active"] = false
	ff["damage_per_turn"] = 0.0
	ff["turns_remaining"] = 0
	ff["duration_pending_start"] = false


# ------------------------------------------------------------------
# Tusk's Tag Team - mirrors battle.gd's own _activate_tag_team()/_tick_
# tag_team()/_end_tag_team(): a flat bonus_damage added to
# _npc_roll_damage()/_npc_estimate_damage() for the duration, same spot
# Arctic Burn's/True Form's own bonus_damage already occupy there.
# ------------------------------------------------------------------

func _activate_npc_tag_team(tt: Dictionary, level_data: Dictionary) -> void:
	tt["active"] = true
	tt["bonus_damage"] = float(level_data.get("bonus_damage", 0))
	tt["turns_remaining"] = int(level_data.get("duration", 0))
	tt["duration_pending_start"] = true


func _tick_npc_tag_team(tt: Dictionary) -> void:
	if not tt["active"]:
		return
	if tt["duration_pending_start"]:
		tt["duration_pending_start"] = false
		return
	tt["turns_remaining"] -= 1
	if tt["turns_remaining"] <= 0:
		_end_npc_tag_team(tt)


func _end_npc_tag_team(tt: Dictionary) -> void:
	tt["active"] = false
	tt["bonus_damage"] = 0.0
	tt["turns_remaining"] = 0
	tt["duration_pending_start"] = false


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
# Abaddon's Aphotic Shield - mirrors battle.gd's _activate_aphotic_
# shield/_tick_aphotic_shield/_end_aphotic_shield. Simplification
# versus the real fight: there's no "dispel every negative effect on
# the hero" step here the way the player's own copy has one - a
# simulated hero has no per-self debuff fields to dispel in the first
# place (only the ENEMY side of a fight tracks root/silence/curse
# fields, via _apply_npc_root()/_apply_npc_curse_of_avernus_stack()),
# so there's nothing for a self-cast shield to clear.
# ------------------------------------------------------------------

func _activate_npc_aphotic_shield(shield: Dictionary, level_data: Dictionary) -> void:
	shield["active"] = true
	shield["hp"] = float(level_data.get("shield_hp", 0))
	shield["aoe_damage"] = float(level_data.get("aoe_damage", 0))
	shield["turns_remaining"] = int(level_data.get("duration", 0))
	shield["duration_pending_start"] = true


func _tick_npc_aphotic_shield(shield: Dictionary) -> void:
	if not shield["active"]:
		return
	if shield["duration_pending_start"]:
		shield["duration_pending_start"] = false
		return
	shield["turns_remaining"] -= 1
	if shield["turns_remaining"] <= 0:
		_end_npc_aphotic_shield(shield, false, [])


## Ends the shield, whether its duration simply ran out (`exploded`
## false) or enough damage drained it to 0 HP (`exploded` true, from
## _apply_reduced_damage_to_npc()) - in which case it deals the cast's
## own aoe_damage to every living enemy, mirroring Dark Pact's own
## "no columns, hit everyone" simplification in this sim (see
## _cast_skill()'s "dark_pact" case).
func _end_npc_aphotic_shield(shield: Dictionary, exploded: bool, living: Array) -> void:
	var aoe_damage: float = shield["aoe_damage"]

	shield["active"] = false
	shield["hp"] = 0.0
	shield["aoe_damage"] = 0.0
	shield["turns_remaining"] = 0
	shield["duration_pending_start"] = false

	if exploded and aoe_damage > 0.0:
		for enemy in living:
			_apply_damage_to_enemy(enemy, aoe_damage)


# ------------------------------------------------------------------
# Abaddon's Curse of Avernus - a passive, so unlike every skill above
# there's no cooldown/mana cost check for it; it just triggers off the
# hero's own plain Attacks (see _run_stage_fight()'s basic-attack
# branch). Per-target progress lives directly on each enemy's own
# Dictionary, the same way Entangle's root/silence/DoT fields do
# (_apply_npc_root()) - mirrors battle.gd's own
# _apply_curse_of_avernus_stack()/_tick_curse_of_avernus_effects().
# ------------------------------------------------------------------

func _get_npc_curse_of_avernus_level_data(hero_id: String, hero_static: Dictionary) -> Dictionary:
	var level: int = PlayerManager.get_npc_skill_level(hero_id, "curse_of_avernus")
	if level <= 0:
		return {}
	var skill: Dictionary = _find_skill(hero_static, "curse_of_avernus")
	if skill.is_empty():
		return {}
	return GameManager.get_skill_level_data(skill, level)


func _apply_npc_curse_of_avernus_stack(hero_id: String, hero_static: Dictionary, target: Dictionary, turn_index: int) -> void:
	var level_data: Dictionary = _get_npc_curse_of_avernus_level_data(hero_id, hero_static)
	if level_data.is_empty() or target.get("current_hp", 0) <= 0 or target.get("curse_active", false):
		return

	target["curse_last_hit_turn"] = turn_index

	var stacks: int = target.get("curse_stacks", 0) + 1
	var hits_to_activate: int = int(level_data.get("hits_to_activate", 1))
	if stacks < hits_to_activate:
		target["curse_stacks"] = stacks
		return

	target["curse_stacks"] = 0
	target["curse_active"] = true
	target["silence_turns_left"] = int(level_data.get("silence_turns", 0))
	target["curse_dot_damage"] = float(level_data.get("dot_damage", 0))
	target["curse_dot_turns_left"] = int(level_data.get("dot_duration", 0))


func _tick_npc_curse_of_avernus_effects(enemies: Array, turn_index: int) -> void:
	for enemy in enemies:
		if enemy.get("curse_active", false):
			if enemy.get("curse_dot_turns_left", 0) > 0:
				enemy["curse_dot_turns_left"] -= 1
				var dot_damage: float = float(enemy.get("curse_dot_damage", 0))
				if dot_damage > 0.0 and enemy.get("current_hp", 0) > 0:
					_apply_damage_to_enemy(enemy, dot_damage)

			if enemy.get("curse_dot_turns_left", 0) <= 0:
				enemy["curse_active"] = false
				enemy["curse_dot_damage"] = 0.0
		elif enemy.get("curse_stacks", 0) > 0:
			var last_hit_turn: int = int(enemy.get("curse_last_hit_turn", turn_index))
			if turn_index - last_hit_turn >= CURSE_OF_AVERNUS_STACK_DECAY_TURNS:
				enemy["curse_stacks"] = 0


# ------------------------------------------------------------------
# Kunkka's Tidebringer - a passive, so like Curse of Avernus above (and
# unlike every skill in KNOWN_ACTIVE_SKILL_IDS) it's never "cast"; it
# just builds off the hero's own plain Attacks - see this file's own
# basic-attack branch in _run_stage_fight(). Mirrors battle.gd's
# _maybe_consume_tidebringer_stack()/_apply_tidebringer_cleave().
# ------------------------------------------------------------------

func _get_npc_tidebringer_level_data(hero_id: String, hero_static: Dictionary) -> Dictionary:
	var level: int = PlayerManager.get_npc_skill_level(hero_id, "tidebringer")
	if level <= 0:
		return {}
	var skill: Dictionary = _find_skill(hero_static, "tidebringer")
	if skill.is_empty():
		return {}
	return GameManager.get_skill_level_data(skill, level)


## Called from _run_stage_fight()'s basic-attack branch, right before
## rolling that Attack's damage: counts one more plain Attack toward
## this level's own hits_to_activate - never reset by a turn going by
## without attacking, only by another empowered hit consuming it - and,
## once that threshold is reached, consumes the count and returns this
## level's data for the caller to fold bonus_damage into the roll and
## then cleave with (_apply_npc_tidebringer_cleave()). Returns {} (an
## ordinary Attack, no bonus) if the hero hasn't learned Tidebringer or
## hasn't reached the threshold yet.
func _maybe_consume_npc_tidebringer_stack(hero_id: String, hero_static: Dictionary, state: Dictionary) -> Dictionary:
	var level_data: Dictionary = _get_npc_tidebringer_level_data(hero_id, hero_static)
	if level_data.is_empty():
		return {}

	state["tidebringer_attack_count"] += 1
	if state["tidebringer_attack_count"] < int(level_data.get("hits_to_activate", 1)):
		return {}

	state["tidebringer_attack_count"] = 0
	return level_data


## Tidebringer's cleave, positionless-sim style: no columns here to
## measure cleave_columns against `target`'s own, so - same as Dark
## Pact's and Aphotic Shield's own AoE in this sim - it falls back to
## hitting every OTHER living enemy, each for cleave_damage_pct of
## `attack_damage` (the same raw, pre-mitigation roll `target` was just
## hit with, bonus damage already folded in by the caller), still
## mitigated by ITS OWN armor via _apply_damage_to_enemy().
func _apply_npc_tidebringer_cleave(target: Dictionary, attack_damage: float, level_data: Dictionary, living: Array) -> void:
	var cleave_damage: float = attack_damage * float(level_data.get("cleave_damage_pct", 0.0))
	if cleave_damage <= 0.0:
		return

	for enemy in living:
		if is_same(enemy, target):
			continue
		_apply_damage_to_enemy(enemy, cleave_damage)


# ------------------------------------------------------------------
# Abaddon's Borrowed Time - mirrors battle.gd's
# _maybe_auto_activate_borrowed_time()/_tick_borrowed_time()/
# _end_borrowed_time(). Like the player's own copy, nothing "casts"
# this - the only entry point is _apply_reduced_damage_to_npc() below
# noticing the hero's HP has crossed this level's threshold.
# ------------------------------------------------------------------

func _get_npc_borrowed_time_level_data(hero_id: String, hero_static: Dictionary) -> Dictionary:
	var level: int = PlayerManager.get_npc_skill_level(hero_id, "borrowed_time")
	if level <= 0:
		return {}
	var skill: Dictionary = _find_skill(hero_static, "borrowed_time")
	if skill.is_empty():
		return {}
	return GameManager.get_skill_level_data(skill, level)


func _maybe_auto_activate_npc_borrowed_time(hero_id: String, hero_static: Dictionary, state: Dictionary, current_hp: float, effective_max_hp: float, cooldowns: Dictionary) -> void:
	var bt: Dictionary = state["borrowed_time"]
	if bt["active"] or cooldowns.get("borrowed_time", 0) > 0:
		return

	var level_data: Dictionary = _get_npc_borrowed_time_level_data(hero_id, hero_static)
	if level_data.is_empty() or effective_max_hp <= 0.0:
		return

	var hp_pct: float = current_hp / effective_max_hp
	if hp_pct > float(level_data.get("auto_activate_hp_pct", 0.3)):
		return

	bt["active"] = true
	bt["heal_conversion_pct"] = float(level_data.get("heal_conversion_pct", 1.0))
	bt["turns_remaining"] = int(level_data.get("duration", 0))
	bt["duration_pending_start"] = true

	# Rides along in the same generic cooldowns dict every KNOWN_ACTIVE_
	# SKILL_IDS entry uses (see _run_stage_fight()'s per-turn tick loop
	# at its top) even though "borrowed_time" itself is never a pick-
	# able skill - exactly mirroring how battle.gd's own auto-activate
	# starts a normal entry in _skill_cooldowns/_enemy_skill_cooldowns.
	cooldowns["borrowed_time"] = int(level_data.get("cooldown", 0))


func _tick_npc_borrowed_time(bt: Dictionary) -> void:
	if not bt["active"]:
		return
	if bt["duration_pending_start"]:
		bt["duration_pending_start"] = false
		return
	bt["turns_remaining"] -= 1
	if bt["turns_remaining"] <= 0:
		_end_npc_borrowed_time(bt)


func _end_npc_borrowed_time(bt: Dictionary) -> void:
	bt["active"] = false
	bt["heal_conversion_pct"] = 0.0
	bt["turns_remaining"] = 0
	bt["duration_pending_start"] = false


## Applies `reduced` retaliation damage (already mitigated by armor/
## Savage Roar) to the simulated hero's own current_hp, redirecting it
## through Borrowed Time (converts to a heal) or Aphotic Shield
## (absorbs into its own HP pool, exploding onto every living enemy if
## that breaks it) first - mirrors battle.gd's own apply_damage(), just
## reading/writing `state` instead of instance variables and returning
## the hero's updated current_hp instead of mutating it in place.
func _apply_reduced_damage_to_npc(hero_id: String, hero_static: Dictionary, state: Dictionary, cooldowns: Dictionary, current_hp: float, effective_max_hp: float, reduced: float, living: Array) -> float:
	var bt: Dictionary = state["borrowed_time"]
	if bt["active"]:
		return minf(effective_max_hp, current_hp + reduced * bt["heal_conversion_pct"])

	var shield: Dictionary = state["aphotic_shield"]
	if shield["active"]:
		var absorbed: float = minf(reduced, shield["hp"])
		shield["hp"] -= absorbed
		var new_hp: float = current_hp - (reduced - absorbed)
		if shield["hp"] <= 0.0:
			_end_npc_aphotic_shield(shield, true, living)
		if new_hp > 0.0:
			_maybe_auto_activate_npc_borrowed_time(hero_id, hero_static, state, new_hp, effective_max_hp, cooldowns)
		return new_hp

	var new_hp: float = current_hp - reduced
	if new_hp > 0.0:
		_maybe_auto_activate_npc_borrowed_time(hero_id, hero_static, state, new_hp, effective_max_hp, cooldowns)
	return new_hp


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

	var bonus_damage: float = state["essence_shift"]["bonus"].get("damage", 0.0) + state["true_form"]["bonus_damage"] + state["arctic_burn"]["bonus_damage"] + state["tag_team"]["bonus_damage"] + extra_bonus
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
