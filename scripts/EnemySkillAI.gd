extends RefCounted
class_name EnemySkillAI

# ============================================================
# EnemySkillAI
# ============================================================
# Shared skill-scoring brain for every enemy hero's own AI - used by
# BOTH battle.gd's _pick_enemy_ready_skill() (a real hero fight, with
# positions/range) and EnemyHeroManager.gd's _pick_ready_skill() (the
# background stage-fight simulation, with no positions at all). Neither
# file scores skills itself; each just builds a small "context"
# Dictionary out of whatever data it already has and hands candidate
# skills here one at a time via evaluate_skill(), then hands the whole
# scored list to pick_best_skill() to get a final answer back.
#
# This replaces the old "first known/ready/affordable skill in a fixed
# priority list wins" rule with: score every currently-castable skill,
# take the highest score, and only fall back to a hero's own static
# priority order (HERO_TIE_BREAK) to break a near-tie. Everything
# upstream of this file - cooldowns, mana, "is this buff already
# active", and (in battle.gd only) range - is still exactly the same
# gate it always was; this file only ranks whatever survives those
# gates. If nothing survives them, callers get an empty candidates
# array, pick_best_skill() returns "", and the caller's own existing
# fallback (a plain Attack) takes over, unchanged.
#
# Deliberately NOT covered as scored SKILL candidates here: Savage
# Roar, The Mist Remembers, Mark of the Mist, and Tidebringer. All four
# already auto-trigger off HP%/hits-landed outside of any skill-picking
# loop (see battle.gd's _update_enemy_blood_of_the_wild_state()/
# _maybe_auto_activate_enemy_the_mist_remembers()/
# _apply_enemy_mark_of_the_mist_stack()/_maybe_consume_enemy_
# tidebringer_stack(), and EnemyHeroManager.gd's own mirrors) - they're
# never "picked", so they have no business being scored candidates.
# Tidebringer's current state DOES still feed into the AI, though - not
# as a candidate of its own, but as an input to how a plain Attack
# itself scores (see BASIC_ATTACK_ID/basic_attack_participates()/
# evaluate_basic_attack() and Kunkka's own "basic_attack" case in
# _kunkka_modifier()), since a Tidebringer-empowered Attack can
# genuinely be the better play than any of Kunkka's real skills.
#
# Eleven heroes have real AI logic today: Veyrik, Erynd, Morvael,
# Kunkka, Ancient Apparition, Winter Wyvern, Crystal Maiden, Tusk,
# Treant Protector, Timbersaw, and Snapfire - see resolve_hero_
# archetype() for how a hero_static maps to one of them,
# and each one's own _*_modifier() function below for its personality.
# Ancient Apparition's Ice Blast in particular models an "execute"
# mechanic (a target dies outright once its HP drops to or below a
# reserved % of its own max HP, regardless of remaining HP - see
# _aa_ice_blast_execute_score()) that nothing else in this file has to
# account for. Winter Wyvern's Winter's Curse models a redirect
# mechanic of its own (every OTHER living enemy ignores the caster and
# piles onto the frozen target instead, for bonus damage - see
# _ww_winters_curse_modifier()'s own "redirect_candidate_count" scoring
# and battle.gd's/EnemyHeroManager.gd's own retaliation-loop hooks).
# Crystal Maiden's Freezing Field is a self-cast AoE ultimate (centered
# on HER OWN position, never a selected enemy's) rather than a targeted
# one - see _cm_freezing_field_modifier()'s own "target_distance" check,
# which is battle.gd's already-computed distance from Crystal Maiden's
# own pos_index to the player, not a fresh per-target search. Arcane
# Aura is passive and deliberately never appears in SKILL_INFO/
# HERO_TIE_BREAK/_estimate_skill_damage - callers only ever hand this
# file a hero's KNOWN active skills to begin with (see battle.gd's
# ENEMY_KNOWN_SKILL_IDS/EnemyHeroManager's KNOWN_ACTIVE_SKILL_IDS,
# neither of which lists it), so it can never become a scored candidate.
# Tusk's Ice Shards is the one skill in this file whose main value is
# positional rather than a raw damage/control number - see
# _tusk_ice_shards_modifier()'s own "grid_columns" check, real board
# data battle.gd's own _build_enemy_ai_context() supplies (never present
# in the simulation - see EnemyHeroManager's own _build_npc_ai_context()
# docstring - where a missing value falls back to a generic "more
# enemies around, more this matters" proxy, same spirit as Winter's
# Curse's own redirect_candidate_count). Walrus Punch's own damage is
# Tusk's actual (rolled) Attack damage times a multiplier, not a flat
# number - see its own "walrus_punch" case in _estimate_skill_damage().
# Treant Protector's Nature's Guise is "defensive" category, exactly
# like Veyrik's own Depthsveil (functionally the same invisibility) -
# in the simulation it relies ENTIRELY on that shared category term, no
# hero-specific modifier on top at all, same as Depthsveil's own
# _veyrik_modifier() case (there isn't one); only in a real hero fight,
# with real positions, does _tp_natures_guise_modifier() add its own
# stealth-engage/root-setup value on top (see that function's own
# "target_distance" gate). Overgrowth is a second self-cast AoE
# ultimate, same "centered on the caster" shape as Crystal Maiden's own
# Freezing Field - see _tp_overgrowth_modifier().
# Timbersaw's Whirling Death is ALSO self-cast/self-centered (like
# Freezing Field/Overgrowth), but Timber Chain and Chakram are both
# TARGET-centered - see _timbersaw_chakram_modifier()'s own docstring
# for why Chakram in particular is scored differently from a self-
# centered AoE despite both ending up reading the same `living_target_
# hps`/`target_distance` context fields in a hero fight (there's only
# ever the one player to hit either way - see _build_enemy_ai_
# context()'s own docstring). Reactive Armor is passive and, like Arcane
# Aura, deliberately never appears in SKILL_INFO/HERO_TIE_BREAK/
# _estimate_skill_damage - its own stacks still feed every one of
# Timbersaw's active skills through the context's own "reactive_armor_
# stacks"/"reactive_armor_max_stacks" fields (see _timbersaw_modifier()'s
# own docstring), just never as a scored candidate of its own. Whirling
# Death's own "pure damage"/primary-attribute-reduction flavor text
# isn't backed by any real mechanic in this project (see battle.gd's own
# _cast_enemy_whirling_death() docstring) - same "documented but not
# implemented" gap Abyssal Spasm's own silence effect already has - so
# _timbersaw_whirling_death_modifier() only ever adds a small flat
# qualitative bonus for "a hero was hit" (context's own "target_is_hero"
# field), never a real stat-based number.
# Snapfire's Scatterblast is DIRECTIONAL rather than self-centered like
# Whirling Death/Freezing Field/Overgrowth (see battle.gd's own
# _enemy_skill_in_range()'s "scatterblast" case for how that's actually
# enforced) - by the time this file ever scores it as a candidate, the
# player is already confirmed to be ahead of the rival in whichever
# direction it's facing, so _snapfire_scatterblast_modifier() reads the
# same `living_target_hps` every other AoE skill's own modifier does,
# with no extra directional math of its own to repeat. Firesnap Cookie
# is self-directed (a hop, not a self-centered radius check the way
# Freezing Field's own is) - _snapfire_firesnap_cookie_modifier()
# projects the landing column itself from the context's own
# `caster_pos_index`/`caster_facing_left`/`grid_columns` fields (the
# same ones Tusk's own Ice Shards/Walrus Punch modifiers already read)
# rather than needing a new one. Mortimer Kisses' own splash always
# collapses to 0 extra targets in a real hero fight (there's only ever
# the one player to hit - see _cast_enemy_mortimer_kisses()'s own "no
# cleave" simplification), so its real multi-target value only ever
# shows up in the simulation, where "no columns, hit everyone else"
# gives it real splash to work with (see EnemyHeroManager's own
# "_fire_npc_mortimer_kisses_shot()"). Lil' Shredder's own armor
# reduction is real (see battle.gd's own _hero_armor()/EnemyHeroManager's
# own _apply_damage_to_enemy(), both of which now fold a runtime
# "armor_reduction" in) - context's own "target_armor" field (the
# target's CURRENT armor, reduction already applied) lets _snapfire_
# lil_shredder_modifier() value shredding a heavily-armored target
# without inventing a parallel armor system of its own.
#
# Naga Siren is the twelfth hero with real AI logic. Mirror Image is
# "utility" category, same shape as Erynd's own Elderwild Companion - its
# entire value (both the illusions' own expected total damage over their
# FULL duration and the redirect chance that can soak a hit meant for
# Naga herself) is hero-specific, computed entirely in
# _naga_mirror_image_modifier() rather than any generic category term
# (see that function's own docstring). Ensnare is "offensive" (a root,
# not a stun - the target can still attack/cast while rooted, so unlike
# Torrent's/Barbed Lunge's own stuns it gets no generic "stun_turns" bonus of
# its own, only the movement-denial/kill-setup value
# _naga_ensnare_modifier() adds). Song of the Siren, Naga's ultimate, is
# also "offensive" despite dealing no direct damage of its own - see
# _naga_song_expected_damage()'s own docstring for what its "damage"
# really means (every hit Naga/her illusions land completely safely
# while the stun holds), shared between _estimate_skill_damage()'s own
# case and _naga_song_of_the_siren_modifier() so the two numbers never
# drift apart. Rip Tide is passive, same as Arcane Aura/Reactive Armor -
# never in SKILL_INFO/HERO_TIE_BREAK/_estimate_skill_damage, never a
# scored candidate; its bonuses reach Mirror Image/Song/a plain Attack
# purely through context fields (rip_tide_illusion_damage_bonus_pct/
# rip_tide_extra_illusion/rip_tide_illusion_duration_bonus/rip_tide_aoe_
# damage_pct) battle.gd's/EnemyHeroManager's own _build_*_ai_context()
# compute fresh off Naga's current Rip Tide level, same "empty/0 means
# locked" convention every other auto-triggered skill's own level-data
# getter uses.
#
# Slardar is the thirteenth hero with real AI logic. Guardian Sprint is
# "utility" category, same "the hero-specific modifier IS the whole
# value" shape Mirror Image/Elderwild Companion already use - its value is almost
# entirely positional, not a generic damage/defensive term (see
# _slardar_guardian_sprint_modifier()'s own docstring). Slithereen Crush
# and Corrosive Haze are both "offensive", same shape as every other
# self-cast/target-marking skill in this file. Bash of the Deep is
# passive and, like Rip Tide/Reactive Armor/Arcane Aura, never appears in
# SKILL_INFO/HERO_TIE_BREAK/_estimate_skill_damage - its progression
# reaches every one of Slardar's other actions purely through context
# fields ("bash_attacks_required"/"bash_current_progress"/"bash_bonus_
# damage_pct"/"bash_knockback" - see _slardar_bash_ready()/_slardar_bash_
# knockback_value()), never as a scored candidate of its own.
#
# Mirana is the fourteenth hero with real AI logic. Starstorm is
# "offensive", same self-centered-AoE shape as Slithereen Crush/Song of
# the Siren. Sacred Arrow is also "offensive" - its own damage genuinely
# scales with the real travel distance (see _mirana_sacred_arrow_
# expected_damage()'s own docstring), never a flat number the way a
# lesser implementation might read `base_damage` alone. Leap deals no
# damage at all (it "sails clean over any enemy in the way" - see
# battle.gd's own _activate_leap()), so it's "utility" category, same
# "the modifier IS the whole value" shape Guardian Sprint/Mirror Image
# already use - see _mirana_leap_modifier()'s own docstring for how a
# single cast can still end up scored for EITHER direction (toward or
# away) since Leap always jumps in whichever way Mirana is currently
# facing, never a chosen "toward the enemy" step the way Guardian
# Sprint's own fallback movement is. Moonlight Shadow is "utility" too -
# defensive protection, positioning, AND a guaranteed enhanced next
# Attack all at once (see _mirana_moonlight_shadow_modifier()'s own
# docstring), never scored as a pure escape.
#
# Luna is the fifteenth hero with real AI logic. Lucent Beam is
# "offensive", same single-target-nuke-plus-stun shape as Sacred Arrow/
# Torrent. Eclipse is "offensive" too, despite dealing spell damage that
# has nothing to do with Luna's own attack roll - see _luna_eclipse_
# modifier()'s/_luna_eclipse_expected_damage()'s own docstrings for how
# its "no cap on hits per enemy" random-beam mechanic is actually
# evaluated (deterministic at one real candidate, a genuine expected
# value at more than one - never a naive "beams x damage, guaranteed"
# reading, and never a "one beam per enemy" assumption). Moon Glaives and
# Lunar Blessing are both passive and, like Bash of the Deep/Rip Tide/
# Reactive Armor/Arcane Aura, never appear in SKILL_INFO/HERO_TIE_BREAK/
# _estimate_skill_damage - Lunar Blessing's own bonus is already folded
# into "hero_damage" itself by _roll_enemy_hero_damage()/
# _npc_roll_damage() (see each one's own docstring), and Moon Glaives'
# own bounce reaches Basic Attack purely through context fields (see
# _luna_basic_attack_modifier()'s own docstring) - Eclipse's own beams
# are spell damage, never bounced or boosted by either passive, per the
# design doc's own explicit "do not assume Moon Glaives causes Eclipse to
# bounce" instruction.
# ============================================================

const DEBUG_AI := false

# A skill's starting value before any situational scoring - roughly
# "how good is this in a vacuum," tuned per the hero design doc. These
# are starting points for balancing, not hard rules - the situational
# terms in _evaluate_offensive()/_evaluate_defensive()/
# _evaluate_utility() and each hero's own modifier below can easily
# swing a low-base skill above a high-base one.
const SKILL_INFO := {
	"abyssal_spasm": {"category": "offensive", "base_score": 30.0},
	"barbed_lunge": {"category": "offensive", "base_score": 40.0},
	"leeching_hunger": {"category": "utility", "base_score": 20.0},
	"depthsveil": {"category": "defensive", "base_score": 50.0},
	"thornbind": {"category": "offensive", "base_score": 40.0},
	"elderwild_companion": {"category": "utility", "base_score": 50.0},
	"wildbond": {"category": "defensive", "base_score": 30.0},
	"beast_of_the_elderwild": {"category": "defensive", "base_score": 45.0},
	"whisper_of_the_veil": {"category": "offensive", "base_score": 35.0},
	# Whisper of the Veil cast on Morvael himself (see WHISPER_OF_THE_VEIL_SELF_ID) - a heal,
	# so it rides the same HP-danger tiers every defensive skill does.
	"whisper_of_the_veil_self": {"category": "defensive", "base_score": 25.0},
	"veil_of_the_forgotten": {"category": "defensive", "base_score": 40.0},
	"torrent": {"category": "offensive", "base_score": 45.0},
	"x_marks_the_spot": {"category": "utility", "base_score": 35.0},
	"ghostship": {"category": "offensive", "base_score": 55.0},
	"cold_feet": {"category": "offensive", "base_score": 40.0},
	"ice_vortex": {"category": "offensive", "base_score": 35.0},
	"chilling_touch": {"category": "offensive", "base_score": 50.0},
	"ice_blast": {"category": "offensive", "base_score": 65.0},
	"arctic_burn": {"category": "utility", "base_score": 40.0},
	"splinter_blast": {"category": "offensive", "base_score": 50.0},
	"cold_embrace": {"category": "defensive", "base_score": 45.0},
	"winter's_curse": {"category": "defensive", "base_score": 65.0},
	"crystal_nova": {"category": "offensive", "base_score": 45.0},
	"frostbite": {"category": "offensive", "base_score": 50.0},
	"freezing_field": {"category": "offensive", "base_score": 65.0},
	"ice_shards": {"category": "offensive", "base_score": 40.0},
	"snowball": {"category": "offensive", "base_score": 50.0},
	"tag_team": {"category": "utility", "base_score": 35.0},
	"walrus_punch": {"category": "offensive", "base_score": 65.0},
	"nature's_guise": {"category": "defensive", "base_score": 40.0},
	"leech_seed": {"category": "offensive", "base_score": 45.0},
	"living_armor": {"category": "defensive", "base_score": 35.0},
	"overgrowth": {"category": "offensive", "base_score": 65.0},
	"whirling_death": {"category": "offensive", "base_score": 45.0},
	"timber_chain": {"category": "offensive", "base_score": 50.0},
	"chakram": {"category": "offensive", "base_score": 70.0},
	"scatterblast": {"category": "offensive", "base_score": 45.0},
	"firesnap_cookie": {"category": "offensive", "base_score": 50.0},
	"lil_shredder": {"category": "offensive", "base_score": 45.0},
	"mortimer_kisses": {"category": "offensive", "base_score": 70.0},
	"mirror_image": {"category": "utility", "base_score": 50.0},
	"ensnare": {"category": "offensive", "base_score": 45.0},
	"song_of_the_siren": {"category": "offensive", "base_score": 75.0},
	"guardian_sprint": {"category": "utility", "base_score": 45.0},
	"slithereen_crush": {"category": "offensive", "base_score": 55.0},
	"corrosive_haze": {"category": "offensive", "base_score": 75.0},
	"starstorm": {"category": "offensive", "base_score": 50.0},
	"sacred_arrow": {"category": "offensive", "base_score": 65.0},
	"leap": {"category": "utility", "base_score": 40.0},
	"moonlight_shadow": {"category": "utility", "base_score": 70.0},
	"lucent_beam": {"category": "offensive", "base_score": 55.0},
	"eclipse": {"category": "offensive", "base_score": 80.0},
}

# A plain Attack's own pseudo skill id - never a real skill, but scored
# and compared exactly like one for whichever heroes opt into it (see
# basic_attack_participates()/evaluate_basic_attack()) so it can win
# outright instead of only ever being "whatever happens when nothing
# else was picked."
const BASIC_ATTACK_ID := "basic_attack"

# A plain Attack's baseline score for a hero that opts in - deliberately
# a flat constant rather than running through _evaluate_offensive(): a
# basic Attack has no kill-potential/AoE terms of its own here, only
# whatever a hero-specific modifier adds on top (Tidebringer's own bonus
# damage/cleave, for Kunkka).
const BASELINE_BASIC_ATTACK_SCORE := 30.0

# Whisper of the Veil cast on the caster himself (Morvael's self-heal: pay
# hp_cost, heal for `heal`) - a pseudo skill id, like BASIC_ATTACK_ID:
# never a real skill of its own, just a second way to use the real
# "whisper_of_the_veil" that's scored and compared as its own candidate. Callers
# add it (see battle.gd's _pick_enemy_ready_skill()/EnemyHeroManager's
# _pick_ready_skill()) only when the caster could survive paying its
# hp_cost, and map a win back onto a self-targeted "whisper_of_the_veil" cast.
const WHISPER_OF_THE_VEIL_SELF_ID := "whisper_of_the_veil_self"

# Static fallback order, per hero, used ONLY to settle a near-tie (see
# CLOSE_SCORE_THRESHOLD/pick_best_skill()) - never consulted while one
# skill's score clearly beats the rest.
const HERO_TIE_BREAK := {
	"veyrik": ["barbed_lunge", "abyssal_spasm", "depthsveil", "leeching_hunger"],
	"erynd": ["thornbind", "elderwild_companion", "wildbond", "beast_of_the_elderwild"],
	"morvael": ["veil_of_the_forgotten", "whisper_of_the_veil_self", "whisper_of_the_veil"],
	"kunkka": ["ghostship", "torrent", "x_marks_the_spot"],
	"ancient_apparition": ["ice_blast", "chilling_touch", "cold_feet", "ice_vortex"],
	"winter_wyvern": ["winter's_curse", "splinter_blast", "cold_embrace", "arctic_burn"],
	"crystal_maiden": ["freezing_field", "frostbite", "crystal_nova"],
	"tusk": ["walrus_punch", "snowball", "ice_shards", "tag_team"],
	"treant_protector": ["overgrowth", "leech_seed", "nature's_guise", "living_armor"],
	"timbersaw": ["chakram", "timber_chain", "whirling_death"],
	"snapfire": ["mortimer_kisses", "firesnap_cookie", "scatterblast", "lil_shredder"],
	"naga_siren": ["song_of_the_siren", "mirror_image", "ensnare"],
	"slardar": ["corrosive_haze", "slithereen_crush", "guardian_sprint"],
	"mirana": ["moonlight_shadow", "sacred_arrow", "starstorm", "leap"],
	"luna": ["eclipse", "lucent_beam"],
}

# Scores within this many points of the top score are treated as
# "close" - see pick_best_skill(). A skill that clearly wins (more than
# this far ahead) is always picked outright.
const CLOSE_SCORE_THRESHOLD := 5.0


## Figures out which of the six heroes with real AI logic today
## `hero_static` is, by checking for a skill only that hero has -
## rather than ever comparing hero ids directly, so this keeps working
## however a hero's id is spelled or renamed. Returns "" for any hero without a
## known kit, in which case every hero-specific modifier below is a
## no-op and skills fall back to pure category scoring.
static func resolve_hero_archetype(hero_static: Dictionary) -> String:
	var skill_ids: Array = []
	for skill in hero_static.get("skills", []):
		skill_ids.append(skill.get("id", ""))

	if "barbed_lunge" in skill_ids:
		return "veyrik"
	if "elderwild_companion" in skill_ids:
		return "erynd"
	if "the_mist_remembers" in skill_ids:
		return "morvael"
	if "torrent" in skill_ids:
		return "kunkka"
	if "ice_blast" in skill_ids:
		return "ancient_apparition"
	if "winter's_curse" in skill_ids:
		return "winter_wyvern"
	if "freezing_field" in skill_ids:
		return "crystal_maiden"
	if "walrus_punch" in skill_ids:
		return "tusk"
	if "overgrowth" in skill_ids:
		return "treant_protector"
	if "chakram" in skill_ids:
		return "timbersaw"
	if "mortimer_kisses" in skill_ids:
		return "snapfire"
	if "song_of_the_siren" in skill_ids:
		return "naga_siren"
	if "slithereen_crush" in skill_ids:
		return "slardar"
	if "sacred_arrow" in skill_ids:
		return "mirana"
	if "lucent_beam" in skill_ids:
		return "luna"
	return ""


## The full score for one candidate skill - already known to be
## learned, off cooldown, worth casting, affordable, and (in battle.gd)
## in range by the time this is called; this only ranks it against
## whatever else also survived those checks.
static func evaluate_skill(skill_id: String, level_data: Dictionary, context: Dictionary) -> float:
	var info: Dictionary = SKILL_INFO.get(skill_id, {"category": "utility", "base_score": 20.0})
	var category: String = info.get("category", "utility")
	var score: float = float(info.get("base_score", 20.0))

	match category:
		"offensive":
			score += _evaluate_offensive(skill_id, level_data, context)
		"defensive":
			score += _evaluate_defensive(context)
		"utility":
			score += _evaluate_utility(context)

	score += _hero_specific_modifier(str(context.get("archetype", "")), skill_id, level_data, context)
	score -= _resource_penalty(level_data, context)

	return score


