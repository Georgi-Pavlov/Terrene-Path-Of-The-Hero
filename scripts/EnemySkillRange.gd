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
#   - Torrent/X Marks the Spot/Ghostship: targeted casts with their own
#     `range` field (a constant 3 for Torrent, 2-5 growing with level
#     for X Marks the Spot, 4-6 for Ghostship) - in range whenever the
#     player is within it, the same "distance <= radius" comparison as
#     Dark Pact, just against a targeting range instead of a self-
#     centered AoE radius (see battle.gd's _enemy_skill_in_range(),
#     which reads whichever of the two fields a given skill actually
#     has).
#   - Entangle/Mist Coil/Chilling Touch/Splinter Blast/Winter's Curse/
#     Crystal Nova/Frostbite: none of the seven has a range field of its
#     own (Splinter Blast has `splinter_range`, but that's its splash
#     radius around whichever target gets hit, not its own targeting
#     range; Crystal Nova's own `radius` field is the same story;
#     Winter's Curse has no range field at all), so all seven use the
#     rival's own basic-attack range for its type instead, mirroring how
#     the player's own copies of each use the player's attack-column
#     range (_hero_attack_column_range(), via _start_crystal_nova_
#     targeting()/_start_frostbite_targeting()).
#   - Pounce: a gap-closer, but only up to its own `distance` field of
#     columns - it stops the moment it lands on the player's column
#     (see battle.gd's _cast_enemy_pounce()), so a player standing
#     farther away than that just watches the rival leap partway and
#     whiff instead of taking the hit. In range whenever the player is
#     within `distance`, the same "distance <= radius" comparison as
#     Dark Pact/Torrent/X Marks the Spot/Ghostship, just against the
#     leap's own reach instead of a targeting range or AoE radius.
#   - Cold Feet: a targeted cast with its own per-level `range` field
#     (2-4, growing with level) - same "distance <= radius" comparison
#     as Torrent/X Marks the Spot/Ghostship, just against Cold Feet's
#     own range instead of theirs.
#   - Ice Vortex: also a targeted cast, but its own targeting range is
#     a FIXED constant (battle.gd's ICE_VORTEX_RANGE) rather than a
#     per-level field - its level only changes the AoE radius applied
#     around whichever target gets hit, never the targeting range
#     itself. battle.gd's own _enemy_skill_in_range() special-cases
#     this before calling in here, passing ICE_VORTEX_RANGE as `radius`
#     instead of pulling from level data (which would otherwise
#     silently grab the AoE radius field instead - see that function's
#     own comment).
#   - Ice Shards/Snowball (both Tusk's): targeted casts with their own
#     per-level `range` field, same "distance <= radius" comparison as
#     Cold Feet's own - Tusk himself fights at melee range, but both are
#     thrown/charged well past it.
#   - Walrus Punch (Tusk's ultimate): strictly melee range (same column
#     as the player, sharing his own basic-attack reach for "mele" - 0
#     columns) rather than any range/radius field of its own, mirroring
#     the player's own _start_walrus_punch_targeting()'s "shares his own
#     column" requirement - so this uses the same attack_range fallback
#     Entangle/Mist Coil do, just against a hero whose own type is
#     always "mele" (see GameManager's own Tusk entry), where that
#     fallback is always 0 anyway.
#   - Leech Seed (Treant Protector's): a targeted cast with its own
#     per-level `range` field (a constant 2 per the design doc), same
#     "distance <= radius" comparison as Cold Feet's/Ice Shards'/
#     Snowball's own.
#   - Whirling Death (Timbersaw's): an AoE centered on the caster, same
#     shape as Dark Pact's own - in range whenever the player is within
#     the skill's own `radius` field. It has no `range` field of its
#     own, so the generic fallback chain battle.gd's own
#     _enemy_skill_in_range() already uses (range, then radius, then
#     distance) correctly falls through to `radius` here, exactly like
#     Dark Pact's own case.
#   - Timber Chain/Chakram (both Timbersaw's): targeted casts with their
#     own per-level `range` field, same "distance <= radius" comparison
#     as Cold Feet's/Leech Seed's own. Chakram ALSO has its own `radius`
#     field (the AoE size once it's already landed - see EnemySkillAI's
#     own _timbersaw_chakram_modifier()), but that's never what gates
#     whether the cast itself is reachable - the generic fallback chain
#     always prefers `range` first when a skill has both, same
#     "targeting range, not AoE radius" distinction Torrent's own
#     level-4 splash radius already needs.
# Ice Blast is deliberately NOT range-checked at all (not in
# RANGE_CHECKED_SKILL_IDS below) - it "targets any enemy on the field,"
# with no range limit, mirroring the player's own _start_ice_blast_
# targeting()'s complete lack of a distance filter.
# Every other known skill (Essence Shift, Shadow Dance, Spirit Link,
# True Form, Summon Spirit Bear, Aphotic Shield, Arctic Burn, Cold
# Embrace, Crystal Maiden's own Freezing Field, Tusk's own Tag Team, and
# Treant Protector's own Nature's Guise/Living Armor/Overgrowth) is a
# self-buff/summon/AoE with no target to range-check, so this always
# reports those as in range - Freezing Field/Overgrowth in particular
# are centered on the caster's OWN position (see EnemySkillAI's own
# _cm_freezing_field_modifier()/_tp_overgrowth_modifier()), never a
# selected enemy's, so there's nothing here to check range against in
# the first place, exactly like every other self-cast skill in this
# list; Tag Team/Nature's Guise/Living Armor are simpler still - no
# target of their own to reach at cast time at all (Nature's Guise's own
# "attack from stealth" follow-up reuses the player's normal Attack
# range/targeting, not a skill-cast range check here). Timbersaw's own
# Reactive Armor is passive and never even reaches this file - see
# battle.gd's ENEMY_KNOWN_SKILL_IDS/EnemyHeroManager's own
# KNOWN_ACTIVE_SKILL_IDS, neither of which lists it.
# ============================================================

