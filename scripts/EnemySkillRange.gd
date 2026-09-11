extends RefCounted
class_name EnemySkillRange

# ============================================================
# EnemySkillRange
# ============================================================
# Pure helper for battle.gd's rival-hero AI (_enemy_hero_turn()/
# _pick_enemy_ready_skill()): decides whether a rival hero is actually
# within range to land a given skill on the player, so a boss can't
# hit the player with Dark Pact or Entangle from clear across the
# board regardless of distance - it has to close in first, same as it
# already must for a plain Attack (see battle.gd's
# RANGE_ENEMY_ATTACK_RANGE/_enemy_hero_turn()).
#
# Only skills that hit the player directly need a range check here:
#   - Dark Pact: an AoE centered on the caster - in range whenever the
#     player is within the skill's own `radius` field (0 at low
#     levels, meaning the same column; 1 only at max level).
#   - Entangle: has no radius field of its own, so it uses the rival's
#     own basic-attack range for its type instead, mirroring how the
#     player's own Entangle uses the player's attack-column range.
# Every other known skill (Pounce, Essence Shift, Shadow Dance, Spirit
# Link, True Form, Summon Spirit Bear) is either a gap-closer that
# already handles its own positioning or a self-buff/summon with no
# target to range-check, so this always reports those as in range.
# ============================================================

const RANGE_CHECKED_SKILL_IDS: Array[String] = ["dark_pact", "entangle"]


## True if `skill_id` needs a range check at all before being cast -
## see the header comment above for which skills those are and why.
static func requires_range_check(skill_id: String) -> bool:
	return skill_id in RANGE_CHECKED_SKILL_IDS


## True if a rival hero standing `distance` columns from the player can
## reach them with `skill_id` right now. `radius` is Dark Pact's own
## level-data field; `attack_range` is the rival's basic-attack range
## for its type (0 for "mele", battle.gd's RANGE_ENEMY_ATTACK_RANGE for
## "range") - Entangle piggybacks on that since it has no radius field
## of its own. Any skill not in RANGE_CHECKED_SKILL_IDS always reports
## true here, matching requires_range_check().
static func is_in_range(skill_id: String, distance: int, radius: int, attack_range: int) -> bool:
	match skill_id:
		"dark_pact":
			return distance <= radius
		"entangle":
			return distance <= attack_range
		_:
			return true