## True if a plain Attack should be scored and compared directly
## against `archetype`'s real skills, rather than only ever being
## whatever happens when no skill candidate was found. Kunkka opts in
## because Tidebringer can make his next Attack genuinely worth more
## than any of his three active skills (see _kunkka_modifier()'s own
## "basic_attack" case); Winter Wyvern opts in for the same reason
## Arctic Burn is worth using at all - an Attack made while it's active
## realizes its buff's value instead of banking a charge that might
## expire unused (see _ww_basic_attack_modifier()). This stays a hero-
## gated switch rather than always-on so no other hero's existing
## behavior changes: for everyone else, a plain Attack is still purely
## the fallback for "nothing else qualified," exactly as before. Crystal
## Maiden opts in too: her whole kit is mana-hungry (70-330 a cast), so a
## plain Attack that can already finish a low-HP target off deserves a
## real shot at beating one of them outright - see
## _cm_basic_attack_modifier(). Tusk opts in for the same reason - his
## Walrus Punch in particular is an expensive ultimate that a cheap
## plain Attack can already make redundant against a low-HP target (see
## _tusk_basic_attack_modifier()/_tusk_walrus_punch_modifier()'s own
## early-out). Treant Protector opts in for the same reason as Snowball/
## Overgrowth's own early-outs (see _tp_leech_seed_modifier()/_tp_
## overgrowth_modifier()) - a free kill beats spending mana/cooldown for
## the same result. Timbersaw opts in too - Chakram in particular is a
## very expensive ultimate (200-350 mana) that a cheap plain Attack can
## already make redundant (see the design doc's own "one enemy at 20 HP
## should almost never justify a 350-mana ultimate" instruction and
## _timbersaw_chakram_modifier()'s own early-out). Snapfire opts in for
## the exact same reason - Mortimer Kisses is her own 200-350 mana
## ultimate, and Lil' Shredder specifically "competes directly with
## normal attacks" per the design doc's own instruction (see
## _snapfire_lil_shredder_modifier()'s own early-out). Naga Siren opts in
## too - the design doc's own explicit requirement that Basic Attack
## always remain a real candidate, able to win outright (see its own
## Scenario D: a low-HP target already in range, with Rip Tide's own
## splash, can beat every one of her real skills). Slardar opts in for
## the same "Basic Attack must always remain a candidate" requirement,
## made especially important by Bash of the Deep - a Bash-ready Attack
## with a real kill on the line can beat spending Corrosive Haze's own
## mana/cooldown on a target about to die anyway (see this file's own
## Scenario C). Mirana opts in too, for the same reason - Moonlight
## Shadow directly enhances her next Attack, so a plain Attack has to be
## a real contender, not just the fallback (see this file's own
## Scenario E). Luna opts in too - Moon Glaives/Lunar Blessing make her
## own plain Attack a real multi-target, passive-boosted action in its
## own right, not just the fallback for "nothing else qualified" (see
## _luna_basic_attack_modifier()'s own docstring).
static func basic_attack_participates(archetype: String) -> bool:
	return archetype == "kunkka" or archetype == "winter_wyvern" or archetype == "crystal_maiden" or archetype == "tusk" or archetype == "treant_protector" or archetype == "timbersaw" or archetype == "snapfire" or archetype == "naga_siren" or archetype == "slardar" or archetype == "mirana" or archetype == "luna"


## The score for a plain Attack, for a hero basic_attack_participates()
## opts in for. See BASELINE_BASIC_ATTACK_SCORE for why this doesn't
## route through _evaluate_offensive() - only the hero-specific modifier
## (Tidebringer's own bonus, for Kunkka) gives this any situational
## value at all.
static func evaluate_basic_attack(context: Dictionary) -> float:
	return BASELINE_BASIC_ATTACK_SCORE + _hero_specific_modifier(str(context.get("archetype", "")), BASIC_ATTACK_ID, {}, context)


# ------------------------------------------------------------------
# Category scoring - shared by every hero's skills of that category.
# Hero-specific behavior layers on top via _hero_specific_modifier()
# below, it never replaces this.
# ------------------------------------------------------------------

## Offensive: rewards a target that's already hurt, a real chance to
## finish it off, and - for a true AoE like Abyssal Spasm - extra living
## targets to hit at once. Torrent's own level-4 splash and Ghostship's
## whole "everyone the ship's path crosses" AoE get their own precise
## tiered bonuses in _kunkka_torrent_modifier()/_kunkka_ghostship_
## modifier() instead of this generic per-target formula, since the
## design calls for different, specific tiers for each rather than one
## shared curve.
static func _evaluate_offensive(skill_id: String, level_data: Dictionary, context: Dictionary) -> float:
	var target_hp: float = float(context.get("target_hp", 0.0))
	var target_max_hp: float = float(context.get("target_max_hp", 0.0))
	var enemy_count: int = int(context.get("enemy_count", 1))
	var estimated_damage: float = _estimate_skill_damage(skill_id, level_data, context)

	var score: float = 0.0
	if target_max_hp > 0.0:
		score += (1.0 - target_hp / target_max_hp) * 15.0
	score += _kill_potential_bonus(estimated_damage, target_hp)

	if skill_id == "abyssal_spasm":
		score += minf(float(enemy_count - 1), 4.0) * 8.0

	return score


## +50 for a clean kill, +10..+30 for a serious dent (>=50% of current
## HP), nothing for a glancing hit - see the design doc's Kill
## Potential section for why kill opportunities need to dominate.
static func _kill_potential_bonus(estimated_damage: float, target_hp: float) -> float:
	if target_hp <= 0.0 or estimated_damage <= 0.0:
		return 0.0
	if estimated_damage >= target_hp:
		return 50.0
	var pct: float = estimated_damage / target_hp
	if pct >= 0.5:
		return lerpf(10.0, 30.0, (pct - 0.5) / 0.5)
	return 0.0


## Defensive: the steep HP-ratio tiers Depthsveil's own design calls
## for (big at <20%, less at <35%, a little at <50%, nothing above
## that) - shared by every defensive skill (Veil of the Forgotten, Beast of the Elderwild,
## Wildbond) rather than reimplemented per hero. Being outnumbered
## adds a small bump on top, but only once a danger tier is already
## active - it must never by itself be enough to make a defensive skill
## outscore offense at full HP (a defensive skill's base_score alone,
## e.g. Depthsveil's 50, would otherwise already beat a lower-base
## offensive skill with nothing at stake - see the explicit "healthy"
## penalty below, without which Depthsveil/Beast of the Elderwild would fire every
## single turn regardless of HP).
static func _evaluate_defensive(context: Dictionary) -> float:
	var hp_ratio: float = float(context.get("hero_hp_ratio", 1.0))
	var enemy_pressure: float = minf(float(int(context.get("enemy_count", 1)) - 1), 3.0) * 5.0

	if hp_ratio < 0.20:
		return 80.0 + enemy_pressure
	elif hp_ratio < 0.35:
		return 45.0 + enemy_pressure
	elif hp_ratio < 0.50:
		return 20.0 + enemy_pressure
	elif hp_ratio < 0.70:
		return 0.0
	else:
		return -30.0


## Utility/setup: no bonus of its own (its value is long-term, not
## situational) but a penalty once things get dangerous, so a hero in
## real trouble reaches for offense/defense instead of a setup skill.
static func _evaluate_utility(context: Dictionary) -> float:
	var hp_ratio: float = float(context.get("hero_hp_ratio", 1.0))
	return -15.0 if hp_ratio < 0.35 else 0.0


## A small, deliberately gentle penalty proportional to how much of the
## hero's mana pool a skill eats - the "- Resource Penalty" term in the
## design doc. Kept subtle (at most -5) so it nudges rather than
## overrides everything above.
static func _resource_penalty(level_data: Dictionary, context: Dictionary) -> float:
	var max_mana: float = float(context.get("hero_max_mana", 0.0))
	if max_mana <= 0.0:
		return 0.0
	return (float(level_data.get("mana_cost", 0.0)) / max_mana) * 5.0


## A deterministic (no randi_range) estimate of how much damage
## `skill_id` would land right now, purely for scoring - actual damage
## still rolls its own way when the skill is actually cast. Add a case
## here for any new offensive skill; every other skill (buffs, summons,
## control-only casts) simply has no damage to estimate.
static func _estimate_skill_damage(skill_id: String, level_data: Dictionary, context: Dictionary) -> float:
	var hero_damage: float = float(context.get("hero_damage", 0.0))
	match skill_id:
		"abyssal_spasm":
			return hero_damage * float(level_data.get("damage_multiplier", 0.75))
		"barbed_lunge":
			return hero_damage
		"thornbind":
			return float(level_data.get("dot_damage", 0.0)) * float(level_data.get("dot_duration", 0.0))
		"whisper_of_the_veil", "torrent", "ghostship":
			return float(level_data.get("damage", 0.0))
		"cold_feet", "ice_vortex":
			# Both are pure DoTs with no upfront hit at all - their
			# entire value is damage x duration, never just the per-
			# turn tick (see the design doc's own "damage x duration,
			# not per-turn damage" note).
			return float(level_data.get("damage", 0.0)) * float(level_data.get("duration", 0.0))
		"chilling_touch":
			return hero_damage + float(level_data.get("bonus_damage", 0.0))
		"ice_blast":
			return float(level_data.get("damage", 0.0)) + float(level_data.get("dot_damage", 0.0)) * float(level_data.get("dot_duration", 0.0))
		"splinter_blast":
			return float(level_data.get("damage", 0.0))
		"crystal_nova":
			return float(level_data.get("damage", 0.0))
		"frostbite":
			# A pure DoT/control cast, same as Cold Feet/Ice Vortex above -
			# its entire damage value is dot_damage x dot_duration, never
			# just the per-turn tick.
			return float(level_data.get("dot_damage", 0.0)) * float(level_data.get("dot_duration", 0.0))
		"freezing_field":
			# Also a pure damage-over-time cast (on herself, hitting
			# whoever's in range each tick) - damage x duration, same
			# reasoning as Cold Feet/Ice Vortex/Frostbite above.
			return float(level_data.get("damage", 0.0)) * float(level_data.get("duration", 0.0))
		"ice_shards", "snowball":
			return float(level_data.get("damage", 0.0))
		"walrus_punch":
			# NOT a flat number - Walrus Punch's damage is Tusk's own
			# actual (already-rolled) Attack damage times this level's
			# own multiplier (see the design doc's own "do not treat
			# damage_multiplier as flat damage" note). `hero_damage` is
			# the same roll a plain Attack candidate would use (see
			# evaluate_basic_attack()). The 50% collision bonus is
			# deliberately NOT folded in here - it's conditional on
			# knockback actually being cut short, which only
			# _tusk_walrus_punch_modifier() (with real board data, or the
			# simulation's own proxy) is in a position to judge; this
			# stays the conservative no-collision baseline, same split
			# Ice Blast's own execute bonus uses versus its base estimate.
			return float(context.get("hero_damage", 0.0)) * float(level_data.get("damage_multiplier", 1.0))
		"leech_seed":
			# A pure DoT/sustain cast, same as Cold Feet/Ice Vortex/
			# Frostbite above - its entire damage value is dot_damage x
			# duration, never just the per-turn tick.
			return float(level_data.get("dot_damage", 0.0)) * float(level_data.get("duration", 0.0))
		"overgrowth":
			# Also a pure damage-over-time cast (on herself... himself,
			# hitting whoever's in range each tick) - dot_damage x
			# root_duration, same reasoning as Freezing Field's own case.
			return float(level_data.get("dot_damage", 0.0)) * float(level_data.get("root_duration", 0.0))
		"whirling_death", "timber_chain":
			return float(level_data.get("damage", 0.0))
		"chakram":
			# Only the initial cast_damage - the persistent damage_per_
			# turn ticks are estimated separately (and much more
			# conservatively - see the design doc's own "do not
			# automatically assume every enemy stays inside the radius
			# for the full duration" instruction), in _timbersaw_chakram_
			# modifier() rather than here.
			return float(level_data.get("cast_damage", 0.0))
		"scatterblast", "firesnap_cookie":
			return float(level_data.get("damage", 0.0))
		"lil_shredder":
			# The FULL volley's own expected total, not just one shot -
			# Lil' Shredder is inherently a multi-hit sequence at the same
			# target, so "can this kill it" has to weigh all `shots` of
			# them (a conservative estimate: the actual cast lands
			# slightly harder than this once armor_reduction starts
			# stacking mid-volley, but this stays the simple, un-inflated
			# baseline, same "do not assume" caution the design doc's own
			# armor-reduction-duration instruction calls for elsewhere).
			return float(context.get("hero_damage", 0.0)) * float(level_data.get("damage_pct", 0.0)) * float(level_data.get("shots", 1))
		"mortimer_kisses":
			# Only the first shot's own main_damage - persistent/tracked
			# follow-up shots are never guaranteed to land on the same
			# target (see the design doc's own "do not assume all three
			# shots automatically hit the same target" instruction), so
			# those are estimated separately, more conservatively, in
			# _snapfire_mortimer_kisses_modifier() instead.
			return float(level_data.get("main_damage", 0.0))
		"ensnare":
			return float(level_data.get("damage", 0.0))
		"song_of_the_siren":
			return _naga_song_expected_damage(level_data, context)
		"slithereen_crush":
			return float(level_data.get("damage", 0.0))
		"corrosive_haze":
			return _slardar_corrosive_haze_expected_damage(level_data, context)
		"starstorm":
			return float(level_data.get("damage", 0.0))
		"sacred_arrow":
			return _mirana_sacred_arrow_expected_damage(level_data, context)
		"lucent_beam":
			return float(level_data.get("damage", 0.0))
		"eclipse":
			return _luna_eclipse_expected_damage(level_data, context)
		_:
			return 0.0


# ------------------------------------------------------------------
# Hero-specific modifiers - the only place per-hero "personality" is
# encoded. Dispatched by archetype then by skill id via match, so
# adding a new hero or a new per-skill quirk is one new match branch,
# never a combinatorial if/elif chain.
# ------------------------------------------------------------------

static func _hero_specific_modifier(archetype: String, skill_id: String, level_data: Dictionary, context: Dictionary) -> float:
	match archetype:
		"veyrik":
			return _veyrik_modifier(skill_id, level_data, context)
		"erynd":
			return _erynd_modifier(skill_id, level_data, context)
		"morvael":
			return _morvael_modifier(skill_id, level_data, context)
		"kunkka":
			return _kunkka_modifier(skill_id, level_data, context)
		"ancient_apparition":
			return _ancient_apparition_modifier(skill_id, level_data, context)
		"winter_wyvern":
			return _winter_wyvern_modifier(skill_id, level_data, context)
		"crystal_maiden":
			return _crystal_maiden_modifier(skill_id, level_data, context)
		"tusk":
			return _tusk_modifier(skill_id, level_data, context)
		"treant_protector":
			return _treant_modifier(skill_id, level_data, context)
		"timbersaw":
			return _timbersaw_modifier(skill_id, level_data, context)
		"snapfire":
			return _snapfire_modifier(skill_id, level_data, context)
		"naga_siren":
			return _naga_siren_modifier(skill_id, level_data, context)
		"slardar":
			return _slardar_modifier(skill_id, level_data, context)
		"mirana":
			return _mirana_modifier(skill_id, level_data, context)
		"luna":
			return _luna_modifier(skill_id, level_data, context)
		_:
			return 0.0


## Veyrik: an aggressive kill-seeker. Barbed Lunge gets a further top-up when
## it can personally close out the kill (on top of the generic kill
## bonus every offensive skill already gets), and Leeching Hunger is more
## attractive when Veyrik is healthy enough to expect to land the
## follow-up hits it needs to pay off.
static func _veyrik_modifier(skill_id: String, level_data: Dictionary, context: Dictionary) -> float:
	match skill_id:
		"barbed_lunge":
			var target_hp: float = float(context.get("target_hp", 0.0))
			var dmg: float = _estimate_skill_damage(skill_id, level_data, context)
			return 15.0 if (target_hp > 0.0 and dmg >= target_hp) else 0.0
		"leeching_hunger":
			return 15.0 if float(context.get("hero_hp_ratio", 1.0)) > 0.6 else 0.0
		_:
			return 0.0


## Erynd: leans hard on his Elderwild Companion. A missing/dead bear is
## treated as a near-emergency (a big enough bonus to beat almost
## everything except a genuine defensive crisis - see
## _evaluate_defensive()'s own <20% HP tier); once the bear is up,
## Thornbind/Wildbond get a small synergy bump instead.
static func _erynd_modifier(skill_id: String, level_data: Dictionary, context: Dictionary) -> float:
	var bear_active: bool = bool(context.get("bear_active", false))
	match skill_id:
		"elderwild_companion":
			return 0.0 if bear_active else 70.0
		"thornbind":
			return 10.0 if bear_active else 0.0
		"wildbond":
			return 15.0 if bear_active else 0.0
		_:
			return 0.0


## Morvael: defensive/reactive, not a nuker. He'd rather put Veil of the
## Forgotten up before things get dangerous than only as a last resort
## (unlike Depthsveil/Beast of the Elderwild's own "wait for real danger" curve),
## and only reaches for Whisper of the Veil's damage when it's actually a
## meaningful hit - otherwise he holds back rather than trading his own
## resources for a marginal poke.
static func _morvael_modifier(skill_id: String, level_data: Dictionary, context: Dictionary) -> float:
	match skill_id:
		"veil_of_the_forgotten":
			return 10.0 if float(context.get("hero_hp_ratio", 1.0)) < 0.7 else 0.0
		"whisper_of_the_veil":
			var target_hp: float = float(context.get("target_hp", 0.0))
			var dmg: float = _estimate_skill_damage(skill_id, level_data, context)
			return -10.0 if (target_hp > 0.0 and dmg < target_hp * 0.3) else 0.0
		"whisper_of_the_veil_self":
			return _morvael_whisper_of_the_veil_self_modifier(level_data, context)
		_:
			return 0.0


## Morvael's self-cast Whisper of the Veil, on top of the shared defensive HP
## tiers (_evaluate_defensive() - big when badly hurt, a penalty when
## healthy): how much of the heal would actually land. It costs
## hp_cost first, then heals `heal`, capped at max HP - so near full
## health most of it is wasted, and it's marked down accordingly
## (+8 when every point counts, down to -12 when barely any does).
## Never picked if paying the cost would kill him, or if it would
## leave him no better off than before.
static func _morvael_whisper_of_the_veil_self_modifier(level_data: Dictionary, context: Dictionary) -> float:
	var hp: float = float(context.get("hero_hp", 0.0))
	var max_hp: float = float(context.get("hero_max_hp", 0.0))
	var hp_cost: float = float(level_data.get("hp_cost", 0.0))
	var heal: float = float(level_data.get("heal", 0.0))
	var net_heal: float = heal - hp_cost
	if hp <= hp_cost or max_hp <= 0.0 or net_heal <= 0.0:
		return -1000.0

	var gain: float = minf(hp - hp_cost + heal, max_hp) - hp
	if gain <= 0.0:
		return -1000.0
	var efficiency: float = gain / net_heal
	return lerpf(-12.0, 8.0, clampf(efficiency, 0.0, 1.0))


## Kunkka: offensive, control, burst, positioning, combo-oriented. Every
## branch below is one piece of that: Torrent's own multi-target/stun
## value, Ghostship's own AoE/multi-kill value, X Marks the Spot's value
## as a setup move (worthless on its own, valuable only for what it
## enables), and a plain Attack's value once Tidebringer is about to pay
## off - see BASIC_ATTACK_ID/basic_attack_participates().
static func _kunkka_modifier(skill_id: String, level_data: Dictionary, context: Dictionary) -> float:
	match skill_id:
		"torrent":
			return _kunkka_torrent_modifier(level_data, context)
		"ghostship":
			return _kunkka_ghostship_modifier(level_data, context)
		"x_marks_the_spot":
			return _kunkka_xmarks_modifier(context)
		BASIC_ATTACK_ID:
			return _kunkka_basic_attack_modifier(context)
		_:
			return 0.0


## Torrent: on top of the generic offensive scoring every damage skill
## already gets (target value, kill potential), this adds the two
## things unique to Torrent's own design - its level-4 splash (a
## smaller, cheaper AoE than Ghostship's, so smaller bonuses) and its
## stun, worth more at 2 turns than at 1 since it buys a full extra free
## hit rather than just a delayed one.
static func _kunkka_torrent_modifier(level_data: Dictionary, context: Dictionary) -> float:
	var score: float = 0.0
	var has_splash: bool = float(level_data.get("radius", 0.0)) > 0.0

	if has_splash:
		var living_hps: Array = context.get("living_target_hps", [])
		var extra_targets: int = maxi(living_hps.size() - 1, 0)
		if extra_targets >= 2:
			score += 40.0
		elif extra_targets == 1:
			score += 22.5

		var damage: float = float(level_data.get("damage", 0.0))
		var extra_kills: int = 0
		for hp in living_hps:
			if damage >= float(hp) and float(hp) > 0.0:
				extra_kills += 1
		# The primary target's own kill is already scored generically
		# (see _kill_potential_bonus(), fed by target_hp) - this only
		# adds for kills BEYOND that one.
		if extra_kills >= 2:
			score += 40.0 * float(extra_kills - 1)

	var stun_turns: int = int(level_data.get("stun_turns", 0))
	if stun_turns >= 2:
		score += 25.0
	elif stun_turns >= 1:
		score += 10.0

	return score


## Ghostship: Kunkka's biggest single play, so it leans hardest on how
## many targets the ship's path actually reaches (every living target
## in this game's simplified "no columns" execution - see both
## _cast_enemy_ghostship() and EnemyHeroManager's own "ghostship" case)
## and how many of them it can also kill outright, same "primary kill is
## already generic, only extra kills add here" split Torrent's own
## modifier uses.
static func _kunkka_ghostship_modifier(level_data: Dictionary, context: Dictionary) -> float:
	var living_hps: Array = context.get("living_target_hps", [])
	var hit_count: int = living_hps.size()

	var score: float = 0.0
	if hit_count >= 4:
		score += 70.0
	elif hit_count == 3:
		score += 50.0
	elif hit_count == 2:
		score += 30.0
	elif hit_count == 1:
		score += 10.0

	var damage: float = float(level_data.get("damage", 0.0))
	var extra_kills: int = 0
	for hp in living_hps:
		if damage >= float(hp) and float(hp) > 0.0:
			extra_kills += 1
	if extra_kills >= 2:
		score += 50.0 * float(extra_kills - 1)

	return score


## X Marks the Spot deals no damage itself - its entire value is either
## the guaranteed teleport closing distance, or (far more so) setting up
## a real follow-up next turn. Worthless (and a waste of mana/cooldown)
## if Kunkka is already standing right on the target, so it's penalized
## outright at melee range; otherwise a small flat value for closing
## distance at all, plus a much larger combo bonus if Ghostship or
## Torrent would actually be usable the moment the teleport lands (see
## battle.gd's own "kunkka_torrent_combo_ready"/"kunkka_ghostship_combo_
## ready" context fields - a REAL cooldown/mana/worth-casting check, not
## just "is it off cooldown"). Ghostship's own combo bonus wins over
## Torrent's when both are ready, matching Ghostship being the bigger
## payoff. Neither combo field exists in the simulation (X Marks isn't
## even a candidate there - see KNOWN_ACTIVE_SKILL_IDS's own comment),
## so this only ever does anything in a real battle.
static func _kunkka_xmarks_modifier(context: Dictionary) -> float:
	if int(context.get("target_distance", 0)) <= 0:
		return -30.0

	var score: float = 10.0
	if bool(context.get("kunkka_ghostship_combo_ready", false)):
		score += 35.0
	elif bool(context.get("kunkka_torrent_combo_ready", false)):
		score += 30.0
	return score