const RANGE_CHECKED_SKILL_IDS: Array[String] = ["dark_pact", "entangle", "mist_coil", "torrent", "x_marks_the_spot", "ghostship", "pounce", "cold_feet", "ice_vortex", "chilling_touch", "splinter_blast", "winter's_curse", "crystal_nova", "frostbite", "ice_shards", "snowball", "walrus_punch", "leech_seed", "whirling_death", "timber_chain", "chakram"]


## True if `skill_id` needs a range check at all before being cast -
## see the header comment above for which skills those are and why.
static func requires_range_check(skill_id: String) -> bool:
	return skill_id in RANGE_CHECKED_SKILL_IDS


## True if a rival hero standing `distance` columns from the player can
## reach them with `skill_id` right now. `radius` is Dark Pact's own
## `radius` field, Torrent's/X Marks the Spot's/Ghostship's own `range`
## field, or Pounce's own `distance` field, depending on the skill (all
## compared the same way as "distance <= radius"); `attack_range` is the
## rival's basic-attack range for its type (0 for "mele", battle.gd's
## RANGE_ENEMY_ATTACK_RANGE for "range") - Entangle/Mist Coil piggyback
## on that since neither has a range field of its own. Any skill not in
## RANGE_CHECKED_SKILL_IDS always reports true here, matching
## requires_range_check().
static func is_in_range(skill_id: String, distance: int, radius: int, attack_range: int) -> bool:
	match skill_id:
		"dark_pact", "torrent", "x_marks_the_spot", "ghostship", "pounce", "cold_feet", "ice_vortex", "ice_shards", "snowball", "leech_seed", "whirling_death", "timber_chain", "chakram":
			return distance <= radius
		"entangle", "mist_coil", "chilling_touch", "splinter_blast", "winter's_curse", "crystal_nova", "frostbite", "walrus_punch":
			return distance <= attack_range
		_:
			return true
