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
# Roar, Borrowed Time, Curse of Avernus, and Tidebringer. All four
# already auto-trigger off HP%/hits-landed outside of any skill-picking
# loop (see battle.gd's _update_enemy_savage_roar_state()/
# _maybe_auto_activate_enemy_borrowed_time()/
# _apply_enemy_curse_of_avernus_stack()/_maybe_consume_enemy_
# tidebringer_stack(), and EnemyHeroManager.gd's own mirrors) - they're
# never "picked", so they have no business being scored candidates.
# Tidebringer's current state DOES still feed into the AI, though - not
# as a candidate of its own, but as an input to how a plain Attack
# itself scores (see BASIC_ATTACK_ID/basic_attack_participates()/
# evaluate_basic_attack() and Kunkka's own "basic_attack" case in
# _kunkka_modifier()), since a Tidebringer-empowered Attack can
# genuinely be the better play than any of Kunkka's real skills.
#
# Six heroes have real AI logic today: Slark, Lone Druid, Abaddon,
# Kunkka, Ancient Apparition, and Winter Wyvern - see
# resolve_hero_archetype() for how a hero_static maps to one of them,
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
# ============================================================

const DEBUG_AI := false

# A skill's starting value before any situational scoring - roughly
# "how good is this in a vacuum," tuned per the hero design doc. These
# are starting points for balancing, not hard rules - the situational
# terms in _evaluate_offensive()/_evaluate_defensive()/
# _evaluate_utility() and each hero's own modifier below can easily
# swing a low-base skill above a high-base one.
const SKILL_INFO := {
	"dark_pact": {"category": "offensive", "base_score": 30.0},
	"pounce": {"category": "offensive", "base_score": 40.0},
	"essence_shift": {"category": "utility", "base_score": 20.0},
	"shadow_dance": {"category": "defensive", "base_score": 50.0},
	"entangle": {"category": "offensive", "base_score": 40.0},
	"summon_spirit_bear": {"category": "utility", "base_score": 50.0},
	"spirit_link": {"category": "defensive", "base_score": 30.0},
	"true_form": {"category": "defensive", "base_score": 45.0},
	"mist_coil": {"category": "offensive", "base_score": 35.0},
	"aphotic_shield": {"category": "defensive", "base_score": 40.0},
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

# Static fallback order, per hero, used ONLY to settle a near-tie (see
# CLOSE_SCORE_THRESHOLD/pick_best_skill()) - never consulted while one
# skill's score clearly beats the rest.
const HERO_TIE_BREAK := {
	"slark": ["pounce", "dark_pact", "shadow_dance", "essence_shift"],
	"lone_druid": ["entangle", "summon_spirit_bear", "spirit_link", "true_form"],
	"abaddon": ["aphotic_shield", "mist_coil"],
	"kunkka": ["ghostship", "torrent", "x_marks_the_spot"],
	"ancient_apparition": ["ice_blast", "chilling_touch", "cold_feet", "ice_vortex"],
	"winter_wyvern": ["winter's_curse", "splinter_blast", "cold_embrace", "arctic_burn"],
}

# Scores within this many points of the top score are treated as
# "close" - see pick_best_skill(). A skill that clearly wins (more than
# this far ahead) is always picked outright.
const CLOSE_SCORE_THRESHOLD := 5.0


## Figures out which of the six heroes with real AI logic today
## `hero_static` is, by checking for a skill only that hero has -
## rather than ever comparing hero ids directly. (Abaddon's own id in
## GameManager.gd is spelled with a Cyrillic "а", not a Latin "a" - see
## its own hero entry - so an id == "abaddon" check would silently
## never match. Every lookup in this file goes through skill ids
## instead, which have no such trap.) Returns "" for any hero without a
## known kit, in which case every hero-specific modifier below is a
## no-op and skills fall back to pure category scoring.
static func resolve_hero_archetype(hero_static: Dictionary) -> String:
	var skill_ids: Array = []
	for skill in hero_static.get("skills", []):
		skill_ids.append(skill.get("id", ""))

	if "pounce" in skill_ids:
		return "slark"
	if "summon_spirit_bear" in skill_ids:
		return "lone_druid"
	if "borrowed_time" in skill_ids:
		return "abaddon"
	if "torrent" in skill_ids:
		return "kunkka"
	if "ice_blast" in skill_ids:
		return "ancient_apparition"
	if "winter's_curse" in skill_ids:
		return "winter_wyvern"
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
## the fallback for "nothing else qualified," exactly as before.
static func basic_attack_participates(archetype: String) -> bool:
	return archetype == "kunkka" or archetype == "winter_wyvern"


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
## finish it off, and - for a true AoE like Dark Pact - extra living
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

	if skill_id == "dark_pact":
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


## Defensive: the steep HP-ratio tiers Shadow Dance's own design calls
## for (big at <20%, less at <35%, a little at <50%, nothing above
## that) - shared by every defensive skill (Aphotic Shield, True Form,
## Spirit Link) rather than reimplemented per hero. Being outnumbered
## adds a small bump on top, but only once a danger tier is already
## active - it must never by itself be enough to make a defensive skill
## outscore offense at full HP (a defensive skill's base_score alone,
## e.g. Shadow Dance's 50, would otherwise already beat a lower-base
## offensive skill with nothing at stake - see the explicit "healthy"
## penalty below, without which Shadow Dance/True Form would fire every
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
		"dark_pact":
			return hero_damage * float(level_data.get("damage_multiplier", 0.75))
		"pounce":
			return hero_damage
		"entangle":
			return float(level_data.get("dot_damage", 0.0)) * float(level_data.get("dot_duration", 0.0))
		"mist_coil", "torrent", "ghostship":
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
		"slark":
			return _slark_modifier(skill_id, level_data, context)
		"lone_druid":
			return _lone_druid_modifier(skill_id, level_data, context)
		"abaddon":
			return _abaddon_modifier(skill_id, level_data, context)
		"kunkka":
			return _kunkka_modifier(skill_id, level_data, context)
		"ancient_apparition":
			return _ancient_apparition_modifier(skill_id, level_data, context)
		"winter_wyvern":
			return _winter_wyvern_modifier(skill_id, level_data, context)
		_:
			return 0.0


## Slark: an aggressive kill-seeker. Pounce gets a further top-up when
## it can personally close out the kill (on top of the generic kill
## bonus every offensive skill already gets), and Essence Shift is more
## attractive when Slark is healthy enough to expect to land the
## follow-up hits it needs to pay off.
static func _slark_modifier(skill_id: String, level_data: Dictionary, context: Dictionary) -> float:
	match skill_id:
		"pounce":
			var target_hp: float = float(context.get("target_hp", 0.0))
			var dmg: float = _estimate_skill_damage(skill_id, level_data, context)
			return 15.0 if (target_hp > 0.0 and dmg >= target_hp) else 0.0
		"essence_shift":
			return 15.0 if float(context.get("hero_hp_ratio", 1.0)) > 0.6 else 0.0
		_:
			return 0.0


## Lone Druid: leans hard on his Spirit Bear. A missing/dead bear is
## treated as a near-emergency (a big enough bonus to beat almost
## everything except a genuine defensive crisis - see
## _evaluate_defensive()'s own <20% HP tier); once the bear is up,
## Entangle/Spirit Link get a small synergy bump instead.
static func _lone_druid_modifier(skill_id: String, level_data: Dictionary, context: Dictionary) -> float:
	var bear_active: bool = bool(context.get("bear_active", false))
	match skill_id:
		"summon_spirit_bear":
			return 0.0 if bear_active else 70.0
		"entangle":
			return 10.0 if bear_active else 0.0
		"spirit_link":
			return 15.0 if bear_active else 0.0
		_:
			return 0.0


## Abaddon: defensive/reactive, not a nuker. He'd rather put Aphotic
## Shield up before things get dangerous than only as a last resort
## (unlike Shadow Dance/True Form's own "wait for real danger" curve),
## and only reaches for Mist Coil's damage when it's actually a
## meaningful hit - otherwise he holds back rather than trading his own
## resources for a marginal poke.
static func _abaddon_modifier(skill_id: String, level_data: Dictionary, context: Dictionary) -> float:
	match skill_id:
		"aphotic_shield":
			return 10.0 if float(context.get("hero_hp_ratio", 1.0)) < 0.7 else 0.0
		"mist_coil":
			var target_hp: float = float(context.get("target_hp", 0.0))
			var dmg: float = _estimate_skill_damage(skill_id, level_data, context)
			return -10.0 if (target_hp > 0.0 and dmg < target_hp * 0.3) else 0.0
		_:
			return 0.0


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
## Target selection: this project's own AoE skills (Dark Pact, Torrent's
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