## A plain Attack is only worth scoring above its flat baseline for
## Kunkka when Tidebringer is actually about to pay off - see
## BASIC_ATTACK_ID/basic_attack_participates(). `tidebringer_cleave_
## targets` is already 0 in a real hero fight (there's only ever the
## player to cleave onto - see battle.gd's own _build_enemy_ai_context()
## comment), so the cleave top-up only ever fires in the simulation.
static func _kunkka_basic_attack_modifier(context: Dictionary) -> float:
	if not bool(context.get("tidebringer_ready", false)):
		return 0.0

	var score: float = 20.0
	var cleave_targets: int = int(context.get("tidebringer_cleave_targets", 0))
	if cleave_targets > 0:
		score += minf(float(cleave_targets), 3.0) * 15.0
	return score


## Ancient Apparition: ranged, DoT/execute-oriented caster. Cold Feet/
## Ice Vortex lean on total-damage-over-time and how many targets are
## caught in it (see _estimate_skill_damage()'s own "damage x duration"
## cases for both, which already feeds the generic kill-potential
## bonus); Chilling Touch is deliberately left to pure generic offensive
## scoring (it's just the hero's own attack damage plus a flat bonus -
## nothing AA-specific to add on top); Ice Blast gets the most
## elaborate treatment of anything in this file, since its AoE and
## execute mechanic both need dedicated modeling - see
## _aa_ice_blast_modifier().
static func _ancient_apparition_modifier(skill_id: String, level_data: Dictionary, context: Dictionary) -> float:
	match skill_id:
		"cold_feet":
			return _aa_cold_feet_modifier(context)
		"ice_vortex":
			return _aa_ice_vortex_modifier(level_data, context)
		"chilling_touch":
			# Its effective damage (hero_damage + bonus_damage) and the
			# target-value/kill-potential terms that damage feeds are
			# already fully covered by the shared _evaluate_offensive()
			# - nothing AA-specific to add here.
			return 0.0
		"ice_blast":
			return _aa_ice_blast_modifier(level_data, context)
		_:
			return 0.0


## Cold Feet: on top of the generic offensive scoring (which already
## uses damage x duration as its damage estimate - see
## _estimate_skill_damage() - so a long, high-level freeze already
## scores its kill potential correctly), a further top-up for an
## already-low-HP target, per the design doc's explicit "<30%/<20%"
## tiers. Not worth recasting on an already-frozen target at all - see
## _enemy_skill_worth_casting()'s/_npc_skill_worth_casting()'s own
## "cold_feet" gate, which keeps it out of the candidate list entirely
## rather than scoring it low here.
static func _aa_cold_feet_modifier(context: Dictionary) -> float:
	var target_hp: float = float(context.get("target_hp", 0.0))
	var target_max_hp: float = float(context.get("target_max_hp", 0.0))
	if target_max_hp <= 0.0:
		return 0.0

	var hp_ratio: float = target_hp / target_max_hp
	if hp_ratio < 0.20:
		return 20.0
	elif hp_ratio < 0.30:
		return 10.0
	return 0.0


## Ice Vortex: an AoE DoT, so - like Ghostship - it leans hardest on how
## many targets it actually reaches (every living target, in this
## game's own simplified "no columns" AoE execution) and how many of
## them its own total damage-over-time (damage x duration) would also
## kill. In a real hero fight `enemy_count`/`living_target_hps` are
## always just the one player, so this collapses to the "1 target: +5"
## tier plus whatever the generic kill-potential bonus already gives it
## - exactly like every other AoE skill's own rival-side simplification.
static func _aa_ice_vortex_modifier(level_data: Dictionary, context: Dictionary) -> float:
	var enemy_count: int = int(context.get("enemy_count", 1))
	var score: float = 0.0

	if enemy_count >= 4:
		score += 65.0
	elif enemy_count == 3:
		score += 45.0
	elif enemy_count == 2:
		score += 25.0
	elif enemy_count == 1:
		score += 5.0

	var living_hps: Array = context.get("living_target_hps", [])
	var total_dot: float = float(level_data.get("damage", 0.0)) * float(level_data.get("duration", 0.0))
	var extra_kills: int = 0
	for hp in living_hps:
		if total_dot >= float(hp) and float(hp) > 0.0:
			extra_kills += 1
	# The primary target's own kill is already scored generically (see
	# _kill_potential_bonus(), fed by target_hp/_estimate_skill_damage's
	# own "cold_feet"/"ice_vortex" case) - this only adds for kills
	# BEYOND that one, same split Torrent's/Ghostship's own modifiers use.
	if extra_kills >= 2:
		score += 35.0 * float(extra_kills - 1)

	return score


## Ice Blast: Ancient Apparition's highest-value play, and the most
## elaborate scoring in this file - it has to value THREE things a
## normal AoE nuke doesn't: how many targets its radius reaches, how
## many of them its raw damage would also kill (both handled the same
## way Ghostship's own modifier does), and - the mechanic that matters
## most here - how many of them its damage+DoT would push at or below
## their own execute threshold (max_hp x execute_pct) even without
## fully depleting their HP. See _aa_ice_blast_execute_score() for how
## that last one is actually worked out per-target. In a real hero
## fight `living_target_hps`/`living_target_max_hps` are always just
## the one player, so the AoE/multi-kill terms collapse to their own
## "1 target" tiers, exactly like every other AoE skill's own rival-
## side simplification - only the execute term still does real work
## there.
##
## Target selection: this project's own AoE skills (Abyssal Spasm, Torrent's
## splash, Ghostship, Ice Vortex) already always hit either the single
## player (a hero fight) or literally every living enemy (this sim's own
## "no columns" simplification - see EnemyHeroManager's own "ice_blast"
## case) rather than requiring a chosen center point that only reaches
## SOME of them. So there's no separate "which target produces the
## highest total value" search to run here the way a real multi-column
## fight would need - every living target is already "the one Ice Blast
## would hit," and this modifier simply sums each of their contributions.
static func _aa_ice_blast_modifier(level_data: Dictionary, context: Dictionary) -> float:
	var living_hps: Array = context.get("living_target_hps", [])
	var living_max_hps: Array = context.get("living_target_max_hps", living_hps)
	var hit_count: int = living_hps.size()

	var score: float = 0.0
	if hit_count >= 4:
		score += 80.0
	elif hit_count == 3:
		score += 55.0
	elif hit_count == 2:
		score += 30.0
	elif hit_count == 1:
		score += 10.0

	var damage: float = float(level_data.get("damage", 0.0))
	var extra_kills: int = 0
	var execute_score: float = 0.0

	for i in range(hit_count):
		var hp: float = float(living_hps[i])
		if hp <= 0.0:
			continue

		var after_initial_hit: float = hp - damage
		if after_initial_hit <= 0.0:
			extra_kills += 1
			continue

		var max_hp: float = float(living_max_hps[i]) if i < living_max_hps.size() else hp
		execute_score += _aa_ice_blast_execute_score(after_initial_hit, max_hp, level_data)

	# The primary target's own kill is already scored generically (see
	# _kill_potential_bonus(), fed by target_hp/_estimate_skill_damage's
	# own "ice_blast" case, which already folds the DoT into its own
	# kill-potential estimate) - this only adds for kills BEYOND that
	# one, same split Torrent's/Ghostship's own modifiers use.
	if extra_kills >= 2:
		score += 50.0 * float(extra_kills - 1)

	score += execute_score

	var stun_turns: int = int(level_data.get("stun_turns", 0))
	if stun_turns >= 2:
		score += 25.0
	elif stun_turns >= 1:
		score += 10.0

	return score


## The execute mechanic, explicitly modeled: a target hit by Ice Blast
## reserves execute_pct of its OWN max HP for the DoT's duration - the
## instant its current HP ever drops to or below that reserved amount
## (checked once per tick, not continuously - see battle.gd's own
## _tick_ice_blast_effects()), it dies outright regardless of how much
## HP is technically still there. `hp_after_initial_hit` is what a
## target has left right after Ice Blast's own upfront `damage` (a
## target already fully killed by that alone is handled by the caller's
## own `extra_kills`, never passed in here). This is deliberately one of
## the largest modifiers in the whole file, per the design doc's own
## "one of the strongest modifiers in the entire AI system" instruction.
static func _aa_ice_blast_execute_score(hp_after_initial_hit: float, max_hp: float, level_data: Dictionary) -> float:
	var execute_pct: float = float(level_data.get("execute_pct", 0.0))
	if execute_pct <= 0.0 or max_hp <= 0.0:
		return 0.0

	var threshold: float = max_hp * execute_pct
	if threshold <= 0.0:
		return 0.0

	if hp_after_initial_hit <= threshold:
		# Already guaranteed to die the very next DoT tick, no matter
		# how much of hp_after_initial_hit is technically still there.
		return 70.0

	var total_dot: float = float(level_data.get("dot_damage", 0.0)) * float(level_data.get("dot_duration", 0.0))
	if hp_after_initial_hit - total_dot <= threshold:
		# The DoT alone finishes the job before it expires.
		return 40.0

	if hp_after_initial_hit - threshold <= total_dot * 1.5:
		# Not quite guaranteed, but close enough that incidental damage
		# from elsewhere (an ally's hit, another DoT) plausibly closes
		# the remaining gap - worth a smaller speculative bonus.
		return 15.0

	return 0.0


## Winter Wyvern: ranged, offensive/defensive/control, reaction-
## oriented. Arctic Burn is a setup buff (only worth its base_score once
## it can realistically turn into real damage - see _ww_arctic_burn_
## modifier()); Splinter Blast is the main burst/AoE option (generic
## offensive scoring already handles its primary hit, this only adds
## its own splash-specific terms); Cold Embrace and Winter's Curse are
## both "defensive" category (see SKILL_INFO), so both already get the
## shared HP-ratio tiers _evaluate_defensive() provides for free - this
## only layers each skill's own extra factors on top (healing/buff-
## removal for Cold Embrace, redirected-enemy count for Winter's Curse).
static func _winter_wyvern_modifier(skill_id: String, level_data: Dictionary, context: Dictionary) -> float:
	match skill_id:
		"arctic_burn":
			return _ww_arctic_burn_modifier(level_data, context)
		"splinter_blast":
			return _ww_splinter_blast_modifier(level_data, context)
		"cold_embrace":
			return _ww_cold_embrace_modifier(level_data, context)
		"winter's_curse":
			return _ww_winters_curse_modifier(level_data, context)
		BASIC_ATTACK_ID:
			return _ww_basic_attack_modifier(context)
		_:
			return 0.0


## Arctic Burn's real value is buff_value x expected useful attacks
## within its own attacks-or-duration limit (whichever is smaller - see
## the skill's own design doc), not just its raw bonus_damage stat - a
## level with a huge bonus_damage but only 2 banked attacks isn't worth
## as much as the number alone suggests. Scores low if there's no
## realistic attack coming at all (context's own "in_attack_range_now"/
## "in_attack_range_with_arctic_burn_bonus" - always true in the
## simulation, real column distance in battle.gd), and a little extra if
## the bonus range specifically is what closes the gap - "already active"
## is gated at the candidacy level instead (see _enemy_skill_worth_
## casting()'s/_npc_skill_worth_casting()'s own "arctic_burn" case), same
## as every other self-buff in this file.
static func _ww_arctic_burn_modifier(level_data: Dictionary, context: Dictionary) -> float:
	var can_attack_now: bool = bool(context.get("in_attack_range_now", true))
	var can_attack_with_bonus: bool = bool(context.get("in_attack_range_with_arctic_burn_bonus", true))

	if not can_attack_now and not can_attack_with_bonus:
		return -25.0

	var attacks: int = int(level_data.get("attacks", 0))
	var duration: int = int(level_data.get("duration", 0))
	var expected_attacks: int = mini(attacks, duration)
	var bonus_damage: float = float(level_data.get("bonus_damage", 0.0))

	var score: float = bonus_damage * 0.3 * float(expected_attacks)
	if can_attack_with_bonus and not can_attack_now:
		# The extended range specifically is what makes this worthwhile
		# right now - a genuine tactical advantage, not just a buff cast
		# into the void.
		score += 10.0

	return score


## Splinter Blast: on top of the generic offensive scoring the primary
## hit already gets (target value, kill potential - via _estimate_
## skill_damage()'s own "splinter_blast" case), this adds the AoE tier
## for however many total targets are in play and a bonus for each
## SECONDARY target (i.e. every living target except the primary, which
## is always the lowest-HP one - see _lowest_hp_enemy()'s established
## convention) the splash damage alone would also kill. A hero fight
## only ever has the player as a possible target, so this collapses to
## the "1 target: +5" tier there, same as every other AoE skill's own
## rival-side simplification.
static func _ww_splinter_blast_modifier(level_data: Dictionary, context: Dictionary) -> float:
	var living_hps: Array = context.get("living_target_hps", [])
	var total_count: int = living_hps.size()

	var score: float = 0.0
	if total_count >= 4:
		score += 65.0
	elif total_count == 3:
		score += 45.0
	elif total_count == 2:
		score += 25.0
	elif total_count == 1:
		score += 5.0

	var splinter_damage: float = float(level_data.get("splinter_damage", 0.0))
	var sorted_hps: Array = living_hps.duplicate()
	sorted_hps.sort()
	var extra_kills: int = 0
	for i in range(1, sorted_hps.size()):
		if splinter_damage >= float(sorted_hps[i]) and float(sorted_hps[i]) > 0.0:
			extra_kills += 1
	if extra_kills >= 1:
		score += 35.0 * float(extra_kills)

	return score


## Cold Embrace: on top of the shared defensive HP-ratio tiers
## (_evaluate_defensive(), already covering "large score increase when
## in danger" and the "healthy -> penalty" that stops it from being cast
## just because it's available - see that function's own docstring for
## why), this adds its own two extra factors: the healing itself (only
## worth anything once actually hurt - full HP has nothing to heal
## into), and the cost/benefit of what casting it would dispel - a
## penalty if Arctic Burn is currently running (a real buff that would
## be thrown away), a bonus if the rival currently has a harmful debuff
## on it (which Cold Embrace would clear for free). The "can't move or
## attack while encased" opportunity cost isn't a separate term here -
## it's already what the healthy-HP penalty in _evaluate_defensive()
## represents: safe and free to keep attacking is exactly when this
## skill scores worst.
static func _ww_cold_embrace_modifier(level_data: Dictionary, context: Dictionary) -> float:
	var score: float = 0.0

	var hp_ratio: float = float(context.get("hero_hp_ratio", 1.0))
	if hp_ratio < 0.85:
		var heal: float = float(level_data.get("heal", 0.0))
		var duration: int = int(level_data.get("duration", 0))
		score += minf(heal * float(duration) * 0.05, 30.0)

	if bool(context.get("arctic_burn_active", false)):
		score -= 15.0
	if bool(context.get("has_harmful_debuff", false)):
		score += 15.0

	return score


## Winter's Curse: on top of the shared defensive HP-ratio tiers (see
## Cold Embrace's own docstring above for why this skill benefits from
## them too - a curse that removes attackers is exactly the kind of
## "defensive value" those tiers already model), this adds the design
## doc's own redirect-count tiers (0/1/2/3/4+ redirected enemies) and an
## estimate of the bonus damage those redirected enemies would deal to
## the frozen target instead of to Winter Wyvern - a simple, bounded
## normalized estimate (redirect count x their own average damage stat x
## bonus_damage_pct x duration) rather than trying to predict exact
## future turns, per the design doc's own fallback guidance. A hero
## fight only ever has the player to curse and nothing else on the
## rival's own side to redirect (see battle.gd's own "redirect_
## candidate_count" comment), so this collapses to the "0 redirected:
## +0" tier there - the ultimate still isn't wasted, since the shared
## HP-ratio tiers alone can make it worth using purely to freeze a
## dangerous player in place.
static func _ww_winters_curse_modifier(level_data: Dictionary, context: Dictionary) -> float:
	var redirect_count: int = int(context.get("redirect_candidate_count", 0))
	var score: float = 0.0

	if redirect_count >= 4:
		score += 100.0
	elif redirect_count == 3:
		score += 70.0
	elif redirect_count == 2:
		score += 45.0
	elif redirect_count == 1:
		score += 20.0

	var bonus_damage_pct: float = float(level_data.get("bonus_damage_pct", 0.0))
	var duration: int = int(level_data.get("duration", 0))
	var avg_enemy_damage: float = float(context.get("avg_enemy_damage", 0.0))
	score += minf(float(redirect_count) * avg_enemy_damage * bonus_damage_pct * float(duration) * 0.1, 40.0)

	if redirect_count >= 2 and float(context.get("hero_hp_ratio", 1.0)) < 0.5:
		# Compounding value: pulling multiple attackers off Winter
		# Wyvern while she's already in real danger, not just a
		# comfortable AoE opportunity.
		score += 25.0

	return score


## A plain Attack is only worth scoring above its flat baseline for
## Winter Wyvern when Arctic Burn is currently active - attacking
## realizes the buff's value (bonus damage, and spends one of its banked
## charges) instead of leaving it to potentially expire unused. See
## BASIC_ATTACK_ID/basic_attack_participates().
static func _ww_basic_attack_modifier(context: Dictionary) -> float:
	return 25.0 if bool(context.get("arctic_burn_active", false)) else 0.0


## Crystal Maiden: ranged, control/burst/AoE, mana-aware. Crystal Nova's
## generic offensive scoring already covers its primary hit (target
## value, kill potential - via _estimate_skill_damage()'s own
## "crystal_nova" case); this only adds its own splash-specific terms
## once its radius actually exists (level 3+ - see _cm_crystal_nova_
## modifier()). Frostbite is "offensive" category too (so it gets the
## same generic kill-potential/target-value terms, fed by its own DoT-
## totaled _estimate_skill_damage() case) - this layers its control
## value (stun_turns) and defensive value (hero_hp_ratio) on top (see
## _cm_frostbite_modifier()). Freezing Field is the one skill here that
## ISN'T a targeted cast - it's centered on Crystal Maiden's own
## position, never a selected enemy's (see _cm_freezing_field_
## modifier()'s own docstring for how that's told apart from a normal
## AoE in a codebase where every existing AoE skill is either target-
## centered or "no columns, hit everyone").
static func _crystal_maiden_modifier(skill_id: String, level_data: Dictionary, context: Dictionary) -> float:
	match skill_id:
		"crystal_nova":
			return _cm_crystal_nova_modifier(level_data, context)
		"frostbite":
			return _cm_frostbite_modifier(level_data, context)
		"freezing_field":
			return _cm_freezing_field_modifier(level_data, context)
		BASIC_ATTACK_ID:
			return _cm_basic_attack_modifier(context)
		_:
			return 0.0


## Crystal Nova: radius is 0 at levels 1-2 (a single-target nuke - the
## generic offensive scoring above already covers it in full, so this
## adds nothing extra), and 1-2 at levels 3-4, at which point every
## other living target within it takes the same damage too. Target
## count tiers mirror Winter's Splinter Blast/Ancient Apparition's Ice
## Blast (see _ww_splinter_blast_modifier()/_aa_ice_blast_modifier());
## the multi-kill bonus below only counts kills BEYOND the primary
## target's own (already scored generically via _kill_potential_bonus()),
## same split those two use. A hero fight only ever has the player as a
## possible target (see _build_enemy_ai_context()'s own docstring), so
## this collapses to the "1 target: +5" tier there, same as every other
## AoE skill's own rival-side simplification.
static func _cm_crystal_nova_modifier(level_data: Dictionary, context: Dictionary) -> float:
	var radius: int = int(level_data.get("radius", 0))
	if radius <= 0:
		return 0.0

	var living_hps: Array = context.get("living_target_hps", [])
	var total_count: int = living_hps.size()

	var score: float = 0.0
	if total_count >= 4:
		score += 65.0
	elif total_count == 3:
		score += 45.0
	elif total_count == 2:
		score += 25.0
	elif total_count == 1:
		score += 5.0

	var damage: float = float(level_data.get("damage", 0.0))
	var sorted_hps: Array = living_hps.duplicate()
	sorted_hps.sort()
	var extra_kills: int = 0
	for i in range(1, sorted_hps.size()):
		if damage >= float(sorted_hps[i]) and float(sorted_hps[i]) > 0.0:
			extra_kills += 1
	if extra_kills >= 1:
		score += 35.0 * float(extra_kills)

	return score


## Frostbite: control is at least as important as the damage here (per
## the design doc), so a 2-turn stun scores substantially higher than a
## 1-turn one, and being in real danger (low hero_hp_ratio - the same
## signal every defensive skill in this file already keys off, via
## _evaluate_defensive()) adds its own separate defensive bonus on top,
## even though Frostbite itself is "offensive" category (so it doesn't
## get _evaluate_defensive()'s tiers automatically). enemy_count is a
## small extra nudge for "also outnumbered while hurt" - always 1 in a
## real hero fight (a no-op there), the simulation's actual living-
## enemy count otherwise. Recasting on an already-frostbitten target is
## gated out at the candidacy level instead (see battle.gd's own
## _enemy_skill_worth_casting()'s "frostbite" case), same as every
## other already-active check in this file - the simulation doesn't
## mirror that gate, since its own target is always whichever living
## enemy is currently lowest-HP (see EnemyHeroManager's own _build_npc_
## ai_context() docstring), which can be a different one turn to turn.
static func _cm_frostbite_modifier(level_data: Dictionary, context: Dictionary) -> float:
	var score: float = 0.0

	var stun_turns: int = int(level_data.get("stun_turns", 0))
	if stun_turns >= 2:
		score += 40.0
	elif stun_turns >= 1:
		score += 20.0

	var hp_ratio: float = float(context.get("hero_hp_ratio", 1.0))
	if hp_ratio < 0.35:
		score += 35.0
	elif hp_ratio < 0.50:
		score += 15.0

	if int(context.get("enemy_count", 1)) >= 2 and hp_ratio < 0.5:
		score += 10.0

	return score


## Freezing Field: the one skill in this file centered on the CASTER's
## own position rather than a selected enemy's. `target_distance` is
## battle.gd's already-computed distance from Crystal Maiden's own
## pos_index to the player (see _build_enemy_ai_context()) - reused
## here rather than re-derived, and never present in the simulation's
## own context (no positions there at all - see EnemyHeroManager's own
## _build_npc_ai_context() docstring), where a missing value defaults to
## "in range," matching every other AoE skill's own "no columns, hit
## everyone" simplification there. Out of range in a real fight, this is
## a low-value cast (see the design doc's own "do not cast merely
## because it's available" note) - there's nothing else close enough to
## hit instead (a hero fight only ever has the player as a possible
## target), so the duration would very likely tick out unused. In range
## (or in the simulation), this layers the design doc's own multi-target/
## low-HP/multi-kill tiers on top of the generic kill-potential/"already
## hurt" terms _evaluate_offensive() already provides (fed by this
## skill's own damage x duration _estimate_skill_damage() case) - the
## same split Ice Blast's/Splinter Blast's own modifiers use for their
## own multi-kill bonus. The survivability penalty is deliberately small
## and only fires when things are clearly dire (hero_hp_ratio < 30% AND
## multiple living enemies) - Freezing Field has no invented immunity/
## stun/slow of its own to lean on here (per the design doc's own "use
## only mechanics that actually exist" note), so this is a real cost,
## not a wash.
static func _cm_freezing_field_modifier(level_data: Dictionary, context: Dictionary) -> float:
	var radius: int = int(level_data.get("radius", 0))
	var raw_distance: int = int(context.get("target_distance", -1))
	var in_range: bool = raw_distance < 0 or raw_distance <= radius

	if not in_range:
		return -35.0

	var living_hps: Array = context.get("living_target_hps", [])
	var living_max_hps: Array = context.get("living_target_max_hps", living_hps)
	var hit_count: int = living_hps.size()

	var score: float = 0.0
	if hit_count >= 4:
		score += 90.0
	elif hit_count == 3:
		score += 60.0
	elif hit_count == 2:
		score += 35.0
	elif hit_count == 1:
		score += 10.0

	var total_dot: float = float(level_data.get("damage", 0.0)) * float(level_data.get("duration", 0.0))
	var extra_kills: int = 0
	var low_hp_count: int = 0
	for i in range(hit_count):
		var hp: float = float(living_hps[i])
		if hp <= 0.0:
			continue
		var max_hp: float = float(living_max_hps[i]) if i < living_max_hps.size() else hp
		if max_hp > 0.0 and hp <= max_hp * 0.3:
			low_hp_count += 1
		if total_dot >= hp:
			extra_kills += 1

	# The primary target's own kill is already scored generically (see
	# _kill_potential_bonus(), fed by _estimate_skill_damage()'s own
	# "freezing_field" case) - this only adds for kills BEYOND that one,
	# same split Torrent's/Ghostship's/Ice Blast's own modifiers use.
	if extra_kills >= 2:
		score += 30.0 * float(extra_kills - 1)

	if low_hp_count >= 1:
		score += 15.0 * float(low_hp_count)

	var hp_ratio: float = float(context.get("hero_hp_ratio", 1.0))
	if hp_ratio < 0.30 and int(context.get("enemy_count", 1)) >= 2:
		score -= 20.0

	return score


## A plain Attack is only worth scoring above its flat baseline for
## Crystal Maiden when it can finish the target off outright (see
## basic_attack_participates()'s own docstring for why she opts in at
## all) - every one of her real skills costs 70-330 mana, so a free kill
## deserves a real shot at winning over spending any of it. A small extra
## nudge applies when mana is already scarce (<30% of max), the same
## "mana efficiency as a small modifier, never a dominant one" role
## _resource_penalty() already plays for every hero's every skill.
static func _cm_basic_attack_modifier(context: Dictionary) -> float:
	var score: float = 0.0

	var hero_damage: float = float(context.get("hero_damage", 0.0))
	var target_hp: float = float(context.get("target_hp", 0.0))
	if target_hp > 0.0 and hero_damage >= target_hp:
		score += 50.0

	var max_mana: float = float(context.get("hero_max_mana", 0.0))
	if max_mana > 0.0 and float(context.get("hero_mana", 0.0)) / max_mana < 0.3:
		score += 8.0

	return score


## Tusk: aggressive, melee, burst/control/positioning. Ice Shards and
## Snowball are "offensive" category (generic kill-potential/target-
## value terms, fed by their own flat-damage _estimate_skill_damage()
## cases); Walrus Punch is "offensive" too (fed by its own hero_damage x
## damage_multiplier case); Tag Team is "utility" (no damage of its own
## at all - its entire value is computed here, as an expected-value
## calculation over the duration, never a flat "add bonus_damage once").
static func _tusk_modifier(skill_id: String, level_data: Dictionary, context: Dictionary) -> float:
	match skill_id:
		"ice_shards":
			return _tusk_ice_shards_modifier(level_data, context)
		"snowball":
			return _tusk_snowball_modifier(level_data, context)
		"tag_team":
			return _tusk_tag_team_modifier(level_data, context)
		"walrus_punch":
			return _tusk_walrus_punch_modifier(level_data, context)
		BASIC_ATTACK_ID:
			return _tusk_basic_attack_modifier(context)
		_:
			return 0.0


## Ice Shards: movement denial, not a normal AoE nuke - the generic
## offensive scoring above already covers its own primary hit (target
## value, kill potential); this only adds for whether the wall it throws
## up actually matters. `grid_columns` (battle.gd's GRID_COLUMNS, always
## 0 in the simulation - see EnemyHeroManager's own _build_npc_ai_
## context() docstring) gates whether real board math is even possible;
## without it this falls back to the same "more living enemies, more a
## control effect is worth" proxy Winter's Curse's own sim-side
## redirect_candidate_count uses. Deliberately does NOT reward
## blocked_columns just for being a big number (see the design doc's own
## "do not give Ice Shards a huge score merely because it blocks many
## columns" instruction) - only for what it actually reaches: the
## target's own column (frozen in place outright) or the one column
## needed to safely retreat past it, plus a small bonus for pinning
## against the far edge too and for Tusk staying close enough to keep
## following up. The wall never blocks TUSK'S OWN movement (see
## _resolve_ice_shards_cast()/_cast_enemy_ice_shards() - it walls off
## columns starting on the CASTER's own column outward, and (mirroring
## the player's own copy, which never checks it in _hero_move() either)
## the caster is never gated against their own wall in _hero_move()'s
## own enemy-side check), so that's not a real cost to weigh here.
static func _tusk_ice_shards_modifier(level_data: Dictionary, context: Dictionary) -> float:
	var blocked_columns: int = int(level_data.get("blocked_columns", 0))
	var score: float = 0.0

	var grid_columns: int = int(context.get("grid_columns", 0))
	if grid_columns > 0:
		var target_distance: int = int(context.get("target_distance", 0))
		if blocked_columns > target_distance:
			# The wall reaches all the way to the target's own column -
			# frozen in place outright for the duration, same value as a
			# root landing.
			score += 50.0

			var caster_pos: int = int(context.get("caster_pos_index", 0))
			var target_pos: int = int(context.get("target_pos_index", 0))
			var direction: int = 1 if target_pos >= caster_pos else -1
			var far_edge_distance: int = (grid_columns - 1 - target_pos) if direction > 0 else target_pos
			if far_edge_distance <= 0:
				# Already pinned against the far edge too - nowhere left
				# to go even once the wall wears off early.
				score += 20.0
		elif blocked_columns == target_distance:
			# Right up against the target's own column - denies the one
			# step that would have let it retreat to safety this turn.
			score += 20.0

		if target_distance <= 1:
			# Tusk himself stays close enough to keep following up next
			# turn (Snowball/Walrus Punch/a plain Attack) once it wears
			# off - a wall he can't capitalize on is worth less.
			score += 10.0
	else:
		# No real positions in the simulation - fall back to the same
		# "more enemies around, more this matters" proxy every other
		# AoE/control skill in this file already uses there.
		score += minf(float(int(context.get("enemy_count", 1)) - 1), 3.0) * 10.0

	var target_hp: float = float(context.get("target_hp", 0.0))
	var target_max_hp: float = float(context.get("target_max_hp", 0.0))
	if target_max_hp > 0.0 and target_hp / target_max_hp < 0.4:
		# A badly hurt target has more reason to want to flee next turn -
		# denying that is worth more than trapping a healthy one that
		# wasn't going anywhere anyway.
		score += 15.0

	return score


## Snowball: direct offensive/control - the generic offensive scoring
## above already covers its own damage/kill-potential; this layers
## control value (stun_turns) and "how much does removing an action
## matter right now" (hero_hp_ratio, same danger signal Frostbite's own
## defensive bonus uses) on top. Early-out mirrors Walrus Punch's own
## below: a target a plain Attack can already kill outright leaves
## nothing for the stun to prevent, so it's not worth the mana (see the
## design doc's own "do not waste Snowball simply because it is
## available" instruction).
static func _tusk_snowball_modifier(level_data: Dictionary, context: Dictionary) -> float:
	var hero_damage: float = float(context.get("hero_damage", 0.0))
	var target_hp: float = float(context.get("target_hp", 0.0))
	if target_hp > 0.0 and hero_damage >= target_hp:
		return -40.0

	var score: float = 0.0

	var stun_turns: int = int(level_data.get("stun_turns", 0))
	if stun_turns >= 2:
		score += 35.0
	elif stun_turns >= 1:
		score += 15.0

	var target_max_hp: float = float(context.get("target_max_hp", 0.0))
	if target_max_hp > 0.0 and target_hp / target_max_hp < 0.35:
		score += 15.0

	if float(context.get("hero_hp_ratio", 1.0)) < 0.4:
		score += 20.0

	return score


## Tag Team: NOT an instant hit - a temporary buff to Tusk's own plain
## Attacks, so its whole value has to be the expected bonus damage over
## however many Attacks he realistically lands during the duration, per
## the design doc's own "expected_value = bonus_damage x expected_
## attacks_during_duration" formula - never a flat one-time add the way
## a real damage skill's _estimate_skill_damage() case would (which is
## exactly why Tag Team is "utility" category with no such case at all;
## every point of its value is computed right here). "Already active" is
## gated at the candidacy level instead (see battle.gd's own
## _enemy_skill_worth_casting()'s/EnemyHeroManager's own _npc_skill_
## worth_casting()'s "tag_team" case), same as every other self-buff in
## this file - so this never has to ask that question itself. The
## shared _evaluate_utility() term this skill's "utility" category
## already gets (a flat -15 once hero_hp_ratio < 0.35) covers the design
## doc's own "lower value when Tusk is low HP" instruction without this
## needing its own separate copy of that penalty. `target_distance`
## defaults to 0 (adjacent) rather than "far away" when absent - that's
## the simulation, where every attack already reaches its target with no
## travel cost at all (see EnemyHeroManager's own _build_npc_ai_
## context() docstring, and its "in_attack_range_now"/"in_attack_range_
## with_arctic_burn_bonus" fields making the same unconditional-true
## call for Arctic Burn's own copy there).
static func _tusk_tag_team_modifier(level_data: Dictionary, context: Dictionary) -> float:
	var bonus_damage: float = float(level_data.get("bonus_damage", 0.0))
	var duration: int = int(level_data.get("duration", 0))
	var already_adjacent: bool = int(context.get("target_distance", 0)) <= 0

	var expected_attacks: float
	if already_adjacent:
		# Roughly one Attack per remaining turn of the buff, capped by
		# how much HP the target realistically has left to soak them -
		# no point banking on attacks past its own death.
		expected_attacks = float(duration)
		var target_hp: float = float(context.get("target_hp", 0.0))
		var hero_damage: float = float(context.get("hero_damage", 0.0))
		if target_hp > 0.0 and hero_damage > 0.0:
			expected_attacks = minf(expected_attacks, ceil(target_hp / hero_damage))
	else:
		# Tusk still needs to close the distance first - a real
		# possibility (he might well get there next turn), just a
		# smaller and less certain one than already being adjacent.
		expected_attacks = maxf(0.0, float(duration) - 1.0) * 0.5

	var expected_value: float = bonus_damage * expected_attacks

	# A flat fraction of the raw expected bonus damage, same spirit as
	# _evaluate_offensive()'s own damage-based terms, so this lands on a
	# comparable scale to every other skill's score rather than the raw
	# (potentially very large) expected_value number itself.
	return expected_value * 0.35


## Walrus Punch: the highest-value skill in Tusk's kit, but not an
## unconditional "if ready, use it" - the early-out mirrors Snowball's
## own above (a target a plain Attack can already kill outright makes
## spending the ultimate's mana/cooldown wasteful, collision/stun
## flourishes included, per the design doc's own Example A). Otherwise,
## `base_punch_damage` (Tusk's actual hero_damage x damage_multiplier,
## the same figure _estimate_skill_damage()'s own "walrus_punch" case
## already fed into the generic kill-potential term above) determines
## whether a knockback that gets cut short would ALSO cross the kill
## threshold via its 50% collision bonus - credited here rather than
## twice, since the generic term only ever sees the no-collision
## estimate. `grid_columns` gates real knockback-destination math (see
## _tusk_ice_shards_modifier()'s own docstring for why); without it
## (the simulation), collision is approximated as "likely when at least
## one other living enemy exists to run into," same "no columns, but
## more enemies still means more" proxy every position-dependent skill
## in this file falls back to there.
static func _tusk_walrus_punch_modifier(level_data: Dictionary, context: Dictionary) -> float:
	var hero_damage: float = float(context.get("hero_damage", 0.0))
	var target_hp: float = float(context.get("target_hp", 0.0))

	if target_hp > 0.0 and hero_damage >= target_hp:
		return -75.0

	var score: float = 0.0
	var multiplier: float = float(level_data.get("damage_multiplier", 1.0))
	var base_punch_damage: float = hero_damage * multiplier

	var knockback: int = int(level_data.get("knockback", 0))
	var grid_columns: int = int(context.get("grid_columns", 0))
	var collision: bool = false

	if grid_columns > 0:
		var target_pos: int = int(context.get("target_pos_index", 0))
		var direction: int = -1 if bool(context.get("caster_facing_left", false)) else 1
		var raw_landing: int = target_pos + direction * knockback
		collision = raw_landing < 0 or raw_landing >= grid_columns
		var landing: int = clampi(raw_landing, 0, grid_columns - 1)

		if collision:
			score += 30.0
		else:
			var edge_distance: int = mini(landing, grid_columns - 1 - landing)
			if edge_distance <= 0:
				# Didn't collide this cast, but lands pinned right against
				# an edge anyway - a good spot to follow up into.
				score += 10.0
	else:
		collision = int(context.get("enemy_count", 1)) >= 2
		if collision:
			score += 25.0

	var punch_damage: float = base_punch_damage * 1.5 if collision else base_punch_damage
	if target_hp > 0.0 and base_punch_damage < target_hp and punch_damage >= target_hp:
		# The collision alone is what pushes this over the kill
		# threshold - the generic kill bonus above (fed by the
		# no-collision estimate) never sees this case, so it's credited
		# here instead, same split Ice Blast's own execute bonus uses.
		score += 50.0

	var stun_turns: int = int(level_data.get("stun_turns", 0))
	if stun_turns >= 2:
		score += 30.0
	elif stun_turns >= 1:
		score += 15.0

	return score


## A plain Attack is only worth scoring above its flat baseline for Tusk
## when it can finish the target off outright (see basic_attack_
## participates()'s own docstring for why he opts in at all) - Walrus
## Punch/Snowball are both real mana/cooldown investments, so a free
## kill deserves a real shot at winning over spending either (see the
## design doc's own Example A). Same small mana-scarcity nudge as
## Crystal Maiden's own copy.
static func _tusk_basic_attack_modifier(context: Dictionary) -> float:
	var score: float = 0.0

	var hero_damage: float = float(context.get("hero_damage", 0.0))
	var target_hp: float = float(context.get("target_hp", 0.0))
	if target_hp > 0.0 and hero_damage >= target_hp:
		score += 50.0

	var max_mana: float = float(context.get("hero_max_mana", 0.0))
	if max_mana > 0.0 and float(context.get("hero_mana", 0.0)) / max_mana < 0.3:
		score += 8.0

	return score


## Treant Protector: durable, melee, control/sustain, opportunistic.
## Nature's Guise is "defensive" category (see SKILL_INFO) - in the
## simulation that's its ENTIRE score, no case here at all (matching
## Depthsveil's own precedent); in a real hero fight, _tp_natures_
## guise_modifier() adds its own stealth-engage/root-setup value on top.
## Leech Seed and Overgrowth are both "offensive" (fed by their own
## dot_damage x duration _estimate_skill_damage() cases, for the shared
## kill-potential/target-value terms); this layers Leech Seed's own
## Treant-condition-scaled healing value, and Overgrowth's own multi-
## target root/DoT tiers (self-centered, same shape as Crystal Maiden's
## own Freezing Field), on top. Living Armor is "defensive" too (the
## shared HP-ratio tiers already cover most of the design doc's own
## "lower priority at high HP" instruction); this adds its own expected
## healing/armor value.
static func _treant_modifier(skill_id: String, level_data: Dictionary, context: Dictionary) -> float:
	match skill_id:
		"nature's_guise":
			return _tp_natures_guise_modifier(level_data, context)
		"leech_seed":
			return _tp_leech_seed_modifier(level_data, context)
		"living_armor":
			return _tp_living_armor_modifier(level_data, context)
		"overgrowth":
			return _tp_overgrowth_modifier(level_data, context)
		BASIC_ATTACK_ID:
			return _tp_basic_attack_modifier(context)
		_:
			return 0.0


## Nature's Guise: setup/engage/defensive positioning, never a damage
## skill in its own right - the root only ever comes from a SUCCESSFUL
## stealth Attack next turn, never guaranteed just from casting this
## (see the design doc's own "do not assume the root will always
## happen" instruction), so its whole value here is an EXPECTED one:
## target_value + expected_root_value, gated by whether Treant has a
## realistic shot at actually landing that Attack before the
## invisibility runs out. `target_distance` is absent in the simulation
## (no positions there - see EnemyHeroManager's own _build_npc_ai_
## context() docstring); this returns a flat 0 in that case rather than
## guessing, leaving the shared "defensive" category term (hero_hp_
## ratio tiers) as this skill's entire simulated value, exactly mirroring
## Depthsveil's own precedent (no hero-specific case for it at all).
static func _tp_natures_guise_modifier(level_data: Dictionary, context: Dictionary) -> float:
	var raw_distance: int = int(context.get("target_distance", -1))
	if raw_distance < 0:
		return 0.0

	if raw_distance <= 0:
		# Already standing right next to a valuable target - vanishing
		# first only delays the Attack that matters, it doesn't set up
		# anything Treant doesn't already have (see the design doc's own
		# "already in a good melee position" waste case).
		return -30.0

	var duration: int = int(level_data.get("duration", 0))
	if raw_distance > duration:
		# Can't realistically close the distance (roughly one column a
		# turn, the same pace every other melee hero in this file
		# assumes when no more precise move-speed figure is available)
		# before the invisibility runs out - a setup with nothing left
		# to set up (see the design doc's own "cannot realistically
		# reach a useful target" waste case).
		return -15.0

	var target_hp: float = float(context.get("target_hp", 0.0))
	var target_max_hp: float = float(context.get("target_max_hp", 0.0))
	var target_value: float = ((1.0 - target_hp / target_max_hp) * 10.0) if target_max_hp > 0.0 else 0.0

	# The closer the opportunity already is relative to how long the
	# invisibility lasts, the more confidently the root's own value can
	# be counted - a distant, uncertain approach counts for less than an
	# almost-guaranteed one, never the full amount either way.
	var proximity_factor: float = clampf(1.0 - float(raw_distance - 1) / float(maxi(duration, 1)), 0.2, 1.0)
	var root_turns: int = int(level_data.get("root_turns", 0))
	var expected_root_value: float = float(root_turns) * 12.0 * proximity_factor

	var score: float = target_value + expected_root_value

	if float(context.get("hero_hp_ratio", 1.0)) < 0.4:
		# Also doubles as an escape/reposition, on top of whatever engage
		# value the stealth Attack itself has - the shared defensive
		# HP-ratio tiers already cover the base "Treant is threatened"
		# case, this is specifically for the "and this also lets him
		# reposition out of it" angle.
		score += 15.0

	return score


## Leech Seed: offensive AND sustain. The generic offensive scoring
## above already covers target value/kill potential (fed by dot_damage x
## duration - see _estimate_skill_damage()'s own "leech_seed" case);
## this adds the healing half, scaled by how close Treant already is to
## needing it (0 extra value at full HP, per the design doc's own "do
## not automatically use Leech Seed simply because Treant is damaged"
## instruction - kill potential/target value alone can still justify it
## at full HP). Early-out mirrors Snowball's/Walrus Punch's own below: a
## target a plain Attack can already kill outright leaves nothing for a
## multi-turn DoT to finish first, so it's not worth the mana (see the
## design doc's own Basic Attack example).
static func _tp_leech_seed_modifier(level_data: Dictionary, context: Dictionary) -> float:
	var hero_damage: float = float(context.get("hero_damage", 0.0))
	var target_hp: float = float(context.get("target_hp", 0.0))
	if target_hp > 0.0 and hero_damage >= target_hp:
		return -45.0

	var heal_per_turn: float = float(level_data.get("heal_per_turn", 0.0))
	var duration: int = int(level_data.get("duration", 0))
	var expected_healing: float = heal_per_turn * float(duration)

	var hp_ratio: float = float(context.get("hero_hp_ratio", 1.0))
	var missing_hp_pct: float = clampf(1.0 - hp_ratio, 0.0, 1.0)
	var score: float = expected_healing * missing_hp_pct * 0.35

	if int(context.get("enemy_count", 1)) >= 2:
		# A small extra nudge for "also engaged with more than one
		# threat" - the same outnumbered signal _evaluate_defensive()
		# uses elsewhere, feeding this skill's own sustain-urgency value
		# instead of a flat defensive tier.
		score += 8.0

	return score


## Living Armor: preventive, not automatic - the shared "defensive"
## category already provides the bulk of the design doc's own high/low
## priority tiers (hero_hp_ratio-based, including the explicit "healthy
## -> penalty" that stops it from being cast just because it's
## available); this adds its own expected-healing and armor-specific
## value on top, plus a penalty when Treant isn't close enough to combat
## for either to matter yet.
static func _tp_living_armor_modifier(level_data: Dictionary, context: Dictionary) -> float:
	var bonus_hp_regen: float = float(level_data.get("bonus_hp_regen", 0.0))
	var duration: int = int(level_data.get("duration", 0))
	var expected_healing: float = bonus_hp_regen * float(duration)

	var score: float = expected_healing * 0.25

	var bonus_armor: float = float(level_data.get("bonus_armor", 0.0))
	var enemy_count: int = int(context.get("enemy_count", 1))
	# More attackers around means the armor mitigates more total hits
	# over the buff's duration - the same "outnumbered" signal
	# _evaluate_defensive() already uses, just feeding this skill's own
	# armor-specific value instead of a flat HP-ratio tier.
	score += bonus_armor * float(mini(enemy_count, 4)) * 1.5

	var raw_distance: int = int(context.get("target_distance", -1))
	if raw_distance >= 0 and raw_distance > 2:
		# Not about to be in melee combat any time soon - the armor/regen
		# has nothing to mitigate yet, and may well expire before it
		# does (see the design doc's own "not currently threatened"/
		# "mostly wasted because the fight is likely to end soon" cases).
		score -= 15.0

	return score


## Overgrowth: Treant's primary AoE control + damage ultimate, SELF-
## CENTERED like Crystal Maiden's own Freezing Field - never a selected
## enemy's position (see _cm_freezing_field_modifier()'s own docstring
## for why `target_distance` is reused here rather than re-derived: it's
## battle.gd's already-computed distance from Treant's own pos_index to
## the player). Out of radius in a real fight, this is a low-value cast,
## same reasoning as Freezing Field's own early-out. In range (or the
## simulation, where a missing value defaults to "in range" - every
## other AoE skill's own "no columns, hit everyone" simplification),
## this layers the design doc's own multi-target/low-HP/multi-kill tiers
## on top of the generic kill-potential/"already hurt" terms
## _evaluate_offensive() already provides, PLUS its own root-control
## value scaled by duration and target count - movement denial only,
## deliberately never scored as a stun (per the design doc's own
## explicit "rooting does NOT prevent attacks/skills/items" instruction
## - Overgrowth's root shares the same generic root_turns_left field
## Thornbind's own does, which every attack/skill/item check already
## ignores). The early-out mirrors Leech Seed's/Snowball's/Walrus
## Punch's own: a single target a plain Attack can already kill outright
## isn't worth an ultimate's mana/cooldown, but ONLY when just one enemy
## is actually affected - a multi-target opportunity is never penalized
## this way, per the design doc's own "if the ultimate can affect 3-4
## enemies... the multi-target value can justify its high mana cost".
static func _tp_overgrowth_modifier(level_data: Dictionary, context: Dictionary) -> float:
	var radius: int = int(level_data.get("radius", 0))
	var raw_distance: int = int(context.get("target_distance", -1))
	var in_range: bool = raw_distance < 0 or raw_distance <= radius

	if not in_range:
		return -35.0

	var living_hps: Array = context.get("living_target_hps", [])
	var living_max_hps: Array = context.get("living_target_max_hps", living_hps)
	var hit_count: int = living_hps.size()

	var hero_damage: float = float(context.get("hero_damage", 0.0))
	var target_hp: float = float(context.get("target_hp", 0.0))
	if hit_count <= 1 and target_hp > 0.0 and hero_damage >= target_hp:
		return -70.0

	var score: float = 0.0
	if hit_count >= 4:
		score += 90.0
	elif hit_count == 3:
		score += 60.0
	elif hit_count == 2:
		score += 35.0
	elif hit_count == 1:
		score += 10.0

	var root_duration: int = int(level_data.get("root_duration", 0))
	var total_dot: float = float(level_data.get("dot_damage", 0.0)) * float(root_duration)
	var extra_kills: int = 0
	var low_hp_count: int = 0
	for i in range(hit_count):
		var hp: float = float(living_hps[i])
		if hp <= 0.0:
			continue
		var max_hp: float = float(living_max_hps[i]) if i < living_max_hps.size() else hp
		if max_hp > 0.0 and hp <= max_hp * 0.3:
			low_hp_count += 1
		if total_dot >= hp:
			extra_kills += 1

	# The primary target's own kill is already scored generically (see
	# _kill_potential_bonus(), fed by _estimate_skill_damage()'s own
	# "overgrowth" case) - this only adds for kills BEYOND that one, same
	# split Torrent's/Ghostship's/Ice Blast's/Freezing Field's own
	# modifiers use.
	if extra_kills >= 2:
		score += 30.0 * float(extra_kills - 1)

	if low_hp_count >= 1:
		score += 15.0 * float(low_hp_count)

	# Root control value: pure movement denial, scaled by duration and by
	# how many enemies are actually affected - never scored as a stun
	# (see this function's own docstring).
	score += float(root_duration) * float(hit_count) * 3.0

	var hp_ratio: float = float(context.get("hero_hp_ratio", 1.0))
	if hp_ratio < 0.30 and int(context.get("enemy_count", 1)) >= 2:
		# Too vulnerable to bank on surviving long enough to exploit the
		# control - Overgrowth has no invented immunity of its own to
		# lean on here, so a bad HP situation is a real cost.
		score -= 20.0

	return score


## A plain Attack is only worth scoring above its flat baseline for
## Treant Protector when it can finish the target off outright (see
## basic_attack_participates()'s own docstring for why he opts in at
## all) - every one of his real skills is a real mana/cooldown
## investment, so a free kill deserves a real shot at winning over
## spending any of them (see the design doc's own Basic Attack example).
## Same small mana-scarcity nudge as every other hero's own copy here.
static func _tp_basic_attack_modifier(context: Dictionary) -> float:
	var score: float = 0.0

	var hero_damage: float = float(context.get("hero_damage", 0.0))
	var target_hp: float = float(context.get("target_hp", 0.0))
	if target_hp > 0.0 and hero_damage >= target_hp:
		score += 50.0

	var max_mana: float = float(context.get("hero_max_mana", 0.0))
	if max_mana > 0.0 and float(context.get("hero_mana", 0.0)) / max_mana < 0.3:
		score += 8.0

	return score


## Timbersaw: aggressive, durable, melee, AoE-focused. Whirling Death and
## Timber Chain are both "offensive" category (generic kill-potential/
## target-value terms, fed by their own flat-damage _estimate_skill_
## damage() cases); Chakram is "offensive" too (fed by its own
## cast_damage-only case - its persistent damage_per_turn ticks are
## deliberately kept OUT of that generic estimate, since they're never a
## guaranteed hit the way a cast's own initial damage is - see this
## function's own _timbersaw_chakram_modifier()). Reactive Armor's
## current stacks (context's own "reactive_armor_stacks"/"reactive_
## armor_max_stacks" fields - see battle.gd's/EnemyHeroManager's own
## _build_enemy_ai_context()/_build_npc_ai_context() docstrings) feed
## into how comfortable Timbersaw is staying in the fight, per the design
## doc's own "modify the survival calculation, not override it"
## instruction - see _timbersaw_sustain_factor()'s own docstring for how
## that's actually worked out.
static func _timbersaw_modifier(skill_id: String, level_data: Dictionary, context: Dictionary) -> float:
	match skill_id:
		"whirling_death":
			return _timbersaw_whirling_death_modifier(level_data, context)
		"timber_chain":
			return _timbersaw_timber_chain_modifier(level_data, context)
		"chakram":
			return _timbersaw_chakram_modifier(level_data, context)
		BASIC_ATTACK_ID:
			return _timbersaw_basic_attack_modifier(context)
		_:
			return 0.0


## How much Reactive Armor is currently cushioning Timbersaw, as a 0..1
## fraction of its own cap (0 with the skill unlearned or no stacks up) -
## shared by every one of his own modifiers below that needs to lean
## into (or shy away from) staying in a fight, rather than each
## reimplementing the same ratio.
static func _timbersaw_sustain_factor(context: Dictionary) -> float:
	var max_stacks: int = int(context.get("reactive_armor_max_stacks", 0))
	if max_stacks <= 0:
		return 0.0
	return clampf(float(context.get("reactive_armor_stacks", 0)) / float(max_stacks), 0.0, 1.0)


## Whirling Death: self-centered, never a targeted cast - the AI has to
## evaluate however many enemies are ALREADY within radius of Timbersaw's
## own current position, never an arbitrary chosen location (see
## _cm_freezing_field_modifier()'s own docstring for the same "reuse
## target_distance as the self-centered range check" reasoning this
## mirrors). The generic offensive scoring above already covers the
## primary target's own value/kill potential (fed by the flat-damage
## _estimate_skill_damage() case); this adds the shared AoE multi-target
## tiers (see _aa_ice_blast_modifier()'s own tiers, reused verbatim
## rather than inventing a new curve - per the design doc's own "do not
## use arbitrary bonuses if the shared evaluator already has an AoE
## scoring helper" instruction) plus this skill's own extra-kill/hero-hit
## terms. `sustain_factor` makes a crowded fight a little MORE appealing
## rather than less once Timbersaw has real Reactive Armor stacks banked
## up, per the design doc's own "he can reasonably receive a lower
## penalty for remaining in close combat" instruction - never enough on
## its own to matter without real AoE value already present (it only
## ever applies alongside an actual hit_count>=2 bonus above).
static func _timbersaw_whirling_death_modifier(level_data: Dictionary, context: Dictionary) -> float:
	var radius: int = int(level_data.get("radius", 0))
	var raw_distance: int = int(context.get("target_distance", -1))
	var in_range: bool = raw_distance < 0 or raw_distance <= radius

	if not in_range:
		return -35.0

	var living_hps: Array = context.get("living_target_hps", [])
	var hit_count: int = living_hps.size()

	var score: float = 0.0
	if hit_count >= 4:
		score += 80.0
	elif hit_count == 3:
		score += 55.0
	elif hit_count == 2:
		score += 30.0
	elif hit_count == 1:
		score += 10.0

	var damage: float = float(level_data.get("damage", 0.0))
	var extra_kills: int = 0
	for i in range(1, living_hps.size()):
		if damage >= float(living_hps[i]) and float(living_hps[i]) > 0.0:
			extra_kills += 1
	if extra_kills >= 1:
		score += 35.0 * float(extra_kills)

	if bool(context.get("target_is_hero", false)):
		# Whirling Death's own primary-attribute reduction - purely
		# qualitative (see this file's own header comment on why: no
		# real stat-reduction mechanic exists anywhere in this project
		# to calculate a real number from).
		score += 10.0

	if hit_count >= 2 and _timbersaw_sustain_factor(context) > 0.5:
		score += 10.0

	return score


## Timber Chain: BOTH an offensive skill and a positioning/escape tool -
## the generic offensive scoring above already covers the marked
## target's own value/kill potential; this adds the path-damage value
## (every enemy the chain crosses takes the same hit, so more of them
## matters a lot - same AoE tiers Whirling Death's own modifier uses,
## reused rather than inventing a second curve) plus movement value.
## Deliberately has NO "a plain Attack could already kill this" early-out
## the way Snowball's/Leech Seed's/Chakram's own do - per the design
## doc's own explicit instruction, Timber Chain must be allowed to score
## highly purely for a meaningful escape, "even when its damage is low"
## and "do not require the target itself to be low HP". `grid_columns`
## gates whether real escape/engage math is even possible (never present
## in the simulation - see EnemyHeroManager's own _build_npc_ai_
## context() docstring - where every attack already reaches its target
## with no travel cost at all, so there's nothing here for movement value
## to compute).
static func _timbersaw_timber_chain_modifier(level_data: Dictionary, context: Dictionary) -> float:
	var living_hps: Array = context.get("living_target_hps", [])
	var path_targets: int = living_hps.size()

	var score: float = 0.0
	if path_targets >= 4:
		score += 65.0
	elif path_targets == 3:
		score += 45.0
	elif path_targets == 2:
		score += 25.0
	elif path_targets == 1:
		score += 5.0

	var damage: float = float(level_data.get("damage", 0.0))
	var extra_kills: int = 0
	for i in range(1, living_hps.size()):
		if damage >= float(living_hps[i]) and float(living_hps[i]) > 0.0:
			extra_kills += 1
	if extra_kills >= 1:
		score += 30.0 * float(extra_kills)

	var grid_columns: int = int(context.get("grid_columns", 0))
	if grid_columns > 0:
		var hp_ratio: float = float(context.get("hero_hp_ratio", 1.0))
		# More banked Reactive Armor stacks means Timbersaw is already
		# more cushioned, so the threshold for reading this as a real
		# emergency is a little more forgiving - modifies the threshold,
		# never removes the emergency case outright (see the design
		# doc's own "modify the survival calculation, not override it"
		# instruction).
		var escape_threshold: float = 0.35 - (_timbersaw_sustain_factor(context) * 0.12)
		if hp_ratio < escape_threshold:
			# The pull itself moves Timbersaw off wherever he's currently
			# under threat, regardless of the target's own HP - see this
			# function's own docstring for why there's no low-HP
			# requirement gating this.
			score += 35.0
		else:
			var target_distance: int = int(context.get("target_distance", 0))
			if target_distance >= 2:
				# A real, meaningful reposition even outside an
				# emergency - closing genuine distance onto a target
				# worth reaching is itself valuable positioning, not
				# just incidental movement.
				score += 12.0

	return score


## Chakram: TARGET-centered, unlike Whirling Death - never evaluated as
## if it were a self-centered AoE (see this file's own header comment).
## Its own `range` field (a real targeting requirement, gated by
## EnemySkillRange before this is ever a candidate) already keeps this
## from firing at an unreachable target, so - unlike Freezing Field's/
## Overgrowth's/Whirling Death's own self-centered "is the caster's own
## radius even reaching anything" gate - there's no separate range check
## to repeat here. The early-out mirrors Leech Seed's/Snowball's own: a
## single affected target a plain Attack can already kill outright isn't
## worth an expensive ultimate's mana/cooldown, but ONLY when just one
## enemy is actually affected - per the design doc's own explicit "if 3
## enemies are affected... the multi-target value can justify its high
## mana cost" instruction, a real multi-target opportunity is never
## penalized this way. Initial AoE reuses the same multi-target tiers
## Whirling Death's/Ice Blast's own modifiers already use; persistent
## damage is deliberately discounted rather than assumed at full uptime
## (see the design doc's own "do not automatically assume every enemy
## stays inside the radius for the full duration" instruction) - a
## target already standing right next to Timbersaw (target_distance <=
## 0, the closest proxy this context offers for "already engaged, likely
## to still be here next turn") gets a much higher expected-uptime
## estimate than one that isn't.
static func _timbersaw_chakram_modifier(level_data: Dictionary, context: Dictionary) -> float:
	var hero_damage: float = float(context.get("hero_damage", 0.0))
	var target_hp: float = float(context.get("target_hp", 0.0))
	var living_hps: Array = context.get("living_target_hps", [])
	var living_max_hps: Array = context.get("living_target_max_hps", living_hps)
	var hit_count: int = living_hps.size()

	if hit_count <= 1 and target_hp > 0.0 and hero_damage >= target_hp:
		return -90.0

	var score: float = 0.0
	if hit_count >= 3:
		score += 70.0
	elif hit_count == 2:
		score += 40.0
	elif hit_count == 1:
		score += 10.0

	var cast_damage: float = float(level_data.get("cast_damage", 0.0))
	var extra_initial_kills: int = 0
	for i in range(1, living_hps.size()):
		if cast_damage >= float(living_hps[i]) and float(living_hps[i]) > 0.0:
			extra_initial_kills += 1
	if extra_initial_kills >= 1:
		score += 35.0 * float(extra_initial_kills)

	var duration: int = int(level_data.get("duration", 0))
	var damage_per_turn: float = float(level_data.get("damage_per_turn", 0.0))
	var target_distance: int = int(context.get("target_distance", 0))
	var expected_uptime_pct: float = 0.9 if target_distance <= 0 else 0.5
	var persistent_damage: float = damage_per_turn * float(duration) * expected_uptime_pct
	score += persistent_damage * 0.12 * float(hit_count)

	# Persistent (future) kills - distinguished from the initial-AoE
	# extra_initial_kills above, which are immediate: a target that
	# survives the cast but is expected to die to the lingering damage
	# still contributes real value here, at a smaller weight than an
	# immediate kill gets (see the design doc's own "immediate kills
	# should receive higher urgency" instruction).
	var persistent_kills: int = 0
	for i in range(hit_count):
		var hp: float = float(living_hps[i])
		if hp <= 0.0:
			continue
		var after_cast: float = hp - cast_damage
		if after_cast <= 0.0:
			continue
		if after_cast - persistent_damage <= 0.0:
			persistent_kills += 1
	if persistent_kills >= 1:
		score += 20.0 * float(persistent_kills)

	return score


## A plain Attack is only worth scoring above its flat baseline for
## Timbersaw when it can finish the target off outright (see
## basic_attack_participates()'s own docstring for why he opts in at
## all) - Chakram in particular is a very expensive ultimate, so a free
## kill deserves a real shot at winning over spending it (see the design
## doc's own Basic Attack example). Same small mana-scarcity nudge as
## every other hero's own copy here.
static func _timbersaw_basic_attack_modifier(context: Dictionary) -> float:
	var score: float = 0.0

	var hero_damage: float = float(context.get("hero_damage", 0.0))
	var target_hp: float = float(context.get("target_hp", 0.0))
	if target_hp > 0.0 and hero_damage >= target_hp:
		score += 50.0

	var max_mana: float = float(context.get("hero_max_mana", 0.0))
	if max_mana > 0.0 and float(context.get("hero_mana", 0.0)) / max_mana < 0.3:
		score += 8.0

	return score


## Snapfire: aggressive, ranged, AoE-focused, kill-oriented,
## opportunistic. Scatterblast/Firesnap Cookie/Lil' Shredder/Mortimer
## Kisses are all "offensive" category (each fed by its own _estimate_
## skill_damage() case, for the shared kill-potential/target-value
## terms); this layers each skill's own AoE/positioning/armor/
## opportunity-cost value on top. None of the four needs anything beyond
## context fields this file already exposes generically (living_target_
## hps/target_distance/caster_pos_index/target_pos_index/grid_columns/
## caster_facing_left, all already established by Tusk's/Crystal
## Maiden's own modifiers) plus two new ones scoped to this file's own
## header comment: "target_is_hero" (Timbersaw's own, reused as-is) and
## "target_armor" (new, for Lil' Shredder specifically).
static func _snapfire_modifier(skill_id: String, level_data: Dictionary, context: Dictionary) -> float:
	match skill_id:
		"scatterblast":
			return _snapfire_scatterblast_modifier(level_data, context)
		"firesnap_cookie":
			return _snapfire_firesnap_cookie_modifier(level_data, context)
		"lil_shredder":
			return _snapfire_lil_shredder_modifier(level_data, context)
		"mortimer_kisses":
			return _snapfire_mortimer_kisses_modifier(level_data, context)
		BASIC_ATTACK_ID:
			return _snapfire_basic_attack_modifier(context)
		_:
			return 0.0


## Scatterblast: the generic offensive scoring above already covers the
## primary target's own value/kill potential (fed by the flat-damage
## _estimate_skill_damage() case); this adds the shared AoE multi-target
## tiers on top - by the time this runs, the directional "is anything
## actually ahead of the blast" check has already happened (see battle.gd's
## own _enemy_skill_in_range()'s "scatterblast" case), so `living_target_
## hps` here is already exactly "whoever the blast actually reaches," per
## the design doc's own "do NOT give Scatterblast a high score merely
## because enemies exist within its maximum range - the actual affected
## positions must be evaluated" instruction - never a fresh directional
## re-check of its own. A real hero fight only ever has the player as a
## possible target, so this collapses to a single hit there (no AoE
## bonus), same rival-side simplification every other AoE skill in this
## file already has; the multi-target tiers only ever do real work in the
## simulation.
static func _snapfire_scatterblast_modifier(level_data: Dictionary, context: Dictionary) -> float:
	var living_hps: Array = context.get("living_target_hps", [])
	var hit_count: int = living_hps.size()

	var score: float = 0.0
	if hit_count >= 3:
		score += 35.0
	elif hit_count == 2:
		score += 20.0

	if hit_count >= 2:
		# "Hits the primary target AND at least one additional enemy" -
		# a real cluster, not just a lucky single hit (which already
		# gets its own value from the generic offensive term above, with
		# no separate AoE bonus needed).
		score += 15.0

	var damage: float = float(level_data.get("damage", 0.0))
	var extra_kills: int = 0
	for i in range(1, living_hps.size()):
		if damage >= float(living_hps[i]) and float(living_hps[i]) > 0.0:
			extra_kills += 1
	if extra_kills >= 1:
		score += 25.0 * float(extra_kills)

	return score


## Firesnap Cookie: a self-directed hop with an AoE landing, so - unlike
## Whirling Death's own self-CENTERED radius (checked against Snapfire's
## CURRENT position) - the AI has to project where the hop actually ends
## up before it can tell whether anyone's within `radius` of it at all.
## `grid_columns` gates whether that projection is even possible (never
## present in the simulation - see EnemyHeroManager's own _build_npc_ai_
## context() docstring - where a missing value falls back to the same
## "more enemies around, more this matters" proxy every other position-
## dependent skill in this file uses there). Per the design doc's own
## "do not score the ability as useful if there is no valid landing
## position that actually affects an enemy" instruction, a landing that
## reaches nobody scores WORSE than not casting it at all, not just
## "no bonus".
static func _snapfire_firesnap_cookie_modifier(level_data: Dictionary, context: Dictionary) -> float:
	var grid_columns: int = int(context.get("grid_columns", 0))
	var radius: int = int(level_data.get("radius", 0))
	var hit_count: int

	if grid_columns > 0:
		var jump_distance: int = int(level_data.get("jump_distance", 0))
		var caster_pos: int = int(context.get("caster_pos_index", 0))
		var target_pos: int = int(context.get("target_pos_index", 0))
		var direction: int = -1 if bool(context.get("caster_facing_left", false)) else 1
		var landing_pos: int = clampi(caster_pos + direction * jump_distance, 0, grid_columns - 1)
		hit_count = 1 if abs(landing_pos - target_pos) <= radius else 0
	else:
		hit_count = int(context.get("enemy_count", 1))

	if hit_count <= 0:
		return -30.0

	var score: float = 20.0

	var stun_turns: int = int(level_data.get("stun_turns", 0))
	if stun_turns >= 1:
		score += 30.0

	if hit_count >= 2:
		# One credit per additional enemy hit, plus a flat bonus for
		# "2+ enemies stunned at once" (every enemy the AoE reaches also
		# gets stunned, per the skill's own description).
		score += 25.0 * float(hit_count - 1)
		score += 35.0

	if float(context.get("hero_hp_ratio", 1.0)) < 0.4:
		# A high-threat situation for Snapfire herself makes locking an
		# enemy down here worth more, same "how much does removing an
		# action matter right now" signal every other stun-carrying
		# skill in this file already uses.
		score += 20.0

	var damage: float = float(level_data.get("damage", 0.0))
	var target_hp: float = float(context.get("target_hp", 0.0))
	if target_hp > 0.0 and damage >= target_hp:
		score += 25.0

	return score


## Lil' Shredder: single-target burst that "competes directly with
## normal attacks" per the design doc's own instruction, hence the
## early-out below - a target a plain Attack can already kill outright
## leaves nothing for a slower 3-shot volley to finish first. Armor
## reduction is valued BOTH as immediate offensive value (this volley's
## own later shots land harder) and as setup value for whatever Snapfire
## does next while it's still up - `target_armor` (the target's own
## CURRENT armor, already reflecting any earlier reduction - see this
## file's own header comment) is what makes "high-armor target" a real
## number instead of a guess, and `duration` (read straight from this
## level's own data, never assumed to last forever) scales how much of
## that setup value is actually likely to still be there when it matters.
static func _snapfire_lil_shredder_modifier(level_data: Dictionary, context: Dictionary) -> float:
	var hero_damage: float = float(context.get("hero_damage", 0.0))
	var target_hp: float = float(context.get("target_hp", 0.0))
	if target_hp <= 0.0:
		return 0.0
	if hero_damage >= target_hp:
		return -35.0

	var score: float = 0.0

	var target_armor: float = float(context.get("target_armor", 0.0))
	if target_armor >= 4.0:
		score += 15.0

	var shots: int = int(level_data.get("shots", 3))
	var damage_pct: float = float(level_data.get("damage_pct", 0.0))
	var per_shot: float = hero_damage * damage_pct
	if per_shot > 0.0 and target_hp > per_shot * float(shots - 1) and target_hp <= per_shot * float(shots) * 1.6:
		# Enough HP to soak most/all `shots` without wildly overkilling -
		# the "worth spending all of them on" middle ground the design
		# doc's own "target has enough HP to benefit from multiple
		# shots" instruction calls for.
		score += 20.0

	var target_max_hp: float = float(context.get("target_max_hp", 0.0))
	if target_max_hp > 0.0 and target_hp / target_max_hp < 0.5:
		score += 20.0

	var armor_reduction_per_shot: float = float(level_data.get("armor_reduction_per_shot", 0.0))
	var duration: int = int(level_data.get("duration", 0))
	if armor_reduction_per_shot > 0.0 and duration > 0 and target_armor > 0.0:
		# Worth more the larger a slice of the target's OWN armor it
		# actually shreds - both this volley's own later shots and
		# whatever Snapfire lands before it expires.
		var reduction_pct: float = clampf((armor_reduction_per_shot * float(shots)) / maxf(target_armor, 1.0), 0.0, 1.0)
		score += 15.0 * reduction_pct

	return score


## Mortimer Kisses: a target-centered AoE + persistent burn ultimate,
## same shape as Timbersaw's own Chakram - see _timbersaw_chakram_
## modifier()'s own docstring for why a real hero fight's splash always
## collapses to 0 (there's only ever the one player to hit), while the
## simulation's own "no columns, hit everyone else" fallback gives it
## real multi-target value (see EnemyHeroManager's own _fire_npc_
## mortimer_kisses_shot()). The early-out mirrors Lil' Shredder's/every
## other expensive-skill's own: a target a plain Attack can already kill
## outright isn't worth a 200-350 mana ultimate. Opportunity cost (3 full
## turns of no movement/attack/other skill/items) is expressed as
## straight penalties scaled by how dangerous the situation already is -
## deliberately NOT a separate "would another action have been better"
## penalty, since that's exactly what the surrounding score COMPARISON
## against every other candidate already does on its own.
static func _snapfire_mortimer_kisses_modifier(level_data: Dictionary, context: Dictionary) -> float:
	var hero_damage: float = float(context.get("hero_damage", 0.0))
	var target_hp: float = float(context.get("target_hp", 0.0))
	if target_hp > 0.0 and hero_damage >= target_hp:
		return -100.0

	# A valid target worth marking at all - always true once this is a
	# candidate (there's always exactly one possible target in a hero
	# fight, and the simulation never offers this as a candidate with an
	# empty `living` either - see EnemyHeroManager's own "living.is_
	# empty()" guard in _fire_npc_mortimer_kisses_shot()).
	var score: float = 25.0

	var main_damage: float = float(level_data.get("main_damage", 0.0))
	var burn_per_turn: float = float(level_data.get("burn_per_turn", 0.0))
	var burn_duration: int = int(level_data.get("burn_duration", 0))
	var total_expected_damage: float = main_damage + burn_per_turn * float(burn_duration)
	if target_hp > 0.0 and total_expected_damage >= target_hp:
		score += 25.0

	var target_max_hp: float = float(context.get("target_max_hp", 0.0))
	if target_max_hp > 0.0 and target_hp / target_max_hp < 0.6:
		score += 20.0

	var splash_targets: int = 0
	if int(context.get("grid_columns", 0)) <= 0:
		splash_targets = maxi(int(context.get("enemy_count", 1)) - 1, 0)

	if splash_targets >= 3:
		score += 40.0
	elif splash_targets >= 2:
		score += 25.0
	elif splash_targets >= 1:
		score += 20.0

	# --- Opportunity cost: 3 full turns of no movement, no Attack, no
	# other skill, no items. ---
	var hp_ratio: float = float(context.get("hero_hp_ratio", 1.0))
	if hp_ratio < 0.35:
		# In real danger - channeling through that is a genuine gamble,
		# not a free commitment.
		score -= 25.0
	if int(context.get("enemy_count", 1)) >= 2 and hp_ratio < 0.5:
		# Likely to need to reposition during the channel and won't be
		# able to.
		score -= 20.0

	return score


## A plain Attack is only worth scoring above its flat baseline for
## Snapfire when it can finish the target off outright (see
## basic_attack_participates()'s own docstring for why she opts in at
## all) - Mortimer Kisses in particular is a very expensive ultimate, so
## a free kill deserves a real shot at winning over spending it (see the
## design doc's own Basic Attack example). Same small mana-scarcity
## nudge as every other hero's own copy here.
static func _snapfire_basic_attack_modifier(context: Dictionary) -> float:
	var score: float = 0.0

	var hero_damage: float = float(context.get("hero_damage", 0.0))
	var target_hp: float = float(context.get("target_hp", 0.0))
	if target_hp > 0.0 and hero_damage >= target_hp:
		score += 50.0

	var max_mana: float = float(context.get("hero_max_mana", 0.0))
	if max_mana > 0.0 and float(context.get("hero_mana", 0.0)) / max_mana < 0.3:
		score += 8.0

	return score


## Naga Siren: tactical, control-oriented, illusion-focused. Every one of
## her skills leans on the same handful of context fields battle.gd's/
## EnemyHeroManager's own _build_*_ai_context() compute fresh each turn -
## "illusions_active"/"illusion_count"/"illusion_turns_remaining"/
## "illusion_total_damage_per_turn" (Mirror Image's current state, read
## by Ensnare/Song/a plain Attack for their own synergy bonuses) and
## "rip_tide_illusion_damage_bonus_pct"/"rip_tide_extra_illusion"/
## "rip_tide_illusion_duration_bonus"/"rip_tide_aoe_damage_pct" (Rip
## Tide's current level, folded into Mirror Image/Song/a plain Attack
## since the passive itself is never a scored candidate - see this
## file's own header comment).
static func _naga_siren_modifier(skill_id: String, level_data: Dictionary, context: Dictionary) -> float:
	match skill_id:
		"mirror_image":
			return _naga_mirror_image_modifier(level_data, context)
		"ensnare":
			return _naga_ensnare_modifier(level_data, context)
		"song_of_the_siren":
			return _naga_song_of_the_siren_modifier(level_data, context)
		BASIC_ATTACK_ID:
			return _naga_basic_attack_modifier(context)
		_:
			return 0.0


## Mirror Image: NOT a one-shot damage spell - its value is the
## illusions' own expected total damage over their FULL duration
## (offensive) plus the chance a hit meant for Naga herself lands on an
## illusion instead (defensive). Neither half is generic enough for
## _evaluate_offensive()/_evaluate_defensive() to cover (this skill's own
## SKILL_INFO category is "utility", same "the hero-specific modifier IS
## the whole value" shape Erynd's own Elderwild Companion uses - see
## _erynd_modifier()), so both live here together, exactly per the
## design doc's own "a defensive Mirror Image can be the right call even
## with lower immediate damage" instruction.
static func _naga_mirror_image_modifier(level_data: Dictionary, context: Dictionary) -> float:
	var hero_damage: float = float(context.get("hero_damage", 0.0))
	var illusions_count: int = int(level_data.get("illusions", 0)) + int(context.get("rip_tide_extra_illusion", 0))
	var damage_pct: float = float(level_data.get("damage_pct", 0.0)) + float(context.get("rip_tide_illusion_damage_bonus_pct", 0.0))
	var duration: int = int(level_data.get("duration", 0)) + int(context.get("rip_tide_illusion_duration_bonus", 0))
	var hit_chance_pct: float = float(level_data.get("hit_chance_pct", 0.0))

	var living_hps: Array = context.get("living_target_hps", [])
	var hit_count: int = living_hps.size()

	var score: float = 0.0

	# --- Offensive value: the illusions' own expected total damage over
	# the FULL duration, never just one turn's hit. There's no separate
	# signal anywhere in this project for "a target Naga herself can
	# reach" versus "a target the illusions can reach" - both draw from
	# the exact same in-range enemy pool (see battle.gd's own
	# _fire_mirror_image_attack()) - so the design doc's own "+20 if at
	# least one enemy is attackable" and "+20 if Naga can attack the same
	# target as the illusions" collapse into this single hit_count>=1
	# check rather than two independent ones.
	if hit_count >= 1:
		score += 40.0
	if hit_count >= 2:
		score += 25.0
	if duration >= 2:
		score += 20.0
	if float(context.get("rip_tide_illusion_damage_bonus_pct", 0.0)) > 0.0:
		score += 15.0

	var illusion_damage_per_turn: float = hero_damage * damage_pct * float(illusions_count)
	var total_expected_damage: float = illusion_damage_per_turn * float(duration)
	var target_hp: float = float(context.get("target_hp", 0.0))
	if target_hp > 0.0 and total_expected_damage >= target_hp:
		score += 25.0

	# --- Defensive value: enemies can hit an illusion instead of Naga
	# herself - never purely offensive (see this function's own
	# docstring). Reuses the same HP-ratio/outnumbered signals
	# _evaluate_defensive() uses elsewhere, just feeding this skill's own
	# value instead of the shared category term (which never runs for a
	# "utility"-category skill like this one).
	var hp_ratio: float = float(context.get("hero_hp_ratio", 1.0))
	if hp_ratio < 0.20:
		score += 35.0
	elif hp_ratio < 0.50:
		score += 20.0
	if int(context.get("enemy_count", 1)) >= 2:
		score += 25.0
	if hit_chance_pct >= 0.35:
		score += 20.0

	# --- Recasting mid-duration replaces a still-healthy set outright
	# (_end_mirror_image() runs first every time - see battle.gd's own
	# _activate_mirror_image()) - only worth it once the current set is
	# close to expiring anyway, never as a mid-duration "refresh". ---
	if bool(context.get("illusions_active", false)) and int(context.get("illusion_turns_remaining", 0)) >= 2:
		score -= 25.0

	return score


## Ensnare: a ROOT, not a stun - the target can still attack and cast
## while rooted (see the design doc's own explicit "does not prevent
## attacking or skill usage" instruction), so unlike Torrent's/Barbed Lunge's
## own stuns this gets no generic "stun_turns" bonus at all - its whole
## value is movement denial/kill setup: securing a kill the upfront hit
## alone wouldn't, keeping a target that would otherwise create distance
## within reach, and letting active illusions keep attacking it too.
static func _naga_ensnare_modifier(level_data: Dictionary, context: Dictionary) -> float:
	var score: float = 0.0

	var target_hp: float = float(context.get("target_hp", 0.0))
	var target_max_hp: float = float(context.get("target_max_hp", 0.0))
	if target_max_hp > 0.0 and target_hp / target_max_hp < 0.35:
		score += 20.0

	# A kill the root itself doesn't land but SETS UP over the turns the
	# target can't escape Naga's (and any active illusions') follow-up
	# hits - the primary target's own upfront kill is already scored
	# generically (see _kill_potential_bonus(), fed by this skill's own
	# flat-damage _estimate_skill_damage() case), this only adds for a
	# kill that needs the follow-up window to actually happen.
	var ensnare_damage: float = float(level_data.get("damage", 0.0))
	if target_hp > 0.0 and ensnare_damage < target_hp:
		var root_turns: int = int(level_data.get("root_turns", 0))
		var follow_up_damage: float = float(context.get("hero_damage", 0.0)) * float(root_turns)
		if bool(context.get("illusions_active", false)):
			follow_up_damage += float(context.get("illusion_total_damage_per_turn", 0.0)) * float(root_turns)
		if ensnare_damage + follow_up_damage >= target_hp:
			score += 25.0

	# Only real in a hero fight (target_distance is absent in the
	# simulation - no positions there, same "no columns" honesty every
	# other position-dependent modifier in this file already follows -
	# see _tp_natures_guise_modifier()'s own early-out for the same
	# pattern). A target not already adjacent has real room to try to
	# create distance next turn; one within this level's own range that
	# wouldn't otherwise be guaranteed to stay there is exactly what the
	# root is for.
	var raw_distance: int = int(context.get("target_distance", -1))
	if raw_distance >= 0:
		if raw_distance > 1:
			score += 15.0
		var ensnare_range: int = int(level_data.get("range", 0))
		if raw_distance > 0 and raw_distance <= ensnare_range:
			score += 20.0

	# Active illusions can keep attacking a target that can no longer run
	# from them either - this also covers the design doc's own separate
	# "rooting the target allows Naga/illusions to attack it" bullet,
	# which would otherwise double-count the same signal.
	if bool(context.get("illusions_active", false)):
		score += 20.0

	return score


## Song of the Siren: not a direct-damage cast (no damage field of its
## own at all) - its real destructive value is every hit Naga and any
## active illusions can land completely safely while every enemy in
## radius is stunned and unable to retaliate. Self-centered, same "reuse
## target_distance as its own self-cast range check" idiom Crystal
## Maiden's own Freezing Field/Treant Protector's own Overgrowth already
## use (see _tp_overgrowth_modifier()'s own docstring) - out of range in
## a real fight scores low rather than being excluded outright, same
## early-out shape Overgrowth's own uses.
static func _naga_song_of_the_siren_modifier(level_data: Dictionary, context: Dictionary) -> float:
	var radius: int = int(level_data.get("radius", 0))
	var raw_distance: int = int(context.get("target_distance", -1))
	var in_range: bool = raw_distance < 0 or raw_distance <= radius
	if not in_range:
		return -40.0

	var living_hps: Array = context.get("living_target_hps", [])
	var living_max_hps: Array = context.get("living_target_max_hps", living_hps)
	var hit_count: int = living_hps.size()

	var score: float = 0.0
	if hit_count >= 3:
		score += 60.0
	elif hit_count == 2:
		score += 40.0
	elif hit_count == 1:
		score += 25.0

	# "High-threat enemy" has no real stat to read anywhere in this
	# project (same gap Whirling Death's own primary-attribute reduction
	# has - see this file's own header comment) - the closest honest
	# proxy is a target already low enough to be worth finishing off, the
	# same low-HP signal Overgrowth's own modifier already uses.
	var low_hp_count: int = 0
	for i in range(hit_count):
		var hp: float = float(living_hps[i])
		if hp <= 0.0:
			continue
		var max_hp: float = float(living_max_hps[i]) if i < living_max_hps.size() else hp
		if max_hp > 0.0 and hp <= max_hp * 0.3:
			low_hp_count += 1
	score += 20.0 * float(low_hp_count)

	# --- The offensive window itself: every hit Naga (and any active
	# illusions) land completely safely while enemies are stunned - see
	# _naga_song_expected_damage()'s own docstring. ---
	var total_physical_damage: float = _naga_song_expected_damage(level_data, context)

	var extra_kills: int = 0
	for hp in living_hps:
		if total_physical_damage >= float(hp) and float(hp) > 0.0:
			extra_kills += 1
	if extra_kills >= 1:
		score += 25.0
	if extra_kills >= 2:
		score += 35.0 * float(extra_kills - 1)

	# --- Armor reduction: worth more the larger a slice of the target's
	# own CURRENT armor it actually shreds AND the more physical damage
	# is already happening during the window to benefit from it - same
	# "reduction_pct off the target's own current armor" idiom Snapfire's
	# own Lil' Shredder modifier uses (see _snapfire_lil_shredder_
	# modifier()), scaled by this window's own real damage total instead
	# of a flat number, per the design doc's own explicit "its value
	# depends on how much physical damage Naga can actually deal, not a
	# flat bonus" instruction. ---
	var armor_reduction: float = float(level_data.get("armor_reduction", 0.0))
	var target_armor: float = float(context.get("target_armor", 0.0))
	if armor_reduction > 0.0 and target_armor > 0.0:
		var reduction_pct: float = clampf(armor_reduction / target_armor, 0.0, 1.0)
		score += total_physical_damage * reduction_pct * 0.3

	# --- Mirror Image synergy: Naga's primary combo. Active illusions
	# turn the stun from pure control into a second wave of safe damage. ---
	var illusions_active: bool = bool(context.get("illusions_active", false))
	var stun_turns: int = int(level_data.get("stun_turns", 0))
	if illusions_active:
		score += 25.0
		var illusion_count: int = int(context.get("illusion_count", 0))
		var illusion_turns_remaining: int = int(context.get("illusion_turns_remaining", 0))
		var illusion_damage_per_turn: float = float(context.get("illusion_total_damage_per_turn", 0.0))
		if illusion_count >= 2 and illusion_turns_remaining >= int(ceil(float(stun_turns) / 2.0)):
			score += 40.0
		if illusion_count >= 2 and illusion_turns_remaining >= stun_turns and illusion_damage_per_turn > 0.0:
			score += 60.0

	# --- Defensive use: only under real danger, never just "took some
	# damage" (per the design doc's own explicit caution) - she can
	# still attack while the stun holds, so offense stays the default
	# read whenever a real offensive opportunity already exists above. ---
	var hp_ratio: float = float(context.get("hero_hp_ratio", 1.0))
	var enemy_count: int = int(context.get("enemy_count", 1))
	if hp_ratio < 0.20:
		score += 20.0
	elif hp_ratio < 0.30 and enemy_count >= 2:
		score += 30.0

	# --- Opportunity cost: a single already-low-value target, no
	# illusions up, and no real attack window isn't worth a high-mana
	# ultimate's cooldown - a cheaper play can do the same job (per the
	# design doc's own "apply a resource penalty when Naga is unable to
	# capitalize on the stun" instruction). A nudge, not a veto - the
	# surrounding score comparison against every other candidate still
	# gets the final say. ---
	var target_hp: float = float(context.get("target_hp", 0.0))
	if hit_count <= 1 and not illusions_active and total_physical_damage < target_hp * 0.4:
		score -= 30.0

	return score


## Shared by both _estimate_skill_damage()'s own "song_of_the_siren" case
## (which feeds the generic kill-potential term against the primary
## target) and _naga_song_of_the_siren_modifier() (which needs the same
## total for its own armor-reduction/extra-kill math), so the two never
## drift apart. Song of the Siren has no damage field of its own at all -
## its real value is every attack Naga (this level's own stun_turns
## worth of them - she can still act every turn the stun holds) and any
## active illusions land completely safely, plus whatever Rip Tide's own
## splash adds across the other stunned targets.
static func _naga_song_expected_damage(level_data: Dictionary, context: Dictionary) -> float:
	var stun_turns: int = int(level_data.get("stun_turns", 0))
	var hero_damage: float = float(context.get("hero_damage", 0.0))
	var expected_naga_damage: float = hero_damage * float(stun_turns)

	var illusion_damage: float = 0.0
	if bool(context.get("illusions_active", false)):
		illusion_damage = float(context.get("illusion_total_damage_per_turn", 0.0)) * float(stun_turns)

	var hit_count: int = context.get("living_target_hps", []).size()
	var rip_tide_aoe_pct: float = float(context.get("rip_tide_aoe_damage_pct", 0.0))
	var splash_damage: float = expected_naga_damage * rip_tide_aoe_pct * float(maxi(hit_count - 1, 0))

	return expected_naga_damage + illusion_damage + splash_damage


## A plain Attack is only worth scoring above its flat baseline for Naga
## Siren when it can already finish the target off, when Rip Tide's own
## splash reaches more than one enemy, or when active illusions are
## already focus-firing the same target (see basic_attack_participates()'
## own docstring for why she opts in at all).
static func _naga_basic_attack_modifier(context: Dictionary) -> float:
	var score: float = 0.0

	var hero_damage: float = float(context.get("hero_damage", 0.0))
	var target_hp: float = float(context.get("target_hp", 0.0))
	if target_hp > 0.0 and hero_damage >= target_hp:
		score += 50.0

	var living_hps: Array = context.get("living_target_hps", [])
	if float(context.get("rip_tide_aoe_damage_pct", 0.0)) > 0.0:
		var splash_targets: int = maxi(living_hps.size() - 1, 0)
		if splash_targets >= 2:
			score += 30.0
		elif splash_targets == 1:
			score += 15.0

	if bool(context.get("illusions_active", false)):
		# The illusions already focus-fire the same target a plain Attack
		# would hit (see battle.gd's own _fire_mirror_image_attack()) -
		# stacking a real Attack onto that same target keeps the whole
		# squad's damage concentrated instead of spending mana on a fresh
		# cast.
		score += 10.0

	var max_mana: float = float(context.get("hero_max_mana", 0.0))
	if max_mana > 0.0 and float(context.get("hero_mana", 0.0)) / max_mana < 0.3:
		score += 8.0

	return score


## Slardar: aggressive melee bruiser, control-oriented, kill-focused,
## armor-break/damage-amplification focused. Every one of his skills
## leans on context fields battle.gd's/EnemyHeroManager's own
## _build_*_ai_context() compute fresh each turn - "hero_move_distance"/
## "sprint_bonus_movement"/"sprint_charge_damage_pct" (Guardian Sprint's
## own reach, read by Corrosive Haze/a plain Attack too, since Sprint
## itself is only ever scored as a candidate on the turn it's actually
## cast), "bash_attacks_required"/"bash_current_progress"/"bash_bonus_
## damage_pct"/"bash_knockback" (Bash of the Deep's current progression -
## the passive itself is never a scored candidate, see this file's own
## header comment), "crush_radius"/"crush_damage" (Slithereen Crush's
## current level, for Sprint's/Haze's own combo bonuses), and
## "target_marked_bonus_pct" (whether the CURRENT target is already
## Corrosive Haze-marked, for a plain Attack's own synergy bonus).
static func _slardar_modifier(skill_id: String, level_data: Dictionary, context: Dictionary) -> float:
	match skill_id:
		"guardian_sprint":
			return _slardar_guardian_sprint_modifier(level_data, context)
		"slithereen_crush":
			return _slardar_slithereen_crush_modifier(level_data, context)
		"corrosive_haze":
			return _slardar_corrosive_haze_modifier(level_data, context)
		BASIC_ATTACK_ID:
			return _slardar_basic_attack_modifier(context)
		_:
			return 0.0


## True if Bash of the Deep is learned and the VERY NEXT qualifying
## Attack will trigger it - shared by every one of this hero's own
## modifiers that care (Guardian Sprint's own "+20 enables a ready Bash"
## bonus, Corrosive Haze's own Bash synergy, a plain Attack's own
## substantial bonus) so none of them re-derive the same off-by-one
## threshold check differently.
static func _slardar_bash_ready(context: Dictionary) -> bool:
	var required: int = int(context.get("bash_attacks_required", 0))
	if required <= 0:
		return false
	return int(context.get("bash_current_progress", 0)) + 1 >= required


## Bash's own knockback: worth a real (if modest) bonus while Slardar is
## actually threatened - a bit of breathing room right after he already
## landed the hit - but at full/moderate HP it only pushes the target OUT
## of his own melee follow-up range (he was already standing next to it
## to land the Attack that triggered Bash in the first place), a real
## cost rather than a free one, per the design doc's own explicit "do not
## give large value to knockback if it moves the target away and makes
## subsequent attacks harder" caution. Guardian Sprint's own current
## reach being enough to close that same gap right back turns the cost
## into a wash instead of a loss.
static func _slardar_bash_knockback_value(context: Dictionary) -> float:
	var knockback: int = int(context.get("bash_knockback", 0))
	if knockback <= 0:
		return 0.0

	var hp_ratio: float = float(context.get("hero_hp_ratio", 1.0))
	var enemy_count: int = int(context.get("enemy_count", 1))
	if hp_ratio < 0.35 or enemy_count >= 2:
		return 12.0

	if int(context.get("sprint_bonus_movement", 0)) >= knockback:
		return 0.0

	return -8.0


## The raw (pre-amplification) physical damage Slardar can realistically
## land on the current target over `duration` turns - Basic Attacks,
## Bash of the Deep's own bonus procs along the way, one Slithereen Crush
## hit if the target stays within its radius, and Guardian Sprint's own
## charge damage if the target isn't already in melee range but Sprint
## can close the gap. Shared by _slardar_corrosive_haze_modifier() (which
## needs this to work out the debuff's own AMPLIFIED total, per the
## design doc's own "do not treat bonus_damage_pct as simply +20 score -
## estimate the actual bonus damage" instruction) and _estimate_skill_
## damage()'s own "corrosive_haze" case (via _slardar_corrosive_haze_
## expected_damage()), so the two numbers never drift apart. `duration`
## is capped at 4 turns' worth of attacks even when the debuff itself
## lasts longer - the same "do not automatically assume every enemy
## stays in range for the full duration" caution Timbersaw's own Chakram
## modifier already follows, rather than letting a 6-turn Haze imply six
## guaranteed hits.
static func _slardar_expected_attacks_on_target(duration: int, context: Dictionary) -> float:
	var hero_damage: float = float(context.get("hero_damage", 0.0))
	var raw_distance: int = int(context.get("target_distance", -1))
	var reach: int = int(context.get("hero_move_distance", 1)) + int(context.get("sprint_bonus_movement", 0))
	var expected_hits: int = mini(duration, 4)

	# No positions at all in the simulation (target_distance is absent) -
	# every attack already reaches its target with no travel cost, same
	# "no columns" simplification _tp_natures_guise_modifier()'s own
	# early-out already follows - so Slardar is always treated as already
	# in melee range there.
	var already_in_range: bool = raw_distance < 0 or raw_distance <= 0
	var reachable_via_sprint: bool = raw_distance > 0 and raw_distance <= reach

	var base_damage: float = 0.0
	var sprint_damage: float = 0.0
	var attacks_landed: int = 0
	if already_in_range:
		base_damage = hero_damage * float(expected_hits)
		attacks_landed = expected_hits
	elif reachable_via_sprint:
		# Closing the distance costs the FIRST turn of the window - only
		# the turns left over actually land a plain Attack, same "the
		# travel itself isn't free" honesty this whole estimate leans on.
		sprint_damage = hero_damage * float(context.get("sprint_charge_damage_pct", 0.0))
		attacks_landed = maxi(expected_hits - 1, 0)
		base_damage = hero_damage * float(attacks_landed)
	# else: genuinely unreachable during the window - nothing to count.

	var bash_required: int = int(context.get("bash_attacks_required", 0))
	var bash_damage: float = 0.0
	if bash_required > 0 and attacks_landed > 0:
		var bash_progress: int = int(context.get("bash_current_progress", 0))
		var expected_bash_procs: float = floor(float(attacks_landed + bash_progress) / float(bash_required))
		bash_damage = expected_bash_procs * hero_damage * float(context.get("bash_bonus_damage_pct", 0.0))

	var crush_damage: float = 0.0
	var crush_radius: int = int(context.get("crush_radius", 0))
	if crush_radius > 0 and (raw_distance < 0 or raw_distance <= crush_radius):
		crush_damage = float(context.get("crush_damage", 0.0))

	return base_damage + sprint_damage + bash_damage + crush_damage


## Guardian Sprint: NOT a pure damage ability - its primary value is
## positional (see the design doc's own explicit instruction). Out of
## reach even with the bonus movement folded in scores as a wasted cast,
## already standing on the target scores as a redundant one (Sprint has
## nothing left to set up that Basic Attack/Crush don't already have),
## and landing on the target - which, per Guardian Sprint's own "stop on
## the first enemy in the way" rule (see battle.gd's own
## _guardian_sprint_move_target()), always means reaching the enemy,
## dealing charge damage, AND ending up in attack range simultaneously -
## is the one case that matters, so the design doc's own separate "+20
## reach"/"+20 charge damage"/"+20 attack range" bonuses collapse into
## one 60-point event here rather than three independent checks over an
## event that only ever happens once. `target_distance` is absent in the
## simulation (no positions there at all) - this returns a flat 0 in
## that case rather than guessing, same as every other position-
## dependent modifier in this file.
static func _slardar_guardian_sprint_modifier(level_data: Dictionary, context: Dictionary) -> float:
	var raw_distance: int = int(context.get("target_distance", -1))
	if raw_distance < 0:
		return 0.0

	var reach: int = int(context.get("hero_move_distance", 1)) + int(level_data.get("bonus_movement", 0))
	var score: float = 0.0

	if raw_distance <= 0:
		# Already standing right on the target - vanishing distance that
		# isn't there only delays whatever's already available (see the
		# design doc's own "do not use Sprint without a meaningful
		# positional benefit" instruction).
		score -= 20.0
	elif raw_distance <= reach:
		score += 60.0

		var charge_damage: float = float(context.get("hero_damage", 0.0)) * float(level_data.get("charge_damage_pct", 0.0))
		var target_hp: float = float(context.get("target_hp", 0.0))
		if target_hp > 0.0 and charge_damage >= target_hp:
			score += 25.0

		if int(context.get("crush_radius", 0)) > 0:
			# Landing ON the target's own column is within any radius
			# >= 0, so there's no separate distance check needed here -
			# reaching it at all already guarantees Crush would connect.
			score += 15.0

		if _slardar_bash_ready(context):
			score += 20.0
	else:
		# Can't realistically reach the target even with the bonus
		# movement folded in - a setup with nothing left to set up, same
		# "cannot realistically reach a useful target" waste case
		# _tp_natures_guise_modifier()'s own copy already covers.
		score -= 15.0

	# --- Defensive value: an escape, not an engage - only under real
	# danger, never just "lost some HP" (per the design doc's own
	# explicit caution), and small enough that a real offensive
	# opportunity above (the +60 branch) always wins out regardless. ---
	var hp_ratio: float = float(context.get("hero_hp_ratio", 1.0))
	if hp_ratio < 0.20:
		score += 30.0 + minf(float(int(context.get("enemy_count", 1)) - 1), 3.0) * 5.0

	return score


## Slithereen Crush: one of Slardar's most frequently valuable actives -
## real AoE damage/stun/burst, not a single-target nuke that happens to
## have a radius. The generic offensive scoring above already covers the
## primary target's own value/kill potential (fed by this skill's own
## flat-damage _estimate_skill_damage() case); this adds the design
## doc's own multi-target/high-threat/stun/kill-setup tiers on top, all
## computed from the ACTUAL affected positions (`living_target_hps`),
## never assumed from "is one enemy in range" alone.
static func _slardar_slithereen_crush_modifier(level_data: Dictionary, context: Dictionary) -> float:
	var living_hps: Array = context.get("living_target_hps", [])
	var hit_count: int = living_hps.size()
	if hit_count <= 0:
		return -35.0

	var score: float = 0.0
	if hit_count >= 3:
		score += 50.0
	elif hit_count == 2:
		score += 35.0
	elif hit_count == 1:
		score += 20.0

	# "High-threat enemy" has no real per-creep stat exposed to this
	# shared context today (same gap Whirling Death's own primary-
	# attribute reduction has - see this file's own header comment); the
	# one real, always-available signal is `target_is_hero` - a hero-
	# fight boss's own opponent (the player) is definitionally a bigger
	# threat than a regular creep, same qualitative read Timbersaw's own
	# modifier already uses that field for.
	if bool(context.get("target_is_hero", false)):
		score += 20.0 * float(hit_count)

	var stun_turns: int = int(level_data.get("stun_turns", 0))
	# Control value scaled by BOTH duration and how many targets are
	# actually stunned at once - reading the level's own real stun_turns
	# rather than assuming a fixed 1-turn stun, per the design doc's own
	# explicit instruction. A real stun (unlike Overgrowth's pure root),
	# so this leans harder per turn than Overgrowth's own root-duration
	# term does.
	score += float(stun_turns) * float(hit_count) * 8.0

	var damage: float = float(level_data.get("damage", 0.0))
	var extra_kills: int = 0
	for hp in living_hps:
		if damage >= float(hp) and float(hp) > 0.0:
			extra_kills += 1
	# The primary target's own kill is already scored generically (see
	# _kill_potential_bonus(), fed by _estimate_skill_damage()'s own
	# "slithereen_crush" case) - this only adds for kills BEYOND that
	# one, same split Torrent's/Overgrowth's/Song of the Siren's own
	# modifiers use.
	if extra_kills >= 2:
		score += 40.0 * float(extra_kills - 1)

	# Crush → Bash: a stunned target Slardar can immediately follow up on
	# is exactly the setup a ready Bash needs - per the design doc's own
	# explicit "Slithereen Crush → Bash" synergy.
	if _slardar_bash_ready(context):
		score += 20.0

	return score


## Corrosive Haze: Slardar's ultimate - armor reduction + damage
## amplification + a multi-turn offensive setup, never a simple debuff
## scored by a flat "+20 per 10% amplification" - see _slardar_expected_
## attacks_on_target()'s own docstring for how the real bonus damage is
## actually estimated. Targets a high-HP/high-armor/dangerous enemy that
## will stick around long enough to be worth the setup, and backs off
## when the target would die to a normal/Bash-ready Attack anyway (per
## the design doc's own explicit "casting the ultimate first may be
## unnecessary" instruction) or when Slardar has no realistic way to
## reach it before the debuff mostly expires.
static func _slardar_corrosive_haze_modifier(level_data: Dictionary, context: Dictionary) -> float:
	var score: float = 0.0

	var hero_damage: float = float(context.get("hero_damage", 0.0))
	var target_hp: float = float(context.get("target_hp", 0.0))
	var target_max_hp: float = float(context.get("target_max_hp", 0.0))

	if hero_damage > 0.0 and target_max_hp >= hero_damage * 3.0:
		score += 20.0

	var target_armor: float = float(context.get("target_armor", 0.0))
	if target_armor >= 4.0:
		score += 20.0

	var raw_distance: int = int(context.get("target_distance", -1))
	var reach: int = int(context.get("hero_move_distance", 1)) + int(context.get("sprint_bonus_movement", 0))
	var can_attack_repeatedly: bool = raw_distance < 0 or raw_distance <= reach
	if can_attack_repeatedly:
		score += 20.0

	if target_hp > 0.0 and hero_damage > 0.0 and target_hp > hero_damage:
		# Will survive the next hit outright - there's a debuff window
		# actually left to exploit, per the design doc's own "the target
		# will survive several attacks" instruction.
		score += 25.0

	if bool(context.get("target_is_hero", false)):
		score += 25.0

	var duration: int = int(level_data.get("duration", 0))
	var raw_total_damage: float = _slardar_expected_attacks_on_target(duration, context)
	var bonus_pct: float = float(level_data.get("bonus_damage_pct", 0.0))
	var bonus_damage_from_haze: float = raw_total_damage * bonus_pct
	# Scaled by the REAL estimated bonus damage, never a flat "+20 per
	# 10%" reading of bonus_damage_pct - per the design doc's own
	# explicit instruction.
	score += bonus_damage_from_haze * 0.15

	var total_expected_damage: float = raw_total_damage + bonus_damage_from_haze
	if target_hp > 0.0 and total_expected_damage >= target_hp:
		score += 30.0

	# --- Haze + Bash: an already/soon-ready Bash means the amplified hit
	# that triggers it benefits from both normal damage and Bash's own
	# bonus - per the design doc's own explicit "Corrosive Haze + Bash"
	# section (already folded into raw_total_damage above via
	# _slardar_expected_attacks_on_target()'s own bash_damage term; this
	# is the qualitative top-up on top of that). ---
	var bash_ready: bool = _slardar_bash_ready(context)
	if bash_ready:
		score += 15.0

	# --- Early-out: a target that already dies to a normal (or Bash-
	# ready) Attack has nothing left for a multi-turn debuff to exploit -
	# per the design doc's own explicit "if Slardar can already kill the
	# target with a normal/Bash attack, casting the ultimate first may be
	# unnecessary" instruction. A steep penalty, not a hard veto - a
	# genuinely strong multi-target/multi-turn setup can still outweigh
	# it once every term above is in. ---
	var immediate_kill_damage: float = hero_damage
	if bash_ready:
		immediate_kill_damage += hero_damage * float(context.get("bash_bonus_damage_pct", 0.0))
	if target_hp > 0.0 and immediate_kill_damage >= target_hp:
		score -= 40.0

	# --- Resource penalty: genuinely can't reach the target during the
	# debuff's own window - per the design doc's own explicit "Slardar
	# cannot reach the target" resource-penalty instruction. ---
	if raw_distance >= 0 and raw_distance > reach and not (target_hp > 0.0 and immediate_kill_damage >= target_hp):
		score -= 35.0

	return score


## Shared by both _estimate_skill_damage()'s own "corrosive_haze" case
## (which feeds the generic kill-potential term against the primary
## target) and _slardar_corrosive_haze_modifier() (which needs the same
## total for its own amplification/kill-potential math), so the two
## never drift apart - the mark's own total expected damage over its
## duration, raw physical output plus the amplified portion on top.
static func _slardar_corrosive_haze_expected_damage(level_data: Dictionary, context: Dictionary) -> float:
	var duration: int = int(level_data.get("duration", 0))
	var raw_total: float = _slardar_expected_attacks_on_target(duration, context)
	var bonus_pct: float = float(level_data.get("bonus_damage_pct", 0.0))
	return raw_total * (1.0 + bonus_pct)


## A plain Attack is Slardar's single most important candidate - Bash of
## the Deep rides on it, so this is scored well above the flat baseline
## whenever it matters, per the design doc's own explicit "it is
## especially important for Slardar because of Bash of the Deep"
## instruction, rather than only ever being the fallback for "nothing
## else qualified" (see basic_attack_participates()'s own docstring for
## why he opts in at all).
static func _slardar_basic_attack_modifier(context: Dictionary) -> float:
	var score: float = 0.0

	var hero_damage: float = float(context.get("hero_damage", 0.0))
	var target_hp: float = float(context.get("target_hp", 0.0))
	var bash_ready: bool = _slardar_bash_ready(context)

	var attack_damage: float = hero_damage
	if bash_ready:
		attack_damage += hero_damage * float(context.get("bash_bonus_damage_pct", 0.0))
		score += 30.0
		score += _slardar_bash_knockback_value(context)

	if target_hp > 0.0 and attack_damage >= target_hp:
		score += 50.0
		if bash_ready:
			score += 20.0

	var marked_bonus_pct: float = float(context.get("target_marked_bonus_pct", 0.0))
	if marked_bonus_pct > 0.0:
		# The target is already Corrosive Haze-marked - a plain Attack
		# realizes that amplification for free, right now, rather than
		# spending another cast to set up more of it.
		score += hero_damage * marked_bonus_pct * 0.5

	var max_mana: float = float(context.get("hero_max_mana", 0.0))
	if max_mana > 0.0 and float(context.get("hero_mana", 0.0)) / max_mana < 0.3:
		score += 8.0

	return score


## Mirana: mobile ranged hunter - hit-and-run, position-aware, kill-
## focused. Every one of her skills leans on context fields battle.gd's/
## EnemyHeroManager's own _build_*_ai_context() compute fresh each turn -
## "hero_attack_range" (her own basic-attack reach, for Leap's own before/
## after comparison), "starstorm_radius"/"sacred_arrow_range"/"sacred_
## arrow_base_damage"/"sacred_arrow_bonus_per_column" (her OTHER skills'
## current levels, read by Leap's/Moonlight Shadow's own combo bonuses
## since each is only ever scored as a candidate on the turn it's itself
## being cast), "moonlight_shadow_active"/"moonlight_shadow_bonus_damage_
## pct" (her own current stealth state, for a plain Attack's own
## substantial bonus), and "target_stunned" (whether her own Sacred Arrow
## already locked the current target down, for a plain Attack's own
## follow-up bonus).
static func _mirana_modifier(skill_id: String, level_data: Dictionary, context: Dictionary) -> float:
	match skill_id:
		"starstorm":
			return _mirana_starstorm_modifier(level_data, context)
		"sacred_arrow":
			return _mirana_sacred_arrow_modifier(level_data, context)
		"leap":
			return _mirana_leap_modifier(level_data, context)
		"moonlight_shadow":
			return _mirana_moonlight_shadow_modifier(level_data, context)
		BASIC_ATTACK_ID:
			return _mirana_basic_attack_modifier(context)
		_:
			return 0.0


## Starstorm: real AoE burst, not a single-target nuke that happens to
## have a radius - same shape as Slithereen Crush's own modifier (see
## _slardar_slithereen_crush_modifier()'s own docstring), minus the stun
## (Starstorm deals damage only - see battle.gd's own _cast_starstorm()).
## The generic offensive scoring above already covers the primary
## target's own value/kill potential (fed by this skill's own flat-
## damage _estimate_skill_damage() case); this adds the design doc's own
## multi-target/high-threat/multi-kill/finish-the-weakened tiers on top,
## all computed from the ACTUAL affected positions (`living_target_hps`),
## never assumed from "is one enemy nearby" alone.
static func _mirana_starstorm_modifier(level_data: Dictionary, context: Dictionary) -> float:
	var living_hps: Array = context.get("living_target_hps", [])
	var hit_count: int = living_hps.size()
	if hit_count <= 0:
		return -35.0

	var score: float = 0.0
	if hit_count >= 3:
		score += 50.0
	elif hit_count == 2:
		score += 35.0
	elif hit_count == 1:
		score += 20.0

	# "High-threat enemy" has no real per-creep stat exposed to this
	# shared context today (same gap this file's own header comment
	# already documents for Whirling Death/Slithereen Crush) - the one
	# real, always-available signal is `target_is_hero`, same qualitative
	# read _slardar_slithereen_crush_modifier() already uses it for.
	if bool(context.get("target_is_hero", false)):
		score += 20.0 * float(hit_count)

	var damage: float = float(level_data.get("damage", 0.0))
	var living_max_hps: Array = context.get("living_target_max_hps", living_hps)
	var extra_kills: int = 0
	var finishable_count: int = 0
	for i in range(hit_count):
		var hp: float = float(living_hps[i])
		if hp <= 0.0:
			continue
		if damage >= hp:
			extra_kills += 1
		var max_hp: float = float(living_max_hps[i]) if i < living_max_hps.size() else hp
		if max_hp > 0.0 and hp <= max_hp * 0.3:
			finishable_count += 1

	# The primary target's own kill is already scored generically (see
	# _kill_potential_bonus(), fed by _estimate_skill_damage()'s own
	# "starstorm" case) - this only adds for kills BEYOND that one, same
	# split every other multi-target ultimate's own modifier in this file
	# uses.
	if extra_kills >= 2:
		score += 40.0 * float(extra_kills - 1)
	# "Finish several weakened enemies" - a real bonus for enemies
	# already low even when Starstorm's own flat damage doesn't quite
	# finish them outright (a DoT/another attack the same turn might).
	score += 15.0 * float(finishable_count)

	# --- Defensive value: real when Mirana is actually surrounded/
	# threatened, never the DOMINANT reason to cast (per the design
	# doc's own explicit "do not make this purely defensive" caution -
	# note this only ever adds on top of the offensive tiers above,
	# never replaces them). ---
	var enemy_count: int = int(context.get("enemy_count", 1))
	var hp_ratio: float = float(context.get("hero_hp_ratio", 1.0))
	if enemy_count >= 2 and hp_ratio < 0.5:
		score += 15.0 * float(mini(enemy_count - 1, 3))

	return score


## Sacred Arrow: generally Mirana's strongest single-target ability - its
## damage genuinely scales with how far it traveled (see _mirana_sacred_
## arrow_expected_damage()'s own docstring), so a long-range shot against
## a valuable target is worth real extra score, never a flat "+X for
## using it at range" the way a lesser implementation might. The generic
## offensive scoring above already covers target value/kill potential
## (fed by the real distance-scaled estimate); this adds the design
## doc's own high-threat/stun/follow-up-kill tiers on top, all reading
## this level's own actual stun_turns rather than assuming a fixed
## duration.
static func _mirana_sacred_arrow_modifier(level_data: Dictionary, context: Dictionary) -> float:
	var score: float = 0.0

	var raw_distance: int = int(context.get("target_distance", -1))
	var distance: float = float(maxi(raw_distance, 0)) if raw_distance >= 0 else 0.0
	var bonus_per_column: float = float(level_data.get("bonus_per_column", 0.0))
	var target_hp: float = float(context.get("target_hp", 0.0))
	var target_max_hp: float = float(context.get("target_max_hp", 0.0))

	# Long travel distance is only worth reaching FOR when the target is
	# actually worth hitting hard - scaled by how valuable/already-hurt
	# it is, per the design doc's own "strongly prefer a long-distance
	# arrow when the target is valuable" instruction, never a flat
	# "more distance = more score" regardless of who's on the other end.
	var value_factor: float = clampf(1.0 - (target_hp / target_max_hp if target_max_hp > 0.0 else 0.0), 0.2, 1.0)
	score += distance * bonus_per_column * 0.25 * value_factor

	if bool(context.get("target_is_hero", false)):
		score += 20.0

	var stun_turns: int = int(level_data.get("stun_turns", 0))
	if stun_turns >= 1:
		score += 20.0  # a meaningful single-target stun
		score += float(stun_turns - 1) * 8.0  # duration scales control value
		if bool(context.get("target_is_hero", false)):
			score += 25.0  # prevents a dangerous enemy's own next action
		# A stunned single target always creates a safe follow-up here -
		# there's nothing else for it to do back regardless of who lands
		# the next hit (see _mirana_basic_attack_modifier()'s own
		# "target_stunned" bonus for the other half of this synergy).
		score += 20.0

	var estimated_damage: float = _mirana_sacred_arrow_expected_damage(level_data, context)
	if stun_turns >= 1 and target_hp > 0.0 and estimated_damage < target_hp and estimated_damage + float(context.get("hero_damage", 0.0)) >= target_hp:
		# The stun buys the follow-up Attack that actually finishes it.
		score += 25.0

	return score


## Shared by both _estimate_skill_damage()'s own "sacred_arrow" case
## (which feeds the generic kill-potential term) and _mirana_sacred_
## arrow_modifier() (which needs the same number for its own distance-
## value/follow-up-kill math), so the two never drift apart. Reads the
## REAL travel distance (`target_distance`, already the actual column
## count the shared movement/grid rules give every other position-aware
## modifier in this file) rather than assuming a fixed or maximum-range
## hit - 0 (base damage only) in the simulation, where there are no
## positions to travel across at all, same "no columns" honesty every
## other position-dependent modifier here already follows.
static func _mirana_sacred_arrow_expected_damage(level_data: Dictionary, context: Dictionary) -> float:
	var raw_distance: int = int(context.get("target_distance", -1))
	var distance: float = float(maxi(raw_distance, 0)) if raw_distance >= 0 else 0.0
	return float(level_data.get("base_damage", 0.0)) + float(level_data.get("bonus_per_column", 0.0)) * distance


## Leap: deals no damage of its own - its whole value is the resulting
## position, compared explicitly BEFORE and AFTER the jump rather than
## scored off its own movement distance alone, per the design doc's own
## explicit instruction. `target_distance` is absent in the simulation
## (no positions there at all) - this returns a flat 0 in that case
## rather than guessing, same as every other position-dependent modifier
## in this file (see _tp_natures_guise_modifier()'s own early-out).
##
## Leap always jumps in whichever direction Mirana is CURRENTLY facing
## (see battle.gd's own _activate_leap()/_cast_enemy_leap()), so unlike a
## gap-closer that always steps toward the nearest enemy, a single cast
## could go either toward or away from the target - this function scores
## both the offensive "closes distance" case and the defensive "creates
## distance" case in the same pass, trusting the actual cast function
## (_cast_enemy_leap()) to pick whichever direction the SAME hp_ratio
## threshold used below would call for, so the two never disagree about
## which way she'd actually jump.
static func _mirana_leap_modifier(level_data: Dictionary, context: Dictionary) -> float:
	var raw_distance: int = int(context.get("target_distance", -1))
	if raw_distance < 0:
		return 0.0

	var jump_distance: int = int(level_data.get("jump_distance", 0))
	var attack_range: int = int(context.get("hero_attack_range", 0))
	var distance_after_leap_toward: int = maxi(raw_distance - jump_distance, 0)

	var score: float = 0.0
	var was_in_range: bool = raw_distance <= attack_range
	var would_be_in_range: bool = distance_after_leap_toward <= attack_range

	if was_in_range:
		# Already close enough - leaping only trades a real position for
		# nothing new, per the design doc's own "do not use Leap without
		# a meaningful positional benefit" instruction.
		score -= 15.0
	elif would_be_in_range:
		score += 20.0

		var starstorm_radius: int = int(context.get("starstorm_radius", 0))
		var living_hps: Array = context.get("living_target_hps", [])
		if starstorm_radius > 0 and living_hps.size() >= 2:
			# Setup value: landing here doesn't just enable an Attack, it
			# also sets up a real multi-target Starstorm next - per the
			# design doc's own explicit "Leap + Starstorm" instruction.
			score += 25.0

		var hero_damage: float = float(context.get("hero_damage", 0.0))
		var target_hp: float = float(context.get("target_hp", 0.0))
		if target_hp > 0.0 and hero_damage >= target_hp:
			score += 20.0
	else:
		# Still out of reach even with the full jump - a wasted cast.
		score -= 10.0

	# --- Arrow positioning: only a real gain if leaping AWAY actually
	# increases the USABLE travel distance (capped at Sacred Arrow's own
	# current range) - never rewarded just for moving, per the design
	# doc's own "do not blindly reward movement if Arrow damage actually
	# gets worse" instruction. ---
	var arrow_range: int = int(context.get("sacred_arrow_range", 0))
	if arrow_range > 0:
		var current_arrow_distance: int = mini(raw_distance, arrow_range)
		var distance_after_leap_away: int = raw_distance + jump_distance
		var leap_away_arrow_distance: int = mini(distance_after_leap_away, arrow_range)
		if leap_away_arrow_distance > current_arrow_distance:
			var bonus_per_column: float = float(context.get("sacred_arrow_bonus_per_column", 0.0))
			score += float(leap_away_arrow_distance - current_arrow_distance) * bonus_per_column * 0.2

	# --- Defensive value: only under real danger (per the design doc's
	# own "do not use Leap defensively if the offensive value of staying
	# is significantly higher" caution - kept small enough that the
	# offensive branch above still wins outright whenever it applies). ---
	var hp_ratio: float = float(context.get("hero_hp_ratio", 1.0))
	if hp_ratio < 0.20:
		score += 35.0
		if int(context.get("enemy_count", 1)) >= 2:
			score += 25.0
	elif hp_ratio < 0.50:
		score += 20.0

	return score


## Moonlight Shadow: NOT simply an escape ability - defensive protection,
## positioning, a safe approach, AND a guaranteed enhanced next Attack,
## all at once (see the design doc's own explicit framing). "utility"
## category (see this file's own header comment) means every point of
## value here is hero-specific, same "the modifier IS the whole value"
## shape Mirror Image/Guardian Sprint already use.
static func _mirana_moonlight_shadow_modifier(level_data: Dictionary, context: Dictionary) -> float:
	var score: float = 0.0

	var hero_damage: float = float(context.get("hero_damage", 0.0))
	var bonus_pct: float = float(level_data.get("bonus_damage_pct", 0.0))
	var enhanced_damage: float = hero_damage * (1.0 + bonus_pct)
	var bonus_damage: float = enhanced_damage - hero_damage
	var target_hp: float = float(context.get("target_hp", 0.0))
	var target_max_hp: float = float(context.get("target_max_hp", 0.0))

	# --- Offensive value: the guaranteed enhanced next Attack, scaled by
	# the REAL bonus damage it generates - never a flat reading of
	# bonus_damage_pct, same "estimate the actual bonus damage" honesty
	# _slardar_corrosive_haze_modifier() already follows for its own
	# amplification percentage. ---
	score += bonus_damage * 0.3

	if bool(context.get("target_is_hero", false)):
		score += 15.0

	var meaningful_kill: bool = target_hp > 0.0 and hero_damage < target_hp and enhanced_damage >= target_hp
	if meaningful_kill:
		# A kill the enhanced Attack creates that a plain one couldn't -
		# per the design doc's own "a guaranteed kill should strongly
		# increase the score" instruction.
		score += 50.0
	elif target_hp > 0.0 and hero_damage >= target_hp:
		# Already killable outright with a plain Attack - the ultimate's
		# own delayed setup adds nothing here, per the design doc's own
		# explicit "do not use Moonlight Shadow simply to add bonus
		# damage if Mirana can already kill the target safely" caution.
		score -= 45.0

	# --- Approach/reposition value: invisibility lets her safely close
	# in on a target she currently can't reach at all. ---
	var raw_distance: int = int(context.get("target_distance", -1))
	var attack_range: int = int(context.get("hero_attack_range", 0))
	if raw_distance > attack_range:
		score += 15.0

	# --- Starstorm setup: invisibility can carry her safely into the
	# middle of a group - real value, but (per the design doc's own
	# explicit "do not incorrectly apply the bonus damage to Starstorm"
	# instruction) the bonus itself NEVER applies here, only to the next
	# Attack (see this function's own "offensive value" term above and
	# battle.gd's own _apply_hero_attack()/_resolve_enemy_hero_attack(),
	# neither of which ever folds it into a skill cast). ---
	var starstorm_radius: int = int(context.get("starstorm_radius", 0))
	var living_hps: Array = context.get("living_target_hps", [])
	if starstorm_radius > 0 and living_hps.size() >= 2:
		score += 15.0

	# --- Defensive value: significant under real danger, more so while
	# outnumbered - never the reason to cast at full health (per the
	# design doc's own explicit "do not use Moonlight Shadow purely
	# because it is off cooldown" caution). ---
	var hp_ratio: float = float(context.get("hero_hp_ratio", 1.0))
	var enemy_count: int = int(context.get("enemy_count", 1))
	if hp_ratio < 0.20:
		score += 40.0 + minf(float(enemy_count - 1), 3.0) * 8.0
	elif hp_ratio < 0.35:
		score += 20.0

	# --- Opportunity cost: safe, no kill enabled, and the enhanced
	# Attack is a negligible sliver of the target's own max HP - a high-
	# mana ultimate with nothing real to show for itself, per the design
	# doc's own explicit resource-penalty instruction. ---
	if hp_ratio >= 0.70 and not meaningful_kill and (target_max_hp <= 0.0 or bonus_damage < target_max_hp * 0.05):
		score -= 25.0

	return score


## A plain Attack is Mirana's single most important candidate whenever
## Moonlight Shadow is up (it directly consumes and enhances THIS
## action) or the current target is already stunned by her own Sacred
## Arrow - never only the fallback for "nothing else qualified" (see
## basic_attack_participates()'s own docstring for why she opts in at
## all).
static func _mirana_basic_attack_modifier(context: Dictionary) -> float:
	var score: float = 0.0

	var hero_damage: float = float(context.get("hero_damage", 0.0))
	var target_hp: float = float(context.get("target_hp", 0.0))

	var moonlight_active: bool = bool(context.get("moonlight_shadow_active", false))
	var bonus_pct: float = float(context.get("moonlight_shadow_bonus_damage_pct", 0.0)) if moonlight_active else 0.0
	var attack_damage: float = hero_damage * (1.0 + bonus_pct)

	if moonlight_active:
		# Consumes the guaranteed enhanced Attack right now, before it
		# risks going to waste - per the design doc's own "should receive
		# a substantial bonus" instruction.
		score += 35.0

	if target_hp > 0.0 and attack_damage >= target_hp:
		score += 50.0
		if moonlight_active:
			score += 25.0

	if bool(context.get("target_stunned", false)):
		# Sacred Arrow's own follow-up window - see _mirana_sacred_
		# arrow_modifier()'s own matching bonus for the other half.
		score += 15.0

	var max_mana: float = float(context.get("hero_max_mana", 0.0))
	if max_mana > 0.0 and float(context.get("hero_mana", 0.0)) / max_mana < 0.3:
		score += 8.0

	return score


## Luna: aggressive ranged carry, AoE-focused, kill-oriented. Every one
## of her skills leans on context fields battle.gd's/EnemyHeroManager's
## own _build_*_ai_context() compute fresh each turn - "moon_glaives_
## bounces"/"moon_glaives_bounce_damage_pct"/"moon_glaives_bounce_range"/
## "moon_glaives_valid_bounce_targets"/"moon_glaives_bounce_target_hps"
## (Moon Glaives' own current level PLUS the actual, position-computed
## bounce targets available right now - never the skill's own maximum,
## per the design doc's own explicit instruction), "lunar_blessing_
## bonus_pct" (read for transparency/synergy flavor only - "hero_damage"
## itself already has Lunar Blessing folded in by _roll_enemy_hero_
## damage()/_npc_roll_damage(), so nothing here ever adds it a second
## time - see _roll_enemy_hero_damage()'s own docstring), and "eclipse_
## candidate_count"/"eclipse_candidate_hps"/"eclipse_candidate_max_hps"
## (every real beam candidate within Eclipse's own current radius right
## now - the target, its illusions, and its Elderwild Companion all separately,
## mirroring the actual _tick_enemy_eclipse()/_tick_eclipse() candidate
## pool exactly, never just a single "target_hp").
static func _luna_modifier(skill_id: String, level_data: Dictionary, context: Dictionary) -> float:
	match skill_id:
		"lucent_beam":
			return _luna_lucent_beam_modifier(level_data, context)
		"eclipse":
			return _luna_eclipse_modifier(level_data, context)
		BASIC_ATTACK_ID:
			return _luna_basic_attack_modifier(context)
		_:
			return 0.0


## Lucent Beam: Luna's primary single-target active. The generic
## offensive scoring above already covers target value/kill potential
## (fed by this skill's own flat-damage _estimate_skill_damage() case);
## this adds the design doc's own high-threat/stun/follow-up tiers on
## top, reading this level's own actual stun_turns rather than assuming
## a fixed duration. Deliberately does NOT add a flat bonus merely for
## the target being in range - EnemySkillRange's own gate already
## guarantees that before this is ever scored, and the design doc's own
## "do not give a high score merely because a target is in range"
## instruction rules out double-counting it here too.
static func _luna_lucent_beam_modifier(level_data: Dictionary, context: Dictionary) -> float:
	var score: float = 0.0

	var target_hp: float = float(context.get("target_hp", 0.0))
	var target_max_hp: float = float(context.get("target_max_hp", 0.0))
	if target_max_hp > 0.0 and target_hp / target_max_hp < 0.5:
		score += 20.0  # a meaningful target, not just whatever's closest

	if bool(context.get("target_is_hero", false)):
		score += 25.0  # a high-threat target

	var stun_turns: int = int(level_data.get("stun_turns", 0))
	if stun_turns >= 1:
		score += 20.0  # prevents a dangerous enemy action
		score += float(stun_turns - 1) * 10.0  # a 2-turn stun scales control value significantly
		# A stunned single target always creates a safe follow-up Basic
		# Attack here - there's nothing else for it to do back regardless
		# of who lands the next hit (see _luna_basic_attack_modifier()'s
		# own "target_stunned" bonus for the other half of this synergy).
		score += 20.0

	# --- Lucent Beam + Basic Attack: the stun buys a follow-up hit that
	# can secure a kill the beam alone couldn't - the follow-up's own
	# damage already includes Moon Glaives/Lunar Blessing via "hero_
	# damage" (see this function's own docstring), so no separate combo
	# math is needed beyond adding it to the beam's own damage. ---
	var damage: float = float(level_data.get("damage", 0.0))
	var hero_damage: float = float(context.get("hero_damage", 0.0))
	if stun_turns >= 1 and target_hp > 0.0 and damage < target_hp and damage + hero_damage >= target_hp:
		score += 25.0

	return score


## Eclipse: AoE burst, random targeting, multi-beam damage - NEVER simply
## cast whenever available. The current implementation has NO per-enemy
## hit cap (see battle.gd's own _tick_eclipse()/_tick_enemy_eclipse()) -
## with exactly one real candidate within radius, every one of this
## level's own `beams` lands on it, a fully deterministic total; with N
## candidates, the expected share per candidate is beams/N, a genuine
## EXPECTED value, never treated as a guaranteed kill just because the
## raw beams×damage total exceeds someone's HP (per the design doc's own
## explicit caution). `eclipse_candidate_hps`/`_max_hps` are the REAL
## beam candidates within radius right now (the target, its illusions,
## its Elderwild Companion, each counted separately - see this file's own header
## comment), never a synthetic count.
static func _luna_eclipse_modifier(level_data: Dictionary, context: Dictionary) -> float:
	var candidate_hps: Array = context.get("eclipse_candidate_hps", [])
	var candidate_max_hps: Array = context.get("eclipse_candidate_max_hps", candidate_hps)
	var n: int = candidate_hps.size()
	if n <= 0:
		# Nothing within radius at all - a wasted cast, same "out of
		# range scores low" shape every other self-cast AoE ultimate in
		# this file already uses (see _naga_song_of_the_siren_
		# modifier()'s own early-out).
		return -50.0

	var beams: int = int(level_data.get("beams", 0))
	var damage_per_beam: float = float(level_data.get("damage", 0.0))
	var total_expected_damage: float = float(beams) * damage_per_beam
	var per_candidate_expected: float = total_expected_damage / float(n)

	var score: float = 0.0

	# --- Total damage value: real regardless of N, but scaled down
	# modestly since the generic kill-potential term above already
	# credits the PRIMARY target's own expected share of it (see
	# _luna_eclipse_expected_damage()'s own docstring, which feeds that
	# generic term the exact same per-candidate figure this uses). ---
	score += total_expected_damage * 0.08

	# --- Kill potential: the real story here, per the design doc's own
	# explicit emphasis. n==1 is fully deterministic (every beam has
	# nowhere else to go); n>1 only ever gets a probability-weighted
	# EXPECTED kill count, never a guaranteed one just because the raw
	# total clears someone's HP - per the design doc's own explicit "do
	# not label a kill as guaranteed... if multiple enemies can receive
	# the beams" instruction. ---
	var expected_kills: float = 0.0
	var high_value_kill_bonus: float = 0.0
	for i in range(n):
		var hp: float = float(candidate_hps[i])
		if hp <= 0.0:
			continue
		var kill_confidence: float = clampf(total_expected_damage / hp, 0.0, 1.0) if n == 1 else clampf(per_candidate_expected / hp, 0.0, 1.0)
		expected_kills += kill_confidence
		var max_hp: float = float(candidate_max_hps[i]) if i < candidate_max_hps.size() else hp
		if kill_confidence >= 0.9 and max_hp > damage_per_beam * 2.0:
			# A reliable kill against something that actually took real
			# HP to get there, not a target one beam would've dropped
			# anyway (that's already covered by the generic offensive
			# scoring above).
			high_value_kill_bonus += 30.0

	if n == 1 and expected_kills >= 1.0:
		# The single-candidate case: every beam lands here, so this is as
		# close to a guaranteed kill as this file's own random-weighted
		# selection ever gets - per the design doc's own explicit
		# "increase the ultimate score significantly" instruction for
		# exactly this scenario (see Scenario A).
		score += 70.0
	elif expected_kills >= 1.0:
		score += 40.0 * expected_kills
	elif expected_kills >= 0.5:
		score += 20.0
	score += high_value_kill_bonus

	if bool(context.get("target_is_hero", false)):
		score += 25.0

	# --- Multi-target field value: real, but deliberately modest next to
	# the kill-potential terms above - per the design doc's own explicit
	# "3 enemies at full HP should not automatically be valued higher
	# than 1 high-value enemy at low HP" instruction (see Eclipse +
	# grouped enemies). ---
	if n >= 3:
		score += 15.0
	elif n == 2:
		score += 8.0

	return score


## Shared by both _estimate_skill_damage()'s own "eclipse" case (which
## feeds the generic kill-potential term against the primary reference
## target) and _luna_eclipse_modifier() (which needs the same per-
## candidate figure for its own multi-candidate kill-confidence math), so
## the two never drift apart. Returns the EXPECTED damage the primary
## target's own share of the beam total works out to - beams×damage when
## it's the only real candidate in radius (fully deterministic - every
## beam has nowhere else to go), divided across every OTHER real
## candidate (its own illusions, its Elderwild Companion) when they're also
## present, per the design doc's own explicit "do not assume an even
## deterministic distribution" instruction for the multi-target case.
static func _luna_eclipse_expected_damage(level_data: Dictionary, context: Dictionary) -> float:
	var beams: int = int(level_data.get("beams", 0))
	var damage_per_beam: float = float(level_data.get("damage", 0.0))
	var n: int = maxi(int(context.get("eclipse_candidate_count", 1)), 1)
	return float(beams) * damage_per_beam / float(n)


## A plain Attack is one of Luna's most important candidates - Moon
## Glaives/Lunar Blessing make it a real multi-target, passive-boosted
## action in its own right (see basic_attack_participates()'s own
## docstring for why she opts in at all), never only the fallback for
## "nothing else qualified".
static func _luna_basic_attack_modifier(context: Dictionary) -> float:
	var score: float = 0.0

	# Lunar Blessing is already folded into this by _roll_enemy_hero_
	# damage()/_npc_roll_damage() themselves (see this function's own
	# docstring) - never re-added here, per the design doc's own explicit
	# "do not double-count Lunar Blessing" instruction.
	var hero_damage: float = float(context.get("hero_damage", 0.0))
	var target_hp: float = float(context.get("target_hp", 0.0))

	if target_hp > 0.0 and hero_damage >= target_hp:
		score += 50.0

	# --- Moon Glaives: the ACTUAL number of valid bounce targets right
	# now, never the skill's own maximum bounce count - per the design
	# doc's own explicit "do NOT simply add the maximum number of
	# bounces" instruction. ---
	var bounces: int = int(context.get("moon_glaives_bounces", 0))
	var valid_bounce_targets: int = mini(int(context.get("moon_glaives_valid_bounce_targets", 0)), bounces)
	if valid_bounce_targets > 0:
		var bounce_damage_pct: float = float(context.get("moon_glaives_bounce_damage_pct", 0.0))
		var bounce_damage: float = hero_damage * bounce_damage_pct

		if valid_bounce_targets >= 3:
			score += 45.0
		elif valid_bounce_targets == 2:
			score += 30.0
		elif valid_bounce_targets == 1:
			score += 15.0
		# The actual bounce damage total this attack would generate,
		# never assumed at the skill's own maximum.
		score += bounce_damage * float(valid_bounce_targets) * 0.2

		# Secondary kill potential: a bounce landing on an already-weak
		# enemy can finish it off on top of (never instead of) the
		# primary target's own kill - per the design doc's own explicit
		# "do not ignore secondary kills simply because the primary
		# target is the selected target" instruction.
		var bounce_target_hps: Array = context.get("moon_glaives_bounce_target_hps", [])
		var secondary_kills: int = 0
		for hp in bounce_target_hps:
			if bounce_damage >= float(hp) and float(hp) > 0.0:
				secondary_kills += 1
		if secondary_kills >= 1:
			score += 35.0 * float(secondary_kills)

	if bool(context.get("target_stunned", false)):
		# Lucent Beam's own follow-up window - see _luna_lucent_beam_
		# modifier()'s own matching bonus for the other half.
		score += 15.0

	var max_mana: float = float(context.get("hero_max_mana", 0.0))
	if max_mana > 0.0 and float(context.get("hero_mana", 0.0)) / max_mana < 0.3:
		score += 8.0

	return score


# ------------------------------------------------------------------
# Selection: highest score wins outright; scores within
# CLOSE_SCORE_THRESHOLD of each other are resolved by a score-weighted
# random pick (so a close second isn't NEVER picked, but still isn't as
# likely as the leader) rather than a coin flip or a hardcoded order.
# ------------------------------------------------------------------

## `scored` is an Array of {"id": String, "score": float} for every
## candidate skill that survived its caller's own cooldown/mana/worth-
## casting/(range) gates. Returns the chosen skill id, or "" if
## `scored` is empty (caller's own basic-attack fallback takes over).
## `hero_label` is only for the debug print below.
static func pick_best_skill(archetype: String, scored: Array, hero_label: String = "") -> String:
	if scored.is_empty():
		_debug_print(hero_label, scored, "")
		return ""

	var ranked: Array = scored.duplicate()
	ranked.sort_custom(func(a, b): return a["score"] > b["score"])

	var top_score: float = ranked[0]["score"]
	var contenders: Array = []
	for entry in ranked:
		if top_score - entry["score"] <= CLOSE_SCORE_THRESHOLD:
			contenders.append(entry)
		else:
			break

	var chosen_id: String = contenders[0]["id"] if contenders.size() == 1 else _weighted_random_pick(archetype, contenders, top_score)

	_debug_print(hero_label, ranked, chosen_id)
	return chosen_id


## Picks among near-tied `contenders`, weighting each by how close it
## is to the top score - the leader is still the most likely outcome,
## just not the guaranteed one, giving the "controlled randomness" the
## design doc asks for without ever letting a clearly-worse skill beat
## a clearly-better one (those never end up in `contenders` at all).
static func _weighted_random_pick(archetype: String, contenders: Array, top_score: float) -> String:
	var weights: Array = []
	var total_weight: float = 0.0
	for entry in contenders:
		var weight: float = entry["score"] - top_score + CLOSE_SCORE_THRESHOLD + 1.0
		weights.append(weight)
		total_weight += weight

	var roll: float = randf() * total_weight
	var cursor: float = 0.0
	for i in range(contenders.size()):
		cursor += weights[i]
		if roll <= cursor:
			return contenders[i]["id"]

	# Unreachable in practice (the loop above always crosses `roll`
	# before running out) - if float rounding ever gets here, fall back
	# to the hero's own static tie-break order instead of leaving the
	# skill unpicked.
	var tie_break: Array = HERO_TIE_BREAK.get(archetype, [])
	for skill_id in tie_break:
		for entry in contenders:
			if entry["id"] == skill_id:
				return skill_id
	return contenders[0]["id"]


static func _debug_print(hero_label: String, scored: Array, chosen_id: String) -> void:
	if not DEBUG_AI:
		return
	print("AI: %s" % hero_label)
	for entry in scored:
		print("  %s: %.0f" % [entry["id"], entry["score"]])
	print("Selected: %s" % (chosen_id if chosen_id != "" else "(basic attack)"))
