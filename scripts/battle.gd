extends Control

@onready var background: TextureRect = $Background
@onready var hero_image: TextureRect = $HeroImage
@onready var enemies_layer: Control = $EnemiesLayer
@onready var hp_bar: ProgressBar = $BarsBox/HPRow/HPBar
@onready var hp_value_label: Label = $BarsBox/HPRow/HPBar/HPValueLabel
@onready var mana_bar: ProgressBar = $BarsBox/ManaRow/ManaBar
@onready var mana_value_label: Label = $BarsBox/ManaRow/ManaBar/ManaValueLabel
@onready var xp_bar: ProgressBar = $BarsBox/XPRow/XPBar
@onready var xp_value_label: Label = $BarsBox/XPRow/XPBar/XPValueLabel
@onready var ice_blast_reserve_overlay: ColorRect = $BarsBox/HPRow/HPBar/IceBlastReserveOverlay
@onready var frost_status_icon: PanelContainer = $BarsBox/HPRow/StatusIconRow/FrostIcon
@onready var curse_status_icon: PanelContainer = $BarsBox/HPRow/StatusIconRow/CurseIcon
@onready var root_status_icon: PanelContainer = $BarsBox/HPRow/StatusIconRow/RootIcon
@onready var ambient_tint_overlay: ColorRect = $AmbientTintOverlay
@onready var cast_flash_overlay: ColorRect = $CastFlashOverlay
@onready var skill_buttons_container: HBoxContainer = $SkillsPanel/SkillsMargin/SkillButtons
@onready var items_grid: GridContainer = $ItemsPanel/ItemsMargin/ItemsVBox/ItemsGrid
@onready var gold_value_label: Label = $ItemsPanel/ItemsMargin/ItemsVBox/GoldRow/GoldValueLabel
@onready var move_left_button: Button = $ActionsPanel/MoveRow/MoveLeftButton
@onready var move_right_button: Button = $ActionsPanel/MoveRow/MoveRightButton
@onready var attack_button: Button = $ActionsPanel/AttackButton
@onready var flee_button: Button = $FleeButton
@onready var defeat_popup: PanelContainer = $DefeatPopup
@onready var defeat_ok_button: Button = $DefeatPopup/DefeatMargin/DefeatVBox/DefeatOkButton
@onready var level_up_popup: PanelContainer = $LevelUpPopup
@onready var level_up_level_label: Label = $LevelUpPopup/LevelUpMargin/LevelUpVBox/LevelUpLevelLabel
@onready var level_up_ok_button: Button = $LevelUpPopup/LevelUpMargin/LevelUpVBox/LevelUpOkButton
@onready var level_up_strength_old: Label = $LevelUpPopup/LevelUpMargin/LevelUpVBox/StatsGrid/StrengthOld
@onready var level_up_strength_new: Label = $LevelUpPopup/LevelUpMargin/LevelUpVBox/StatsGrid/StrengthNew
@onready var level_up_agility_old: Label = $LevelUpPopup/LevelUpMargin/LevelUpVBox/StatsGrid/AgilityOld
@onready var level_up_agility_new: Label = $LevelUpPopup/LevelUpMargin/LevelUpVBox/StatsGrid/AgilityNew
@onready var level_up_intelligence_old: Label = $LevelUpPopup/LevelUpMargin/LevelUpVBox/StatsGrid/IntelligenceOld
@onready var level_up_intelligence_new: Label = $LevelUpPopup/LevelUpMargin/LevelUpVBox/StatsGrid/IntelligenceNew
@onready var level_up_hp_old: Label = $LevelUpPopup/LevelUpMargin/LevelUpVBox/StatsGrid/HPOld
@onready var level_up_hp_new: Label = $LevelUpPopup/LevelUpMargin/LevelUpVBox/StatsGrid/HPNew
@onready var level_up_mana_old: Label = $LevelUpPopup/LevelUpMargin/LevelUpVBox/StatsGrid/ManaOld
@onready var level_up_mana_new: Label = $LevelUpPopup/LevelUpMargin/LevelUpVBox/StatsGrid/ManaNew
@onready var level_up_damage_old: Label = $LevelUpPopup/LevelUpMargin/LevelUpVBox/StatsGrid/DamageOld
@onready var level_up_damage_new: Label = $LevelUpPopup/LevelUpMargin/LevelUpVBox/StatsGrid/DamageNew
@onready var skill_choice_popup: PanelContainer = $SkillChoicePopup
@onready var skill_choice_points_label: Label = $SkillChoicePopup/SkillChoiceMargin/SkillChoiceVBox/SkillChoicePointsLabel
@onready var skill_choice_options: VBoxContainer = $SkillChoicePopup/SkillChoiceMargin/SkillChoiceVBox/SkillChoiceOptions
@onready var skill_choice_desc_popup: PanelContainer = $SkillChoiceDescPopup
@onready var skill_choice_desc_name_label: Label = $SkillChoiceDescPopup/SkillChoiceDescMargin/SkillChoiceDescVBox/SkillChoiceDescNameLabel
@onready var skill_choice_desc_label: Label = $SkillChoiceDescPopup/SkillChoiceDescMargin/SkillChoiceDescVBox/SkillChoiceDescLabel
@onready var skill_choice_desc_ok_button: Button = $SkillChoiceDescPopup/SkillChoiceDescMargin/SkillChoiceDescVBox/SkillChoiceDescButtons/OkButton
@onready var skill_choice_desc_cancel_button: Button = $SkillChoiceDescPopup/SkillChoiceDescMargin/SkillChoiceDescVBox/SkillChoiceDescButtons/CancelButton
@onready var stage_label: Label = $StagePanel/StageMargin/StageLabel

# The battlefield is divided into 10 columns. Movement shifts by one
# column (1/10 screen width); "same space" for attacks/melee means
# matching column index.
const GRID_COLUMNS := 10

# How long a floating status message (_show_message_over_hero()/
# _show_message_over_enemy() - "No enemy in range", "Not enough mana",
# "Stunned!", an enemy's own cast-name banner, etc.) holds still and
# fully readable before it starts floating up and fading out. Previously
# both started the instant the message appeared, so a player barely had
# a moment to read it before it was already fading away.
const MESSAGE_READ_HOLD_DURATION := 1.0

# Tidebringer's proc callout (see _show_rising_message_over()): deep
# blue text, with a light outline so the dark blue stays readable.
const TIDEBRINGER_TEXT_COLOR := Color(0.05, 0.2, 0.8, 1)
const TIDEBRINGER_TEXT_OUTLINE_COLOR := Color(0.85, 0.93, 1, 1)

# Every _start_X_targeting() function marks its valid targets with this
# highlight (see _highlight_valid_targets()) instead of each picking its
# own flat tint - those used to each land somewhere in the same pale,
# desaturated blue range (0.5-0.95 per channel), easy to lose against a
# similarly pale sprite or background. This pushes brightness well past
# 1.0 (an "overbright" modulate, the same trick _pulse_caster_sprite()'s
# own cast-feedback flash already uses) into a warm, saturated gold -
# high contrast against the game's mostly cool/icy palette - and pulses
# continuously between the two values below rather than sitting flat, so
# motion helps draw the eye too.
const TARGET_HIGHLIGHT_COLOR := Color(1.5, 1.2, 0.3, 1)
const TARGET_HIGHLIGHT_PULSE_COLOR := Color(1.9, 1.7, 0.7, 1)

# Moon Glaives' own bounce-hit flash (_flash_bounce_hit()) - same
# "overbright modulate" trick as TARGET_HIGHLIGHT_COLOR/
# _pulse_caster_sprite() above, just pushed toward red instead of gold
# or plain white brightness, so a bounced enemy visibly reads as "just
# got hit" rather than "something happened to it."
const BOUNCE_HIT_FLASH_COLOR := Color(1.8, 0.25, 0.25, 1)

# Entangle's own visuals: the one-shot flash on cast (same overbright
# trick as BOUNCE_HIT_FLASH_COLOR, pushed toward green), and the
# lingering tint for as long as the root holds (see
# _refresh_entangle_tints()). The tint is applied through
# self_modulate rather than modulate, since modulate is already
# owned by the target highlight, hit flashes and stealth fades.
const ENTANGLE_FLASH_COLOR := Color(0.5, 1.8, 0.4, 1)
const ENTANGLE_TINT_COLOR := Color(0.6, 1.0, 0.55, 1)

# Spirit Link's own visual while it's active (see _set_spirit_link_
# visual()): the sprite grows to this scale. The enlarged scale is
# stored as the node's "base_scale" meta, which _pulse_caster_sprite()/
# _flash_bounce_hit() return to instead of a hard-coded Vector2.ONE.
const SPIRIT_LINK_SCALE := 1.1

# Mote colors for _play_drain_effect(): Essence Shift's stolen stats
# in Slark's teal, Spirit Link's lifesteal in red.
const ESSENCE_SHIFT_MOTE_COLOR := Color(0.2, 0.9, 0.8, 1.0)
const SPIRIT_LINK_MOTE_COLOR := Color(1.0, 0.2, 0.15, 1.0)

# Mist Coil's projectile (see _play_mist_coil_effect()): the ball/trail/
# impact-burst color, and the overbright flash the target gets on
# impact (same trick as BOUNCE_HIT_FLASH_COLOR).
const MIST_COIL_COLOR := Color(0.35, 1.0, 0.45, 1.0)
const MIST_COIL_FLASH_COLOR := Color(0.6, 1.8, 0.6, 1)

# Ice Blast's projectile (see _play_ice_blast_effect()): a big pale-ice
# ball with a white rim, the same projectile Mist Coil uses
# (_play_orb_projectile()), just scaled up. Its flash on impact reuses
# COLD_FEET_FLASH_COLOR, and the lingering frost is the same one Cold
# Feet/Ice Vortex use (_refresh_cold_feet_frost()).
const ICE_BLAST_BALL_COLOR := Color(0.6, 0.85, 1.0, 1.0)
const ICE_BLAST_RIM_COLOR := Color(0.95, 0.98, 1.0, 1.0)
const ICE_BLAST_BALL_SIZE := 46.0

# Splinter Blast's visual (see _play_splinter_shards()): an ice
# explosion on the blast's target, then big ice chunks flung from it to
# every unit its splinters hit.
const SPLINTER_SHARD_COLOR := Color(0.75, 0.92, 1.0, 1.0)
const SPLINTER_SHARDS_PER_TARGET := 4
# The explosion on the target (in units of Mist Coil's own impact
# burst - see _play_orb_impact()) and the flung chunks' size in px.
const SPLINTER_EXPLOSION_SCALE := 3.0
const SPLINTER_CHUNK_SIZE := 18.0

# Aphotic Shield's visuals (see _show_aphotic_shell() and friends): the
# translucent shell's fill and rim, the cast flash, and the shard/spark
# color for the cleanse and the shatter. The shell is a child Panel of
# the shielded sprite, named APHOTIC_SHELL_NAME so its presence can be
# looked up.
const APHOTIC_SHELL_FILL_COLOR := Color(0.35, 0.08, 0.55, 0.28)
const APHOTIC_SHELL_RIM_COLOR := Color(0.62, 0.3, 0.95, 0.95)
const APHOTIC_FLASH_COLOR := Color(1.3, 0.6, 1.8, 1)
const APHOTIC_SHARD_COLOR := Color(0.55, 0.2, 0.85, 1.0)
const APHOTIC_SHELL_NAME := "AphoticShell"

# Borrowed Time's visual (see _set_borrowed_time_visual()): a pulsing
# greenish-teal glow over the sprite for as long as it's active. It's
# an additive-blended copy of the sprite itself rather than a change to
# the sprite's own modulate/self_modulate, which the hit flashes,
# stealth fades and Entangle's tint already own.
const BORROWED_TIME_GLOW_COLOR := Color(0.25, 1.0, 0.75, 1.0)
const BORROWED_TIME_GLOW_NAME := "BorrowedTimeGlow"
const BORROWED_TIME_PULSE_SECONDS := 1.1

# Cold Feet's/Ice Vortex's frost on a marked unit (see
# _set_cold_feet_frost()/_play_ice_vortex_swirl()): the
# additive icy sheen over the sprite, the snowflakes, and the one-shot
# flash on cast (same overbright trick as BOUNCE_HIT_FLASH_COLOR). The
# frost is a child node named COLD_FEET_FROST_NAME, so - like Borrowed
# Time's glow - it never touches the sprite's own modulate/
# self_modulate, which the hit flashes and Entangle's tint own.
const COLD_FEET_SHEEN_COLOR := Color(0.35, 0.6, 0.95, 1.0)
const COLD_FEET_FLAKE_COLOR := Color(0.85, 0.95, 1.0, 1.0)
const COLD_FEET_FLASH_COLOR := Color(0.7, 1.3, 1.9, 1)
const COLD_FEET_FROST_NAME := "ColdFeetFrost"

# How long Crystal Nova's frost lingers on everything it hit (see
# _flash_frost_briefly()) - it's a single burst with no DoT to keep the
# frost up, unlike Cold Feet/Ice Vortex/Ice Blast/Frostbite.
const CRYSTAL_NOVA_FROST_SECONDS := 2.5

# Torrent's water spray color (see _play_torrent_splash()).
const TORRENT_SPRAY_COLOR := Color(0.55, 0.8, 1.0, 1.0)

# Same pulsing treatment as TARGET_HIGHLIGHT_COLOR/_PULSE_COLOR above,
# just in green rather than gold - marks the hero's own portrait as a
# valid target for a skill that can be self-cast (right now, only Mist
# Coil - see _highlight_hero_self_target()). Deliberately a different
# hue rather than reusing the gold: for a skill like Mist Coil that can
# be cast on either an enemy in range OR the hero, both highlights can
# be lit and pulsing at the same time, so they need to read as two
# distinct options rather than one ambiguous "the target."
const HERO_TARGET_HIGHLIGHT_COLOR := Color(0.3, 1.7, 0.5, 1)
const HERO_TARGET_HIGHLIGHT_PULSE_COLOR := Color(0.6, 2.0, 0.8, 1)

# Lone Druid's Spirit Bear (summon_spirit_bear) always uses this art,
# regardless of skill level.
const SPIRIT_BEAR_IMAGE_PATH := "res://assets/heroes/Lone Druid Bear.png"
# True Form's transformed portrait, likewise fixed regardless of level.
const TRUE_FORM_IMAGE_PATH := "res://assets/heroes/Lone Druid Ultimate.png"
# How much of the hero's own max HP he loses when the bear dies (see
# _apply_bear_death_penalty()).
const BEAR_DEATH_HP_PENALTY_PCT := 0.2

# Kunkka's Ghostship (see _play_ghostship_animation()) always uses this
# art, regardless of skill level - a purely visual flourish, played
# alongside the instant, already-resolved damage (_resolve_ghostship_
# cast()) rather than gating it.
const GHOSTSHIP_IMAGE_PATH := "res://assets/heroes skills/Kunkka_Ghostship.png"
# How long the ship's flight from Kunkka's column to the target's takes
# to visually cross the screen.
const GHOSTSHIP_TRAVEL_DURATION := 0.6

# Timbersaw's Chakram (see _resolve_chakram_cast()) always uses this
# art, regardless of skill level - drawn at half the usual creature
# height, since it's a planted marker rather than a combatant.
const CHAKRAM_IMAGE_PATH := "res://assets/heroes skills/Timbersaw_Chakram.png"

# Naga Siren's Mirror Image (see _spawn_illusion_node()) fades every
# illusion's copy of the hero's own portrait to this alpha, so the real
# hero still reads clearly among his own decoys.
const HERO_ILLUSION_ALPHA := 0.45

# Winter Wyvern's Cold Embrace (see _activate_cold_embrace()) always
# uses this art for the hero's portrait while it's active, regardless
# of skill level - reverted back to the hero's own normal image
# (_hero_static.image) once it ends (see _end_cold_embrace()).
const COLD_EMBRACE_IMAGE_PATH := "res://assets/heroes skills/Winter_Wyvern_Cold_Embrace.png"

# Tusk's Snowball (see _resolve_snowball_cast()) shows this art for the
# hero's portrait while he's charging across the board, reverted back
# to his own normal image once he lands on the target (see
# _end_snowball_animation()) - a purely visual flourish, same "instant,
# already-resolved damage, cosmetic animation on top" split Ghostship's
# own travel already uses.
const SNOWBALL_IMAGE_PATH := "res://assets/heroes skills/Tusk_Snowball.png"
# How long the charge takes to visually cross the screen.
const SNOWBALL_TRAVEL_DURATION := 0.4

# Luna's Lucent Beam (see _play_lucent_beam_impact()) has no dedicated
# art asset, unlike the skills above - drawn instead as a plain pale
# moonlight-colored ColorRect that grows downward from above the target
# onto it, purely cosmetic and played alongside the instant,
# already-resolved damage (_resolve_lucent_beam_cast()) rather than
# gating it, same split as Ghostship's/Snowball's own animation above.
const LUCENT_BEAM_COLOR := Color(1.5, 1.6, 2.0, 0.85)
const LUCENT_BEAM_WIDTH := 14.0
const LUCENT_BEAM_FALL_HEIGHT := 220.0
const LUCENT_BEAM_FALL_DURATION := 0.16

# Mirana's Sacred Arrow (see _play_sacred_arrow_flight()) - same "no
# dedicated art asset, plain cosmetic ColorRect played alongside the
# already-resolved instant damage" shape as Lucent Beam just above, but
# deliberately varied in a few ways so the two don't read as the same
# effect recolored: light blue instead of pale white, a short streak
# that FLIES HORIZONTALLY in from the hero's own position rather than
# growing straight down out of the sky onto the target, and a flight
# time that scales with the shot's own distance (SACRED_ARROW_BASE_
# DURATION + SACRED_ARROW_DURATION_PER_COLUMN per column travelled) -
# echoing the skill's own "more damage the further it travels" identity
# - instead of Lucent Beam's fixed fall duration.
const SACRED_ARROW_COLOR := Color(0.65, 1.3, 1.9, 0.9)
const SACRED_ARROW_HEIGHT := 10.0
const SACRED_ARROW_LENGTH := 46.0
const SACRED_ARROW_BASE_DURATION := 0.12
const SACRED_ARROW_DURATION_PER_COLUMN := 0.025

# Tusk's Walrus Punch (see _resolve_walrus_punch_cast()) deliberately
# flips Snowball's/Ghostship's own "instant, already-resolved outcome,
# cosmetic animation layered on top" split: the knockback slide plays
# FIRST, then damage/death/stun are only resolved once it finishes (see
# _resolve_walrus_punch_damage()) - so a lethal punch still visibly
# sends the target flying before it drops, instead of it just vanishing
# on the spot mid-hit.
const WALRUS_PUNCH_KNOCKBACK_DURATION := 0.35

var _hero_static: Dictionary = {}   # full definition from GameManager (stats, skills, image)
var _recruited: Dictionary = {}     # saved state from PlayerManager (current hp/mana/xp, chosen skill)

var _hero_pos_index: int = 1

# Each entry: {static, current_hp, current_main_stat_value, pos_index, node}
var _enemies: Array = []

# Turn state: exactly one action - move, attack, skill, or item - per
# turn, then the turn ends automatically (see _mark_turn_used()).
var _has_acted_this_turn: bool = false
var _battle_over: bool = false

# skill_id -> that skill's Button, for every LEARNED skill (level > 0).
# _update_action_buttons() toggles all of them with the turn; unlearned
# skills' buttons stay permanently disabled and aren't tracked here.
var _skill_buttons: Dictionary = {}

# skill_id -> turns remaining before it can be used again (0 = ready).
# Ticks down once per End Turn - see _tick_skill_cooldowns().
var _skill_cooldowns: Dictionary = {}
# skill_id -> the Label under that skill's button showing "Ready" or
# "N turns left".
var _skill_cooldown_labels: Dictionary = {}

# The skill_id currently shown in the level-up skill-choice
# description popup, awaiting OK/Cancel - not yet spent on.
var _pending_level_up_skill_id: String = ""

# ------------------------------------------------------------------
# Slark's Essence Shift: while active, Slark's next
# _essence_shift_attacks_remaining melee hits each steal 1 point of
# the target's main stat (see _apply_essence_shift_steal()). All
# currently-borrowed stats are handed back - to whichever donor
# enemies are still alive - together, once
# _essence_shift_turns_remaining counts down to 0 (see
# _tick_essence_shift() / _end_essence_shift()).
# ------------------------------------------------------------------
var _essence_shift_active: bool = false
var _essence_shift_attacks_remaining: int = 0
var _essence_shift_turns_remaining: int = 0
# True from the moment the skill is cast until the first End Turn
# after that - the casting turn itself doesn't count against the
# duration, so this makes _tick_essence_shift() skip exactly one
# decrement before duration starts counting down for real.
var _essence_shift_duration_pending_start: bool = false
# Every point currently borrowed, so it can be handed back on expiry:
# each entry is {enemy: Dictionary (that enemy's own _enemies entry),
# stat: String, amount: int}.
var _essence_shift_stolen: Array = []
# Running total of the borrowed stats currently added to Slark -
# purely a battle-local calculation/display modifier (see
# _roll_hero_damage(), _hero_armor(), _refresh_bars()). Never written
# to PlayerManager, so it naturally has no effect outside this fight.
var _essence_shift_bonus: Dictionary = {"damage": 0.0, "hp": 0.0, "mana": 0.0, "armor": 0.0}

# ------------------------------------------------------------------
# Slark's Shadow Dance: while active, the hero is hidden (see
# _is_hero_hidden()) - regular enemy attacks can't land on him at all
# (see _enemy_turn()). His next Attack while hidden adds
# _shadow_dance_bonus_damage on top of the normal roll (still mitigated
# by the target's armor same as any other damage) and ends the
# invisibility right there; casting any OTHER skill also ends it
# early with no bonus damage; using an item does not. Otherwise it
# just runs out on its own after _shadow_dance_turns_remaining turns.
# ------------------------------------------------------------------
var _shadow_dance_active: bool = false
var _shadow_dance_bonus_damage: float = 0.0
var _shadow_dance_turns_remaining: int = 0
# Same "doesn't count on the casting turn" behavior as Essence Shift's
# duration - see _essence_shift_duration_pending_start.
var _shadow_dance_duration_pending_start: bool = false

# ------------------------------------------------------------------
# Treant Protector's Nature's Guise: functionally the same invisibility
# as Slark's own Shadow Dance - folded into the very same _is_hero_
# hidden() check, so every "enemies can't target or chase a hidden
# hero" rule in _enemy_turn() already applies here for free - just with
# a different payoff for the Attack that breaks it: instead of bonus
# damage, the target gets rooted (root_turns_left, the same shared
# per-enemy field Entangle's own root uses and _tick_enemy_turn_start_
# effects() already ticks down - it can still attack/cast/use items while rooted,
# same as any other rooted enemy) for _natures_guise_root_turns turns.
# Casting any OTHER skill still just ends it early with no root, same
# as Shadow Dance's own "no bonus damage" rule for that case. While
# active, the hero also moves a flat +1 column further per move (see
# _hero_move_distance()) - moving unseen covers more ground.
# ------------------------------------------------------------------
var _natures_guise_active: bool = false
var _natures_guise_root_turns: int = 0
var _natures_guise_turns_remaining: int = 0
var _natures_guise_duration_pending_start: bool = false

# ------------------------------------------------------------------
# Mirana's ultimate, Moonlight Shadow: functionally the same
# invisibility as Slark's own Shadow Dance - folded into the very same
# _is_hero_hidden() check, so every "enemies can't target or chase a
# hidden hero" rule in _enemy_turn() already applies here for free, and
# the same bonus-damage-on-breaking-Attack payoff too, just as a
# PERCENTAGE of the attack's own rolled damage (bonus_damage_pct,
# applied AFTER the roll) rather than Shadow Dance's own flat pre-roll
# bonus_damage - see _apply_hero_attack()'s own read of whichever of
# the two is actually active (only one hero's kit ever has either, but
# each still gets its own flag/fields rather than reusing Shadow
# Dance's, same reasoning Nature's Guise's own separate flag above
# already follows). Casting any OTHER skill still just ends it early
# with no bonus damage, same as Shadow Dance's own rule for that case.
# ------------------------------------------------------------------
var _moonlight_shadow_active: bool = false
var _moonlight_shadow_bonus_damage_pct: float = 0.0
var _moonlight_shadow_turns_remaining: int = 0
var _moonlight_shadow_duration_pending_start: bool = false

# ------------------------------------------------------------------
# Treant Protector's Living Armor: a self-cast that adds a flat
# bonus_armor (folded into _hero_armor(), same slot Spirit Link's own
# bonus armor uses) plus a flat bonus_hp_regen healed every turn on top
# of the hero's own baseline passive regen (_apply_passive_hero_regen()
# - same "bonus stacks on top of the baseline" relationship Arcane
# Aura's own regen already has) for the duration. Same "casting turn
# doesn't count" pattern as every other duration-based buff (see
# _tick_living_armor()).
# ------------------------------------------------------------------
var _living_armor_active: bool = false
var _living_armor_bonus_armor: float = 0.0
var _living_armor_bonus_hp_regen: float = 0.0
var _living_armor_turns_remaining: int = 0
var _living_armor_duration_pending_start: bool = false

# ------------------------------------------------------------------
# Slardar's Guardian Sprint: a self-cast that arms this level's own
# bonus_movement/charge_damage_pct for `level_data.duration` turns -
# doesn't move the hero itself (casting just consumes the turn like any
# other self-buff), it only changes what his NEXT normal moves do (see
# _hero_move()'s own read of _guardian_sprint_turns_remaining). While
# active, a move adds bonus_movement to the usual distance AND always
# stops on the first enemy in its path (the melee "stop on top of an
# enemy" rule _melee_move_target() already uses, applied here
# regardless of range_type), dealing charge_damage_pct of a freshly-
# rolled hero Attack to whatever it stopped on - no stun, just the hit.
# Same "casting turn doesn't count" pattern as every other duration-
# based buff (see _tick_guardian_sprint()).
# ------------------------------------------------------------------
var _guardian_sprint_turns_remaining: int = 0
var _guardian_sprint_bonus_movement: int = 0
var _guardian_sprint_charge_damage_pct: float = 0.0
var _guardian_sprint_duration_pending_start: bool = false

# ------------------------------------------------------------------
# Timbersaw's Reactive Armor: a passive - no cast, no cooldown/mana
# spend of its own. Every hit the hero takes (see apply_damage())
# earns one stack, each with its OWN independent turns-remaining
# counter (unlike every other duration-based buff above, which only
# ever tracks one shared timer for the whole effect) so stacks fall
# off individually rather than all at once. Gaining a stack past this
# level's own max_stacks drops the oldest one first, same as it being
# replaced. Folds bonus_armor_per_stack * stack count into _hero_armor()
# (same slot Living Armor's/Spirit Link's own bonus armor use) and
# heals bonus_hp_regen_per_stack * stack count every hero turn
# (_apply_reactive_armor_regen(), same timing/stacking relationship as
# Arcane Aura's/the baseline passive regen).
# ------------------------------------------------------------------
var _reactive_armor_stack_turns: Array[int] = []

# ------------------------------------------------------------------
# Winter Wyvern's Arctic Burn: while active, the hero's plain Attacks
# get a flat bonus_damage (folded into _roll_hero_damage(), same slot
# Essence Shift's/Shadow Dance's/True Form's own bonus damage use) and
# extra reach (folded into _hero_attack_column_range(), so ranged
# targeting opens further out too), for this level's own `attacks`
# count of Attacks or `duration` turns - whichever runs out first, same
# two-limits race as Essence Shift's attacks_remaining/turns_remaining
# (see _apply_arctic_burn_attack()/_tick_arctic_burn()). Recasting
# while a previous activation is still running just overwrites it
# outright - there's nothing borrowed to give back first, unlike
# Essence Shift.
# ------------------------------------------------------------------
var _arctic_burn_active: bool = false
var _arctic_burn_bonus_damage: float = 0.0
var _arctic_burn_bonus_range: int = 0
var _arctic_burn_attacks_remaining: int = 0
var _arctic_burn_turns_remaining: int = 0
var _arctic_burn_duration_pending_start: bool = false

# ------------------------------------------------------------------
# Winter Wyvern's Cold Embrace: a defensive self-cast that swaps the
# hero's portrait to COLD_EMBRACE_IMAGE_PATH, makes him fully immune to
# damage (see apply_damage()), heals him once per turn, and locks out
# EVERY other action - move, attack, skill, or item (see _hero_move()/
# _on_attack_pressed()/_on_skill_pressed()/_on_item_pressed()) - for the
# duration, same "casting turn doesn't count" pattern as every other
# buff (see _tick_cold_embrace()). With no action possible, the turn
# auto-skips straight through to the next one (_end_turn()'s own tail),
# the same way a stunned turn does. Casting it also dispels every OTHER
# effect currently on the hero, good or bad, before establishing itself
# (see _dispel_all_hero_effects(), called from _activate_cold_embrace()).
# ------------------------------------------------------------------
var _cold_embrace_active: bool = false
var _cold_embrace_heal_per_turn: float = 0.0
var _cold_embrace_turns_remaining: int = 0
var _cold_embrace_duration_pending_start: bool = false

# ------------------------------------------------------------------
# Snapfire's ultimate, Mortimer Kisses: a targeted channel, not a
# self-cast buff like Cold Embrace above, but locked out the same way -
# move, attack, skill, and item are all disabled for its whole
# duration (same 7 check sites Cold Embrace already touches: _populate_
# item_grid(), _on_item_pressed(), _on_skill_pressed(), _hero_move(),
# _on_attack_pressed(), _update_action_buttons(), _apply_tutorial_
# gate()). Unlike Cold Embrace, an unable-to-act turn here doesn't just
# skip - it AUTO-FIRES one shot instead, from _end_turn()'s own tail
# (see the block right before it reopens the action buttons), for
# level_data.hits total shots counting the cast turn's own immediate
# one (_resolve_mortimer_kisses_cast() fires that first one directly;
# _mortimer_kisses_turns_left only tracks the REMAINING auto-fired
# ones). _mortimer_marked_enemy is a live Dictionary reference into
# _enemies - reading its own "pos_index" tracks it turn to turn while
# it's alive, and keeps returning wherever it died once it isn't (see
# _fire_mortimer_kisses_shot()'s own comment - _kill_enemy() only ever
# removes a dead enemy from the _enemies array, it never mutates the
# Dictionary's own fields).
# ------------------------------------------------------------------
var _mortimer_kisses_active: bool = false
var _mortimer_kisses_turns_left: int = 0
var _mortimer_marked_enemy: Dictionary = {}
var _mortimer_kisses_level_data: Dictionary = {}

# ------------------------------------------------------------------
# Naga Siren's Mirror Image: a self-cast that spawns this level's own
# `illusions` count (always 3) of decoys, one in the column immediately
# in front of the hero, one immediately behind, and a third doubling up
# randomly on whichever of those two columns (see _activate_mirror_
# image()) - each a Dictionary of {pos_index, current_hp, max_hp, node}
# in `_illusions`, own HP pool sized off `hp_pct` of the hero's own max
# HP. While any are up, apply_damage() (every hit that would otherwise
# land on the hero, from any source) rolls `hit_chance_pct` to redirect
# the ENTIRE hit onto a random living illusion instead - a full
# redirect, not a split, and completely bypassing the hero's own
# defensive mechanics (Reactive Armor stacks, Borrowed Time, Aphotic
# Shield) since nothing actually touched him this time. Every hero turn
# that isn't the casting one, every surviving illusion also strikes the
# SAME randomly-picked living enemy within the hero's own attack range
# for `damage_pct` of a freshly-rolled hero Attack each (see
# _fire_mirror_image_attack(), called from _tick_mirror_image()) - same
# "casting turn doesn't count" pattern as every other duration-based
# buff. Ends (despawning every surviving illusion) once the duration
# runs out; recasting mid-duration replaces the set outright, same as
# Living Armor/Chakram's own "recast overwrites" reasoning.
# ------------------------------------------------------------------
var _illusions: Array = []
var _illusion_damage_pct: float = 0.0
var _illusion_hit_chance_pct: float = 0.0
var _illusions_turns_remaining: int = 0
var _illusions_duration_pending_start: bool = false

# ------------------------------------------------------------------
# Winter Wyvern's ultimate, Winter's Curse: freezes a target enemy
# (target["stun_turns_left"], same shared per-enemy field Torrent's/
# Ice Blast's own stun already uses) for `level_data.duration` of its
# own turns. There's no separate duration counter for the "nearby
# enemies pile onto it instead of the hero" half of the effect either -
# _is_winters_curse_active() derives it straight from that same stun
# counter, so both halves always wear off together. _enemy_turn()
# captures whether the curse is active once at the very top of each
# full enemy-turn pass (see its own `curse_active`/`curse_target_pos`
# locals) rather than re-checking per enemy, so every enemy this turn
# sees the same answer even though the target's own stun_turns_left
# ticks down partway through that same pass.
# ------------------------------------------------------------------
var _winter_curse_target: Dictionary = {}
var _winter_curse_bonus_damage_pct: float = 0.0
var _winter_curse_range: int = 0

# ------------------------------------------------------------------
# Crystal Maiden's ultimate, Freezing Field: a self-cast that deals
# this level's own damage to every enemy within radius columns of the
# hero's CURRENT position (re-checked fresh every tick, not fixed at
# cast time - so it follows him if he moves) at the start of every
# turn for the duration, same "casting turn doesn't count" pattern as
# every other buff (see _tick_freezing_field()).
# ------------------------------------------------------------------
var _freezing_field_active: bool = false
var _freezing_field_damage_per_turn: float = 0.0
var _freezing_field_radius: int = 0
var _freezing_field_turns_remaining: int = 0
var _freezing_field_duration_pending_start: bool = false

# ------------------------------------------------------------------
# Luna's ultimate, Eclipse: a self-cast that, at the start of every turn
# for as long as beams remain, fires ECLIPSE_BEAMS_PER_TURN beams (or
# however many are left, if fewer) at random living, targetable enemies
# within radius columns of the hero's CURRENT position (re-checked
# fresh every tick, same as Freezing Field's own radius above - so it
# follows her if she moves), each for this level's own damage. Ends the
# instant every beam has landed, rather than running a fixed number of
# turns like Freezing Field's own duration does. Same "casting turn
# doesn't count" pattern as every other buff (see _tick_eclipse()).
# ------------------------------------------------------------------
var _eclipse_active: bool = false
var _eclipse_damage_per_beam: float = 0.0
var _eclipse_radius: int = 0
var _eclipse_beams_remaining: int = 0
var _eclipse_duration_pending_start: bool = false

# ------------------------------------------------------------------
# Timbersaw's ultimate, Chakram: a targeted cast that deals this
# level's own cast_damage to the target and every enemy within radius
# columns of the target's position AT CAST TIME, then plants a marker
# there - fixed at that snapshot, unlike Freezing Field's own
# hero-centered radius above, which re-checks the hero's current
# position every tick - dealing damage_per_turn to every enemy within
# radius columns of that FIXED spot at the start of every turn for the
# duration (same "casting turn doesn't count" pattern as every other
# duration-based buff). Empty dictionary means no chakram is currently
# planted; see _resolve_chakram_cast()/_tick_chakram()/
# _despawn_chakram().
# ------------------------------------------------------------------
var _chakram: Dictionary = {}

# ------------------------------------------------------------------
# Tusk's Ice Shards: on cast, deals a straight instant hit to the
# target, then walls off a line of columns - starting on the hero's OWN
# column and continuing toward the target, `blocked_columns` of them
# total - for the duration (see _is_column_ice_shards_blocked(),
# checked from every plain-movement decision in _enemy_turn()/
# _enemy_hero_turn()). Fixed at cast time, unlike Freezing Field's own
# radius - the wall doesn't follow the hero if he moves afterward.
# Recasting while a previous wall is still up simply replaces it
# outright - there's nothing to give back, same as Arctic Burn/Winter's
# Curse.
# ------------------------------------------------------------------
var _ice_shards_active: bool = false
var _ice_shards_blocked_columns: Array[int] = []
var _ice_shards_turns_remaining: int = 0
var _ice_shards_duration_pending_start: bool = false

const ICE_SHARDS_WALL_IMAGE_PATH := "res://assets/heroes skills/Tusk_ice_shards.png"

# One TextureRect per currently-walled column (either side's - both use
# the same visual), rebuilt from scratch by _refresh_ice_shards_visuals()
# every time either side's own blocked-columns list changes, rather
# than tracked per-side - a column blocked by both at once (rare, but
# possible if both the player and a rival Tusk have one up) would
# otherwise need de-duplicating twice over.
var _ice_shards_wall_nodes: Array[TextureRect] = []

# ------------------------------------------------------------------
# Tusk's Tag Team: a self-cast that adds a flat bonus_damage to the
# hero's own Attacks (folded into _roll_hero_damage(), same slot
# Arctic Burn's/Essence Shift's/True Form's own bonus damage use) for
# the duration - no attack-count cap, unlike Arctic Burn, just a plain
# turn-based buff. Same "casting turn doesn't count" pattern as every
# other duration-based buff (see _tick_tag_team()).
# ------------------------------------------------------------------
var _tag_team_active: bool = false
var _tag_team_bonus_damage: float = 0.0
var _tag_team_turns_remaining: int = 0
var _tag_team_duration_pending_start: bool = false

# ------------------------------------------------------------------
# Lone Druid's Spirit Bear (summon_spirit_bear): a persistent ally
# that fights alongside the hero. {} when no bear is out (see
# _is_bear_alive()); otherwise {hp, current_hp, damage_min,
# damage_max, armor, speed, pos_index, node}. It lives outside
# _enemies/enemies_layer entirely, so stage transitions - which only
# clear those - leave it untouched (see _load_enemies(),
# _start_hero_fight()); it's only ever removed by _despawn_bear()
# (recasting the skill, or the hero fleeing the scene entirely) or by
# _kill_bear() (an enemy brings its HP to 0 - notably not the same
# path as _kill_enemy(), so it never grants XP/gold - though it does
# cost the hero HP of his own, see _apply_bear_death_penalty()).
# ------------------------------------------------------------------
var _bear: Dictionary = {}

# The rival hero's single-target skills that can be aimed at the
# player's Spirit Bear instead of the player himself - see
# _choose_enemy_skill_on_bear() for how the AI picks between the two,
# and each skill's own _cast_enemy_*_on_bear() for what it does to the
# bear. Skills left out are either about the player's own position
# (X Marks the Spot, Ghostship/Timber Chain's line, Chakram's/Ice
# Shards' placement, Mortimer Kisses' channel, Crystal Nova's area) or
# not targeted at all; those still reach the bear through their own
# AoE collateral, same as before.
const ENEMY_BEAR_TARGETABLE_SKILLS: Array[String] = [
	"entangle", "mist_coil", "torrent", "corrosive_haze", "sacred_arrow",
	"lucent_beam", "ensnare", "cold_feet", "ice_vortex", "chilling_touch",
	"ice_blast", "splinter_blast", "winter's_curse", "frostbite", "snowball",
	"walrus_punch", "leech_seed", "lil_shredder",
]

# Set by _cast_enemy_skill() for the duration of one cast: true when
# the rival's current skill is aimed at the player's Spirit Bear rather
# than the player (see _choose_enemy_skill_on_bear()). Each bear-
# targetable _cast_enemy_*() checks it first and hands off to its own
# _cast_enemy_*_on_bear() counterpart.
var _enemy_skill_on_bear: bool = false

# Set by _cast_enemy_skill() for the duration of one cast: true when the
# rival's current Mist Coil is aimed at himself (the self-heal - see
# EnemySkillAI.MIST_COIL_SELF_ID) rather than at the player or his bear.
var _enemy_mist_coil_self: bool = false

# Whether the player is hidden from the rival for the turn being
# decided right now (see _enemy_hero_turn()) - lets the skill picker
# still consider the bear as a target while the player himself can't
# be seen.
var _enemy_ai_hero_hidden: bool = false

# ------------------------------------------------------------------
# Lone Druid's Spirit Link: while active, the hero gets a flat armor
# bonus (folded into _hero_armor(), same slot Essence Shift's borrowed
# armor uses) and lifesteal on his Attacks - a % of an Attack's
# damage, taken AFTER the target's armor has already reduced it, paid
# back as HP (see _apply_spirit_link_lifesteal(), called only from
# _apply_hero_attack() - skill damage never triggers it). Same
# "casting turn doesn't count" duration pattern as Essence Shift/
# Shadow Dance. Recasting simply overwrites the running values with
# the new cast's - there's nothing to "give back" the way Essence
# Shift's borrowed stats are, so no need to end the old one first.
# ------------------------------------------------------------------
var _spirit_link_active: bool = false
var _spirit_link_lifesteal_pct: float = 0.0
var _spirit_link_bonus_armor: float = 0.0
var _spirit_link_turns_remaining: int = 0
var _spirit_link_duration_pending_start: bool = false

# ------------------------------------------------------------------
# Lone Druid's Savage Roar: a passive (no button press, no mana, no
# cooldown - see _populate_skill_buttons()'s "passive" branch) that
# turns itself on and off automatically based on the hero's own HP%,
# recalculated every time the bars refresh (_update_savage_roar_state,
# called from _refresh_bars()). Uses hysteresis rather than a single
# threshold - see _update_savage_roar_state() - so it doesn't flicker
# on/off turn to turn while HP hovers in the 50-80% band. While
# active, both _hero_move_distance() and incoming damage on the hero
# (apply_damage()) AND the bear (_deal_damage_to_bear()) read the
# bonus movement/damage reduction below; while inactive they're 0, so
# nothing extra needs to be undone when it turns off.
# ------------------------------------------------------------------
var _savage_roar_active: bool = false
var _savage_roar_bonus_movement: int = 0
var _savage_roar_damage_reduction_pct: float = 0.0
# The skill button slot's status label ("Passive"/"Active"/
# "Inactive"), captured when _populate_skill_buttons() builds it, so
# _update_savage_roar_state() can keep it current live.
var _savage_roar_status_label: Label = null

# ------------------------------------------------------------------
# Lone Druid's ultimate, True Form: transforms the hero into a bear
# for the duration - swaps his portrait to TRUE_FORM_IMAGE_PATH (and
# back to his normal one on expiry), grants bonus max HP (added to his
# CURRENT HP too the moment it's granted, then taken back off again on
# expiry, clamped so it can never do that part below 1 - see
# _activate_true_form()/_end_true_form()), bonus damage (folded into
# _roll_hero_damage() the same way Essence Shift's/Shadow Dance's
# bonus damage is), and forces melee range for the duration regardless
# of his own range_type stat (see _is_ranged_hero()) - so if he's
# normally ranged, Attack just resolves as a melee hit on whatever
# shares his own column instead of opening ranged targeting. Same
# "casting turn doesn't count" duration pattern as the other buffs.
# ------------------------------------------------------------------
var _true_form_active: bool = false
var _true_form_bonus_hp: float = 0.0
var _true_form_bonus_damage: float = 0.0
var _true_form_turns_remaining: int = 0
var _true_form_duration_pending_start: bool = false

# ------------------------------------------------------------------
# Abaddon's Aphotic Shield: a self-cast shield with its own HP pool
# that absorbs incoming damage in the hero's place (see
# apply_damage()) until either its duration runs out (fades quietly,
# see _tick_aphotic_shield()) or enough damage drains it to 0 (see
# apply_damage()/_end_aphotic_shield()) - in which case it explodes,
# dealing _aphotic_shield_aoe_damage to every enemy within
# _aphotic_shield_radius columns of the hero, the same radius-around-
# a-position AoE concept Dark Pact uses (_cast_dark_pact()). Casting
# it also dispels every negative effect currently on the player - root,
# a hostile Entangle's damage-over-time, Pounce's stun, and a hostile
# Essence Shift's stat drain (see _activate_aphotic_shield()) - except
# silence, since _on_skill_pressed() already refuses to cast ANY skill
# while silenced, so that debuff can never still be active by the time
# this one goes off.
# ------------------------------------------------------------------
var _aphotic_shield_active: bool = false
var _aphotic_shield_hp: float = 0.0
var _aphotic_shield_aoe_damage: float = 0.0
var _aphotic_shield_radius: int = 0
var _aphotic_shield_turns_remaining: int = 0
var _aphotic_shield_duration_pending_start: bool = false

# ------------------------------------------------------------------
# Abaddon's Borrowed Time: not cast at all - it auto-activates once
# the hero's own HP falls to or below a level-based threshold (see
# apply_damage()/_maybe_auto_activate_borrowed_time()), then for its
# duration every attack that would otherwise damage the hero heals him
# instead (a full reversal, not just a reduction - see apply_damage()
# again). Its cooldown reuses the same generic _skill_cooldowns/
# _skill_cooldown_labels tracking every manually-cast skill uses (see
# _populate_skill_buttons()'s "auto_activate" branch), started the
# moment it auto-activates rather than by a button press.
# ------------------------------------------------------------------
var _borrowed_time_active: bool = false
var _borrowed_time_heal_conversion_pct: float = 0.0
var _borrowed_time_turns_remaining: int = 0
var _borrowed_time_duration_pending_start: bool = false

# Kunkka's Tidebringer: a passive counter of plain Attacks landed (see
# _maybe_consume_tidebringer_stack(), called from _apply_hero_attack())
# - never reset by a turn going by without attacking, only by another
# empowered hit consuming it once this level's own hits_to_activate is
# reached. No duration, no on/off state to track - unlike every buff
# above, so just the one counter.
var _tidebringer_attack_count: int = 0

# Slardar's Bash of the Deep - same "count plain Attacks toward a
# threshold, consume them all once reached" idiom as Tidebringer's own
# counter just above (see _maybe_consume_bash_of_the_deep_stack(),
# called from _apply_hero_attack()).
var _bash_of_the_deep_attack_count: int = 0

# ------------------------------------------------------------------
# A rival hero's own skills, during a hero fight (_in_hero_fight) -
# see _enemy_hero_turn()/_cast_enemy_skill() and everything below it.
# This is the enemy-side mirror of the block above: same skills, same
# mechanics, just cast by the boss at the player instead of by the
# player at his enemies. Reset fresh for each new hero fight by
# _reset_enemy_hero_state() (called from _start_hero_fight()), since
# nothing here should carry over from a previously-fought rival.
# ------------------------------------------------------------------

# The full hero definition (stats, skills) of whichever rival is
# currently being fought - "" is a full hero_static.get("id","") away
# for _enemy_hero_id, the more commonly needed value. Both are {}/""
# outside a hero fight.
var _enemy_hero_static: Dictionary = {}
var _enemy_hero_id: String = ""

var _enemy_max_mana: float = 0.0
var _enemy_current_mana: float = 0.0

# The rival's Health/Mana Potions for this fight - seeded from whatever
# PlayerManager.get_npc_potion_count() says they've actually got banked
# (see _reset_enemy_hero_state()), same as their skill levels are read
# live from PlayerManager rather than reset to some fixed loadout. Each
# drink (_drink_enemy_health_potion()/_drink_enemy_mana_potion()) writes
# the new count straight back to PlayerManager too, so a rival that
# survives the duel - by winning it (_handle_defeat()) or by the player
# fleeing it (_on_flee_pressed()) - keeps whatever it didn't use, and
# EnemyHeroManager.restock_npc_potions() tops it back up (gold
# permitting) before the next encounter, exactly mirroring how the
# simulation restocks after every fight of its own.
var _enemy_potion_health_count: int = 0
var _enemy_potion_mana_count: int = 0

# skill_id -> turns remaining before the rival hero can cast it again -
# the enemy-side mirror of the player's own _skill_cooldowns. Unlike
# the player's, these never persist between fights (see
# _reset_enemy_hero_state()) - a freshly re-challenged rival always
# starts every skill ready.
var _enemy_skill_cooldowns: Dictionary = {}

# Slark's Essence Shift, cast by the rival at the PLAYER: unlike the
# player's own copy (which drains a battle-local counter on the
# enemy), there's nothing equivalent to permanently drain on the
# player, so this steals from - and gives back to - a battle-local
# penalty instead (_player_essence_shift_penalty below), never written
# to PlayerManager. The stolen stat is always the player's own
# main_stat (there's only one target, so no need to track "stolen"
# per-donor the way the player's own _essence_shift_stolen does).
var _enemy_essence_shift_active: bool = false
var _enemy_essence_shift_attacks_remaining: int = 0
var _enemy_essence_shift_turns_remaining: int = 0
var _enemy_essence_shift_duration_pending_start: bool = false
var _enemy_essence_shift_bonus: Dictionary = {"damage": 0.0, "hp": 0.0, "mana": 0.0, "armor": 0.0}

# Slark's Shadow Dance, cast by the rival: while active the boss can't
# be targeted by any of the player's attacks or targeted skills (see
# _is_target_hidden(), checked from _get_enemy_at()/
# _start_ranged_targeting()/_start_entangle_targeting()/
# _cast_dark_pact()) and skips the player's own retaliation-avoidance
# entirely - rather, HIS retaliation against the player still happens
# normally (see _enemy_hero_turn()); only being attacked back is
# blocked.
var _enemy_shadow_dance_active: bool = false
var _enemy_shadow_dance_bonus_damage: float = 0.0
var _enemy_shadow_dance_turns_remaining: int = 0
var _enemy_shadow_dance_duration_pending_start: bool = false

# Lone Druid's Spirit Link, cast by the rival on himself.
var _enemy_spirit_link_active: bool = false
var _enemy_spirit_link_lifesteal_pct: float = 0.0
var _enemy_spirit_link_bonus_armor: float = 0.0
var _enemy_spirit_link_turns_remaining: int = 0
var _enemy_spirit_link_duration_pending_start: bool = false

# Lone Druid's True Form, cast by the rival on himself. No forced-
# melee-range or portrait-swap-on-a-dedicated-node concept is needed
# here the way the player's own copy has one - True Form just swaps
# the boss's existing enemy node's texture (see
# _activate_enemy_true_form()/_end_enemy_true_form()) and adds bonus
# hp/damage.
var _enemy_true_form_active: bool = false
var _enemy_true_form_bonus_hp: float = 0.0
var _enemy_true_form_bonus_damage: float = 0.0
var _enemy_true_form_turns_remaining: int = 0
var _enemy_true_form_duration_pending_start: bool = false

# Lone Druid's Savage Roar, on the rival - same automatic hysteresis
# as the player's own copy, just re-evaluated once per rival turn (see
# _update_enemy_savage_roar_state()) rather than after every HP change,
# since there's no bars UI to keep live for an enemy.
var _enemy_savage_roar_active: bool = false
var _enemy_savage_roar_damage_reduction_pct: float = 0.0

# Abaddon's Aphotic Shield, cast by the rival on himself.
var _enemy_aphotic_shield_active: bool = false
var _enemy_aphotic_shield_hp: float = 0.0
var _enemy_aphotic_shield_aoe_damage: float = 0.0
var _enemy_aphotic_shield_radius: int = 0
var _enemy_aphotic_shield_turns_remaining: int = 0
var _enemy_aphotic_shield_duration_pending_start: bool = false

# Abaddon's Borrowed Time, on the rival - same auto-activate-off-HP%
# pattern as the player's own copy: nothing ever "casts" this, it just
# triggers itself from _deal_fixed_damage_to_enemy() the moment the
# rival's HP crosses this level's threshold - see
# _maybe_auto_activate_enemy_borrowed_time().
var _enemy_borrowed_time_active: bool = false
var _enemy_borrowed_time_heal_conversion_pct: float = 0.0
var _enemy_borrowed_time_turns_remaining: int = 0
var _enemy_borrowed_time_duration_pending_start: bool = false

# Kunkka's Tidebringer, on the rival - same plain-Attack counter as the
# player's own copy, just counting the rival's own Attacks on the
# player instead (see _maybe_consume_enemy_tidebringer_stack(), called
# from _resolve_enemy_hero_attack()).
var _enemy_tidebringer_attack_count: int = 0

# Slardar's Bash of the Deep, on the rival - same "count plain Attacks
# toward a threshold, consume them all once reached" idiom as
# Tidebringer's own counter just above (see
# _maybe_consume_enemy_bash_of_the_deep_stack(), called from
# _resolve_enemy_hero_attack()).
var _enemy_bash_of_the_deep_attack_count: int = 0

# Slardar's Guardian Sprint, on the rival - mirrors the player's own
# _guardian_sprint_bonus_movement/_guardian_sprint_charge_damage_pct/
# _guardian_sprint_turns_remaining/_guardian_sprint_duration_pending_
# start fields exactly: a self-buff that boosts the rival's own NEXT
# moves (see _enemy_hero_turn()'s own movement fallback) rather than an
# instant leap - doesn't move the rival itself when cast.
var _enemy_guardian_sprint_bonus_movement: int = 0
var _enemy_guardian_sprint_charge_damage_pct: float = 0.0
var _enemy_guardian_sprint_turns_remaining: int = 0
var _enemy_guardian_sprint_duration_pending_start: bool = false

# Mirana's ultimate, Moonlight Shadow, cast by the rival - mirrors Shadow
# Dance's own shape above: while active the boss can't be targeted by any
# of the player's attacks or targeted skills (see _is_target_hidden()/
# _update_enemy_hero_visibility(), both extended to also read this flag),
# and its own bonus_damage_pct folds into the rival's next Attack as a
# PERCENTAGE of the roll (see _resolve_enemy_hero_attack()), same "post-
# roll percentage" shape Bash of the Deep's own bonus uses, rather than
# Shadow Dance's flat pre-roll one. Reveals itself (ends) the instant
# that empowered Attack actually lands, whether or not it kills the
# player - same "one guaranteed hit, then the invisibility is spent"
# rule the player-side copy follows in _apply_hero_attack().
var _enemy_moonlight_shadow_active: bool = false
var _enemy_moonlight_shadow_bonus_damage_pct: float = 0.0
var _enemy_moonlight_shadow_turns_remaining: int = 0
var _enemy_moonlight_shadow_duration_pending_start: bool = false

# Luna's ultimate, Eclipse, cast by the rival - mirrors the player's own
# _eclipse_active/_eclipse_damage_per_beam/_eclipse_radius/_eclipse_
# beams_remaining/_eclipse_duration_pending_start fields exactly: fires
# ECLIPSE_BEAMS_PER_TURN beams per End Turn (see _tick_enemy_eclipse()),
# each independently picking ONE random living, targetable candidate from
# everything within radius columns of the rival's CURRENT position - the
# player, one of his own illusions, or his own Spirit Bear, all equally
# likely (see _tick_enemy_eclipse()'s own docstring) - with NO cap on how
# many beams the same candidate can take. Doesn't lock the rival's own
# actions while it's ticking, same as the player-side copy.
var _enemy_eclipse_active: bool = false
var _enemy_eclipse_damage_per_beam: float = 0.0
var _enemy_eclipse_radius: int = 0
var _enemy_eclipse_beams_remaining: int = 0
var _enemy_eclipse_duration_pending_start: bool = false

# Kunkka's X Marks the Spot, on the rival - unlike the player's own
# copy, the target is always the player (the only other participant in
# a hero fight, same simplification Dark Pact/Mist Coil/Torrent already
# use), so there's nothing to hold onto but a single pending flag - see
# _cast_enemy_xmarks()/_enemy_hero_turn()'s own teleport check at its
# very top.
var _enemy_xmarks_pending: bool = false

# Winter Wyvern's Arctic Burn, cast by the rival on themselves - mirrors
# the player's own _activate_arctic_burn()/_apply_arctic_burn_attack()/
# _tick_arctic_burn()/_end_arctic_burn(): bonus damage/range for this
# level's own `attacks` count of Attacks, or `duration` turns, whichever
# runs out first.
var _enemy_arctic_burn_active: bool = false
var _enemy_arctic_burn_bonus_damage: float = 0.0
var _enemy_arctic_burn_bonus_range: int = 0
var _enemy_arctic_burn_attacks_remaining: int = 0
var _enemy_arctic_burn_turns_remaining: int = 0
var _enemy_arctic_burn_duration_pending_start: bool = false

# Winter Wyvern's Cold Embrace, cast by the rival on themselves - mirrors
# the player's own _activate_cold_embrace()/_tick_cold_embrace()/
# _end_cold_embrace(): full damage immunity (see
# _deal_fixed_damage_to_enemy()) plus a heal every turn, for the
# duration - during which the rival can't move or attack (see
# _enemy_hero_turn()'s own lockout) but CAN still cast another skill,
# same as the player's own copy only blocks Move/Attack, never
# _on_skill_pressed(). Casting it also dispels every other effect
# currently on the rival, good or bad - see
# _dispel_all_enemy_hero_effects().
var _enemy_cold_embrace_active: bool = false
var _enemy_cold_embrace_heal_per_turn: float = 0.0
var _enemy_cold_embrace_turns_remaining: int = 0
var _enemy_cold_embrace_duration_pending_start: bool = false

# Crystal Maiden's Freezing Field, cast by the rival on herself - mirrors
# the player's own _activate_freezing_field()/_tick_freezing_field()/
# _end_freezing_field(): every tick that counts against the duration,
# whichever of the player/rival is within `radius` columns of the
# rival's OWN current position takes `damage_per_turn` (re-checked fresh
# each tick, not fixed at cast time, same as the player's own copy) -
# see _tick_enemy_freezing_field().
var _enemy_freezing_field_active: bool = false
var _enemy_freezing_field_damage_per_turn: float = 0.0
var _enemy_freezing_field_radius: int = 0
var _enemy_freezing_field_turns_remaining: int = 0
var _enemy_freezing_field_duration_pending_start: bool = false

# Tusk's Ice Shards, cast by the rival - mirrors the player's own
# _resolve_ice_shards_cast()/_tick_ice_shards()/_end_ice_shards(): walls
# off `blocked_columns` columns, starting on the rival's OWN column and
# continuing toward the player's, for the duration - see
# _is_column_enemy_ice_shards_blocked(), checked from _hero_move() so
# the player can't step into (or act from within) a walled column,
# mirroring how the player's own _is_column_ice_shards_blocked() gates
# every enemy's own movement in _enemy_turn()/_enemy_hero_turn(). Never
# blocks the RIVAL's own movement - same asymmetry the player's own copy
# already has (see _hero_move(), which never checks its own wall).
var _enemy_ice_shards_active: bool = false
var _enemy_ice_shards_blocked_columns: Array[int] = []
var _enemy_ice_shards_turns_remaining: int = 0
var _enemy_ice_shards_duration_pending_start: bool = false

# Tusk's Tag Team, cast by the rival on himself - mirrors the player's
# own _activate_tag_team()/_tick_tag_team()/_end_tag_team(): a flat
# bonus_damage added to _roll_enemy_hero_damage() for the duration, same
# "add to the bonus sum" spot Arctic Burn's own bonus_damage already
# occupies there.
var _enemy_tag_team_active: bool = false
var _enemy_tag_team_bonus_damage: float = 0.0
var _enemy_tag_team_turns_remaining: int = 0
var _enemy_tag_team_duration_pending_start: bool = false

# Treant Protector's Nature's Guise, cast by the rival on himself -
# mirrors the player's own _activate_natures_guise()/_tick_natures_
# guise()/_end_natures_guise(): folded into _is_target_hidden() (the
# enemy-side mirror of the player's own _is_hero_hidden()) so the
# player can't target/select the hidden boss, same as Shadow Dance's own
# copy - see _is_target_hidden()/_update_enemy_hero_visibility(). The
# Attack that breaks it roots the player instead of dealing bonus damage
# - see _resolve_enemy_hero_attack()'s own "attacking_from_enemy_
# natures_guise" capture.
var _enemy_natures_guise_active: bool = false
var _enemy_natures_guise_root_turns: int = 0
var _enemy_natures_guise_turns_remaining: int = 0
var _enemy_natures_guise_duration_pending_start: bool = false

# Treant Protector's Living Armor, cast by the rival on himself - mirrors
# the player's own _activate_living_armor()/_tick_living_armor()/
# _end_living_armor(): bonus_armor folds into _enemy_hero_bonus_armor()
# (the same slot Essence Shift's/Spirit Link's own bonus armor already
# share there), bonus_hp_regen heals the rival on top of his own
# baseline passive regen (_tick_enemy_passive_regen()) every tick - see
# _tick_enemy_living_armor().
var _enemy_living_armor_active: bool = false
var _enemy_living_armor_bonus_armor: float = 0.0
var _enemy_living_armor_bonus_hp_regen: float = 0.0
var _enemy_living_armor_turns_remaining: int = 0
var _enemy_living_armor_duration_pending_start: bool = false

# Timbersaw's Reactive Armor, on the rival - mirrors the player's own
# _reactive_armor_stack_turns/_apply_reactive_armor_stack()/_tick_
# reactive_armor_stacks()/_apply_reactive_armor_regen(): each entry is
# one stack's own remaining-turns counter, ticking down independently
# (unlike every other duration-based buff in this file, which only ever
# tracks one shared timer). Stacked from _deal_fixed_damage_to_enemy()
# every time a hit actually lands on the boss, folded into _enemy_hero_
# bonus_armor() for the armor half and healed via _apply_enemy_reactive_
# armor_regen() for the regen half - see _apply_enemy_reactive_armor_
# stack().
var _enemy_reactive_armor_stack_turns: Array[int] = []

# Timbersaw's ultimate, Chakram, on the rival - mirrors the player's own
# _chakram field/_resolve_chakram_cast()/_tick_chakram()/_despawn_
# chakram(): a targeted cast that deals this level's own cast_damage to
# the player (the only possible initial-AoE target in a hero fight - see
# _cast_enemy_chakram()'s own "no cleave" simplification every other
# rival AoE already uses), then plants the chakram at the player's
# CURRENT position at that moment (never re-checked against where the
# player moves to afterward), dealing damage_per_turn to the player
# every tick they're still within radius columns of that fixed spot, for
# the duration. Empty dictionary means no chakram is currently planted;
# see _cast_enemy_chakram()/_tick_enemy_chakram()/_despawn_enemy_
# chakram().
var _enemy_chakram: Dictionary = {}

# Snapfire's ultimate, Mortimer Kisses, on the rival - mirrors the
# player's own _mortimer_kisses_active/_mortimer_kisses_turns_left/
# _mortimer_kisses_level_data field shape (see that block's own comment
# for the full lock-site list): channels for `hits` turns, unable to
# move/attack/cast another skill/use items for the duration - see
# _enemy_hero_turn()'s own top-of-function lockout. Unlike the player's
# own _mortimer_marked_enemy, there's no separate "marked enemy"
# reference to hold here - the only possible target in a hero fight is
# the player himself, tracked live via _hero_pos_index, which (unlike a
# creep) never needs a "last known column" fallback since the battle
# would already be over if he'd died.
var _enemy_mortimer_kisses_active: bool = false
var _enemy_mortimer_kisses_turns_left: int = 0
var _enemy_mortimer_kisses_level_data: Dictionary = {}

# Naga Siren's Mirror Image, cast by the rival - mirrors the player's own
# _illusions/_illusion_damage_pct/_illusion_hit_chance_pct/_illusions_
# turns_remaining/_illusions_duration_pending_start fields exactly (see
# that block's own comment above): each entry in _enemy_illusions is a
# {pos_index, current_hp, max_hp, node} Dictionary, own HP pool sized off
# `hp_pct` of the boss's own effective max HP. While any are up,
# _deal_fixed_damage_to_enemy() rolls `hit_chance_pct` to redirect a hit
# meant for the boss onto a random surviving illusion instead - see that
# function's own comment. Every rival turn that isn't the casting one,
# every surviving illusion also strikes the player for `damage_pct` of a
# freshly-rolled rival Attack each (see _fire_enemy_mirror_image_
# attack(), called from _tick_enemy_mirror_image()). Rip Tide's own
# bonuses (extra_illusion, illusion_damage_bonus_pct, illusion_duration_
# bonus) are folded straight in at cast time, read fresh off
# _get_enemy_rip_tide_level_data() - a no-op while the rival hasn't
# learned it, same "empty means locked" convention every other auto-
# triggered skill's own level-data getter uses.
var _enemy_illusions: Array = []
var _enemy_illusion_damage_pct: float = 0.0
var _enemy_illusion_hit_chance_pct: float = 0.0
var _enemy_illusions_turns_remaining: int = 0
var _enemy_illusions_duration_pending_start: bool = false

# Set by _deal_fixed_damage_to_enemy() every time it redirects a hit
# onto one of the boss's own illusions instead of the boss itself -
# reset to {} at the top of every one of its calls, so this only ever
# reflects the MOST RECENT call's own outcome. Read right after by
# _apply_hero_attack() so Bash of the Deep's own knockback (which
# needs to know WHAT actually got hit) can move the illusion that took
# the hit instead of the boss that didn't.
var _last_enemy_illusion_redirect: Dictionary = {}

# ------------------------------------------------------------------
# What the rival's skills above do TO THE PLAYER. All of this only
# ever gets set during a hero fight and is reset by
# _reset_enemy_hero_state() before each new one.
# ------------------------------------------------------------------

# Essence Shift's running toll on the player - subtracted everywhere
# the matching _essence_shift_bonus is normally ADDED (see
# _hero_max_hp(), _hero_armor(), _roll_hero_damage(), _refresh_bars())
# so a hostile Essence Shift is exactly as strong in reverse as the
# player's own copy is in his favor. Reset to all-zero, in one shot,
# once the cast that caused it ends (_end_enemy_essence_shift()) -
# there's only one victim (the player), so there's no per-donor
# bookkeeping to do the way the player's own _essence_shift_stolen
# needs for potentially many enemies.
var _player_essence_shift_penalty: Dictionary = {"damage": 0.0, "hp": 0.0, "mana": 0.0, "armor": 0.0}

# Entangle's root/silence/damage-over-time, cast by the rival on the
# player - the mirror of _apply_root(), just aimed at the player
# instead of an enemy. Root blocks _hero_move(); silence blocks
# _on_skill_pressed(); the DoT ticks at the start of the player's own
# turn, alongside everything else in _tick_player_turn_start_effects().
var _player_root_turns_left: int = 0
var _player_silence_turns_left: int = 0
var _player_entangle_dot_damage: float = 0.0
var _player_entangle_dot_turns_left: int = 0

# Pounce's stun on the player - counts down once per _end_turn() call
# while > 0, each time skipping the player's own action entirely and
# immediately re-triggering _end_turn() again (see its tail) so the
# rival keeps acting until it wears off, the same way a stunned enemy
# just loses its turn to the player's own Pounce.
var _player_stun_turns_left: int = 0

# Set alongside _player_stun_turns_left specifically by
# _cast_enemy_winters_curse() (see that function's own comment on why
# it collapses onto the shared stun field) - purely cosmetic, so the
# frost screen tint/status icon can tell "frozen by Winter's Curse"
# apart from a Torrent/Pounce/Ice Blast/Frostbite stun, all of which
# also just set the same field. Cleared wherever the stun itself is
# (a fresh dispel or the stun's own natural countdown reaching 0).
var _player_winters_curse_active: bool = false

# Curse of Avernus's stacks/DoT on the player, built by the rival's own
# plain Attacks - the mirror of the same fields _apply_curse_of_avernus_
# stack() writes onto an enemy Dictionary, just held as battle-local
# vars since there's only one player to track them on. Silence isn't
# among them - it shares the _player_silence_turns_left field above,
# same as how a cursed enemy shares its own silence_turns_left with
# Entangle.
var _player_curse_stacks: int = 0
var _player_curse_active: bool = false
var _player_curse_dot_damage: float = 0.0
var _player_curse_dot_turns_left: int = 0
var _player_curse_last_hit_turn: int = 0

# Ancient Apparition's Cold Feet/Ice Vortex, cast by the rival on the
# player - both are plain damage-over-time, so both mirror Entangle's
# own _player_entangle_dot_* fields exactly, just held separately (each
# under its own dedicated pair of fields) since a different skill's DoT
# shouldn't silently share or clobber another's counters, the same
# reasoning the player-side per-enemy cold_feet_dot_*/ice_vortex_dot_*
# fields already follow.
var _player_cold_feet_dot_damage: float = 0.0
var _player_cold_feet_dot_turns_left: int = 0
var _player_ice_vortex_dot_damage: float = 0.0
var _player_ice_vortex_dot_turns_left: int = 0

# Ancient Apparition's Ice Blast, cast by the rival on the player -
# mirrors the player-side per-enemy ice_blast_dot_damage/ice_blast_dot_
# turns_left/ice_blast_execute_pct fields (see _resolve_ice_blast_
# cast()), just held as battle-local vars since there's only one player
# to track them on. The stun shares _player_stun_turns_left above, same
# as Torrent's own stun does.
var _player_ice_blast_dot_damage: float = 0.0
var _player_ice_blast_dot_turns_left: int = 0
var _player_ice_blast_execute_pct: float = 0.0

# Crystal Maiden's Frostbite, cast by the rival on the player - mirrors
# the player-side per-enemy frostbite_dot_damage/frostbite_dot_turns_
# left fields (see _resolve_frostbite_cast()), just held as battle-local
# vars since there's only one player to track them on. The stun shares
# _player_stun_turns_left above, same as Torrent's/Ice Blast's own stun
# does.
var _player_frostbite_dot_damage: float = 0.0
var _player_frostbite_dot_turns_left: int = 0

# Treant Protector's Leech Seed, cast by the rival on the player -
# mirrors the player-side per-enemy leech_seed_dot_damage/leech_seed_
# heal_per_turn/leech_seed_dot_turns_left fields (see _resolve_leech_
# seed_cast()), just held as battle-local vars since there's only one
# player to track them on. Unlike every other DoT here, the healing half
# goes to the CASTER (the rival), not the player - see _tick_player_
# turn_start_effects()'s own "leech_seed" case, which heals the boss
# directly (via _get_hero_fight_boss()) each tick instead.
var _player_leech_seed_dot_damage: float = 0.0
var _player_leech_seed_heal_per_turn: float = 0.0
var _player_leech_seed_dot_turns_left: int = 0

# Treant Protector's ultimate, Overgrowth, cast by the rival - mirrors
# the player-side per-enemy overgrowth_dot_damage/overgrowth_dot_turns_
# left fields (see _activate_overgrowth()), just held as battle-local
# vars since there's only one player to track them on. The root shares
# _player_root_turns_left above, the same field Entangle's own root
# already uses - Overgrowth's own "can't move, can still attack/cast/
# use items" rule is exactly what that field already means everywhere
# it's checked (_hero_move()), so there's nothing extra to enforce here.
var _player_overgrowth_dot_damage: float = 0.0
var _player_overgrowth_dot_turns_left: int = 0

# Snapfire's Lil' Shredder, cast by the rival on the player - mirrors
# the player-side per-enemy armor_reduction/armor_reduction_turns_left
# fields (see _resolve_lil_shredder_cast()), just held as battle-local
# vars since there's only one player to track them on. Folded into
# _hero_armor() as a straight subtraction, same "runtime field, never
# touching the static template" reasoning the enemy-side version uses.
var _player_armor_reduction: float = 0.0
var _player_armor_reduction_turns_left: int = 0

# Slardar's ultimate, Corrosive Haze, cast by the rival on the player -
# mirrors the player-side per-enemy "corrosive_haze_bonus_pct" field
# (see _resolve_corrosive_haze_cast()), just held as a battle-local var
# since there's only one player to track it on. Read by apply_damage()
# to boost every hit the player takes from the rival's own attacks/
# skills, mirroring _deal_fixed_damage_to_enemy()'s own "is_hero_action"
# check. Shares _player_armor_reduction_turns_left above as its own
# turns-left counter, same "share the shred's own timer" convention the
# player-side copy uses (see _resolve_corrosive_haze_cast()'s own
# comment) - Corrosive Haze's own armor_reduction half is folded
# straight into that same shared field, additively, rather than getting
# a second one of its own.
var _player_corrosive_haze_bonus_pct: float = 0.0

# Snapfire's ultimate, Mortimer Kisses, cast by the rival on the player -
# mirrors the player-side per-enemy mortimer_burn_dot_damage/mortimer_
# burn_dot_turns_left fields (see _fire_mortimer_kisses_shot()), just
# held as battle-local vars since there's only one player to track them
# on.
var _player_mortimer_burn_dot_damage: float = 0.0
var _player_mortimer_burn_dot_turns_left: int = 0

# ------------------------------------------------------------------
# Ranged-hero target selection: when true, the enemies in
# _valid_targets are highlighted and clickable; clicking one resolves
# either a plain attack or a targeted skill, depending on
# _targeting_purpose ("attack" or a skill id like "entangle" or
# "mist_coil") - see _on_enemy_clicked(). Mist Coil additionally lets
# the player click the hero's own portrait instead (self-cast) - see
# _on_hero_image_gui_input()/_resolve_mist_coil_self_cast(). Every
# _start_X_targeting() function marks _valid_targets via the shared
# _highlight_valid_targets() (see TARGET_HIGHLIGHT_COLOR/_PULSE_COLOR),
# whose pulsing tweens are tracked here so _cancel_targeting() can kill
# them before resetting modulate back to normal.
var _targeting_mode: bool = false
var _valid_targets: Array = []
var _targeting_purpose: String = "attack"
var _target_highlight_tweens: Array = []

# Entangle's level data, held from the moment its target-picking
# starts (_start_entangle_targeting) until a target is actually
# clicked (_resolve_entangle_cast) - mana/cooldown/turn are only spent
# once that click resolves, same as a normal ranged Attack.
var _pending_entangle_level_data: Dictionary = {}

# Mist Coil's level data, held the same way as Entangle's above, from
# the moment _start_mist_coil_targeting() opens targeting until either
# an enemy or the hero's own portrait is clicked
# (_resolve_mist_coil_enemy_cast()/_resolve_mist_coil_self_cast()).
var _pending_mist_coil_level_data: Dictionary = {}

# Kunkka's Torrent, held the same way as Entangle's/Mist Coil's own
# pending level data above, from the moment _start_torrent_targeting()
# opens targeting until a target is actually clicked
# (_resolve_torrent_cast()).
var _pending_torrent_level_data: Dictionary = {}

# Kunkka's X Marks the Spot, held the same way while its own targeting
# is open (_start_xmarks_targeting()) until a target is clicked
# (_resolve_xmarks_cast()).
var _pending_xmarks_level_data: Dictionary = {}

# X Marks the Spot's actual mark, set once _resolve_xmarks_cast() spends
# the cast and held until the hero's own NEXT turn opens (_end_turn()),
# at which point he teleports onto the marked enemy's CURRENT position
# (see _resolve_xmarks_teleport()) - wherever it's moved to by then -
# for free, without spending that turn's action. `target` is the marked
# enemy's own Dictionary reference (live - its "pos_index" updates as it
# moves, so reading it later reads wherever it ended up), {} meaning no
# mark is pending. `stage_generation` is _stage_generation at the moment
# of marking, so a stage transition/hero fight change in between (a
# fresh _enemies array, making `target` a stale reference into a fight
# that's already over) fizzles the mark instead of teleporting into
# nothing - see _resolve_xmarks_teleport().
var _pending_xmarks_target: Dictionary = {}
var _pending_xmarks_stage_generation: int = -1

# Kunkka's Ghostship, held the same way as Torrent's/X Marks the Spot's
# own pending level data above, from the moment _start_ghostship_
# targeting() opens targeting until a target is actually clicked
# (_resolve_ghostship_cast()).
var _pending_ghostship_level_data: Dictionary = {}

# Timbersaw's Timber Chain, held the same way as every other targeted
# skill's own pending level data above, from the moment _start_timber_
# chain_targeting() opens targeting until a target is actually clicked
# (_resolve_timber_chain_cast()).
var _pending_timber_chain_level_data: Dictionary = {}

# Timbersaw's Chakram, held the same way as every other targeted
# skill's own pending level data above, from the moment _start_chakram_
# targeting() opens targeting until a target is actually clicked
# (_resolve_chakram_cast()).
var _pending_chakram_level_data: Dictionary = {}

# Snapfire's Lil' Shredder, held the same way as every other targeted
# skill's own pending level data above, from the moment _start_lil_
# shredder_targeting() opens targeting until a target is actually
# clicked (_resolve_lil_shredder_cast()).
var _pending_lil_shredder_level_data: Dictionary = {}

# Snapfire's Mortimer Kisses, held the same way as every other targeted
# skill's own pending level data above, from the moment _start_
# mortimer_kisses_targeting() opens targeting until a target is
# actually clicked (_resolve_mortimer_kisses_cast()).
var _pending_mortimer_kisses_level_data: Dictionary = {}

# Naga Siren's Ensnare, held the same way as every other targeted
# skill's own pending level data above, from the moment _start_ensnare_
# targeting() opens targeting until a target is actually clicked
# (_resolve_ensnare_cast()).
var _pending_ensnare_level_data: Dictionary = {}

# Slardar's Corrosive Haze, held the same way as every other targeted
# skill's own pending level data above, from the moment _start_
# corrosive_haze_targeting() opens targeting until a target is actually
# clicked (_resolve_corrosive_haze_cast()).
var _pending_corrosive_haze_level_data: Dictionary = {}

# Mirana's Sacred Arrow, held the same way as every other targeted
# skill's own pending level data above, from the moment _start_
# sacred_arrow_targeting() opens targeting until a target is actually
# clicked (_resolve_sacred_arrow_cast()).
var _pending_sacred_arrow_level_data: Dictionary = {}

# Luna's Lucent Beam, held the same way as every other targeted skill's
# own pending level data above, from the moment _start_lucent_beam_
# targeting() opens targeting until a target is actually clicked
# (_resolve_lucent_beam_cast()).
var _pending_lucent_beam_level_data: Dictionary = {}

# Ancient Apparition's Cold Feet, held the same way as every other
# targeted skill's own pending level data above, from the moment
# _start_cold_feet_targeting() opens targeting until a target is
# actually clicked (_resolve_cold_feet_cast()).
var _pending_cold_feet_level_data: Dictionary = {}

# Ancient Apparition's Ice Vortex, held the same way as every other
# targeted skill's own pending level data above, from the moment
# _start_ice_vortex_targeting() opens targeting until a target is
# actually clicked (_resolve_ice_vortex_cast()).
var _pending_ice_vortex_level_data: Dictionary = {}

# Ancient Apparition's Chilling Touch, held the same way as every other
# targeted skill's own pending level data above, from the moment
# _start_chilling_touch_targeting() opens targeting until a target is
# actually clicked (_resolve_chilling_touch_cast()).
var _pending_chilling_touch_level_data: Dictionary = {}

# Ancient Apparition's Ice Blast, held the same way as every other
# targeted skill's own pending level data above, from the moment
# _start_ice_blast_targeting() opens targeting until a target is
# actually clicked (_resolve_ice_blast_cast()).
var _pending_ice_blast_level_data: Dictionary = {}

# Winter Wyvern's Splinter Blast, held the same way as every other
# targeted skill's own pending level data above, from the moment
# _start_splinter_blast_targeting() opens targeting until a target is
# actually clicked (_resolve_splinter_blast_cast()).
var _pending_splinter_blast_level_data: Dictionary = {}

# Winter Wyvern's ultimate, Winter's Curse, held the same way as every
# other targeted skill's own pending level data above, from the moment
# _start_winters_curse_targeting() opens targeting until a target is
# actually clicked (_resolve_winters_curse_cast()).
var _pending_winters_curse_level_data: Dictionary = {}

# Crystal Maiden's Crystal Nova, held the same way as every other
# targeted skill's own pending level data above, from the moment
# _start_crystal_nova_targeting() opens targeting until a target is
# actually clicked (_resolve_crystal_nova_cast()).
var _pending_crystal_nova_level_data: Dictionary = {}

# Crystal Maiden's Frostbite, held the same way as every other targeted
# skill's own pending level data above, from the moment
# _start_frostbite_targeting() opens targeting until a target is
# actually clicked (_resolve_frostbite_cast()).
var _pending_frostbite_level_data: Dictionary = {}

# Tusk's Ice Shards, held the same way as every other targeted skill's
# own pending level data above, from the moment _start_ice_shards_
# targeting() opens targeting until a target is actually clicked
# (_resolve_ice_shards_cast()).
var _pending_ice_shards_level_data: Dictionary = {}

# Tusk's Snowball, held the same way as every other targeted skill's
# own pending level data above, from the moment _start_snowball_
# targeting() opens targeting until a target is actually clicked
# (_resolve_snowball_cast()).
var _pending_snowball_level_data: Dictionary = {}

# Tusk's ultimate, Walrus Punch, held the same way as every other
# targeted skill's own pending level data above, from the moment
# _start_walrus_punch_targeting() opens targeting until a target is
# actually clicked (_resolve_walrus_punch_cast()).
var _pending_walrus_punch_level_data: Dictionary = {}

# Treant Protector's Leech Seed, held the same way as every other
# targeted skill's own pending level data above, from the moment
# _start_leech_seed_targeting() opens targeting until a target is
# actually clicked (_resolve_leech_seed_cast()).
var _pending_leech_seed_level_data: Dictionary = {}

const RANGE_ENEMY_ATTACK_RANGE := 3
const RANGE_ENEMY_FLEE_DISTANCE := 1

# Every ACTIVE skill a rival hero might cast during a hero fight - the
# full candidate pool _pick_enemy_ready_skill() checks for cooldown/
# worth-casting/mana/range before handing survivors to EnemySkillAI to
# score and pick from (the same pool EnemyHeroManager.
# KNOWN_ACTIVE_SKILL_IDS drives for its own background simulation).
# This is no longer a priority order - see EnemySkillAI.HERO_TIE_BREAK
# for each hero's own tie-break fallback order, only ever consulted
# when two skills' scores are too close to call outright. Savage Roar,
# Curse of Avernus, Borrowed Time, and Tidebringer aren't here - none
# of them are ever "cast" or scored: Savage Roar and Borrowed Time turn
# themselves on/off automatically off the rival's own HP% (see
# _update_enemy_savage_roar_state()/
# _maybe_auto_activate_enemy_borrowed_time()), and Curse of Avernus/
# Tidebringer only ever build off the rival's own plain Attacks (see
# _apply_enemy_curse_of_avernus_stack()/
# _maybe_consume_enemy_tidebringer_stack()).
const ENEMY_KNOWN_SKILL_IDS: Array[String] = [
	"dark_pact", "pounce", "essence_shift", "shadow_dance",
	"entangle", "summon_spirit_bear", "spirit_link", "true_form",
	"mist_coil", "aphotic_shield", "torrent", "x_marks_the_spot", "ghostship",
	"cold_feet", "ice_vortex", "chilling_touch", "ice_blast",
	"arctic_burn", "splinter_blast", "cold_embrace", "winter's_curse",
	"crystal_nova", "frostbite", "freezing_field",
	"ice_shards", "snowball", "tag_team", "walrus_punch",
	"nature's_guise", "leech_seed", "living_armor", "overgrowth",
	"whirling_death", "timber_chain", "chakram",
	"scatterblast", "firesnap_cookie", "lil_shredder", "mortimer_kisses",
	"mirror_image", "ensnare", "song_of_the_siren",
	"guardian_sprint", "slithereen_crush", "corrosive_haze",
	"starstorm", "sacred_arrow", "leap", "moonlight_shadow",
	"lucent_beam", "eclipse",
]

# Reinforcements: if the hero hasn't cleared every enemy within
# REINFORCEMENT_INTERVAL turns of the stage/fight starting, a fresh
# wave (sized by GameManager.REINFORCEMENT_ENEMY_COUNTS for the current
# stage, or the FULL stage 3 STAGE_ENEMY_COUNTS during a hero fight -
# see _spawn_reinforcements()) joins the fight, scaled to that same
# stage's stats. Every wave after that first one gives the player a
# shorter REINFORCEMENT_REPEAT_INTERVAL-turn grace period instead - see
# _next_reinforcement_turn, which tracks the turn count the NEXT wave
# is due on and advances by REPEAT (not INTERVAL) each time one
# actually spawns, so it keeps arriving every REPEAT turns for as long
# as the stage/fight goes on. Both counters reset (_turn_count back to
# 0, _next_reinforcement_turn back to REINFORCEMENT_INTERVAL) whenever
# a fresh stage or hero fight starts - see _advance_to_next_stage()/
# _start_hero_fight() - and stop mattering entirely once the stage
# clears or the player flees, since there's no more fight for them to
# fire into.
const REINFORCEMENT_INTERVAL := 13
const REINFORCEMENT_REPEAT_INTERVAL := 10
var _turn_count: int = 0
var _next_reinforcement_turn: int = REINFORCEMENT_INTERVAL

# Which of the zone's up-to-GameManager.MAX_ZONE_STAGE waves this
# battle is currently on. Starts at whatever PlayerManager.
# get_zone_start_stage() says (1, unless this zone's already been
# fully cleared, in which case straight to the final stage every
# time). Clearing every enemy in a non-final stage reloads the next
# stage's enemies in this same scene instance - see _handle_victory()
# and _advance_to_next_stage() - rather than returning to the Map.
var _current_stage: int = 1

# True while fighting a post-stage-3 rival hero instead of the zone's
# regular creeps - see _try_start_hero_fight()/_start_hero_fight().
# _current_stage stays at MAX_ZONE_STAGE throughout, so code that
# needs to know "are we in the normal stage progression or a hero
# fight" should check this rather than _current_stage.
var _in_hero_fight: bool = false

# Which hero id is being fought, so _handle_victory() knows who to
# mark defeated via PlayerManager.mark_hero_defeated() when it's won.
var _hero_fight_target_id: String = ""

# Bumped every time _advance_to_next_stage() runs. Action handlers
# that might kill the last enemy of a stage (attack, Pounce, Dark
# Pact) capture this before acting and check it again after - if it
# changed, a stage transition already reset the turn state (fresh
# actions, only skill cooldowns carried over) and they must NOT then
# overwrite that by unconditionally marking the turn as used.
var _stage_generation: int = 0



func _ready() -> void:
	flee_button.pressed.connect(_on_flee_pressed)
	defeat_ok_button.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/PostLogin.tscn"))
	move_left_button.pressed.connect(_on_move_left_pressed)
	move_right_button.pressed.connect(_on_move_right_pressed)
	attack_button.pressed.connect(_on_attack_pressed)
	hero_image.gui_input.connect(_on_hero_image_gui_input)
	level_up_ok_button.pressed.connect(_on_level_up_continue_pressed)
	skill_choice_desc_ok_button.pressed.connect(_on_skill_choice_desc_ok_pressed)
	skill_choice_desc_cancel_button.pressed.connect(_on_skill_choice_desc_cancel_pressed)

	_recruited = PlayerManager.get_recruited_hero()
	if _recruited.is_empty():
		print("ERROR: No recruited hero found - accept a hero in a zone first.")
		return

	_hero_static = GameManager.get_hero_by_id(_recruited["id"])
	_current_stage = PlayerManager.get_zone_start_stage(GameManager.selected_zone)

	# Tutorial stages 2 and 3 are manufactured mid-run scenarios (see
	# TutorialManager.start_stage2()/start_stage3()) rather than a real
	# zone-cleared state, so they override the stage computed above
	# directly.
	if TutorialManager.is_active and (TutorialManager.current_stage == 2 or TutorialManager.current_stage == 3):
		_current_stage = 3

	# Every player battle attempt (not just full zone clears - fleeing
	# after a partial clear still counts) also ticks the background
	# simulation for every other hero in the game, so their world
	# keeps progressing whether or not the player's own runs finish.
	# See EnemyHeroManager.tick_all_npc_heroes().
	EnemyHeroManager.tick_all_npc_heroes(_recruited["id"])

	_load_battle_background()
	_load_hero_image()
	_build_bar_styles()
	_refresh_bars()
	_populate_skill_buttons()
	_populate_item_grid()
	_refresh_gold_label()
	_load_enemies()
	_update_stage_label()
	_update_action_buttons()

	if TutorialManager.is_active and TutorialManager.current_stage == 1:
		_advance_tutorial_stage1_step("move_to_torrent_range")
	elif TutorialManager.is_active and TutorialManager.current_stage == 2:
		_start_tutorial_stage2_battle()
	elif TutorialManager.is_active and TutorialManager.current_stage == 3:
		_start_tutorial_stage3_battle()


func _load_battle_background() -> void:
	var zone_data: Dictionary = GameManager.get_selected_zone()
	var battle_bg_path: String = zone_data.get("battle_background", "")
	if battle_bg_path != "" and ResourceLoader.exists(battle_bg_path):
		background.texture = load(battle_bg_path)
	else:
		print("No battle_background set for the current zone - using fallback color.")


func _grid_unit() -> float:
	return get_viewport_rect().size.x / float(GRID_COLUMNS)


func _index_to_x(index: int) -> float:
	return index * _grid_unit()


func _creature_y() -> float:
	var target_height: float = get_viewport_rect().size.y / 4.0
	return (get_viewport_rect().size.y - target_height) / 2.0


## Shortest distance between two columns, accounting for the fact
## that moving off one edge wraps to the other.
func _distance(a: int, b: int) -> int:
	return absi(a - b)


## Fraction of incoming damage an armor value blocks, on a 0-1 scale
## (e.g. armor 5 -> ~0.23, meaning 23% reduced). Approaches but never
## reaches 1, so damage can be mitigated heavily but never nullified.
func _damage_reduction(armor: float) -> float:
	return (0.06 * armor) / (1.0 + 0.06 * armor)


## Applies an armor value's damage reduction to a raw damage amount.
## Negative armor increases damage taken instead of reducing it.
## Result is clamped to 0 so negative armor can't flip a hit into a heal.
func _apply_armor_reduction(raw_damage: float, armor: float) -> float:
	var reduction: float = _damage_reduction(armor)
	return maxf(0.0, raw_damage * (1.0 - reduction))


## Hero's total max HP: base stat plus Essence Shift's borrowed hp
## plus True Form's bonus hp while each is active - the one place
## that combination is computed, used by the HP bar, Savage Roar's
## threshold check, and the bear-death HP penalty.
func _hero_max_hp() -> float:
	var stats: Dictionary = _recruited.get("stats", {})
	return float(stats.get("hp", 0)) + _essence_shift_bonus.get("hp", 0.0) + _true_form_bonus_hp - _player_essence_shift_penalty.get("hp", 0.0)


## Hero's total armor: base stat from GameManager plus any permanent
## bonus picked up from items (mirrors how damage bonus is combined
## in _roll_hero_damage), plus any armor currently borrowed via
## Essence Shift, plus Spirit Link's flat bonus, Living Armor's own
## flat bonus, and Reactive Armor's own per-stack bonus, each while
## active.
func _hero_armor() -> float:
	var stats: Dictionary = _recruited.get("stats", {})
	return float(stats.get("armor", 0)) + _essence_shift_bonus.get("armor", 0.0) + _spirit_link_bonus_armor + _living_armor_bonus_armor + _reactive_armor_bonus_armor() - _player_essence_shift_penalty.get("armor", 0.0) - _player_armor_reduction


## Savage Roar's current level data ({} if not learned yet) - looked
## up fresh each time rather than cached, so a mid-battle level-up
## (via a banked skill point) is picked up immediately.
func _get_savage_roar_level_data() -> Dictionary:
	var level: int = PlayerManager.get_skill_level("savage_roar")
	if level <= 0:
		return {}
	for skill in _hero_static.get("skills", []):
		if skill.get("id", "") == "savage_roar":
			return GameManager.get_skill_level_data(skill, level)
	return {}


## Recomputes Savage Roar's on/off state and its bonus values, and
## refreshes its status label to match. Called from _refresh_bars()
## (i.e. after every HP change) and right after _populate_skill_
## buttons() rebuilds that label, so it's never stale.
##
## Uses hysteresis rather than one threshold: it switches ON once HP
## drops below 50%, then stays on through the whole climb back up
## until HP actually reaches 80%, rather than flicking on and off
## every time HP crosses a single line. Between 50% and 80%, whatever
## state it was already in just holds.
func _update_savage_roar_state() -> void:
	var level_data: Dictionary = _get_savage_roar_level_data()

	if level_data.is_empty():
		_savage_roar_active = false
	else:
		var max_hp: float = _hero_max_hp()
		if max_hp > 0.0:
			var hp_pct: float = float(_recruited.get("current_hp", 0)) / max_hp
			if _savage_roar_active:
				if hp_pct >= 0.8:
					_savage_roar_active = false
			elif hp_pct < 0.5:
				_savage_roar_active = true

	if _savage_roar_active:
		_savage_roar_bonus_movement = int(level_data.get("bonus_movement", 0))
		_savage_roar_damage_reduction_pct = float(level_data.get("damage_reduction_pct", 0.0))
	else:
		_savage_roar_bonus_movement = 0
		_savage_roar_damage_reduction_pct = 0.0

	if not is_instance_valid(_savage_roar_status_label):
		return

	if level_data.is_empty():
		_savage_roar_status_label.text = "Passive"
		_savage_roar_status_label.add_theme_color_override("font_color", Color(0.7, 0.8, 1, 1))
	elif _savage_roar_active:
		_savage_roar_status_label.text = "Active"
		_savage_roar_status_label.add_theme_color_override("font_color", Color(1, 0.65, 0.2, 1))
	else:
		_savage_roar_status_label.text = "Inactive"
		_savage_roar_status_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1))


## Which direction (+1 or -1) is the shorter path from `from` to `to`,
## going around the wraparound board rather than always picking the
## raw lower/higher index.
func _step_toward(from: int, to: int) -> int:
	if from < to:
		return 1
	elif from > to:
		return -1

	return 0


func _load_hero_image() -> void:
	_set_hero_image(_hero_static.get("image", ""))


## Loads `image_path` into hero_image, scaled to a quarter of the
## screen's height with its own aspect ratio preserved - shared by the
## normal hero portrait (_load_hero_image()) and True Form's swap to
## its bear portrait/back again (see _activate_true_form()/
## _end_true_form()). No-ops (with a printed warning) if the path is
## empty or missing, leaving whatever's already showing untouched.
func _set_hero_image(image_path: String) -> void:
	if image_path == "" or not ResourceLoader.exists(image_path):
		print("No hero image found at: ", image_path)
		return

	var texture: Texture2D = load(image_path)
	hero_image.texture = texture

	# Scale so the hero's height is exactly 1/4 of the screen, keeping
	# the image's original aspect ratio for the width.
	var target_height: float = get_viewport_rect().size.y / 4.0
	var tex_size: Vector2 = texture.get_size()
	var scale_factor: float = target_height / tex_size.y
	var target_width: float = tex_size.x * scale_factor

	hero_image.size = Vector2(target_width, target_height)
	_update_hero_position()


func _update_hero_position() -> void:
	hero_image.position = Vector2(_index_to_x(_hero_pos_index), _creature_y())
	

## Spawns the current stage's enemies: GameManager.STAGE_ENEMY_COUNTS
## says how many melee/ranged enemies this stage has, cycling through
## the zone's own melee/ranged templates if it needs more than the
## zone defines (e.g. 5 melee out of only 2 distinct templates just
## repeats them). Each spawned enemy gets its own stage-adjusted stats
## via _build_stage_enemy_def() - the zone's template dictionaries
## themselves are never modified.
func _load_enemies() -> void:
	for child in enemies_layer.get_children():
		child.queue_free()
	_enemies.clear()

	var zone_data: Dictionary = GameManager.get_selected_zone()
	var enemy_defs: Array = zone_data.get("enemies", [])

	var mele_templates: Array = []
	var range_templates: Array = []
	for enemy_def in enemy_defs:
		if enemy_def.get("type", "") == "range":
			range_templates.append(enemy_def)
		else:
			mele_templates.append(enemy_def)

	var counts: Dictionary = GameManager.get_stage_enemy_counts(_current_stage)

	# Tutorial stage 3 (see TutorialManager.start_stage3()) puts the
	# hero into this stage's real enemy composition (5 melee + 2 range
	# at Cladd Isles) while deliberately low on HP - fine for the brief
	# stage 2 scenario (one attack, then flee), but that many attackers
	# every turn is lethal over stage 3's longer script (level up, wait
	# for reinforcements, cast the ultimate, mop up). Opens with stage
	# 1's smaller count instead - reinforcements (still sized for the
	# real stage 3, see _spawn_reinforcements()) bring the numbers back
	# up right as Ghostship becomes available to deal with them.
	if TutorialManager.is_active and TutorialManager.current_stage == 3:
		counts = GameManager.get_stage_enemy_counts(1)

	_spawn_stage_enemies(mele_templates, int(counts.get("mele", 0)))
	_spawn_stage_enemies(range_templates, int(counts.get("range", 0)))


func _spawn_stage_enemies(templates: Array, count: int) -> void:
	if templates.is_empty():
		return
	for i in range(count):
		var template: Dictionary = templates[i % templates.size()]
		_spawn_enemy(_build_stage_enemy_def(template, _current_stage))


## Returns a copy of `base_def` with this stage's hp/damage/gold
## bonuses baked in - both are cumulative across stages (see
## GameManager.get_stage_stat_bonus / get_stage_cumulative_gold_bonus),
## each stage adding its own increment on top of whatever the
## previous stage already added, not a flat total over the base value.
func _build_stage_enemy_def(base_def: Dictionary, stage: int) -> Dictionary:
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


## Creates one enemy (image, position, hitbox) from a definition and
## adds it to `_enemies`. Used both for the zone's starting roster and
## for reinforcements later. Melee enemies stack at column 7, ranged
## at column 8, offset visually so same-column enemies don't render
## exactly on top of each other - the offset is based on how many
## enemies of that type are already on the field, so this works
## whether it's the initial load or a reinforcement arriving mid-fight.
func _spawn_enemy(enemy_def: Dictionary) -> void:
	var image_path: String = enemy_def.get("image", "")
	if image_path == "" or not ResourceLoader.exists(image_path):
		print("No enemy image found at: ", image_path)
		return

	var target_height: float = get_viewport_rect().size.y / 4.0
	var y_pos: float = _creature_y()

	var texture: Texture2D = load(image_path)
	var tex_size: Vector2 = texture.get_size()
	var scale_factor: float = target_height / tex_size.y
	var target_width: float = tex_size.x * scale_factor

	var tex_rect := TextureRect.new()
	tex_rect.texture = texture
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	tex_rect.size = Vector2(target_width, target_height)
	tex_rect.mouse_filter = Control.MOUSE_FILTER_STOP

	# Hero art is drawn facing right (toward the enemy side, where the
	# player's own hero always stands) - a hero fight puts that same
	# art on the enemy side instead, facing the player's hero, so it
	# needs to be mirrored to face left. Regular creep art is already
	# drawn facing left and is untouched.
	tex_rect.flip_h = enemy_def.get("is_hero_fight", false)

	var enemy_type: String = enemy_def.get("type", "")
	var pos_index: int
	var visual_offset: float

	if enemy_type == "range":
		pos_index = 8
		visual_offset = _enemy_count_of_type("range") * 16.0
	else:
		pos_index = 7
		visual_offset = _enemy_count_of_type("mele") * 16.0

	tex_rect.position = Vector2(_index_to_x(pos_index) + visual_offset, y_pos)

	enemies_layer.add_child(tex_rect)

	var hp_label := Label.new()
	hp_label.size = Vector2(ENEMY_HP_LABEL_WIDTH, ENEMY_HP_LABEL_HEIGHT)
	hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hp_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	hp_label.add_theme_constant_override("outline_size", 3)
	enemies_layer.add_child(hp_label)

	var status_label := Label.new()
	status_label.size = Vector2(ENEMY_STATUS_LABEL_WIDTH, ENEMY_HP_LABEL_HEIGHT)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_label.visible = false
	status_label.add_theme_color_override("font_color", ENEMY_STATUS_LABEL_COLOR)
	status_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	status_label.add_theme_constant_override("outline_size", 3)
	status_label.add_theme_font_size_override("font_size", ENEMY_STATUS_LABEL_FONT_SIZE)
	enemies_layer.add_child(status_label)

	var enemy_data := {
		"static": enemy_def,
		"current_hp": float(enemy_def.get("hp", 1)),
		"current_main_stat_value": float(enemy_def.get("main_stat_value", 0)),
		"pos_index": pos_index,
		"node": tex_rect,
		"hp_label": hp_label,
		"status_label": status_label,
	}
	_enemies.append(enemy_data)

	tex_rect.gui_input.connect(_on_enemy_gui_input.bind(enemy_data))

	_refresh_enemy_overhead_labels()


func _enemy_count_of_type(type: String) -> int:
	var count := 0
	for enemy in _enemies:
		if enemy["static"].get("type", "") == type:
			count += 1
	return count


# ------------------------------------------------------------------
# Enemy HP number display - "current / max" over every enemy's own
# image (no bars, just the numbers, per the design ask), in gold and a
# little bigger for a hero-fight boss specifically so it reads as
# unmistakably different from a regular creep's - plus, right next to
# it, a plain-text list of whatever status effects are currently
# active on that enemy ("Stunned", "Rooted", etc. - see
# _enemy_status_effect_text()). Every enemy that shares a column (they
# can end up sharing one via movement even though spawning only ever
# uses columns 7/8 - see _spawn_enemy()'s own visual_offset fan-out)
# gets its HP/status pair stacked vertically above that shared spot
# instead of overlapping, with whichever one _get_enemy_at() would
# actually resolve an attack on that column against - the "front" one
# - always at the bottom of the stack, since that's the one actually
# being attacked whenever that column is hit.
# ------------------------------------------------------------------

const ENEMY_HP_LABEL_WIDTH := 90.0
const ENEMY_HP_LABEL_HEIGHT := 22.0
const ENEMY_HP_LABEL_GAP := 4.0
const ENEMY_HP_LABEL_FONT_SIZE := 15
const ENEMY_HERO_HP_LABEL_FONT_SIZE := 20
const ENEMY_HP_LABEL_COLOR := Color(1, 1, 1, 1)
const ENEMY_HERO_HP_LABEL_COLOR := Color(1, 0.85, 0.2, 1)

const ENEMY_STATUS_LABEL_WIDTH := 220.0
const ENEMY_STATUS_LABEL_GAP := 6.0
const ENEMY_STATUS_LABEL_FONT_SIZE := 13
const ENEMY_STATUS_LABEL_COLOR := Color(1, 0.55, 0.3, 1)


## Every status effect currently on `enemy` that's worth calling out,
## as a comma-separated string ("" if none) - one entry per distinct
## effect a player skill (or a wall the player's own Ice Shards put
## under its feet) can inflict directly on an enemy Dictionary. Mirrors
## _enemy_has_harmful_debuff()'s own field list (used for Cold Embrace's
## AI scoring) plus the effects that helper doesn't need for that
## purpose - stun, Frostbite's/Leech Seed's/Overgrowth's own DoTs, and
## an Ice-Shards-blocked column, which isn't a Dictionary field at all
## but reads as "rooted" just the same since the enemy can't move
## either way (see _is_column_ice_shards_blocked()).
func _enemy_status_effect_text(enemy: Dictionary) -> String:
	var effects: PackedStringArray = []

	if enemy.get("stun_turns_left", 0) > 0:
		effects.append("Stunned")

	# Entangle roots AND silences for the exact same duration - every
	# level's own data sets root_turns == silence_turns, and both now
	# tick down together every turn (see _enemy_turn()'s own silence
	# decrement, added to match root's) - so silence_turns_left > 0 is
	# a reliable "this root is Entangle's, not Nature's Guise's" signal
	# (Nature's Guise only ever sets root_turns_left, never silence -
	# see _apply_hero_attack()'s own "attacking_from_natures_guise"
	# branch), without needing entangle_dot_turns_left at all - that
	# field's own duration runs one turn longer than root/silence by
	# design, but the "Entangled" status itself shouldn't outlive the
	# root/silence it actually represents, just the residual DoT tick.
	# An activated Curse of Avernus also silences through that same
	# silence_turns_left field, so while it's active silence alone no
	# longer proves Entangle - fall back to Entangle's own DoT counter.
	# Only an ACTIVATED curse counts as "Cursed"; stacks still building
	# toward hits_to_activate aren't a curse yet.
	var cursed: bool = enemy.get("curse_active", false)
	var silenced: bool = enemy.get("silence_turns_left", 0) > 0
	var entangled: bool = silenced and (not cursed or enemy.get("entangle_dot_turns_left", 0) > 0)
	var rooted: bool = enemy.get("root_turns_left", 0) > 0 or _is_column_ice_shards_blocked(enemy["pos_index"])
	var overgrown: bool = enemy.get("overgrowth_dot_turns_left", 0) > 0

	if entangled:
		effects.append("Entangled")
	elif rooted and not overgrown:
		# Overgrowth's own root already gets its own label below - so
		# only fall back to plain "Rooted" when nothing more specific
		# (Entangle, Overgrowth) is already covering it.
		effects.append("Rooted")
	if silenced:
		effects.append("Silenced")
	if cursed:
		effects.append("Cursed")
	if enemy.get("cold_feet_dot_turns_left", 0) > 0:
		effects.append("Cold Feet")
	if enemy.get("ice_vortex_dot_turns_left", 0) > 0:
		effects.append("Ice Vortex")
	if enemy.get("ice_blast_dot_turns_left", 0) > 0:
		effects.append("Ice Blast")
	if enemy.get("frostbite_dot_turns_left", 0) > 0:
		effects.append("Frostbitten")
	if enemy.get("leech_seed_dot_turns_left", 0) > 0:
		effects.append("Leeched")
	if enemy.get("overgrowth_dot_turns_left", 0) > 0:
		effects.append("Overgrowth")

	return ", ".join(effects)


## Recomputes every enemy's HP/status label text and position from
## scratch - cheap enough to call from anywhere the enemy roster, any
## enemy's current_hp, pos_index, or status effects could have changed
## (spawning, dying, moving, taking damage, regenerating, a fresh
## debuff landing or an old one ticking off) rather than trying to
## track exactly which of those actually happened at each call site.
func _refresh_enemy_overhead_labels() -> void:
	var groups: Dictionary = {}
	for enemy in _enemies:
		var col: int = enemy["pos_index"]
		if not groups.has(col):
			groups[col] = []
		groups[col].append(enemy)

	for col in groups.keys():
		var group: Array = groups[col]

		# _get_enemy_at() is the same lookup melee attacks/ranged range-
		# checks already resolve a column against - whichever enemy it
		# returns here IS "the one being attacked" for this column, so
		# that's the one anchored at the bottom. Falls back to the
		# group's own first entry on the rare all-hidden case (see
		# _get_enemy_at()'s own is_target_hidden() skip), so the stack
		# still has *a* bottom rather than silently doing nothing.
		var front: Dictionary = _get_enemy_at(col)
		if front.is_empty():
			front = group[0]

		var ordered: Array = [front]
		for enemy in group:
			if not is_same(enemy, front):
				ordered.append(enemy)

		var front_node: Control = front["node"]
		var center_x: float = front_node.position.x + front_node.size.x / 2.0
		var base_y: float = front_node.position.y - ENEMY_HP_LABEL_GAP

		for i in range(ordered.size()):
			var enemy: Dictionary = ordered[i]
			var label: Label = enemy.get("hp_label")
			if label == null:
				continue

			var is_boss: bool = enemy["static"].get("is_hero_fight_boss", false)
			var max_hp: float = _enemy_hero_effective_max_hp(enemy) if is_boss else float(enemy["static"].get("hp", 1))
			var current_hp: float = maxf(0.0, float(enemy.get("current_hp", 0)))
			label.text = "%d / %d" % [roundi(current_hp), maxi(1, roundi(max_hp))]

			label.add_theme_color_override("font_color", ENEMY_HERO_HP_LABEL_COLOR if is_boss else ENEMY_HP_LABEL_COLOR)
			label.add_theme_font_size_override("font_size", ENEMY_HERO_HP_LABEL_FONT_SIZE if is_boss else ENEMY_HP_LABEL_FONT_SIZE)

			var slot_bottom: float = base_y - float(i) * (ENEMY_HP_LABEL_HEIGHT + ENEMY_HP_LABEL_GAP)
			var label_top: float = slot_bottom - ENEMY_HP_LABEL_HEIGHT
			label.position = Vector2(center_x - ENEMY_HP_LABEL_WIDTH / 2.0, label_top)

			var status_label: Label = enemy.get("status_label")
			if status_label != null:
				var status_text: String = _enemy_status_effect_text(enemy)
				status_label.visible = status_text != ""
				if status_label.visible:
					status_label.text = status_text
					status_label.position = Vector2(label.position.x + ENEMY_HP_LABEL_WIDTH + ENEMY_STATUS_LABEL_GAP, label_top)


## Called every REINFORCEMENT_INTERVAL/REINFORCEMENT_REPEAT_INTERVAL
## turns the current stage/fight isn't cleared yet. Spawns a wave sized
## by GameManager.get_reinforcement_enemy_counts(_current_stage) - a
## smaller top-up than that same stage's own opening STAGE_ENEMY_COUNTS
## - built the exact same way _load_enemies() builds a stage's opening
## wave (_spawn_stage_enemies(), which bakes in _build_stage_enemy_def()'s
## hp/damage/gold scaling for _current_stage), so reinforcements always
## come in at the stats of whatever's currently on the field rather
## than unscaled base stats.
## A hero fight is the one exception: rather than the usual smaller
## top-up, it throws the FULL stage 3 composition (STAGE_ENEMY_COUNTS,
## not REINFORCEMENT_ENEMY_COUNTS) at the player every time - a boss
## fight already means business, so its own reinforcements should hit
## as hard as an entire fresh stage 3 wave rather than a token trickle.
## _current_stage stays at MAX_ZONE_STAGE throughout a hero fight, same
## as everywhere else that reads it, so the stat scaling still lines up
## either way.
func _spawn_reinforcements() -> void:
	var zone_data: Dictionary = GameManager.get_selected_zone()
	var enemy_defs: Array = zone_data.get("enemies", [])

	var mele_templates: Array = []
	var range_templates: Array = []
	for enemy_def in enemy_defs:
		if enemy_def.get("type", "") == "range":
			range_templates.append(enemy_def)
		else:
			mele_templates.append(enemy_def)

	var counts: Dictionary = GameManager.get_stage_enemy_counts(_current_stage) if _in_hero_fight else GameManager.get_reinforcement_enemy_counts(_current_stage)
	var mele_count: int = int(counts.get("mele", 0))
	var range_count: int = int(counts.get("range", 0))

	_spawn_stage_enemies(mele_templates, mele_count)
	_spawn_stage_enemies(range_templates, range_count)

	if (not mele_templates.is_empty() and mele_count > 0) or (not range_templates.is_empty() and range_count > 0):
		_show_message_over_hero("Reinforcements arrived!")
		_tutorial_maybe_explain_reinforcements()
		_tutorial_maybe_advance_stage3_for_reinforcements()


## Only items that are actually consumed by use (heal/mana potions)
## show up as clickable battle actions - equipment-type items ("stat"
## effect, like Blades of Attack or Gauntlets of Strength) apply their
## bonus passively just by being in the inventory (see PlayerManager.
## get_inventory_stat_bonus) and are managed from the Shop instead.
## Shows every occupied inventory slot (PlayerManager caps this at 6,
## matching the panel's 3x2 grid, so nothing is ever hidden). Only
## consumables (heal/mana effect) are clickable battle actions -
## equipment ("stat" effect, like Blades of Attack) is shown so it's
## visible in the inventory, but stays disabled since it applies its
## bonus passively just by being held (see PlayerManager.
## get_inventory_stat_bonus) rather than being "used".
func _populate_item_grid() -> void:
	var slots: Array = PlayerManager.get_inventory_slots()
	var buttons: Array = items_grid.get_children()

	for i in buttons.size():
		var btn: Button = buttons[i]

		# Clear any previous connection before rebinding - otherwise
		# repeated refreshes stack up multiple connections on the
		# same button, each bound to a stale item_id.
		for connection in btn.pressed.get_connections():
			btn.pressed.disconnect(connection["callable"])

		if i < slots.size():
			var slot: Dictionary = slots[i]
			var item_id: String = slot["item_id"]
			var count: int = slot["count"]
			var item_data: Dictionary = GameManager.get_item(item_id)
			var image_path: String = item_data.get("image", "")
			var effect: String = item_data.get("effect", "")
			var is_consumable: bool = effect == "heal" or effect == "mana"

			btn.icon = load(image_path) if (image_path != "" and ResourceLoader.exists(image_path)) else null
			btn.text = "x" + str(count) if count > 1 else ""

			if is_consumable:
				btn.mouse_filter = Control.MOUSE_FILTER_STOP
				# Items are locked out for as long as Cold Embrace is
				# active on the hero (see _cold_embrace_active), or while
				# he's stunned/frozen (_player_stun_turns_left > 0 - set
				# by Torrent's/Pounce's/Ice Blast's/Frostbite's/Winter's
				# Curse's own stun, whether cast by the player or a rival
				# hero) - a stunned hero loses the turn entirely, same as
				# a stunned enemy loses its own (see _enemy_turn()'s stun
				# check), so there's nothing left for him to spend it on.
				btn.disabled = _battle_over or _has_acted_this_turn or _cold_embrace_active or _player_stun_turns_left > 0 or _mortimer_kisses_active
				btn.pressed.connect(_on_item_pressed.bind(item_id))
				# Lets _apply_tutorial_gate() find this button again by
				# item id without needing its own tracking dict, the way
				# _skill_buttons already does for skills.
				btn.set_meta("tutorial_item_id", item_id)
			else:
				# Equipment is passive, not clickable - but `disabled`
				# also dims the icon in Godot's default theme, which
				# would make owned gear look faded/less visible than a
				# potion. Blocking input via mouse_filter instead keeps
				# it fully bright while still being unclickable.
				btn.disabled = false
				btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
				btn.set_meta("tutorial_item_id", "")
		else:
			btn.icon = null
			btn.text = ""
			btn.disabled = true
			btn.mouse_filter = Control.MOUSE_FILTER_STOP
			btn.set_meta("tutorial_item_id", "")


func _refresh_gold_label() -> void:
	gold_value_label.text = str(PlayerManager.get_gold())


func _on_item_pressed(item_id: String) -> void:
	if _battle_over or _has_acted_this_turn or _cold_embrace_active or _player_stun_turns_left > 0 or _mortimer_kisses_active:
		return
	if not PlayerManager.use_item(item_id):
		return

	var item_data: Dictionary = GameManager.get_item(item_id)
	var effect: String = item_data.get("effect", "")
	var value: float = float(item_data.get("value", 0))

	match effect:
		"heal":
			heal(value)
		"mana":
			restore_mana(value)

	if TutorialManager.is_active and TutorialManager.current_stage == 3:
		if _tutorial_stage3_step == "heal_up" and item_id == "health":
			_advance_tutorial_stage3_step("attack_to_level_up")
		elif _tutorial_stage3_step == "need_mana_potion" and item_id == "mana":
			_advance_tutorial_stage3_step("cast_ultimate_ready")

	_mark_turn_used()


func _build_bar_styles() -> void:
	var hp_fill := StyleBoxFlat.new()
	hp_fill.bg_color = Color(0.8, 0.15, 0.15, 1)
	hp_fill.set_corner_radius_all(4)
	hp_bar.add_theme_stylebox_override("fill", hp_fill)

	var mana_fill := StyleBoxFlat.new()
	mana_fill.bg_color = Color(0.2, 0.4, 0.9, 1)
	mana_fill.set_corner_radius_all(4)
	mana_bar.add_theme_stylebox_override("fill", mana_fill)

	var xp_fill := StyleBoxFlat.new()
	xp_fill.bg_color = Color(0.95, 0.65, 0.1, 1)
	xp_fill.set_corner_radius_all(4)
	xp_bar.add_theme_stylebox_override("fill", xp_fill)

	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.1, 0.1, 0.1, 0.7)
	bg_style.set_corner_radius_all(4)
	hp_bar.add_theme_stylebox_override("background", bg_style)
	mana_bar.add_theme_stylebox_override("background", bg_style)
	xp_bar.add_theme_stylebox_override("background", bg_style)


func _refresh_bars() -> void:
	# Re-read from PlayerManager each time so bars always reflect the
	# saved values, even if damage/xp were applied elsewhere.
	_recruited = PlayerManager.get_recruited_hero()
	var stats: Dictionary = _recruited.get("stats", {})

	# Essence Shift's borrowed hp/mana, and True Form's bonus hp while
	# it's active, show up as extra max here - a battle-local display
	# bonus only, never written back to PlayerManager (see
	# _essence_shift_bonus/_true_form_bonus_hp).
	hp_bar.max_value = _hero_max_hp()
	hp_bar.value = _recruited.get("current_hp", 0)
	hp_value_label.text = str(int(hp_bar.value)) + "/" + str(int(hp_bar.max_value))

	mana_bar.max_value = float(stats.get("mana", 1)) + _essence_shift_bonus.get("mana", 0.0) - _player_essence_shift_penalty.get("mana", 0.0)
	mana_bar.value = _recruited.get("current_mana", 0)
	mana_value_label.text = str(int(mana_bar.value)) + "/" + str(int(mana_bar.max_value))

	# hero_xp tracks progress within the current level (see
	# PlayerManager.check_level_up), so the bar always fills from 0 up
	# to whatever the current level requires - no lifetime-total math.
	var xp_required: int = GameManager.get_xp_required_for_level(PlayerManager.get_level())
	if xp_required <= 0:
		# Max level - nothing further to progress toward, show a full bar.
		xp_bar.max_value = 1.0
		xp_bar.value = 1.0
		xp_value_label.text = "MAX"
	else:
		xp_bar.max_value = float(xp_required)
		xp_bar.value = clamp(_recruited.get("xp", 0), 0.0, float(xp_required))
		xp_value_label.text = str(int(xp_bar.value)) + "/" + str(int(xp_bar.max_value))

	# HP just changed (or at least might have) - re-check Savage
	# Roar's on/off state against the fresh numbers above.
	_update_savage_roar_state()

	_refresh_status_effects()
	_refresh_entangle_tints()
	_refresh_cold_feet_frost()

	# Called this pervasively (after nearly every action/tick in the
	# game - see _refresh_bars()'s own many call sites) so an enemy's
	# HP number stays current after damage/regen/potions too, not just
	# the movement/spawn/death paths that already call this directly.
	_refresh_enemy_overhead_labels()


## Keeps the "reserved HP" danger-zone marker and the three status
## badges (frost/curse/root) in sync with whatever's currently on the
## player - called every time _refresh_bars() is (i.e. constantly), so
## each one just reflects current state rather than being toggled from
## every individual cast/tick/dispel site.
func _refresh_status_effects() -> void:
	# Ice Blast's execute mechanic (see _tick_player_turn_start_effects())
	# reserves execute_pct of the player's OWN max HP as a fixed danger
	# zone near the bottom of the bar, not a chunk of current HP - so
	# this is a static width fraction of the bar, not tied to hp_bar's
	# own value.
	var reserving: bool = _player_ice_blast_execute_pct > 0.0 and _player_ice_blast_dot_turns_left > 0
	ice_blast_reserve_overlay.visible = reserving
	if reserving:
		ice_blast_reserve_overlay.anchor_right = clampf(_player_ice_blast_execute_pct, 0.0, 1.0)

	var frost_active: bool = _player_ice_blast_dot_turns_left > 0 or _player_frostbite_dot_turns_left > 0 \
		or _player_cold_feet_dot_turns_left > 0 or _player_ice_vortex_dot_turns_left > 0 \
		or _player_winters_curse_active
	_set_status_icon_visible(frost_status_icon, frost_active)

	var curse_active: bool = _player_curse_active or _player_entangle_dot_turns_left > 0
	_set_status_icon_visible(curse_status_icon, curse_active)

	var root_active: bool = _player_root_turns_left > 0 or _player_silence_turns_left > 0 or _player_stun_turns_left > 0
	_set_status_icon_visible(root_status_icon, root_active)

	# The frost skills' own ambient reminder - a persistent tint while
	# any of Winter's Curse/Frostbite/Ice Blast's own effects are still
	# on the player, fading out the instant they all are (a win, a
	# flee, or the effect just running out all reach this the same way
	# - every one of them already ends up back through _refresh_bars()).
	var target_alpha: float = 0.24 if frost_active else 0.0
	if not is_equal_approx(ambient_tint_overlay.color.a, target_alpha):
		var tween := create_tween()
		tween.tween_property(ambient_tint_overlay, "color:a", target_alpha, 0.35)


## Toggles one of the three HP-bar status badges, playing a quick
## pop-in scale bounce the moment it switches from hidden to shown so
## a newly-applied effect catches the eye instead of just silently
## appearing - easy to miss otherwise at this size, tucked next to the
## HP bar. A no-op re-call while already in the target state (the
## common case, since this runs on every _refresh_bars()) doesn't
## replay the bounce.
func _set_status_icon_visible(icon: PanelContainer, should_be_visible: bool) -> void:
	if icon.visible == should_be_visible:
		return

	icon.visible = should_be_visible
	if not should_be_visible:
		return

	icon.pivot_offset = icon.size / 2.0
	icon.scale = Vector2(0.3, 0.3)
	var tween := create_tween()
	tween.tween_property(icon, "scale", Vector2(1.25, 1.25), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(icon, "scale", Vector2.ONE, 0.1)


func _populate_skill_buttons() -> void:
	for child in skill_buttons_container.get_children():
		child.queue_free()
	_skill_buttons.clear()
	_skill_cooldown_labels.clear()
	_savage_roar_status_label = null

	var skills: Array = _hero_static.get("skills", [])
	var learned_skills: Dictionary = _recruited.get("learned_skills", {})

	for skill in skills:
		var skill_id: String = skill.get("id", "")
		var learned_level: int = learned_skills.get(skill_id, 0)
		var is_passive: bool = skill.get("type", "") == "passive"
		# Borrowed Time is the one skill that's neither: a real
		# ("ultimate") level track and mana cost, but never clicked -
		# it auto-activates off the hero's own HP% (see
		# _maybe_auto_activate_borrowed_time()) same as a passive would.
		var is_auto_activate: bool = skill.get("auto_activate", false)

		var slot := VBoxContainer.new()
		slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot.add_theme_constant_override("separation", 2)

		# Rows 1-2: the skill's name, split across two lines (see
		# _skill_name_button_text()) so a multi-word name doesn't get
		# clipped or force the slot wider than its neighbors.
		var btn := Button.new()
		btn.text = _skill_name_button_text(skill.get("name", "Skill"))
		btn.custom_minimum_size = Vector2(0, 50)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		# Row 3: mana cost, just the number - blank for a skill with no
		# point in it yet, since there's no level data behind it to make
		# a mana cost (or a Ready/Passive status, below) mean anything
		# yet; it's not "castable at this cost", it's not learned at all.
		var mana_label := Label.new()
		mana_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mana_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
		mana_label.add_theme_constant_override("outline_size", 2)
		mana_label.add_theme_font_size_override("font_size", 12)
		mana_label.add_theme_color_override("font_color", Color(0.4, 0.7, 1, 1))
		if not is_passive and learned_level > 0:
			var mana_level_data: Dictionary = GameManager.get_skill_level_data(skill, learned_level)
			var mana_cost: float = float(mana_level_data.get("mana_cost", skill.get("mana_cost", 0)))
			mana_label.text = str(int(mana_cost))

		# Row 4: ready/cooldown status.
		var status_label := Label.new()
		status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		status_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
		status_label.add_theme_constant_override("outline_size", 2)
		status_label.add_theme_font_size_override("font_size", 12)

		if learned_level <= 0:
			# No skill point spent here yet - leave both labels blank
			# (mana above, status here) and the button disabled; there's
			# nothing "Ready" or "Passive" about a skill that isn't
			# learned at all.
			btn.disabled = true
		elif is_passive:
			# Passives (currently just Savage Roar and Curse of
			# Avernus) apply themselves automatically rather than
			# being cast - no click, no mana, no cooldown. The label
			# instead shows whether its effect is live right now (see
			# _update_savage_roar_state) or just "Passive" as a
			# default for one with no such live state to report.
			btn.disabled = true
			status_label.text = "Passive"
			status_label.add_theme_color_override("font_color", Color(0.7, 0.8, 1, 1))
		elif is_auto_activate:
			# Never clickable, same as a passive, but it DOES have a
			# real cooldown - tracked and ticked exactly like a
			# manually-cast skill's (see _skill_cooldown_labels/
			# _skill_cooldowns below), just started by
			# _maybe_auto_activate_borrowed_time() instead of a button
			# press. _refresh_skill_cooldown_labels() overlays "Active"
			# on top of the normal Ready/cooldown text while it's
			# actually in effect.
			btn.disabled = true
			status_label.text = "Ready"
			status_label.add_theme_color_override("font_color", Color(0.5, 1, 0.5, 1))
		else:
			btn.disabled = false
			btn.pressed.connect(_on_skill_pressed.bind(skill))
			status_label.text = "Ready"
			status_label.add_theme_color_override("font_color", Color(0.5, 1, 0.5, 1))

		slot.add_child(btn)
		slot.add_child(mana_label)
		slot.add_child(status_label)
		skill_buttons_container.add_child(slot)

		if learned_level > 0:
			if is_passive:
				if skill_id == "savage_roar":
					_savage_roar_status_label = status_label
			else:
				_skill_cooldown_labels[skill_id] = status_label
				# Cooldowns persist across battles (see PlayerManager.
				# get_skill_cooldown/set_skill_cooldown), so a skill used
				# near the end of one fight stays locked into the next.
				_skill_cooldowns[skill_id] = PlayerManager.get_skill_cooldown(skill_id)

				# Borrowed Time is never added to _skill_buttons - that
				# dict drives _update_action_buttons()'s per-turn lock,
				# which would re-enable its button (nothing handles a
				# click on it) the moment the hero hasn't acted yet.
				if not is_auto_activate:
					_skill_buttons[skill_id] = btn

	_refresh_skill_cooldown_labels()
	_update_savage_roar_state()


## Splits a skill's name across two lines for its button - the first
## word on its own line, every word after it on the second - so a
## multi-word name (e.g. "Summon Spirit Bear") doesn't get clipped or
## force its slot wider than its single-word neighbors (e.g. "Pounce").
## A one-word name is returned as-is, with no second line.
func _skill_name_button_text(skill_name: String) -> String:
	var space_index: int = skill_name.find(" ")
	if space_index == -1:
		return skill_name
	return skill_name.substr(0, space_index) + "\n" + skill_name.substr(space_index + 1)


func _on_skill_pressed(skill: Dictionary) -> void:
	if _battle_over or _has_acted_this_turn:
		return

	if _cold_embrace_active:
		_show_message_over_hero("Encased in ice!")
		return

	if _mortimer_kisses_active:
		_show_message_over_hero("Focused on Mortimer Kisses!")
		return

	if _player_silence_turns_left > 0:
		_show_message_over_hero("Silenced!")
		return

	var skill_id: String = skill.get("id", "")
	if _skill_cooldowns.get(skill_id, 0) > 0:
		return

	var skill_level: int = PlayerManager.get_skill_level(skill_id)
	if skill_level <= 0:
		return

	var level_data: Dictionary = GameManager.get_skill_level_data(skill, skill_level)

	# Mana cost lives per-level now (like every other per-level number),
	# so it can be tuned per level - skill.get() is only a fallback for
	# a skill that hasn't been given a "levels" array at all.
	var mana_cost: float = float(level_data.get("mana_cost", skill.get("mana_cost", 0)))
	if _recruited.get("current_mana", 0) < mana_cost:
		_show_message_over_hero("Not enough mana")
		if TutorialManager.is_active and TutorialManager.current_stage == 3 \
		and skill_id == "ghostship" and _tutorial_stage3_step == "cast_ultimate":
			_advance_tutorial_stage3_step("need_mana_potion")
		return

	var generation_before: int = _stage_generation

	match skill_id:
		"pounce":
			if not _cast_pounce(level_data):
				# No target found - nothing happened, so don't spend
				# mana, the turn, or start the cooldown.
				return
		"dark_pact":
			if not _cast_dark_pact(level_data):
				# No enemies in range - same as above, no-op.
				return
		"whirling_death":
			if not _cast_whirling_death(level_data):
				# No enemies in range - same as above, no-op.
				return
		"scatterblast":
			if not _cast_scatterblast(level_data):
				# No enemies in range - same as above, no-op.
				return
		"firesnap_cookie":
			_activate_firesnap_cookie(level_data)
		"lil_shredder":
			if not _start_lil_shredder_targeting(level_data):
				# No enemy in range - nothing happened, same as above.
				return
			# Same deferred-spend pattern as every other targeted skill
			# above - the mana/cooldown/turn spend happens once the
			# click resolves (_resolve_lil_shredder_cast), not here.
			return
		"mortimer_kisses":
			if not _start_mortimer_kisses_targeting(level_data):
				# No enemy in range - nothing happened, same as above.
				return
			# Same deferred-spend pattern as every other targeted skill
			# above - the mana/cooldown/turn spend happens once the
			# click resolves (_resolve_mortimer_kisses_cast), not here.
			return
		"mirror_image":
			_activate_mirror_image(level_data)
		"guardian_sprint":
			_activate_guardian_sprint(level_data)
		"slithereen_crush":
			if not _cast_slithereen_crush(level_data):
				# No enemies in range - same as above, no-op.
				return
		"starstorm":
			if not _cast_starstorm(level_data):
				# No enemies in range - same as above, no-op.
				return
		"sacred_arrow":
			if not _start_sacred_arrow_targeting(level_data):
				# No enemy in range - nothing happened, same as above.
				return
			# Same deferred-spend pattern as every other targeted skill
			# above - the mana/cooldown/turn spend happens once the
			# click resolves (_resolve_sacred_arrow_cast), not here.
			return
		"lucent_beam":
			if not _start_lucent_beam_targeting(level_data):
				# No enemy in range - nothing happened, same as above.
				return
			# Same deferred-spend pattern as every other targeted skill
			# above - the mana/cooldown/turn spend happens once the
			# click resolves (_resolve_lucent_beam_cast), not here.
			return
		"eclipse":
			_activate_eclipse(level_data)
		"leap":
			_activate_leap(level_data)
		"moonlight_shadow":
			_activate_moonlight_shadow(level_data)
		"corrosive_haze":
			if not _start_corrosive_haze_targeting(level_data):
				# No enemy in range - nothing happened, same as above.
				return
			# Same deferred-spend pattern as every other targeted skill
			# above - the mana/cooldown/turn spend happens once the
			# click resolves (_resolve_corrosive_haze_cast), not here.
			return
		"ensnare":
			if not _start_ensnare_targeting(level_data):
				# No enemy in range - nothing happened, same as above.
				return
			# Same deferred-spend pattern as every other targeted skill
			# above - the mana/cooldown/turn spend happens once the
			# click resolves (_resolve_ensnare_cast), not here.
			return
		"song_of_the_siren":
			if not _cast_song_of_the_siren(level_data):
				# No enemies in range - same as above, no-op.
				return
		"timber_chain":
			if not _start_timber_chain_targeting(level_data):
				# No enemy in range - nothing happened, same as above.
				return
			# Same deferred-spend pattern as every other targeted skill
			# above - the mana/cooldown/turn spend happens once the
			# click resolves (_resolve_timber_chain_cast), not here.
			return
		"chakram":
			if not _start_chakram_targeting(level_data):
				# No enemy in range - nothing happened, same as above.
				return
			# Same deferred-spend pattern as every other targeted skill
			# above - the mana/cooldown/turn spend happens once the
			# click resolves (_resolve_chakram_cast), not here.
			return
		"mist_coil":
			_start_mist_coil_targeting(level_data)
			# Mist Coil needs the player to click a target first - an
			# enemy to damage, or the hero's own portrait to heal
			# himself - so the mana/cooldown/turn spend happens once
			# that click resolves (_resolve_mist_coil_enemy_cast()/
			# _resolve_mist_coil_self_cast()), not here. Bail out of
			# this function without falling through to the shared
			# spend logic below, same as Entangle.
			return
		"essence_shift":
			_activate_essence_shift(level_data)
		"shadow_dance":
			_activate_shadow_dance(level_data)
		"nature's_guise":
			_activate_natures_guise(level_data)
		"arctic_burn":
			_activate_arctic_burn(level_data)
		"cold_embrace":
			_activate_cold_embrace(level_data)
		"summon_spirit_bear":
			_summon_spirit_bear(level_data)
		"spirit_link":
			_activate_spirit_link(level_data)
		"true_form":
			_activate_true_form(level_data)
		"aphotic_shield":
			_activate_aphotic_shield(level_data)
		"entangle":
			if not _start_entangle_targeting(level_data):
				# No enemy in range - nothing happened, so don't spend
				# mana, the turn, or start the cooldown, same as above.
				return
			# Entangle needs the player to click a target first - the
			# mana/cooldown/turn spend below happens once that click
			# resolves (_resolve_entangle_cast), not here, so bail out
			# of this function without falling through to it.
			return
		"torrent":
			if not _start_torrent_targeting(level_data):
				# No enemy in range - nothing happened, same as above.
				return
			# Same deferred-spend pattern as Entangle/Mist Coil - the
			# mana/cooldown/turn spend happens once the click resolves
			# (_resolve_torrent_cast), not here.
			return
		"x_marks_the_spot":
			if not _start_xmarks_targeting(level_data):
				# No enemy in range - nothing happened, same as above.
				return
			# Same deferred-spend pattern as every other targeted skill
			# above - the mana/cooldown/turn spend happens once the
			# click resolves (_resolve_xmarks_cast), not here.
			return
		"ghostship":
			if not _start_ghostship_targeting(level_data):
				# No enemy in range - nothing happened, same as above.
				return
			# Same deferred-spend pattern as every other targeted skill
			# above - the mana/cooldown/turn spend happens once the
			# click resolves (_resolve_ghostship_cast), not here.
			return
		"cold_feet":
			if not _start_cold_feet_targeting(level_data):
				# No enemy in range - nothing happened, same as above.
				return
			# Same deferred-spend pattern as every other targeted skill
			# above - the mana/cooldown/turn spend happens once the
			# click resolves (_resolve_cold_feet_cast), not here.
			return
		"ice_vortex":
			if not _start_ice_vortex_targeting(level_data):
				# No enemy in range - nothing happened, same as above.
				return
			# Same deferred-spend pattern as every other targeted skill
			# above - the mana/cooldown/turn spend happens once the
			# click resolves (_resolve_ice_vortex_cast), not here.
			return
		"chilling_touch":
			if not _start_chilling_touch_targeting(level_data):
				# No enemy in range - nothing happened, same as above.
				return
			# Same deferred-spend pattern as every other targeted skill
			# above - the mana/cooldown/turn spend happens once the
			# click resolves (_resolve_chilling_touch_cast), not here.
			return
		"ice_blast":
			if not _start_ice_blast_targeting(level_data):
				# No living enemy anywhere on the field - nothing
				# happened, same as above.
				return
			# Same deferred-spend pattern as every other targeted skill
			# above - the mana/cooldown/turn spend happens once the
			# click resolves (_resolve_ice_blast_cast), not here.
			return
		"splinter_blast":
			if not _start_splinter_blast_targeting(level_data):
				# No enemy in range - nothing happened, same as above.
				return
			# Same deferred-spend pattern as every other targeted skill
			# above - the mana/cooldown/turn spend happens once the
			# click resolves (_resolve_splinter_blast_cast), not here.
			return
		"winter's_curse":
			if not _start_winters_curse_targeting(level_data):
				# No enemy in range - nothing happened, same as above.
				return
			# Same deferred-spend pattern as every other targeted skill
			# above - the mana/cooldown/turn spend happens once the
			# click resolves (_resolve_winters_curse_cast), not here.
			return
		"crystal_nova":
			if not _start_crystal_nova_targeting(level_data):
				# No enemy in range - nothing happened, same as above.
				return
			# Same deferred-spend pattern as every other targeted skill
			# above - the mana/cooldown/turn spend happens once the
			# click resolves (_resolve_crystal_nova_cast), not here.
			return
		"frostbite":
			if not _start_frostbite_targeting(level_data):
				# No enemy in range - nothing happened, same as above.
				return
			# Same deferred-spend pattern as every other targeted skill
			# above - the mana/cooldown/turn spend happens once the
			# click resolves (_resolve_frostbite_cast), not here.
			return
		"freezing_field":
			_activate_freezing_field(level_data)
		"ice_shards":
			if not _start_ice_shards_targeting(level_data):
				# No enemy in range - nothing happened, same as above.
				return
			# Same deferred-spend pattern as every other targeted skill
			# above - the mana/cooldown/turn spend happens once the
			# click resolves (_resolve_ice_shards_cast), not here.
			return
		"snowball":
			if not _start_snowball_targeting(level_data):
				# No enemy in range - nothing happened, same as above.
				return
			# Same deferred-spend pattern as every other targeted skill
			# above - the mana/cooldown/turn spend happens once the
			# click resolves (_resolve_snowball_cast), not here.
			return
		"tag_team":
			_activate_tag_team(level_data)
		"walrus_punch":
			if not _start_walrus_punch_targeting(level_data):
				# No enemy in range - nothing happened, same as above.
				return
			# Same deferred-spend pattern as every other targeted skill
			# above - the mana/cooldown/turn spend happens once the
			# click resolves (_resolve_walrus_punch_cast), not here.
			return
		"leech_seed":
			if not _start_leech_seed_targeting(level_data):
				# No enemy in range - nothing happened, same as above.
				return
			# Same deferred-spend pattern as every other targeted skill
			# above - the mana/cooldown/turn spend happens once the
			# click resolves (_resolve_leech_seed_cast), not here.
			return
		"living_armor":
			_activate_living_armor(level_data)
		"overgrowth":
			_activate_overgrowth(level_data)
		_:
			# No effect implemented yet for other skills - this is the
			# hook point for when they're added. For now it just
			# confirms the wiring works end to end.
			print("Used skill: ", skill.get("name", ""))

	# Shadow Dance/Nature's Guise/Moonlight Shadow only break from
	# attacking or casting ANOTHER skill - not from the cast that just
	# activated them in the first place, and not from items/potions
	# (those never reach this function at all). Only one of the three
	# could ever be active in a given battle (different heroes' own
	# kits), so this just ends whichever one actually is.
	if _is_hero_hidden() and skill_id != "shadow_dance" and skill_id != "nature's_guise" and skill_id != "moonlight_shadow":
		if _shadow_dance_active:
			_end_shadow_dance()
		elif _natures_guise_active:
			_end_natures_guise()
		elif _moonlight_shadow_active:
			_end_moonlight_shadow()

	spend_mana(mana_cost)
	_skill_cooldowns[skill_id] = int(level_data.get("cooldown", 0))
	PlayerManager.set_skill_cooldown(skill_id, _skill_cooldowns[skill_id])
	_refresh_skill_cooldown_labels()

	# If that cast cleared the stage (or won a hero fight) and a fresh
	# encounter started, the turn lock has already been reset for it -
	# re-locking it here would carry the old turn's "used" state into
	# an encounter that hasn't had a turn yet. The cooldown/mana spend
	# above still applies regardless.
	if _battle_over or _stage_generation != generation_before:
		return

	_mark_turn_used()


## Slark's Pounce: leaps `level_data.distance` columns toward the
## nearest enemy - overriding the hero's normal speed-based move
## distance - and stops early if it lands on an enemy's column along
## the way. That enemy takes a standard attack and gets stunned for
## `level_data.stun_turns` of its own turns (see the "stun_turns_left"
## counter checked at the top of each enemy's turn in _enemy_turn()).
## Returns false (leaving position/turn untouched) if there's no
## enemy anywhere to leap toward.
func _cast_pounce(level_data: Dictionary) -> bool:
	if _enemies.is_empty():
		_show_message_over_hero("No target for Pounce")
		return false

	var nearest: Dictionary = {}
	var nearest_distance: int = GRID_COLUMNS + 1
	for enemy in _enemies:
		var d: int = _distance(enemy["pos_index"], _hero_pos_index)
		if d < nearest_distance:
			nearest_distance = d
			nearest = enemy

	var direction: int = _step_toward(_hero_pos_index, nearest["pos_index"])
	if direction == 0:
		# Already sharing the enemy's column - still leap somewhere
		# rather than doing nothing.
		direction = 1

	var move_distance: int = int(level_data.get("distance", 2))
	var pos: int = _hero_pos_index
	var hit_enemy: Dictionary = {}

	for i in range(move_distance):
		var next_pos: int = pos + direction
		if next_pos < 0 or next_pos >= GRID_COLUMNS:
			break
		# A rival's Ice Shards wall stops the leap dead - it can't carry
		# the hero past a blocked column, same "can't step into one"
		# rule _melee_move_target()/_ranged_move_target() already
		# enforce for a normal move.
		if _is_column_enemy_ice_shards_blocked(next_pos):
			break
		pos = next_pos

		var enemy_here: Dictionary = _get_enemy_at(pos)
		if not enemy_here.is_empty():
			hit_enemy = enemy_here
			break

	_hero_pos_index = pos
	_update_hero_position()

	if not hit_enemy.is_empty():
		_deal_damage_to_enemy(hit_enemy)
		# Only stun if it survived the hit - a dead enemy has already
		# been removed from _enemies by _deal_damage_to_enemy's kill check.
		if hit_enemy.get("current_hp", 0) > 0:
			hit_enemy["stun_turns_left"] = int(level_data.get("stun_turns", 1))

	return true


## Slark's Dark Pact: deals `level_data.damage_multiplier` of one
## rolled hero-damage hit to every enemy within `level_data.radius`
## columns of Slark (0 = only Slark's own column), each still
## mitigated by that enemy's own armor. All hits share the same
## rolled amount - it's one burst around Slark, not a separate attack
## roll per enemy. (Silencing enemies caught in it isn't implemented yet.)
## Returns false (no mana/turn/cooldown spent) if nothing is in range.
func _cast_dark_pact(level_data: Dictionary) -> bool:
	var radius: int = int(level_data.get("radius", 0))
	var targets: Array = []
	for enemy in _enemies:
		if _is_target_hidden(enemy):
			continue
		if _distance(enemy["pos_index"], _hero_pos_index) <= radius:
			targets.append(enemy)

	if targets.is_empty():
		_show_message_over_hero("No enemies in range")
		return false

	var multiplier: float = float(level_data.get("damage_multiplier", 0.75))
	var pact_damage: float = _roll_hero_damage() * multiplier
	for enemy in targets:
		_deal_fixed_damage_to_enemy(enemy, pact_damage)
		# Same red hit-flash as Moon Glaives' bounce, so every enemy
		# caught in the burst visibly reacts, not just via damage numbers.
		if is_instance_valid(enemy.get("node")):
			_flash_bounce_hit(enemy["node"])
	# Self-centered on the hero, same as the check above - a rival's own
	# illusion (Naga Siren's Mirror Image) can be in range independently
	# of whether the boss itself currently is.
	_deal_aoe_damage_to_enemy_illusions(_hero_pos_index, radius, pact_damage, true)

	return true


## Timbersaw's Whirling Death: deals `level_data.damage` (a flat amount,
## not a roll off the hero's own attack) to every enemy within
## `level_data.radius` columns of Timbersaw. Same shape as
## _cast_dark_pact() above, just with a flat damage value instead of a
## multiplier on a rolled hit. Returns false (no mana/turn/cooldown
## spent) if nothing is in range.
func _cast_whirling_death(level_data: Dictionary) -> bool:
	var radius: int = int(level_data.get("radius", 0))
	var targets: Array = []
	for enemy in _enemies:
		if _is_target_hidden(enemy):
			continue
		if _distance(enemy["pos_index"], _hero_pos_index) <= radius:
			targets.append(enemy)

	if targets.is_empty():
		_show_message_over_hero("No enemies in range")
		return false

	var whirling_damage: float = float(level_data.get("damage", 0))
	for enemy in targets:
		_deal_fixed_damage_to_enemy(enemy, whirling_damage)
	# Self-centered on the hero, same as the check above - a rival's own
	# illusion (Naga Siren's Mirror Image) can be in range independently
	# of whether the boss itself currently is.
	_deal_aoe_damage_to_enemy_illusions(_hero_pos_index, radius, whirling_damage)

	return true


## Slardar's Slithereen Crush: deals `level_data.damage` and stuns
## (target["stun_turns_left"], same shared field Pounce's/Torrent's own
## stun use) every enemy within `level_data.radius` columns of Slardar -
## same shape as _cast_whirling_death() above, just with a stun folded
## in and only ever stunning a hit that actually left the target alive.
## Returns false (no mana/turn/cooldown spent) if nothing is in range.
func _cast_slithereen_crush(level_data: Dictionary) -> bool:
	var radius: int = int(level_data.get("radius", 0))
	var targets: Array = []
	for enemy in _enemies:
		if _is_target_hidden(enemy):
			continue
		if _distance(enemy["pos_index"], _hero_pos_index) <= radius:
			targets.append(enemy)

	if targets.is_empty():
		_show_message_over_hero("No enemies in range")
		return false

	var crush_damage: float = float(level_data.get("damage", 0))
	var stun_turns: int = int(level_data.get("stun_turns", 0))
	for enemy in targets:
		_deal_fixed_damage_to_enemy(enemy, crush_damage)
		if enemy.get("current_hp", 0) > 0:
			enemy["stun_turns_left"] = stun_turns
	# Self-centered on the hero, same as the check above - a rival's own
	# illusion (Naga Siren's Mirror Image) can be in range independently
	# of whether the boss itself currently is. The rival's own Spirit
	# Bear needs no equivalent call - it's a genuine _enemies entry
	# (see _summon_enemy_spirit_bear()), so the `targets` loop above
	# already caught it, stun included.
	_deal_aoe_damage_to_enemy_illusions(_hero_pos_index, radius, crush_damage)

	return true


## Mirana's Starstorm: deals `level_data.damage` (a flat amount, not a
## roll off the hero's own attack) to every enemy within
## `level_data.radius` columns of Mirana - same shape as
## _cast_whirling_death()/_cast_slithereen_crush() above, just with no
## stun/CC folded in. Returns false (no mana/turn/cooldown spent) if
## nothing is in range.
func _cast_starstorm(level_data: Dictionary) -> bool:
	var radius: int = int(level_data.get("radius", 0))
	var targets: Array = []
	for enemy in _enemies:
		if _is_target_hidden(enemy):
			continue
		if _distance(enemy["pos_index"], _hero_pos_index) <= radius:
			targets.append(enemy)

	if targets.is_empty():
		_show_message_over_hero("No enemies in range")
		return false

	var starstorm_damage: float = float(level_data.get("damage", 0))
	for enemy in targets:
		_deal_fixed_damage_to_enemy(enemy, starstorm_damage)
	# Self-centered on the hero, same as the check above - a rival's own
	# illusion (Naga Siren's Mirror Image) can be in range independently
	# of whether the boss itself currently is. The rival's own Spirit
	# Bear needs no equivalent call - it's a genuine _enemies entry
	# (see _summon_enemy_spirit_bear()), so the `targets` loop above
	# already caught it.
	_deal_aoe_damage_to_enemy_illusions(_hero_pos_index, radius, starstorm_damage)

	return true


## Naga Siren's ultimate, Song of the Siren: stuns (target["stun_turns_
## left"], same shared field Pounce's/Torrent's/Firesnap Cookie's own
## stun use) and shreds the armor (target["armor_reduction"]/
## "armor_reduction_turns_left", the same per-instance runtime fields
## Lil' Shredder's own shred uses - stacking additively with any
## already on a target, but refreshing (not adding to) the turns left,
## same "reapplying overwrites the timer" convention every other
## refreshable debuff in this file uses) of every enemy within this
## level's own radius of the hero's CURRENT position, both for this
## level's own stun_turns. Purely offensive - no damage of its own, and
## nothing about the hero himself changes (he and his illusions can
## still move/attack normally the whole time, unlike Mortimer Kisses'
## own channel). Returns false (no mana/turn/cooldown spent) if nothing
## is in range.
func _cast_song_of_the_siren(level_data: Dictionary) -> bool:
	var radius: int = int(level_data.get("radius", 0))
	var targets: Array = []
	for enemy in _enemies:
		if _is_target_hidden(enemy):
			continue
		if _distance(enemy["pos_index"], _hero_pos_index) <= radius:
			targets.append(enemy)

	if targets.is_empty():
		_show_message_over_hero("No enemies in range")
		return false

	var stun_turns: int = int(level_data.get("stun_turns", 0))
	var armor_reduction: float = float(level_data.get("armor_reduction", 0))
	for enemy in targets:
		enemy["stun_turns_left"] = stun_turns
		enemy["armor_reduction"] = float(enemy.get("armor_reduction", 0.0)) + armor_reduction
		enemy["armor_reduction_turns_left"] = stun_turns

	_show_message_over_hero("Song of the Siren!")
	return true


## Snapfire's Scatterblast: fires straight in whatever direction she's
## currently facing (hero_image.flip_h, kept up to date by _hero_move()/
## every other repositioning skill that sets it), dealing
## level_data.damage to every enemy within level_data.range columns
## AHEAD of her in that direction only - unlike Whirling Death's/Dark
## Pact's own radius checks above, which look every direction at once,
## an enemy behind her (or sharing her own column) is never hit. Returns
## false (no mana/turn/cooldown spent) if nothing is in range.
func _cast_scatterblast(level_data: Dictionary) -> bool:
	var range_columns: int = int(level_data.get("range", 0))
	var direction: int = -1 if hero_image.flip_h else 1

	var targets: Array = []
	for enemy in _enemies:
		if _is_target_hidden(enemy):
			continue
		# 0 = sharing Snapfire's own column (point-blank - still in front
		# of the blast regardless of which way she's facing), up through
		# range_columns strictly ahead in her facing direction.
		var ahead: int = (enemy["pos_index"] - _hero_pos_index) * direction
		if ahead >= 0 and ahead <= range_columns:
			targets.append(enemy)

	if targets.is_empty():
		_show_message_over_hero("No enemies in range")
		return false

	var scatter_damage: float = float(level_data.get("damage", 0))
	for enemy in targets:
		_deal_fixed_damage_to_enemy(enemy, scatter_damage)
	# Same directional cone as the check above - a rival's own illusion
	# (Naga Siren's Mirror Image) ahead of the hero can be caught in it
	# independently of whether the boss itself currently is.
	_deal_directional_aoe_damage_to_enemy_illusions(_hero_pos_index, direction, range_columns, scatter_damage)

	_play_scatterblast_effect(hero_image, direction, range_columns)

	return true


## Purely cosmetic: a one-shot cone of particles bursting from
## `origin_node`'s own position out toward `direction` (+1 right, -1
## left), sized to travel roughly `range_columns` columns before
## fading - visualizes Scatterblast's blast, from whichever side cast
## it (the player's own hero_image, or a rival's own node). The damage
## above has already fully resolved by the time this plays; it never
## gates on this. First particle-based effect in this file - every
## other one-shot visual (Ghostship's flight, Spirit Bear's summon) is
## a plain TextureRect tween instead, since there's no shotgun-pellet
## art asset to tween in the same way.
func _play_scatterblast_effect(origin_node: Control, direction: int, range_columns: int) -> void:
	if not is_instance_valid(origin_node):
		return

	var lifetime: float = 0.35
	var travel_distance: float = _grid_unit() * maxf(1.0, float(range_columns))

	var particles := CPUParticles2D.new()
	particles.position = origin_node.position + origin_node.size / 2.0
	particles.emitting = false
	particles.one_shot = true
	particles.amount = 40
	particles.lifetime = lifetime
	particles.explosiveness = 1.0
	particles.direction = Vector2(direction, 0)
	particles.spread = 18.0
	particles.gravity = Vector2.ZERO
	particles.initial_velocity_min = travel_distance / lifetime * 0.7
	particles.initial_velocity_max = travel_distance / lifetime * 1.1
	particles.scale_amount_min = 4.0
	particles.scale_amount_max = 8.0
	particles.color = Color(1.0, 0.65, 0.15, 1.0)
	add_child(particles)
	# Same reasoning as _summon_spirit_bear()'s own move_child() call -
	# render at the hero/enemy layer, not on top of every UI panel.
	move_child(particles, enemies_layer.get_index() + 1)
	particles.emitting = true

	get_tree().create_timer(lifetime + 0.2).timeout.connect(particles.queue_free)


## Snapfire's Firesnap Cookie: hops level_data.jump_distance columns in
## whatever direction she's currently facing (hero_image.flip_h, same
## convention Scatterblast reads), same move-distance rules
## (board edge/Ice Shards wall, ranged-vs-melee straight-through-or-
## stop-on-enemy) as a normal move (see _hero_move()) - then, on
## landing, deals level_data.damage and stuns for level_data.stun_turns
## every enemy within level_data.radius columns of wherever she ends
## up, if any (there doesn't need to be one for the hop itself to
## happen - unlike Pounce, this never "fails" for lack of a target).
## Only stuns a hit enemy that's still alive - a dead one has already
## been removed from _enemies by _deal_fixed_damage_to_enemy's kill
## check.
func _activate_firesnap_cookie(level_data: Dictionary) -> void:
	var jump_distance: int = int(level_data.get("jump_distance", 0))
	var direction: int = -1 if hero_image.flip_h else 1

	if _is_ranged_hero():
		_hero_pos_index = _ranged_move_target(_hero_pos_index, direction, jump_distance)
	else:
		_hero_pos_index = _melee_move_target(_hero_pos_index, direction, jump_distance)
	_update_hero_position()

	var radius: int = int(level_data.get("radius", 0))
	var damage: float = float(level_data.get("damage", 0))
	var stun_turns: int = int(level_data.get("stun_turns", 0))
	for enemy in _enemies.duplicate():
		if _is_target_hidden(enemy):
			continue
		if _distance(enemy["pos_index"], _hero_pos_index) <= radius:
			_deal_fixed_damage_to_enemy(enemy, damage)
			if enemy.get("current_hp", 0) > 0:
				enemy["stun_turns_left"] = stun_turns
	# Centered on the landing spot, same as the check above - a rival's
	# own illusion (Naga Siren's Mirror Image) can be in range
	# independently of whether the boss itself currently is.
	_deal_aoe_damage_to_enemy_illusions(_hero_pos_index, radius, damage)


## Mirana's Leap: hops level_data.jump_distance columns in whatever
## direction she's currently facing (hero_image.flip_h, same convention
## Scatterblast/Firesnap Cookie already read) - unlike Firesnap Cookie's
## own hop, this ALWAYS sails clean over any enemy in the way regardless
## of range_type (the unobstructed "walk straight through" rule
## _ranged_move_target() already uses for a ranged hero, applied here
## even for a melee one), stopping only at the board edge or a rival's
## Ice Shards wall. No damage, no target required - always "succeeds",
## same as every other self-cast buff.
func _activate_leap(level_data: Dictionary) -> void:
	var jump_distance: int = int(level_data.get("jump_distance", 0))
	var direction: int = -1 if hero_image.flip_h else 1

	_hero_pos_index = _ranged_move_target(_hero_pos_index, direction, jump_distance)
	_update_hero_position()


## Resolves an Ensnare cast on `target`: `level_data.damage` (mitigated
## by the target's own armor via _deal_fixed_damage_to_enemy(), same
## helper Dark Pact/Torrent/Ghostship use) plus a root for this level's
## own `root_turns` - reusing _apply_root() with no `silence_turns`/
## `dot_damage`/`dot_duration` keys in `level_data` (all default to 0
## there), so unlike Entangle this only ever roots, never silences or
## burns - a rooted enemy can still attack and cast skills, just not
## move or jump (see _is_enemy_rooted()'s own call sites in
## _enemy_turn()/_enemy_hero_turn(), which only ever gate movement
## branches). Only roots if the hit actually left it alive.
func _resolve_ensnare_cast(target: Dictionary, level_data: Dictionary) -> void:
	var generation_before: int = _stage_generation

	var damage: float = float(level_data.get("damage", 0))
	_deal_fixed_damage_to_enemy(target, damage)
	if target.get("current_hp", 0) > 0:
		_apply_root(target, level_data)

	var mana_cost: float = float(level_data.get("mana_cost", 0))
	spend_mana(mana_cost)
	_skill_cooldowns["ensnare"] = int(level_data.get("cooldown", 0))
	PlayerManager.set_skill_cooldown("ensnare", _skill_cooldowns["ensnare"])
	_refresh_skill_cooldown_labels()

	if _battle_over or _stage_generation != generation_before:
		return

	_mark_turn_used()


## Resolves a Corrosive Haze cast on `target`: reduces its armor by
## this level's own `armor_reduction` (target["armor_reduction"], the
## same per-instance runtime field Lil' Shredder's own shred and Song
## of the Siren use - stacking additively with any already on it) and
## marks it with `bonus_damage_pct` (target["corrosive_haze_bonus_pct"],
## read by _deal_fixed_damage_to_enemy() to boost every hit it takes
## from the hero's own attacks/skills - overwritten outright on
## recast, not stacked, since a second mark isn't meant to double the
## vulnerability). Both share `duration`'s own turns-left counter
## (target["armor_reduction_turns_left"]) - see
## _tick_enemy_turn_start_effects()'s own comment on why that's fine to
## share with Lil' Shredder's shred. Deals no damage of its own - a
## pure debuff.
func _resolve_corrosive_haze_cast(target: Dictionary, level_data: Dictionary) -> void:
	var generation_before: int = _stage_generation

	target["armor_reduction"] = float(target.get("armor_reduction", 0.0)) + float(level_data.get("armor_reduction", 0))
	target["corrosive_haze_bonus_pct"] = float(level_data.get("bonus_damage_pct", 0.0))
	target["armor_reduction_turns_left"] = int(level_data.get("duration", 0))

	_show_message_over_hero("Corrosive Haze!")

	var mana_cost: float = float(level_data.get("mana_cost", 0))
	spend_mana(mana_cost)
	_skill_cooldowns["corrosive_haze"] = int(level_data.get("cooldown", 0))
	PlayerManager.set_skill_cooldown("corrosive_haze", _skill_cooldowns["corrosive_haze"])
	_refresh_skill_cooldown_labels()

	if _battle_over or _stage_generation != generation_before:
		return

	_mark_turn_used()


## Resolves a Sacred Arrow cast on `target`: deals this level's own
## base_damage plus bonus_per_column for every column between Mirana
## and `target` at the moment it was clicked (mitigated by the target's
## own armor via _deal_fixed_damage_to_enemy(), same helper Dark Pact/
## Torrent/Ghostship use) - since `target` was only ever a valid click
## within this level's own `range` in the first place (see
## _start_sacred_arrow_targeting()), the farthest it can ever reach is
## exactly the table's own "Max Damage" column, reached at max range.
## Then stuns it (target["stun_turns_left"], same shared field Pounce's/
## Torrent's own stun use) for this level's own stun_turns, only if the
## hit left it alive. _play_sacred_arrow_flight() plays the actual
## flight alongside this already-resolved damage, same "cosmetic only,
## never gates the outcome" split Lucent Beam's own impact uses.
func _resolve_sacred_arrow_cast(target: Dictionary, level_data: Dictionary) -> void:
	var generation_before: int = _stage_generation

	var target_node: TextureRect = target.get("node")
	var distance: int = _distance(target["pos_index"], _hero_pos_index)
	var damage: float = float(level_data.get("base_damage", 0)) + float(level_data.get("bonus_per_column", 0)) * distance
	_deal_fixed_damage_to_enemy(target, damage)
	if target.get("current_hp", 0) > 0:
		target["stun_turns_left"] = int(level_data.get("stun_turns", 0))
	_play_sacred_arrow_flight(hero_image, target_node, distance)

	var mana_cost: float = float(level_data.get("mana_cost", 0))
	spend_mana(mana_cost)
	_skill_cooldowns["sacred_arrow"] = int(level_data.get("cooldown", 0))
	PlayerManager.set_skill_cooldown("sacred_arrow", _skill_cooldowns["sacred_arrow"])
	_refresh_skill_cooldown_labels()

	if _battle_over or _stage_generation != generation_before:
		return

	_mark_turn_used()


## Resolves a Lucent Beam cast on `target`: deals this level's own flat
## `damage` (mitigated by the target's own armor via
## _deal_fixed_damage_to_enemy(), same helper Sacred Arrow uses above),
## then stuns it (target["stun_turns_left"], same shared field Sacred
## Arrow's/Pounce's/Torrent's own stun use) for this level's own
## stun_turns, only if the hit left it alive.
func _resolve_lucent_beam_cast(target: Dictionary, level_data: Dictionary) -> void:
	var generation_before: int = _stage_generation

	var target_node: TextureRect = target.get("node")
	var damage: float = float(level_data.get("damage", 0))
	_deal_fixed_damage_to_enemy(target, damage)
	if target.get("current_hp", 0) > 0:
		target["stun_turns_left"] = int(level_data.get("stun_turns", 0))
	_play_lucent_beam_impact(target_node)

	var mana_cost: float = float(level_data.get("mana_cost", 0))
	spend_mana(mana_cost)
	_skill_cooldowns["lucent_beam"] = int(level_data.get("cooldown", 0))
	PlayerManager.set_skill_cooldown("lucent_beam", _skill_cooldowns["lucent_beam"])
	_refresh_skill_cooldown_labels()

	if _battle_over or _stage_generation != generation_before:
		return

	_mark_turn_used()


## Resolves an Entangle cast once the player has clicked a target
## (see _start_entangle_targeting()/_on_enemy_clicked()): roots and
## silences `target` for this level's turn counts and arms its
## damage-over-time (ticked once per turn, at the start of that enemy's
## own turn, by _tick_enemy_turn_start_effects()). Then spends mana, starts Entangle's own
## cooldown, and ends the turn - the same bookkeeping _on_skill_pressed
## does for every other skill, just deferred to here since Entangle's
## target isn't known until after that function already returned.
func _resolve_entangle_cast(target: Dictionary, level_data: Dictionary) -> void:
	var generation_before: int = _stage_generation

	_apply_root(target, level_data)
	if is_instance_valid(target.get("node")):
		_play_entangle_effect(target["node"])
	_refresh_entangle_tints()

	if _is_hero_hidden():
		_end_shadow_dance()

	var mana_cost: float = float(level_data.get("mana_cost", 0))
	spend_mana(mana_cost)
	_skill_cooldowns["entangle"] = int(level_data.get("cooldown", 0))
	PlayerManager.set_skill_cooldown("entangle", _skill_cooldowns["entangle"])
	_refresh_skill_cooldown_labels()

	if _battle_over or _stage_generation != generation_before:
		return

	_mark_turn_used()


## Resolves a Mist Coil cast on an enemy: deals `level_data.damage`
## straight damage (still mitigated by the target's own armor, via
## _deal_fixed_damage_to_enemy() - same helper Dark Pact and the bear
## use), then spends mana, starts Mist Coil's cooldown, and ends the
## turn - the same bookkeeping _resolve_entangle_cast() does for
## Entangle, since Mist Coil's target isn't known until after
## _on_skill_pressed() already returned.
func _resolve_mist_coil_enemy_cast(target: Dictionary, level_data: Dictionary) -> void:
	var generation_before: int = _stage_generation

	var damage: float = float(level_data.get("damage", 0))
	# Captured before the hit, which may kill (and free) the target.
	_play_mist_coil_effect(hero_image, target.get("node"))
	_deal_fixed_damage_to_enemy(target, damage)

	var mana_cost: float = float(level_data.get("mana_cost", 0))
	spend_mana(mana_cost)
	_skill_cooldowns["mist_coil"] = int(level_data.get("cooldown", 0))
	PlayerManager.set_skill_cooldown("mist_coil", _skill_cooldowns["mist_coil"])
	_refresh_skill_cooldown_labels()

	if _battle_over or _stage_generation != generation_before:
		return

	_mark_turn_used()


## Resolves a Torrent cast on `target`: deals `level_data.damage`
## (mitigated by the target's own armor, via _deal_fixed_damage_to_
## enemy() - same helper Dark Pact/Mist Coil use) and stuns it for
## `level_data.stun_turns` if it survives, exactly like Pounce's own
## stun. At max level (level_data.radius > 0), also splashes every
## OTHER living, targetable enemy within that radius of `target`'s own
## column for the same damage - centered on the target rather than the
## hero, unlike Dark Pact's radius (which is centered on Kunkka
## himself) - so the splash never re-hits `target` a second time.
func _resolve_torrent_cast(target: Dictionary, level_data: Dictionary) -> void:
	var generation_before: int = _stage_generation

	var damage: float = float(level_data.get("damage", 0))
	# Played before the hit, which may kill (and free) the target.
	_play_torrent_splash(target.get("node"))
	_deal_fixed_damage_to_enemy(target, damage)
	if target.get("current_hp", 0) > 0:
		target["stun_turns_left"] = int(level_data.get("stun_turns", 1))

	var radius: int = int(level_data.get("radius", 0))
	if radius > 0:
		var target_pos: int = target["pos_index"]
		for enemy in _enemies:
			if is_same(enemy, target) or _is_target_hidden(enemy):
				continue
			if _distance(enemy["pos_index"], target_pos) <= radius:
				_play_torrent_splash(enemy.get("node"))
				_deal_fixed_damage_to_enemy(enemy, damage)
		# Centered on the target's own column, same as the splash above -
		# a rival's own illusion (Naga Siren's Mirror Image) can be in
		# range independently of whether the boss itself currently is.
		_play_torrent_splash_on_illusions(_enemy_illusions, target_pos, radius)
		_deal_aoe_damage_to_enemy_illusions(target_pos, radius, damage)

	# No Shadow Dance check here, unlike Entangle's own resolve - that
	# only ever matters for Slark's own kit, and Torrent belongs to
	# Kunkka (same reasoning as Mist Coil's enemy-cast, Abaddon's own
	# skill, right above/below this).
	var mana_cost: float = float(level_data.get("mana_cost", 0))
	spend_mana(mana_cost)
	_skill_cooldowns["torrent"] = int(level_data.get("cooldown", 0))
	PlayerManager.set_skill_cooldown("torrent", _skill_cooldowns["torrent"])
	_refresh_skill_cooldown_labels()

	if TutorialManager.is_active and TutorialManager.current_stage == 1 \
	and (_tutorial_stage1_step == "cast_torrent_on_range" or _tutorial_stage1_step == "recast_torrent_on_range"):
		# A recast (see "melee_in_range"'s own check below) can land while
		# the hero isn't actually standing next to a melee creep yet - a
		# reinforcement's melee creep spawns at its own fixed column,
		# independent of wherever the hero happens to be by then. Only
		# jump straight to "attack" if one is already right there;
		# otherwise route through "approach_melee" same as the very
		# first cast always has.
		if _get_enemy_at(_hero_pos_index).is_empty():
			_advance_tutorial_stage1_step("approach_melee")
		else:
			_advance_tutorial_stage1_step("melee_in_range")

	if _battle_over or _stage_generation != generation_before:
		return

	_mark_turn_used()


## Resolves an X Marks the Spot cast on `target`: no damage, no
## immediate effect at all beyond setting the mark itself - see
## _pending_xmarks_target's own comment above and _resolve_xmarks_
## teleport() (called from _end_turn()) for what actually happens with
## it, on the hero's own next turn. Recasting (marking a different
## target before the first one ever triggers) simply overwrites the
## pending mark outright, same as Essence Shift/True Form being
## recast - there's nothing to "give back" from the old one.
func _resolve_xmarks_cast(target: Dictionary, level_data: Dictionary) -> void:
	var generation_before: int = _stage_generation

	_pending_xmarks_target = target
	_pending_xmarks_stage_generation = _stage_generation

	var mana_cost: float = float(level_data.get("mana_cost", 0))
	spend_mana(mana_cost)
	_skill_cooldowns["x_marks_the_spot"] = int(level_data.get("cooldown", 0))
	PlayerManager.set_skill_cooldown("x_marks_the_spot", _skill_cooldowns["x_marks_the_spot"])
	_refresh_skill_cooldown_labels()

	if _battle_over or _stage_generation != generation_before:
		return

	_mark_turn_used()


## Called once per _end_turn() call, right as the hero's new turn opens
## (see its own call site) - resolves whatever X Marks the Spot mark is
## pending, if any. Teleports the hero onto the marked enemy's CURRENT
## pos_index (it may well have moved since it was marked) and clears
## the mark either way; no-ops (a silent fizzle, no teleport) if the
## mark's target died in the meantime or the stage/hero fight moved on
## since it was placed (_pending_xmarks_stage_generation mismatch,
## meaning `target` is a stale reference into a fight that's already
## over). Never spends the hero's turn - _end_turn() calls this before
## reopening the action buttons, not in response to one of them.
func _resolve_xmarks_teleport() -> void:
	if _pending_xmarks_target.is_empty():
		return

	var target: Dictionary = _pending_xmarks_target
	var stage_generation: int = _pending_xmarks_stage_generation
	_pending_xmarks_target = {}
	_pending_xmarks_stage_generation = -1

	if stage_generation != _stage_generation or target.get("current_hp", 0) <= 0:
		return

	_hero_pos_index = target["pos_index"]
	_update_hero_position()
	_show_message_over_hero("X Marks the Spot!")


## Resolves a Ghostship cast on `target`: the ship sails in a straight
## line from Kunkka's own column to `target`'s, so every enemy
## currently standing anywhere between the two (inclusive of both
## ends) takes `level_data.damage` - not just `target` itself, unlike
## every other single-target cast above. Each hit is still mitigated by
## that enemy's own armor, via _deal_fixed_damage_to_enemy() (same
## helper Dark Pact/Torrent use to split one amount across several
## targets). The whole path is snapshotted into `hit_targets` before
## any damage is dealt, so a kill partway through the loop (removing
## the dead enemy from _enemies) can't skip whoever comes after it in
## the same pass. _play_ghostship_animation() is purely the visual
## flourish of the ship's flight - the damage above has already fully
## resolved by the time it's even called.
func _resolve_ghostship_cast(target: Dictionary, level_data: Dictionary) -> void:
	var generation_before: int = _stage_generation

	var damage: float = float(level_data.get("damage", 0))
	var start_col: int = mini(_hero_pos_index, target["pos_index"])
	var end_col: int = maxi(_hero_pos_index, target["pos_index"])

	var hit_targets: Array = []
	for enemy in _enemies:
		if _is_target_hidden(enemy):
			continue
		var pos: int = enemy["pos_index"]
		if pos >= start_col and pos <= end_col:
			hit_targets.append(enemy)
	for enemy in hit_targets:
		_deal_fixed_damage_to_enemy(enemy, damage)
	# The ship sails the whole line from the hero's own column to the
	# target's - a rival's own illusion (Naga Siren's Mirror Image)
	# standing anywhere along that path can still be caught in it.
	_deal_line_aoe_damage_to_enemy_illusions(_hero_pos_index, target["pos_index"], damage)

	_play_ghostship_animation(_hero_pos_index, target["pos_index"])

	var mana_cost: float = float(level_data.get("mana_cost", 0))
	spend_mana(mana_cost)
	_skill_cooldowns["ghostship"] = int(level_data.get("cooldown", 0))
	PlayerManager.set_skill_cooldown("ghostship", _skill_cooldowns["ghostship"])
	_refresh_skill_cooldown_labels()

	if TutorialManager.is_active and TutorialManager.current_stage == 3 and _tutorial_stage3_step == "cast_ultimate_ready":
		_advance_tutorial_stage3_step("mop_up")

	if _battle_over or _stage_generation != generation_before:
		return

	_mark_turn_used()


## Resolves a Timber Chain cast on `target`: chains a line from
## Timbersaw's own column to `target`'s, so every enemy currently
## standing anywhere between the two (inclusive of both ends, same
## convention as _resolve_ghostship_cast() above) takes
## `level_data.damage` - `target` itself takes the same amount, it's
## not a separate/bonus hit. The whole path is snapshotted into
## `hit_targets` before any damage is dealt, same reasoning as
## Ghostship's own snapshot. Timbersaw then pulls himself onto
## `target`'s own pos_index (read after the damage above, but a dead
## enemy keeps its last "pos_index" around, so this still lands in the
## right spot even if the chain itself killed `target`) - UNLESS a
## rival's Ice Shards wall sits somewhere in that path, in which case
## the pull itself stops one column short of it (the chain's damage
## above still reaches the full line regardless - only the hero's own
## physical landing spot is blocked).
func _resolve_timber_chain_cast(target: Dictionary, level_data: Dictionary) -> void:
	var generation_before: int = _stage_generation

	var damage: float = float(level_data.get("damage", 0))
	var start_col: int = mini(_hero_pos_index, target["pos_index"])
	var end_col: int = maxi(_hero_pos_index, target["pos_index"])

	var hit_targets: Array = []
	for enemy in _enemies:
		if _is_target_hidden(enemy):
			continue
		var pos: int = enemy["pos_index"]
		if pos >= start_col and pos <= end_col:
			hit_targets.append(enemy)
	for enemy in hit_targets:
		_deal_fixed_damage_to_enemy(enemy, damage)
	# Same line as above (captured before the pull below can move the
	# hero off start_col) - a rival's own illusion (Naga Siren's Mirror
	# Image) standing anywhere along it can still be caught in it.
	_deal_line_aoe_damage_to_enemy_illusions(start_col, end_col, damage)

	# The chain's own damage still reaches every enemy across the full
	# line above (a magical effect, not the hero physically walking it)
	# but a rival's Ice Shards wall in that same path stops the hero's
	# own pull short of target's column - same "can't step into one"
	# rule every other hero movement enforces, just walked one column
	# at a time here instead of using _melee_move_target()/_ranged_
	# move_target() (this pull crosses a whole line at once, not a
	# fixed per-move distance).
	var chain_direction: int = _step_toward(_hero_pos_index, target["pos_index"])
	var landing_pos: int = _hero_pos_index
	while chain_direction != 0 and landing_pos != target["pos_index"]:
		var next_pos: int = landing_pos + chain_direction
		if _is_column_enemy_ice_shards_blocked(next_pos):
			break
		landing_pos = next_pos

	_hero_pos_index = landing_pos
	_update_hero_position()

	var mana_cost: float = float(level_data.get("mana_cost", 0))
	spend_mana(mana_cost)
	_skill_cooldowns["timber_chain"] = int(level_data.get("cooldown", 0))
	PlayerManager.set_skill_cooldown("timber_chain", _skill_cooldowns["timber_chain"])
	_refresh_skill_cooldown_labels()

	if _battle_over or _stage_generation != generation_before:
		return

	_mark_turn_used()


# ------------------------------------------------------------------
# Timbersaw's ultimate, Chakram (see the field comment above _chakram
# for the overall shape).
# ------------------------------------------------------------------

## Resolves a Chakram cast on `target`: deals this level's own
## cast_damage to `target` and every other enemy within radius columns
## of `target`'s position at this moment, then plants the chakram
## there - snapshotting that position now, so it stays fixed even if
## `target` (or anything else) moves later. Any chakram already planted
## from a previous cast is torn down first, same "recast replaces
## outright" reasoning as _summon_spirit_bear()'s own _despawn_bear()
## call, since the ultimate's long cooldown makes an overlapping recast
## a rare, deliberate choice rather than something worth stacking.
func _resolve_chakram_cast(target: Dictionary, level_data: Dictionary) -> void:
	var generation_before: int = _stage_generation

	var pos_index: int = target["pos_index"]
	var radius: int = int(level_data.get("radius", 0))

	var cast_damage: float = float(level_data.get("cast_damage", 0))
	var hit_targets: Array = []
	for enemy in _enemies:
		if _is_target_hidden(enemy):
			continue
		if _distance(enemy["pos_index"], pos_index) <= radius:
			hit_targets.append(enemy)
	for enemy in hit_targets:
		_deal_fixed_damage_to_enemy(enemy, cast_damage)
	# Planted at the target's own position at this moment - a rival's
	# own illusion (Naga Siren's Mirror Image) there (or nearby) takes
	# the same initial burst.
	_deal_aoe_damage_to_enemy_illusions(pos_index, radius, cast_damage)

	_despawn_chakram()
	_chakram = {
		"pos_index": pos_index,
		"radius": radius,
		"damage_per_turn": float(level_data.get("damage_per_turn", 0)),
		"turns_remaining": int(level_data.get("duration", 0)),
		"duration_pending_start": true,
		"node": _spawn_chakram_marker(pos_index),
	}
	_show_message_over_hero("Chakram!")

	var mana_cost: float = float(level_data.get("mana_cost", 0))
	spend_mana(mana_cost)
	_skill_cooldowns["chakram"] = int(level_data.get("cooldown", 0))
	PlayerManager.set_skill_cooldown("chakram", _skill_cooldowns["chakram"])
	_refresh_skill_cooldown_labels()

	if _battle_over or _stage_generation != generation_before:
		return

	_mark_turn_used()


## Purely cosmetic: spawns the chakram's marker texture at
## `pos_index`, half the usual creature height since it's a planted
## marker rather than a combatant - same texture-loading/layering
## convention as _summon_spirit_bear()'s own art. Returns the created
## node for _resolve_chakram_cast() to store into `_chakram["node"]`,
## or null (with a console print, same as a missing bear image) if the
## art asset isn't actually there.
func _spawn_chakram_marker(pos_index: int) -> TextureRect:
	if not ResourceLoader.exists(CHAKRAM_IMAGE_PATH):
		print("No Chakram image found at: ", CHAKRAM_IMAGE_PATH)
		return null

	var full_creature_height: float = get_viewport_rect().size.y / 4.0
	var target_height: float = full_creature_height / 2.0
	var texture: Texture2D = load(CHAKRAM_IMAGE_PATH)
	var tex_size: Vector2 = texture.get_size()
	var scale_factor: float = target_height / tex_size.y
	var target_width: float = tex_size.x * scale_factor

	var tex_rect := TextureRect.new()
	tex_rect.texture = texture
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	tex_rect.size = Vector2(target_width, target_height)
	tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tex_rect.position = Vector2(_index_to_x(pos_index), _creature_y() + (full_creature_height - target_height) / 2.0)
	add_child(tex_rect)
	# Same reasoning as _summon_spirit_bear()'s own move_child() call -
	# render at the hero/enemy layer, not on top of every UI panel.
	move_child(tex_rect, enemies_layer.get_index() + 1)

	return tex_rect


## Ticks the planted Chakram's duration down once per End Turn, same
## timing (and same "the casting turn doesn't count" skip) as every
## other duration-based buff - dealing this level's own damage_per_turn
## to every living, targetable enemy within radius columns of the
## FIXED position it was planted at (not re-checked against any
## enemy's current position - see the field comment above _chakram) on
## every tick that actually counts against the duration. A no-op while
## no chakram is planted.
func _tick_chakram() -> void:
	if _chakram.is_empty():
		return

	if _chakram.get("duration_pending_start", false):
		_chakram["duration_pending_start"] = false
		return

	var pos_index: int = int(_chakram["pos_index"])
	var radius: int = int(_chakram["radius"])
	var damage_per_turn: float = float(_chakram["damage_per_turn"])
	for enemy in _enemies.duplicate():
		if _is_target_hidden(enemy):
			continue
		if _distance(enemy["pos_index"], pos_index) <= radius:
			_deal_fixed_damage_to_enemy(enemy, damage_per_turn)
			if _battle_over:
				return
	# Same FIXED planted position as the check above - a rival's own
	# illusion can be in range independently of whether the boss itself
	# currently is.
	_deal_aoe_damage_to_enemy_illusions(pos_index, radius, damage_per_turn)

	_chakram["turns_remaining"] = int(_chakram["turns_remaining"]) - 1
	if int(_chakram["turns_remaining"]) <= 0:
		_despawn_chakram()


## Removes whatever chakram is currently planted, if any - used both
## when a fresh cast replaces one still active (see
## _resolve_chakram_cast()) and when its duration runs out
## (_tick_chakram()). Scene teardown at battle end frees the node
## implicitly either way, same reasoning as _despawn_bear()'s own
## comment.
func _despawn_chakram() -> void:
	if _chakram.is_empty():
		return
	if is_instance_valid(_chakram.get("node")):
		_chakram["node"].queue_free()
	_chakram = {}


## Purely cosmetic: spawns the ship art at `start_pos_index` and tweens
## it across to `target_pos_index`'s, fading itself out once it arrives
## - mirrors _summon_spirit_bear()'s own texture-loading/sizing
## convention, just as a one-shot flight instead of a persistent ally.
## No-op (with a console print, same as a missing bear image) if the
## art asset isn't actually there. `start_pos_index` is the player's own
## Kunkka casting on an enemy (_resolve_ghostship_cast() passes
## _hero_pos_index) or a rival Kunkka casting on the player
## (_cast_enemy_ghostship() passes the boss's own enemy["pos_index"]
## instead) - either way this only draws the flight, the damage above
## has already fully resolved by the time it's even called.
func _play_ghostship_animation(start_pos_index: int, target_pos_index: int) -> void:
	if not ResourceLoader.exists(GHOSTSHIP_IMAGE_PATH):
		print("No Ghostship image found at: ", GHOSTSHIP_IMAGE_PATH)
		return

	var target_height: float = get_viewport_rect().size.y / 4.0
	var texture: Texture2D = load(GHOSTSHIP_IMAGE_PATH)
	var tex_size: Vector2 = texture.get_size()
	var scale_factor: float = target_height / tex_size.y
	var target_width: float = tex_size.x * scale_factor

	var tex_rect := TextureRect.new()
	tex_rect.texture = texture
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	tex_rect.size = Vector2(target_width, target_height)
	tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tex_rect.flip_h = target_pos_index < start_pos_index
	tex_rect.position = Vector2(_index_to_x(start_pos_index), _creature_y())
	add_child(tex_rect)
	# Same reasoning as _summon_spirit_bear()'s own move_child() call -
	# render at the hero/enemy layer, not on top of every UI panel.
	move_child(tex_rect, enemies_layer.get_index() + 1)

	var tween := create_tween()
	tween.tween_property(tex_rect, "position:x", _index_to_x(target_pos_index), GHOSTSHIP_TRAVEL_DURATION)
	tween.finished.connect(tex_rect.queue_free)


## Purely cosmetic: drops a thin beam of moonlight (LUCENT_BEAM_COLOR)
## from above straight down onto `target_node`'s own position, growing
## into place top-down rather than flying in from the side - mirrors
## _play_ghostship_animation()'s own "damage already resolved, this just
## draws it" split (see that function's own comment). Once the beam
## reaches the target it flashes the struck sprite the same quick
## brightness pulse an enemy's own cast already gets
## (_pulse_caster_sprite()), so the hit itself reads as a clear impact,
## then fades the beam out and frees it. No-op if the target's node is
## already gone (e.g. the hit killed it) by the time this runs.
func _play_lucent_beam_impact(target_node: TextureRect) -> void:
	if not is_instance_valid(target_node):
		return

	var beam := ColorRect.new()
	beam.color = LUCENT_BEAM_COLOR
	beam.mouse_filter = Control.MOUSE_FILTER_IGNORE
	beam.size = Vector2(LUCENT_BEAM_WIDTH, 0.0)
	beam.position = Vector2(
		target_node.position.x + target_node.size.x / 2.0 - LUCENT_BEAM_WIDTH / 2.0,
		target_node.position.y - LUCENT_BEAM_FALL_HEIGHT
	)
	add_child(beam)
	# Same reasoning as _summon_spirit_bear()'s own move_child() call -
	# render at the hero/enemy layer, not on top of every UI panel.
	move_child(beam, enemies_layer.get_index() + 1)

	var tween := create_tween()
	tween.tween_property(beam, "size:y", LUCENT_BEAM_FALL_HEIGHT, LUCENT_BEAM_FALL_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void:
		if is_instance_valid(target_node):
			_pulse_caster_sprite(target_node, false)
	)
	tween.tween_property(beam, "modulate:a", 0.0, 0.18)
	tween.tween_callback(beam.queue_free)


## Purely cosmetic: a short light-blue streak (SACRED_ARROW_COLOR) that
## flies horizontally from `caster_node`'s own position to
## `target_node`'s - either direction (the player's own hero_image
## shooting an enemy, or a rival's own node shooting the player's
## hero_image, both plain TextureRects) - see SACRED_ARROW_* constants'
## own comment for how this is deliberately varied from Lucent Beam's
## "grows down out of the sky" drop rather than just being it
## recolored. `distance` (already known to the caller - see
## _resolve_sacred_arrow_cast()/_cast_enemy_sacred_arrow()) stretches
## the flight time for a longer shot, same value the damage itself
## already scales off. Same "pulse the struck sprite, then fade out"
## finish as Lucent Beam once it lands. No-op if either node is already
## gone (e.g. the hit killed it) by the time this runs.
func _play_sacred_arrow_flight(caster_node: Control, target_node: TextureRect, distance: int) -> void:
	if not is_instance_valid(caster_node) or not is_instance_valid(target_node):
		return

	var start_x: float = caster_node.position.x + caster_node.size.x / 2.0
	var end_x: float = target_node.position.x + target_node.size.x / 2.0
	var center_y: float = target_node.position.y + target_node.size.y / 2.0 - SACRED_ARROW_HEIGHT / 2.0

	var arrow := ColorRect.new()
	arrow.color = SACRED_ARROW_COLOR
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arrow.size = Vector2(SACRED_ARROW_LENGTH, SACRED_ARROW_HEIGHT)
	arrow.position = Vector2(start_x - SACRED_ARROW_LENGTH / 2.0, center_y)
	add_child(arrow)
	# Same reasoning as _summon_spirit_bear()'s own move_child() call -
	# render at the hero/enemy layer, not on top of every UI panel.
	move_child(arrow, enemies_layer.get_index() + 1)

	var flight_duration: float = SACRED_ARROW_BASE_DURATION + SACRED_ARROW_DURATION_PER_COLUMN * float(distance)

	var tween := create_tween()
	tween.tween_property(arrow, "position:x", end_x - SACRED_ARROW_LENGTH / 2.0, flight_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func() -> void:
		if is_instance_valid(target_node):
			_pulse_caster_sprite(target_node, false)
	)
	tween.tween_property(arrow, "modulate:a", 0.0, 0.18)
	tween.tween_callback(arrow.queue_free)


## Resolves a Cold Feet cast on `target`: no immediate damage, just
## arms this level's own damage/duration onto `target`'s own
## Dictionary (dedicated cold_feet_dot_damage/cold_feet_dot_turns_left
## fields, separate from Entangle's/Curse of Avernus's own DoT fields
## even though the mechanism is identical, since a different skill's
## effect shouldn't silently share or clobber another's state) - ticked
## once per turn, at the start of that enemy's own turn, by
## _tick_enemy_turn_start_effects(). Recasting on an already-frozen target simply
## overwrites its counters with this cast's fresh values, same as
## Entangle's own recast rule.
func _resolve_cold_feet_cast(target: Dictionary, level_data: Dictionary) -> void:
	var generation_before: int = _stage_generation

	target["cold_feet_dot_damage"] = float(level_data.get("damage", 0))
	target["cold_feet_dot_turns_left"] = int(level_data.get("duration", 0))
	if is_instance_valid(target.get("node")):
		_flash_bounce_hit(target["node"], COLD_FEET_FLASH_COLOR)
	_refresh_cold_feet_frost()

	var mana_cost: float = float(level_data.get("mana_cost", 0))
	spend_mana(mana_cost)
	_skill_cooldowns["cold_feet"] = int(level_data.get("cooldown", 0))
	PlayerManager.set_skill_cooldown("cold_feet", _skill_cooldowns["cold_feet"])
	_refresh_skill_cooldown_labels()

	if _battle_over or _stage_generation != generation_before:
		return

	_mark_turn_used()


## Resolves an Ice Vortex cast on `target`: no immediate damage, just
## arms this level's own damage/duration onto EVERY enemy within
## this level's own radius of `target`'s column (`target` included -
## it's just the center of the AoE, not a special case) via dedicated
## ice_vortex_dot_damage/ice_vortex_dot_turns_left fields, kept
## separate from Cold Feet's/Entangle's/Curse of Avernus's own DoT
## fields for the same reason Cold Feet's are separate from theirs.
## Ticked once per turn, at the start of that enemy's own turn, by
## _tick_enemy_turn_start_effects(). Recasting overwrites whatever DoT
## an already-affected enemy was carrying, same as every other DoT
## skill's own recast rule.
func _resolve_ice_vortex_cast(target: Dictionary, level_data: Dictionary) -> void:
	var generation_before: int = _stage_generation

	var damage: float = float(level_data.get("damage", 0))
	var duration: int = int(level_data.get("duration", 0))
	var radius: int = int(level_data.get("radius", 1))
	var target_pos: int = target["pos_index"]

	for enemy in _enemies:
		if _is_target_hidden(enemy):
			continue
		if _distance(enemy["pos_index"], target_pos) <= radius:
			enemy["ice_vortex_dot_damage"] = damage
			enemy["ice_vortex_dot_turns_left"] = duration
			if is_instance_valid(enemy.get("node")):
				_flash_bounce_hit(enemy["node"], COLD_FEET_FLASH_COLOR)
	# The rival's own illusions (Naga Siren's Mirror Image) in the same
	# area get the same DoT - ticked by _tick_enemy_illusions_ice_vortex()
	# at the start of the enemy turn. The rival's own Spirit Bear needs
	# nothing extra: it's a regular _enemies entry, already marked above.
	_mark_illusions_ice_vortex(_enemy_illusions, target_pos, radius, damage, duration)

	_play_ice_vortex_swirl(target.get("node"), radius)
	_refresh_cold_feet_frost()

	var mana_cost: float = float(level_data.get("mana_cost", 0))
	spend_mana(mana_cost)
	_skill_cooldowns["ice_vortex"] = int(level_data.get("cooldown", 0))
	PlayerManager.set_skill_cooldown("ice_vortex", _skill_cooldowns["ice_vortex"])
	_refresh_skill_cooldown_labels()

	if _battle_over or _stage_generation != generation_before:
		return

	_mark_turn_used()


## Resolves a Chilling Touch cast on `target`: one instant hit for the
## hero's own rolled Attack damage (_roll_hero_damage(), the same roll
## a plain Attack uses) plus this level's own flat bonus_damage on top,
## mitigated by the target's own armor via _deal_fixed_damage_to_enemy()
## - same helper Dark Pact/Torrent/Ghostship use. This is SKILL damage,
## not the plain Attack action itself, so - same as every other skill
## here - it never triggers Essence Shift's steal, Spirit Link's
## lifesteal, or Curse of Avernus's stacking; those are all scoped
## specifically to _apply_hero_attack().
func _resolve_chilling_touch_cast(target: Dictionary, level_data: Dictionary) -> void:
	var generation_before: int = _stage_generation

	var damage: float = _roll_hero_damage() + float(level_data.get("bonus_damage", 0))
	_deal_fixed_damage_to_enemy(target, damage)

	var mana_cost: float = float(level_data.get("mana_cost", 0))
	spend_mana(mana_cost)
	_skill_cooldowns["chilling_touch"] = int(level_data.get("cooldown", 0))
	PlayerManager.set_skill_cooldown("chilling_touch", _skill_cooldowns["chilling_touch"])
	_refresh_skill_cooldown_labels()

	if _battle_over or _stage_generation != generation_before:
		return

	_mark_turn_used()


## Resolves a Lil' Shredder cast on `target`: fires this level's own
## `shots` count of separately-rolled hits at it (each
## _roll_hero_damage() * damage_pct, same "own roll per shot" idiom
## Whirling Death/Dark Pact use for "one roll shared across many
## targets" just inverted here into "many rolls at one target"), each
## shot ALSO stacking armor_reduction_per_shot onto `target`'s own
## armor_reduction - a per-instance runtime field folded into
## _deal_fixed_damage_to_enemy()'s own armor calc, never touching
## target["static"]'s shared template armor - so a later shot in the
## SAME volley already lands harder than the first, having shredded
## some of the target's armor away. Stops early if `target` dies
## partway through. The whole stack's own duration (this level's own
## `duration`, in the target's own upcoming turns) is only set once,
## after the last shot connects - see _tick_enemy_turn_start_effects()'s
## own comment for why the casting round is never counted against it
## for free, with no separate "pending start" flag needed here.
func _resolve_lil_shredder_cast(target: Dictionary, level_data: Dictionary) -> void:
	var generation_before: int = _stage_generation

	var shots: int = int(level_data.get("shots", 3))
	var damage_pct: float = float(level_data.get("damage_pct", 0))
	var armor_reduction_per_shot: float = float(level_data.get("armor_reduction_per_shot", 0))
	var target_pos_index: int = target["pos_index"]

	for i in range(shots):
		if target.get("current_hp", 0) <= 0:
			break
		var shot_damage: float = _roll_hero_damage() * damage_pct
		_deal_fixed_damage_to_enemy(target, shot_damage)
		_play_lil_shredder_shot_effect(target_pos_index, i * 0.15)
		if target.get("current_hp", 0) <= 0:
			break
		target["armor_reduction"] = float(target.get("armor_reduction", 0.0)) + armor_reduction_per_shot

	if target.get("current_hp", 0) > 0:
		target["armor_reduction_turns_left"] = int(level_data.get("duration", 0))

	var mana_cost: float = float(level_data.get("mana_cost", 0))
	spend_mana(mana_cost)
	_skill_cooldowns["lil_shredder"] = int(level_data.get("cooldown", 0))
	PlayerManager.set_skill_cooldown("lil_shredder", _skill_cooldowns["lil_shredder"])
	_refresh_skill_cooldown_labels()

	if _battle_over or _stage_generation != generation_before:
		return

	_mark_turn_used()


## Purely cosmetic: schedules one small impact-spark burst at
## `target_pos_index` after `delay` seconds - called once per shot from
## _resolve_lil_shredder_cast() with a slight stagger (0, 0.15, 0.3s) so
## the 3 shots read as a rapid volley instead of one simultaneous flash.
## The damage above has already fully resolved by the time each of
## these plays; none of this ever gates it. Guards _battle_over at fire
## time since the delay can outlive the battle (a scene change from the
## last shot's own kill, say) - same reasoning every other delayed
## cleanup in this file already follows.
func _play_lil_shredder_shot_effect(target_pos_index: int, delay: float) -> void:
	get_tree().create_timer(maxf(delay, 0.01)).timeout.connect(_spawn_lil_shredder_impact.bind(target_pos_index))


func _spawn_lil_shredder_impact(target_pos_index: int) -> void:
	if _battle_over:
		return

	var lifetime: float = 0.2

	var particles := CPUParticles2D.new()
	particles.position = Vector2(_index_to_x(target_pos_index) + _grid_unit() / 2.0, _creature_y() + get_viewport_rect().size.y / 8.0)
	particles.emitting = false
	particles.one_shot = true
	particles.amount = 14
	particles.lifetime = lifetime
	particles.explosiveness = 1.0
	particles.direction = Vector2(0, -1)
	particles.spread = 70.0
	particles.gravity = Vector2.ZERO
	particles.initial_velocity_min = 60.0
	particles.initial_velocity_max = 120.0
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 4.0
	particles.color = Color(1.0, 0.85, 0.3, 1.0)
	add_child(particles)
	# Same reasoning as _summon_spirit_bear()'s own move_child() call -
	# render at the hero/enemy layer, not on top of every UI panel.
	move_child(particles, enemies_layer.get_index() + 1)
	particles.emitting = true

	get_tree().create_timer(lifetime + 0.2).timeout.connect(particles.queue_free)


# ------------------------------------------------------------------
# Snapfire's ultimate, Mortimer Kisses (see the field comment above
# _mortimer_kisses_active for the overall channel shape).
# ------------------------------------------------------------------

## Snapfire's Mortimer Kisses target picking: same "normal attack
## range" gate (_hero_attack_column_range()) every other attack-range
## targeted skill uses - marking a target for the whole channel is the
## only click involved; the following shots never need another one.
## Returns false (and shows a message) if nothing is in range.
func _start_mortimer_kisses_targeting(level_data: Dictionary) -> bool:
	_cancel_targeting()

	var col_range: int = _hero_attack_column_range()
	for enemy in _enemies:
		if _is_target_hidden(enemy):
			continue
		if _distance(enemy["pos_index"], _hero_pos_index) <= col_range:
			_valid_targets.append(enemy)

	if _valid_targets.is_empty():
		_show_message_over_hero("No enemy in range")
		return false

	_targeting_mode = true
	_targeting_purpose = "mortimer_kisses"
	_pending_mortimer_kisses_level_data = level_data
	_highlight_valid_targets()
	return true


## Resolves a Mortimer Kisses cast on `target`: marks it, fires the
## FIRST of this level's own `hits` shots immediately (right now, as
## part of this cast, same as any other instant skill), and arms
## _mortimer_kisses_turns_left with however many are left (hits - 1) -
## _end_turn()'s own tail auto-fires the rest, one per hero turn, with
## every other action locked out for as long as any remain (see
## _mortimer_kisses_active's own field comment for the full list of
## lock sites). Always "succeeds" once a target's been marked - there's
## nothing further for this cast itself to fail on.
func _resolve_mortimer_kisses_cast(target: Dictionary, level_data: Dictionary) -> void:
	var generation_before: int = _stage_generation

	_mortimer_marked_enemy = target
	_mortimer_kisses_level_data = level_data
	_mortimer_kisses_active = true
	_mortimer_kisses_turns_left = int(level_data.get("hits", 1)) - 1

	_fire_mortimer_kisses_shot()

	var mana_cost: float = float(level_data.get("mana_cost", 0))
	spend_mana(mana_cost)
	_skill_cooldowns["mortimer_kisses"] = int(level_data.get("cooldown", 0))
	PlayerManager.set_skill_cooldown("mortimer_kisses", _skill_cooldowns["mortimer_kisses"])
	_refresh_skill_cooldown_labels()

	if _battle_over or _stage_generation != generation_before:
		return

	_mark_turn_used()


## Fires one Mortimer Kisses shot: the impact column is always
## `_mortimer_marked_enemy`'s own "pos_index" - while it's alive that
## tracks it turn to turn (a live Dictionary reference into _enemies),
## and once it's dead _kill_enemy() never mutates that field further,
## so it keeps reading as wherever it died - "the last column that the
## enemy occupied" falls out for free. Deals this level's own
## main_damage plus a refreshed burn DoT to whoever's standing on that
## column RIGHT NOW (_get_enemy_at() - not necessarily the marked enemy
## itself, if it died and something else moved onto that spot), and
## splash_damage (no burn) to anything exactly 1 column either side of
## it. Always plays the lava-pool impact visual at that column, even if
## nothing was actually standing there to hit.
func _fire_mortimer_kisses_shot() -> void:
	var level_data: Dictionary = _mortimer_kisses_level_data
	var impact_pos: int = int(_mortimer_marked_enemy.get("pos_index", _hero_pos_index))

	var main_damage: float = float(level_data.get("main_damage", 0))
	var splash_damage: float = float(level_data.get("splash_damage", 0))
	var burn_per_turn: float = float(level_data.get("burn_per_turn", 0))
	var burn_duration: int = int(level_data.get("burn_duration", 0))

	var main_target: Dictionary = _get_enemy_at(impact_pos)
	if not main_target.is_empty():
		_deal_fixed_damage_to_enemy(main_target, main_damage)
		if main_target.get("current_hp", 0) > 0 and burn_per_turn > 0.0:
			main_target["mortimer_burn_dot_damage"] = burn_per_turn
			main_target["mortimer_burn_dot_turns_left"] = burn_duration

	for enemy in _enemies.duplicate():
		if _is_target_hidden(enemy):
			continue
		if is_same(enemy, main_target):
			continue
		if _distance(enemy["pos_index"], impact_pos) == 1:
			_deal_fixed_damage_to_enemy(enemy, splash_damage)

	# A rival's own illusion (Naga Siren's Mirror Image) exactly on the
	# impact column takes main_damage, one column either side takes
	# splash_damage - same split as the regular-enemy checks above,
	# rather than the single flat radius _deal_aoe_damage_to_enemy_
	# illusions() would give (which can't tell "the impact column
	# itself" apart from "one column over").
	if not _enemy_illusions.is_empty():
		var boss: Dictionary = _get_hero_fight_boss()
		if not boss.is_empty():
			var boss_armor: float = _enemy_hero_effective_armor(boss)
			for illusion in _enemy_illusions.duplicate():
				var illusion_dist: int = _distance(illusion["pos_index"], impact_pos)
				if illusion_dist == 0:
					_deal_damage_to_enemy_illusion(illusion, _apply_armor_reduction(main_damage, boss_armor))
				elif illusion_dist == 1:
					_deal_damage_to_enemy_illusion(illusion, _apply_armor_reduction(splash_damage, boss_armor))

	_play_mortimer_kisses_impact_effect(impact_pos)


## Ends the Mortimer Kisses channel - called once its last shot has
## fired (see _end_turn()'s own tail). Clears every bit of state the
## lock/auto-fire logic reads, so a stale reference to a long-dead
## `_mortimer_marked_enemy` can never leak into some later, unrelated
## check.
func _end_mortimer_kisses() -> void:
	_mortimer_kisses_active = false
	_mortimer_kisses_turns_left = 0
	_mortimer_marked_enemy = {}
	_mortimer_kisses_level_data = {}
	_show_message_over_hero("Mortimer Kisses ends")


## Purely cosmetic: a brief burning/lava-pool flare at `pos_index` -
## visualizes each of Mortimer Kisses' own shots landing. The damage
## above has already fully resolved by the time this plays; it never
## gates on this. Same CPUParticles2D one-shot-burst recipe as Lil'
## Shredder's own impact spark, just wider, slower, and colored like
## fire/lava rather than a gunshot's spark.
func _play_mortimer_kisses_impact_effect(pos_index: int) -> void:
	var lifetime: float = 0.7
	var column_width: float = _grid_unit()

	var particles := CPUParticles2D.new()
	particles.position = Vector2(_index_to_x(pos_index) + column_width / 2.0, _creature_y() + get_viewport_rect().size.y / 4.0)
	particles.emitting = false
	particles.one_shot = true
	particles.amount = 70
	particles.lifetime = lifetime
	particles.explosiveness = 0.85
	# Spread across the whole column's own width rather than bursting
	# from a single point, so the pool visually covers the column it
	# hit instead of just its center.
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	particles.emission_rect_extents = Vector2(column_width / 2.0, 16.0)
	particles.direction = Vector2(0, -1)
	particles.spread = 100.0
	particles.gravity = Vector2.ZERO
	particles.initial_velocity_min = 30.0
	particles.initial_velocity_max = 90.0
	particles.scale_amount_min = 10.0
	particles.scale_amount_max = 20.0
	particles.color = Color(1.0, 0.35, 0.05, 1.0)
	add_child(particles)
	# Same reasoning as _summon_spirit_bear()'s own move_child() call -
	# render at the hero/enemy layer, not on top of every UI panel.
	move_child(particles, enemies_layer.get_index() + 1)
	particles.emitting = true

	get_tree().create_timer(lifetime + 0.2).timeout.connect(particles.queue_free)


# ------------------------------------------------------------------
# Naga Siren's Mirror Image (see the field comment above _illusions for
# the overall shape).
# ------------------------------------------------------------------

## Activates Mirror Image: replaces any illusions already up outright
## (_end_mirror_image() first - recasting mid-duration just resets the
## set, nothing carries over), then spawns this level's own `illusions`
## count of decoys - one immediately in front of the hero, one
## immediately behind (both clamped to the grid, so at the very edge a
## decoy can end up sharing the hero's own column instead of going out
## of bounds), and any beyond those first two doubling up randomly on
## one of those same two columns. "Front"/"behind" follows the hero's
## own CURRENT facing (hero_image.flip_h, same convention Scatterblast/
## Firesnap Cookie already read) rather than a fixed board direction.
## Rip Tide's own bonuses (extra_illusion, illusion_damage_bonus_pct,
## illusion_duration_bonus) are folded straight in here, read fresh off
## _get_rip_tide_level_data() at cast time - a no-op contribution while
## that skill isn't learned, same "empty means locked" convention every
## other auto-triggered skill's own level-data getter uses. Always
## "succeeds" - self-cast, no target or range requirement, same as
## every other self-cast buff.
func _activate_mirror_image(level_data: Dictionary) -> void:
	_end_mirror_image()

	var rip_tide_level_data: Dictionary = _get_rip_tide_level_data()

	var direction: int = -1 if hero_image.flip_h else 1
	var front_pos: int = clampi(_hero_pos_index + direction, 0, GRID_COLUMNS - 1)
	var behind_pos: int = clampi(_hero_pos_index - direction, 0, GRID_COLUMNS - 1)

	var illusions_count: int = int(level_data.get("illusions", 3)) + int(rip_tide_level_data.get("extra_illusion", 0))
	var illusion_hp: float = _hero_max_hp() * float(level_data.get("hp_pct", 0.0))

	for i in range(illusions_count):
		var pos: int
		if i == 0:
			pos = front_pos
		elif i == 1:
			pos = behind_pos
		else:
			pos = front_pos if randf() < 0.5 else behind_pos
		_illusions.append({
			"pos_index": pos,
			"current_hp": illusion_hp,
			"max_hp": illusion_hp,
			"node": _spawn_illusion_node(pos),
		})

	_illusion_damage_pct = float(level_data.get("damage_pct", 0.0)) + float(rip_tide_level_data.get("illusion_damage_bonus_pct", 0.0))
	_illusion_hit_chance_pct = float(level_data.get("hit_chance_pct", 0.0))
	_illusions_turns_remaining = int(level_data.get("duration", 0)) + int(rip_tide_level_data.get("illusion_duration_bonus", 0))
	# The casting turn itself doesn't count - duration only starts
	# ticking (and the illusions only start attacking) from the turn
	# after (see _tick_mirror_image()), same as every other duration-
	# based buff.
	_illusions_duration_pending_start = true

	_show_message_over_hero("Mirror Image!")


## Purely visual: a copy of the hero's own current portrait, faded to
## HERO_ILLUSION_ALPHA so the real hero still reads clearly among his
## own decoys, positioned on `pos_index`'s own column at the same
## size/scale _set_hero_image() already gives hero_image itself.
func _spawn_illusion_node(pos_index: int) -> TextureRect:
	var tex_rect := TextureRect.new()
	tex_rect.texture = hero_image.texture
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	tex_rect.size = hero_image.size
	tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tex_rect.flip_h = hero_image.flip_h
	tex_rect.modulate = Color(1, 1, 1, HERO_ILLUSION_ALPHA)
	tex_rect.position = Vector2(_index_to_x(pos_index), _creature_y())
	add_child(tex_rect)
	# Same reasoning as _summon_spirit_bear()'s own move_child() call -
	# render at the hero/enemy layer, not on top of every UI panel.
	move_child(tex_rect, enemies_layer.get_index() + 1)
	return tex_rect


## Ticks Mirror Image's duration down once per End Turn, same timing
## (and same "the casting turn doesn't count" skip) as every other
## duration-based buff - firing the illusions' own attack
## (_fire_mirror_image_attack()) on every tick that actually counts
## against the duration, then ending the effect once it runs out. A
## no-op once every illusion has already died in combat (see
## _kill_illusion()) even if the duration itself hasn't run out yet.
func _tick_mirror_image() -> void:
	if _illusions.is_empty():
		return

	if _illusions_duration_pending_start:
		_illusions_duration_pending_start = false
		return

	_fire_mirror_image_attack()

	_illusions_turns_remaining -= 1
	if _illusions_turns_remaining <= 0:
		_end_mirror_image()


## Every surviving illusion strikes the SAME randomly-picked living,
## targetable enemy within the hero's own normal attack range
## (_hero_attack_column_range(), same reach a plain Attack/most of his
## skills use) - each illusion rolling its own hero-damage instance
## (_roll_hero_damage()) scaled by _illusion_damage_pct, same "own roll
## per hit" idiom Lil' Shredder's own shots use, mitigated by the
## target's own armor via _deal_fixed_damage_to_enemy(). Stops early if
## that focus-fire kills the target partway through - a no-op if
## nothing is in range this turn.
func _fire_mirror_image_attack() -> void:
	var col_range: int = _hero_attack_column_range()
	var targets: Array = []
	for enemy in _enemies:
		if _is_target_hidden(enemy):
			continue
		if _distance(enemy["pos_index"], _hero_pos_index) <= col_range:
			targets.append(enemy)

	if targets.is_empty():
		return

	var target: Dictionary = targets[randi() % targets.size()]
	for illusion in _illusions.duplicate():
		if target.get("current_hp", 0) <= 0:
			break
		var illusion_damage: float = _roll_hero_damage() * _illusion_damage_pct
		_deal_fixed_damage_to_enemy(target, illusion_damage)
		if _battle_over:
			return


## Ends Mirror Image, despawning every surviving illusion - called both
## when its duration runs out (_tick_mirror_image()) and defensively at
## the top of _activate_mirror_image() so a recast mid-duration never
## leaks the old set's nodes. Only shows the "fades" message if there
## was actually something to end (so casting it fresh, with nothing yet
## up to replace, stays silent).
func _end_mirror_image() -> void:
	var had_illusions: bool = not _illusions.is_empty()
	for illusion in _illusions:
		if is_instance_valid(illusion.get("node")):
			illusion["node"].queue_free()
	_illusions.clear()
	_illusion_damage_pct = 0.0
	_illusion_hit_chance_pct = 0.0
	_illusions_turns_remaining = 0
	_illusions_duration_pending_start = false

	if had_illusions:
		_show_message_over_hero("Mirror Image fades")


## Applies `amount` of already-mitigated damage to `illusion` - the
## illusion-side equivalent of _deal_damage_to_bear(), just against the
## `_illusions` array instead of the single `_bear` dict. Called from
## apply_damage() whenever a hit redirects onto an illusion instead of
## the hero.
func _deal_damage_to_illusion(illusion: Dictionary, amount: float) -> void:
	illusion["current_hp"] = float(illusion.get("current_hp", 0.0)) - amount
	if is_instance_valid(illusion.get("node")):
		_show_damage_number(illusion["node"], amount)
	if illusion["current_hp"] <= 0:
		_kill_illusion(illusion)


## Removes one illusion that's died in combat - used both here (a
## redirected hit finishing it off) and, in principle, anywhere else an
## illusion's HP could hit 0. Doesn't end Mirror Image outright even if
## this was the last one; _tick_mirror_image()'s own early-empty check
## just makes every remaining tick (attack + duration decrement) a
## no-op until the duration itself finally runs out.
func _kill_illusion(illusion: Dictionary) -> void:
	if is_instance_valid(illusion.get("node")):
		illusion["node"].queue_free()
	_illusions.erase(illusion)


## Any enemy AoE skill that damages the hero over an area should ALSO
## independently hit every surviving illusion within that same area -
## illusions are real occupants of their own columns, not something
## folded into apply_damage()'s own redirect-chance roll (that roll
## only ever fires for a hit actually landing on the hero; an AoE's
## OTHER victims, illusions included, are unconditional collateral, not
## a chance). Called alongside (never instead of) whatever apply_damage()
## call the AoE skill already makes for the hero himself - see each
## enemy skill cast function's own call site. `amount` is the RAW,
## pre-mitigation damage the AoE deals to the hero - each illusion
## mitigates it separately via the hero's own armor, same as apply_
## damage()'s own redirect roll does, since an illusion is a copy of
## him, not a separate combatant with its own defense stat. A no-op
## while no illusions are up.
## `flash_hits` gives each one hit the same red hit-flash as Moon
## Glaives' bounce (_flash_bounce_hit()) - off by default, opted into by
## Dark Pact.
func _deal_aoe_damage_to_illusions(center_pos_index: int, radius: int, amount: float, flash_hits: bool = false) -> void:
	if _illusions.is_empty() or amount <= 0.0:
		return

	var mitigated: float = _apply_armor_reduction(amount, _hero_armor())
	for illusion in _illusions.duplicate():
		if _distance(illusion["pos_index"], center_pos_index) <= radius:
			_deal_damage_to_illusion(illusion, mitigated)
			if flash_hits and is_instance_valid(illusion.get("node")):
				_flash_bounce_hit(illusion["node"])


## The line-shaped equivalent of _deal_aoe_damage_to_illusions() above -
## for Ghostship's/Timber Chain's own "every column between the caster
## and the target, inclusive of both ends" line, rather than a radius
## around one point. Same "amount is raw, each illusion mitigates it
## separately via the hero's own armor" contract.
func _deal_line_aoe_damage_to_illusions(start_pos_index: int, end_pos_index: int, amount: float) -> void:
	if _illusions.is_empty() or amount <= 0.0:
		return

	var start_col: int = mini(start_pos_index, end_pos_index)
	var end_col: int = maxi(start_pos_index, end_pos_index)
	var mitigated: float = _apply_armor_reduction(amount, _hero_armor())
	for illusion in _illusions.duplicate():
		var pos: int = illusion["pos_index"]
		if pos >= start_col and pos <= end_col:
			_deal_damage_to_illusion(illusion, mitigated)


## The directional-cone equivalent of the two AoE-shape helpers above -
## for a rival Scatterblast's own "every column strictly ahead of the
## caster, in whichever direction it's facing, up to range_columns"
## cone (same shape _cast_scatterblast()'s own "ahead" check uses for
## the player's copy), rather than a radius or a line between two
## points. Same "amount is raw, each illusion mitigates it separately
## via the hero's own armor" contract.
func _deal_directional_aoe_damage_to_illusions(origin_pos_index: int, direction: int, range_columns: int, amount: float) -> void:
	if _illusions.is_empty() or amount <= 0.0:
		return

	var mitigated: float = _apply_armor_reduction(amount, _hero_armor())
	for illusion in _illusions.duplicate():
		var ahead: int = (illusion["pos_index"] - origin_pos_index) * direction
		if ahead >= 0 and ahead <= range_columns:
			_deal_damage_to_illusion(illusion, mitigated)


## Resolves an Ice Blast cast on `target`: `level_data.damage` to
## `target` and every OTHER living, targetable enemy within
## `level_data.radius` columns of it (mirroring Dark Pact's/Torrent's
## own "one rolled amount, many separately-mitigated hits" pattern),
## then arms this level's own DoT (dot_damage/dot_duration) AND execute
## threshold (execute_pct, the "reserved %" of max HP - see
## _tick_enemy_turn_start_effects() for how that's actually enforced) on every
## one of them that survived the initial hit. `target` alone also gets
## stunned, mirroring Torrent's own "only the primary target" rule for
## its stun.
func _resolve_ice_blast_cast(target: Dictionary, level_data: Dictionary) -> void:
	var generation_before: int = _stage_generation

	var damage: float = float(level_data.get("damage", 0))
	var dot_damage: float = float(level_data.get("dot_damage", 0))
	var dot_duration: int = int(level_data.get("dot_duration", 0))
	var execute_pct: float = float(level_data.get("execute_pct", 0.0))
	var radius: int = int(level_data.get("radius", 1))
	var target_pos: int = target["pos_index"]

	var hit_targets: Array = []
	for enemy in _enemies:
		if _is_target_hidden(enemy):
			continue
		if _distance(enemy["pos_index"], target_pos) <= radius:
			hit_targets.append(enemy)

	# Launched before the hits land - they may kill (and free) the target.
	_play_ice_blast_effect(hero_image, target.get("node"))

	for enemy in hit_targets:
		_deal_fixed_damage_to_enemy(enemy, damage)
		if enemy.get("current_hp", 0) > 0:
			enemy["ice_blast_dot_damage"] = dot_damage
			enemy["ice_blast_dot_turns_left"] = dot_duration
			enemy["ice_blast_execute_pct"] = execute_pct
	_refresh_cold_feet_frost()
	# Centered on the target's own column, same as the check above - a
	# rival's own illusion (Naga Siren's Mirror Image) can be in range
	# independently of whether the boss itself currently is.
	_deal_aoe_damage_to_enemy_illusions(target_pos, radius, damage)

	if target.get("current_hp", 0) > 0:
		target["stun_turns_left"] = int(level_data.get("stun_turns", 1))

	var mana_cost: float = float(level_data.get("mana_cost", 0))
	spend_mana(mana_cost)
	_skill_cooldowns["ice_blast"] = int(level_data.get("cooldown", 0))
	PlayerManager.set_skill_cooldown("ice_blast", _skill_cooldowns["ice_blast"])
	_refresh_skill_cooldown_labels()

	if _battle_over or _stage_generation != generation_before:
		return

	_mark_turn_used()


## Resolves a Splinter Blast cast on `target`: `level_data.damage` to
## `target` alone, then `level_data.splinter_damage` - a separate,
## lighter amount, not a fraction of the main hit - to every OTHER
## living, targetable enemy within `level_data.splinter_range` columns
## of `target`'s own position, mirroring Torrent's own "splash centered
## on the target, never re-hitting it" radius (_resolve_torrent_cast()),
## just with the splash using its own flat damage figure instead of
## reusing the primary hit's.
func _resolve_splinter_blast_cast(target: Dictionary, level_data: Dictionary) -> void:
	var generation_before: int = _stage_generation

	var damage: float = float(level_data.get("damage", 0))
	var splinter_damage: float = float(level_data.get("splinter_damage", 0))
	var splinter_range: int = int(level_data.get("splinter_range", 0))
	var target_pos: int = target["pos_index"]

	# Every unit the splinters will reach, gathered (and their shards
	# launched) before any damage lands - a kill frees its node.
	var splinter_targets: Array = []
	var shard_nodes: Array = []
	for enemy in _enemies:
		if is_same(enemy, target) or _is_target_hidden(enemy):
			continue
		if _distance(enemy["pos_index"], target_pos) <= splinter_range:
			splinter_targets.append(enemy)
			shard_nodes.append(enemy.get("node"))
	for illusion in _enemy_illusions:
		if _distance(illusion["pos_index"], target_pos) <= splinter_range:
			shard_nodes.append(illusion.get("node"))
	_play_splinter_shards(target.get("node"), shard_nodes)

	_deal_fixed_damage_to_enemy(target, damage)
	for enemy in splinter_targets:
		_deal_fixed_damage_to_enemy(enemy, splinter_damage)
	# Centered on the target's own column, same as the check above - a
	# rival's own illusion (Naga Siren's Mirror Image) can be in range
	# independently of whether the boss itself currently is.
	_deal_aoe_damage_to_enemy_illusions(target_pos, splinter_range, splinter_damage)

	var mana_cost: float = float(level_data.get("mana_cost", 0))
	spend_mana(mana_cost)
	_skill_cooldowns["splinter_blast"] = int(level_data.get("cooldown", 0))
	PlayerManager.set_skill_cooldown("splinter_blast", _skill_cooldowns["splinter_blast"])
	_refresh_skill_cooldown_labels()

	if _battle_over or _stage_generation != generation_before:
		return

	_mark_turn_used()


## Resolves a Winter's Curse cast on `target`: freezes it in place for
## `level_data.duration` of its own turns (target["stun_turns_left"],
## the same shared per-enemy field Torrent's/Ice Blast's own stun
## already uses - see _enemy_turn()'s stun check), then marks it as the
## hero's current curse target so _enemy_turn() redirects every OTHER
## enemy within `level_data.curse_range` columns of it for as long as
## that freeze holds (see _is_winters_curse_active()). Recasting while a
## previous curse is still running simply overwrites it outright -
## there's nothing to give back the way Essence Shift's borrowed stats
## need.
func _resolve_winters_curse_cast(target: Dictionary, level_data: Dictionary) -> void:
	var generation_before: int = _stage_generation

	target["stun_turns_left"] = int(level_data.get("duration", 0))
	_winter_curse_target = target
	_winter_curse_bonus_damage_pct = float(level_data.get("bonus_damage_pct", 0.0))
	_winter_curse_range = int(level_data.get("curse_range", 0))

	_show_message_over_hero("Winter's Curse!")
	if is_instance_valid(target.get("node")):
		_flash_bounce_hit(target["node"], COLD_FEET_FLASH_COLOR)
	_refresh_cold_feet_frost()

	var mana_cost: float = float(level_data.get("mana_cost", 0))
	spend_mana(mana_cost)
	_skill_cooldowns["winter's_curse"] = int(level_data.get("cooldown", 0))
	PlayerManager.set_skill_cooldown("winter's_curse", _skill_cooldowns["winter's_curse"])
	_refresh_skill_cooldown_labels()

	if _battle_over or _stage_generation != generation_before:
		return

	_mark_turn_used()


## Whether Winter's Curse is still actively redirecting enemies toward
## its target right now: there's a target at all, it's still part of
## the current fight (_is_enemy_still_active() - the same "hasn't died
## or been cleared by a stage/hero-fight transition" check Essence
## Shift's own donors use), and its freeze (target["stun_turns_left"])
## hasn't run out. No separate duration counter to keep in sync - the
## curse's "pile onto the target" half rides on exactly the same clock
## as the freeze itself, by design (see the state-var block's own
## comment above).
func _is_winters_curse_active() -> bool:
	if _winter_curse_target.is_empty():
		return false
	if not _is_enemy_still_active(_winter_curse_target):
		return false
	return _winter_curse_target.get("stun_turns_left", 0) > 0


## Resolves a Crystal Nova cast on `target`: `level_data.damage` to
## `target`, then - once level_data.radius rises above 0, starting at
## level 3 - that same damage to every OTHER living, targetable enemy
## within `level_data.radius` columns of `target`'s own position too,
## mirroring Torrent's own "splash centered on the target, never
## re-hitting it, same amount as the primary hit" radius
## (_resolve_torrent_cast()).
func _resolve_crystal_nova_cast(target: Dictionary, level_data: Dictionary) -> void:
	var generation_before: int = _stage_generation

	var damage: float = float(level_data.get("damage", 0))
	# Frosted before each hit lands - a kill frees the node.
	_flash_frost_briefly(target.get("node"), CRYSTAL_NOVA_FROST_SECONDS)
	_deal_fixed_damage_to_enemy(target, damage)

	var radius: int = int(level_data.get("radius", 0))
	if radius > 0:
		var target_pos: int = target["pos_index"]
		for enemy in _enemies.duplicate():
			if is_same(enemy, target) or _is_target_hidden(enemy):
				continue
			if _distance(enemy["pos_index"], target_pos) <= radius:
				_flash_frost_briefly(enemy.get("node"), CRYSTAL_NOVA_FROST_SECONDS)
				_deal_fixed_damage_to_enemy(enemy, damage)
		# Centered on the target's own column, same as the splash above -
		# a rival's own illusion (Naga Siren's Mirror Image) can be in
		# range independently of whether the boss itself currently is.
		for illusion in _enemy_illusions:
			if _distance(illusion["pos_index"], target_pos) <= radius:
				_flash_frost_briefly(illusion.get("node"), CRYSTAL_NOVA_FROST_SECONDS)
		_deal_aoe_damage_to_enemy_illusions(target_pos, radius, damage)

	var mana_cost: float = float(level_data.get("mana_cost", 0))
	spend_mana(mana_cost)
	_skill_cooldowns["crystal_nova"] = int(level_data.get("cooldown", 0))
	PlayerManager.set_skill_cooldown("crystal_nova", _skill_cooldowns["crystal_nova"])
	_refresh_skill_cooldown_labels()

	if _battle_over or _stage_generation != generation_before:
		return

	_mark_turn_used()


## Resolves a Frostbite cast on `target`: freezes it in place for
## `level_data.stun_turns` of its own turns (target["stun_turns_left"],
## the same shared per-enemy field Torrent's/Ice Blast's/Winter's
## Curse's own stun already uses), then arms its own damage-over-time
## (target["frostbite_dot_damage"]/["frostbite_dot_turns_left"], ticked
## by _tick_enemy_turn_start_effects() at the start of that enemy's own
## turn, alongside every other DoT) - a
## dedicated pair of fields rather than reusing Cold Feet's/Ice
## Vortex's/Ice Blast's own, so a different skill's DoT never silently
## shares or clobbers another's counters on the same target.
func _resolve_frostbite_cast(target: Dictionary, level_data: Dictionary) -> void:
	var generation_before: int = _stage_generation

	target["stun_turns_left"] = int(level_data.get("stun_turns", 0))
	target["frostbite_dot_damage"] = float(level_data.get("dot_damage", 0))
	target["frostbite_dot_turns_left"] = int(level_data.get("dot_duration", 0))
	if is_instance_valid(target.get("node")):
		_flash_bounce_hit(target["node"], COLD_FEET_FLASH_COLOR)
	_refresh_cold_feet_frost()

	var mana_cost: float = float(level_data.get("mana_cost", 0))
	spend_mana(mana_cost)
	_skill_cooldowns["frostbite"] = int(level_data.get("cooldown", 0))
	PlayerManager.set_skill_cooldown("frostbite", _skill_cooldowns["frostbite"])
	_refresh_skill_cooldown_labels()

	if _battle_over or _stage_generation != generation_before:
		return

	_mark_turn_used()



# ------------------------------------------------------------------
# Kunkka's Tidebringer - a passive, so unlike Torrent above there's no
# button/cast/mana/cooldown for it (see _populate_skill_buttons()'s
# "passive" branch); it just triggers off the hero's own plain Attacks
# (_apply_hero_attack()), exactly the way Curse of Avernus's stacking
# does for Abaddon.
# ------------------------------------------------------------------

## Tidebringer's level data for whatever level the player has it at
## right now - {} if it isn't learned at all (level 0), the same
## "empty means locked" convention every other auto-triggered skill's
## own _get_*_level_data() helper uses.
func _get_tidebringer_level_data() -> Dictionary:
	var level: int = PlayerManager.get_skill_level("tidebringer")
	if level <= 0:
		return {}
	for skill in _hero_static.get("skills", []):
		if skill.get("id", "") == "tidebringer":
			return GameManager.get_skill_level_data(skill, level)
	return {}


## Called from _apply_hero_attack() right before rolling that Attack's
## damage: counts one more plain Attack toward this level's own
## hits_to_activate - never reset by a turn going by without attacking
## (only consuming the count resets it, never time) - and, once that
## threshold is reached, consumes the count and returns this level's
## data for _apply_hero_attack() to fold bonus_damage into the roll and
## then cleave with (_apply_tidebringer_cleave()). Returns {} (an
## ordinary Attack, no bonus) if the hero hasn't learned Tidebringer or
## hasn't reached the threshold yet.
func _maybe_consume_tidebringer_stack() -> Dictionary:
	var level_data: Dictionary = _get_tidebringer_level_data()
	if level_data.is_empty():
		return {}

	_tidebringer_attack_count += 1
	if _tidebringer_attack_count < int(level_data.get("hits_to_activate", 1)):
		return {}

	_tidebringer_attack_count = 0
	_show_rising_message_over(hero_image, "Tidebringer!", TIDEBRINGER_TEXT_COLOR)
	return level_data


## Tidebringer's cleave: every OTHER living, targetable enemy within
## this level's cleave_columns of `target`'s own column takes
## cleave_damage_pct of `attack_damage` - the same raw, pre-mitigation
## roll `target` was just hit with (bonus damage already folded in by
## _apply_hero_attack()), each still mitigated by ITS OWN armor via
## _deal_fixed_damage_to_enemy(), mirroring Dark Pact's own "one rolled
## amount, many separately-mitigated hits" pattern (_cast_dark_pact()).
func _apply_tidebringer_cleave(target: Dictionary, attack_damage: float, level_data: Dictionary) -> void:
	var cleave_damage: float = attack_damage * float(level_data.get("cleave_damage_pct", 0.0))
	if cleave_damage <= 0.0:
		return

	_apply_splash_damage(target, cleave_damage, int(level_data.get("cleave_columns", 1)))


const CLEAVER_DAMAGE_PCT := 0.30
const CLEAVER_RANGE := 1


## The Cleaver item's own passive: identical shape to Tidebringer's
## cleave just above (same "% of the attack's own raw damage, before
## the main target's own armor reduces it, splashed to every OTHER
## living enemy within `radius` columns, each mitigated by its own
## armor separately" rule - see _apply_tidebringer_cleave()) but a
## flat, always-on item bonus rather than a levelled, stack-consuming
## skill proc. Gated on actually owning one - a no-op the instant it's
## sold, same as every other passive "stat" item's own bonus (see
## PlayerManager.get_inventory_stat_bonus()'s own comment on why
## nothing needs to be stored beyond "is it in the inventory right
## now").
func _apply_cleaver_cleave(target: Dictionary, attack_damage: float) -> void:
	if PlayerManager.get_inventory().get("cleaver", 0) <= 0:
		return
	# The cleave is melee-only - a ranged hero still gets Cleaver's flat
	# +10 damage (a plain "stat" bonus, see GameManager's item entry),
	# just no splash. True Form's forced melee counts as melee here,
	# same as everywhere else _is_ranged_hero() is asked.
	if _is_ranged_hero():
		return

	var cleave_damage: float = attack_damage * CLEAVER_DAMAGE_PCT
	if cleave_damage <= 0.0:
		return

	_apply_splash_damage(target, cleave_damage, CLEAVER_RANGE)


# ------------------------------------------------------------------
# Naga Siren's Rip Tide - a passive, so unlike every cast skill above
# there's no button/cast/mana/cooldown for it. Two independent halves:
# a Tidebringer/Cleaver-style AoE splash off the hero's own plain
# Attacks (_apply_rip_tide_cleave(), called from _apply_hero_attack()),
# and a set of flat bonuses folded into Mirror Image's own cast
# (_activate_mirror_image() reads _get_rip_tide_level_data() itself -
# see that function's own comment) rather than anything ticked or
# tracked here.
# ------------------------------------------------------------------

## Rip Tide's level data for whatever level the player has it at right
## now - {} if it isn't learned at all (level 0), the same "empty means
## locked" convention every other auto-triggered skill's own
## _get_*_level_data() helper uses.
func _get_rip_tide_level_data() -> Dictionary:
	var level: int = PlayerManager.get_skill_level("rip_tide")
	if level <= 0:
		return {}
	for skill in _hero_static.get("skills", []):
		if skill.get("id", "") == "rip_tide":
			return GameManager.get_skill_level_data(skill, level)
	return {}


## Rip Tide's own AoE splash: identical shape to Tidebringer's/
## Cleaver's own cleave above (% of the attack's own raw damage, before
## the main target's own armor reduces it, splashed to every OTHER
## living enemy within `radius` columns, each mitigated by its own
## armor separately) but keyed off this level's own aoe_damage_pct/
## radius rather than a flat item bonus or a consumed stack - independent
## of and stacks with Tidebringer's/Cleaver's, same as those two already
## stack with each other. A no-op while the skill isn't learned.
func _apply_rip_tide_cleave(target: Dictionary, attack_damage: float) -> void:
	var level_data: Dictionary = _get_rip_tide_level_data()
	if level_data.is_empty():
		return

	var cleave_damage: float = attack_damage * float(level_data.get("aoe_damage_pct", 0.0))
	if cleave_damage <= 0.0:
		return

	_apply_splash_damage(target, cleave_damage, int(level_data.get("radius", 0)))


## The standard splash/cleave off a hit on `target`: every OTHER living,
## targetable enemy within `radius` columns of `target`'s own column
## takes `splash_damage` - raw and pre-mitigation, each still mitigated
## by ITS OWN armor via _deal_fixed_damage_to_enemy() - and gets
## _flash_bounce_hit()'s red flash, the same one Moon Glaives' bounces
## use, so a splashed enemy visibly reads as hit. Every enemy illusion
## within that same radius is hit (and flashed) too - illusions are
## unconditional collateral on any AoE splash, same rule Moon Glaives
## follows. The boss's own Spirit Bear needs nothing extra: it's a
## regular _enemies entry, so the loop reaches it like any other enemy.
##
## Shared by Tidebringer, the Cleaver item and Rip Tide - any future
## cleave/splash should route through here too, so they all behave and
## look the same.
func _apply_splash_damage(target: Dictionary, splash_damage: float, radius: int) -> void:
	if splash_damage <= 0.0:
		return

	var target_pos: int = target["pos_index"]
	# Iterates a copy - a splash kill removes that enemy from _enemies
	# mid-loop.
	for enemy in _enemies.duplicate():
		if is_same(enemy, target) or _is_target_hidden(enemy):
			continue
		if enemy.get("current_hp", 0) <= 0:
			continue
		if _distance(enemy["pos_index"], target_pos) <= radius:
			_deal_fixed_damage_to_enemy(enemy, splash_damage)
			if is_instance_valid(enemy.get("node")):
				_flash_bounce_hit(enemy["node"])

	_deal_aoe_damage_to_enemy_illusions(target_pos, radius, splash_damage, true)


# ------------------------------------------------------------------
# Luna's Moon Glaives - a passive, so unlike every cast skill above
# there's no button/cast/mana/cooldown for it. Unlike Tidebringer's/
# Cleaver's/Rip Tide's cleave above (every OTHER enemy within radius,
# uncapped), this caps at this level's own `bounces` count - see
# _apply_moon_glaives_bounces()'s own comment.
# ------------------------------------------------------------------

## Moon Glaives' level data for whatever level the player has it at
## right now - {} if it isn't learned at all (level 0), same "empty
## means locked" convention every other auto-triggered skill's own
## _get_*_level_data() helper uses.
func _get_moon_glaives_level_data() -> Dictionary:
	var level: int = PlayerManager.get_skill_level("moon_glaives")
	if level <= 0:
		return {}
	for skill in _hero_static.get("skills", []):
		if skill.get("id", "") == "moon_glaives":
			return GameManager.get_skill_level_data(skill, level)
	return {}


## Moon Glaives' own bounce: the nearest `bounces` other living,
## targetable enemies within `bounce_range` columns of `target`'s own
## column each take `bounce_damage_pct` of `attack_damage` - the same
## raw, pre-mitigation roll `target` was just hit with - still mitigated
## by their own armor separately via _deal_fixed_damage_to_enemy(),
## mirroring Tidebringer's/Cleaver's/Rip Tide's own "one rolled amount,
## many separately-mitigated hits" pattern, just capped at `bounces`
## targets (nearest first) instead of hitting everyone in range. Any
## enemy illusion within that same radius is ALSO hit, via
## _deal_aoe_damage_to_enemy_illusions() - illusions are unconditional
## collateral on any AoE splash, never counted toward the bounce cap
## (see that function's own comment). The boss's own Spirit Bear needs
## no separate call: it's a regular _enemies entry (see
## _get_enemy_spirit_bear()), so the loop below already reaches it like
## any other enemy. Each bounced enemy also gets _flash_bounce_hit()'s
## own quick scale/red-flash, so a bounce reads as a distinct hit
## instead of a damage number appearing on an enemy that was never
## targeted. A no-op while the skill isn't learned.
func _apply_moon_glaives_bounces(target: Dictionary, attack_damage: float) -> void:
	var level_data: Dictionary = _get_moon_glaives_level_data()
	if level_data.is_empty():
		return

	var bounce_damage: float = attack_damage * float(level_data.get("bounce_damage_pct", 0.0))
	if bounce_damage <= 0.0:
		return

	var bounces: int = int(level_data.get("bounces", 0))
	if bounces <= 0:
		return

	var radius: int = int(level_data.get("bounce_range", 0))
	var target_pos: int = target["pos_index"]

	_deal_aoe_damage_to_enemy_illusions(target_pos, radius, bounce_damage)

	var candidates: Array = []
	for enemy in _enemies:
		if is_same(enemy, target) or _is_target_hidden(enemy):
			continue
		if _distance(enemy["pos_index"], target_pos) <= radius:
			candidates.append(enemy)

	candidates.sort_custom(func(a, b): return _distance(a["pos_index"], target_pos) < _distance(b["pos_index"], target_pos))

	for i in range(mini(bounces, candidates.size())):
		var bounced_enemy: Dictionary = candidates[i]
		_deal_fixed_damage_to_enemy(bounced_enemy, bounce_damage)
		if is_instance_valid(bounced_enemy.get("node")):
			_flash_bounce_hit(bounced_enemy["node"])


# ------------------------------------------------------------------
# Luna's Lunar Blessing - a passive, so unlike every cast skill above
# there's no button/cast/mana/cooldown for it. Just a permanent %
# increase to the hero's own Attack damage, read fresh off this level's
# own bonus_damage_pct by _roll_hero_damage() itself (see that
# function's own comment) rather than anything ticked or tracked here.
# ------------------------------------------------------------------

## Lunar Blessing's level data for whatever level the player has it at
## right now - {} if it isn't learned at all (level 0), same "empty
## means locked" convention every other auto-triggered skill's own
## _get_*_level_data() helper uses.
func _get_lunar_blessing_level_data() -> Dictionary:
	var level: int = PlayerManager.get_skill_level("lunar_blessing")
	if level <= 0:
		return {}
	for skill in _hero_static.get("skills", []):
		if skill.get("id", "") == "lunar_blessing":
			return GameManager.get_skill_level_data(skill, level)
	return {}


# ------------------------------------------------------------------
# Slardar's Bash of the Deep - a passive, so unlike every cast skill
# above there's no button/cast/mana/cooldown for it. Counts the hero's
# own plain Attacks toward this level's own attacks_required threshold
# (same "build a stack, consume it all once the threshold's reached"
# idiom Tidebringer's own _maybe_consume_tidebringer_stack() uses,
# just under its own counter rather than a per-enemy one - there's
# only one hero to track this on), then _apply_hero_attack() itself
# folds the returned level data's own bonus_damage_pct into that SAME
# attack's damage (see its own comment) and knocks the target back
# afterward.
# ------------------------------------------------------------------

## Bash of the Deep's level data for whatever level the player has it
## at right now - {} if it isn't learned at all (level 0), the same
## "empty means locked" convention every other auto-triggered skill's
## own _get_*_level_data() helper uses.
func _get_bash_of_the_deep_level_data() -> Dictionary:
	var level: int = PlayerManager.get_skill_level("bash_of_the_deep")
	if level <= 0:
		return {}
	for skill in _hero_static.get("skills", []):
		if skill.get("id", "") == "bash_of_the_deep":
			return GameManager.get_skill_level_data(skill, level)
	return {}


## Called on every plain hero Attack (see _apply_hero_attack()): builds
## one stack, or - once this level's own attacks_required is reached -
## consumes them all and returns the level data for that same Attack to
## apply its bonus/knockback with. Returns {} (a no-op contribution)
## every other Attack, and while the skill isn't learned at all.
func _maybe_consume_bash_of_the_deep_stack() -> Dictionary:
	var level_data: Dictionary = _get_bash_of_the_deep_level_data()
	if level_data.is_empty():
		return {}

	_bash_of_the_deep_attack_count += 1
	if _bash_of_the_deep_attack_count < int(level_data.get("attacks_required", 1)):
		return {}

	_bash_of_the_deep_attack_count = 0
	return level_data


## Knocks `target` back this level's own `knockback` columns, away from
## the hero (his current facing, hero_image.flip_h) - stopping early at
## the board edge or another enemy already occupying the next column,
## same rules Walrus Punch's own knockback follows, just without that
## ultimate's own wall-bonus-damage/stun/animated-slide flourishes
## (this is a passive proc off a plain Attack, not its own cast).
## Repositions instantly via _move_enemy(), the same helper regular
## enemy AI movement already uses.
func _apply_bash_of_the_deep_knockback(target: Dictionary, level_data: Dictionary) -> void:
	var knockback_columns: int = int(level_data.get("knockback", 0))
	var direction: int = -1 if hero_image.flip_h else 1
	var pos: int = target["pos_index"]

	for i in range(knockback_columns):
		var next_pos: int = pos + direction
		if next_pos < 0 or next_pos >= GRID_COLUMNS:
			break
		if not _get_enemy_at(next_pos).is_empty():
			break
		pos = next_pos

	if pos != target["pos_index"]:
		_move_enemy(target, pos)


## The illusion-side equivalent of _apply_bash_of_the_deep_knockback()
## above, for when the triggering hit actually landed on one of the
## boss's own illusions instead (see _apply_hero_attack()'s own read of
## _last_enemy_illusion_redirect). Same movement rule, just repositioning
## an illusion dict directly instead of going through _move_enemy() -
## that helper assumes an "static"/is_hero_fight-flavored enemy entry,
## which an illusion (a plain {pos_index, current_hp, max_hp, node}
## dict, never added to _enemies) doesn't have.
func _apply_bash_of_the_deep_illusion_knockback(illusion: Dictionary, level_data: Dictionary) -> void:
	var knockback_columns: int = int(level_data.get("knockback", 0))
	var direction: int = -1 if hero_image.flip_h else 1
	var pos: int = illusion["pos_index"]

	for i in range(knockback_columns):
		var next_pos: int = pos + direction
		if next_pos < 0 or next_pos >= GRID_COLUMNS:
			break
		if not _get_enemy_at(next_pos).is_empty():
			break
		pos = next_pos

	if pos != illusion["pos_index"]:
		illusion["pos_index"] = pos
		if is_instance_valid(illusion.get("node")):
			illusion["node"].position = Vector2(_index_to_x(pos), _creature_y())


# ------------------------------------------------------------------
# Crystal Maiden's Arcane Aura - a passive, so unlike every cast skill
# above there's no button/cast/mana/cooldown for it (see
# _populate_skill_buttons()'s "passive" branch); it just regenerates
# mana on its own at the start of every hero turn (_apply_arcane_aura_
# regen(), called from _end_turn()).
# ------------------------------------------------------------------

## Arcane Aura's level data for whatever level the player has it at
## right now - {} if it isn't learned at all (level 0), the same
## "empty means locked" convention every other auto-triggered skill's
## own _get_*_level_data() helper uses.
func _get_arcane_aura_level_data() -> Dictionary:
	var level: int = PlayerManager.get_skill_level("arcane_aura")
	if level <= 0:
		return {}
	for skill in _hero_static.get("skills", []):
		if skill.get("id", "") == "arcane_aura":
			return GameManager.get_skill_level_data(skill, level)
	return {}


## Restores this level's own flat bonus_mana_regen, on top of the
## hero's own passive mana regen (_apply_passive_hero_regen(), called
## right after this in _end_turn()) rather than replacing it - once at
## the very start of every hero turn, regardless of whether the player
## actually gets to act that turn (e.g. still stunned or encased in
## Cold Embrace). A no-op while the skill isn't learned.
func _apply_arcane_aura_regen() -> void:
	var level_data: Dictionary = _get_arcane_aura_level_data()
	if level_data.is_empty():
		return

	restore_mana(float(level_data.get("bonus_mana_regen", 0)))


# ------------------------------------------------------------------
# Crystal Maiden's ultimate, Freezing Field.
# ------------------------------------------------------------------

## Activates Freezing Field: arms this level's own damage/radius for
## `level_data.duration` turns. Always "succeeds" - cast on the hero
## himself, no target or range requirement, same as every other
## self-cast buff.
func _activate_freezing_field(level_data: Dictionary) -> void:
	_freezing_field_active = true
	_freezing_field_damage_per_turn = float(level_data.get("damage", 0))
	_freezing_field_radius = int(level_data.get("radius", 0))
	_freezing_field_turns_remaining = int(level_data.get("duration", 0))
	# The casting turn itself doesn't count - duration only starts
	# ticking from the turn after (see _tick_freezing_field()), same as
	# every other duration-based buff.
	_freezing_field_duration_pending_start = true

	_show_message_over_hero("Freezing Field!")


## Ticks Freezing Field's duration down once per End Turn, same timing
## (and same "the casting turn doesn't count" skip) as every other
## duration-based buff - dealing this level's own damage to every
## living, targetable enemy within radius columns of the hero's CURRENT
## position (re-checked fresh here, not fixed at cast time) on every
## tick that actually counts against the duration.
func _tick_freezing_field() -> void:
	if not _freezing_field_active:
		return

	if _freezing_field_duration_pending_start:
		_freezing_field_duration_pending_start = false
		return

	for enemy in _enemies.duplicate():
		if _is_target_hidden(enemy):
			continue
		if _distance(enemy["pos_index"], _hero_pos_index) <= _freezing_field_radius:
			_deal_fixed_damage_to_enemy(enemy, _freezing_field_damage_per_turn)
			if _battle_over:
				return
	# Self-centered on the hero's CURRENT position, same as the check
	# above - a rival's own illusion (Naga Siren's Mirror Image) can be
	# in range independently of whether the boss itself currently is.
	_deal_aoe_damage_to_enemy_illusions(_hero_pos_index, _freezing_field_radius, _freezing_field_damage_per_turn)

	_freezing_field_turns_remaining -= 1
	if _freezing_field_turns_remaining <= 0:
		_end_freezing_field()


## Ends Freezing Field once its duration runs out.
func _end_freezing_field() -> void:
	_freezing_field_active = false
	_freezing_field_damage_per_turn = 0.0
	_freezing_field_radius = 0
	_freezing_field_turns_remaining = 0
	_freezing_field_duration_pending_start = false

	_show_message_over_hero("Freezing Field fades")


# ------------------------------------------------------------------
# Luna's ultimate, Eclipse.
# ------------------------------------------------------------------

# How many beams _tick_eclipse() fires per End Turn while Eclipse is
# active - a flat rule, not a per-level number (only the total beam
# count, damage, and radius scale with level - see GameManager's own
# "eclipse" skill data).
const ECLIPSE_BEAMS_PER_TURN := 2


## Activates Eclipse: arms this level's own damage/radius/beams. Always
## "succeeds" - cast on the hero himself, no target or range
## requirement, same as every other self-cast buff.
func _activate_eclipse(level_data: Dictionary) -> void:
	_eclipse_active = true
	_eclipse_damage_per_beam = float(level_data.get("damage", 0))
	_eclipse_radius = int(level_data.get("radius", 0))
	_eclipse_beams_remaining = int(level_data.get("beams", 0))
	# The casting turn itself doesn't count - beams only start landing
	# from the turn after (see _tick_eclipse()), same as every other
	# duration-based buff.
	_eclipse_duration_pending_start = true

	_show_message_over_hero("Eclipse!")


## Ticks Eclipse once per End Turn, same timing (and same "the casting
## turn doesn't count" skip) as every other duration-based buff: fires
## up to ECLIPSE_BEAMS_PER_TURN beams (or however many are left, if
## fewer) this turn. Each beam independently rolls ONE random living,
## targetable candidate from everything within radius columns of the
## hero's CURRENT position (re-checked fresh here, not fixed at cast
## time, so the range follows her if she moves) - a real enemy or, while
## the rival has Mirror Image up, one of its illusions, both equally
## likely since an illusion is a real occupant of its own column same as
## the boss's own Spirit Bear already is (it's a regular _enemies entry,
## same reasoning as Moon Glaives' own bounce - see
## _apply_moon_glaives_bounces()'s own comment). A beam with nothing in
## range still counts against the total, same as a Dota Eclipse beam
## that finds no target. Every beam that does land also plays Lucent
## Beam's own falling-moonlight visual (_play_lucent_beam_impact()) on
## whatever it struck. Ends the instant every beam has landed.
func _tick_eclipse() -> void:
	if not _eclipse_active:
		return

	if _eclipse_duration_pending_start:
		_eclipse_duration_pending_start = false
		return

	var boss: Dictionary = _get_hero_fight_boss()

	for i in range(ECLIPSE_BEAMS_PER_TURN):
		if _eclipse_beams_remaining <= 0:
			break
		_eclipse_beams_remaining -= 1

		var candidates: Array = []
		for enemy in _enemies:
			if _is_target_hidden(enemy):
				continue
			if _distance(enemy["pos_index"], _hero_pos_index) <= _eclipse_radius:
				candidates.append(enemy)
		if not boss.is_empty():
			for illusion in _enemy_illusions:
				if _distance(illusion["pos_index"], _hero_pos_index) <= _eclipse_radius:
					candidates.append(illusion)

		if not candidates.is_empty():
			var picked: Dictionary = candidates[randi() % candidates.size()]
			if picked.has("static"):
				_deal_fixed_damage_to_enemy(picked, _eclipse_damage_per_beam)
			else:
				var mitigated: float = _apply_armor_reduction(_eclipse_damage_per_beam, _enemy_hero_effective_armor(boss))
				_deal_damage_to_enemy_illusion(picked, mitigated)
			# Same falling moonlight beam Lucent Beam lands with (see
			# _play_lucent_beam_impact()'s own comment) - purely cosmetic,
			# played alongside the damage above rather than gating it.
			_play_lucent_beam_impact(picked.get("node"))

		if _battle_over:
			return

	if _eclipse_beams_remaining <= 0:
		_end_eclipse()


## Ends Eclipse once every beam has landed.
func _end_eclipse() -> void:
	_eclipse_active = false
	_eclipse_damage_per_beam = 0.0
	_eclipse_radius = 0
	_eclipse_beams_remaining = 0
	_eclipse_duration_pending_start = false

	_show_message_over_hero("Eclipse fades")


# ------------------------------------------------------------------
# Tusk's Ice Shards.
# ------------------------------------------------------------------

## Resolves an Ice Shards cast on `target`: `level_data.damage` to
## `target` (still mitigated by its own armor, via _deal_fixed_damage_
## to_enemy() - same helper every other targeted skill uses), then
## walls off `level_data.blocked_columns` columns for `level_data.
## duration` turns - starting on the hero's OWN column and continuing
## one column at a time toward `target`'s, stopping early if that walk
## would run off either edge of the board. Recasting while a previous
## wall is still up simply replaces it outright.
func _resolve_ice_shards_cast(target: Dictionary, level_data: Dictionary) -> void:
	var generation_before: int = _stage_generation

	var damage: float = float(level_data.get("damage", 0))
	_deal_fixed_damage_to_enemy(target, damage)

	var direction: int = _step_toward(_hero_pos_index, target["pos_index"])
	if direction == 0:
		direction = 1

	var blocked_columns: int = int(level_data.get("blocked_columns", 0))
	var columns: Array[int] = []
	var col: int = _hero_pos_index
	for i in range(blocked_columns):
		if col < 0 or col >= GRID_COLUMNS:
			break
		columns.append(col)
		col += direction

	_ice_shards_active = true
	_ice_shards_blocked_columns = columns
	_ice_shards_turns_remaining = int(level_data.get("duration", 0))
	# The casting turn itself doesn't count - duration only starts
	# ticking from the turn after (see _tick_ice_shards()), same as
	# every other duration-based effect.
	_ice_shards_duration_pending_start = true
	_refresh_ice_shards_visuals()

	var mana_cost: float = float(level_data.get("mana_cost", 0))
	spend_mana(mana_cost)
	_skill_cooldowns["ice_shards"] = int(level_data.get("cooldown", 0))
	PlayerManager.set_skill_cooldown("ice_shards", _skill_cooldowns["ice_shards"])
	_refresh_skill_cooldown_labels()

	if _battle_over or _stage_generation != generation_before:
		return

	_mark_turn_used()


## Ticks Ice Shards' duration down once per End Turn, same timing (and
## same "the casting turn doesn't count" skip) as every other duration-
## based effect.
func _tick_ice_shards() -> void:
	if not _ice_shards_active:
		return

	if _ice_shards_duration_pending_start:
		_ice_shards_duration_pending_start = false
		return

	_ice_shards_turns_remaining -= 1
	if _ice_shards_turns_remaining <= 0:
		_end_ice_shards()


## Ends Ice Shards once its duration runs out - the walled-off columns
## reopen to movement immediately.
func _end_ice_shards() -> void:
	_ice_shards_active = false
	_ice_shards_blocked_columns = []
	_ice_shards_turns_remaining = 0
	_ice_shards_duration_pending_start = false
	_refresh_ice_shards_visuals()


## Rebuilds the on-screen ice-wall art from scratch against whatever's
## actually walled off right now, on either side (the player's own
## Ice Shards and a rival Tusk's both use the same image) - called
## from every place either side's own blocked-columns list changes
## (cast, natural expiry, a recast replacing the old columns) so
## there's never a stale wall left over from one that's no longer up,
## or a missing one for a wall that just went up. Semi-transparent and
## layered like Ghostship's own flight animation (a root-level sibling
## placed right after enemies_layer, so it draws over the hero/enemy
## sprites without a z-order fight) rather than fully opaque, so a
## creature standing in a walled column (very likely - both sides'
## own walls always start on the caster's own column) still reads
## through it.
func _refresh_ice_shards_visuals() -> void:
	for node in _ice_shards_wall_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_ice_shards_wall_nodes.clear()

	if not ResourceLoader.exists(ICE_SHARDS_WALL_IMAGE_PATH):
		return

	var columns: Array[int] = []
	if _ice_shards_active:
		columns.append_array(_ice_shards_blocked_columns)
	if _enemy_ice_shards_active:
		for col in _enemy_ice_shards_blocked_columns:
			if col not in columns:
				columns.append(col)

	if columns.is_empty():
		return

	var texture: Texture2D = load(ICE_SHARDS_WALL_IMAGE_PATH)
	var tex_size: Vector2 = texture.get_size()
	var wall_width: float = _grid_unit() * 0.9
	var wall_height: float = wall_width * (tex_size.y / tex_size.x)
	var ground_y: float = _creature_y() + get_viewport_rect().size.y / 4.0

	for col in columns:
		var wall := TextureRect.new()
		wall.texture = texture
		wall.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		wall.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
		wall.mouse_filter = Control.MOUSE_FILTER_IGNORE
		wall.modulate = Color(1, 1, 1, 0.85)
		wall.size = Vector2(wall_width, wall_height)
		wall.position = Vector2(_index_to_x(col) + (_grid_unit() - wall_width) / 2.0, ground_y - wall_height)
		add_child(wall)
		move_child(wall, enemies_layer.get_index() + 1)
		_ice_shards_wall_nodes.append(wall)


## Whether `col` is currently walled off by Ice Shards - checked from
## every PLAIN movement decision in _enemy_turn()/_enemy_hero_turn()
## (flee, "close in", Winter's Curse's own redirect) so an enemy
## standing in a blocked column can't move at all and one standing
## outside it can't step into one, i.e. can't move past it. A true
## teleport (X Marks the Spot) still isn't checked against this - it
## doesn't travel through the columns in between at all, unlike a jump
## (Pounce, Snowball) or a pull (Timber Chain), which now ARE stopped
## by a wall in their path on both sides (see _cast_pounce()/
## _resolve_snowball_cast()/_resolve_timber_chain_cast() and their own
## _is_column_enemy_ice_shards_blocked() checks for the player's own
## copies, _cast_enemy_pounce()/_cast_enemy_snowball() for the rival's).
func _is_column_ice_shards_blocked(col: int) -> bool:
	return _ice_shards_active and col in _ice_shards_blocked_columns


# ------------------------------------------------------------------
# Tusk's Snowball.
# ------------------------------------------------------------------

## Resolves a Snowball cast on `target`: moves the hero straight onto
## `target`'s own column - or, if a rival's Ice Shards wall sits
## somewhere in that path, only as far as one column short of it -
## updating his LOGICAL position immediately, same as every other
## action, so anything checked right after (range, _stage_generation,
## etc.) already sees him there - then deals
## `level_data.damage` and stuns it for `level_data.stun_turns` if it
## survives, same stun mechanism Torrent's/Ice Blast's/Frostbite's own
## use. The charge itself (portrait swap to SNOWBALL_IMAGE_PATH, a
## tween sliding his VISUAL position across to match) is purely
## cosmetic and layered on top afterward, same "instant, already-
## resolved outcome, cosmetic animation played alongside it" split
## Ghostship's own travel already uses - see _end_snowball_animation()
## for the revert.
func _resolve_snowball_cast(target: Dictionary, level_data: Dictionary) -> void:
	var generation_before: int = _stage_generation

	var start_pos_index: int = _hero_pos_index
	var target_pos_index: int = target["pos_index"]

	var damage: float = float(level_data.get("damage", 0))
	_deal_fixed_damage_to_enemy(target, damage)
	if target.get("current_hp", 0) > 0:
		target["stun_turns_left"] = int(level_data.get("stun_turns", 1))

	# The charge physically carries the hero across every column in
	# between (unlike X Marks the Spot's true teleport), so a rival's
	# Ice Shards wall in its path stops it one column short of
	# target_pos_index, same rule Pounce's own leap and Timber Chain's
	# own pull now follow.
	var charge_direction: int = _step_toward(start_pos_index, target_pos_index)
	var landing_pos_index: int = start_pos_index
	while charge_direction != 0 and landing_pos_index != target_pos_index:
		var next_pos: int = landing_pos_index + charge_direction
		if _is_column_enemy_ice_shards_blocked(next_pos):
			break
		landing_pos_index = next_pos

	_hero_pos_index = landing_pos_index
	# Hero art is drawn facing right by default (see _hero_move()'s own
	# note on art orientation), so charging left mirrors it to face
	# that way.
	hero_image.flip_h = landing_pos_index < start_pos_index
	_set_hero_image(SNOWBALL_IMAGE_PATH)

	var tween := create_tween()
	tween.tween_property(hero_image, "position:x", _index_to_x(landing_pos_index), SNOWBALL_TRAVEL_DURATION)
	tween.finished.connect(_end_snowball_animation)

	var mana_cost: float = float(level_data.get("mana_cost", 0))
	spend_mana(mana_cost)
	_skill_cooldowns["snowball"] = int(level_data.get("cooldown", 0))
	PlayerManager.set_skill_cooldown("snowball", _skill_cooldowns["snowball"])
	_refresh_skill_cooldown_labels()

	if _battle_over or _stage_generation != generation_before:
		return

	_mark_turn_used()


## Reverts the hero's portrait back to normal and snaps his visual
## position to match his (already-updated) logical one, once the
## charge's own travel tween finishes.
func _end_snowball_animation() -> void:
	_set_hero_image(_hero_static.get("image", ""))
	_update_hero_position()


# ------------------------------------------------------------------
# Tusk's Tag Team.
# ------------------------------------------------------------------

## Activates Tag Team: arms this level's own bonus_damage for
## `level_data.duration` turns. Always "succeeds" - no target or range
## requirement to cast it, same as every other self-cast buff.
func _activate_tag_team(level_data: Dictionary) -> void:
	_tag_team_active = true
	_tag_team_bonus_damage = float(level_data.get("bonus_damage", 0))
	_tag_team_turns_remaining = int(level_data.get("duration", 0))
	# The casting turn itself doesn't count - duration only starts
	# ticking from the turn after (see _tick_tag_team()), same as every
	# other duration-based buff.
	_tag_team_duration_pending_start = true

	_show_message_over_hero("Tag Team!")


## Ticks Tag Team's duration down once per End Turn, same timing (and
## same "the casting turn doesn't count" skip) as every other duration-
## based buff.
func _tick_tag_team() -> void:
	if not _tag_team_active:
		return

	if _tag_team_duration_pending_start:
		_tag_team_duration_pending_start = false
		return

	_tag_team_turns_remaining -= 1
	if _tag_team_turns_remaining <= 0:
		_end_tag_team()


## Ends Tag Team once its duration runs out.
func _end_tag_team() -> void:
	_tag_team_active = false
	_tag_team_bonus_damage = 0.0
	_tag_team_turns_remaining = 0
	_tag_team_duration_pending_start = false

	_show_message_over_hero("Tag Team wears off")


# ------------------------------------------------------------------
# Tusk's ultimate, Walrus Punch.
# ------------------------------------------------------------------

## Resolves a Walrus Punch cast on `target`: rolls the hero's own
## Attack damage (_roll_hero_damage(), same roll a plain Attack uses)
## and multiplies it by this level's own damage_multiplier, then works
## out how far the knockback actually carries - walking one column at a
## time, away from Tusk's current facing direction (hero_image.flip_h),
## for up to `level_data.knockback` columns, stopping early at the edge
## of the board or at the first column another living, targetable enemy
## already occupies. Coming up short either way ("hits a wall or
## another obstacle") adds 50% more damage to this same hit before it
## lands - the critical-hit-styled number _deal_fixed_damage_to_enemy()
## shows either way (see its own `is_critical` param) is already that
## boosted total.
## Unlike every other targeted skill here, the knockback plays out
## BEFORE damage: `target`'s LOGICAL position updates immediately (same
## as always), but its VISUAL slide (WALRUS_PUNCH_KNOCKBACK_DURATION)
## has to actually finish before _resolve_walrus_punch_damage() deals
## the hit, checks for death, and stuns it if it survives - so a punch
## that kills still visibly sends its target flying first, instead of
## it just vanishing on the spot. Skips the tween entirely (resolving
## instantly) if the target never actually moved - already pinned
## against something this same turn, so there's nothing to show.
func _resolve_walrus_punch_cast(target: Dictionary, level_data: Dictionary) -> void:
	var generation_before: int = _stage_generation

	var multiplier: float = float(level_data.get("damage_multiplier", 1.0))
	var punch_damage: float = _roll_hero_damage() * multiplier

	var knockback_columns: int = int(level_data.get("knockback", 0))
	var direction: int = -1 if hero_image.flip_h else 1
	var pos: int = target["pos_index"]
	var actual_distance: int = 0
	for i in range(knockback_columns):
		var next_pos: int = pos + direction
		if next_pos < 0 or next_pos >= GRID_COLUMNS:
			break
		if not _get_enemy_at(next_pos).is_empty():
			break
		pos = next_pos
		actual_distance += 1

	var hit_wall: bool = actual_distance < knockback_columns
	if hit_wall:
		punch_damage *= 1.5

	if actual_distance > 0 and is_instance_valid(target.get("node")):
		target["pos_index"] = pos
		# Same facing convention as _move_enemy() - hero-fight art
		# faces right natively, every other enemy's faces left.
		var native_faces_right: bool = target["static"].get("is_hero_fight", false)
		target["node"].flip_h = (direction < 0) if native_faces_right else (direction > 0)

		var tween := create_tween()
		tween.tween_property(target["node"], "position:x", _index_to_x(pos), WALRUS_PUNCH_KNOCKBACK_DURATION)
		tween.finished.connect(_resolve_walrus_punch_damage.bind(target, punch_damage, hit_wall, level_data, generation_before))
	else:
		_resolve_walrus_punch_damage(target, punch_damage, hit_wall, level_data, generation_before)


## Second half of a Walrus Punch cast, deferred until the knockback
## slide (see _resolve_walrus_punch_cast()) has actually finished
## playing: deals the punch's own damage, shows "Wall hit!" if it fell
## short of its full knockback distance, and - if the target survived -
## stuns it in place for `level_data.stun_turns`, the same shared
## stun_turns_left field Torrent's/Ice Blast's/Frostbite's/Snowball's
## own stun already uses. Bails out first if a stage/hero-fight
## transition already happened while the slide was playing - the same
## generation guard every other targeted cast checks before spending
## anything.
func _resolve_walrus_punch_damage(target: Dictionary, punch_damage: float, hit_wall: bool, level_data: Dictionary, generation_before: int) -> void:
	if _stage_generation != generation_before:
		return

	_deal_fixed_damage_to_enemy(target, punch_damage, true)

	if hit_wall:
		_show_message_over_hero("Wall hit!")

	if target.get("current_hp", 0) > 0:
		target["stun_turns_left"] = int(level_data.get("stun_turns", 1))

	var mana_cost: float = float(level_data.get("mana_cost", 0))
	spend_mana(mana_cost)
	_skill_cooldowns["walrus_punch"] = int(level_data.get("cooldown", 0))
	PlayerManager.set_skill_cooldown("walrus_punch", _skill_cooldowns["walrus_punch"])
	_refresh_skill_cooldown_labels()

	if _battle_over or _stage_generation != generation_before:
		return

	_mark_turn_used()


# ------------------------------------------------------------------
# Treant Protector's Leech Seed.
# ------------------------------------------------------------------

## Resolves a Leech Seed cast on `target`: no immediate damage, just
## arms this level's own dot_damage/heal_per_turn onto `target`'s own
## dedicated leech_seed_dot_turns_left counter - a separate pair of
## fields from Cold Feet's/Ice Vortex's/Ice Blast's/Frostbite's own
## DoTs, same "never silently shares or clobbers another skill's
## counters on the same target" reasoning those already follow - ticked
## once per turn, at the start of that enemy's own turn, by
## _tick_enemy_turn_start_effects(), healing the hero the same amount
## it damages the target.
func _resolve_leech_seed_cast(target: Dictionary, level_data: Dictionary) -> void:
	var generation_before: int = _stage_generation

	target["leech_seed_dot_damage"] = float(level_data.get("dot_damage", 0))
	target["leech_seed_heal_per_turn"] = float(level_data.get("heal_per_turn", 0))
	target["leech_seed_dot_turns_left"] = int(level_data.get("duration", 0))

	var mana_cost: float = float(level_data.get("mana_cost", 0))
	spend_mana(mana_cost)
	_skill_cooldowns["leech_seed"] = int(level_data.get("cooldown", 0))
	PlayerManager.set_skill_cooldown("leech_seed", _skill_cooldowns["leech_seed"])
	_refresh_skill_cooldown_labels()

	if _battle_over or _stage_generation != generation_before:
		return

	_mark_turn_used()



# ------------------------------------------------------------------
# Treant Protector's Living Armor.
# ------------------------------------------------------------------

## Activates Living Armor: arms this level's own bonus_armor/
## bonus_hp_regen for `level_data.duration` turns. Always "succeeds" -
## cast on the hero himself, no target or range requirement, same as
## every other self-cast buff.
func _activate_living_armor(level_data: Dictionary) -> void:
	_living_armor_active = true
	_living_armor_bonus_armor = float(level_data.get("bonus_armor", 0))
	_living_armor_bonus_hp_regen = float(level_data.get("bonus_hp_regen", 0))
	_living_armor_turns_remaining = int(level_data.get("duration", 0))
	# The casting turn itself doesn't count - duration only starts
	# ticking from the turn after (see _tick_living_armor()), same as
	# every other duration-based buff.
	_living_armor_duration_pending_start = true

	_show_message_over_hero("Living Armor!")


## Ticks Living Armor's duration down once per End Turn, same timing
## (and same "the casting turn doesn't count" skip) as every other
## duration-based buff - healing the hero for this level's own
## bonus_hp_regen, on top of his baseline passive regen
## (_apply_passive_hero_regen()), on every tick that actually counts
## against the duration.
func _tick_living_armor() -> void:
	if not _living_armor_active:
		return

	if _living_armor_duration_pending_start:
		_living_armor_duration_pending_start = false
		return

	heal(_living_armor_bonus_hp_regen)
	_living_armor_turns_remaining -= 1
	if _living_armor_turns_remaining <= 0:
		_end_living_armor()


## Ends Living Armor once its duration runs out.
func _end_living_armor() -> void:
	_living_armor_active = false
	_living_armor_bonus_armor = 0.0
	_living_armor_bonus_hp_regen = 0.0
	_living_armor_turns_remaining = 0
	_living_armor_duration_pending_start = false

	_show_message_over_hero("Living Armor wears off")


# ------------------------------------------------------------------
# Timbersaw's Reactive Armor (passive - see the field comment above
# _reactive_armor_stack_turns for the overall shape).
# ------------------------------------------------------------------

## Reactive Armor's level data for whatever level the player has it at
## right now - {} if it isn't learned at all (level 0) or the current
## hero isn't Timbersaw, the same "empty means locked" convention every
## other auto-triggered skill's own _get_*_level_data() helper uses.
func _get_reactive_armor_level_data() -> Dictionary:
	var level: int = PlayerManager.get_skill_level("reactive_armor")
	if level <= 0:
		return {}
	for skill in _hero_static.get("skills", []):
		if skill.get("id", "") == "reactive_armor":
			return GameManager.get_skill_level_data(skill, level)
	return {}


## Reactive Armor's current total armor bonus - this level's own
## bonus_armor_per_stack times however many stacks are currently up.
## Folded into _hero_armor(). A no-op (0.0) while the skill isn't
## learned or no stacks are up.
func _reactive_armor_bonus_armor() -> float:
	var level_data: Dictionary = _get_reactive_armor_level_data()
	if level_data.is_empty():
		return 0.0
	return _reactive_armor_stack_turns.size() * float(level_data.get("bonus_armor_per_stack", 0.0))


## Called from apply_damage() every time a hit actually lands on the
## hero, regardless of source (Attack, skill nuke, DoT tick - anything
## routed through apply_damage()). Adds one stack with this level's own
## full duration; if that would exceed max_stacks, the oldest stack
## (soonest to expire) is dropped first so the count never exceeds the
## cap. A no-op while the skill isn't learned.
func _apply_reactive_armor_stack() -> void:
	var level_data: Dictionary = _get_reactive_armor_level_data()
	if level_data.is_empty():
		return

	var max_stacks: int = int(level_data.get("max_stacks", 0))
	if _reactive_armor_stack_turns.size() >= max_stacks:
		_reactive_armor_stack_turns.pop_front()
	_reactive_armor_stack_turns.append(int(level_data.get("duration", 0)))


## Ticks every active stack's own remaining-turns counter down by one,
## once per End Turn, dropping any that reach zero - independently of
## each other, unlike every other duration-based buff in this file
## which only ever tracks one shared timer. A no-op while no stacks are
## up (including while the skill isn't learned, since then none can
## ever have been added).
func _tick_reactive_armor_stacks() -> void:
	for i in range(_reactive_armor_stack_turns.size()):
		_reactive_armor_stack_turns[i] -= 1
	_reactive_armor_stack_turns = _reactive_armor_stack_turns.filter(func(turns_left): return turns_left > 0)


## Heals this level's own bonus_hp_regen_per_stack times however many
## stacks are currently up, once at the start of every hero turn - same
## timing/stacking relationship (on top of, not instead of) as Arcane
## Aura's and the baseline passive regen. A no-op while the skill isn't
## learned or no stacks are up.
func _apply_reactive_armor_regen() -> void:
	var level_data: Dictionary = _get_reactive_armor_level_data()
	if level_data.is_empty() or _reactive_armor_stack_turns.is_empty():
		return

	heal(_reactive_armor_stack_turns.size() * float(level_data.get("bonus_hp_regen_per_stack", 0.0)))


# ------------------------------------------------------------------
# Treant Protector's ultimate, Overgrowth.
# ------------------------------------------------------------------

## Activates Overgrowth: every living, targetable enemy within
## `level_data.radius` columns of the hero's CURRENT position gets
## rooted (target["root_turns_left"], the same shared per-enemy field
## Entangle's/Nature's Guise's/Ice Shards'/Winter's Curse's own root/
## freeze effects already use - it can still attack and cast skills
## while rooted, same as any other rooted enemy) for `level_data.
## root_duration` turns, and armed with that same level's own DoT
## (target["overgrowth_dot_damage"]/["overgrowth_dot_turns_left"], a
## dedicated pair of fields so it never clobbers another skill's DoT on
## the same enemy) for the same duration - ticked, at the start of each
## enemy's own turn, by _tick_enemy_turn_start_effects(). Always
## "succeeds" - cast on the hero himself, no target or range
## requirement, same as every other self-cast buff/AoE.
func _activate_overgrowth(level_data: Dictionary) -> void:
	var dot_damage: float = float(level_data.get("dot_damage", 0))
	var root_duration: int = int(level_data.get("root_duration", 0))
	var radius: int = int(level_data.get("radius", 0))

	for enemy in _enemies:
		if _is_target_hidden(enemy):
			continue
		if _distance(enemy["pos_index"], _hero_pos_index) <= radius:
			enemy["root_turns_left"] = root_duration
			enemy["overgrowth_dot_damage"] = dot_damage
			enemy["overgrowth_dot_turns_left"] = root_duration

	# A rival's own illusion (Naga Siren's Mirror Image) has no root/DoT
	# of its own to carry the way a regular enemy does above - just a
	# one-time hit for whatever's caught in the burst, centered on the
	# hero's own position, same as the check above.
	_deal_aoe_damage_to_enemy_illusions(_hero_pos_index, radius, dot_damage)

	_show_message_over_hero("Overgrowth!")


## Resolves a Mist Coil cast on Abaddon himself: pays `level_data.
## hp_cost` straight off current_hp - no armor mitigation, same as the
## Spirit Bear's death penalty (_apply_bear_death_penalty()) - then
## heals for `level_data.heal`, which is always more than the HP cost,
## for a net gain. If the hero doesn't have enough HP to cover the
## cost, nothing happens at all: no HP lost, no heal, and - like a
## failed Pounce/Dark Pact/Entangle target search - no mana, cooldown,
## or turn spent either, so the player can simply try something else.
func _resolve_mist_coil_self_cast(level_data: Dictionary) -> void:
	var hp_cost: float = float(level_data.get("hp_cost", 0))
	var current_hp: float = float(_recruited.get("current_hp", 0))
	if current_hp < hp_cost:
		_cancel_targeting()
		_show_message_over_hero("Not enough HP")
		return

	_cancel_targeting()
	var generation_before: int = _stage_generation

	PlayerManager.damage_hero(hp_cost)
	heal(float(level_data.get("heal", 0)))
	_play_mist_coil_effect(hero_image, hero_image)

	var mana_cost: float = float(level_data.get("mana_cost", 0))
	spend_mana(mana_cost)
	_skill_cooldowns["mist_coil"] = int(level_data.get("cooldown", 0))
	PlayerManager.set_skill_cooldown("mist_coil", _skill_cooldowns["mist_coil"])
	_refresh_skill_cooldown_labels()

	if _battle_over or _stage_generation != generation_before:
		return

	_mark_turn_used()


## Puts Entangle's root/silence/damage-over-time state onto `target`:
##   - "root_turns_left": can't move while > 0 (checked in
##     _enemy_turn()'s movement fallback and flee logic) - it can
##     still attack normally if something's already in its range.
##   - "silence_turns_left": blocks a hero-fight boss's own skill casts
##     while it's > 0 (see _is_enemy_silenced()/_enemy_hero_turn()) -
##     the same field Curse of Avernus's own silence writes onto this
##     target (_apply_curse_of_avernus_stack()). Regular creeps never
##     cast skills in the first place, so this only ever matters
##     against a hero-fight boss.
##   - "entangle_dot_damage"/"entangle_dot_turns_left": ticked once per
##     turn by _tick_enemy_turn_start_effects(), dealing that much
##     damage (through normal armor mitigation) for that many turns.
## Recasting Entangle on an already-rooted target simply overwrites
## its counters with this cast's fresh values rather than stacking.
func _apply_root(target: Dictionary, level_data: Dictionary) -> void:
	target["root_turns_left"] = int(level_data.get("root_turns", 0))
	target["silence_turns_left"] = int(level_data.get("silence_turns", 0))
	target["entangle_dot_damage"] = float(level_data.get("dot_damage", 0))
	target["entangle_dot_turns_left"] = int(level_data.get("dot_duration", 0))


## Applies every "start of its own turn" damage-over-time currently on
## `enemy`, all in one pass, right before anything else about its turn
## is decided (stun included - see the call site in _enemy_turn()/
## _enemy_hero_turn()): Entangle's own DoT, Curse of Avernus's DoT
## (ending the curse once its own duration runs out - stack decay for a
## NOT-yet-activated curse is a separate, turn-count-based check handled
## by _tick_curse_of_avernus_effects() instead, since it isn't a DoT),
## Cold Feet's/Ice Vortex's/Frostbite's/Leech Seed's own DoTs (Leech
## Seed also healing the hero back), Ice Blast's DoT plus its own
## execute-threshold check, and Treant Protector's Overgrowth DoT -
## each a dedicated pair of fields so none of them ever clobber each
## other on the same enemy. Every damage instance is still mitigated by
## the enemy's own armor, via _deal_fixed_damage_to_enemy(). Bails out
## the moment a hit ends the battle (last enemy dies, stage clears,
## etc.) - the caller then knows to stop processing this enemy (and the
## turn) immediately, same reasoning the old per-skill tick functions
## this replaces used to need individually. Also stops early (without
## ending the battle) the moment `enemy` itself dies partway through,
## since there's nothing left on it worth ticking further that turn.
## Root/silence (Entangle's own counters, also reused by Nature's Guise's
## root) are deliberately NOT decremented here, unlike everything else in
## this function - unlike a DoT, they GATE a decision later in this same
## turn (_is_enemy_rooted()/_is_enemy_silenced(), checked from _enemy_
## turn()/_enemy_hero_turn() after this call returns), so decrementing
## them up front would burn off one full turn's worth of root/silence
## before it ever actually blocked anything - a 1-turn root would never
## stop a single move. They're decremented instead at the point they're
## actually consumed, the same "check with the CURRENT value, use it,
## decrement after" pattern stun_turns_left already uses in _enemy_turn().
func _tick_enemy_turn_start_effects(enemy: Dictionary) -> void:
	# Lil' Shredder's armor shred and Slardar's Corrosive Haze both
	# write "armor_reduction" (Corrosive Haze also "corrosive_haze_
	# bonus_pct", see _deal_fixed_damage_to_enemy()'s own read of it) -
	# cast during the PLAYER's turn, but only ever ticked here (the
	# start of THIS enemy's own turn), so the round either was cast in
	# is never counted against duration for free, no separate "pending
	# start" flag needed (see _resolve_lil_shredder_cast()'s own
	# comment). Both share the one counter/expiry, same "reapplying
	# overwrites the timer" convention every other refreshable debuff in
	# this file already uses - a rare edge case if both ever land on the
	# same enemy at once, not worth a second counter for.
	if enemy.get("armor_reduction_turns_left", 0) > 0:
		enemy["armor_reduction_turns_left"] -= 1
		if enemy.get("armor_reduction_turns_left", 0) <= 0:
			enemy["armor_reduction"] = 0.0
			enemy["corrosive_haze_bonus_pct"] = 0.0

	# Mortimer Kisses' burn: re-armed (both damage and turns_left) by
	# every main-hit shot that lands on this enemy (see
	# _fire_mortimer_kisses_shot()), never by its splash - so "the DoT
	# duration starts from the first hit" falls out for free here too,
	# same reasoning the armor shred block above already spells out.
	if enemy.get("mortimer_burn_dot_turns_left", 0) > 0:
		enemy["mortimer_burn_dot_turns_left"] -= 1
		var mortimer_burn_dot: float = float(enemy.get("mortimer_burn_dot_damage", 0))
		if mortimer_burn_dot > 0.0:
			_deal_fixed_damage_to_enemy(enemy, mortimer_burn_dot, false, false)
			if _battle_over or enemy.get("current_hp", 0) <= 0:
				return

	if enemy.get("entangle_dot_turns_left", 0) > 0:
		enemy["entangle_dot_turns_left"] -= 1
		var entangle_dot: float = float(enemy.get("entangle_dot_damage", 0))
		if entangle_dot > 0.0:
			_deal_fixed_damage_to_enemy(enemy, entangle_dot, false, false)
			if _battle_over or enemy.get("current_hp", 0) <= 0:
				return

	if enemy.get("curse_active", false):
		if enemy.get("curse_dot_turns_left", 0) > 0:
			enemy["curse_dot_turns_left"] -= 1
			var curse_dot: float = float(enemy.get("curse_dot_damage", 0))
			if curse_dot > 0.0:
				_deal_fixed_damage_to_enemy(enemy, curse_dot, false, false)
				if _battle_over or enemy.get("current_hp", 0) <= 0:
					return
		if enemy.get("curse_dot_turns_left", 0) <= 0:
			enemy["curse_active"] = false
			enemy["curse_dot_damage"] = 0.0

	if enemy.get("cold_feet_dot_turns_left", 0) > 0:
		enemy["cold_feet_dot_turns_left"] -= 1
		var cold_feet_dot: float = float(enemy.get("cold_feet_dot_damage", 0))
		if cold_feet_dot > 0.0:
			_deal_fixed_damage_to_enemy(enemy, cold_feet_dot, false, false)
			if _battle_over or enemy.get("current_hp", 0) <= 0:
				return

	if enemy.get("ice_vortex_dot_turns_left", 0) > 0:
		enemy["ice_vortex_dot_turns_left"] -= 1
		var ice_vortex_dot: float = float(enemy.get("ice_vortex_dot_damage", 0))
		if ice_vortex_dot > 0.0:
			_deal_fixed_damage_to_enemy(enemy, ice_vortex_dot, false, false)
			if _battle_over or enemy.get("current_hp", 0) <= 0:
				return

	if enemy.get("ice_blast_dot_turns_left", 0) > 0:
		enemy["ice_blast_dot_turns_left"] -= 1
		var ice_blast_dot: float = float(enemy.get("ice_blast_dot_damage", 0))
		if ice_blast_dot > 0.0:
			_deal_fixed_damage_to_enemy(enemy, ice_blast_dot, false, false)
			if _battle_over or enemy.get("current_hp", 0) <= 0:
				return

		if enemy.get("current_hp", 0) > 0:
			var execute_pct: float = float(enemy.get("ice_blast_execute_pct", 0.0))
			var max_hp: float = float(enemy["static"].get("hp", 1))
			if execute_pct > 0.0 and enemy["current_hp"] <= max_hp * execute_pct:
				_kill_enemy(enemy)
				if _battle_over:
					return

		if enemy.get("ice_blast_dot_turns_left", 0) <= 0:
			enemy["ice_blast_execute_pct"] = 0.0

		if enemy.get("current_hp", 0) <= 0:
			return

	if enemy.get("frostbite_dot_turns_left", 0) > 0:
		enemy["frostbite_dot_turns_left"] -= 1
		var frostbite_dot: float = float(enemy.get("frostbite_dot_damage", 0))
		if frostbite_dot > 0.0:
			_deal_fixed_damage_to_enemy(enemy, frostbite_dot, false, false)
			if _battle_over or enemy.get("current_hp", 0) <= 0:
				return

	if enemy.get("leech_seed_dot_turns_left", 0) > 0:
		enemy["leech_seed_dot_turns_left"] -= 1
		var leech_seed_dot: float = float(enemy.get("leech_seed_dot_damage", 0))
		if leech_seed_dot > 0.0:
			_deal_fixed_damage_to_enemy(enemy, leech_seed_dot, false, false)
			if _battle_over:
				return
		var leech_seed_heal: float = float(enemy.get("leech_seed_heal_per_turn", 0))
		if leech_seed_heal > 0.0:
			heal(leech_seed_heal)
		if enemy.get("current_hp", 0) <= 0:
			return

	if enemy.get("overgrowth_dot_turns_left", 0) > 0:
		enemy["overgrowth_dot_turns_left"] -= 1
		var overgrowth_dot: float = float(enemy.get("overgrowth_dot_damage", 0))
		if overgrowth_dot > 0.0:
			_deal_fixed_damage_to_enemy(enemy, overgrowth_dot, false, false)


## The player-side mirror of _tick_enemy_turn_start_effects(): every
## "start of the player's own turn" duration counter and damage-over-
## time a rival hero could have inflicted on him, ticked in one pass
## against the single-player battle-local vars instead of a per-enemy
## Dictionary - Entangle's root/silence counters and DoT, Curse of
## Avernus's DoT (stack decay lives in _tick_enemy_curse_of_avernus_
## effects() instead, same "not a DoT" reasoning as the enemy-side
## version), Cold Feet's/Ice Vortex's/Frostbite's own DoTs, Ice Blast's
## DoT plus its own execute-threshold check, Treant Protector's Leech
## Seed (unlike every other DoT here, its own healing half goes to the
## CASTER - the rival - not the player, so this heals the boss directly
## via _get_hero_fight_boss() each tick instead of calling heal()), and
## Overgrowth's own DoT (its root shares _player_root_turns_left above,
## the same field Entangle's own root already ticks down), Snapfire's
## Lil' Shredder armor reduction (a plain countdown, zeroing the
## reduction itself once it runs out - no damage of its own to deal,
## just folded into _hero_armor() for as long as it's up), and Mortimer
## Kisses' own burn DoT. Called once, right where the player's own new
## turn opens in _end_turn() - before he gets to act. Unlike the
## enemy-side version, nothing here needs to bail out mid-function on a
## kill: apply_damage() never frees nodes or changes scenes the way
## killing an enemy can, so _end_turn() just checks the hero's HP once,
## right after calling this.
func _tick_player_turn_start_effects() -> void:
	if _player_root_turns_left > 0:
		_player_root_turns_left -= 1
	if _player_silence_turns_left > 0:
		_player_silence_turns_left -= 1

	if _player_entangle_dot_turns_left > 0:
		_player_entangle_dot_turns_left -= 1
		if _player_entangle_dot_damage > 0.0:
			apply_damage(_player_entangle_dot_damage)

	if _player_curse_active:
		if _player_curse_dot_turns_left > 0:
			_player_curse_dot_turns_left -= 1
			if _player_curse_dot_damage > 0.0:
				apply_damage(_player_curse_dot_damage)
		if _player_curse_dot_turns_left <= 0:
			_player_curse_active = false
			_player_curse_dot_damage = 0.0

	if _player_cold_feet_dot_turns_left > 0:
		_player_cold_feet_dot_turns_left -= 1
		if _player_cold_feet_dot_damage > 0.0:
			apply_damage(_player_cold_feet_dot_damage)

	if _player_ice_vortex_dot_turns_left > 0:
		_player_ice_vortex_dot_turns_left -= 1
		if _player_ice_vortex_dot_damage > 0.0:
			apply_damage(_player_ice_vortex_dot_damage)
	# His illusions caught in the same vortex tick right here too,
	# independently of whether the hero himself still is - and so does
	# every DoT a rival has put on his Spirit Bear.
	_tick_player_allies_ice_vortex()
	_tick_bear_turn_start_effects()

	if _player_ice_blast_dot_turns_left > 0:
		_player_ice_blast_dot_turns_left -= 1
		if _player_ice_blast_dot_damage > 0.0:
			apply_damage(_player_ice_blast_dot_damage)

		if _recruited.get("current_hp", 0) > 0 and _player_ice_blast_execute_pct > 0.0:
			var max_hp: float = _hero_max_hp()
			if max_hp > 0.0 and float(_recruited.get("current_hp", 0)) <= max_hp * _player_ice_blast_execute_pct:
				PlayerManager.damage_hero(float(_recruited.get("current_hp", 0)))
				_refresh_bars()

		if _player_ice_blast_dot_turns_left <= 0:
			_player_ice_blast_execute_pct = 0.0

	if _player_frostbite_dot_turns_left > 0:
		_player_frostbite_dot_turns_left -= 1
		if _player_frostbite_dot_damage > 0.0:
			apply_damage(_player_frostbite_dot_damage)

	if _player_leech_seed_dot_turns_left > 0:
		_player_leech_seed_dot_turns_left -= 1
		if _player_leech_seed_dot_damage > 0.0:
			apply_damage(_player_leech_seed_dot_damage)
		# Unlike every other DoT above, the healing half goes to the
		# CASTER (the rival), not the player - mirrors the player's own
		# _resolve_leech_seed_cast()/_tick_enemy_turn_start_effects()
		# ("leech_seed" case), just healing the boss directly here
		# instead of the player.
		if _player_leech_seed_heal_per_turn > 0.0:
			var leech_seed_caster: Dictionary = _get_hero_fight_boss()
			if not leech_seed_caster.is_empty():
				var caster_max_hp: float = _enemy_hero_effective_max_hp(leech_seed_caster)
				leech_seed_caster["current_hp"] = minf(caster_max_hp, float(leech_seed_caster.get("current_hp", 0.0)) + _player_leech_seed_heal_per_turn)

	if _player_overgrowth_dot_turns_left > 0:
		_player_overgrowth_dot_turns_left -= 1
		if _player_overgrowth_dot_damage > 0.0:
			apply_damage(_player_overgrowth_dot_damage)

	if _player_armor_reduction_turns_left > 0:
		_player_armor_reduction_turns_left -= 1
		if _player_armor_reduction_turns_left <= 0:
			_player_armor_reduction = 0.0
			_player_corrosive_haze_bonus_pct = 0.0

	if _player_mortimer_burn_dot_turns_left > 0:
		_player_mortimer_burn_dot_turns_left -= 1
		if _player_mortimer_burn_dot_damage > 0.0:
			apply_damage(_player_mortimer_burn_dot_damage)


## Whether `enemy` is currently rooted by Entangle and therefore can't
## move (it can still attack normally if something's already in
## range) - checked from _enemy_turn()'s flee/movement-fallback logic.
func _is_enemy_rooted(enemy: Dictionary) -> bool:
	return enemy.get("root_turns_left", 0) > 0


## Whether `enemy` is currently silenced - by Entangle or Curse of
## Avernus, both of which write the same `silence_turns_left` field
## (see _apply_root()/_apply_curse_of_avernus_stack()) - and therefore
## can't cast a skill this turn. Checked from _enemy_hero_turn(), the
## only enemy AI that ever casts skills in the first place.
func _is_enemy_silenced(enemy: Dictionary) -> bool:
	return enemy.get("silence_turns_left", 0) > 0


## Activates Essence Shift: arms the next `level_data.attacks` melee
## hits to each steal 1 point of their target's main stat, for
## `level_data.duration` turns. Always "succeeds" (there's no target
## or range requirement to activate it, unlike Pounce/Dark Pact) - it
## just arms the effect for upcoming attacks. Recasting while a
## previous activation is still running first returns everything that
## one had borrowed (as if its duration had just run out) so the two
## instances' durations/attack counts never get mixed together.
func _activate_essence_shift(level_data: Dictionary) -> void:
	if _essence_shift_active:
		_end_essence_shift()

	_essence_shift_active = true
	_essence_shift_attacks_remaining = int(level_data.get("attacks", 0))
	_essence_shift_turns_remaining = int(level_data.get("duration", 0))
	# The casting turn itself doesn't count - duration only starts
	# ticking from the turn after (see _tick_essence_shift()).
	_essence_shift_duration_pending_start = true


## Called right after a melee Attack lands (see _apply_hero_attack()).
## If Essence Shift is active and still has attacks banked, steals 1
## point of `target`'s main stat - down to
## GameManager.ESSENCE_SHIFT_MIN_ENEMY_MAIN_STAT, never lower - and
## converts it into the matching Slark bonus via
## _essence_shift_contribution_for(). A hit that can't steal anything
## (enemy already at the floor, or has no main stat at all) doesn't
## spend one of the banked attacks.
func _apply_essence_shift_steal(target: Dictionary) -> void:
	if not _essence_shift_active or _essence_shift_attacks_remaining <= 0:
		return

	var stat_name: String = str(target["static"].get("main_stat", "")).to_lower()
	if stat_name == "":
		return

	var current_value: float = float(target.get("current_main_stat_value", 0.0))
	if current_value <= GameManager.ESSENCE_SHIFT_MIN_ENEMY_MAIN_STAT:
		_show_message_over_hero("Nothing left to steal")
		return

	target["current_main_stat_value"] = current_value - 1.0
	_essence_shift_attacks_remaining -= 1
	_essence_shift_stolen.append({"enemy": target, "stat": stat_name, "amount": 1.0})

	var contribution: Dictionary = _essence_shift_contribution_for(stat_name)
	_essence_shift_bonus["damage"] = _essence_shift_bonus.get("damage", 0.0) + contribution["damage"]
	_essence_shift_bonus["hp"] = _essence_shift_bonus.get("hp", 0.0) + contribution["hp"]
	_essence_shift_bonus["mana"] = _essence_shift_bonus.get("mana", 0.0) + contribution["mana"]
	_essence_shift_bonus["armor"] = _essence_shift_bonus.get("armor", 0.0) + contribution["armor"]

	_play_drain_effect(target.get("node"), hero_image, ESSENCE_SHIFT_MOTE_COLOR)
	_refresh_bars()


## Purely cosmetic: a short stream of small motes drifting from
## `from_node` (whoever was just drained) to `to_node` (whoever did the
## draining), each along its own slightly-arced path and staggered so
## they read as a flow rather than a single blob, in `mote_color`. Used
## by Essence Shift's steal (ESSENCE_SHIFT_MOTE_COLOR) and Spirit Link's
## lifesteal (SPIRIT_LINK_MOTE_COLOR), each from both the player's side
## and the rival's - the stat/HP has already moved by the time this
## plays; it never gates on this. Individual tweened ColorRects rather than
## CPUParticles2D (see _play_scatterblast_effect()) since every mote has
## to land on a specific moving-free target point, not just spray out.
func _play_drain_effect(from_node: Variant, to_node: Variant, mote_color: Color) -> void:
	if not (from_node is Control) or not (to_node is Control):
		return
	if not is_instance_valid(from_node) or not is_instance_valid(to_node):
		return

	var start: Vector2 = from_node.position + from_node.size / 2.0
	var end: Vector2 = to_node.position + to_node.size / 2.0
	var travel: Vector2 = end - start
	# Perpendicular to the flight line - each mote's arc bulges along
	# this by a random amount, up or down.
	var normal: Vector2 = Vector2(-travel.y, travel.x).normalized() if travel.length() > 0.001 else Vector2.UP
	var arc_height: float = maxf(24.0, travel.length() * 0.25)

	var mote_count: int = 14
	var flight_time: float = 0.55
	var stagger: float = 0.025
	var mote_size: float = 7.0

	for i in mote_count:
		var mote := ColorRect.new()
		mote.color = mote_color
		mote.size = Vector2(mote_size, mote_size)
		mote.pivot_offset = mote.size / 2.0
		mote.rotation = PI / 4.0
		mote.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mote.modulate.a = 0.0
		var jitter: Vector2 = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * from_node.size * 0.2
		var mote_start: Vector2 = start + jitter
		var control_point: Vector2 = (mote_start + end) / 2.0 + normal * arc_height * randf_range(-1.0, 1.0)
		mote.position = mote_start - mote.pivot_offset
		add_child(mote)
		# Same layering as _play_scatterblast_effect() - at the hero/enemy
		# layer, not on top of every UI panel.
		move_child(mote, enemies_layer.get_index() + 1)

		var tween: Tween = mote.create_tween()
		tween.tween_interval(i * stagger)
		tween.tween_property(mote, "modulate:a", 1.0, 0.08)
		tween.parallel().tween_method(
			func(t: float) -> void:
				var a: Vector2 = mote_start.lerp(control_point, t)
				var b: Vector2 = control_point.lerp(end, t)
				mote.position = a.lerp(b, t) - mote.pivot_offset,
			0.0, 1.0, flight_time
		).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		# Shrink/fade on arrival, as if absorbed.
		tween.tween_property(mote, "scale", Vector2(0.2, 0.2), 0.12)
		tween.parallel().tween_property(mote, "modulate:a", 0.0, 0.12)
		tween.tween_callback(mote.queue_free)


## What 1 stolen point of `stat_name` ("strength"/"agility"/
## "intelligence") is worth to Slark, in the same battle-facing terms
## his own stat growth uses (see GameManager.compute_derived_stats):
## strength -> hp, agility -> armor, intelligence -> mana, each at
## that same per-point rate. On top of that, if `stat_name` happens to
## be Slark's own main stat, the point also adds damage - exactly like
## a hero's main-stat growth does.
func _essence_shift_contribution_for(stat_name: String) -> Dictionary:
	var contribution: Dictionary = {"damage": 0.0, "hp": 0.0, "mana": 0.0, "armor": 0.0}

	match stat_name:
		"strength":
			contribution["hp"] = GameManager.HP_PER_STRENGTH
		"agility":
			contribution["armor"] = GameManager.ARMOR_PER_AGILITY
		"intelligence":
			contribution["mana"] = GameManager.MANA_PER_INTELLIGENCE

	if stat_name == str(_hero_static.get("main_stat", "")).to_lower():
		contribution["damage"] = GameManager.DAMAGE_PER_MAIN_STAT

	return contribution


## Ticks Essence Shift's duration down once per End Turn, same timing
## as _tick_skill_cooldowns() - except the very first call after the
## skill is cast is skipped (see _essence_shift_duration_pending_start)
## so the casting turn itself doesn't count against the duration.
func _tick_essence_shift() -> void:
	if not _essence_shift_active:
		return

	if _essence_shift_duration_pending_start:
		_essence_shift_duration_pending_start = false
		return

	_essence_shift_turns_remaining -= 1
	if _essence_shift_turns_remaining <= 0:
		_end_essence_shift()


## Essence Shift has run its course: Slark loses every borrowed point
## and each donor enemy that's still alive gets its point(s) back
## (donors from a stage/hero fight that's already moved on are simply
## skipped - see _is_enemy_still_active()).
func _end_essence_shift() -> void:
	for entry in _essence_shift_stolen:
		var donor: Dictionary = entry["enemy"]
		if _is_enemy_still_active(donor):
			donor["current_main_stat_value"] = float(donor.get("current_main_stat_value", 0.0)) + float(entry["amount"])

	_essence_shift_stolen.clear()
	_essence_shift_bonus = {"damage": 0.0, "hp": 0.0, "mana": 0.0, "armor": 0.0}
	_essence_shift_active = false
	_essence_shift_attacks_remaining = 0
	_essence_shift_turns_remaining = 0
	_essence_shift_duration_pending_start = false

	_refresh_bars()
	_show_message_over_hero("Essence Shift wore off")


## Whether `enemy_ref` (one of _enemies' own dictionaries, stashed
## earlier in _essence_shift_stolen) is still part of the current
## fight - false once it's died, or once a stage/hero-fight transition
## has cleared and replaced the whole _enemies roster.
func _is_enemy_still_active(enemy_ref: Dictionary) -> bool:
	for enemy in _enemies:
		if enemy == enemy_ref:
			return true
	return false


# ------------------------------------------------------------------
# Winter Wyvern's Arctic Burn.
# ------------------------------------------------------------------

## Activates Arctic Burn: arms this level's own bonus_damage/bonus_range
## for the next `level_data.attacks` plain Attacks, or `level_data.
## duration` turns - whichever runs out first (see
## _apply_arctic_burn_attack()/_tick_arctic_burn()). Always "succeeds" -
## no target or range requirement to cast it, same as Essence Shift/
## Shadow Dance.
func _activate_arctic_burn(level_data: Dictionary) -> void:
	_arctic_burn_active = true
	_arctic_burn_bonus_damage = float(level_data.get("bonus_damage", 0))
	_arctic_burn_bonus_range = int(level_data.get("bonus_range", 0))
	_arctic_burn_attacks_remaining = int(level_data.get("attacks", 0))
	_arctic_burn_turns_remaining = int(level_data.get("duration", 0))
	# The casting turn itself doesn't count - duration only starts
	# ticking from the turn after (see _tick_arctic_burn()), same as
	# every other duration-based buff.
	_arctic_burn_duration_pending_start = true


## Called right after a plain Attack lands (see _apply_hero_attack()).
## Spends one of Arctic Burn's banked attacks, if any are left, and ends
## the whole effect right there once the last one is used - the other
## half of the attacks-or-duration race _tick_arctic_burn() runs on the
## turn-count side.
func _apply_arctic_burn_attack() -> void:
	if not _arctic_burn_active or _arctic_burn_attacks_remaining <= 0:
		return

	_arctic_burn_attacks_remaining -= 1
	if _arctic_burn_attacks_remaining <= 0:
		_end_arctic_burn()


## Ticks Arctic Burn's duration down once per End Turn, same timing (and
## same "the casting turn doesn't count" skip) as Essence Shift's own
## _tick_essence_shift().
func _tick_arctic_burn() -> void:
	if not _arctic_burn_active:
		return

	if _arctic_burn_duration_pending_start:
		_arctic_burn_duration_pending_start = false
		return

	_arctic_burn_turns_remaining -= 1
	if _arctic_burn_turns_remaining <= 0:
		_end_arctic_burn()


## Arctic Burn has run its course - either every banked Attack got used
## (_apply_arctic_burn_attack()) or its duration ran out first
## (_tick_arctic_burn()), whichever came first.
func _end_arctic_burn() -> void:
	_arctic_burn_active = false
	_arctic_burn_bonus_damage = 0.0
	_arctic_burn_bonus_range = 0
	_arctic_burn_attacks_remaining = 0
	_arctic_burn_turns_remaining = 0
	_arctic_burn_duration_pending_start = false

	_show_message_over_hero("Arctic Burn wore off")


# ------------------------------------------------------------------
# Winter Wyvern's Cold Embrace.
# ------------------------------------------------------------------

## Activates Cold Embrace: dispels every OTHER effect currently on the
## hero (see _dispel_all_hero_effects()), swaps his portrait to
## COLD_EMBRACE_IMAGE_PATH, and arms this level's own heal_per_turn for
## `level_data.duration` turns - during which apply_damage() blocks
## every hit outright and _hero_move()/_on_attack_pressed() refuse to
## act. Always "succeeds" - no target or range requirement to cast it,
## same as every other self-cast buff.
func _activate_cold_embrace(level_data: Dictionary) -> void:
	_dispel_all_hero_effects()

	_cold_embrace_active = true
	_cold_embrace_heal_per_turn = float(level_data.get("heal", 0))
	_cold_embrace_turns_remaining = int(level_data.get("duration", 0))
	# The casting turn itself doesn't count - duration only starts
	# ticking from the turn after (see _tick_cold_embrace()), same as
	# every other duration-based buff.
	_cold_embrace_duration_pending_start = true

	_set_hero_image(COLD_EMBRACE_IMAGE_PATH)
	_show_message_over_hero("Encased in ice!")
	_flash_bounce_hit(hero_image, COLD_FEET_FLASH_COLOR)
	_refresh_cold_feet_frost()


## Dispels every other effect currently on the hero, good or bad, right
## before Cold Embrace establishes its own state (_activate_cold_
## embrace()): every self-buff that could in principle be active - only
## ever really Arctic Burn for Winter Wyvern's own kit, since the rest
## belong to other heroes, but this stays generic and correct regardless
## of whose battle it runs in - plus every debuff a rival hero fight
## boss could have inflicted (root, silence, Entangle's/Curse of
## Avernus's/Cold Feet's/Ice Vortex's/Ice Blast's/Frostbite's/Leech
## Seed's/Overgrowth's/Mortimer Kisses' burn damage-over-time, Ice
## Blast's execute threshold, Pounce's/Torrent's stun, Lil' Shredder's
## own armor reduction, and a hostile Essence Shift's stat penalty) -
## the same field list _reset_enemy_hero_state() clears fresh for each
## new hero fight.
func _dispel_all_hero_effects() -> void:
	if _arctic_burn_active:
		_end_arctic_burn()
	if _essence_shift_active:
		_end_essence_shift()
	if _shadow_dance_active:
		_end_shadow_dance()
	if _moonlight_shadow_active:
		_end_moonlight_shadow()
	if _spirit_link_active:
		_end_spirit_link()
	if _true_form_active:
		_end_true_form()
	if _aphotic_shield_active:
		_end_aphotic_shield(false)
	if _borrowed_time_active:
		_end_borrowed_time()

	_player_essence_shift_penalty = {"damage": 0.0, "hp": 0.0, "mana": 0.0, "armor": 0.0}
	_player_root_turns_left = 0
	_player_silence_turns_left = 0
	_player_entangle_dot_damage = 0.0
	_player_entangle_dot_turns_left = 0
	_player_stun_turns_left = 0
	_player_winters_curse_active = false
	_player_curse_stacks = 0
	_player_curse_active = false
	_player_curse_dot_damage = 0.0
	_player_curse_dot_turns_left = 0
	_player_curse_last_hit_turn = 0
	_player_cold_feet_dot_damage = 0.0
	_player_cold_feet_dot_turns_left = 0
	_player_ice_vortex_dot_damage = 0.0
	_player_ice_vortex_dot_turns_left = 0
	_player_ice_blast_dot_damage = 0.0
	_player_ice_blast_dot_turns_left = 0
	_player_ice_blast_execute_pct = 0.0
	_player_frostbite_dot_damage = 0.0
	_player_frostbite_dot_turns_left = 0
	_player_leech_seed_dot_damage = 0.0
	_player_leech_seed_heal_per_turn = 0.0
	_player_leech_seed_dot_turns_left = 0
	_player_overgrowth_dot_damage = 0.0
	_player_overgrowth_dot_turns_left = 0
	_player_armor_reduction = 0.0
	_player_armor_reduction_turns_left = 0
	_player_corrosive_haze_bonus_pct = 0.0
	_player_mortimer_burn_dot_damage = 0.0
	_player_mortimer_burn_dot_turns_left = 0

	_refresh_bars()


## Ticks Cold Embrace's duration down once per End Turn, same timing
## (and same "the casting turn doesn't count" skip) as every other
## duration-based buff - healing the hero for this level's own
## heal_per_turn on every tick that actually counts against the
## duration (the skipped casting-turn one doesn't heal either).
func _tick_cold_embrace() -> void:
	if not _cold_embrace_active:
		return

	if _cold_embrace_duration_pending_start:
		_cold_embrace_duration_pending_start = false
		return

	heal(_cold_embrace_heal_per_turn)
	_cold_embrace_turns_remaining -= 1
	if _cold_embrace_turns_remaining <= 0:
		_end_cold_embrace()


## Ends Cold Embrace once its duration runs out: reverts the hero's
## portrait and drops his damage immunity/heal-per-turn/full-action
## lockout (see _update_action_buttons()/_end_turn()'s own auto-skip).
func _end_cold_embrace() -> void:
	_cold_embrace_active = false
	_cold_embrace_heal_per_turn = 0.0
	_cold_embrace_turns_remaining = 0
	_cold_embrace_duration_pending_start = false

	_set_hero_image(_hero_static.get("image", ""))
	_show_message_over_hero("Cold Embrace wears off")
	_refresh_cold_feet_frost()


# ------------------------------------------------------------------
# Slark's Shadow Dance.
# ------------------------------------------------------------------

## True while the hero is hidden by Shadow Dance OR Nature's Guise -
## whichever the current hero actually has, since only one of the two
## could ever be active in a given battle. Enemy attacks check this in
## _enemy_turn() and simply don't land while it's true.
func _is_hero_hidden() -> bool:
	return _shadow_dance_active or _natures_guise_active or _moonlight_shadow_active


## Whether the rival can currently see (and therefore attack, chase, or
## otherwise target) the player, despite Shadow Dance's/Nature's
## Guise's/Moonlight Shadow's own stealth - true sight from a rival
## Slardar's own Corrosive Haze (_player_corrosive_haze_bonus_pct > 0,
## the same field _cast_enemy_corrosive_haze() writes and apply_damage()
## reads for its own damage bonus, both sharing _player_armor_reduction_
## turns_left's own countdown) overrides it for as long as the mark
## holds. Deliberately kept separate from _is_hero_hidden() itself -
## that one still needs to report the player's OWN actual stealth state
## honestly (e.g. so casting another skill still ends it early, see
## _on_skill_pressed()'s own check) - true sight only ever changes
## whether an ENEMY can currently perceive it, never whether it's
## really active. Used everywhere the rival's own AI decides whether it
## can currently see the player (_enemy_turn()/_enemy_hero_turn()) in
## place of a bare _is_hero_hidden() read.
func _can_enemy_see_hero() -> bool:
	if _player_corrosive_haze_bonus_pct > 0.0:
		return true
	return not _is_hero_hidden()


## Activates Shadow Dance: hides Slark for `level_data.duration` turns
## (not counting the casting turn itself - see
## _shadow_dance_duration_pending_start) and arms
## `level_data.bonus_damage` for whichever comes first, his next
## Attack or the duration running out.
func _activate_shadow_dance(level_data: Dictionary) -> void:
	_shadow_dance_active = true
	_shadow_dance_bonus_damage = float(level_data.get("bonus_damage", 0))
	_shadow_dance_turns_remaining = int(level_data.get("duration", 0))
	_shadow_dance_duration_pending_start = true
	_update_hero_visibility()


## Ticks Shadow Dance's duration down once per End Turn, same timing
## and same "casting turn doesn't count" rule as Essence Shift (see
## _tick_essence_shift()).
func _tick_shadow_dance() -> void:
	if not _shadow_dance_active:
		return

	if _shadow_dance_duration_pending_start:
		_shadow_dance_duration_pending_start = false
		return

	_shadow_dance_turns_remaining -= 1
	if _shadow_dance_turns_remaining <= 0:
		_end_shadow_dance()


## Ends Shadow Dance, whether from its duration running out, Slark
## attacking while hidden, or casting another skill while hidden.
func _end_shadow_dance() -> void:
	_shadow_dance_active = false
	_shadow_dance_bonus_damage = 0.0
	_shadow_dance_turns_remaining = 0
	_shadow_dance_duration_pending_start = false
	_update_hero_visibility()


# ------------------------------------------------------------------
# Treant Protector's Nature's Guise.
# ------------------------------------------------------------------

## Activates Nature's Guise: hides the hero for `level_data.duration`
## turns (not counting the casting turn itself) and arms `level_data.
## root_turns` for whichever comes first, his next Attack or the
## duration running out - same "casting turn doesn't count"/"one-shot
## payoff on the breaking Attack" shape as Shadow Dance's own
## _activate_shadow_dance(), just with a root instead of bonus damage.
func _activate_natures_guise(level_data: Dictionary) -> void:
	_natures_guise_active = true
	_natures_guise_root_turns = int(level_data.get("root_turns", 0))
	_natures_guise_turns_remaining = int(level_data.get("duration", 0))
	_natures_guise_duration_pending_start = true
	_update_hero_visibility()


## Ticks Nature's Guise's duration down once per End Turn, same timing
## and same "casting turn doesn't count" rule as Shadow Dance's own
## _tick_shadow_dance().
func _tick_natures_guise() -> void:
	if not _natures_guise_active:
		return

	if _natures_guise_duration_pending_start:
		_natures_guise_duration_pending_start = false
		return

	_natures_guise_turns_remaining -= 1
	if _natures_guise_turns_remaining <= 0:
		_end_natures_guise()


## Ends Nature's Guise, whether from its duration running out, the hero
## attacking while hidden, or casting another skill while hidden.
func _end_natures_guise() -> void:
	_natures_guise_active = false
	_natures_guise_root_turns = 0
	_natures_guise_turns_remaining = 0
	_natures_guise_duration_pending_start = false
	_update_hero_visibility()


# ------------------------------------------------------------------
# Mirana's ultimate, Moonlight Shadow.
# ------------------------------------------------------------------

## Activates Moonlight Shadow: hides Mirana for `level_data.duration`
## turns (not counting the casting turn itself - see
## _moonlight_shadow_duration_pending_start) and arms
## `level_data.bonus_damage_pct` for whichever comes first, her next
## Attack or the duration running out - same overall shape as Shadow
## Dance's own _activate_shadow_dance(), just a percentage bonus
## instead of a flat one (see the field comment above
## _moonlight_shadow_active).
func _activate_moonlight_shadow(level_data: Dictionary) -> void:
	_moonlight_shadow_active = true
	_moonlight_shadow_bonus_damage_pct = float(level_data.get("bonus_damage_pct", 0.0))
	_moonlight_shadow_turns_remaining = int(level_data.get("duration", 0))
	_moonlight_shadow_duration_pending_start = true
	_update_hero_visibility()


## Ticks Moonlight Shadow's duration down once per End Turn, same
## timing and same "casting turn doesn't count" rule as Shadow Dance
## (see _tick_shadow_dance()).
func _tick_moonlight_shadow() -> void:
	if not _moonlight_shadow_active:
		return

	if _moonlight_shadow_duration_pending_start:
		_moonlight_shadow_duration_pending_start = false
		return

	_moonlight_shadow_turns_remaining -= 1
	if _moonlight_shadow_turns_remaining <= 0:
		_end_moonlight_shadow()


## Ends Moonlight Shadow, whether from its duration running out, Mirana
## attacking while hidden, or casting another skill while hidden.
func _end_moonlight_shadow() -> void:
	_moonlight_shadow_active = false
	_moonlight_shadow_bonus_damage_pct = 0.0
	_moonlight_shadow_turns_remaining = 0
	_moonlight_shadow_duration_pending_start = false
	_update_hero_visibility()


## Slight fade to represent invisibility - fully opaque and visible
## otherwise. Called whenever Shadow Dance, Nature's Guise, or
## Moonlight Shadow starts or ends.
func _update_hero_visibility() -> void:
	hero_image.modulate = Color(1, 1, 1, 0.4) if _is_hero_hidden() else Color(1, 1, 1, 1)


# ------------------------------------------------------------------
# Lone Druid's Spirit Link.
# ------------------------------------------------------------------

## Activates (or refreshes) Spirit Link at `level_data`'s values.
## Nothing needs to be "returned" the way Essence Shift's borrowed
## stats do on recast, since the bonus armor/lifesteal aren't taken
## from anything - overwriting the running values is enough.
func _activate_spirit_link(level_data: Dictionary) -> void:
	_spirit_link_active = true
	_spirit_link_lifesteal_pct = float(level_data.get("lifesteal_pct", 0.0))
	_spirit_link_bonus_armor = float(level_data.get("bonus_armor", 0))
	_spirit_link_turns_remaining = int(level_data.get("duration", 0))
	_spirit_link_duration_pending_start = true
	_set_spirit_link_visual(hero_image, true)


## Ticks Spirit Link's duration down once per End Turn, same timing
## and "casting turn doesn't count" rule as Essence Shift/Shadow Dance.
func _tick_spirit_link() -> void:
	if not _spirit_link_active:
		return

	if _spirit_link_duration_pending_start:
		_spirit_link_duration_pending_start = false
		return

	_spirit_link_turns_remaining -= 1
	if _spirit_link_turns_remaining <= 0:
		_end_spirit_link()


## Ends Spirit Link, whether from its duration running out or a fresh
## cast overwriting it outright (see _activate_spirit_link()).
func _end_spirit_link() -> void:
	_spirit_link_active = false
	_spirit_link_lifesteal_pct = 0.0
	_spirit_link_bonus_armor = 0.0
	_spirit_link_turns_remaining = 0
	_spirit_link_duration_pending_start = false
	_set_spirit_link_visual(hero_image, false)


## Purely cosmetic: while Spirit Link is active, `node` (the player's
## hero_image, or the rival Lone Druid's own node) grows to
## SPIRIT_LINK_SCALE. Only does anything when the state actually
## changes (the "base_scale" meta is the "currently on" marker), so a
## recast while it's already up just leaves it as is.
func _set_spirit_link_visual(node: Variant, active: bool) -> void:
	if not (node is Control) or not is_instance_valid(node):
		return
	var target_scale: Vector2 = Vector2.ONE * (SPIRIT_LINK_SCALE if active else 1.0)
	if node.get_meta("base_scale", Vector2.ONE) == target_scale:
		return

	node.set_meta("base_scale", target_scale)
	node.pivot_offset = node.size / 2.0
	var scale_tween: Tween = node.create_tween()
	scale_tween.tween_property(node, "scale", target_scale, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Spirit Link's lifesteal: converts `_spirit_link_lifesteal_pct` of an
## Attack's damage - AFTER the target's armor has already reduced it -
## into HP for the hero. Only called from _apply_hero_attack() (the
## plain Attack action, melee or ranged) - skill damage (Pounce, Dark
## Pact, Entangle's DoT, the Spirit Bear's own hits, etc.) never routes
## through here, matching the skill's own wording. No-op while Spirit
## Link isn't active or the hit did no damage (e.g. fully absorbed).
## `target` is only used for the red drain motes flowing from it back
## to the hero (_play_drain_effect()).
func _apply_spirit_link_lifesteal(mitigated_attack_damage: float, target: Dictionary) -> void:
	if not _spirit_link_active or mitigated_attack_damage <= 0.0:
		return
	heal(mitigated_attack_damage * _spirit_link_lifesteal_pct)
	_play_drain_effect(target.get("node"), hero_image, SPIRIT_LINK_MOTE_COLOR)


const MORBID_MASK_LIFESTEAL_PCT := 0.10


## The Morbid Mask item's own passive: identical shape to Spirit
## Link's own lifesteal just above (same "% of the plain Attack's
## damage, after the target's own armor already reduced it" rule,
## never skill damage) but a flat, always-on item bonus rather than a
## temporary skill buff - stacks with Spirit Link if the player has
## both active at once. Gated on actually owning one, same as
## Cleaver's own item check (see _apply_cleaver_cleave()).
func _apply_morbid_mask_lifesteal(mitigated_attack_damage: float) -> void:
	if mitigated_attack_damage <= 0.0 or PlayerManager.get_inventory().get("morbid_mask", 0) <= 0:
		return
	heal(mitigated_attack_damage * MORBID_MASK_LIFESTEAL_PCT)


# ------------------------------------------------------------------
# Lone Druid's ultimate, True Form.
# ------------------------------------------------------------------

## Activates (or, if already active, restarts) True Form at
## `level_data`'s values: swaps the hero's portrait to his bear form,
## and arms the bonus HP/damage plus the forced-melee range for the
## duration (see _hero_max_hp(), _roll_hero_damage(), _is_ranged_hero()
## respectively - each reads the state set here directly). The bonus
## HP raises his max HP the same way Essence Shift's borrowed HP does
## (see _hero_max_hp()) rather than instantly topping him up - it's
## extra capacity for the duration, not a free heal.
func _activate_true_form(level_data: Dictionary) -> void:
	if _true_form_active:
		_end_true_form()

	_true_form_active = true
	_true_form_bonus_hp = float(level_data.get("bonus_hp", 0))
	_true_form_bonus_damage = float(level_data.get("bonus_damage", 0))
	_true_form_turns_remaining = int(level_data.get("duration", 0))
	# The casting turn itself doesn't count - duration only starts
	# ticking from the turn after (see _tick_true_form()).
	_true_form_duration_pending_start = true

	_set_hero_image(TRUE_FORM_IMAGE_PATH)
	_refresh_bars()


## Ticks True Form's duration down once per End Turn, same timing and
## "casting turn doesn't count" rule as Essence Shift/Shadow Dance/
## Spirit Link.
func _tick_true_form() -> void:
	if not _true_form_active:
		return

	if _true_form_duration_pending_start:
		_true_form_duration_pending_start = false
		return

	_true_form_turns_remaining -= 1
	if _true_form_turns_remaining <= 0:
		_end_true_form()


## Ends True Form, whether from its duration running out or a fresh
## cast restarting it outright (see _activate_true_form()): reverts
## the portrait, drops the bonus HP/damage and the forced melee range
## back to normal.
func _end_true_form() -> void:
	_true_form_active = false
	_true_form_bonus_hp = 0.0
	_true_form_bonus_damage = 0.0
	_true_form_turns_remaining = 0
	_true_form_duration_pending_start = false

	_set_hero_image(_hero_static.get("image", ""))
	_refresh_bars()
	_show_message_over_hero("True Form wears off")


# ------------------------------------------------------------------
# Lone Druid's Spirit Bear.
# ------------------------------------------------------------------

func _is_bear_alive() -> bool:
	return not _bear.is_empty()


## Summons (or re-summons) the Spirit Bear at `level_data`'s stats,
## starting on the hero's own column. Any bear already out - even a
## stronger one from a previous cast at a higher level, since the
## player might recast at the same level just to top it back up to
## full HP - is replaced outright, per _despawn_bear().
func _summon_spirit_bear(level_data: Dictionary) -> void:
	_despawn_bear()

	if not ResourceLoader.exists(SPIRIT_BEAR_IMAGE_PATH):
		print("No bear image found at: ", SPIRIT_BEAR_IMAGE_PATH)
		return

	var target_height: float = get_viewport_rect().size.y / 4.0
	var texture: Texture2D = load(SPIRIT_BEAR_IMAGE_PATH)
	var tex_size: Vector2 = texture.get_size()
	var scale_factor: float = target_height / tex_size.y
	var target_width: float = tex_size.x * scale_factor

	var tex_rect := TextureRect.new()
	tex_rect.texture = texture
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	tex_rect.size = Vector2(target_width, target_height)
	tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tex_rect.position = Vector2(_index_to_x(_hero_pos_index), _creature_y())
	add_child(tex_rect)
	# add_child() appends as the LAST sibling, which would draw on top
	# of every UI panel and popup (LevelUpPopup, DefeatPopup, etc.) -
	# move it right after EnemiesLayer instead, so it renders at the
	# same visual layer as the hero/enemies and stays behind all UI.
	move_child(tex_rect, enemies_layer.get_index() + 1)

	var hp: float = float(level_data.get("hp", 1))
	_bear = {
		"hp": hp,
		"current_hp": hp,
		"damage_min": float(level_data.get("damage_min", 0)),
		"damage_max": float(level_data.get("damage_max", 0)),
		"armor": float(level_data.get("armor", 0)),
		"speed": maxi(1, int(level_data.get("speed", 1))),
		"pos_index": _hero_pos_index,
		"node": tex_rect,
	}


## Removes whatever bear is currently out, if any, with no XP/gold and
## no message - used both when a fresh bear replaces it (see
## _summon_spirit_bear()) and when the hero leaves the battle for good
## (the scene tearing down would free the node either way, but this
## keeps _bear itself consistent for as long as the script is alive).
func _despawn_bear() -> void:
	if not _is_bear_alive():
		return
	if is_instance_valid(_bear["node"]):
		_bear["node"].queue_free()
	_bear = {}


## An enemy's hit landed on the bear instead of the hero: mitigated by
## the bear's own armor, same formula as any other target's, plus
## Savage Roar's damage reduction on top while it's active - the
## skill covers the bear as well as the hero (see
## _update_savage_roar_state()).
func _deal_damage_to_bear(amount: float) -> void:
	if not _is_bear_alive():
		return

	# A rival's Corrosive Haze on the bear boosts every hit it takes,
	# and its/Lil' Shredder's armor shred lowers its armor - same two
	# effects the player's own apply_damage() applies to him.
	amount *= (1.0 + float(_bear.get("corrosive_haze_bonus_pct", 0.0)))
	var bear_armor: float = float(_bear.get("armor", 0)) - float(_bear.get("armor_reduction", 0.0))
	var mitigated: float = _apply_armor_reduction(amount, bear_armor)
	mitigated *= (1.0 - _savage_roar_damage_reduction_pct)
	_bear["current_hp"] -= mitigated
	_show_damage_number(_bear["node"], mitigated)

	if _bear["current_hp"] <= 0:
		_kill_bear()


## Any enemy AoE skill that damages the hero over an area should ALSO
## independently hit the Spirit Bear if it's standing within that same
## area - same reasoning as the illusion-side equivalent
## (_deal_aoe_damage_to_illusions()), just against the single `_bear`
## dict instead of the `_illusions` array. Unlike that helper, `amount`
## is passed straight to _deal_damage_to_bear() un-mitigated - the bear
## has its own armor stat (set at summon time), not the hero's, and
## that function already mitigates with it internally. A no-op while no
## bear is out.
## `flash_hits` gives each one hit the same red hit-flash as Moon
## Glaives' bounce (_flash_bounce_hit()) - off by default, opted into by
## Dark Pact.
func _deal_aoe_damage_to_bear(center_pos_index: int, radius: int, amount: float, flash_hits: bool = false) -> void:
	if not _is_bear_alive() or amount <= 0.0:
		return
	if _distance(_bear["pos_index"], center_pos_index) <= radius:
		_deal_damage_to_bear(amount)
		if flash_hits and _is_bear_alive() and is_instance_valid(_bear.get("node")):
			_flash_bounce_hit(_bear["node"])


## The line-shaped equivalent of _deal_aoe_damage_to_bear() above - for
## Ghostship's/Timber Chain's own "every column between the caster and
## the target, inclusive of both ends" line. Same "amount is raw, the
## bear mitigates it with its own armor" contract.
func _deal_line_aoe_damage_to_bear(start_pos_index: int, end_pos_index: int, amount: float) -> void:
	if not _is_bear_alive() or amount <= 0.0:
		return
	var start_col: int = mini(start_pos_index, end_pos_index)
	var end_col: int = maxi(start_pos_index, end_pos_index)
	var pos: int = _bear["pos_index"]
	if pos >= start_col and pos <= end_col:
		_deal_damage_to_bear(amount)


## The directional-cone equivalent of the two AoE-shape helpers above -
## for a rival Scatterblast's own facing-based cone. Same "amount is
## raw, the bear mitigates it with its own armor" contract.
func _deal_directional_aoe_damage_to_bear(origin_pos_index: int, direction: int, range_columns: int, amount: float) -> void:
	if not _is_bear_alive() or amount <= 0.0:
		return
	var ahead: int = (_bear["pos_index"] - origin_pos_index) * direction
	if ahead >= 0 and ahead <= range_columns:
		_deal_damage_to_bear(amount)


## The bear falls - unlike _kill_enemy(), this never grants XP or
## gold, since it's the hero's own summon rather than a foe. Losing it
## also costs the hero a chunk of his own HP (see
## _apply_bear_death_penalty()).
func _kill_bear() -> void:
	_despawn_bear()
	_apply_bear_death_penalty()


## Losing the bear costs the hero BEAR_DEATH_HP_PENALTY_PCT of his max
## HP, taken directly off current_hp with no armor mitigation at all
## (unlike apply_damage(), which always mitigates) - but this specific
## penalty is capped so it can never bring him below 1 HP; it's a
## punishment for losing the bear, not a death sentence on its own.
func _apply_bear_death_penalty() -> void:
	var max_hp: float = _hero_max_hp()
	var current_hp: float = float(_recruited.get("current_hp", 0))

	var penalty: float = max_hp * BEAR_DEATH_HP_PENALTY_PCT
	var actual_damage: float = minf(penalty, maxf(0.0, current_hp - 1.0))

	if actual_damage > 0.0:
		PlayerManager.damage_hero(actual_damage)
		_refresh_bars()

	_show_message_over_hero("The Spirit Bear falls - Sylla is weakened!")


func _roll_bear_damage() -> float:
	return randi_range(int(_bear.get("damage_min", 0)), int(_bear.get("damage_max", 0)))


## The bear acts automatically once per turn, right alongside the
## enemies (see _end_turn()): attacks whatever enemy shares its
## column, or - if none does - closes in on the nearest enemy at its
## own speed (columns per turn), stopping early if that walk would
## carry it onto an enemy's column anyway (see _melee_move_target()).
## No-ops entirely while no bear is summoned, or once every enemy is
## already dead.
func _bear_turn() -> void:
	if not _is_bear_alive() or _enemies.is_empty():
		return

	# A rival's stun (Torrent/Sacred Arrow/Lucent Beam/Ice Blast/
	# Frostbite/Winter's Curse/Snowball/Walrus Punch aimed at the bear)
	# costs it this whole turn; a root (Entangle/Ensnare) still lets it
	# attack what's already on its column, just not walk. Both are
	# checked with their CURRENT value before ticking down - the same
	# "use it, then decrement" order the rival's own root/stun use - so
	# a 1-turn stun/root actually blocks the one turn it's meant to.
	var stunned: bool = int(_bear.get("stun_turns_left", 0)) > 0
	if stunned:
		_bear["stun_turns_left"] -= 1
		return
	var rooted: bool = int(_bear.get("root_turns_left", 0)) > 0
	if rooted:
		_bear["root_turns_left"] -= 1

	var target: Dictionary = _get_enemy_at(_bear["pos_index"])
	if not target.is_empty():
		# The bear's own attack, not the hero's - Corrosive Haze's own
		# bonus (see _deal_fixed_damage_to_enemy()'s own is_hero_action
		# param) never applies to it.
		_deal_fixed_damage_to_enemy(target, _roll_bear_damage(), false, false)
		return

	if rooted:
		return

	var nearest: Dictionary = {}
	var nearest_distance: int = GRID_COLUMNS + 1
	for enemy in _enemies:
		var d: int = _distance(enemy["pos_index"], _bear["pos_index"])
		if d < nearest_distance:
			nearest_distance = d
			nearest = enemy

	var direction: int = _step_toward(_bear["pos_index"], nearest["pos_index"])
	if direction == 0:
		return

	var new_pos: int = _melee_move_target(_bear["pos_index"], direction, int(_bear["speed"]))
	_bear["pos_index"] = new_pos
	_bear["node"].position = Vector2(_index_to_x(new_pos), _creature_y())


## Updates every skill's cooldown label - "Ready" or "N turns left" -
## to match _skill_cooldowns. Called after a skill is used and after
## cooldowns tick down at End Turn.
func _refresh_skill_cooldown_labels() -> void:
	for skill_id in _skill_cooldown_labels.keys():
		var label: Label = _skill_cooldown_labels[skill_id]
		var remaining: int = _skill_cooldowns.get(skill_id, 0)
		if remaining <= 0:
			label.text = "Ready"
			label.add_theme_color_override("font_color", Color(0.5, 1, 0.5, 1))
		else:
			var noun: String = "turn" if remaining == 1 else "turns"
			label.text = "%d %s left" % [remaining, noun]
			label.add_theme_color_override("font_color", Color(1, 0.6, 0.4, 1))

	# Borrowed Time has no button click to show its own "in effect"
	# state the way a manually-cast buff's activation message does, so
	# this overlays "Active" on top of whatever the loop above just
	# wrote (its cooldown only starts counting down once it ends - see
	# _end_borrowed_time() - so "Ready"/"N turns left"
	# would otherwise read as if it wasn't doing anything right now).
	if _borrowed_time_active and _skill_cooldown_labels.has("borrowed_time"):
		var borrowed_time_label: Label = _skill_cooldown_labels["borrowed_time"]
		borrowed_time_label.text = "Active"
		borrowed_time_label.add_theme_color_override("font_color", Color(1, 0.65, 0.2, 1))


## Ticks every tracked skill cooldown down by one turn, clamped at 0,
## and ticks Essence Shift's, Shadow Dance's, Arctic Burn's, Cold
## Embrace's, Freezing Field's, Ice Shards', Tag Team's, Nature's
## Guise's, Living Armor's, Reactive Armor's (each stack independently),
## Chakram's, Spirit Link's, True Form's, Aphotic Shield's, and Borrowed
## Time's durations, plus Curse of Avernus's own (enemy- and player-side)
## un-activated-stack decay - not a DoT, so it
## stays here rather than moving to turn-start with the rest (see
## _tick_curse_of_avernus_effects()'s own comment) - and, during a hero
## fight, the rival's own mirrored buff/cooldown durations. Every actual
## DoT/root/silence/execute effect, on either side, now ticks at the
## start of whichever turn it belongs to instead
## (_tick_enemy_turn_start_effects()/_tick_player_turn_start_effects()).
## Called once per End Turn.
func _tick_skill_cooldowns() -> void:
	for skill_id in _skill_cooldowns.keys():
		var new_value: int = maxi(0, _skill_cooldowns[skill_id] - 1)
		_skill_cooldowns[skill_id] = new_value
		PlayerManager.set_skill_cooldown(skill_id, new_value)

	_tick_essence_shift()
	_tick_shadow_dance()
	_tick_natures_guise()
	_tick_moonlight_shadow()
	_tick_arctic_burn()
	_tick_cold_embrace()
	_tick_freezing_field()
	_tick_eclipse()
	_tick_ice_shards()
	_tick_tag_team()
	_tick_living_armor()
	_tick_spirit_link()
	_tick_true_form()
	_tick_aphotic_shield()
	_tick_borrowed_time()
	_tick_curse_of_avernus_effects()
	_tick_reactive_armor_stacks()
	_tick_chakram()
	_tick_mirror_image()
	_tick_guardian_sprint()
	_tick_enemy_passive_regen()

	if _in_hero_fight:
		for skill_id in _enemy_skill_cooldowns.keys():
			_enemy_skill_cooldowns[skill_id] = maxi(0, _enemy_skill_cooldowns[skill_id] - 1)

		_tick_enemy_essence_shift()
		_tick_enemy_shadow_dance()
		_tick_enemy_spirit_link()
		_tick_enemy_true_form()
		_tick_enemy_aphotic_shield()
		_tick_enemy_borrowed_time()
		_tick_enemy_curse_of_avernus_effects()
		_tick_enemy_arctic_burn()
		_tick_enemy_cold_embrace()
		_tick_enemy_freezing_field()
		_tick_enemy_ice_shards()
		_tick_enemy_tag_team()
		_tick_enemy_natures_guise()
		_tick_enemy_living_armor()
		_tick_enemy_reactive_armor_stacks()
		_apply_enemy_reactive_armor_regen()
		_tick_enemy_chakram()
		_tick_enemy_mirror_image()
		_tick_enemy_guardian_sprint()
		_tick_enemy_moonlight_shadow()
		_tick_enemy_eclipse()


# ------------------------------------------------------------------
# Passive HP/mana regen - a small amount every turn for every
# creature in the fight (the player's own hero, a hero fight's rival
# boss, and every regular creep), scaled off the same stat each side's
# HP/mana already derive from (strength for HP, intelligence for
# mana). Ticks right after status effects/DoT for that same "turn" -
# _apply_passive_hero_regen() is called from _end_turn() right where
# Arcane Aura's own regen already is (right after _tick_skill_
# cooldowns()' DoT tick, before the player's action buttons reopen);
# _tick_enemy_passive_regen() is called from _tick_skill_cooldowns()
# itself, alongside every other unconditional enemy-side tick, so a
# creep's own regen lands between its last action and its next one the
# same way its DoT ticks already do.
# ------------------------------------------------------------------

const PASSIVE_HP_REGEN_BASE := 2.0
const PASSIVE_HP_REGEN_PER_STRENGTH := 0.10
const PASSIVE_MANA_REGEN_BASE := 1.0
const PASSIVE_MANA_REGEN_PER_INT := 0.05


## The player hero's own passive regen. Reads strength/intelligence
## straight off _recruited's own stats - the same raw base values
## _hero_armor()/_hero_max_hp() already read for their own bonus terms
## - since Essence Shift/True Form never touch strength/intelligence
## themselves (only derived hp/mana/armor/damage), no extra bonus
## terms belong here.
func _apply_passive_hero_regen() -> void:
	var stats: Dictionary = _recruited.get("stats", {})
	var strength: float = float(stats.get("strength", 0))
	var intelligence: float = float(stats.get("intelligence", 0))

	heal(PASSIVE_HP_REGEN_BASE + strength * PASSIVE_HP_REGEN_PER_STRENGTH)
	restore_mana(PASSIVE_MANA_REGEN_BASE + intelligence * PASSIVE_MANA_REGEN_PER_INT)


## The enemy-side mirror, for every living entry in _enemies at once -
## a regular creep, a hero fight's rival boss, or its summoned Spirit
## Bear ally. HP regen applies to all three, using whichever stat each
## kind actually tracks: the boss's real strength (from
## _enemy_hero_static's own stats, mirroring the player's own read
## above - a hero-fight enemy_def only ever carries flattened hp/
## damage/armor, never strength/intelligence, see GameManager.gd's own
## build_hero_fight_enemy_def()), or a creep's/bear's own
## current_main_stat_value ONLY when its static main_stat is actually
## "strength" - an agility/intelligence creep has no tracked strength
## at all, so it just gets the flat base. Mana regen only applies to
## the boss: a regular creep's own "mana" field (see GameManager.gd's
## own creep entries) is never read or spent anywhere in this file, so
## ticking it would just be dead state - _enemy_current_mana is the
## boss's own single shared mana pool (there's only ever one boss per
## fight).
func _tick_enemy_passive_regen() -> void:
	for enemy in _enemies.duplicate():
		var enemy_static: Dictionary = enemy["static"]
		var is_boss: bool = enemy_static.get("is_hero_fight_boss", false)

		var strength: float = 0.0
		if is_boss:
			strength = float(_enemy_hero_static.get("stats", {}).get("strength", 0))
		elif enemy_static.get("main_stat", "") == "strength":
			strength = float(enemy.get("current_main_stat_value", 0))

		var hp_regen: float = PASSIVE_HP_REGEN_BASE + strength * PASSIVE_HP_REGEN_PER_STRENGTH
		var max_hp: float = _enemy_hero_effective_max_hp(enemy) if is_boss else float(enemy_static.get("hp", 1))
		enemy["current_hp"] = minf(max_hp, enemy["current_hp"] + hp_regen)

		if is_boss:
			var intelligence: float = float(_enemy_hero_static.get("stats", {}).get("intelligence", 0))
			var mana_regen: float = PASSIVE_MANA_REGEN_BASE + intelligence * PASSIVE_MANA_REGEN_PER_INT
			var max_mana: float = _enemy_max_mana + _enemy_essence_shift_bonus.get("mana", 0.0)
			_enemy_current_mana = minf(max_mana, _enemy_current_mana + mana_regen)


# ------------------------------------------------------------------
# Abaddon's Aphotic Shield.
# ------------------------------------------------------------------

## Activates (or, if already active, replaces outright - no explosion
## from the old one, same "silently overwritten" rule True Form uses
## when recast) Aphotic Shield at `level_data`'s values, and dispels
## every negative effect currently on the player - see the state-var
## block's comment above for exactly which ones and why silence isn't
## among them.
func _activate_aphotic_shield(level_data: Dictionary) -> void:
	_aphotic_shield_active = true
	_aphotic_shield_hp = float(level_data.get("shield_hp", 0))
	_aphotic_shield_aoe_damage = float(level_data.get("aoe_damage", 0))
	_aphotic_shield_radius = int(level_data.get("radius", 0))
	_aphotic_shield_turns_remaining = int(level_data.get("duration", 0))
	# The casting turn itself doesn't count - duration only starts
	# ticking from the turn after (see _tick_aphotic_shield()), same as
	# every other duration-based buff.
	_aphotic_shield_duration_pending_start = true

	# Checked before the dispel below clears it all - only drives the
	# cleanse sparks in _show_aphotic_shell().
	var cleansed: bool = _player_root_turns_left > 0 or _player_entangle_dot_turns_left > 0 \
		or _player_stun_turns_left > 0 or _player_winters_curse_active
	for penalty in _player_essence_shift_penalty.values():
		if float(penalty) > 0.0:
			cleansed = true

	_player_root_turns_left = 0
	_player_entangle_dot_damage = 0.0
	_player_entangle_dot_turns_left = 0
	_player_stun_turns_left = 0
	_player_winters_curse_active = false
	_player_essence_shift_penalty = {"damage": 0.0, "hp": 0.0, "mana": 0.0, "armor": 0.0}

	_show_message_over_hero("Shield up!")
	_show_aphotic_shell(hero_image, _aphotic_shield_hp, cleansed)
	_refresh_bars()


## Ticks the shield's duration down once per End Turn, same "casting
## turn doesn't count" pattern as Essence Shift/Shadow Dance/Spirit
## Link/True Form. Only reached while the shield is still standing -
## see apply_damage() for the other way it can end, mid-turn, from
## being drained to 0 instead of outlasting its clock.
func _tick_aphotic_shield() -> void:
	if not _aphotic_shield_active:
		return

	if _aphotic_shield_duration_pending_start:
		_aphotic_shield_duration_pending_start = false
		return

	_aphotic_shield_turns_remaining -= 1
	if _aphotic_shield_turns_remaining <= 0:
		_end_aphotic_shield(false)


## Ends Aphotic Shield, whether its duration simply ran out (`exploded`
## false - it just fades) or enough damage drained it to 0 HP
## (`exploded` true, from apply_damage()) - in which case it deals the
## cast's own aoe_damage to every living, targetable enemy within its
## own radius columns of the hero, mirroring Dark Pact's radius-around-
## a-position AoE (_cast_dark_pact()). Captures the level's aoe_damage/
## radius into locals before clearing the state below, since the
## explosion still needs them afterward.
func _end_aphotic_shield(exploded: bool) -> void:
	var aoe_damage: float = _aphotic_shield_aoe_damage
	var radius: int = _aphotic_shield_radius

	_aphotic_shield_active = false
	_aphotic_shield_hp = 0.0
	_aphotic_shield_aoe_damage = 0.0
	_aphotic_shield_radius = 0
	_aphotic_shield_turns_remaining = 0
	_aphotic_shield_duration_pending_start = false

	_remove_aphotic_shell(hero_image, exploded, radius)

	if not exploded:
		_show_message_over_hero("Shield fades")
		return

	var targets: Array = []
	for enemy in _enemies:
		if _is_target_hidden(enemy):
			continue
		if _distance(enemy["pos_index"], _hero_pos_index) <= radius:
			targets.append(enemy)
	for enemy in targets:
		_deal_fixed_damage_to_enemy(enemy, aoe_damage)
		# Same red hit-flash as Dark Pact.
		if is_instance_valid(enemy.get("node")):
			_flash_bounce_hit(enemy["node"])
	# Self-centered on the hero, same as the check above - a rival's own
	# illusion (Naga Siren's Mirror Image) can be in range independently
	# of whether the boss itself currently is.
	_deal_aoe_damage_to_enemy_illusions(_hero_pos_index, radius, aoe_damage, true)

	_show_message_over_hero("Shield shattered!")


## Purely cosmetic: puts Aphotic Shield's shell on `node` (the
## player's hero_image, or the rival Abaddon's own node) - a
## translucent dark purple bubble, a child Panel so it follows the
## sprite's position/scale/fades for free, snapping on from small with
## an overshoot, then slowly "breathing" for as long as it's up. Also
## flashes the sprite purple and, if the cast actually `cleansed`
## anything, lets off a few purple sparks. `shield_hp` is remembered as
## the shell's full strength so _update_aphotic_shell() can fade it as
## it drains. A recast replaces any existing shell outright, the same
## way the shield itself is replaced.
func _show_aphotic_shell(node: Variant, shield_hp: float, cleansed: bool) -> void:
	if not (node is TextureRect) or not is_instance_valid(node):
		return

	var old_shell: Node = node.get_node_or_null(APHOTIC_SHELL_NAME)
	if old_shell != null:
		old_shell.name = APHOTIC_SHELL_NAME + "Replaced"
		old_shell.queue_free()

	var shell := Panel.new()
	shell.name = APHOTIC_SHELL_NAME
	shell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# A circle centered on the sprite, as wide as the sprite is tall.
	shell.size = Vector2(node.size.y, node.size.y)
	shell.position = (node.size - shell.size) / 2.0
	shell.pivot_offset = shell.size / 2.0

	var style := StyleBoxFlat.new()
	style.bg_color = APHOTIC_SHELL_FILL_COLOR
	style.border_color = APHOTIC_SHELL_RIM_COLOR
	style.set_border_width_all(2)
	# Corner radius of half the (square) size makes it a full circle.
	style.set_corner_radius_all(int(ceilf(shell.size.x / 2.0)))
	# Smooth the curve at this size - StyleBoxFlat's default corner
	# detail looks faceted on a large circle.
	style.corner_detail = 32
	style.shadow_color = Color(APHOTIC_SHARD_COLOR.r, APHOTIC_SHARD_COLOR.g, APHOTIC_SHARD_COLOR.b, 0.45)
	style.shadow_size = 12
	shell.add_theme_stylebox_override("panel", style)
	shell.set_meta("max_hp", maxf(1.0, shield_hp))
	shell.scale = Vector2(0.3, 0.3)
	node.add_child(shell)

	var snap: Tween = shell.create_tween()
	snap.tween_property(shell, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# Breathing lives on self_modulate, so it multiplies with the
	# HP-based strength _update_aphotic_shell() keeps on modulate.
	var breath: Tween = shell.create_tween().set_loops()
	breath.tween_property(shell, "self_modulate:a", 0.6, 0.9).set_trans(Tween.TRANS_SINE)
	breath.tween_property(shell, "self_modulate:a", 1.0, 0.9).set_trans(Tween.TRANS_SINE)
	shell.set_meta("breath_tween", breath)

	_flash_bounce_hit(node, APHOTIC_FLASH_COLOR)

	if cleansed:
		_play_aphotic_cleanse_sparks(node)


## Called whenever the shield soaks up part of a hit but survives it:
## fades the shell toward faint as `remaining_hp` drops (full strength
## when fresh, ~30% just before it breaks) and gives it a quick ripple
## so the absorbed hit visibly lands on the shield.
func _update_aphotic_shell(node: Variant, remaining_hp: float) -> void:
	if not (node is Control) or not is_instance_valid(node):
		return
	var shell: Panel = node.get_node_or_null(APHOTIC_SHELL_NAME)
	if shell == null:
		return

	var fraction: float = clampf(remaining_hp / float(shell.get_meta("max_hp", 1.0)), 0.0, 1.0)
	var tween: Tween = shell.create_tween()
	tween.tween_property(shell, "scale", Vector2(1.08, 1.08), 0.08).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(shell, "modulate:a", lerpf(0.3, 1.0, fraction), 0.2)
	tween.tween_property(shell, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_SINE)


## Takes Aphotic Shield's shell off `node`: a quiet ~0.4s dissolve when
## it just ran out (or was cleared on a reset), or - when `shattered` -
## a burst of dark purple shards flying out about `radius` columns (the
## explosion's own reach) plus a light screen shake. The explosion's
## damage and hit flashes are the caller's.
func _remove_aphotic_shell(node: Variant, shattered: bool, radius: int) -> void:
	if not (node is Control) or not is_instance_valid(node):
		return
	var shell: Panel = node.get_node_or_null(APHOTIC_SHELL_NAME)
	if shell == null:
		return

	# Renamed right away so a recast during the fade creates a fresh
	# shell instead of finding this dying one.
	shell.name = APHOTIC_SHELL_NAME + "Ending"
	var breath: Variant = shell.get_meta("breath_tween", null)
	if breath is Tween and breath.is_valid():
		breath.kill()

	var fade_time: float = 0.15 if shattered else 0.4
	var tween: Tween = shell.create_tween()
	tween.tween_property(shell, "scale", Vector2(1.25, 1.25) if shattered else Vector2(1.1, 1.1), fade_time)
	tween.parallel().tween_property(shell, "modulate:a", 0.0, fade_time)
	tween.tween_callback(shell.queue_free)

	if not shattered:
		return

	_play_aphotic_shatter(node.position + node.size / 2.0, radius)
	_shake_screen()


## The shatter's shards: a one-shot radial burst of spinning dark
## purple pieces, fast enough to reach about `radius` columns before
## they fade (at least one column, even for a radius-0 shield). Same
## CPUParticles2D one-shot-burst recipe as _spawn_lil_shredder_impact().
func _play_aphotic_shatter(pos: Vector2, radius: int) -> void:
	var lifetime: float = 0.5
	var reach: float = _grid_unit() * maxf(1.0, float(radius))
	var particles := CPUParticles2D.new()
	particles.position = pos
	particles.emitting = false
	particles.one_shot = true
	particles.amount = 48
	particles.lifetime = lifetime
	particles.explosiveness = 1.0
	particles.spread = 180.0
	particles.gravity = Vector2.ZERO
	particles.initial_velocity_min = reach / lifetime * 0.6
	particles.initial_velocity_max = reach / lifetime * 1.1
	particles.angle_min = 0.0
	particles.angle_max = 360.0
	particles.angular_velocity_min = -360.0
	particles.angular_velocity_max = 360.0
	particles.scale_amount_min = 4.0
	particles.scale_amount_max = 9.0
	particles.color = APHOTIC_SHARD_COLOR
	add_child(particles)
	# Same reasoning as _play_scatterblast_effect()'s own move_child()
	# call - render at the hero/enemy layer, not on top of every UI panel.
	move_child(particles, enemies_layer.get_index() + 1)
	particles.emitting = true

	get_tree().create_timer(lifetime + 0.2).timeout.connect(particles.queue_free)


## The cleanse: a few small purple sparks drifting up off `node`, as if
## the removed debuffs are being lifted away. Only played when the
## cast actually dispelled something.
func _play_aphotic_cleanse_sparks(node: Control) -> void:
	var lifetime: float = 0.8
	var particles := CPUParticles2D.new()
	particles.position = node.position + node.size / 2.0
	particles.emitting = false
	particles.one_shot = true
	particles.amount = 16
	particles.lifetime = lifetime
	particles.explosiveness = 0.7
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	particles.emission_rect_extents = node.size * 0.3
	particles.direction = Vector2(0, -1)
	particles.spread = 25.0
	particles.gravity = Vector2.ZERO
	particles.initial_velocity_min = 40.0
	particles.initial_velocity_max = 90.0
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 4.0
	particles.color = APHOTIC_SHELL_RIM_COLOR
	add_child(particles)
	move_child(particles, enemies_layer.get_index() + 1)
	particles.emitting = true

	get_tree().create_timer(lifetime + 0.2).timeout.connect(particles.queue_free)


# ------------------------------------------------------------------
# Abaddon's Curse of Avernus - a passive, so unlike every skill above
# there's no button/cast/mana/cooldown for it (see _populate_skill_
# buttons()'s "passive" branch); it just triggers off the hero's own
# plain Attacks (_apply_hero_attack()). Per-target progress (stacks,
# the active curse's own DoT, and the turn count feeding stack decay)
# lives directly on each enemy's own Dictionary in _enemies, the same
# way Entangle's root/silence/DoT fields do (_apply_root()) - it's
# per-enemy state, not per-hero, so it can't live in a single instance
# variable the way the rest of this hero's kit does.
# ------------------------------------------------------------------

# How many full turns a target can go without being hit by the hero's
# Attack before its un-activated stacks are lost (see
# _tick_curse_of_avernus_effects()) - independent of skill level.
const CURSE_OF_AVERNUS_STACK_DECAY_TURNS := 3


## Curse of Avernus's level data for whatever level the player has it
## at right now - {} if it isn't learned at all (level 0), the same
## "empty means locked" convention _get_savage_roar_level_data() uses.
func _get_curse_of_avernus_level_data() -> Dictionary:
	var level: int = PlayerManager.get_skill_level("curse_of_avernus")
	if level <= 0:
		return {}
	for skill in _hero_static.get("skills", []):
		if skill.get("id", "") == "curse_of_avernus":
			return GameManager.get_skill_level_data(skill, level)
	return {}


## Called on every plain Attack hit (see _apply_hero_attack()): builds
## one stack of Curse of Avernus on `target`, or - once this level's
## hits_to_activate is reached - consumes all of them to activate the
## actual curse instead (silence, via the same `silence_turns_left`
## field Entangle uses; and a damage-over-time - both ticked, at the
## start of that enemy's own turn, by _tick_enemy_turn_start_effects()).
## No-ops entirely if the hero doesn't have this skill learned, if the
## hit already killed the target, or if it's already cursed - a curse
## has nothing left to build toward until it wears off on its own.
func _apply_curse_of_avernus_stack(target: Dictionary) -> void:
	var level_data: Dictionary = _get_curse_of_avernus_level_data()
	if level_data.is_empty() or target.get("current_hp", 0) <= 0 or target.get("curse_active", false):
		return

	# Being hit at all resets the decay clock, whether or not this
	# particular hit is the one that pushes the stacks over the top.
	target["curse_last_hit_turn"] = _turn_count

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
	_refresh_enemy_overhead_labels()


## Curse of Avernus's own DoT (and the silence sharing Entangle's
## `silence_turns_left` field) both moved to _tick_enemy_turn_start_
## effects() along with every other DoT - this is only what's left:
## decaying a NOT-yet-activated curse's stacks back to 0 once
## CURSE_OF_AVERNUS_STACK_DECAY_TURNS full ROUNDS (not that enemy's own
## turns - _turn_count is a global round counter) have passed since the
## last hit that touched it. Not a DoT itself, so it stays here, ticked
## once per End Turn same as before.
func _tick_curse_of_avernus_effects() -> void:
	for enemy in _enemies.duplicate():
		if not enemy.get("curse_active", false) and enemy.get("curse_stacks", 0) > 0:
			var last_hit_turn: int = int(enemy.get("curse_last_hit_turn", _turn_count))
			if _turn_count - last_hit_turn >= CURSE_OF_AVERNUS_STACK_DECAY_TURNS:
				enemy["curse_stacks"] = 0


# ------------------------------------------------------------------
# Abaddon's Borrowed Time - see the state-var block's own comment
# above for the general shape of it. Unlike every other skill here,
# nothing ever calls _maybe_auto_activate_borrowed_time() from a
# button; the only entry point is apply_damage() noticing the hero has
# crossed this level's HP threshold.
# ------------------------------------------------------------------

## Borrowed Time's level data for whatever level the player has it at
## right now - {} if it isn't learned at all (level 0), the same
## "empty means locked" convention _get_savage_roar_level_data()/
## _get_curse_of_avernus_level_data() use.
func _get_borrowed_time_level_data() -> Dictionary:
	var level: int = PlayerManager.get_skill_level("borrowed_time")
	if level <= 0:
		return {}
	for skill in _hero_static.get("skills", []):
		if skill.get("id", "") == "borrowed_time":
			return GameManager.get_skill_level_data(skill, level)
	return {}


## Checked from apply_damage() every time the hero takes real damage
## (i.e. NOT while Borrowed Time is already active, since it can't
## retrigger on top of itself): if he's learned it, it isn't already
## on cooldown, and his HP is now at or below this level's own
## auto_activate_hp_pct, this is the hit that crosses the threshold -
## it still deals its damage normally (see apply_damage()), but every
## hit AFTER this one heals him instead for the rest of the duration.
## Starts the cooldown immediately, the same way a manually-cast
## skill's does the moment it's used, so this can't re-trigger again
## the instant it wears off just because HP is still low.
func _maybe_auto_activate_borrowed_time() -> void:
	if _borrowed_time_active or _skill_cooldowns.get("borrowed_time", 0) > 0:
		return

	var level_data: Dictionary = _get_borrowed_time_level_data()
	if level_data.is_empty():
		return

	var max_hp: float = _hero_max_hp()
	if max_hp <= 0.0:
		return

	var hp_pct: float = float(_recruited.get("current_hp", 0)) / max_hp
	if hp_pct > float(level_data.get("auto_activate_hp_pct", 0.3)):
		return

	_borrowed_time_active = true
	_borrowed_time_heal_conversion_pct = float(level_data.get("heal_conversion_pct", 1.0))
	_borrowed_time_turns_remaining = int(level_data.get("duration", 0))
	# The activating turn itself doesn't count - duration only starts
	# ticking from the turn after (see _tick_borrowed_time()), same as
	# every other duration-based buff.
	_borrowed_time_duration_pending_start = true

	_skill_cooldowns["borrowed_time"] = int(level_data.get("cooldown", 0))
	PlayerManager.set_skill_cooldown("borrowed_time", _skill_cooldowns["borrowed_time"])

	_show_message_over_hero("Borrowed Time!")
	_set_borrowed_time_visual(hero_image, true)
	_refresh_bars()
	_refresh_skill_cooldown_labels()


## Ticks Borrowed Time's duration down once per End Turn, same
## "activating turn doesn't count" pattern as every other duration-
## based buff here.
func _tick_borrowed_time() -> void:
	if not _borrowed_time_active:
		return

	if _borrowed_time_duration_pending_start:
		_borrowed_time_duration_pending_start = false
		return

	_borrowed_time_turns_remaining -= 1
	if _borrowed_time_turns_remaining <= 0:
		_end_borrowed_time()


## Ends Borrowed Time once its duration runs out (or it's dispelled) and
## restarts its cooldown at the full value from here - the cooldown set
## at activation keeps ticking down WHILE the buff is active, so without
## this reset the wait after it ends would only be cooldown - duration.
func _end_borrowed_time() -> void:
	_borrowed_time_active = false
	_borrowed_time_heal_conversion_pct = 0.0
	_borrowed_time_turns_remaining = 0
	_borrowed_time_duration_pending_start = false
	_set_borrowed_time_visual(hero_image, false)

	var level_data: Dictionary = _get_borrowed_time_level_data()
	if not level_data.is_empty():
		_skill_cooldowns["borrowed_time"] = int(level_data.get("cooldown", 0))
		PlayerManager.set_skill_cooldown("borrowed_time", _skill_cooldowns["borrowed_time"])

	_show_message_over_hero("Borrowed Time fades")
	_refresh_bars()
	_refresh_skill_cooldown_labels()


## Purely cosmetic: turns Borrowed Time's pulsing greenish-teal glow on
## or off for `node` (the player's hero_image, or the rival Abaddon's
## own node). The glow is a child TextureRect showing the same texture,
## additively blended and tinted BORROWED_TIME_GLOW_COLOR, so it
## brightens the sprite's own silhouette toward teal and follows its
## position/scale/fades for free. Its strength pulses on a loop; the
## same per-frame update also keeps its flip_h/texture in sync with the
## sprite, since the hero can turn around while it's up. Only does
## anything when the state actually changes (the glow child's presence
## is the "currently on" marker).
func _set_borrowed_time_visual(node: Variant, active: bool) -> void:
	if not (node is TextureRect) or not is_instance_valid(node):
		return
	var glow: TextureRect = node.get_node_or_null(BORROWED_TIME_GLOW_NAME)
	if active == (glow != null):
		return

	if not active:
		# Renamed right away so a quick re-activation during the fade
		# creates a fresh glow instead of finding this dying one.
		glow.name = BORROWED_TIME_GLOW_NAME + "Fading"
		var pulse: Variant = glow.get_meta("pulse_tween", null)
		if pulse is Tween and pulse.is_valid():
			pulse.kill()
		var fade: Tween = glow.create_tween()
		fade.tween_property(glow, "modulate:a", 0.0, 0.4)
		fade.tween_callback(glow.queue_free)
		return

	var material := CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow = TextureRect.new()
	glow.name = BORROWED_TIME_GLOW_NAME
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.material = material
	glow.texture = node.texture
	glow.expand_mode = node.expand_mode
	glow.stretch_mode = node.stretch_mode
	glow.flip_h = node.flip_h
	glow.flip_v = node.flip_v
	glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	glow.self_modulate = BORROWED_TIME_GLOW_COLOR
	glow.modulate.a = 0.0
	node.add_child(glow)

	# 0 -> 1 is one full pulse: faint -> strong -> faint.
	var pulse: Tween = glow.create_tween().set_loops()
	pulse.tween_method(
		func(phase: float) -> void:
			if not is_instance_valid(node):
				return
			glow.flip_h = node.flip_h
			glow.texture = node.texture
			glow.modulate.a = lerpf(0.15, 0.8, 0.5 - 0.5 * cos(phase * TAU)),
		0.0, 1.0, BORROWED_TIME_PULSE_SECONDS
	)
	glow.set_meta("pulse_tween", pulse)


# ------------------------------------------------------------------
# Public API for future combat/enemy scripts to call into.
# Each one persists through PlayerManager and refreshes the bars.
# ------------------------------------------------------------------

## Returns the mitigated damage actually dealt - the full hit's worth,
## even when it ends up somewhere other than the hero's own HP: fully
## converted into a heal while Borrowed Time is active (see below), or
## absorbed some/all by Aphotic Shield's own HP pool instead - so
## callers that need it (a rival hero's own Spirit Link lifesteal, via
## _resolve_enemy_hero_attack()) don't have to re-derive it. While
## Winter Wyvern's Cold Embrace is active the hero is fully immune -
## every hit (a creep's, a rival hero's skill, any ongoing DoT) is
## discarded outright before armor mitigation, Borrowed Time, or Aphotic
## Shield ever get a look at it.
func apply_damage(amount: float) -> float:
	if _cold_embrace_active:
		return 0.0

	# Slardar's Corrosive Haze: boosts every hit the player takes from the
	# rival's own attacks/skills by this level's own bonus_damage_pct -
	# applied to the RAW amount, before armor mitigation and before
	# Mirror Image's own redirect just below, mirroring
	# _deal_fixed_damage_to_enemy()'s own "is_hero_action" check (the
	# mark is about how fragile the PLAYER is, not about whatever ends up
	# absorbing the hit). 0.0 (a no-op) while nothing has marked him.
	if _player_corrosive_haze_bonus_pct > 0.0:
		amount *= (1.0 + _player_corrosive_haze_bonus_pct)

	# Mirror Image: every hit that would otherwise land on the hero, from
	# ANY source, has a chance to be redirected onto a random surviving
	# illusion instead - a full redirect, not a split, and completely
	# bypassing every one of the hero's own defensive mechanics below
	# (Reactive Armor's stack, Savage Roar, Borrowed Time, Aphotic
	# Shield) since nothing actually touched him this time. Uses the
	# hero's own armor for mitigation, same as if he'd taken it himself -
	# an illusion is a copy of him, not a separate combatant with its
	# own defense stat.
	if not _illusions.is_empty() and randf() < _illusion_hit_chance_pct:
		var illusion: Dictionary = _illusions[randi() % _illusions.size()]
		var illusion_damage: float = _apply_armor_reduction(amount, _hero_armor())
		_deal_damage_to_illusion(illusion, illusion_damage)
		return illusion_damage

	var reduced: float = _apply_armor_reduction(amount, _hero_armor())
	# Reactive Armor stacks off of this hit landing - added only after
	# _hero_armor() above already read the stack count, so the stack
	# this hit just earned reduces the NEXT hit, not this one.
	_apply_reactive_armor_stack()
	# Savage Roar's damage reduction stacks on top of armor mitigation
	# rather than replacing it, and only applies while it's active.
	reduced *= (1.0 - _savage_roar_damage_reduction_pct)

	# Borrowed Time reverses the hit entirely into a heal - there's no
	# damage left for Aphotic Shield to absorb, so that check is
	# skipped for as long as this is active.
	if _borrowed_time_active:
		heal(reduced * _borrowed_time_heal_conversion_pct)
		return reduced

	if _aphotic_shield_active:
		var absorbed: float = minf(reduced, _aphotic_shield_hp)
		_aphotic_shield_hp -= absorbed
		var overflow: float = reduced - absorbed
		if overflow > 0.0:
			PlayerManager.damage_hero(overflow)
		if _aphotic_shield_hp <= 0.0:
			_end_aphotic_shield(true)
		elif absorbed > 0.0:
			_update_aphotic_shell(hero_image, _aphotic_shield_hp)
		_refresh_bars()
		_maybe_auto_activate_borrowed_time()
		return reduced

	PlayerManager.damage_hero(reduced)
	_refresh_bars()
	_maybe_auto_activate_borrowed_time()
	return reduced


func spend_mana(amount: float) -> void:
	PlayerManager.use_mana(amount)
	_refresh_bars()


func heal(amount: float) -> void:
	PlayerManager.heal_hero(amount)
	_refresh_bars()


func restore_mana(amount: float) -> void:
	PlayerManager.restore_mana(amount)
	_refresh_bars()


func gain_xp(amount: float) -> void:
	PlayerManager.add_xp(amount)
	var level_ups: Array = PlayerManager.check_level_up(_hero_static)
	_refresh_bars()
	if not level_ups.is_empty():
		_show_level_up_popup(level_ups)


## Displays the LEVEL UP popup for one or more levels gained from a
## single XP gain. Shows the level reached and, for each of the six
## tracked stats, the value from just before the first level-up next
## to the value after the last one - so a multi-level jump reads as
## one clean before/after instead of a stack of popups.
func _show_level_up_popup(level_ups: Array) -> void:
	var first: Dictionary = level_ups[0]
	var last: Dictionary = level_ups[level_ups.size() - 1]
	var old_stats: Dictionary = first["old_stats"]
	var new_stats: Dictionary = last["new_stats"]

	level_up_level_label.text = "Level " + str(last["new_level"])

	_set_stat_row(level_up_strength_old, level_up_strength_new, old_stats["strength"], new_stats["strength"])
	_set_stat_row(level_up_agility_old, level_up_agility_new, old_stats["agility"], new_stats["agility"])
	_set_stat_row(level_up_intelligence_old, level_up_intelligence_new, old_stats["intelligence"], new_stats["intelligence"])
	_set_stat_row(level_up_hp_old, level_up_hp_new, old_stats["hp"], new_stats["hp"])
	_set_stat_row(level_up_mana_old, level_up_mana_new, old_stats["mana"], new_stats["mana"])
	# Damage has no level-up growth yet, so old/new will read the same -
	# still shown for completeness and consistency with the other stats.
	_set_stat_row(level_up_damage_old, level_up_damage_new, old_stats["damage"], new_stats["damage"])

	level_up_popup.visible = true


func _set_stat_row(old_label: Label, new_label: Label, old_value, new_value) -> void:
	old_label.text = _format_stat_value(old_value)
	new_label.text = _format_stat_value(new_value)


## Numeric stats (strength, agility, intelligence, hp, mana) print
## with one decimal place; damage is stored as a "min-max" string and
## just passes through unchanged.
func _format_stat_value(value) -> String:
	if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
		return "%.1f" % float(value)
	return str(value)


func _on_level_up_continue_pressed() -> void:
	level_up_popup.visible = false
	_maybe_show_skill_choice_popup()


## Opens the skill-choice popup if the player has any banked skill
## points AND at least one skill they could currently learn or
## upgrade with one - otherwise there's nothing to do (points with no
## legal use yet just stay banked for a later level).
func _maybe_show_skill_choice_popup() -> void:
	if not PlayerManager.has_spendable_skill_action(_hero_static):
		return
	_refresh_skill_choice_popup()
	skill_choice_popup.visible = true

	match _tutorial_forced_skill_id():
		"tidebringer":
			TutorialManager.show_popup(
				"You've got a skill point to spend. Kunkka needs more damage output to clear every "
				+ "enemy here in time - learn Tidebringer."
			)
		"ghostship":
			TutorialManager.show_popup(
				"You've got a skill point to spend. Learn Ghostship - it's your ultimate, and the "
				+ "single most powerful attack in your kit."
			)


## Rebuilds the skill-choice popup's option buttons from scratch:
## one per skill the player could currently learn (unlearned, level-1
## requirement met) or upgrade (learned, next-level requirement met).
func _refresh_skill_choice_popup() -> void:
	for child in skill_choice_options.get_children():
		child.queue_free()

	var points: int = PlayerManager.get_skill_points()
	var noun: String = "point" if points == 1 else "points"
	skill_choice_points_label.text = "You have %d skill %s to spend" % [points, noun]

	for skill in _hero_static.get("skills", []):
		var skill_id: String = skill.get("id", "")
		if not PlayerManager.can_spend_skill_point_on(skill_id, _hero_static):
			continue

		var current_level: int = PlayerManager.get_skill_level(skill_id)
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, 40)
		if current_level <= 0:
			btn.text = "Learn " + skill.get("name", skill_id)
		else:
			btn.text = "Upgrade " + skill.get("name", skill_id) + " to Lv " + str(current_level + 1)
		# Clicking an option no longer spends the point right away -
		# it opens the same explanation popup used elsewhere, so the
		# player can read the skill before committing (see
		# _on_skill_choice_option_pressed()).
		btn.pressed.connect(_on_skill_choice_option_pressed.bind(skill))

		# Tutorial support: locks every option except whichever skill
		# the current stage is forcing (see _on_skill_choice_desc_ok_
		# pressed()) - once that one's been taught, any later level-up's
		# skill point is the player's own free choice again, same as a
		# real playthrough.
		var forced_skill_id: String = _tutorial_forced_skill_id()
		if forced_skill_id != "" and skill_id != forced_skill_id:
			btn.disabled = true

		skill_choice_options.add_child(btn)


## Opens the description popup for a skill the player is considering
## learning/upgrading with a banked point. Nothing is spent yet - that
## only happens if they confirm with OK (_on_skill_choice_desc_ok_pressed).
func _on_skill_choice_option_pressed(skill: Dictionary) -> void:
	var skill_id: String = skill.get("id", "")
	_pending_level_up_skill_id = skill_id

	var current_level: int = PlayerManager.get_skill_level(skill_id)
	var target_level: int = 1 if current_level <= 0 else current_level + 1
	var action_text: String
	if current_level <= 0:
		action_text = "Learning this will put it at level 1."
	else:
		action_text = "Upgrading this will bring it to level %d." % target_level

	# The level being learned/upgraded TO, not the current one - shows
	# what the player is actually about to get, same reasoning
	# action_text above already uses.
	var level_data: Dictionary = GameManager.get_skill_level_data(skill, target_level)
	var stats_summary: String = GameManager.format_skill_level_stats(level_data)

	skill_choice_desc_name_label.text = skill.get("name", "")
	skill_choice_desc_label.text = skill.get("description", "") + "\n\n" + stats_summary + "\n\n" + action_text

	# Swap the list popup for the description popup - Cancel brings
	# the list back rather than closing everything, so the player can
	# still look at (or pick) a different option.
	skill_choice_popup.visible = false
	skill_choice_desc_popup.visible = true


## Confirms the pending skill: spends the point, refreshes the skill
## buttons (a newly learned skill needs its button re-enabled), then
## either loops back to the choice popup for another point/option, or
## closes everything once there's nothing left to spend.
func _on_skill_choice_desc_ok_pressed() -> void:
	skill_choice_desc_popup.visible = false

	var skill_id: String = _pending_level_up_skill_id
	_pending_level_up_skill_id = ""

	if skill_id == "":
		return

	if PlayerManager.spend_skill_point(skill_id, _hero_static):
		# Everything below reacts to a specific skill being learned
		# purely for the guided tutorial's own scripted beats (forcing
		# the next action, popping up its own explanation) - none of it
		# should ever fire for a normal playthrough, so it's all gated
		# behind TutorialManager.is_active. Without this, any player
		# leveling up Kunkka's Tidebringer or Ghostship outside the
		# tutorial would still get stage 3's "Ghostship is yours now..."
		# popup and its action lock, since TutorialManager.show_popup()/
		# set_allowed_actions() don't check is_active themselves.
		if TutorialManager.is_active:
			if skill_id == "tidebringer":
				_tutorial_taught_tidebringer = true
			elif skill_id == "ghostship":
				_tutorial_taught_ghostship = true
				# Starts the reinforcement countdown fresh from HERE rather
				# than from stage 3's battle start - landing that first kill
				# (to trigger this level-up) can itself take several attacks
				# against a melee creep's real HP, so counting from turn 0
				# let reinforcements arrive mid-leveling, before Ghostship
				# even existed to answer them - roughly doubling the enemy
				# count on top of the original roster and proving fatal.
				_next_reinforcement_turn = _turn_count + 2
				_advance_tutorial_stage3_step("attack_before_reinforcements")
		_recruited = PlayerManager.get_recruited_hero()
		_populate_skill_buttons()
		_update_action_buttons()

	if PlayerManager.has_spendable_skill_action(_hero_static):
		_refresh_skill_choice_popup()
		skill_choice_popup.visible = true
	else:
		skill_choice_popup.visible = false


## Backs out of the description popup without spending anything,
## returning to the list so the player can check other skills or pick
## the same one again.
func _on_skill_choice_desc_cancel_pressed() -> void:
	_pending_level_up_skill_id = ""
	skill_choice_desc_popup.visible = false
	skill_choice_popup.visible = true


# ------------------------------------------------------------------
# Turn actions: at most one move and one attack per turn.
# ------------------------------------------------------------------

## Heroes move faster than enemies as part of their stats - a speed
## of 1.5-2.7 rounds to 2-3 columns per move, while every enemy
## always takes exactly one column per turn (see _enemy_turn()). Adds
## Savage Roar's bonus columns while it's active (see
## _update_savage_roar_state()), plus a flat +1 column while Nature's
## Guise is active - moving unseen covers more ground, same "bonus on
## top of the normal speed-based distance" shape Savage Roar's own
## bonus already has, just gated on _natures_guise_active instead of an
## HP threshold.
func _hero_move_distance() -> int:
	var speed: float = float(_recruited.get("stats", {}).get("speed", 1.0))
	var natures_guise_bonus: int = 1 if _natures_guise_active else 0
	return maxi(1, roundi(speed)) + _savage_roar_bonus_movement + natures_guise_bonus


## Whether the hero currently fights at range - normally just his
## range_type stat, but True Form forces melee for its duration
## regardless of that stat (see _activate_true_form()).
func _is_ranged_hero() -> bool:
	if _true_form_active:
		return false
	return _hero_static.get("range_type", "Mele") == "Range"


## Melee heroes only fight by standing exactly on an enemy's column,
## so a multi-column move that would otherwise carry them past one
## stops right on top of it instead - covering less distance than
## their full speed, but landing somewhere they can actually attack.
## `_is_column_enemy_ice_shards_blocked()` stops the walk one column
## short of entering a rival-walled one, exactly like it already stops
## one column short of an occupied one below - a wall blocks movement
## the same way an enemy standing in the way does, it just isn't a
## valid landing spot either (unlike an enemy's column, which IS - see
## the early return right after).
func _melee_move_target(start: int, direction: int, distance: int) -> int:
	var pos: int = start

	for i in range(distance):
		var next_pos := pos + direction
		if next_pos < 0 or next_pos >= GRID_COLUMNS:
			break
		if _is_column_enemy_ice_shards_blocked(next_pos):
			break
		pos = next_pos

		if not _get_enemy_at(pos).is_empty():
			return pos

	return pos


## A ranged hero's own movement is normally a single unobstructed jump
## (see _hero_move()) - this only exists so a rival's Ice Shards wall
## still stops it early, same "can't move into a blocked column" rule
## _melee_move_target() enforces for a melee one, just without that
## function's own "stop on top of an enemy" rule (a ranged hero doesn't
## need to stand ON an enemy's column to fight it).
func _ranged_move_target(start: int, direction: int, distance: int) -> int:
	var pos: int = start

	for i in range(distance):
		var next_pos := pos + direction
		if next_pos < 0 or next_pos >= GRID_COLUMNS:
			break
		if _is_column_enemy_ice_shards_blocked(next_pos):
			break
		pos = next_pos

	return pos


## Guardian Sprint's own movement rule: walks up to `distance` columns
## from `start` in `direction`, stopping early at the board edge, a
## rival's Ice Shards wall, OR - unlike a plain ranged move, and
## regardless of the hero's own range_type - the first enemy's column
## along the way, same "stop on top of an enemy" rule
## _melee_move_target() already uses. Returns both the landing column
## and whatever enemy it stopped on ({} if it ran the full distance
## clean), for _hero_move() to deal Guardian Sprint's own charge_damage
## to.
func _guardian_sprint_move_target(start: int, direction: int, distance: int) -> Dictionary:
	var pos: int = start
	var hit_enemy: Dictionary = {}

	for i in range(distance):
		var next_pos: int = pos + direction
		if next_pos < 0 or next_pos >= GRID_COLUMNS:
			break
		if _is_column_ice_shards_blocked(next_pos):
			break
		pos = next_pos

		var enemy_here: Dictionary = _get_enemy_at(pos)
		if not enemy_here.is_empty():
			hit_enemy = enemy_here
			break

	return {"pos": pos, "hit_enemy": hit_enemy}


## Activates Guardian Sprint: arms this level's own bonus_movement/
## charge_damage_pct for `level_data.duration` turns. Doesn't move the
## hero himself - only _hero_move()'s own read of
## _guardian_sprint_turns_remaining changes what his NEXT normal moves
## do. Always "succeeds" - no target or range requirement, same as
## every other self-cast buff.
func _activate_guardian_sprint(level_data: Dictionary) -> void:
	_guardian_sprint_bonus_movement = int(level_data.get("bonus_movement", 0))
	_guardian_sprint_charge_damage_pct = float(level_data.get("charge_damage_pct", 0.0))
	_guardian_sprint_turns_remaining = int(level_data.get("duration", 0))
	# The casting turn itself doesn't count - duration only starts
	# ticking from the turn after (see _tick_guardian_sprint()), same as
	# every other duration-based buff. The bonus itself is already live
	# the instant this returns, same as Living Armor's own bonus_armor -
	# only the countdown toward it running out is delayed.
	_guardian_sprint_duration_pending_start = true

	_show_message_over_hero("Guardian Sprint!")


## Ticks Guardian Sprint's duration down once per End Turn, same timing
## (and same "the casting turn doesn't count" skip) as every other
## duration-based buff.
func _tick_guardian_sprint() -> void:
	if _guardian_sprint_turns_remaining <= 0:
		return

	if _guardian_sprint_duration_pending_start:
		_guardian_sprint_duration_pending_start = false
		return

	_guardian_sprint_turns_remaining -= 1
	if _guardian_sprint_turns_remaining <= 0:
		_end_guardian_sprint()


## Ends Guardian Sprint once its duration runs out.
func _end_guardian_sprint() -> void:
	_guardian_sprint_turns_remaining = 0
	_guardian_sprint_bonus_movement = 0
	_guardian_sprint_charge_damage_pct = 0.0
	_guardian_sprint_duration_pending_start = false

	_show_message_over_hero("Guardian Sprint wears off")


func _hero_move(direction: int) -> void:
	if _battle_over or _has_acted_this_turn:
		return

	if _player_root_turns_left > 0:
		_show_message_over_hero("Rooted!")
		return

	if _cold_embrace_active:
		_show_message_over_hero("Encased in ice!")
		return

	if _mortimer_kisses_active:
		_show_message_over_hero("Focused on Mortimer Kisses!")
		return

	if _is_column_enemy_ice_shards_blocked(_hero_pos_index):
		_show_message_over_hero("Frozen in place!")
		return

	_cancel_targeting()

	var generation_before: int = _stage_generation
	var distance: int = _hero_move_distance()

	if _guardian_sprint_turns_remaining > 0:
		distance += _guardian_sprint_bonus_movement
		var sprint_result: Dictionary = _guardian_sprint_move_target(_hero_pos_index, direction, distance)
		_hero_pos_index = int(sprint_result["pos"])
		var charged_enemy: Dictionary = sprint_result["hit_enemy"]
		if not charged_enemy.is_empty():
			var charge_damage: float = _roll_hero_damage() * _guardian_sprint_charge_damage_pct
			_deal_fixed_damage_to_enemy(charged_enemy, charge_damage)
	elif _is_ranged_hero():
		_hero_pos_index = _ranged_move_target(_hero_pos_index, direction, distance)
	else:
		_hero_pos_index = _melee_move_target(_hero_pos_index, direction, distance)

	# Hero art is drawn facing right by default (see _spawn_enemy()'s own
	# note on art orientation), so moving left mirrors it to face that way.
	hero_image.flip_h = direction < 0

	_update_hero_position()

	# A Guardian Sprint charge landing the killing blow could clear the
	# stage (or win a hero fight) and move on to a fresh encounter -
	# same bail-out every skill resolver already uses before spending
	# the turn, needed here for the first time since this is the first
	# path through _hero_move() that can ever deal damage.
	if _battle_over or _stage_generation != generation_before:
		return

	_mark_turn_used()


## Fleeing a hero fight leaves the rival alive and, unlike an actual
## loss, was never going to be caught by _handle_defeat()'s own
## restock - so it needs its own copy of that same "the rival gets a
## chance to restock before the player can meet them again" step (see
## EnemyHeroManager.restock_npc_potions()) or a fled fight would let
## the player whittle a rival's potions down for free, over and over,
## with no gold cost ever attached the way losing to them does. Only
## fires during an actual hero fight - fleeing a normal creep stage has
## no rival hero to restock.
func _on_flee_pressed() -> void:
	if _in_hero_fight:
		EnemyHeroManager.restock_npc_potions(_enemy_hero_id)
	get_tree().change_scene_to_file("res://scenes/Map.tscn")


func _on_move_left_pressed() -> void:
	_hero_move(-1)


func _on_move_right_pressed() -> void:
	_hero_move(1)


func _on_attack_pressed() -> void:
	if _battle_over or _has_acted_this_turn:
		return

	if _cold_embrace_active:
		_show_message_over_hero("Encased in ice!")
		return

	if _mortimer_kisses_active:
		_show_message_over_hero("Focused on Mortimer Kisses!")
		return

	if _is_ranged_hero():
		_start_ranged_targeting()
	else:
		_resolve_melee_attack()


func _resolve_melee_attack() -> void:
	var target: Dictionary = _get_enemy_at(_hero_pos_index)
	if target.is_empty():
		_show_message_over_hero("No enemy in range")
		return
	_apply_hero_attack(target)


## How many columns away a ranged hero can hit, from their Range
## stat: 200-300 -> 1 column, 300-400 -> 2 columns, and so on
## (+100 range per extra column) - plus Winter Wyvern's Arctic Burn
## bonus_range while it's active, folded straight in so it stretches
## every consumer of this helper (a plain ranged Attack, Chilling
## Touch's own "same as attack range" targeting) the same way.
func _hero_attack_column_range() -> int:
	var range_stat: float = float(_recruited.get("stats", {}).get("range", 200))
	return maxi(1, floori((range_stat - 200.0) / 100.0) + 1) + _arctic_burn_bonus_range


func _start_ranged_targeting() -> void:
	_cancel_targeting()

	var col_range: int = _hero_attack_column_range()
	for enemy in _enemies:
		if _is_target_hidden(enemy):
			continue
		if _distance(enemy["pos_index"], _hero_pos_index) <= col_range:
			_valid_targets.append(enemy)

	if _valid_targets.is_empty():
		_show_message_over_hero("No enemy in range")
		return

	_targeting_mode = true
	_targeting_purpose = "attack"
	_highlight_valid_targets()


## Entangle's target picking: same column-range/highlight mechanism as
## a ranged Attack (_start_ranged_targeting), but resolves through
## _resolve_entangle_cast() on click instead of a plain attack.
## Returns false (and shows a message) if nothing is in range - the
## caller then knows not to spend mana/cooldown/the turn.
func _start_entangle_targeting(level_data: Dictionary) -> bool:
	_cancel_targeting()

	var col_range: int = _hero_attack_column_range()
	for enemy in _enemies:
		if _is_target_hidden(enemy):
			continue
		if _distance(enemy["pos_index"], _hero_pos_index) <= col_range:
			_valid_targets.append(enemy)

	if _valid_targets.is_empty():
		_show_message_over_hero("No enemy in range")
		return false

	_targeting_mode = true
	_targeting_purpose = "entangle"
	_pending_entangle_level_data = level_data
	_highlight_valid_targets()
	return true


## Mist Coil's own targeting range, in columns - fixed regardless of
## the hero's Range stat (unlike a plain ranged Attack or Entangle,
## which both scale with it via _hero_attack_column_range()), since
## it's a bolt of mist rather than a physical attack.
const MIST_COIL_RANGE := 2


## Mist Coil's target picking: highlights any enemy within
## MIST_COIL_RANGE columns AND the hero's own portrait, since Mist Coil
## can be cast on either - a damaging bolt on an enemy, or a costly-
## but-net-positive heal on Abaddon himself (see
## _resolve_mist_coil_enemy_cast()/_resolve_mist_coil_self_cast()).
## Self-casting is always available regardless of range, so - unlike
## Entangle/ranged Attack - this never fails for lack of a target;
## it only bails out (returning false) if the player is already stuck
## with no enemies AND can't afford the HP cost, in which case there's
## nothing legal to click at all.
func _start_mist_coil_targeting(level_data: Dictionary) -> bool:
	_cancel_targeting()

	var col_range: int = MIST_COIL_RANGE
	for enemy in _enemies:
		if _is_target_hidden(enemy):
			continue
		if _distance(enemy["pos_index"], _hero_pos_index) <= col_range:
			_valid_targets.append(enemy)

	var hp_cost: float = float(level_data.get("hp_cost", 0))
	var can_self_cast: bool = float(_recruited.get("current_hp", 0)) >= hp_cost

	if _valid_targets.is_empty() and not can_self_cast:
		_show_message_over_hero("No enemy in range and not enough HP")
		return false

	_targeting_mode = true
	_targeting_purpose = "mist_coil"
	_pending_mist_coil_level_data = level_data
	_highlight_valid_targets()
	if can_self_cast:
		_highlight_hero_self_target()
	return true


## Kunkka's Torrent target picking: same column-range/highlight
## mechanism as Entangle/ranged Attack, but the range itself comes
## straight from this level's own `range` field (a constant 3 at every
## level per the design doc) rather than _hero_attack_column_range() -
## Torrent lands where Kunkka calls it down, regardless of his Range
## stat, the same way Mist Coil's own fixed MIST_COIL_RANGE does.
## Returns false (and shows a message) if nothing is in range.
func _start_torrent_targeting(level_data: Dictionary) -> bool:
	_cancel_targeting()

	var col_range: int = int(level_data.get("range", 3))
	for enemy in _enemies:
		if _is_target_hidden(enemy):
			continue
		if _distance(enemy["pos_index"], _hero_pos_index) <= col_range:
			_valid_targets.append(enemy)

	if _valid_targets.is_empty():
		_show_message_over_hero("No enemy in range")
		return false

	_targeting_mode = true
	_targeting_purpose = "torrent"
	_pending_torrent_level_data = level_data
	_highlight_valid_targets()
	return true


## Kunkka's X Marks the Spot target picking: same column-range/
## highlight mechanism as Torrent, using this level's own `range` field
## (2-5 columns, growing with level, unlike Torrent's constant 3).
## Returns false (and shows a message) if nothing is in range.
func _start_xmarks_targeting(level_data: Dictionary) -> bool:
	_cancel_targeting()

	var col_range: int = int(level_data.get("range", 2))
	for enemy in _enemies:
		if _is_target_hidden(enemy):
			continue
		if _distance(enemy["pos_index"], _hero_pos_index) <= col_range:
			_valid_targets.append(enemy)

	if _valid_targets.is_empty():
		_show_message_over_hero("No enemy in range")
		return false

	_targeting_mode = true
	_targeting_purpose = "x_marks_the_spot"
	_pending_xmarks_level_data = level_data
	_highlight_valid_targets()
	return true


## Kunkka's Ghostship target picking: same column-range/highlight
## mechanism as Torrent/X Marks the Spot, using this level's own
## `range` field (4-6 columns, growing with level) - just for picking
## where the ship sails TO; every enemy actually hit is worked out at
## resolve time from the straight line between Kunkka and that pick
## (see _resolve_ghostship_cast()), not from this range itself.
## Returns false (and shows a message) if nothing is in range.
func _start_ghostship_targeting(level_data: Dictionary) -> bool:
	_cancel_targeting()

	var col_range: int = int(level_data.get("range", 4))
	for enemy in _enemies:
		if _is_target_hidden(enemy):
			continue
		if _distance(enemy["pos_index"], _hero_pos_index) <= col_range:
			_valid_targets.append(enemy)

	if _valid_targets.is_empty():
		_show_message_over_hero("No enemy in range")
		return false

	_targeting_mode = true
	_targeting_purpose = "ghostship"
	_pending_ghostship_level_data = level_data
	_highlight_valid_targets()
	return true


## Slardar's Corrosive Haze target picking: same column-range/highlight
## mechanism as every other targeted skill above, using this level's
## own `range` field (4-6 columns, growing with level). Returns false
## (and shows a message) if nothing is in range.
func _start_corrosive_haze_targeting(level_data: Dictionary) -> bool:
	_cancel_targeting()

	var col_range: int = int(level_data.get("range", 4))
	for enemy in _enemies:
		if _is_target_hidden(enemy):
			continue
		if _distance(enemy["pos_index"], _hero_pos_index) <= col_range:
			_valid_targets.append(enemy)

	if _valid_targets.is_empty():
		_show_message_over_hero("No enemy in range")
		return false

	_targeting_mode = true
	_targeting_purpose = "corrosive_haze"
	_pending_corrosive_haze_level_data = level_data
	_highlight_valid_targets()
	return true


## Mirana's Sacred Arrow target picking: same column-range/highlight
## mechanism as every other targeted skill above, using this level's
## own `range` field (4-7 columns, growing with level) - the same
## distance the damage formula scales off of (see
## _resolve_sacred_arrow_cast()), so a target at the very edge of range
## is exactly where the "Max Damage" table column comes from. Returns
## false (and shows a message) if nothing is in range.
func _start_sacred_arrow_targeting(level_data: Dictionary) -> bool:
	_cancel_targeting()

	var col_range: int = int(level_data.get("range", 4))
	for enemy in _enemies:
		if _is_target_hidden(enemy):
			continue
		if _distance(enemy["pos_index"], _hero_pos_index) <= col_range:
			_valid_targets.append(enemy)

	if _valid_targets.is_empty():
		_show_message_over_hero("No enemy in range")
		return false

	_targeting_mode = true
	_targeting_purpose = "sacred_arrow"
	_pending_sacred_arrow_level_data = level_data
	_highlight_valid_targets()
	return true


## Luna's Lucent Beam target picking: same column-range/highlight
## mechanism as every other targeted skill above, using this level's own
## `range` field (4-7 columns, growing with level). Returns false (and
## shows a message) if nothing is in range.
func _start_lucent_beam_targeting(level_data: Dictionary) -> bool:
	_cancel_targeting()

	var col_range: int = int(level_data.get("range", 4))
	for enemy in _enemies:
		if _is_target_hidden(enemy):
			continue
		if _distance(enemy["pos_index"], _hero_pos_index) <= col_range:
			_valid_targets.append(enemy)

	if _valid_targets.is_empty():
		_show_message_over_hero("No enemy in range")
		return false

	_targeting_mode = true
	_targeting_purpose = "lucent_beam"
	_pending_lucent_beam_level_data = level_data
	_highlight_valid_targets()
	return true


## Naga Siren's Ensnare target picking: same column-range/highlight
## mechanism as every other targeted skill above, using this level's
## own `range` field (3-6 columns, growing with level) rather than the
## hero's normal attack range - Ensnare reaches further than a plain
## Attack. Returns false (and shows a message) if nothing is in range.
func _start_ensnare_targeting(level_data: Dictionary) -> bool:
	_cancel_targeting()

	var col_range: int = int(level_data.get("range", 3))
	for enemy in _enemies:
		if _is_target_hidden(enemy):
			continue
		if _distance(enemy["pos_index"], _hero_pos_index) <= col_range:
			_valid_targets.append(enemy)

	if _valid_targets.is_empty():
		_show_message_over_hero("No enemy in range")
		return false

	_targeting_mode = true
	_targeting_purpose = "ensnare"
	_pending_ensnare_level_data = level_data
	_highlight_valid_targets()
	return true


## Timbersaw's Timber Chain target picking: same column-range/highlight
## mechanism as every other targeted skill above, using this level's
## own `range` field (3-5 columns, growing with level).
## Returns false (and shows a message) if nothing is in range.
func _start_timber_chain_targeting(level_data: Dictionary) -> bool:
	_cancel_targeting()

	var col_range: int = int(level_data.get("range", 3))
	for enemy in _enemies:
		if _is_target_hidden(enemy):
			continue
		if _distance(enemy["pos_index"], _hero_pos_index) <= col_range:
			_valid_targets.append(enemy)

	if _valid_targets.is_empty():
		_show_message_over_hero("No enemy in range")
		return false

	_targeting_mode = true
	_targeting_purpose = "timber_chain"
	_pending_timber_chain_level_data = level_data
	_highlight_valid_targets()
	return true


## Timbersaw's Chakram target picking: same column-range/highlight
## mechanism as every other targeted skill above, using this level's
## own `range` field (5-7 columns, growing with level) - separate from
## the `radius` field used for the AoE once it's planted (see
## _resolve_chakram_cast()/_tick_chakram()). Returns false (and shows a
## message) if nothing is in range.
func _start_chakram_targeting(level_data: Dictionary) -> bool:
	_cancel_targeting()

	var col_range: int = int(level_data.get("range", 5))
	for enemy in _enemies:
		if _is_target_hidden(enemy):
			continue
		if _distance(enemy["pos_index"], _hero_pos_index) <= col_range:
			_valid_targets.append(enemy)

	if _valid_targets.is_empty():
		_show_message_over_hero("No enemy in range")
		return false

	_targeting_mode = true
	_targeting_purpose = "chakram"
	_pending_chakram_level_data = level_data
	_highlight_valid_targets()
	return true


## Ancient Apparition's Cold Feet target picking: same column-range/
## highlight mechanism as every other targeted skill above, using this
## level's own `range` field (2-4 columns, growing with level).
## Returns false (and shows a message) if nothing is in range.
func _start_cold_feet_targeting(level_data: Dictionary) -> bool:
	_cancel_targeting()

	var col_range: int = int(level_data.get("range", 2))
	for enemy in _enemies:
		if _is_target_hidden(enemy):
			continue
		if _distance(enemy["pos_index"], _hero_pos_index) <= col_range:
			_valid_targets.append(enemy)

	if _valid_targets.is_empty():
		_show_message_over_hero("No enemy in range")
		return false

	_targeting_mode = true
	_targeting_purpose = "cold_feet"
	_pending_cold_feet_level_data = level_data
	_highlight_valid_targets()
	return true


## Ice Vortex's own targeting range, in columns - fixed regardless of
## level or the hero's Range stat (unlike Cold Feet's own per-level
## range), since it's a cast point, not a stat-scaled attack.
const ICE_VORTEX_RANGE := 3


## Ancient Apparition's Ice Vortex target picking: same column-range/
## highlight mechanism as every other targeted skill above, but always
## at ICE_VORTEX_RANGE - the level only changes the AoE radius applied
## around whichever enemy gets clicked (see _resolve_ice_vortex_cast()),
## never the targeting range itself. Returns false (and shows a
## message) if nothing is in range.
func _start_ice_vortex_targeting(level_data: Dictionary) -> bool:
	_cancel_targeting()

	for enemy in _enemies:
		if _is_target_hidden(enemy):
			continue
		if _distance(enemy["pos_index"], _hero_pos_index) <= ICE_VORTEX_RANGE:
			_valid_targets.append(enemy)

	if _valid_targets.is_empty():
		_show_message_over_hero("No enemy in range")
		return false

	_targeting_mode = true
	_targeting_purpose = "ice_vortex"
	_pending_ice_vortex_level_data = level_data
	_highlight_valid_targets()
	return true


## Ancient Apparition's Chilling Touch target picking: same column-
## range/highlight mechanism as every other targeted skill above, but
## using the hero's own normal attack range (_hero_attack_column_
## range(), the same stat-scaled helper a plain ranged Attack/Entangle
## use) rather than a skill-specific field - Chilling Touch is
## explicitly "attack range", not its own distance. Returns false (and
## shows a message) if nothing is in range.
func _start_chilling_touch_targeting(level_data: Dictionary) -> bool:
	_cancel_targeting()

	var col_range: int = _hero_attack_column_range()
	for enemy in _enemies:
		if _is_target_hidden(enemy):
			continue
		if _distance(enemy["pos_index"], _hero_pos_index) <= col_range:
			_valid_targets.append(enemy)

	if _valid_targets.is_empty():
		_show_message_over_hero("No enemy in range")
		return false

	_targeting_mode = true
	_targeting_purpose = "chilling_touch"
	_pending_chilling_touch_level_data = level_data
	_highlight_valid_targets()
	return true


## Ancient Apparition's Ice Blast target picking: no range limit at
## all, unlike every other targeted skill above - the design doc's own
## "targets an enemy anywhere on the field" - so every living,
## targetable enemy is a valid target regardless of column distance
## from the hero. Returns false (and shows a message) only if there's
## no enemy left to target at all.
func _start_ice_blast_targeting(level_data: Dictionary) -> bool:
	_cancel_targeting()

	for enemy in _enemies:
		if _is_target_hidden(enemy):
			continue
		_valid_targets.append(enemy)

	if _valid_targets.is_empty():
		_show_message_over_hero("No enemy in range")
		return false

	_targeting_mode = true
	_targeting_purpose = "ice_blast"
	_pending_ice_blast_level_data = level_data
	_highlight_valid_targets()
	return true


## Winter Wyvern's Splinter Blast target picking: same column-range/
## highlight mechanism as Chilling Touch - the hero's own normal attack
## range (_hero_attack_column_range()), since the design doc calls for
## "an enemy in range (range of normal attack)" rather than a skill-
## specific distance. Returns false (and shows a message) if nothing is
## in range.
func _start_splinter_blast_targeting(level_data: Dictionary) -> bool:
	_cancel_targeting()

	var col_range: int = _hero_attack_column_range()
	for enemy in _enemies:
		if _is_target_hidden(enemy):
			continue
		if _distance(enemy["pos_index"], _hero_pos_index) <= col_range:
			_valid_targets.append(enemy)

	if _valid_targets.is_empty():
		_show_message_over_hero("No enemy in range")
		return false

	_targeting_mode = true
	_targeting_purpose = "splinter_blast"
	_pending_splinter_blast_level_data = level_data
	_highlight_valid_targets()
	return true


## Winter Wyvern's Winter's Curse target picking: same column-range/
## highlight mechanism as Splinter Blast/Chilling Touch - the hero's own
## normal attack range (_hero_attack_column_range()), per the design
## doc's own "an enemy in range (normal attack range)". Returns false
## (and shows a message) if nothing is in range.
func _start_winters_curse_targeting(level_data: Dictionary) -> bool:
	_cancel_targeting()

	var col_range: int = _hero_attack_column_range()
	for enemy in _enemies:
		if _is_target_hidden(enemy):
			continue
		if _distance(enemy["pos_index"], _hero_pos_index) <= col_range:
			_valid_targets.append(enemy)

	if _valid_targets.is_empty():
		_show_message_over_hero("No enemy in range")
		return false

	_targeting_mode = true
	_targeting_purpose = "winter's_curse"
	_pending_winters_curse_level_data = level_data
	_highlight_valid_targets()
	return true


## Crystal Maiden's Crystal Nova target picking: same column-range/
## highlight mechanism as every other "normal attack range" targeted
## skill above (_hero_attack_column_range()). Returns false (and shows
## a message) if nothing is in range.
func _start_crystal_nova_targeting(level_data: Dictionary) -> bool:
	_cancel_targeting()

	var col_range: int = _hero_attack_column_range()
	for enemy in _enemies:
		if _is_target_hidden(enemy):
			continue
		if _distance(enemy["pos_index"], _hero_pos_index) <= col_range:
			_valid_targets.append(enemy)

	if _valid_targets.is_empty():
		_show_message_over_hero("No enemy in range")
		return false

	_targeting_mode = true
	_targeting_purpose = "crystal_nova"
	_pending_crystal_nova_level_data = level_data
	_highlight_valid_targets()
	return true


## Snapfire's Lil' Shredder target picking: same "normal attack range"
## gate (_hero_attack_column_range()) every other attack-range targeted
## skill above uses - Lil' Shredder is a volley of shots at ONE marked
## target, not an extended-range skill of its own, so it shares the
## plain Attack's own reach rather than a level-specific `range` field.
## Returns false (and shows a message) if nothing is in range.
func _start_lil_shredder_targeting(level_data: Dictionary) -> bool:
	_cancel_targeting()

	var col_range: int = _hero_attack_column_range()
	for enemy in _enemies:
		if _is_target_hidden(enemy):
			continue
		if _distance(enemy["pos_index"], _hero_pos_index) <= col_range:
			_valid_targets.append(enemy)

	if _valid_targets.is_empty():
		_show_message_over_hero("No enemy in range")
		return false

	_targeting_mode = true
	_targeting_purpose = "lil_shredder"
	_pending_lil_shredder_level_data = level_data
	_highlight_valid_targets()
	return true


## Crystal Maiden's Frostbite target picking: same column-range/
## highlight mechanism as every other "normal attack range" targeted
## skill above (_hero_attack_column_range()). Returns false (and shows
## a message) if nothing is in range.
func _start_frostbite_targeting(level_data: Dictionary) -> bool:
	_cancel_targeting()

	var col_range: int = _hero_attack_column_range()
	for enemy in _enemies:
		if _is_target_hidden(enemy):
			continue
		if _distance(enemy["pos_index"], _hero_pos_index) <= col_range:
			_valid_targets.append(enemy)

	if _valid_targets.is_empty():
		_show_message_over_hero("No enemy in range")
		return false

	_targeting_mode = true
	_targeting_purpose = "frostbite"
	_pending_frostbite_level_data = level_data
	_highlight_valid_targets()
	return true


## Tusk's Ice Shards target picking: unlike every "normal attack range"
## targeted skill above, this uses the skill's OWN level_data.range
## field instead of _hero_attack_column_range() - same reasoning as
## Torrent's own targeting (_start_torrent_targeting()), since Tusk
## fights at melee range but Ice Shards is thrown well past it. Returns
## false (and shows a message) if nothing is in range.
func _start_ice_shards_targeting(level_data: Dictionary) -> bool:
	_cancel_targeting()

	var col_range: int = int(level_data.get("range", 0))
	for enemy in _enemies:
		if _is_target_hidden(enemy):
			continue
		if _distance(enemy["pos_index"], _hero_pos_index) <= col_range:
			_valid_targets.append(enemy)

	if _valid_targets.is_empty():
		_show_message_over_hero("No enemy in range")
		return false

	_targeting_mode = true
	_targeting_purpose = "ice_shards"
	_pending_ice_shards_level_data = level_data
	_highlight_valid_targets()
	return true


## Tusk's Snowball target picking: same skill-specific level_data.range
## reasoning as Ice Shards' own targeting - Tusk fights at melee range,
## but Snowball charges well past it. Returns false (and shows a
## message) if nothing is in range.
func _start_snowball_targeting(level_data: Dictionary) -> bool:
	_cancel_targeting()

	var col_range: int = int(level_data.get("range", 0))
	for enemy in _enemies:
		if _is_target_hidden(enemy):
			continue
		if _distance(enemy["pos_index"], _hero_pos_index) <= col_range:
			_valid_targets.append(enemy)

	if _valid_targets.is_empty():
		_show_message_over_hero("No enemy in range")
		return false

	_targeting_mode = true
	_targeting_purpose = "snowball"
	_pending_snowball_level_data = level_data
	_highlight_valid_targets()
	return true


## Tusk's Walrus Punch target picking: strictly melee range (sharing
## his own column, same as a plain melee Attack - _resolve_melee_
## attack()) rather than any column-range field, since the design doc
## calls for "melee range" specifically. Returns false (and shows a
## message) if nothing shares his column.
func _start_walrus_punch_targeting(level_data: Dictionary) -> bool:
	_cancel_targeting()

	for enemy in _enemies:
		if _is_target_hidden(enemy):
			continue
		if enemy["pos_index"] == _hero_pos_index:
			_valid_targets.append(enemy)

	if _valid_targets.is_empty():
		_show_message_over_hero("No enemy in range")
		return false

	_targeting_mode = true
	_targeting_purpose = "walrus_punch"
	_pending_walrus_punch_level_data = level_data
	_highlight_valid_targets()
	return true


## Treant Protector's Leech Seed target picking: same column-range/
## highlight mechanism as every other targeted skill above, using this
## level's own fixed range field (a constant 2 columns per the design
## doc, still stored per-level like every other skill's own range).
## Returns false (and shows a message) if nothing is in range.
func _start_leech_seed_targeting(level_data: Dictionary) -> bool:
	_cancel_targeting()

	var col_range: int = int(level_data.get("range", 0))
	for enemy in _enemies:
		if _is_target_hidden(enemy):
			continue
		if _distance(enemy["pos_index"], _hero_pos_index) <= col_range:
			_valid_targets.append(enemy)

	if _valid_targets.is_empty():
		_show_message_over_hero("No enemy in range")
		return false

	_targeting_mode = true
	_targeting_purpose = "leech_seed"
	_pending_leech_seed_level_data = level_data
	_highlight_valid_targets()
	return true


## Marks every enemy currently in `_valid_targets` with a bright,
## pulsing highlight (TARGET_HIGHLIGHT_COLOR/_PULSE_COLOR) instead of
## the flat, easy-to-miss pastel tint each _start_X_targeting() function
## used to set on its own - called by every one of them right after
## `_valid_targets` is actually populated. Each node's own pulse tween
## is tracked in _target_highlight_tweens so _cancel_targeting() can
## kill it before resetting modulate back to normal - an untracked,
## still-running tween would just fight that reset every frame.
func _highlight_valid_targets() -> void:
	for enemy in _valid_targets:
		var node: TextureRect = enemy["node"]
		node.modulate = TARGET_HIGHLIGHT_COLOR
		var tween := create_tween()
		tween.set_loops()
		tween.tween_property(node, "modulate", TARGET_HIGHLIGHT_PULSE_COLOR, 0.4).set_trans(Tween.TRANS_SINE)
		tween.tween_property(node, "modulate", TARGET_HIGHLIGHT_COLOR, 0.4).set_trans(Tween.TRANS_SINE)
		_target_highlight_tweens.append(tween)


## Same bright, pulsing treatment as _highlight_valid_targets(), just on
## the hero's own portrait (HERO_TARGET_HIGHLIGHT_COLOR/_PULSE_COLOR's
## green, not TARGET_HIGHLIGHT_COLOR's gold) - for a skill that can be
## self-cast (right now, only Mist Coil's _start_mist_coil_targeting(),
## when can_self_cast is true). Tracked in the same
## _target_highlight_tweens _cancel_targeting() already kills and resets
## (via _update_hero_visibility()) - one shared cleanup handles both the
## enemy and hero highlights, whichever combination is currently lit.
func _highlight_hero_self_target() -> void:
	hero_image.modulate = HERO_TARGET_HIGHLIGHT_COLOR
	var tween := create_tween()
	tween.set_loops()
	tween.tween_property(hero_image, "modulate", HERO_TARGET_HIGHLIGHT_PULSE_COLOR, 0.4).set_trans(Tween.TRANS_SINE)
	tween.tween_property(hero_image, "modulate", HERO_TARGET_HIGHLIGHT_COLOR, 0.4).set_trans(Tween.TRANS_SINE)
	_target_highlight_tweens.append(tween)


## Clears any still-highlighted valid-target tint and resets the hero's
## own portrait modulate back to whatever it's SUPPOSED to be right now
## (_update_hero_visibility(), not a hardcoded Color(1,1,1)) - Mist
## Coil's own self-target highlight tints hero_image the same way a
## valid enemy target gets tinted, so this needs to undo that without
## also stomping Shadow Dance's/Nature's Guise's own invisibility fade
## if either is still active. _cancel_targeting() runs constantly -
## every _end_turn() call, every new targeting session - so a hardcoded
## reset here was clobbering the invisibility fade back to fully opaque
## one turn after casting Nature's Guise, even though _natures_guise_
## active stayed true for its whole duration. Kills every pulsing
## highlight tween FIRST (see _highlight_valid_targets()) so none of
## them are still running to immediately overwrite the reset below.
func _cancel_targeting() -> void:
	for tween in _target_highlight_tweens:
		if tween:
			tween.kill()
	_target_highlight_tweens.clear()
	for enemy in _valid_targets:
		if is_instance_valid(enemy["node"]):
			enemy["node"].modulate = Color(1, 1, 1)
	_update_hero_visibility()
	_valid_targets.clear()
	_targeting_mode = false
	_targeting_purpose = "attack"
	_pending_entangle_level_data = {}
	_pending_mist_coil_level_data = {}


func _on_enemy_gui_input(event: InputEvent, enemy: Dictionary) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_enemy_clicked(_pick_enemy_under_mouse(enemy))


## Every enemy's TextureRect catches clicks across its whole rectangle,
## transparent padding included - so where two sprites overlap, whichever
## was added to enemies_layer last swallows the click even when the
## cursor is plainly over the creature drawn behind it. This re-resolves
## the click against actual opaque pixels instead: of every enemy whose
## sprite is visibly under the cursor, prefer the topmost one that's
## currently a valid target (so a non-targetable sprite overlapping a
## targetable one doesn't block it), else the topmost opaque one. Falls
## back to `fallback` (the node Godot actually delivered the click to)
## when the cursor is only over transparent padding.
func _pick_enemy_under_mouse(fallback: Dictionary) -> Dictionary:
	var hits: Array = []
	for enemy in _enemies:
		var node: TextureRect = enemy.get("node")
		if node == null or not is_instance_valid(node) or not node.is_visible_in_tree():
			continue
		if _is_texture_rect_opaque_at(node, node.get_local_mouse_position()):
			hits.append(enemy)
	if hits.is_empty():
		return fallback
	# Topmost first - later siblings draw over earlier ones.
	hits.sort_custom(func(a, b): return a["node"].get_index() > b["node"].get_index())
	if _targeting_mode:
		for enemy in hits:
			if _valid_targets.has(enemy):
				return enemy
	return hits[0]


# Texture -> decompressed Image, so repeated clicks don't re-fetch the
# texture data from the GPU every time.
var _hit_test_image_cache: Dictionary = {}


## Whether `node`'s texture has a visible (non-transparent) pixel at
## `local_pos` - accounts for STRETCH_KEEP_ASPECT's centered letterboxing
## and flip_h, the two modes _spawn_enemy() actually uses.
func _is_texture_rect_opaque_at(node: TextureRect, local_pos: Vector2) -> bool:
	if not Rect2(Vector2.ZERO, node.size).has_point(local_pos):
		return false
	var texture: Texture2D = node.texture
	if texture == null:
		return false
	var image: Image = _hit_test_image_cache.get(texture)
	if image == null:
		image = texture.get_image()
		if image == null:
			return true
		if image.is_compressed():
			image = image.duplicate()
			image.decompress()
		_hit_test_image_cache[texture] = image
	var tex_size: Vector2 = Vector2(image.get_size())
	var s: float = minf(node.size.x / tex_size.x, node.size.y / tex_size.y)
	var offset: Vector2 = (node.size - tex_size * s) / 2.0
	var px: Vector2 = (local_pos - offset) / s
	if px.x < 0 or px.y < 0 or px.x >= tex_size.x or px.y >= tex_size.y:
		return false
	var x: int = int(px.x)
	if node.flip_h:
		x = int(tex_size.x) - 1 - x
	return image.get_pixel(x, int(px.y)).a > 0.1


func _on_enemy_clicked(enemy: Dictionary) -> void:
	if not _targeting_mode or _battle_over or _has_acted_this_turn:
		return
	if not _valid_targets.has(enemy):
		return
	if not _tutorial_allows_enemy_click(enemy):
		return

	# Resolve to whichever enemy on this same column is actually lowest
	# HP, same as a melee Attack/Pounce/the bear already do via
	# _get_enemy_at() - clicking a specific sprite just picks the
	# column/spot to strike, not necessarily which of several stacked
	# enemies there takes the hit. Falls back to the clicked enemy
	# itself on the (should-be-impossible) case _get_enemy_at() finds
	# nothing at its own column.
	var resolved: Dictionary = _get_enemy_at(enemy["pos_index"])
	if not resolved.is_empty():
		enemy = resolved

	var purpose: String = _targeting_purpose
	var entangle_level_data: Dictionary = _pending_entangle_level_data
	var mist_coil_level_data: Dictionary = _pending_mist_coil_level_data
	var torrent_level_data: Dictionary = _pending_torrent_level_data
	var xmarks_level_data: Dictionary = _pending_xmarks_level_data
	var ghostship_level_data: Dictionary = _pending_ghostship_level_data
	var corrosive_haze_level_data: Dictionary = _pending_corrosive_haze_level_data
	var sacred_arrow_level_data: Dictionary = _pending_sacred_arrow_level_data
	var lucent_beam_level_data: Dictionary = _pending_lucent_beam_level_data
	var ensnare_level_data: Dictionary = _pending_ensnare_level_data
	var timber_chain_level_data: Dictionary = _pending_timber_chain_level_data
	var chakram_level_data: Dictionary = _pending_chakram_level_data
	var lil_shredder_level_data: Dictionary = _pending_lil_shredder_level_data
	var mortimer_kisses_level_data: Dictionary = _pending_mortimer_kisses_level_data
	var cold_feet_level_data: Dictionary = _pending_cold_feet_level_data
	var ice_vortex_level_data: Dictionary = _pending_ice_vortex_level_data
	var chilling_touch_level_data: Dictionary = _pending_chilling_touch_level_data
	var ice_blast_level_data: Dictionary = _pending_ice_blast_level_data
	var splinter_blast_level_data: Dictionary = _pending_splinter_blast_level_data
	var winters_curse_level_data: Dictionary = _pending_winters_curse_level_data
	var crystal_nova_level_data: Dictionary = _pending_crystal_nova_level_data
	var frostbite_level_data: Dictionary = _pending_frostbite_level_data
	var ice_shards_level_data: Dictionary = _pending_ice_shards_level_data
	var snowball_level_data: Dictionary = _pending_snowball_level_data
	var walrus_punch_level_data: Dictionary = _pending_walrus_punch_level_data
	var leech_seed_level_data: Dictionary = _pending_leech_seed_level_data
	_cancel_targeting()

	if purpose == "entangle":
		_resolve_entangle_cast(enemy, entangle_level_data)
	elif purpose == "mist_coil":
		_resolve_mist_coil_enemy_cast(enemy, mist_coil_level_data)
	elif purpose == "torrent":
		_resolve_torrent_cast(enemy, torrent_level_data)
	elif purpose == "x_marks_the_spot":
		_resolve_xmarks_cast(enemy, xmarks_level_data)
	elif purpose == "ghostship":
		_resolve_ghostship_cast(enemy, ghostship_level_data)
	elif purpose == "corrosive_haze":
		_resolve_corrosive_haze_cast(enemy, corrosive_haze_level_data)
	elif purpose == "sacred_arrow":
		_resolve_sacred_arrow_cast(enemy, sacred_arrow_level_data)
	elif purpose == "lucent_beam":
		_resolve_lucent_beam_cast(enemy, lucent_beam_level_data)
	elif purpose == "ensnare":
		_resolve_ensnare_cast(enemy, ensnare_level_data)
	elif purpose == "timber_chain":
		_resolve_timber_chain_cast(enemy, timber_chain_level_data)
	elif purpose == "chakram":
		_resolve_chakram_cast(enemy, chakram_level_data)
	elif purpose == "lil_shredder":
		_resolve_lil_shredder_cast(enemy, lil_shredder_level_data)
	elif purpose == "mortimer_kisses":
		_resolve_mortimer_kisses_cast(enemy, mortimer_kisses_level_data)
	elif purpose == "cold_feet":
		_resolve_cold_feet_cast(enemy, cold_feet_level_data)
	elif purpose == "ice_vortex":
		_resolve_ice_vortex_cast(enemy, ice_vortex_level_data)
	elif purpose == "chilling_touch":
		_resolve_chilling_touch_cast(enemy, chilling_touch_level_data)
	elif purpose == "ice_blast":
		_resolve_ice_blast_cast(enemy, ice_blast_level_data)
	elif purpose == "splinter_blast":
		_resolve_splinter_blast_cast(enemy, splinter_blast_level_data)
	elif purpose == "winter's_curse":
		_resolve_winters_curse_cast(enemy, winters_curse_level_data)
	elif purpose == "crystal_nova":
		_resolve_crystal_nova_cast(enemy, crystal_nova_level_data)
	elif purpose == "frostbite":
		_resolve_frostbite_cast(enemy, frostbite_level_data)
	elif purpose == "ice_shards":
		_resolve_ice_shards_cast(enemy, ice_shards_level_data)
	elif purpose == "snowball":
		_resolve_snowball_cast(enemy, snowball_level_data)
	elif purpose == "walrus_punch":
		_resolve_walrus_punch_cast(enemy, walrus_punch_level_data)
	elif purpose == "leech_seed":
		_resolve_leech_seed_cast(enemy, leech_seed_level_data)
	else:
		_apply_hero_attack(enemy)


func _on_hero_image_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_hero_image_clicked()


## Only meaningful while Mist Coil's targeting is open - clicking the
## hero's own portrait at any other time (or for any other skill) is a
## no-op, same as clicking a non-highlighted enemy while targeting.
func _on_hero_image_clicked() -> void:
	if not _targeting_mode or _battle_over or _has_acted_this_turn:
		return
	if _targeting_purpose != "mist_coil":
		return

	var level_data: Dictionary = _pending_mist_coil_level_data
	_resolve_mist_coil_self_cast(level_data)


func _apply_hero_attack(target: Dictionary) -> void:
	var generation_before: int = _stage_generation

	# If Slark is hidden, this Attack gets Shadow Dance's own bonus
	# damage folded straight into the roll (added to the min/max range
	# BEFORE rolling, so it goes through armor mitigation exactly like
	# the rest of the hit - see _roll_hero_damage()) and ends the
	# invisibility right here, whether or not the hit kills the target.
	var shadow_dance_bonus: float = _shadow_dance_bonus_damage if _shadow_dance_active else 0.0
	# Mirana's own Moonlight Shadow pays off the same way, just as a
	# PERCENTAGE of the attack's own rolled damage (folded in AFTER the
	# roll, below - same "post-roll percentage" shape Bash of the
	# Deep's own bonus uses) rather than Shadow Dance's flat pre-roll
	# bonus. Only one of the two could ever be active in a given battle
	# (different heroes' own kits), so this never double-counts either
	# way.
	var moonlight_shadow_active_bonus_pct: float = _moonlight_shadow_bonus_damage_pct if _moonlight_shadow_active else 0.0
	# Same idea for Nature's Guise, just with a root on the target
	# instead of bonus damage - captured now, before the attack (and
	# possibly _end_natures_guise()) below can change what _natures_
	# guise_active reads.
	var attacking_from_natures_guise: bool = _natures_guise_active
	# Tidebringer counts this Attack toward its own threshold - once
	# reached, THIS hit's roll gets its bonus damage folded in below
	# (so the cleave that follows is based on the same empowered
	# total), same as Shadow Dance's own one-shot bonus above.
	var tidebringer_level_data: Dictionary = _maybe_consume_tidebringer_stack()
	var tidebringer_bonus: float = float(tidebringer_level_data.get("bonus_damage", 0.0))
	# Bash of the Deep counts this Attack toward its own threshold too,
	# same idea as Tidebringer's stack just above - once reached, this
	# hit's own damage is boosted by a PERCENTAGE of itself (folded in
	# below, after the roll - unlike Tidebringer's flat pre-roll bonus),
	# and the target gets knocked back afterward (see
	# _apply_bash_of_the_deep_knockback(), called once the target's
	# final position actually matters again, after every cleave above
	# that reads it has already resolved).
	var bash_level_data: Dictionary = _maybe_consume_bash_of_the_deep_stack()

	var attack_damage: float = _roll_hero_damage(shadow_dance_bonus + tidebringer_bonus)
	if moonlight_shadow_active_bonus_pct > 0.0:
		attack_damage += attack_damage * moonlight_shadow_active_bonus_pct
	if not bash_level_data.is_empty():
		attack_damage += attack_damage * float(bash_level_data.get("bonus_damage_pct", 0.0))
	var mitigated_damage: float = _deal_fixed_damage_to_enemy(target, attack_damage)
	_apply_essence_shift_steal(target)
	# Arctic Burn's bonus_damage is already folded into the roll above
	# (see _roll_hero_damage()) - this just spends one of its banked
	# Attacks, ending the effect once the last one is used.
	_apply_arctic_burn_attack()
	# Lifesteal only ever applies to this plain Attack action - never
	# to skill damage (Pounce, Dark Pact, Entangle's DoT, etc.) - and
	# uses the damage actually dealt, i.e. after the target's armor
	# has already reduced it.
	_apply_spirit_link_lifesteal(mitigated_damage, target)
	# Morbid Mask's own lifesteal - independent of and stacks with
	# Spirit Link's above.
	_apply_morbid_mask_lifesteal(mitigated_damage)
	# Curse of Avernus stacks the same way - only this plain Attack
	# action builds toward it, never skill damage.
	_apply_curse_of_avernus_stack(target)

	if not tidebringer_level_data.is_empty():
		_apply_tidebringer_cleave(target, attack_damage, tidebringer_level_data)

	# Cleaver's own cleave - a no-op unless the item is actually owned
	# (see _apply_cleaver_cleave()'s own gate). Independent of
	# Tidebringer's: both can splash off the same Attack if the player
	# has both.
	_apply_cleaver_cleave(target, attack_damage)

	# Rip Tide's own AoE splash - a no-op unless the skill is learned
	# (see _apply_rip_tide_cleave()'s own gate). Independent of and
	# stacks with Tidebringer's/Cleaver's above.
	_apply_rip_tide_cleave(target, attack_damage)

	# Moon Glaives' own bounce - a no-op unless the skill is learned
	# (see _apply_moon_glaives_bounces()'s own gate). Independent of and
	# stacks with Tidebringer's/Cleaver's/Rip Tide's above.
	_apply_moon_glaives_bounces(target, attack_damage)

	# Bash of the Deep's own knockback - after every cleave above that
	# reads target["pos_index"] as ITS OWN splash center, so none of
	# them end up centered on where the target gets shoved to instead
	# of where it actually stood when hit. A no-op unless this attack
	# is the one that triggered the stack (see
	# _maybe_consume_bash_of_the_deep_stack()). If the hit actually
	# landed on one of the boss's own illusions instead of the boss
	# itself (Naga Siren's Mirror Image redirect, see
	# _deal_fixed_damage_to_enemy()'s own comment), knock THAT back
	# instead - "target" never took the hit at all this time, so
	# shoving it would move something the attack never touched.
	if not bash_level_data.is_empty():
		if not _last_enemy_illusion_redirect.is_empty():
			if _last_enemy_illusion_redirect.get("current_hp", 0) > 0:
				_apply_bash_of_the_deep_illusion_knockback(_last_enemy_illusion_redirect, bash_level_data)
		elif target.get("current_hp", 0) > 0:
			_apply_bash_of_the_deep_knockback(target, bash_level_data)

	if shadow_dance_bonus > 0.0:
		_end_shadow_dance()
	elif moonlight_shadow_active_bonus_pct > 0.0:
		_end_moonlight_shadow()

	if attacking_from_natures_guise:
		if target.get("current_hp", 0) > 0:
			target["root_turns_left"] = _natures_guise_root_turns
		_end_natures_guise()

	# If that kill cleared the stage (or won a hero fight) and a fresh
	# encounter started, the turn lock has already been reset for it -
	# re-locking it here would carry the old turn's "used" state into
	# an encounter that hasn't had a turn yet.
	if _battle_over or _stage_generation != generation_before:
		return

	_mark_turn_used()


## Rolls hero damage, applies the target's armor mitigation, subtracts
## it from the target's HP, and kills it if that brings it to 0.
## Shared by Pounce and other skills that deal a standard attack as
## part of their effect but shouldn't duplicate the turn-flag/button
## bookkeeping (the plain Attack button goes through
## _apply_hero_attack() directly instead, since it also needs to fold
## in Shadow Dance's one-shot bonus damage).
## Rolls hero damage and applies it to a single target via
## _deal_fixed_damage_to_enemy. Used by the plain Attack button and by
## skills (like Pounce) that deal exactly one standard attack.
func _deal_damage_to_enemy(target: Dictionary) -> void:
	_deal_fixed_damage_to_enemy(target, _roll_hero_damage())


## Applies an already-determined damage amount to one target (still
## mitigated by that target's own armor) and kills it if that brings
## it to 0. Shared by _deal_damage_to_enemy (single rolled hit),
## Dark Pact (one rolled amount split across every enemy in range),
## and Entangle's DoT. Returns the mitigated damage actually dealt, so
## callers that need it (Spirit Link's lifesteal, via
## _apply_hero_attack()) don't have to re-derive it.
## For a hero-fight boss, this also doubles as the enemy-side mirror of
## the player's own apply_damage(): Borrowed Time reverses the hit into
## a heal, and failing that, Aphotic Shield absorbs it into its own HP
## pool first - same redirection order as the player's copy, just
## checked here since every source of damage to an enemy (attacks,
## Dark Pact, DoTs) already funnels through this one function.
## `is_critical` just forwards to _show_damage_number()'s own bigger-
## and-golden-with-a-"!" treatment (see Walrus Punch's own
## _resolve_walrus_punch_cast()) - it has no effect on the damage math
## itself, only how the number reads. `is_hero_action` gates Slardar's
## own Corrosive Haze bonus (see below) - true for every hero attack/
## skill call site (the overwhelming majority, so it defaults true),
## false only at the handful of calls that AREN'T the hero's own doing:
## a DoT tick (_tick_enemy_turn_start_effects()), the Spirit Bear's own
## attack (_bear_turn()), and another creep piling onto a Winter's
## Curse target (_enemy_turn()'s own curse redirect).
func _deal_fixed_damage_to_enemy(target: Dictionary, amount: float, is_critical: bool = false, is_hero_action: bool = true) -> float:
	# Slardar's Corrosive Haze: boosts every hit THIS specific marked
	# target takes from the hero's own attacks/skills by this level's
	# own bonus_damage_pct - applied to the RAW amount, before armor
	# mitigation and before Mirror Image's own redirect just below, so
	# a hit that ends up landing on one of the boss's own illusions
	# instead still carries the mark's bonus (the mark is about how
	# fragile the TARGET is, not about whatever ends up absorbing the
	# hit).
	if is_hero_action:
		var vulnerability_pct: float = float(target.get("corrosive_haze_bonus_pct", 0.0))
		if vulnerability_pct > 0.0:
			amount *= (1.0 + vulnerability_pct)

	var is_boss: bool = target["static"].get("is_hero_fight_boss", false)

	# Reset on every call, whoever it's for - _apply_hero_attack() reads
	# this right after its own call here to tell "the boss actually took
	# it" apart from "it got redirected onto an illusion instead" (see
	# that function's own Bash of the Deep knockback comment), so a
	# stale value from some EARLIER, unrelated call must never survive
	# to be misread as this one's outcome.
	_last_enemy_illusion_redirect = {}

	# Naga Siren's Mirror Image, cast by the rival - every hit that would
	# otherwise land on the boss has a chance to be redirected onto a
	# random surviving illusion instead, mirroring the player's own
	# apply_damage() redirect (see that function's own comment) - a full
	# redirect, not a split, bypassing Reactive Armor's stack/Savage
	# Roar/Borrowed Time/Aphotic Shield since nothing actually touched
	# the boss this time. Uses the boss's own armor for mitigation, same
	# as if it had taken the hit itself.
	if is_boss and not _enemy_illusions.is_empty() and randf() < _enemy_illusion_hit_chance_pct:
		var illusion: Dictionary = _enemy_illusions[randi() % _enemy_illusions.size()]
		var illusion_damage: float = _apply_armor_reduction(amount, _enemy_hero_effective_armor(target))
		_deal_damage_to_enemy_illusion(illusion, illusion_damage, is_critical)
		_last_enemy_illusion_redirect = illusion
		return illusion_damage

	# Snapfire's Lil' Shredder is the only thing that ever writes
	# "armor_reduction" (see _resolve_lil_shredder_cast()/
	# _tick_enemy_turn_start_effects()'s own revert) - a per-INSTANCE
	# runtime field on this one spawned enemy, never on target["static"]
	# itself, since that dictionary can be shared across every enemy
	# spawned from the same zone template (mutating it would debuff
	# every enemy of that type, not just this one).
	var enemy_armor: float = float(target["static"].get("armor", 0)) + _enemy_hero_bonus_armor(target) - float(target.get("armor_reduction", 0.0))
	var mitigated: float = _apply_armor_reduction(amount, enemy_armor)
	if is_boss:
		mitigated *= (1.0 - _enemy_savage_roar_damage_reduction_pct)

	if is_boss and _enemy_cold_embrace_active:
		# Full immunity, same as the player's own apply_damage() check -
		# no absorption pool to track the way Aphotic Shield has, the
		# hit just never happens.
		return mitigated

	if is_boss:
		# Timbersaw's Reactive Armor stacks off of this hit landing -
		# added only after enemy_armor above already read the stack
		# count, so the stack this hit just earned reduces the NEXT hit,
		# not this one, mirroring the player's own apply_damage(). A
		# no-op for every other hero (see _apply_enemy_reactive_armor_
		# stack()'s own "not learned" check).
		_apply_enemy_reactive_armor_stack()

	if is_boss and _enemy_borrowed_time_active:
		var max_hp: float = _enemy_hero_effective_max_hp(target)
		target["current_hp"] = minf(max_hp, target["current_hp"] + mitigated * _enemy_borrowed_time_heal_conversion_pct)
		return mitigated

	if is_boss and _enemy_aphotic_shield_active:
		var absorbed: float = minf(mitigated, _enemy_aphotic_shield_hp)
		_enemy_aphotic_shield_hp -= absorbed
		var overflow: float = mitigated - absorbed
		if overflow > 0.0:
			target["current_hp"] -= overflow
			_show_damage_number(target["node"], overflow, is_critical)
		if _enemy_aphotic_shield_hp <= 0.0:
			_end_enemy_aphotic_shield(true)
		elif absorbed > 0.0:
			_update_aphotic_shell(target.get("node"), _enemy_aphotic_shield_hp)
		if target["current_hp"] <= 0:
			_kill_enemy(target)
		else:
			_maybe_auto_activate_enemy_borrowed_time(target)
		return mitigated

	target["current_hp"] -= mitigated
	_show_damage_number(target["node"], mitigated, is_critical)

	if target["current_hp"] <= 0:
		_kill_enemy(target)
	elif is_boss:
		_maybe_auto_activate_enemy_borrowed_time(target)

	return mitigated


## A rival hero's own Essence Shift/Spirit Link armor bonuses, folded
## into the armor the player's damage has to punch through - the enemy-
## side mirror of _hero_armor()'s own borrowed-armor terms. 0 for
## anything that isn't the actual boss (a regular creep, or the boss's
## own summoned Spirit Bear ally).
func _enemy_hero_bonus_armor(target: Dictionary) -> float:
	if not target["static"].get("is_hero_fight_boss", false):
		return 0.0
	return _enemy_essence_shift_bonus.get("armor", 0.0) + _enemy_spirit_link_bonus_armor + _enemy_living_armor_bonus_armor + _enemy_reactive_armor_bonus_armor()


## The enemy to actually hit for whatever's on `pos_index` - the
## lowest-HP living, targetable one there, matching EnemyHeroManager.gd's
## own _lowest_hp_enemy() convention for its background simulation (so
## a real hero fight and its simulated equivalent make the same call).
## Ties keep whichever comes first in _enemies (stable, arbitrary but
## consistent). Used for every "whatever's on this column" resolution -
## a melee Attack, the bear's own attack, Pounce's leap, and (via
## _on_enemy_clicked()'s own redirect) every ranged-click skill cast
## too - so stacking two weak creeps in one column can't be used to
## soak hits meant for a low-HP kill target hiding behind them.
func _get_enemy_at(pos_index: int) -> Dictionary:
	var lowest: Dictionary = {}
	for enemy in _enemies:
		if enemy["pos_index"] != pos_index or _is_target_hidden(enemy):
			continue
		if lowest.is_empty() or float(enemy.get("current_hp", 0)) < float(lowest.get("current_hp", 0)):
			lowest = enemy
	return lowest


## True for the rival hero currently hidden by their own Shadow Dance or
## Nature's Guise - the player can't select, attack, or target them with
## a skill while this holds (see _get_enemy_at(), _start_ranged_
## targeting(), _start_entangle_targeting(), _cast_dark_pact()), exactly
## mirroring what the player's own Shadow Dance/Nature's Guise does to
## him in _enemy_turn() (both folded into his own _is_hero_hidden()).
## Slardar's Corrosive Haze overrides this for whichever enemy it's
## currently marked (target["corrosive_haze_bonus_pct"] > 0, the same
## per-instance field _resolve_corrosive_haze_cast() writes and _deal_
## fixed_damage_to_enemy() reads for its own damage bonus, both sharing
## armor_reduction_turns_left's own countdown) - true sight lets Slardar
## keep attacking it, targeting it with a skill, or catching it in an
## AoE for as long as the mark holds, stealth notwithstanding. Since
## this function is the single choke point literally every one of those
## call sites already checks, that one override covers all of them for
## free - no per-skill changes needed.
func _is_target_hidden(target: Dictionary) -> bool:
	if float(target.get("corrosive_haze_bonus_pct", 0.0)) > 0.0:
		return false
	return target["static"].get("is_hero_fight_boss", false) and (_enemy_shadow_dance_active or _enemy_natures_guise_active or _enemy_moonlight_shadow_active)


## Rolls a hero attack's damage, adding Essence Shift's ongoing
## borrowed damage, True Form's bonus damage, Winter Wyvern's Arctic
## Burn bonus damage, and Tusk's Tag Team bonus damage (while each is
## active) plus (for the single hit that triggers it) Shadow Dance's
## one-shot `extra_bonus`, before mitigation. Luna's Lunar Blessing then
## scales the resulting total by its own bonus_damage_pct, same as a
## permanent stat-derived damage bonus would.
func _roll_hero_damage(extra_bonus: float = 0.0) -> float:
	var stats: Dictionary = _recruited.get("stats", {})
	var damage_str: String = str(stats.get("damage", "0-0"))
	var parts: PackedStringArray = damage_str.split("-")
	var min_dmg: float = float(parts[0]) if parts.size() > 0 else 0.0
	var max_dmg: float = float(parts[1]) if parts.size() > 1 else min_dmg

	# Essence Shift's borrowed damage, True Form's bonus damage, Arctic
	# Burn's bonus damage, and Tag Team's bonus damage (while each is
	# active) apply on top of both ends of the roll, same as a permanent
	# damage bonus would - Shadow Dance's bonus (passed in by the
	# caller, only for the specific hit that triggers it) stacks on top
	# of that the same way.
	var bonus_damage: float = _essence_shift_bonus.get("damage", 0.0) + _true_form_bonus_damage + _arctic_burn_bonus_damage + _tag_team_bonus_damage + extra_bonus - _player_essence_shift_penalty.get("damage", 0.0)
	min_dmg += bonus_damage
	max_dmg += bonus_damage

	# Lunar Blessing - read fresh off the player's current level every
	# roll (see _get_lunar_blessing_level_data()) rather than tracked in
	# a field, since it's never toggled on/off like Shadow Dance/Arctic
	# Burn/Tag Team above, just always-on once learned. Applied last so
	# it scales the whole roll (base weapon damage plus every flat bonus
	# above), not just the hero's own base stat.
	var lunar_blessing_bonus_pct: float = float(_get_lunar_blessing_level_data().get("bonus_damage_pct", 0.0))
	if lunar_blessing_bonus_pct > 0.0:
		min_dmg += min_dmg * lunar_blessing_bonus_pct
		max_dmg += max_dmg * lunar_blessing_bonus_pct

	return randi_range(int(min_dmg), int(max_dmg))


## `is_critical` (Walrus Punch's own multiplied hit - see
## _resolve_walrus_punch_cast()) renders bigger, in gold instead of the
## usual red, with a trailing "!" - the same "stands out from a normal
## hit" treatment a critical usually gets, layered on top of the plain
## damage-number styling below rather than replacing it outright.
func _show_damage_number(target_node: Control, amount: float, is_critical: bool = false) -> void:
	var label := Label.new()
	label.text = str(int(amount)) + ("!" if is_critical else "")
	label.add_theme_color_override("font_color", Color(1, 0.75, 0.1, 1) if is_critical else Color(1, 0.15, 0.15, 1))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_font_size_override("font_size", 36 if is_critical else 24)
	label.position = target_node.position + Vector2(target_node.size.x / 2.0 - 15, -10)
	enemies_layer.add_child(label)

	var tween := create_tween()
	tween.tween_property(label, "position:y", label.position.y - 40, 0.8)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.8)
	tween.finished.connect(label.queue_free)


## Same floating/fading style as _show_damage_number, but for text
## (e.g. "No enemy in range") shown over the hero instead of a number
## over an enemy. Holds still and fully readable for
## MESSAGE_READ_HOLD_DURATION before it starts floating up and fading -
## it used to start doing both the instant it appeared, which barely
## gave the player time to read it before it was gone.
func _show_message_over_hero(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", Color(1, 0.15, 0.15, 1))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_font_size_override("font_size", 18)
	label.position = hero_image.position + Vector2(hero_image.size.x / 2.0 - 70, -10)
	add_child(label)

	var tween := create_tween()
	tween.tween_interval(MESSAGE_READ_HOLD_DURATION)
	tween.tween_property(label, "position:y", label.position.y - 40, 0.8)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.8)
	tween.finished.connect(label.queue_free)


## A callout that floats up from the moment it appears instead of
## holding still first like _show_message_over_hero() - rising ~70px
## over 1.4s, fading out over the last part of the climb - over `node`
## (the hero_image or an enemy's node), in `color`. Used for passive
## procs like Tidebringer's, where the text is flavor that doesn't need
## a still, readable hold.
func _show_rising_message_over(node: Control, text: String, color: Color) -> void:
	if not is_instance_valid(node):
		return

	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", TIDEBRINGER_TEXT_OUTLINE_COLOR)
	label.add_theme_constant_override("outline_size", 5)
	label.add_theme_font_size_override("font_size", 20)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.position = node.position + Vector2(node.size.x / 2.0 - 70, -10)
	add_child(label)

	var tween := create_tween()
	tween.tween_property(label, "position:y", label.position.y - 70, 1.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.6).set_delay(0.8)
	tween.finished.connect(label.queue_free)


func _kill_enemy(enemy: Dictionary) -> void:
	var xp_gain: float = float(enemy["static"].get("XP", 0))
	gain_xp(xp_gain)

	var gold_gain: int = _roll_enemy_gold(enemy["static"])
	PlayerManager.add_gold(gold_gain)
	_refresh_gold_label()
	_show_gold_gain(enemy["node"], gold_gain)

	enemy["node"].queue_free()
	if enemy.get("hp_label") != null:
		enemy["hp_label"].queue_free()
	if enemy.get("status_label") != null:
		enemy["status_label"].queue_free()
	_enemies.erase(enemy)
	_refresh_enemy_overhead_labels()

	if _enemies.is_empty():
		_handle_victory()


## Parses an enemy's "gold" field ("34-39") the same way hero damage
## is rolled from a "min-max" string, returning a random amount in
## that range. Missing/malformed fields just yield 0.
func _roll_enemy_gold(enemy_static: Dictionary) -> int:
	var gold_str: String = str(enemy_static.get("gold", "0"))
	var parts: PackedStringArray = gold_str.split("-")
	var min_gold: int = int(parts[0]) if parts.size() > 0 else 0
	var max_gold: int = int(parts[1]) if parts.size() > 1 else min_gold
	return randi_range(min_gold, max_gold)


## Same floating/fading style as _show_damage_number, but in gold for
## the amount of gold just earned from a kill.
func _show_gold_gain(target_node: Control, amount: int) -> void:
	var label := Label.new()
	label.text = "+%d gold" % amount
	label.add_theme_color_override("font_color", Color(1, 0.85, 0.2, 1))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_font_size_override("font_size", 18)
	label.position = target_node.position + Vector2(target_node.size.x / 2.0 - 30, 10)
	enemies_layer.add_child(label)

	var tween := create_tween()
	tween.tween_property(label, "position:y", label.position.y - 40, 0.9)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.9)
	tween.finished.connect(label.queue_free)


## Clearing a non-final stage reloads the next stage's enemies in this
## same Battle scene instance rather than returning to the Map. Only
## clearing the final stage counts as actually winning the zone - and
## if that's reached without ever fleeing in between (nothing resets
## _current_stage except leaving the scene), the zone is marked fully
## cleared so it always reopens on the final stage from now on.
## Clearing a non-final stage reloads the next stage's enemies in this
## same Battle scene instance rather than returning to the Map.
## Clearing the final stage tries to start a hero fight (see
## _try_start_hero_fight()) before actually finishing the zone;
## winning that hero fight (_in_hero_fight was true when the last
## enemy died) marks it defeated and then finishes for real.
func _handle_victory() -> void:
	# Tutorial stage 1 ends here rather than rolling into the zone's own
	# stage 2 - the next tutorial stage is a separately scripted scenario
	# (Kunkka at level 5, mid-fight, low on resources - not a straight
	# continuation of this fight), so it needs its own checkpoint instead
	# of _advance_to_next_stage()'s normal handoff.
	if TutorialManager.is_active and TutorialManager.current_stage == 1 and _current_stage == 1:
		_advance_tutorial_stage1_step("stage_cleared")
		return

	# Tutorial stage 3 is the closing scenario - ends the whole tutorial
	# here with its own closing popup rather than falling through to a
	# real hero-fight/zone-finished flow the sandbox was never set up
	# for (no NPC rivals exist in it - see PlayerManager.
	# clear_recruited_hero()'s npc_* wipe).
	if TutorialManager.is_active and TutorialManager.current_stage == 3:
		_advance_tutorial_stage3_step("zone_cleared")
		return

	if _in_hero_fight:
		PlayerManager.mark_hero_defeated(_hero_fight_target_id)
		_in_hero_fight = false
		_finish_zone_victory()
		return

	if _current_stage < GameManager.MAX_ZONE_STAGE:
		_advance_to_next_stage()
		return

	if _try_start_hero_fight():
		return

	_finish_zone_victory()


func _finish_zone_victory() -> void:
	PlayerManager.set_zone_cleared(GameManager.selected_zone)

	_battle_over = true
	_update_action_buttons()
	PlayerManager.record_high_score()
	get_tree().change_scene_to_file("res://scenes/Map.tscn")


## Moves on to the next wave without leaving the Battle scene: hero
## HP/mana/skill cooldowns carry over as-is (no free heal between
## stages), but position, turn count, and the per-turn action lock
## reset like a fresh encounter.
func _advance_to_next_stage() -> void:
	_current_stage += 1
	_stage_generation += 1
	_update_stage_label()
	_show_message_over_hero("Stage %d!" % _current_stage)

	_cancel_targeting()
	_hero_pos_index = 1
	_update_hero_position()

	_turn_count = 0
	_next_reinforcement_turn = REINFORCEMENT_INTERVAL
	_has_acted_this_turn = false

	_load_enemies()
	_update_action_buttons()


## If this zone still has an undefeated rival hero available, starts a
## fight against a random one of them and returns true. Otherwise
## returns false and leaves the battle unaffected, so the caller can
## fall through to actually finishing the zone.
## The player's own home zone holds its zone-mate fight back on the
## FIRST clear specifically - that run is meant to introduce the zone
## itself, not immediately throw a boss-tier rival at someone who just
## finished their very first playthrough of it. Every other zone (and
## the home zone's own second-and-later clears) still tries the fight
## the normal way. PlayerManager.is_zone_cleared() only flips true once
## _finish_zone_victory() runs - right after this returns false and the
## caller (_handle_victory()) falls through to it - so checking it HERE,
## before that happens, is exactly "has this zone ever been cleared
## before THIS victory."
func _try_start_hero_fight() -> bool:
	var own_hero_id: String = _recruited.get("id", "")
	var is_own_home_zone: bool = GameManager.selected_zone == GameManager.get_zone_id_for_hero(own_hero_id)
	if is_own_home_zone and not PlayerManager.is_zone_cleared(GameManager.selected_zone):
		return false

	var eligible: Array = _get_eligible_hero_fight_heroes()
	if eligible.is_empty():
		return false

	_start_hero_fight(eligible[randi() % eligible.size()])
	return true


## Every hero in this zone that's fair game for a hero fight right
## now: if this is the player's own recruited hero's home zone, their
## own hero is excluded (fighting themselves makes no sense) but any
## OTHER hero recruited from that same zone still counts; in a zone
## that isn't their own, every hero in it is eligible. Either way,
## anyone already marked defeated (PlayerManager.mark_hero_defeated)
## is excluded, so the same hero is never offered for a rematch.
func _get_eligible_hero_fight_heroes() -> Array:
	var heroes: Array = GameManager.get_selected_zone().get("heroes", [])
	if heroes.is_empty():
		return []

	var own_hero_id: String = _recruited.get("id", "")
	var is_own_zone: bool = GameManager.selected_zone == GameManager.get_zone_id_for_hero(own_hero_id)

	var eligible: Array = []
	for hero in heroes:
		var hero_id: String = hero.get("id", "")
		if is_own_zone and hero_id == own_hero_id:
			continue
		if PlayerManager.is_hero_defeated(hero_id):
			continue
		eligible.append(hero)

	return eligible


## Starts a one-enemy fight against a rival hero: same fresh-encounter
## reset as advancing a stage (position, turn count, action lock), but
## _current_stage itself doesn't change - see _in_hero_fight.
func _start_hero_fight(hero_static: Dictionary) -> void:
	_in_hero_fight = true
	_hero_fight_target_id = hero_static.get("id", "")
	_stage_generation += 1

	_update_stage_label()
	_show_message_over_hero("%s challenges you!" % hero_static.get("name", "A rival hero"))

	_cancel_targeting()
	_hero_pos_index = 1
	_update_hero_position()

	_turn_count = 0
	_next_reinforcement_turn = REINFORCEMENT_INTERVAL
	_has_acted_this_turn = false

	for child in enemies_layer.get_children():
		child.queue_free()
	_enemies.clear()

	_reset_enemy_hero_state(hero_static)
	_spawn_enemy(GameManager.build_hero_fight_enemy_def(hero_static))

	_update_action_buttons()


## Fresh state for a newly-challenged rival hero's own skills, and for
## whatever they might have inflicted on the player in a PREVIOUS hero
## fight this scene - none of it should leak from one rival to the
## next (or from a hero fight into the zone's regular stages, though
## _current_stage staying at MAX_ZONE_STAGE throughout a hero fight
## means this is only ever called right before one starts anyway).
func _reset_enemy_hero_state(hero_static: Dictionary) -> void:
	_enemy_hero_static = hero_static
	_enemy_hero_id = hero_static.get("id", "")
	_enemy_skill_cooldowns.clear()

	_enemy_essence_shift_active = false
	_enemy_essence_shift_attacks_remaining = 0
	_enemy_essence_shift_turns_remaining = 0
	_enemy_essence_shift_duration_pending_start = false
	_enemy_essence_shift_bonus = {"damage": 0.0, "hp": 0.0, "mana": 0.0, "armor": 0.0}

	_enemy_shadow_dance_active = false
	_enemy_shadow_dance_bonus_damage = 0.0
	_enemy_shadow_dance_turns_remaining = 0
	_enemy_shadow_dance_duration_pending_start = false

	_enemy_spirit_link_active = false
	_enemy_spirit_link_lifesteal_pct = 0.0
	_enemy_spirit_link_bonus_armor = 0.0
	_enemy_spirit_link_turns_remaining = 0
	_enemy_spirit_link_duration_pending_start = false
	_set_spirit_link_visual(_get_hero_fight_boss().get("node"), false)

	_enemy_true_form_active = false
	_enemy_true_form_bonus_hp = 0.0
	_enemy_true_form_bonus_damage = 0.0
	_enemy_true_form_turns_remaining = 0
	_enemy_true_form_duration_pending_start = false

	_enemy_savage_roar_active = false
	_enemy_savage_roar_damage_reduction_pct = 0.0

	_enemy_aphotic_shield_active = false
	_enemy_aphotic_shield_hp = 0.0
	_enemy_aphotic_shield_aoe_damage = 0.0
	_enemy_aphotic_shield_radius = 0
	_enemy_aphotic_shield_turns_remaining = 0
	_enemy_aphotic_shield_duration_pending_start = false
	_remove_aphotic_shell(_get_hero_fight_boss().get("node"), false, 0)

	_enemy_borrowed_time_active = false
	_enemy_borrowed_time_heal_conversion_pct = 0.0
	_enemy_borrowed_time_turns_remaining = 0
	_enemy_borrowed_time_duration_pending_start = false
	_set_borrowed_time_visual(_get_hero_fight_boss().get("node"), false)

	_enemy_tidebringer_attack_count = 0
	_enemy_xmarks_pending = false

	_enemy_arctic_burn_active = false
	_enemy_arctic_burn_bonus_damage = 0.0
	_enemy_arctic_burn_bonus_range = 0
	_enemy_arctic_burn_attacks_remaining = 0
	_enemy_arctic_burn_turns_remaining = 0
	_enemy_arctic_burn_duration_pending_start = false

	_enemy_cold_embrace_active = false
	_enemy_cold_embrace_heal_per_turn = 0.0
	_enemy_cold_embrace_turns_remaining = 0
	_enemy_cold_embrace_duration_pending_start = false

	_enemy_freezing_field_active = false
	_enemy_freezing_field_damage_per_turn = 0.0
	_enemy_freezing_field_radius = 0
	_enemy_freezing_field_turns_remaining = 0
	_enemy_freezing_field_duration_pending_start = false

	_enemy_ice_shards_active = false
	_enemy_ice_shards_blocked_columns = []
	_enemy_ice_shards_turns_remaining = 0
	_enemy_ice_shards_duration_pending_start = false
	_refresh_ice_shards_visuals()

	_enemy_tag_team_active = false
	_enemy_tag_team_bonus_damage = 0.0
	_enemy_tag_team_turns_remaining = 0
	_enemy_tag_team_duration_pending_start = false

	_enemy_natures_guise_active = false
	_enemy_natures_guise_root_turns = 0
	_enemy_natures_guise_turns_remaining = 0
	_enemy_natures_guise_duration_pending_start = false

	_enemy_living_armor_active = false
	_enemy_living_armor_bonus_armor = 0.0
	_enemy_living_armor_bonus_hp_regen = 0.0
	_enemy_living_armor_turns_remaining = 0
	_enemy_living_armor_duration_pending_start = false

	_enemy_reactive_armor_stack_turns = []
	_despawn_enemy_chakram()

	_enemy_mortimer_kisses_active = false
	_enemy_mortimer_kisses_turns_left = 0
	_enemy_mortimer_kisses_level_data = {}

	_end_enemy_mirror_image()

	var stats: Dictionary = hero_static.get("stats", {})
	_enemy_max_mana = float(stats.get("mana", 0))
	_enemy_current_mana = _enemy_max_mana

	_enemy_potion_health_count = PlayerManager.get_npc_potion_count(_enemy_hero_id, "health")
	_enemy_potion_mana_count = PlayerManager.get_npc_potion_count(_enemy_hero_id, "mana")

	_player_essence_shift_penalty = {"damage": 0.0, "hp": 0.0, "mana": 0.0, "armor": 0.0}
	_player_root_turns_left = 0
	_player_silence_turns_left = 0
	_player_entangle_dot_damage = 0.0
	_player_entangle_dot_turns_left = 0
	_player_stun_turns_left = 0
	_player_winters_curse_active = false
	_player_curse_stacks = 0
	_player_curse_active = false
	_player_curse_dot_damage = 0.0
	_player_curse_dot_turns_left = 0
	_player_curse_last_hit_turn = 0
	_player_cold_feet_dot_damage = 0.0
	_player_cold_feet_dot_turns_left = 0
	_player_ice_vortex_dot_damage = 0.0
	_player_ice_vortex_dot_turns_left = 0
	_player_ice_blast_dot_damage = 0.0
	_player_ice_blast_dot_turns_left = 0
	_player_ice_blast_execute_pct = 0.0
	_player_frostbite_dot_damage = 0.0
	_player_frostbite_dot_turns_left = 0
	_player_leech_seed_dot_damage = 0.0
	_player_leech_seed_heal_per_turn = 0.0
	_player_leech_seed_dot_turns_left = 0
	_player_overgrowth_dot_damage = 0.0
	_player_overgrowth_dot_turns_left = 0
	_player_armor_reduction = 0.0
	_player_armor_reduction_turns_left = 0
	_player_corrosive_haze_bonus_pct = 0.0
	_player_mortimer_burn_dot_damage = 0.0
	_player_mortimer_burn_dot_turns_left = 0

	_end_enemy_guardian_sprint()
	_enemy_bash_of_the_deep_attack_count = 0
	_end_enemy_moonlight_shadow()
	_end_enemy_eclipse()


func _update_stage_label() -> void:
	if _in_hero_fight:
		stage_label.text = "Hero Fight!"
	else:
		stage_label.text = "Stage %d/%d" % [_current_stage, GameManager.MAX_ZONE_STAGE]


# ------------------------------------------------------------------
# End of turn: the hero only gets one action (move, attack, skill, or
# item) per turn, so as soon as one resolves, the turn ends on its
# own - no End Turn button to press. Range enemies then attack every
# turn; melee enemies attack only if sharing the hero's column,
# otherwise take one step toward the hero. Then the turn's
# move/attack allowance resets.
# ------------------------------------------------------------------

## Locks the action buttons and, after a brief pause so the player can
## see the result of their action (damage numbers, messages, etc.),
## triggers the enemies' turn automatically. Bails out first if the
## action that just called this (an attack or skill cast can kill the
## last enemy outright, same as a DoT tick can - see _kill_enemy()/
## _handle_victory()) already resolved the battle: _handle_victory()/
## _handle_defeat() may already have changed scene by this point (see
## _finish_zone_victory()), and scheduling a timer into _end_turn()
## regardless would risk it firing after this node's been removed from
## the tree entirely, crashing on a null get_tree() the same way an
## unguarded _end_turn() could (see that function's own _battle_over
## check right after _tick_skill_cooldowns()).
func _mark_turn_used() -> void:
	if _battle_over:
		return
	_has_acted_this_turn = true
	_update_action_buttons()
	get_tree().create_timer(0.9).timeout.connect(_end_turn)


func _end_turn() -> void:
	if _battle_over:
		return

	_cancel_targeting()
	_bear_turn()
	_enemy_turn()

	if _recruited.get("current_hp", 0) <= 0:
		_handle_defeat()
		return

	_turn_count += 1
	if _turn_count >= _next_reinforcement_turn and not _enemies.is_empty():
		_spawn_reinforcements()
		_next_reinforcement_turn += REINFORCEMENT_REPEAT_INTERVAL

	_tick_skill_cooldowns()

	# A rival's own buff tick inside _tick_skill_cooldowns() above (e.g.
	# Freezing Field, if it ever damages its own caster) could in
	# principle finish either side off outside the normal attack/skill/
	# enemy-turn paths already checked earlier in this function, so this
	# still needs its own defeat check. A kill can just as easily finish
	# off the LAST enemy instead - _kill_enemy() already calls
	# _handle_victory() for that on its own, which can set _battle_over
	# and change scene outright (see _finish_zone_victory()) - so THIS
	# needs its own bail-out too: without it, a hero fight the boss just
	# lost would fall through to the stun/Cold Embrace check at the tail
	# of this function and schedule another _end_turn() call via
	# get_tree().create_timer() - a timer that fires after this node has
	# already been removed from the tree by that scene change, crashing
	# on a null get_tree().
	if _battle_over:
		return
	if _recruited.get("current_hp", 0) <= 0:
		_handle_defeat()
		return

	if _player_stun_turns_left > 0:
		_player_stun_turns_left -= 1
		if _player_stun_turns_left <= 0:
			_player_winters_curse_active = false

	# Every DoT/root/silence/execute effect a rival hero could have
	# inflicted on the player lands right here, at the very start of his
	# own new turn - before he gets to act - same reasoning as the
	# enemy-side version (_tick_enemy_turn_start_effects(), ticked from
	# _enemy_turn() instead). Unlike that version, a kill here can't
	# free any nodes or change scenes on its own, so a plain HP check
	# right after is enough - no bail-out needed mid-function.
	_tick_player_turn_start_effects()
	if _recruited.get("current_hp", 0) <= 0:
		_handle_defeat()
		return

	# The hero's new turn is opening right here - if X Marks the Spot
	# marked something last turn, this is "his next turn", so he
	# teleports now, for free (see _resolve_xmarks_teleport() - it
	# never spends the turn this function is about to reopen below).
	_resolve_xmarks_teleport()

	# Arcane Aura regenerates mana at the start of every hero turn,
	# whether or not he actually gets to act on it (see
	# _apply_arcane_aura_regen()'s own comment) - a no-op while it isn't
	# learned.
	_apply_arcane_aura_regen()

	# Passive HP/mana regen (see _apply_passive_hero_regen()) - same
	# timing as Arcane Aura's own regen just above, on top of it rather
	# than instead of it.
	_apply_passive_hero_regen()

	# Reactive Armor's own regen, off of whatever stacks are currently
	# active - same timing/stacking relationship as Arcane Aura's and
	# the baseline regen above.
	_apply_reactive_armor_regen()

	# Mortimer Kisses' channel: the hero's new turn is opening right
	# here, same point X Marks the Spot's own teleport claims for free
	# above - except this doesn't just do something for free, it
	# consumes the ENTIRE turn on an automatic shot, same as a stunned/
	# Cold-Embraced turn being skipped below, just with a shot fired
	# instead of nothing happening. Never falls through to the normal
	# "reopen the action buttons" code beneath it while a shot remains -
	# only once _fire_mortimer_kisses_shot() has fired the LAST one
	# (_end_mortimer_kisses() clears _mortimer_kisses_active) does
	# control reach the ordinary turn-opening logic below, exactly as if
	# the channel had never been active this turn.
	if _mortimer_kisses_active:
		var generation_before: int = _stage_generation
		_fire_mortimer_kisses_shot()
		_mortimer_kisses_turns_left -= 1
		if _mortimer_kisses_turns_left <= 0:
			_end_mortimer_kisses()

		# A kill from that shot (or its splash) could have cleared the
		# stage/won a hero fight and moved on to a fresh encounter -
		# same bail-out reasoning _end_turn()'s own top-of-function
		# comment already gives for the general case: scheduling
		# another _end_turn() timer here would fire after this node (or
		# this fight's own state) has already moved on.
		if _battle_over or _stage_generation != generation_before:
			return

		if _mortimer_kisses_active:
			_has_acted_this_turn = true
			_update_action_buttons()
			get_tree().create_timer(0.9).timeout.connect(_end_turn)
			return

	_has_acted_this_turn = false
	_update_action_buttons()
	_refresh_skill_cooldown_labels()

	# Still stunned after that decrement, or still encased in Cold
	# Embrace (already ticked - healed and counted down - by
	# _tick_skill_cooldowns()/_tick_cold_embrace() above, so this just
	# checks whether it's still active for the turn that was about to
	# open): the player gets no action at all this "turn" - skip
	# straight back to another _end_turn() call (Spirit Bear + enemy
	# turn again) after a short pause, the same way a stunned enemy
	# just loses its own turn to the player's own Pounce, rather than
	# opening the action buttons only to lock them again next turn. Name
	# whichever effect is actually responsible so the player knows why,
	# same as any other floating status message.
	if _player_stun_turns_left > 0 or _cold_embrace_active:
		var skip_reason: String = "Encased in ice" if _cold_embrace_active else "Stunned"
		_show_message_over_hero(skip_reason + " - turn skipped")
		get_tree().create_timer(0.9).timeout.connect(_end_turn)


## Ranged enemies get exactly one action per turn too - flee, attack,
## or approach - never a flee-then-attack combo in the same turn:
##
##        too close
##            |
##          FLEE
##            |
##        safe range
##            |
##         ATTACK
##            ^
##            |
##        too far
##            |
##          MOVE
##
## While Slark is hidden by Shadow Dance (_is_hero_hidden()), neither
## enemy type's attack can land on him, AND enemies stop moving/
## chasing him entirely - they hold their ground instead of stepping
## toward where he was. If the Spirit Bear is out, it's still fair
## game: enemies will shoot/swing at it, and will still chase it down,
## since only Slark himself is untraceable while invisible. The hero
## is always the priority target when both he and the bear are in
## range at once (while visible); only "too close" flee logic keys
## off him specifically, not the bear.
##
## A rooted enemy (root_turns_left > 0, from Entangle - see
## _apply_root()) never moves either, for the same reason as above:
## every movement branch (flee and the "close in" fallback) is
## skipped. Its attack is untouched, though - if it's already within
## range/on the hero's column, a root doesn't stop it from swinging.
##
## Tusk's Ice Shards works alongside root rather than replacing it: an
## enemy standing IN a walled-off column (_is_column_ice_shards_
## blocked()) is frozen exactly like a rooted one - see `ice_frozen`
## below, folded into every `not rooted` movement gate the same way -
## and one standing outside the wall simply can't step INTO a blocked
## column, checked against each individual destination right before the
## _move_enemy() call that would land it there. Attacking, casting a
## skill, and using an item are all untouched either way, same as root.
##
## Winter's Curse overrides all of the above for whichever OTHER
## enemies currently fall within its own curse_range of its frozen
## target (see _is_winters_curse_active()): they ignore the hero (and
## the bear) entirely for as long as the freeze holds, piling onto the
## target instead - see the dedicated block right after `rooted` is
## computed below. `curse_active`/`curse_target`/`curse_target_pos` are
## captured once, right here at the top, rather than re-checked per
## enemy - the target's own stun_turns_left (what actually drives
## _is_winters_curse_active()) ticks down partway through this same
## loop once its own turn comes up, so every enemy this pass needs to
## see the same answer regardless of iteration order.
func _enemy_turn() -> void:
	var curse_active: bool = _is_winters_curse_active()
	var curse_target: Dictionary = _winter_curse_target if curse_active else {}
	var curse_target_pos: int = curse_target.get("pos_index", -1) if curse_active else -1
	var curse_damage_multiplier: float = 1.0 + _winter_curse_bonus_damage_pct

	# The rival's own illusions caught in the player's Ice Vortex tick
	# at the start of the enemy turn, same as every enemy's own DoT
	# does just below. Illusions never decide the battle, so no
	# _battle_over bail-out is needed here.
	_tick_enemy_illusions_ice_vortex()

	for enemy in _enemies.duplicate():
		# Every DoT/execute effect currently on this enemy lands right
		# here, at the very start of its own turn - before stun is even
		# checked, so a DoT still burns through one. See
		# _tick_enemy_turn_start_effects()'s own comment for the full
		# list. A kill from one of these can end the whole battle (last
		# enemy standing, stage clears, etc.), so this needs the same
		# bail-out every other kill site in this function already uses;
		# a kill that leaves the fight still going just skips the rest
		# of this specific enemy's turn instead.
		_tick_enemy_turn_start_effects(enemy)
		if _battle_over:
			return
		if not _is_enemy_still_active(enemy):
			continue

		var stun_turns_left: int = enemy.get("stun_turns_left", 0)
		if stun_turns_left > 0:
			# Loses this turn entirely - no move, no attack - then the
			# counter ticks down toward wearing off.
			enemy["stun_turns_left"] = stun_turns_left - 1
			continue

		var enemy_static: Dictionary = enemy["static"]

		if enemy_static.get("is_hero_fight_boss", false):
			_enemy_hero_turn(enemy)
			continue

		var enemy_type: String = enemy_static.get("type", "")
		var enemy_damage: float = float(enemy_static.get("damage", 0))
		# Slardar's own Corrosive Haze (see _can_enemy_see_hero()'s own
		# comment) overrides this - true sight lets him keep fighting a
		# hidden player normally, stealth notwithstanding.
		var hero_hidden: bool = not _can_enemy_see_hero()
		# Root (Entangle's own, or Nature's Guise's) is checked with its
		# CURRENT value before ticking it down - same "use it, then
		# decrement" order stun_turns_left uses just above - so a 1-turn
		# root actually blocks the one movement it's meant to, instead of
		# expiring before it's ever consulted.
		var rooted: bool = _is_enemy_rooted(enemy) or _is_column_ice_shards_blocked(enemy["pos_index"])
		if enemy.get("root_turns_left", 0) > 0:
			enemy["root_turns_left"] -= 1
		# Silence has nothing to gate for a regular creep - only
		# _enemy_hero_turn() (the boss) ever checks _is_enemy_silenced()
		# before attempting a skill cast - so unlike root above, there's
		# no "consumed" moment to decrement it at here. Tick it down
		# unconditionally instead (same as _enemy_hero_turn()'s own copy
		# does for the boss), or a creep silenced by Entangle would carry
		# it forever - never expiring since nothing ever "uses" it.
		if enemy.get("silence_turns_left", 0) > 0:
			enemy["silence_turns_left"] -= 1

		if curse_active and not is_same(enemy, curse_target) and _distance(enemy["pos_index"], curse_target_pos) <= _winter_curse_range:
			# Cursed: this enemy drops the hero/bear entirely for this
			# turn and piles onto the frozen target instead - attacking
			# it (for bonus damage) if already within its own normal
			# attack reach of the target, otherwise closing in on it one
			# step at a time, same movement rules (including staying put
			# while rooted or ice-frozen) as it would use against the
			# hero.
			if enemy_type == "range":
				if _distance(enemy["pos_index"], curse_target_pos) <= RANGE_ENEMY_ATTACK_RANGE:
					_play_enemy_attack_lunge(enemy)
					# Another creep's own attack, not the hero's - Corrosive
					# Haze's own bonus never applies to it.
					_deal_fixed_damage_to_enemy(curse_target, enemy_damage * curse_damage_multiplier, false, false)
				elif not rooted:
					var step: int = _step_toward(enemy["pos_index"], curse_target_pos)
					var next_pos: int = enemy["pos_index"] + step
					if not _is_column_ice_shards_blocked(next_pos):
						_move_enemy(enemy, next_pos)
			elif enemy_type == "mele":
				if enemy["pos_index"] == curse_target_pos:
					_play_enemy_attack_lunge(enemy)
					# Same reasoning as the ranged branch above.
					_deal_fixed_damage_to_enemy(curse_target, enemy_damage * curse_damage_multiplier, false, false)
				elif not rooted:
					var step: int = _step_toward(enemy["pos_index"], curse_target_pos)
					var next_pos: int = enemy["pos_index"] + step
					if not _is_column_ice_shards_blocked(next_pos):
						_move_enemy(enemy, next_pos)
			continue

		if enemy_type == "range":
			var hero_distance: int = _distance(enemy["pos_index"], _hero_pos_index)

			if not hero_hidden and not rooted and hero_distance <= RANGE_ENEMY_FLEE_DISTANCE:
				# TOO CLOSE to the hero: move away. Attacking is next
				# turn's business, even if the flee step happens to
				# land back in range. Doesn't apply while he's
				# invisible (nothing visible to flee from), rooted, or
				# ice-frozen (can't move at all either way) - and not at
				# all if the flee spot itself is walled off, same as any
				# other blocked destination.
				var flee_pos: int = _get_flee_position(enemy)
				if not _is_column_ice_shards_blocked(flee_pos):
					_move_enemy(enemy, flee_pos)
				continue

			var attacked: bool = false
			if hero_distance <= RANGE_ENEMY_ATTACK_RANGE and not hero_hidden:
				# SAFE RANGE on the hero, and he's a valid target -
				# always the priority over the bear.
				_play_enemy_attack_lunge(enemy)
				apply_damage(enemy_damage)
				attacked = true
			elif _is_bear_alive() and _distance(enemy["pos_index"], _bear["pos_index"]) <= RANGE_ENEMY_ATTACK_RANGE:
				# Hero's out of range (or hidden), but the bear is
				# close enough to shoot instead.
				_play_enemy_attack_lunge(enemy)
				_deal_damage_to_bear(enemy_damage)
				attacked = true

			if not attacked and not rooted:
				# TOO FAR from anything worth shooting: close in on
				# whichever threat is nearer - but while the hero is
				# hidden, the bear is the only thing worth chasing at
				# all, so stand still if it's not around either. A
				# rooted (or ice-frozen) enemy skips this whole branch
				# and just stays put regardless.
				var target_pos: int = _nearest_threat_pos(enemy["pos_index"], hero_hidden)
				if target_pos != -1:
					var step: int = _step_toward(enemy["pos_index"], target_pos)
					var next_pos: int = enemy["pos_index"] + step
					if not _is_column_ice_shards_blocked(next_pos):
						_move_enemy(enemy, next_pos)

		elif enemy_type == "mele":
			var attacked: bool = false
			if enemy["pos_index"] == _hero_pos_index and not hero_hidden:
				_play_enemy_attack_lunge(enemy)
				apply_damage(enemy_damage)
				attacked = true
			elif _is_bear_alive() and enemy["pos_index"] == _bear["pos_index"]:
				_play_enemy_attack_lunge(enemy)
				_deal_damage_to_bear(enemy_damage)
				attacked = true

			if not attacked and not rooted:
				var target_pos: int = _nearest_threat_pos(enemy["pos_index"], hero_hidden)
				if target_pos != -1:
					var step: int = _step_toward(enemy["pos_index"], target_pos)
					var next_pos: int = enemy["pos_index"] + step
					if not _is_column_ice_shards_blocked(next_pos):
						_move_enemy(enemy, next_pos)


## Whichever "threat" - the hero, or the Spirit Bear if one is
## currently summoned - sits closer to `enemy_pos`, ties going to the
## hero. Only used to choose a movement target when nothing is in
## attack/flee range this turn (see _enemy_turn()).
##
## `hero_is_hidden` excludes the hero from consideration entirely -
## while Slark is invisible enemies can't track him to move toward
## him, only the bear (if one is out). Returns -1 when there's
## nothing left to chase, which the caller reads as "don't move".
func _nearest_threat_pos(enemy_pos: int, hero_is_hidden: bool = false) -> int:
	if hero_is_hidden:
		return _bear["pos_index"] if _is_bear_alive() else -1

	if not _is_bear_alive():
		return _hero_pos_index

	var hero_distance: int = _distance(enemy_pos, _hero_pos_index)
	var bear_distance: int = _distance(enemy_pos, _bear["pos_index"])
	return _bear["pos_index"] if bear_distance < hero_distance else _hero_pos_index


# ------------------------------------------------------------------
# A rival hero's own turn, during a hero fight - tries a skill first
# (see _pick_enemy_ready_skill()/_cast_enemy_skill()), falling back to
# the same flee/attack/approach behavior a regular creep uses in
# _enemy_turn() if nothing is ready/affordable/worthwhile right now, or
# if the player is currently untargetable (his own Shadow Dance).
#
# Two simplifications versus a regular creep's own targeting: a rival
# hero always focuses the player's hero directly rather than ever
# being drawn to the player's Spirit Bear the way a creep can be, and
# (like a creep) always moves exactly one column per turn regardless
# of the hero's own speed stat - matching how a hero fight boss has
# always been treated as a single flattened enemy rather than a full
# player-equivalent hero.
# ------------------------------------------------------------------

func _enemy_hero_turn(enemy: Dictionary) -> void:
	# Encased in ice - no action at all this turn, not even a free
	# X Marks the Spot teleport or a potion: move, attack, skill, and
	# item are ALL locked out for the duration, matching the player's
	# own copy (_update_action_buttons()/_end_turn()'s auto-skip). Its
	# immunity/heal-per-turn already run via _tick_enemy_cold_embrace()
	# regardless of what this turn does, so this just needs to do
	# nothing and let the turn pass.
	if _enemy_cold_embrace_active:
		return

	# Mortimer Kisses' channel: consumes this ENTIRE turn on an automatic
	# shot instead of the normal potion/skill/attack/move decision below
	# - no move, no attack, no other skill, no item, mirroring the
	# player's own copy (_end_turn()'s own "the hero's new turn is
	# opening right here" tail). Never falls through to anything else
	# below while a shot remains.
	if _enemy_mortimer_kisses_active:
		_fire_enemy_mortimer_kisses_shot()
		_enemy_mortimer_kisses_turns_left -= 1
		if _enemy_mortimer_kisses_turns_left <= 0:
			_end_enemy_mortimer_kisses()
		return

	# If X Marks the Spot marked the player last turn, this is the
	# rival's own "next turn" - teleport now, for free, then fall
	# straight through to everything below so it can still act (skill,
	# attack, or move) this same turn, same as the player's own copy
	# never spends the turn it teleports on (_resolve_xmarks_teleport()).
	if _enemy_xmarks_pending:
		_enemy_xmarks_pending = false
		_move_enemy(enemy, _hero_pos_index)
		_show_message_over_hero("X Marks the Spot!")

	_update_enemy_savage_roar_state(enemy)

	var enemy_type: String = enemy["static"].get("type", "")
	var hero_distance: int = _distance(enemy["pos_index"], _hero_pos_index)
	# Slardar's own Corrosive Haze (see _can_enemy_see_hero()'s own
	# comment) overrides this - true sight lets him keep fighting a
	# hidden player normally, stealth notwithstanding.
	var hero_hidden: bool = not _can_enemy_see_hero()
	# Ice Shards (the player's own, cast on this rival's turn) freezes
	# movement exactly like a root does - see _enemy_turn()'s own
	# comment for the full reasoning - so it's folded into the same
	# `rooted` flag rather than tracked separately here.
	# Root/silence are both checked with their CURRENT value before
	# ticking them down - same "use it, then decrement" order stun
	# uses in _enemy_turn() - so a 1-turn root/silence actually blocks
	# the one turn it's meant to, instead of expiring before it's ever
	# consulted (see _tick_enemy_turn_start_effects()'s own comment).
	var rooted: bool = _is_enemy_rooted(enemy) or _is_column_ice_shards_blocked(enemy["pos_index"])
	if enemy.get("root_turns_left", 0) > 0:
		enemy["root_turns_left"] -= 1
	var silenced: bool = _is_enemy_silenced(enemy)
	if enemy.get("silence_turns_left", 0) > 0:
		enemy["silence_turns_left"] -= 1

	# Potion, skill, or basic attack - in that priority, one action per
	# turn, exactly mirroring EnemyHeroManager's own simulated turn
	# order. Drinking a potion is an item, not a spell, so - like the
	# player's own item buttons - it's never gated by hero_hidden/
	# silence/root the way casting a skill or attacking is.
	var effective_max_hp: float = _enemy_hero_effective_max_hp(enemy)
	if float(enemy.get("current_hp", 0.0)) <= effective_max_hp * EnemyHeroManager.LOW_HP_POTION_THRESHOLD and _enemy_potion_health_count > 0:
		_drink_enemy_health_potion(enemy)
		return

	# A hidden player can't be targeted, but his Spirit Bear still can,
	# and a self-cast heal (Mist Coil on himself) needs no target at all
	# - so the rival still gets to pick a skill; the picker (via
	# _enemy_ai_hero_hidden) then only considers the bear-targetable
	# ones, aimed at the bear, plus that self-heal.
	if not silenced:
		_enemy_ai_hero_hidden = hero_hidden
		var skill_id: String = _pick_enemy_ready_skill(enemy, enemy_type, hero_distance)
		if skill_id != "":
			_cast_enemy_skill(enemy, skill_id)
			_enemy_ai_hero_hidden = false
			return
		_enemy_ai_hero_hidden = false
		if not hero_hidden and _enemy_has_unaffordable_ready_skill(enemy_type, hero_distance, enemy) and _enemy_potion_mana_count > 0:
			_drink_enemy_mana_potion()
			return

	if enemy_type == "range":
		if not hero_hidden and not rooted and hero_distance <= RANGE_ENEMY_FLEE_DISTANCE:
			var flee_pos: int = _get_flee_position(enemy)
			if not _is_column_ice_shards_blocked(flee_pos):
				_move_enemy(enemy, flee_pos)
			return

		if hero_distance <= RANGE_ENEMY_ATTACK_RANGE and not hero_hidden:
			_resolve_enemy_hero_attack(enemy)
			return
	else:  # "mele"
		if hero_distance <= 0 and not hero_hidden:
			_resolve_enemy_hero_attack(enemy)
			return

	if not hero_hidden and not rooted:
		var step: int = _step_toward(enemy["pos_index"], _hero_pos_index)
		if step != 0:
			# Slardar's Guardian Sprint boosts this same fallback move,
			# same "changes what the NEXT normal move does" shape the
			# player's own copy has in _hero_move() - a no-op walk of 1
			# column, same as every other enemy, while it isn't active.
			if _enemy_guardian_sprint_turns_remaining > 0:
				var sprint_distance: int = 1 + _enemy_guardian_sprint_bonus_movement
				var sprint_result: Dictionary = _enemy_guardian_sprint_move_target(enemy["pos_index"], step, sprint_distance)
				var landing_pos: int = int(sprint_result["pos"])
				if landing_pos != enemy["pos_index"]:
					_move_enemy(enemy, landing_pos)
				if bool(sprint_result["hit_player"]):
					var charge_damage: float = _roll_enemy_hero_damage(enemy) * _enemy_guardian_sprint_charge_damage_pct
					apply_damage(charge_damage)
			else:
				var next_pos: int = enemy["pos_index"] + step
				if not _is_column_ice_shards_blocked(next_pos):
					_move_enemy(enemy, next_pos)


## Heals the boss for the Health Potion's own flat value (same item
## data the player's own copy in _on_item_pressed() reads), clamped to
## their current effective max hp, and writes the new count straight
## back to PlayerManager immediately rather than waiting for the fight
## to resolve - it's already reflected there no matter how the fight
## ends (win, loss, or a flee - see _handle_defeat()/_on_flee_pressed()).
func _drink_enemy_health_potion(enemy: Dictionary) -> void:
	_enemy_potion_health_count -= 1
	PlayerManager.set_npc_potion_count(_enemy_hero_id, "health", _enemy_potion_health_count)

	var heal_amount: float = float(GameManager.get_item("health").get("value", 0))
	var max_hp: float = _enemy_hero_effective_max_hp(enemy)
	enemy["current_hp"] = minf(max_hp, enemy["current_hp"] + heal_amount)
	_show_message_over_hero("Rival drank a Health Potion")
	_refresh_bars()


## Restores the Mana Potion's own flat value. _enemy_max_mana is the
## rival's base max mana, so a hostile-looking but actually-beneficial
## Essence Shift bonus (_enemy_essence_shift_bonus's own "mana" key)
## has to be added back in for the clamp, the same pairing
## _build_enemy_ai_context() uses for its own "hero_mana"/"hero_max_
## mana" fields.
func _drink_enemy_mana_potion() -> void:
	_enemy_potion_mana_count -= 1
	PlayerManager.set_npc_potion_count(_enemy_hero_id, "mana", _enemy_potion_mana_count)

	var mana_amount: float = float(GameManager.get_item("mana").get("value", 0))
	var max_mana: float = _enemy_max_mana + _enemy_essence_shift_bonus.get("mana", 0.0)
	_enemy_current_mana = minf(max_mana, _enemy_current_mana + mana_amount)
	_show_message_over_hero("Rival drank a Mana Potion")
	_refresh_bars()


## The rival hero's plain Attack against the player: rolls their
## effective damage (folding in their own Essence Shift/True Form
## bonuses and, once per activation, Shadow Dance's one-shot bonus if
## they're currently hidden), applies it to the player, then runs
## Essence Shift's steal and Spirit Link's lifesteal - both of which,
## exactly like the player's own copies, only ever trigger off this
## plain Attack, never off a skill.
func _resolve_enemy_hero_attack(enemy: Dictionary) -> void:
	_play_enemy_attack_lunge(enemy)
	var shadow_bonus: float = _enemy_shadow_dance_bonus_damage if _enemy_shadow_dance_active else 0.0
	# Same idea for Nature's Guise, just with a root on the player
	# instead of bonus damage - captured now, before the attack (and
	# possibly _end_enemy_natures_guise()) below can change what
	# _enemy_natures_guise_active reads.
	var attacking_from_enemy_natures_guise: bool = _enemy_natures_guise_active
	var tidebringer_level_data: Dictionary = _maybe_consume_enemy_tidebringer_stack()
	var tidebringer_bonus: float = float(tidebringer_level_data.get("bonus_damage", 0.0))
	# Bash of the Deep counts this Attack toward its own threshold too,
	# same idea as Tidebringer's stack just above - once reached, this
	# hit's own damage is boosted by a PERCENTAGE of itself (folded in
	# below, after the roll - unlike Tidebringer's flat pre-roll bonus),
	# and the player gets knocked back afterward (see
	# _apply_enemy_bash_of_the_deep_knockback(), called once apply_
	# damage() has already resolved).
	var bash_level_data: Dictionary = _maybe_consume_enemy_bash_of_the_deep_stack()
	# Mirana's own Moonlight Shadow pays off the same way, just as a
	# PERCENTAGE of the attack's own rolled damage (folded in AFTER the
	# roll, below), same "post-roll percentage" shape Bash of the Deep's
	# own bonus uses. Only one of Shadow Dance/Moonlight Shadow could
	# ever be active in a given fight (different heroes' own kits), so
	# this never double-counts either way.
	var moonlight_shadow_active_bonus_pct: float = _enemy_moonlight_shadow_bonus_damage_pct if _enemy_moonlight_shadow_active else 0.0
	var attack_damage: float = _roll_enemy_hero_damage(enemy, shadow_bonus + tidebringer_bonus)
	if moonlight_shadow_active_bonus_pct > 0.0:
		attack_damage += attack_damage * moonlight_shadow_active_bonus_pct
	if not bash_level_data.is_empty():
		attack_damage += attack_damage * float(bash_level_data.get("bonus_damage_pct", 0.0))
	var mitigated: float = apply_damage(attack_damage)

	_apply_enemy_essence_shift_steal(enemy)
	_apply_enemy_spirit_link_lifesteal(enemy, mitigated)
	_apply_enemy_curse_of_avernus_stack()
	_apply_enemy_arctic_burn_attack()

	if not tidebringer_level_data.is_empty():
		# No cleave here - like Dark Pact/Mist Coil/Torrent, there's
		# only one possible target in a hero fight, so Tidebringer's
		# cleave has nothing else to reach; only its bonus damage
		# (already folded into the roll above) applies.
		_show_rising_message_over(hero_image, "Tidebringer!", TIDEBRINGER_TEXT_COLOR)

	# Moon Glaives' own bounce - a no-op unless the skill is learned (see
	# _apply_enemy_moon_glaives_bounces()'s own gate). Independent of
	# Tidebringer's above.
	_apply_enemy_moon_glaives_bounces(attack_damage)

	# Bash of the Deep's own knockback - after essence shift/lifesteal/
	# curse of avernus above, same "resolve every OTHER effect of the hit
	# before shoving the target somewhere else" ordering
	# _apply_hero_attack()'s own player-side copy follows. A no-op unless
	# this attack is the one that triggered the stack, and only if the
	# player actually survived it.
	if not bash_level_data.is_empty() and _recruited.get("current_hp", 0) > 0:
		_apply_enemy_bash_of_the_deep_knockback(enemy, bash_level_data)

	if _enemy_shadow_dance_active and shadow_bonus > 0.0:
		_end_enemy_shadow_dance()
	elif moonlight_shadow_active_bonus_pct > 0.0:
		_end_enemy_moonlight_shadow()

	if attacking_from_enemy_natures_guise:
		if _recruited.get("current_hp", 0) > 0:
			_player_root_turns_left = _enemy_natures_guise_root_turns
		_end_enemy_natures_guise()


## The rival hero's flat "damage" stat (see GameManager.build_hero_
## fight_enemy_def(), which averages their real min-max damage into
## one number the same way every other enemy in this scene works)
## plus whatever their own active buffs currently add - the enemy-side
## mirror of _roll_hero_damage(). No randomness, matching how every
## other enemy in this scene deals a flat amount rather than rolling a
## range.
func _roll_enemy_hero_damage(enemy: Dictionary, extra_bonus: float = 0.0) -> float:
	var base_damage: float = float(enemy["static"].get("damage", 0))
	var bonus: float = _enemy_essence_shift_bonus.get("damage", 0.0) + _enemy_true_form_bonus_damage + _enemy_arctic_burn_bonus_damage + _enemy_tag_team_bonus_damage + extra_bonus
	var total: float = maxf(0.0, base_damage + bonus)

	# Luna's Lunar Blessing - read fresh off the rival's current level
	# every roll (see _get_enemy_lunar_blessing_level_data()) rather than
	# tracked in a field, since it's never toggled on/off, just always-on
	# once learned. Applied last so it scales the whole roll, mirroring
	# the player's own _roll_hero_damage() exactly - this is the ONE
	# place it's ever folded in, so every caller of this function (a
	# plain Attack, Guardian Sprint's own charge damage, etc.) already has
	# it baked into whatever it reads back, with nothing further to add.
	var lunar_blessing_bonus_pct: float = float(_get_enemy_lunar_blessing_level_data().get("bonus_damage_pct", 0.0))
	if lunar_blessing_bonus_pct > 0.0:
		total += total * lunar_blessing_bonus_pct

	return total


## The rival's current max hp: base + Essence Shift's borrowed hp +
## True Form's bonus hp while each is active - the enemy-side mirror
## of _hero_max_hp(). Used to clamp Spirit Link's lifesteal.
func _enemy_hero_effective_max_hp(enemy: Dictionary) -> float:
	return float(enemy["static"].get("hp", 1)) + _enemy_essence_shift_bonus.get("hp", 0.0) + _enemy_true_form_bonus_hp


func _get_hero_fight_boss() -> Dictionary:
	if not _in_hero_fight:
		return {}
	for enemy in _enemies:
		if enemy["static"].get("is_hero_fight_boss", false):
			return enemy
	return {}


func _get_enemy_spirit_bear() -> Dictionary:
	for enemy in _enemies:
		if enemy["static"].get("is_enemy_spirit_bear", false):
			return enemy
	return {}


func _find_enemy_skill(skill_id: String) -> Dictionary:
	for skill in _enemy_hero_static.get("skills", []):
		if skill.get("id", "") == skill_id:
			return skill
	return {}


func _get_enemy_skill_level_data(skill_id: String) -> Dictionary:
	var skill: Dictionary = _find_enemy_skill(skill_id)
	var level: int = PlayerManager.get_npc_skill_level(_enemy_hero_id, skill_id)
	return GameManager.get_skill_level_data(skill, level)


func _enemy_skill_mana_cost(skill_id: String) -> float:
	return float(_get_enemy_skill_level_data(skill_id).get("mana_cost", 0))


## False for a buff/summon skill that's already active and wouldn't do
## anything new right now (recasting Essence Shift/Shadow Dance/Spirit
## Link/True Form just restarts their duration from the same values,
## and a Spirit Bear that's already out doesn't need replacing) - so
## the rival doesn't burn mana refreshing something with no benefit
## instead of attacking. Dark Pact/Pounce/Entangle always report true.
func _enemy_skill_worth_casting(skill_id: String) -> bool:
	match skill_id:
		"essence_shift":
			return not _enemy_essence_shift_active
		"shadow_dance":
			return not _enemy_shadow_dance_active
		"moonlight_shadow":
			return not _enemy_moonlight_shadow_active
		"eclipse":
			return not _enemy_eclipse_active
		"spirit_link":
			return not _enemy_spirit_link_active
		"true_form":
			return not _enemy_true_form_active
		"summon_spirit_bear":
			return _get_enemy_spirit_bear().is_empty()
		"aphotic_shield":
			return not _enemy_aphotic_shield_active
		"x_marks_the_spot":
			# Not worth recasting while a mark is already pending -
			# there's only ever one possible target anyway (the
			# player), so a second cast would just burn mana/cooldown
			# on a mark that hasn't even resolved yet.
			return not _enemy_xmarks_pending
		"cold_feet":
			# Recasting on an already-frozen player just resets the
			# same level's own damage/duration back to full - no extra
			# total damage over just letting the existing DoT run out,
			# so (same simplification as every buff above) it's simply
			# not worth it while one is already ticking.
			return _enemy_skill_worth_on_target("cold_feet", false) or (_is_bear_alive() and _enemy_skill_worth_on_target("cold_feet", true))
		"ice_vortex":
			# Same "no benefit from resetting your own DoT" reasoning
			# as Cold Feet above.
			return _enemy_skill_worth_on_target("ice_vortex", false) or (_is_bear_alive() and _enemy_skill_worth_on_target("ice_vortex", true))
		"arctic_burn":
			return not _enemy_arctic_burn_active
		"cold_embrace":
			return not _enemy_cold_embrace_active
		"freezing_field":
			return not _enemy_freezing_field_active
		"frostbite":
			# Recasting on an already-frostbitten player just resets the
			# same level's own DoT back to full - no extra total damage
			# over just letting it run out, same "no benefit from
			# resetting your own DoT" reasoning as Cold Feet/Ice Vortex
			# above (there's only one possible target in a hero fight, so
			# unlike the simulation's own copy - which always targets
			# whichever living enemy is currently lowest-HP and so can't
			# rely on a single flag like this - recasting here can only
			# ever land on the same, already-frozen player).
			return _enemy_skill_worth_on_target("frostbite", false) or (_is_bear_alive() and _enemy_skill_worth_on_target("frostbite", true))
		"tag_team":
			return not _enemy_tag_team_active
		"nature's_guise":
			return not _enemy_natures_guise_active
		"living_armor":
			return not _enemy_living_armor_active
		"leech_seed":
			# Same "no benefit from resetting your own DoT" reasoning as
			# Cold Feet/Ice Vortex/Frostbite above - recasting on an
			# already-seeded player just restarts the same level's own
			# damage/healing back to full, no extra total value over
			# letting the existing one run its course.
			return _enemy_skill_worth_on_target("leech_seed", false) or (_is_bear_alive() and _enemy_skill_worth_on_target("leech_seed", true))
		"mortimer_kisses":
			# Purely defensive/documentation consistency, mirroring Cold
			# Embrace's own case above - _enemy_hero_turn()'s own top-of-
			# function lockout already returns before this could ever be
			# QUERIED while the channel is active in practice.
			return not _enemy_mortimer_kisses_active
		_:
			return true


## True if `skill_id` is known, off cooldown, worth casting, and
## affordable right now - the same four gates _pick_enemy_ready_skill()
## always applied inline, factored out so combo scoring (see
## _build_enemy_ai_context()'s "kunkka_torrent_combo_ready"/
## "kunkka_ghostship_combo_ready") can ask "would this skill be usable
## if range weren't the issue" via `ignore_range`, without duplicating
## the other four checks. `ignore_range` is only ever true for that
## combo-readiness question - the real candidate loop below always
## leaves it false, so nothing here changes for any existing hero.
## `enemy` is only ever read by _enemy_skill_in_range()'s own
## Scatterblast special-case (its own facing/position, for the
## directional check) - every other skill's range check ignores it.
func _is_enemy_skill_ready(skill_id: String, enemy_type: String, hero_distance: int, enemy: Dictionary, ignore_range: bool = false) -> bool:
	if PlayerManager.get_npc_skill_level(_enemy_hero_id, skill_id) <= 0:
		return false
	if _enemy_skill_cooldowns.get(skill_id, 0) > 0:
		return false
	if not _enemy_skill_worth_casting(skill_id):
		return false
	var level_data: Dictionary = _get_enemy_skill_level_data(skill_id)
	if _enemy_current_mana < float(level_data.get("mana_cost", 0)):
		return false
	# A skill that can be aimed at the player's Spirit Bear is ready as
	# long as EITHER target is reachable and worth hitting - see
	# _enemy_skill_target_options(). Every other skill still needs the
	# player himself, visible and in range.
	if ENEMY_BEAR_TARGETABLE_SKILLS.has(skill_id):
		var options: Dictionary = _enemy_skill_target_options(skill_id, enemy_type, hero_distance, enemy, ignore_range)
		return options["hero"] or options["bear"]
	if _enemy_ai_hero_hidden:
		return false
	if not ignore_range and not _enemy_skill_in_range(skill_id, enemy_type, hero_distance, enemy):
		return false
	return true


## Every known, off-cooldown, currently-worthwhile, currently-
## affordable, in-range active skill the rival hero has right now (that
## is, every skill in ENEMY_KNOWN_SKILL_IDS that survives all of those
## checks), PLUS a plain Attack for whichever heroes EnemySkillAI.
## basic_attack_participates() opts in (today: only Kunkka, whose
## Tidebringer can make a plain Attack the better play - see
## EnemySkillAI's own "basic_attack" scoring), is scored by
## EnemySkillAI.evaluate_skill()/evaluate_basic_attack(), and the
## highest-scoring one wins - ties within EnemySkillAI.
## CLOSE_SCORE_THRESHOLD are resolved by a score-weighted random pick,
## falling back to the hero's own EnemySkillAI.HERO_TIE_BREAK order only
## if that still doesn't settle it. Returns "" if no candidate qualifies
## at all, OR if the winner was that plain-Attack candidate - either way
## the caller's own existing basic-attack fallback takes over unchanged.
## `enemy_type`/`hero_distance` still gate skills that actually need to
## reach the player - see _enemy_skill_in_range()/EnemySkillRange - so a
## boss can't land Dark Pact or Entangle from clear across the board; it
## has to close in first, same as it already must for a plain Attack.
## This replaces the old "first match in ENEMY_KNOWN_SKILL_IDS wins"
## rule - the array is still every skill this AI ever considers, it's
## just no longer the order they're preferred in.
func _pick_enemy_ready_skill(enemy: Dictionary, enemy_type: String, hero_distance: int) -> String:
	var context: Dictionary = _build_enemy_ai_context(enemy, enemy_type, hero_distance)
	var candidates: Array = []

	for skill_id in ENEMY_KNOWN_SKILL_IDS:
		if not _is_enemy_skill_ready(skill_id, enemy_type, hero_distance, enemy):
			continue
		var level_data: Dictionary = _get_enemy_skill_level_data(skill_id)
		candidates.append({"id": skill_id, "score": EnemySkillAI.evaluate_skill(skill_id, level_data, context)})

	# Mist Coil on himself (the self-heal) competes as its own candidate,
	# alongside Mist Coil aimed at the player - see
	# EnemySkillAI.MIST_COIL_SELF_ID. _cast_enemy_skill() maps a win
	# back onto a self-targeted "mist_coil" cast.
	if _enemy_mist_coil_self_ready(enemy):
		var mist_coil_level_data: Dictionary = _get_enemy_skill_level_data("mist_coil")
		candidates.append({"id": EnemySkillAI.MIST_COIL_SELF_ID, "score": EnemySkillAI.evaluate_skill(EnemySkillAI.MIST_COIL_SELF_ID, mist_coil_level_data, context)})

	var archetype: String = str(context.get("archetype", ""))
	if EnemySkillAI.basic_attack_participates(archetype):
		candidates.append({"id": EnemySkillAI.BASIC_ATTACK_ID, "score": EnemySkillAI.evaluate_basic_attack(context)})

	var chosen_id: String = EnemySkillAI.pick_best_skill(archetype, candidates, str(_enemy_hero_static.get("name", _enemy_hero_id)))
	return "" if chosen_id == EnemySkillAI.BASIC_ATTACK_ID else chosen_id


## Whether the rival could cast Mist Coil on himself right now: learned,
## off cooldown, affordable, and with more HP than its hp_cost - paying
## it must never kill him. No range or "worth casting" gate (it's a
## self-cast heal; EnemySkillAI's own scoring decides whether it's worth
## it), and - being self-targeted - it stays available even while the
## player is hidden.
func _enemy_mist_coil_self_ready(enemy: Dictionary) -> bool:
	if PlayerManager.get_npc_skill_level(_enemy_hero_id, "mist_coil") <= 0:
		return false
	if _enemy_skill_cooldowns.get("mist_coil", 0) > 0:
		return false
	var level_data: Dictionary = _get_enemy_skill_level_data("mist_coil")
	if _enemy_current_mana < float(level_data.get("mana_cost", 0)):
		return false
	return float(enemy.get("current_hp", 0.0)) > float(level_data.get("hp_cost", 0))


## True if there's a known, off-cooldown, currently-worthwhile, in-range
## active skill the rival just can't afford right now - the trigger for
## drinking a Mana Potion instead of attacking this turn, mirroring
## EnemyHeroManager's own _has_unaffordable_ready_skill(). Only ever
## checked once _pick_enemy_ready_skill() has already come up empty, so
## this only needs to explain WHY it came up empty (mana, specifically)
## rather than re-picking anything.
func _enemy_has_unaffordable_ready_skill(enemy_type: String, hero_distance: int, enemy: Dictionary) -> bool:
	for skill_id in ENEMY_KNOWN_SKILL_IDS:
		if PlayerManager.get_npc_skill_level(_enemy_hero_id, skill_id) <= 0:
			continue
		if _enemy_skill_cooldowns.get(skill_id, 0) > 0:
			continue
		if not _enemy_skill_worth_casting(skill_id):
			continue
		if not _enemy_skill_in_range(skill_id, enemy_type, hero_distance, enemy):
			continue
		var level_data: Dictionary = _get_enemy_skill_level_data(skill_id)
		if _enemy_current_mana < float(level_data.get("mana_cost", 0)):
			return true
	return false


## Builds the AI context EnemySkillAI scores every candidate skill
## against for this rival's turn - the battle-mode counterpart of
## EnemyHeroManager.gd's own _build_npc_ai_context(). The player is
## always the rival's only possible target during a hero fight, so
## `enemy_count` is always 1 here (contrast the simulation, where it's
## however many creeps are still alive) and there's no per-target
## selection step the way a multi-enemy sim needs one. `living_target_
## hps`/`living_target_max_hps` are the single-player mirror of the
## simulation's own living-enemy HP/max-HP lists - always one entry
## here, but kept under the same keys so EnemySkillAI's shared multi-
## kill/execute scoring (see Kunkka's own Ghostship/Torrent modifiers
## and Ancient Apparition's own Ice Blast modifier) doesn't need a
## battle-vs-sim branch.
##
## The three "kunkka_*"/"tidebringer_*" fields only ever matter for
## Kunkka (every other hero's own modifier ignores them) - they're
## still computed unconditionally since that's cheap and keeps this
## function hero-agnostic, same as every other field here:
##   - tidebringer_ready/tidebringer_cleave_targets/tidebringer_bonus_
##     damage: whether the rival's NEXT plain Attack would activate
##     Tidebringer, and what that's worth - see
##     _maybe_consume_enemy_tidebringer_stack() for the real activation
##     this only ever previews. cleave_targets is always 0 here (a hero
##     fight only ever has the player to cleave onto - see
##     _resolve_enemy_hero_attack()'s own "no cleave" comment).
##   - kunkka_torrent_combo_ready/kunkka_ghostship_combo_ready: whether
##     Torrent/Ghostship would be castable right now if range weren't
##     the issue (see _is_enemy_skill_ready()'s `ignore_range`) - X
##     Marks the Spot always closes the distance to 0 by the rival's own
##     next turn (see _enemy_hero_turn()'s teleport-consumption step),
##     so "everything else about it is ready" is the real question for
##     whether marking now sets up a real follow-up.
##   - in_attack_range_now/in_attack_range_with_arctic_burn_bonus/
##     arctic_burn_active: for Winter Wyvern's own Arctic Burn - whether
##     the player is (or would be, with the bonus range folded in)
##     within the rival's own basic-attack reach right now, so casting
##     it only scores well when there's a realistic attack coming, not
##     just because it's off cooldown.
##   - has_harmful_debuff: whether the rival currently has anything the
##     player inflicted on it (root/silence/a DoT/Curse of Avernus) -
##     for Winter Wyvern's own Cold Embrace, which dispels it.
##   - redirect_candidate_count/avg_enemy_damage: for Winter Wyvern's own
##     Winter's Curse. Always 0/0.0 here - a hero fight only ever has
##     the player to curse, and nothing else on the rival's own side to
##     redirect onto the frozen target the way the simulation's other
##     living creeps can (see EnemyHeroManager's own _build_npc_ai_
##     context() for the real multi-enemy version of both fields).
##   - target_distance: also doubles as Crystal Maiden's own Freezing
##     Field range check (see EnemySkillAI's own _cm_freezing_field_
##     modifier()) - Freezing Field is centered on HERSELF, not the
##     player, but in a hero fight `hero_distance` (the rival's distance
##     to the player) and "the player's distance to the rival" are the
##     same number, so there's no separate field to compute.
##   - caster_pos_index/target_pos_index/grid_columns/caster_facing_left:
##     for Tusk's own Ice Shards (whether its wall actually reaches the
##     player's column, and how close to either board edge that leaves
##     them) and Walrus Punch (working out the knockback's actual
##     landing column, the same walk _cast_enemy_walrus_punch() itself
##     does, just to SCORE it beforehand rather than to resolve it) -
##     see EnemySkillAI's own _tusk_ice_shards_modifier()/_tusk_walrus_
##     punch_modifier(). Never present in the simulation (no positions
##     there at all - see EnemyHeroManager's own _build_npc_ai_context()
##     docstring), where `grid_columns` defaults to 0 and both modifiers
##     fall back to their own no-columns proxy instead.
##   - reactive_armor_stacks/reactive_armor_max_stacks: Timbersaw's own
##     current Reactive Armor stack count/cap, for EnemySkillAI's own
##     _timbersaw_modifier() to fold into its survival/aggression
##     calculations (see that function's own docstring) - 0/0 for every
##     other hero (a no-op there, same as every other hero-specific
##     field in this context).
##   - target_is_hero: always true here - the player is the only
##     possible target in a hero fight, and always a hero. Used by
##     Timbersaw's own Whirling Death (see _timbersaw_whirling_death_
##     modifier()) for its own qualitative "a hero was hit" value;
##     EnemyHeroManager's own _build_npc_ai_context() reports false
##     instead, since the simulation's own targets are always creeps.
##   - target_armor: the player's own current _hero_armor() (already
##     folding in every buff/debuff currently on him, Lil' Shredder's own
##     armor reduction included) - for Snapfire's own Lil' Shredder (see
##     EnemySkillAI's own _snapfire_lil_shredder_modifier()), which
##     values shredding a heavily-armored target more than a lightly-
##     armored one. EnemyHeroManager's own _build_npc_ai_context() reads
##     a creep target's own static armor instead, since the simulation
##     has no per-turn buff/debuff armor system of its own.
##   - illusions_active/illusion_count/illusion_turns_remaining/illusion_
##     total_damage_per_turn: Naga Siren's own Mirror Image, live off
##     _enemy_illusions - for EnemySkillAI's own _naga_mirror_image_
##     modifier()/_naga_ensnare_modifier()/_naga_song_of_the_siren_
##     modifier()/_naga_basic_attack_modifier(), all of which read this
##     turn's illusion state to score their own Mirror Image synergy (see
##     each one's own docstring). illusion_total_damage_per_turn is the
##     WHOLE squad's own expected hit next turn (_roll_enemy_hero_damage()
##     x _enemy_illusion_damage_pct x illusion count), not a per-illusion
##     figure, so callers never have to re-multiply by illusion_count
##     themselves.
##   - rip_tide_illusion_damage_bonus_pct/rip_tide_extra_illusion/rip_
##     tide_illusion_duration_bonus/rip_tide_aoe_damage_pct: Naga Siren's
##     own Rip Tide, read fresh off _get_enemy_rip_tide_level_data() -
##     Rip Tide is passive and never itself a scored candidate (see
##     EnemySkillAI's own header comment), so its bonuses only ever reach
##     Mirror Image/Song of the Siren/a plain Attack through these four
##     fields. All 0/0.0 while the rival hasn't learned it.
##   - hero_move_distance: the rival's own baseline per-turn movement (1 -
##     every enemy always takes exactly one column per turn, see
##     _hero_move_distance()'s own header comment) before Guardian
##     Sprint's own bonus - for Slardar's own reach math.
##   - sprint_bonus_movement/sprint_charge_damage_pct: Guardian Sprint's
##     CURRENT level, read fresh off _get_enemy_skill_level_data() - 0/0.0
##     while unlearned. Guardian Sprint is scored as a candidate only on
##     the turn it's actually cast, so other skills (Corrosive Haze's own
##     reach check, a plain Attack's own knockback-wash check) need these
##     independently of whatever Sprint itself is being scored with.
##   - bash_attacks_required/bash_current_progress/bash_bonus_damage_pct/
##     bash_knockback: Slardar's own Bash of the Deep, read fresh off
##     _get_enemy_bash_of_the_deep_level_data()/_enemy_bash_of_the_deep_
##     attack_count - passive and never itself a scored candidate (see
##     EnemySkillAI's own header comment), so its progression only ever
##     reaches Guardian Sprint/Slithereen Crush/Corrosive Haze/a plain
##     Attack through these fields. All 0/0.0 while unlearned.
##   - crush_radius/crush_damage: Slithereen Crush's CURRENT level, read
##     fresh off _get_enemy_skill_level_data() - for Guardian Sprint's/
##     Corrosive Haze's own combo bonuses, same reasoning as Sprint's own
##     fields above.
##   - target_marked_bonus_pct: whether the player is CURRENTLY Corrosive
##     Haze-marked, and by how much (_player_corrosive_haze_bonus_pct) -
##     for a plain Attack's own synergy bonus.
##   - hero_attack_range: the rival's own basic-attack reach for its type
##     (base_attack_range, already computed below) - for Mirana's own
##     Leap/Moonlight Shadow, which both need to compare a real distance
##     against attack range rather than just the boolean "in_attack_
##     range_now" every other hero's own fields already cover.
##   - starstorm_radius/sacred_arrow_range/sacred_arrow_base_damage/
##     sacred_arrow_bonus_per_column: Mirana's OTHER skills' CURRENT
##     levels, read fresh off _get_enemy_skill_level_data() - each of her
##     skills is only ever scored as a candidate on the turn it's itself
##     being cast, so Leap's/Moonlight Shadow's own combo bonuses need
##     these independently, same reasoning Slardar's own "crush_radius"/
##     "crush_damage" fields already established.
##   - moonlight_shadow_active/moonlight_shadow_bonus_damage_pct:
##     Mirana's own current stealth state - for a plain Attack's own
##     substantial bonus while it's up (see EnemySkillAI's own _mirana_
##     basic_attack_modifier()).
##   - target_stunned: whether the player currently has a stun on him
##     (_player_stun_turns_left > 0) - for Sacred Arrow's own follow-up-
##     Attack synergy (see EnemySkillAI's own _mirana_basic_attack_
##     modifier()'s "target_stunned" case).
##   - moon_glaives_bounces/moon_glaives_bounce_damage_pct/moon_glaives_
##     bounce_range: Luna's own Moon Glaives, CURRENT level, read fresh
##     off _get_enemy_moon_glaives_level_data() - 0/0.0 while unlearned.
##   - moon_glaives_valid_bounce_targets/moon_glaives_bounce_target_hps:
##     the ACTUAL bounce targets right now - every one of the player's
##     own illusions, plus his own Spirit Bear, within bounce_range of
##     his own column (the only column a rival Attack could ever bounce
##     from - see _apply_enemy_moon_glaives_bounces()'s own docstring for
##     why there's no second real _enemies-style target here) - never the
##     skill's own maximum bounce count.
##   - lunar_blessing_bonus_pct: Luna's own Lunar Blessing, CURRENT
##     level - exposed for transparency only; "hero_damage" itself
##     already has it folded in (see _roll_enemy_hero_damage()'s own
##     docstring), so nothing reads this to re-derive the damage number.
##   - eclipse_candidate_count/eclipse_candidate_hps/eclipse_candidate_
##     max_hps: every REAL beam candidate within Luna's own Eclipse
##     radius right now - the player (if in range), each of his own
##     illusions in range, and his own Spirit Bear if in range - mirrors
##     _tick_enemy_eclipse()'s own candidate pool exactly (see
##     EnemySkillAI's own _luna_eclipse_modifier()/_luna_eclipse_
##     expected_damage() for how this drives the ultimate's own scoring).
func _build_enemy_ai_context(enemy: Dictionary, enemy_type: String, hero_distance: int) -> Dictionary:
	var max_hp: float = _enemy_hero_effective_max_hp(enemy)
	var current_hp: float = float(enemy.get("current_hp", 0.0))

	var tidebringer_level_data: Dictionary = _get_enemy_tidebringer_level_data()
	var tidebringer_ready: bool = not tidebringer_level_data.is_empty() \
		and (_enemy_tidebringer_attack_count + 1) >= int(tidebringer_level_data.get("hits_to_activate", 1))

	var base_attack_range: int = RANGE_ENEMY_ATTACK_RANGE if enemy_type == "range" else 0

	# Luna's Moon Glaives: the ACTUAL bounce targets right now - every one
	# of the player's own illusions, plus his own Spirit Bear, within
	# bounce_range of his own column (see _apply_enemy_moon_glaives_
	# bounces()'s own docstring for why that's the only column a rival
	# Attack could ever bounce from in a hero fight).
	var moon_glaives_level_data: Dictionary = _get_enemy_skill_level_data("moon_glaives")
	var moon_glaives_bounce_range: int = int(moon_glaives_level_data.get("bounce_range", 0))
	var moon_glaives_bounce_target_hps: Array = []
	for illusion in _illusions:
		if _distance(illusion["pos_index"], _hero_pos_index) <= moon_glaives_bounce_range:
			moon_glaives_bounce_target_hps.append(float(illusion.get("current_hp", 0.0)))
	if _is_bear_alive() and _distance(_bear["pos_index"], _hero_pos_index) <= moon_glaives_bounce_range:
		moon_glaives_bounce_target_hps.append(float(_bear.get("current_hp", 0.0)))

	# Luna's Eclipse: every REAL beam candidate within radius of the
	# rival's OWN current position right now - the player himself, each
	# of his own illusions, and his own Spirit Bear - mirrors
	# _tick_enemy_eclipse()'s own candidate pool exactly.
	var eclipse_level_data: Dictionary = _get_enemy_skill_level_data("eclipse")
	var eclipse_radius: int = int(eclipse_level_data.get("radius", 0))
	var eclipse_candidate_hps: Array = []
	var eclipse_candidate_max_hps: Array = []
	if hero_distance <= eclipse_radius:
		eclipse_candidate_hps.append(float(_recruited.get("current_hp", 0)))
		eclipse_candidate_max_hps.append(_hero_max_hp())
	for illusion in _illusions:
		if _distance(illusion["pos_index"], enemy["pos_index"]) <= eclipse_radius:
			eclipse_candidate_hps.append(float(illusion.get("current_hp", 0.0)))
			eclipse_candidate_max_hps.append(float(illusion.get("max_hp", 0.0)))
	if _is_bear_alive() and _distance(_bear["pos_index"], enemy["pos_index"]) <= eclipse_radius:
		eclipse_candidate_hps.append(float(_bear.get("current_hp", 0.0)))
		eclipse_candidate_max_hps.append(float(_bear.get("hp", _bear.get("current_hp", 0.0))))

	return {
		"game_mode": "battle",
		"archetype": EnemySkillAI.resolve_hero_archetype(_enemy_hero_static),
		"hero_hp": current_hp,
		"hero_max_hp": max_hp,
		"hero_hp_ratio": (current_hp / max_hp) if max_hp > 0.0 else 0.0,
		"hero_mana": _enemy_current_mana,
		"hero_max_mana": _enemy_max_mana,
		"hero_damage": _roll_enemy_hero_damage(enemy),
		"enemy_count": 1,
		"target_hp": float(_recruited.get("current_hp", 0)),
		"target_max_hp": _hero_max_hp(),
		"target_distance": hero_distance,
		"bear_active": not _get_enemy_spirit_bear().is_empty(),
		"living_target_hps": [float(_recruited.get("current_hp", 0))],
		"living_target_max_hps": [_hero_max_hp()],
		"tidebringer_ready": tidebringer_ready,
		"tidebringer_bonus_damage": float(tidebringer_level_data.get("bonus_damage", 0.0)),
		"tidebringer_cleave_targets": 0,
		"kunkka_torrent_combo_ready": _is_enemy_skill_ready("torrent", enemy_type, hero_distance, enemy, true),
		"kunkka_ghostship_combo_ready": _is_enemy_skill_ready("ghostship", enemy_type, hero_distance, enemy, true),
		"in_attack_range_now": hero_distance <= base_attack_range,
		"in_attack_range_with_arctic_burn_bonus": hero_distance <= (base_attack_range + _enemy_arctic_burn_bonus_range),
		"arctic_burn_active": _enemy_arctic_burn_active,
		"has_harmful_debuff": _enemy_has_harmful_debuff(enemy),
		"redirect_candidate_count": 0,
		"avg_enemy_damage": 0.0,
		"caster_pos_index": enemy["pos_index"],
		"target_pos_index": _hero_pos_index,
		"grid_columns": GRID_COLUMNS,
		"caster_facing_left": bool(enemy["node"].flip_h),
		"reactive_armor_stacks": _enemy_reactive_armor_stack_turns.size(),
		"reactive_armor_max_stacks": int(_get_enemy_reactive_armor_level_data().get("max_stacks", 0)),
		"target_is_hero": true,
		"target_armor": _hero_armor(),
		"illusions_active": not _enemy_illusions.is_empty(),
		"illusion_count": _enemy_illusions.size(),
		"illusion_turns_remaining": _enemy_illusions_turns_remaining,
		"illusion_total_damage_per_turn": _roll_enemy_hero_damage(enemy) * _enemy_illusion_damage_pct * float(_enemy_illusions.size()),
		"rip_tide_illusion_damage_bonus_pct": float(_get_enemy_rip_tide_level_data().get("illusion_damage_bonus_pct", 0.0)),
		"rip_tide_extra_illusion": int(_get_enemy_rip_tide_level_data().get("extra_illusion", 0)),
		"rip_tide_illusion_duration_bonus": int(_get_enemy_rip_tide_level_data().get("illusion_duration_bonus", 0)),
		"rip_tide_aoe_damage_pct": float(_get_enemy_rip_tide_level_data().get("aoe_damage_pct", 0.0)),
		"hero_move_distance": 1,
		"sprint_bonus_movement": int(_get_enemy_skill_level_data("guardian_sprint").get("bonus_movement", 0)),
		"sprint_charge_damage_pct": float(_get_enemy_skill_level_data("guardian_sprint").get("charge_damage_pct", 0.0)),
		"bash_attacks_required": int(_get_enemy_bash_of_the_deep_level_data().get("attacks_required", 0)),
		"bash_current_progress": _enemy_bash_of_the_deep_attack_count,
		"bash_bonus_damage_pct": float(_get_enemy_bash_of_the_deep_level_data().get("bonus_damage_pct", 0.0)),
		"bash_knockback": int(_get_enemy_bash_of_the_deep_level_data().get("knockback", 0)),
		"crush_radius": int(_get_enemy_skill_level_data("slithereen_crush").get("radius", 0)),
		"crush_damage": float(_get_enemy_skill_level_data("slithereen_crush").get("damage", 0.0)),
		"target_marked_bonus_pct": _player_corrosive_haze_bonus_pct,
		"hero_attack_range": base_attack_range,
		"starstorm_radius": int(_get_enemy_skill_level_data("starstorm").get("radius", 0)),
		"sacred_arrow_range": int(_get_enemy_skill_level_data("sacred_arrow").get("range", 0)),
		"sacred_arrow_base_damage": float(_get_enemy_skill_level_data("sacred_arrow").get("base_damage", 0.0)),
		"sacred_arrow_bonus_per_column": float(_get_enemy_skill_level_data("sacred_arrow").get("bonus_per_column", 0.0)),
		"moonlight_shadow_active": _enemy_moonlight_shadow_active,
		"moonlight_shadow_bonus_damage_pct": _enemy_moonlight_shadow_bonus_damage_pct,
		"target_stunned": _player_stun_turns_left > 0,
		"moon_glaives_bounces": int(moon_glaives_level_data.get("bounces", 0)),
		"moon_glaives_bounce_damage_pct": float(moon_glaives_level_data.get("bounce_damage_pct", 0.0)),
		"moon_glaives_bounce_range": moon_glaives_bounce_range,
		"moon_glaives_valid_bounce_targets": moon_glaives_bounce_target_hps.size(),
		"moon_glaives_bounce_target_hps": moon_glaives_bounce_target_hps,
		"lunar_blessing_bonus_pct": float(_get_enemy_lunar_blessing_level_data().get("bonus_damage_pct", 0.0)),
		"eclipse_candidate_count": eclipse_candidate_hps.size(),
		"eclipse_candidate_hps": eclipse_candidate_hps,
		"eclipse_candidate_max_hps": eclipse_candidate_max_hps,
	}


## Whether `enemy` (a hero-fight boss) currently has anything the player
## inflicted on it - root, silence, or any of the DoTs a player skill
## can apply directly onto an enemy Dictionary (Entangle's, Curse of
## Avernus's, Cold Feet's, Ice Vortex's, Ice Blast's) - used by Winter
## Wyvern's own Cold Embrace scoring (see EnemySkillAI's own "winter_
## wyvern" modifier), since casting it dispels all of them at once.
func _enemy_has_harmful_debuff(enemy: Dictionary) -> bool:
	if enemy.get("root_turns_left", 0) > 0:
		return true
	if enemy.get("silence_turns_left", 0) > 0:
		return true
	if enemy.get("entangle_dot_turns_left", 0) > 0:
		return true
	if enemy.get("curse_active", false) or enemy.get("curse_stacks", 0) > 0:
		return true
	if enemy.get("cold_feet_dot_turns_left", 0) > 0:
		return true
	if enemy.get("ice_vortex_dot_turns_left", 0) > 0:
		return true
	if enemy.get("ice_blast_dot_turns_left", 0) > 0:
		return true
	return false


## True if a rival hero of `enemy_type`, `hero_distance` columns from
## the player, can currently reach the player with `skill_id` - see
## EnemySkillRange for which skills need this check and why. `enemy` is
## only ever read by the Scatterblast special-case below (its own
## position/facing, for the directional check) - every other skill's
## check below ignores it entirely, same as EnemySkillRange.is_in_range()
## itself.
func _enemy_skill_in_range(skill_id: String, enemy_type: String, hero_distance: int, enemy: Dictionary) -> bool:
	if not EnemySkillRange.requires_range_check(skill_id):
		return true

	var level: int = PlayerManager.get_npc_skill_level(_enemy_hero_id, skill_id)
	var level_data: Dictionary = GameManager.get_skill_level_data(_find_enemy_skill(skill_id), level)

	if skill_id == "scatterblast":
		# Directional, not a plain "distance <= radius/attack_range"
		# check - mirrors the player's own _cast_scatterblast()'s "ahead"
		# math exactly: only in range if the player is ahead of the
		# rival in whichever direction it's CURRENTLY facing
		# (enemy["node"].flip_h, kept up to date by _move_enemy()), never
		# behind or on the wrong side of a shared column. See
		# EnemySkillRange's own header comment for why this never
		# reaches its generic is_in_range() chain at all.
		var range_columns: int = int(level_data.get("range", 0))
		var direction: int = -1 if bool(enemy["node"].flip_h) else 1
		var ahead: int = (_hero_pos_index - int(enemy["pos_index"])) * direction
		return ahead >= 0 and ahead <= range_columns

	# Torrent's/X Marks the Spot's/Ghostship's/Cold Feet's own targeting
	# range lives in a "range" field rather than "radius" (Torrent's
	# separate, level-4-only splash radius); Pounce's own leap reach
	# lives in a "distance" field instead - see EnemySkillRange's
	# "torrent"/"x_marks_the_spot"/"ghostship"/"pounce"/"cold_feet" case,
	# which compares distance against whichever of the three this
	# resolves to. Ice Vortex is the one exception: its own targeting
	# range is the FIXED constant ICE_VORTEX_RANGE, never part of its
	# level data (which only carries its AoE radius, 1-2) - falling
	# through the same generic chain would silently grab that AoE
	# radius instead, so it's special-cased here first.
	return _enemy_skill_reaches_distance(skill_id, enemy_type, hero_distance)


## The generic half of _enemy_skill_in_range() - whether `skill_id`
## reaches a target `distance` columns away - split out so the same
## check can be asked about the player's Spirit Bear too (see
## _enemy_skill_target_options()). Scatterblast's directional check
## stays in _enemy_skill_in_range() itself; it's never bear-targetable.
func _enemy_skill_reaches_distance(skill_id: String, enemy_type: String, distance: int) -> bool:
	if not EnemySkillRange.requires_range_check(skill_id):
		return true
	var level_data: Dictionary = _get_enemy_skill_level_data(skill_id)
	var radius: int = ICE_VORTEX_RANGE if skill_id == "ice_vortex" else int(level_data.get("range", level_data.get("radius", level_data.get("distance", 0))))
	var attack_range: int = RANGE_ENEMY_ATTACK_RANGE if enemy_type == "range" else 0
	return EnemySkillRange.is_in_range(skill_id, distance, radius, attack_range)


func _cast_enemy_skill(enemy: Dictionary, skill_id: String) -> void:
	# The self-heal candidate (EnemySkillAI.MIST_COIL_SELF_ID) is just
	# Mist Coil aimed at himself - same skill, cooldown and mana.
	var mist_coil_self: bool = skill_id == EnemySkillAI.MIST_COIL_SELF_ID
	if mist_coil_self:
		skill_id = "mist_coil"
	var skill: Dictionary = _find_enemy_skill(skill_id)
	var level: int = PlayerManager.get_npc_skill_level(_enemy_hero_id, skill_id)
	var level_data: Dictionary = GameManager.get_skill_level_data(skill, level)
	_enemy_skill_cooldowns[skill_id] = int(level_data.get("cooldown", 0))
	_enemy_current_mana -= float(level_data.get("mana_cost", 0))

	# Aimed at the player's Spirit Bear instead of the player? Each
	# bear-targetable _cast_enemy_*() below reads this first.
	_enemy_mist_coil_self = mist_coil_self
	_enemy_skill_on_bear = not mist_coil_self and ENEMY_BEAR_TARGETABLE_SKILLS.has(skill_id) and _choose_enemy_skill_on_bear(enemy, skill_id)

	match skill_id:
		"dark_pact":
			_cast_enemy_dark_pact(enemy, level_data)
		"pounce":
			_cast_enemy_pounce(enemy, level_data)
		"essence_shift":
			_activate_enemy_essence_shift(level_data)
		"shadow_dance":
			_activate_enemy_shadow_dance(level_data)
		"entangle":
			_cast_enemy_entangle(level_data)
		"summon_spirit_bear":
			_summon_enemy_spirit_bear(level_data)
		"spirit_link":
			_activate_enemy_spirit_link(level_data)
		"true_form":
			_activate_enemy_true_form(enemy, level_data)
		"mist_coil":
			_cast_enemy_mist_coil(enemy, level_data)
		"aphotic_shield":
			_activate_enemy_aphotic_shield(enemy, level_data)
		"torrent":
			_cast_enemy_torrent(level_data)
		"x_marks_the_spot":
			_cast_enemy_xmarks()
		"ghostship":
			_cast_enemy_ghostship(enemy, level_data)
		"cold_feet":
			_cast_enemy_cold_feet(level_data)
		"ice_vortex":
			_cast_enemy_ice_vortex(level_data)
		"chilling_touch":
			_cast_enemy_chilling_touch(enemy, level_data)
		"ice_blast":
			_cast_enemy_ice_blast(level_data)
		"arctic_burn":
			_cast_enemy_arctic_burn(level_data)
		"splinter_blast":
			_cast_enemy_splinter_blast(level_data)
		"cold_embrace":
			_cast_enemy_cold_embrace(level_data)
		"winter's_curse":
			_cast_enemy_winters_curse(level_data)
		"crystal_nova":
			_cast_enemy_crystal_nova(level_data)
		"frostbite":
			_cast_enemy_frostbite(level_data)
		"freezing_field":
			_cast_enemy_freezing_field(level_data)
		"ice_shards":
			_cast_enemy_ice_shards(enemy, level_data)
		"snowball":
			_cast_enemy_snowball(enemy, level_data)
		"tag_team":
			_cast_enemy_tag_team(level_data)
		"walrus_punch":
			_cast_enemy_walrus_punch(enemy, level_data)
		"nature's_guise":
			_activate_enemy_natures_guise(level_data)
		"leech_seed":
			_cast_enemy_leech_seed(level_data)
		"living_armor":
			_activate_enemy_living_armor(level_data)
		"overgrowth":
			_cast_enemy_overgrowth(enemy, level_data)
		"whirling_death":
			_cast_enemy_whirling_death(enemy, level_data)
		"timber_chain":
			_cast_enemy_timber_chain(enemy, level_data)
		"chakram":
			_cast_enemy_chakram(enemy, level_data)
		"scatterblast":
			_cast_enemy_scatterblast(enemy, level_data)
		"firesnap_cookie":
			_cast_enemy_firesnap_cookie(enemy, level_data)
		"lil_shredder":
			_cast_enemy_lil_shredder(enemy, level_data)
		"mortimer_kisses":
			_cast_enemy_mortimer_kisses(level_data)
		"mirror_image":
			_cast_enemy_mirror_image(enemy, level_data)
		"ensnare":
			_cast_enemy_ensnare(level_data)
		"song_of_the_siren":
			_cast_enemy_song_of_the_siren(enemy, level_data)
		"guardian_sprint":
			_cast_enemy_guardian_sprint(level_data)
		"slithereen_crush":
			_cast_enemy_slithereen_crush(enemy, level_data)
		"corrosive_haze":
			_cast_enemy_corrosive_haze(level_data)
		"starstorm":
			_cast_enemy_starstorm(enemy, level_data)
		"sacred_arrow":
			_cast_enemy_sacred_arrow(enemy, level_data)
		"leap":
			_cast_enemy_leap(enemy, level_data)
		"moonlight_shadow":
			_cast_enemy_moonlight_shadow(level_data)
		"lucent_beam":
			_cast_enemy_lucent_beam(level_data)
		"eclipse":
			_cast_enemy_eclipse(level_data)

	# Shadow Dance/Nature's Guise only break from casting ANOTHER skill
	# (or attacking, handled separately in _resolve_enemy_hero_attack()),
	# never from a cast/recast of themselves - mirrors the player's own
	# _on_skill_pressed(). Only one of the two could ever be active at
	# once (different heroes' kits), so this just ends whichever one
	# actually is.
	_enemy_skill_on_bear = false
	_enemy_mist_coil_self = false

	if _enemy_shadow_dance_active and skill_id != "shadow_dance":
		_end_enemy_shadow_dance()
	if _enemy_natures_guise_active and skill_id != "nature's_guise":
		_end_enemy_natures_guise()
	# Sacred Arrow is deliberately exempt - mirrors the player's own
	# _on_skill_pressed(), where a TARGETED skill's deferred-spend path
	# (_resolve_sacred_arrow_cast()) never reaches the equivalent check at
	# all, so firing Sacred Arrow from stealth never breaks it there
	# either (see EnemySkillAI's own _mirana_moonlight_shadow_modifier()'s
	# docstring for why this matters to scoring, not just execution).
	if _enemy_moonlight_shadow_active and skill_id != "moonlight_shadow" and skill_id != "sacred_arrow":
		_end_enemy_moonlight_shadow()

	# After Shadow Dance's own break above, so the caster's modulate is
	# already back to opaque before the flash reads/writes it.
	_play_enemy_cast_feedback(enemy, skill)

	_refresh_bars()


# ------------------------------------------------------------------
# Enemy hero skill cast feedback - a scale/brightness pulse on the
# caster, a floating cast-name banner over it, a frost screen tint for
# Winter's Curse/Frostbite/Ice Blast specifically (their own lingering
# "ambient reminder" while still active lives in _refresh_status_
# effects() instead, since that has to persist past this one moment),
# and extra weight (a bigger pulse plus a screen shake) for ultimates.
# All driven from _cast_enemy_skill() so every enemy hero skill gets
# this for free.
# ------------------------------------------------------------------

const FROST_TINT_SKILL_IDS := ["winter's_curse", "frostbite", "ice_blast"]
const FROST_TINT_COLOR := Color(0.55, 0.85, 1.0)


func _play_enemy_cast_feedback(enemy: Dictionary, skill: Dictionary) -> void:
	var node: TextureRect = enemy["node"]
	var is_ultimate: bool = skill.get("type", "") == "ultimate"

	_pulse_caster_sprite(node, is_ultimate)
	_show_message_over_enemy(node, skill.get("name", ""))

	if skill.get("id", "") in FROST_TINT_SKILL_IDS:
		_flash_screen_tint(FROST_TINT_COLOR, 0.32 if is_ultimate else 0.2, 0.5)

	if is_ultimate:
		_shake_screen()


## A quick scale-up + brightness flash on `node`, back to normal -
## reads as "this caster just did something," bigger and brighter for
## an ultimate than a standard cast.
func _pulse_caster_sprite(node: TextureRect, big: bool) -> void:
	node.pivot_offset = node.size / 2.0
	var peak_scale: float = 1.28 if big else 1.12
	var base_scale: Vector2 = node.get_meta("base_scale", Vector2.ONE)
	var base_modulate: Color = node.modulate
	var flash_modulate: Color = Color(1.6, 1.6, 1.6, base_modulate.a)

	var tween := create_tween()
	tween.tween_property(node, "scale", base_scale * peak_scale, 0.12).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(node, "modulate", flash_modulate, 0.12)
	tween.tween_property(node, "scale", base_scale, 0.18).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(node, "modulate", base_modulate, 0.18)


## Same quick scale-up + flash shape as _pulse_caster_sprite() above, but
## tinted red (BOUNCE_HIT_FLASH_COLOR) instead of brightened white -
## reads as "this sprite just got hit" rather than "this sprite just did
## something." Used by Moon Glaives' own bounce (_apply_moon_glaives_
## bounces()) so a bounced enemy visibly flashes red instead of only a
## damage number appearing on an enemy that was never the main target.
##
## `flash_color` defaults to that red; Entangle passes
## ENTANGLE_FLASH_COLOR for the same pop in green.
func _flash_bounce_hit(node: TextureRect, flash_color: Color = BOUNCE_HIT_FLASH_COLOR) -> void:
	node.pivot_offset = node.size / 2.0
	var base_scale: Vector2 = node.get_meta("base_scale", Vector2.ONE)
	var base_modulate: Color = node.modulate

	var tween := create_tween()
	tween.tween_property(node, "scale", base_scale * 1.12, 0.12).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(node, "modulate", flash_color, 0.12)
	tween.tween_property(node, "scale", base_scale, 0.18).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(node, "modulate", base_modulate, 0.18)


## Purely cosmetic: Entangle's cast visual on `node` (an enemy, or the
## player's own hero_image when a rival casts it) - a burst of green
## leaves springing up from its feet plus a green version of the hit
## flash. The root itself has already been applied by the time this
## plays; the lingering tint afterwards is _refresh_entangle_tints()'s.
## Same CPUParticles2D one-shot-burst recipe as
## _spawn_lil_shredder_impact().
func _play_entangle_effect(node: TextureRect) -> void:
	_flash_bounce_hit(node, ENTANGLE_FLASH_COLOR)

	var lifetime: float = 0.7
	var particles := CPUParticles2D.new()
	particles.position = node.position + Vector2(node.size.x / 2.0, node.size.y * 0.85)
	particles.emitting = false
	particles.one_shot = true
	particles.amount = 26
	particles.lifetime = lifetime
	particles.explosiveness = 0.9
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	particles.emission_rect_extents = Vector2(node.size.x * 0.3, 4.0)
	particles.direction = Vector2(0, -1)
	particles.spread = 35.0
	# Leaves shoot up, then drift back down.
	particles.gravity = Vector2(0, 260)
	particles.initial_velocity_min = 110.0
	particles.initial_velocity_max = 200.0
	particles.angle_min = 0.0
	particles.angle_max = 360.0
	particles.angular_velocity_min = -240.0
	particles.angular_velocity_max = 240.0
	particles.scale_amount_min = 4.0
	particles.scale_amount_max = 7.0
	particles.color = Color(0.35, 0.85, 0.3, 1.0)
	particles.hue_variation_min = -0.06
	particles.hue_variation_max = 0.06
	add_child(particles)
	# Same reasoning as _play_scatterblast_effect()'s own move_child()
	# call - render at the hero/enemy layer, not on top of every UI panel.
	move_child(particles, enemies_layer.get_index() + 1)
	particles.emitting = true

	get_tree().create_timer(lifetime + 0.2).timeout.connect(particles.queue_free)


## Keeps Entangle's lingering green tint in sync with who's actually
## entangled right now - called from _refresh_bars() (i.e. constantly),
## so the tint just follows current state instead of being toggled at
## every cast/tick/dispel/reset site, same approach as
## _refresh_status_effects(). "Entangled" = rooted AND still carrying
## Entangle's own DoT, so Ensnare's/Overgrowth's plain roots (which
## never set the Entangle DoT) don't pick up the tint.
func _refresh_entangle_tints() -> void:
	for enemy in _enemies:
		var entangled: bool = enemy.get("root_turns_left", 0) > 0 and enemy.get("entangle_dot_turns_left", 0) > 0
		_set_entangle_tint(enemy.get("node"), entangled)
	_set_entangle_tint(hero_image, _player_root_turns_left > 0 and _player_entangle_dot_turns_left > 0)
	if _is_bear_alive():
		_set_entangle_tint(_bear.get("node"), int(_bear.get("root_turns_left", 0)) > 0 and int(_bear.get("entangle_dot_turns_left", 0)) > 0)


## Keeps the frost in sync with who's currently frozen by Cold Feet's,
## Ice Vortex's, Ice Blast's OR Frostbite's DoT, or held by Winter's
## Curse's freeze (for as long as its stun lasts), or encased by their
## own Cold Embrace (the caster - the player or the rival - for as long
## as it's active) - every enemy (their own cold_feet_dot_turns_left/
## ice_vortex_dot_turns_left) and the player's hero (the matching
## _player_* counters, from a rival's cast). Both skills share the one
## frost look, so being marked by both never stacks two. Called from
## _refresh_bars() (i.e. constantly), same approach as
## _refresh_entangle_tints(), so the frost just follows current state
## instead of being toggled at every cast/tick/dispel site.
func _refresh_cold_feet_frost() -> void:
	for enemy in _enemies:
		var frozen: bool = enemy.get("cold_feet_dot_turns_left", 0) > 0 or enemy.get("ice_vortex_dot_turns_left", 0) > 0 \
			or enemy.get("ice_blast_dot_turns_left", 0) > 0 or enemy.get("frostbite_dot_turns_left", 0) > 0 \
			or (is_same(enemy, _winter_curse_target) and _is_winters_curse_active()) \
			or (_enemy_cold_embrace_active and enemy["static"].get("is_hero_fight_boss", false))
		_set_cold_feet_frost(enemy.get("node"), frozen)
	_set_cold_feet_frost(hero_image, _player_cold_feet_dot_turns_left > 0 or _player_ice_vortex_dot_turns_left > 0 \
		or _player_ice_blast_dot_turns_left > 0 or _player_frostbite_dot_turns_left > 0 or _player_winters_curse_active \
		or _cold_embrace_active)
	# Illusions (either side) can only ever carry Ice Vortex's DoT,
	# never Cold Feet's - a single-target cast never lands on one. The
	# player's own Spirit Bear can carry either (a rival can aim Cold
	# Feet at it - see _cast_enemy_cold_feet_on_bear()).
	for illusion in _illusions + _enemy_illusions:
		_set_cold_feet_frost(illusion.get("node"), illusion.get("ice_vortex_dot_turns_left", 0) > 0)
	if _is_bear_alive():
		var bear_frozen: bool = int(_bear.get("cold_feet_dot_turns_left", 0)) > 0 or int(_bear.get("ice_vortex_dot_turns_left", 0)) > 0 \
			or int(_bear.get("ice_blast_dot_turns_left", 0)) > 0 or int(_bear.get("frostbite_dot_turns_left", 0)) > 0 \
			or (bool(_bear.get("winters_curse_active", false)) and int(_bear.get("stun_turns_left", 0)) > 0)
		_set_cold_feet_frost(_bear.get("node"), bear_frozen)


## Purely cosmetic: Ice Vortex's cast - a ring of ice crystals swirling
## outward from `center_node`, sized to reach about `radius` columns (at
## least half a column, so a radius-0 cast still reads), spinning as
## they go. The lingering frost on everyone caught is
## _refresh_cold_feet_frost()'s. Same CPUParticles2D one-shot-burst
## recipe as _spawn_lil_shredder_impact(), with tangential acceleration
## for the swirl.
func _play_ice_vortex_swirl(center_node: Variant, radius: int) -> void:
	if not (center_node is Control) or not is_instance_valid(center_node):
		return

	var lifetime: float = 0.9
	var reach: float = _grid_unit() * maxf(0.5, float(radius))
	var particles := CPUParticles2D.new()
	particles.position = center_node.position + center_node.size / 2.0
	particles.emitting = false
	particles.one_shot = true
	particles.amount = 60
	particles.lifetime = lifetime
	particles.explosiveness = 0.8
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 10.0
	particles.spread = 180.0
	particles.gravity = Vector2.ZERO
	particles.initial_velocity_min = reach / lifetime * 0.5
	particles.initial_velocity_max = reach / lifetime * 0.9
	particles.tangential_accel_min = 180.0
	particles.tangential_accel_max = 260.0
	particles.damping_min = 20.0
	particles.damping_max = 40.0
	particles.angle_min = 0.0
	particles.angle_max = 360.0
	particles.angular_velocity_min = -270.0
	particles.angular_velocity_max = 270.0
	particles.scale_amount_min = 2.5
	particles.scale_amount_max = 5.5
	particles.color = COLD_FEET_FLAKE_COLOR
	particles.hue_variation_min = -0.04
	particles.hue_variation_max = 0.04
	add_child(particles)
	# Same reasoning as _play_scatterblast_effect()'s own move_child()
	# call - render at the hero/enemy layer, not on top of every UI panel.
	move_child(particles, enemies_layer.get_index() + 1)
	particles.emitting = true

	get_tree().create_timer(lifetime + 0.2).timeout.connect(particles.queue_free)


## Purely cosmetic: frosts `node` (any unit's sprite) for `seconds`
## regardless of any DoT - the icy flash plus the same frost Cold Feet/
## Ice Vortex/Ice Blast/Frostbite leave, which then fades on its own.
## Used by Crystal Nova, a single burst with nothing lingering to tie
## the frost to. If a DoT-driven frost is also on the unit, whichever
## lasts longer wins - the timed hold only ever keeps frost on, never
## takes it off early.
func _flash_frost_briefly(node: Variant, seconds: float) -> void:
	if not (node is TextureRect) or not is_instance_valid(node):
		return
	node.set_meta("frost_hold_until_msec", Time.get_ticks_msec() + int(seconds * 1000.0))
	_flash_bounce_hit(node, COLD_FEET_FLASH_COLOR)
	_set_cold_feet_frost(node, true)
	# Re-evaluated once the hold runs out: stays frosted if a DoT is
	# still holding it, otherwise fades. A tween bound to this node (not
	# a SceneTree timer) so it dies with the battle scene if it closes
	# first.
	create_tween().tween_callback(_refresh_cold_feet_frost).set_delay(seconds + 0.05)


## Purely cosmetic: puts Cold Feet's frost on `node` - an enemy's node
## or the player's hero_image - (or takes it off):
## an additive icy-blue copy of the sprite for a frosty sheen that
## slowly shimmers, plus a few snowflakes drifting off it. Both live
## under one child Control, so they follow the sprite's position/
## scale/fades for free and fade in/out together. The shimmer's
## per-frame update also keeps the sheen's flip_h/texture in sync with
## the sprite, the same way Borrowed Time's glow does. Only does
## anything when the state actually changes (the child's presence is
## the "currently on" marker).
func _set_cold_feet_frost(node: Variant, active: bool) -> void:
	if not (node is TextureRect) or not is_instance_valid(node):
		return
	# A timed hold (Crystal Nova - see _flash_frost_briefly()) keeps the
	# frost up even when no DoT is holding it anymore, until it expires.
	if not active and Time.get_ticks_msec() < int(node.get_meta("frost_hold_until_msec", 0)):
		active = true
	var frost: Control = node.get_node_or_null(COLD_FEET_FROST_NAME)
	if active == (frost != null):
		return

	if not active:
		# Renamed right away so a quick re-mark during the fade creates a
		# fresh frost instead of finding this dying one.
		frost.name = COLD_FEET_FROST_NAME + "Fading"
		var shimmer: Variant = frost.get_meta("shimmer_tween", null)
		if shimmer is Tween and shimmer.is_valid():
			shimmer.kill()
		var flakes: CPUParticles2D = frost.get_meta("flakes", null)
		if is_instance_valid(flakes):
			flakes.emitting = false
		var fade: Tween = frost.create_tween()
		fade.tween_property(frost, "modulate:a", 0.0, 0.5)
		fade.tween_callback(frost.queue_free)
		return

	frost = Control.new()
	frost.name = COLD_FEET_FROST_NAME
	frost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frost.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frost.modulate.a = 0.0
	node.add_child(frost)

	var material := CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var sheen := TextureRect.new()
	sheen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sheen.material = material
	sheen.texture = node.texture
	sheen.expand_mode = node.expand_mode
	sheen.stretch_mode = node.stretch_mode
	sheen.flip_h = node.flip_h
	sheen.flip_v = node.flip_v
	sheen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sheen.self_modulate = COLD_FEET_SHEEN_COLOR
	frost.add_child(sheen)

	var flakes := CPUParticles2D.new()
	flakes.position = node.size / 2.0
	flakes.amount = 14
	flakes.lifetime = 1.4
	flakes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	flakes.emission_rect_extents = node.size * 0.35
	flakes.direction = Vector2(0, -1)
	flakes.spread = 60.0
	flakes.gravity = Vector2(0, 25)
	flakes.initial_velocity_min = 8.0
	flakes.initial_velocity_max = 22.0
	flakes.angle_min = 0.0
	flakes.angle_max = 360.0
	flakes.angular_velocity_min = -90.0
	flakes.angular_velocity_max = 90.0
	flakes.scale_amount_min = 2.0
	flakes.scale_amount_max = 4.0
	flakes.color = COLD_FEET_FLAKE_COLOR
	frost.add_child(flakes)
	flakes.emitting = true
	frost.set_meta("flakes", flakes)

	var fade_in: Tween = frost.create_tween()
	fade_in.tween_property(frost, "modulate:a", 1.0, 0.35)

	# 0 -> 1 is one full shimmer: dimmer -> brighter -> dimmer.
	var shimmer: Tween = frost.create_tween().set_loops()
	shimmer.tween_method(
		func(phase: float) -> void:
			if not is_instance_valid(node):
				return
			sheen.flip_h = node.flip_h
			sheen.texture = node.texture
			sheen.modulate.a = lerpf(0.35, 0.6, 0.5 - 0.5 * cos(phase * TAU)),
		0.0, 1.0, 1.8
	)
	frost.set_meta("shimmer_tween", shimmer)


## Fades `node`'s self_modulate to ENTANGLE_TINT_COLOR (or back to
## white) - only when the state actually changes, so the constant
## _refresh_bars() calls don't keep restarting tweens.
func _set_entangle_tint(node: Variant, entangled: bool) -> void:
	if not (node is CanvasItem) or not is_instance_valid(node):
		return
	var target_color: Color = ENTANGLE_TINT_COLOR if entangled else Color(1, 1, 1, 1)
	if node.self_modulate.is_equal_approx(target_color):
		return
	if bool(node.get_meta("entangle_tint_target", false)) == entangled and node.has_meta("entangle_tint_target"):
		return
	node.set_meta("entangle_tint_target", entangled)
	var tween: Tween = node.create_tween()
	tween.tween_property(node, "self_modulate", target_color, 0.3)


## Same floating/fading style as _show_message_over_hero(), just over
## `target_node` instead of always the player's own hero - so a rival's
## cast reads as something THEY did, not something that just happened
## to the player.
func _show_message_over_enemy(target_node: Control, text: String) -> void:
	if text == "":
		return

	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", Color(1, 0.85, 0.3, 1))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_font_size_override("font_size", 18)
	label.position = target_node.position + Vector2(target_node.size.x / 2.0 - 60, -10)
	enemies_layer.add_child(label)

	var tween := create_tween()
	tween.tween_interval(MESSAGE_READ_HOLD_DURATION)
	tween.tween_property(label, "position:y", label.position.y - 40, 0.8)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.8)
	tween.finished.connect(label.queue_free)


## A brief full-screen color flash (fade in, fade out) on
## cast_flash_overlay - separate from ambient_tint_overlay's own
## persistent tint (see _refresh_status_effects()) so the two never
## fight over the same tween.
func _flash_screen_tint(color: Color, peak_alpha: float, duration: float) -> void:
	cast_flash_overlay.color = Color(color.r, color.g, color.b, 0.0)

	var tween := create_tween()
	tween.tween_property(cast_flash_overlay, "color:a", peak_alpha, duration * 0.3)
	tween.tween_property(cast_flash_overlay, "color:a", 0.0, duration * 0.7)


## A short, small random-jitter shake of the whole battle view - the
## "impact weight" cue for an enemy hero's ultimate.
func _shake_screen() -> void:
	var base_position: Vector2 = position
	var tween := create_tween()
	for i in range(5):
		var offset := Vector2(randf_range(-6.0, 6.0), randf_range(-6.0, 6.0))
		tween.tween_property(self, "position", base_position + offset, 0.03)
	tween.tween_property(self, "position", base_position, 0.03)


## Dark Pact only ever has one possible target here (there's no other
## enemy for the rival to hit besides the player), unlike the player's
## own _cast_dark_pact() which has to scan multiple enemies - so this
## just hits. The radius check against the player's distance already
## happened before this skill was even picked (see
## _enemy_skill_in_range()/EnemySkillRange), so by the time this runs
## the player is guaranteed to be in range.
func _cast_enemy_dark_pact(enemy: Dictionary, level_data: Dictionary) -> void:
	var multiplier: float = float(level_data.get("damage_multiplier", 0.75))
	var pact_damage: float = _roll_enemy_hero_damage(enemy) * multiplier
	apply_damage(pact_damage)
	# Same red hit-flash the player's own Dark Pact gives every enemy it
	# catches (see _cast_dark_pact()).
	_flash_bounce_hit(hero_image)
	# Dark Pact is centered on the CASTER's own column, not the
	# player's - an illusion standing near the rival (not necessarily
	# near the hero) can still be caught in it.
	_deal_aoe_damage_to_illusions(enemy["pos_index"], int(level_data.get("radius", 0)), pact_damage, true)
	_deal_aoe_damage_to_bear(enemy["pos_index"], int(level_data.get("radius", 0)), pact_damage, true)


func _cast_enemy_pounce(enemy: Dictionary, level_data: Dictionary) -> void:
	var direction: int = _step_toward(enemy["pos_index"], _hero_pos_index)
	if direction == 0:
		direction = 1

	var move_distance: int = int(level_data.get("distance", 2))
	var pos: int = enemy["pos_index"]
	var hit_hero: bool = false

	for i in range(move_distance):
		var next_pos: int = pos + direction
		if next_pos < 0 or next_pos >= GRID_COLUMNS:
			break
		# The player's own Ice Shards wall stops the leap dead, same
		# "can't jump past a wall in its path" rule the player's own
		# Pounce follows now (see _cast_pounce()).
		if _is_column_ice_shards_blocked(next_pos):
			break
		pos = next_pos
		if pos == _hero_pos_index:
			hit_hero = true
			break

	_move_enemy(enemy, pos)

	if hit_hero:
		apply_damage(_roll_enemy_hero_damage(enemy))
		_player_stun_turns_left = int(level_data.get("stun_turns", 1))
		_show_message_over_hero("Stunned!")


# ------------------------------------------------------------------
# Slark's Essence Shift, cast by the rival at the player - mirrors the
# player's own _activate_essence_shift()/_tick_essence_shift()/
# _end_essence_shift(), just draining a battle-local penalty on the
# player (_player_essence_shift_penalty) instead of a battle-local
# counter on an enemy, since the player has no such counter to drain.
# ------------------------------------------------------------------

func _activate_enemy_essence_shift(level_data: Dictionary) -> void:
	if _enemy_essence_shift_active:
		_end_enemy_essence_shift()
	_enemy_essence_shift_active = true
	_enemy_essence_shift_attacks_remaining = int(level_data.get("attacks", 0))
	_enemy_essence_shift_turns_remaining = int(level_data.get("duration", 0))
	_enemy_essence_shift_duration_pending_start = true


## Steals one point of the player's own main stat, converting it into
## the same hp/armor/mana contribution (plus damage, since the stolen
## stat is always the player's own main stat by definition) that the
## same point would be worth on the player's side of the fight -
## mirrors _essence_shift_contribution_for(), just applied as a
## penalty to the player instead of a bonus to whoever cast it.
##
## Simplification versus the player's own copy: there's no floor on
## how much can be drained from the player the way enemies' battle-
## local main-stat counters bottom out at
## GameManager.ESSENCE_SHIFT_MIN_ENEMY_MAIN_STAT, since the player has
## no such counter - a hero fight is expected to resolve in far fewer
## turns than it'd take for this to matter in practice.
func _apply_enemy_essence_shift_steal(enemy: Dictionary) -> void:
	if not _enemy_essence_shift_active or _enemy_essence_shift_attacks_remaining <= 0:
		return

	var stat_name: String = str(_hero_static.get("main_stat", "")).to_lower()
	if stat_name == "":
		return

	_enemy_essence_shift_attacks_remaining -= 1

	match stat_name:
		"strength":
			_player_essence_shift_penalty["hp"] = _player_essence_shift_penalty.get("hp", 0.0) + GameManager.HP_PER_STRENGTH
		"agility":
			_player_essence_shift_penalty["armor"] = _player_essence_shift_penalty.get("armor", 0.0) + GameManager.ARMOR_PER_AGILITY
		"intelligence":
			_player_essence_shift_penalty["mana"] = _player_essence_shift_penalty.get("mana", 0.0) + GameManager.MANA_PER_INTELLIGENCE
	_player_essence_shift_penalty["damage"] = _player_essence_shift_penalty.get("damage", 0.0) + GameManager.DAMAGE_PER_MAIN_STAT

	var enemy_contribution: Dictionary = _enemy_essence_shift_contribution_for(stat_name)
	for stat_key in enemy_contribution.keys():
		_enemy_essence_shift_bonus[stat_key] = _enemy_essence_shift_bonus.get(stat_key, 0.0) + enemy_contribution[stat_key]

	_play_drain_effect(hero_image, enemy.get("node"), ESSENCE_SHIFT_MOTE_COLOR)
	_refresh_bars()


## What the RIVAL gains from stealing one point of `stat_name` - the
## same conversion table as _essence_shift_contribution_for(), just
## checked against the rival's own main stat (rather than the
## player's) for the extra-damage condition.
func _enemy_essence_shift_contribution_for(stat_name: String) -> Dictionary:
	var contribution: Dictionary = {"damage": 0.0, "hp": 0.0, "mana": 0.0, "armor": 0.0}

	match stat_name:
		"strength":
			contribution["hp"] = GameManager.HP_PER_STRENGTH
		"agility":
			contribution["armor"] = GameManager.ARMOR_PER_AGILITY
		"intelligence":
			contribution["mana"] = GameManager.MANA_PER_INTELLIGENCE

	if stat_name == str(_enemy_hero_static.get("main_stat", "")).to_lower():
		contribution["damage"] = GameManager.DAMAGE_PER_MAIN_STAT

	return contribution


func _tick_enemy_essence_shift() -> void:
	if not _enemy_essence_shift_active:
		return
	if _enemy_essence_shift_duration_pending_start:
		_enemy_essence_shift_duration_pending_start = false
		return
	_enemy_essence_shift_turns_remaining -= 1
	if _enemy_essence_shift_turns_remaining <= 0:
		_end_enemy_essence_shift()


func _end_enemy_essence_shift() -> void:
	_player_essence_shift_penalty = {"damage": 0.0, "hp": 0.0, "mana": 0.0, "armor": 0.0}
	_enemy_essence_shift_bonus = {"damage": 0.0, "hp": 0.0, "mana": 0.0, "armor": 0.0}
	_enemy_essence_shift_active = false
	_enemy_essence_shift_attacks_remaining = 0
	_enemy_essence_shift_turns_remaining = 0
	_enemy_essence_shift_duration_pending_start = false
	_refresh_bars()


# ------------------------------------------------------------------
# Slark's Shadow Dance, cast by the rival on themselves - mirrors the
# player's own _activate_shadow_dance()/_tick_shadow_dance()/
# _end_shadow_dance(). "Hidden" here means the player's attacks and
# targeted skills can't select them at all (_is_target_hidden(),
# checked from _get_enemy_at()/_start_ranged_targeting()/
# _start_entangle_targeting()/_cast_dark_pact()) - their own turn
# proceeds completely normally while hidden.
# ------------------------------------------------------------------

func _activate_enemy_shadow_dance(level_data: Dictionary) -> void:
	_enemy_shadow_dance_active = true
	_enemy_shadow_dance_bonus_damage = float(level_data.get("bonus_damage", 0))
	_enemy_shadow_dance_turns_remaining = int(level_data.get("duration", 0))
	_enemy_shadow_dance_duration_pending_start = true
	_update_enemy_hero_visibility()


func _tick_enemy_shadow_dance() -> void:
	if not _enemy_shadow_dance_active:
		return
	if _enemy_shadow_dance_duration_pending_start:
		_enemy_shadow_dance_duration_pending_start = false
		return
	_enemy_shadow_dance_turns_remaining -= 1
	if _enemy_shadow_dance_turns_remaining <= 0:
		_end_enemy_shadow_dance()


func _end_enemy_shadow_dance() -> void:
	_enemy_shadow_dance_active = false
	_enemy_shadow_dance_bonus_damage = 0.0
	_enemy_shadow_dance_turns_remaining = 0
	_enemy_shadow_dance_duration_pending_start = false
	_update_enemy_hero_visibility()


## Fades the boss's own enemy node while hidden, the same visual cue
## the player's own Shadow Dance gives his portrait - just as a direct
## modulate on the enemy TextureRect rather than a dedicated node,
## since a hero-fight boss is otherwise a completely ordinary entry in
## _enemies.
func _update_enemy_hero_visibility() -> void:
	var boss: Dictionary = _get_hero_fight_boss()
	if boss.is_empty() or not is_instance_valid(boss["node"]):
		return
	var hidden: bool = _enemy_shadow_dance_active or _enemy_natures_guise_active or _enemy_moonlight_shadow_active
	boss["node"].modulate = Color(1, 1, 1, 0.4) if hidden else Color(1, 1, 1, 1)


# ------------------------------------------------------------------
# Lone Druid's Entangle, cast by the rival on the player - mirrors
# _apply_root(), just aimed at the player instead of an enemy. There's
# only one possible target (the player),
# so no targeting step is needed the way the player's own Entangle
# needs _start_entangle_targeting()/_resolve_entangle_cast().
# ------------------------------------------------------------------

func _cast_enemy_entangle(level_data: Dictionary) -> void:
	if _enemy_skill_on_bear:
		_cast_enemy_entangle_on_bear(level_data)
		return
	_player_root_turns_left = int(level_data.get("root_turns", 0))
	_player_silence_turns_left = int(level_data.get("silence_turns", 0))
	_player_entangle_dot_damage = float(level_data.get("dot_damage", 0))
	_player_entangle_dot_turns_left = int(level_data.get("dot_duration", 0))
	_show_message_over_hero("Entangled!")
	_play_entangle_effect(hero_image)
	_refresh_entangle_tints()



# ------------------------------------------------------------------
# Lone Druid's Summon Spirit Bear, cast by the rival - spawned as a
# genuine extra entry in _enemies via the normal _spawn_enemy() path,
# so it automatically gets real movement/attack behavior, a real
# position on the board, and can be fought and killed by the player
# like anything else, all for free. XP/gold are zeroed out so killing
# it doesn't reward anything beyond clearing it out of the way - only
# the rival hero itself is worth a bounty.
#
# Simplification versus the player's own Spirit Bear: defeating the
# boss requires _enemies to be empty (see _handle_victory()), so as
# long as this bear is alive the fight isn't over even after the
# rival hero itself has been reduced to 0 HP and removed - the same
# way any other enemy sharing the field would keep a fight going.
# ------------------------------------------------------------------

func _summon_enemy_spirit_bear(level_data: Dictionary) -> void:
	_despawn_enemy_spirit_bear()

	var damage_min: float = float(level_data.get("damage_min", 0))
	var damage_max: float = float(level_data.get("damage_max", 0))

	_spawn_enemy({
		"id": "enemy_spirit_bear",
		"name": "Spirit Bear",
		"image": SPIRIT_BEAR_IMAGE_PATH,
		"type": "mele",
		"hp": float(level_data.get("hp", 1)),
		"damage": roundi((damage_min + damage_max) / 2.0),
		"armor": float(level_data.get("armor", 0)),
		"XP": 0,
		"gold": "0-0",
		# Same art the player's own Spirit Bear uses is drawn facing
		# right (toward wherever it's an ally of); placed on the enemy
		# side here, it needs the same left-facing flip hero portraits
		# get - see _spawn_enemy()'s use of this flag.
		"is_hero_fight": true,
		"is_enemy_spirit_bear": true,
	})


func _despawn_enemy_spirit_bear() -> void:
	for existing in _enemies.duplicate():
		if existing["static"].get("is_enemy_spirit_bear", false):
			if is_instance_valid(existing["node"]):
				existing["node"].queue_free()
			if is_instance_valid(existing.get("hp_label")):
				existing["hp_label"].queue_free()
			if is_instance_valid(existing.get("status_label")):
				existing["status_label"].queue_free()
			_enemies.erase(existing)
	_refresh_enemy_overhead_labels()


# ------------------------------------------------------------------
# Lone Druid's Spirit Link, cast by the rival on themselves - mirrors
# _activate_spirit_link()/_tick_spirit_link()/_end_spirit_link()/
# _apply_spirit_link_lifesteal().
# ------------------------------------------------------------------

func _activate_enemy_spirit_link(level_data: Dictionary) -> void:
	_enemy_spirit_link_active = true
	_enemy_spirit_link_lifesteal_pct = float(level_data.get("lifesteal_pct", 0.0))
	_enemy_spirit_link_bonus_armor = float(level_data.get("bonus_armor", 0))
	_enemy_spirit_link_turns_remaining = int(level_data.get("duration", 0))
	_enemy_spirit_link_duration_pending_start = true
	_set_spirit_link_visual(_get_hero_fight_boss().get("node"), true)


func _tick_enemy_spirit_link() -> void:
	if not _enemy_spirit_link_active:
		return
	if _enemy_spirit_link_duration_pending_start:
		_enemy_spirit_link_duration_pending_start = false
		return
	_enemy_spirit_link_turns_remaining -= 1
	if _enemy_spirit_link_turns_remaining <= 0:
		_end_enemy_spirit_link()


func _end_enemy_spirit_link() -> void:
	_enemy_spirit_link_active = false
	_enemy_spirit_link_lifesteal_pct = 0.0
	_enemy_spirit_link_bonus_armor = 0.0
	_enemy_spirit_link_turns_remaining = 0
	_enemy_spirit_link_duration_pending_start = false
	_set_spirit_link_visual(_get_hero_fight_boss().get("node"), false)


## Only ever called for the plain basic-attack branch of the rival's
## turn - like the player's own copy, skill damage (Dark Pact, Pounce,
## Entangle's DoT) never triggers this. Heals the boss directly,
## clamped to their current effective max hp.
func _apply_enemy_spirit_link_lifesteal(enemy: Dictionary, mitigated_attack_damage: float) -> void:
	if not _enemy_spirit_link_active or mitigated_attack_damage <= 0.0:
		return
	var heal_amount: float = mitigated_attack_damage * _enemy_spirit_link_lifesteal_pct
	var max_hp: float = _enemy_hero_effective_max_hp(enemy)
	enemy["current_hp"] = minf(max_hp, enemy["current_hp"] + heal_amount)
	_play_drain_effect(hero_image, enemy.get("node"), SPIRIT_LINK_MOTE_COLOR)


# ------------------------------------------------------------------
# Lone Druid's True Form (ultimate), cast by the rival on themselves -
# mirrors _activate_true_form()/_tick_true_form()/_end_true_form().
# No forced-melee-range concept here (a hero-fight boss is already
# always attacking in melee or at range per its own "type", same as
# any other enemy) - just the bonus hp/damage, plus swapping the
# boss's own node texture the same way the player's portrait swaps.
# ------------------------------------------------------------------

func _activate_enemy_true_form(enemy: Dictionary, level_data: Dictionary) -> void:
	if _enemy_true_form_active:
		_end_enemy_true_form()
	_enemy_true_form_active = true
	_enemy_true_form_bonus_hp = float(level_data.get("bonus_hp", 0))
	_enemy_true_form_bonus_damage = float(level_data.get("bonus_damage", 0))
	_enemy_true_form_turns_remaining = int(level_data.get("duration", 0))
	_enemy_true_form_duration_pending_start = true

	if ResourceLoader.exists(TRUE_FORM_IMAGE_PATH) and is_instance_valid(enemy["node"]):
		enemy["node"].texture = load(TRUE_FORM_IMAGE_PATH)


func _tick_enemy_true_form() -> void:
	if not _enemy_true_form_active:
		return
	if _enemy_true_form_duration_pending_start:
		_enemy_true_form_duration_pending_start = false
		return
	_enemy_true_form_turns_remaining -= 1
	if _enemy_true_form_turns_remaining <= 0:
		_end_enemy_true_form()


func _end_enemy_true_form() -> void:
	_enemy_true_form_active = false
	_enemy_true_form_bonus_hp = 0.0
	_enemy_true_form_bonus_damage = 0.0
	_enemy_true_form_turns_remaining = 0
	_enemy_true_form_duration_pending_start = false

	var boss: Dictionary = _get_hero_fight_boss()
	if boss.is_empty() or not is_instance_valid(boss["node"]):
		return
	var original_image: String = str(boss["static"].get("image", ""))
	if original_image != "" and ResourceLoader.exists(original_image):
		boss["node"].texture = load(original_image)


# ------------------------------------------------------------------
# Lone Druid's Savage Roar (passive), on the rival - mirrors
# _get_savage_roar_level_data()/_update_savage_roar_state(), same
# hysteresis: switches on once HP drops below 50%, stays on through
# the climb back up until HP reaches 80%. Re-evaluated once at the
# start of the rival's own turn (see _enemy_hero_turn()) rather than
# after every HP change, since there's no bars UI to keep live for an
# enemy the way _refresh_bars() does for the player.
# ------------------------------------------------------------------

func _get_enemy_savage_roar_level_data() -> Dictionary:
	if _enemy_hero_id == "":
		return {}
	var level: int = PlayerManager.get_npc_skill_level(_enemy_hero_id, "savage_roar")
	if level <= 0:
		return {}
	var skill: Dictionary = _find_enemy_skill("savage_roar")
	if skill.is_empty():
		return {}
	return GameManager.get_skill_level_data(skill, level)


func _update_enemy_savage_roar_state(enemy: Dictionary) -> void:
	var level_data: Dictionary = _get_enemy_savage_roar_level_data()

	if level_data.is_empty():
		_enemy_savage_roar_active = false
	else:
		var max_hp: float = _enemy_hero_effective_max_hp(enemy)
		var hp_pct: float = float(enemy.get("current_hp", 0)) / max_hp if max_hp > 0.0 else 0.0
		if _enemy_savage_roar_active:
			if hp_pct >= 0.8:
				_enemy_savage_roar_active = false
		elif hp_pct < 0.5:
			_enemy_savage_roar_active = true

	_enemy_savage_roar_damage_reduction_pct = float(level_data.get("damage_reduction_pct", 0.0)) if _enemy_savage_roar_active else 0.0


# ------------------------------------------------------------------
# Abaddon's Mist Coil and Aphotic Shield, cast by the rival at (or on
# behalf of) himself - mirrors the player's own
# _resolve_mist_coil_enemy_cast()/_activate_aphotic_shield()/
# _tick_aphotic_shield()/_end_aphotic_shield(). Mist Coil goes either
# way, same as the player's own copy: a hit on the player (or his
# bear), or - picked by EnemySkillAI as its own "mist_coil_self"
# candidate when he's hurt - a self-heal (_cast_enemy_mist_coil_on_
# self()).
# ------------------------------------------------------------------

func _cast_enemy_mist_coil(enemy: Dictionary, level_data: Dictionary) -> void:
	if _enemy_mist_coil_self:
		_cast_enemy_mist_coil_on_self(enemy, level_data)
		return
	if _enemy_skill_on_bear:
		_cast_enemy_mist_coil_on_bear(enemy, level_data)
		return
	_play_mist_coil_effect(enemy.get("node"), hero_image)
	apply_damage(float(level_data.get("damage", 0)))


## Purely cosmetic: Mist Coil's glowing green ball, flying on a slight
## arc from `from_node` (the caster) to `to_node` (the target), trailing
## green sparks, then bursting in green and flashing the target on
## arrival. When both are the same node (Abaddon's self-cast heal) the
## ball drops onto him from above his head instead. The damage/heal has
## already been applied by the time this plays; it never gates on it.
## Start/end points are captured up front, so a target killed by the
## hit still gets its ball and burst, just no flash.
func _play_mist_coil_effect(from_node: Variant, to_node: Variant) -> void:
	_play_orb_projectile(from_node, to_node, MIST_COIL_COLOR, MIST_COIL_COLOR, MIST_COIL_FLASH_COLOR, 22.0)


## The shared glowing-ball projectile behind Mist Coil's and Ice
## Blast's own visuals: a ball of `color` (rimmed in `rim_color`) flies
## on a slight upward arc from `from_node` to `to_node`, trailing sparks,
## then bursts (_play_orb_impact()) and flashes the target in
## `flash_color`. Everything scales off `ball_size` - its glow, trail
## and burst - so a bigger ball reads as a heavier hit. When both nodes
## are the same (Mist Coil's self-cast) it drops from above instead.
## Start/end points are captured up front, so a target killed by the
## hit still gets its ball and burst, just no flash.
func _play_orb_projectile(from_node: Variant, to_node: Variant, color: Color, rim_color: Color, flash_color: Color, ball_size: float) -> void:
	if not (from_node is Control) or not (to_node is Control):
		return
	if not is_instance_valid(from_node) or not is_instance_valid(to_node):
		return
	var size_scale: float = ball_size / 22.0

	var end: Vector2 = to_node.position + to_node.size / 2.0
	var start: Vector2 = from_node.position + from_node.size / 2.0
	if from_node == to_node:
		start = end - Vector2(0, to_node.size.y * 0.9)
	var travel: Vector2 = end - start
	var normal: Vector2 = Vector2(-travel.y, travel.x).normalized() if travel.length() > 0.001 else Vector2.UP
	# Always bulge upward, whichever way it's flying.
	if normal.y > 0.0:
		normal = -normal
	var control_point: Vector2 = (start + end) / 2.0 + normal * minf(60.0, travel.length() * 0.2)
	# A bigger ball travels a little slower, so it reads as heavier.
	var flight_time: float = clampf(travel.length() / (900.0 / sqrt(size_scale)), 0.3, 0.6 * sqrt(size_scale))

	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = rim_color
	style.set_border_width_all(maxi(0, int(size_scale) - 1))
	style.set_corner_radius_all(int(ceilf(ball_size / 2.0)))
	style.corner_detail = 16
	# The glow.
	style.shadow_color = Color(color.r, color.g, color.b, 0.6)
	style.shadow_size = int(10 * size_scale)
	var ball := Panel.new()
	ball.add_theme_stylebox_override("panel", style)
	ball.size = Vector2(ball_size, ball_size)
	ball.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ball.position = start - ball.size / 2.0
	add_child(ball)
	# Same layering as _play_scatterblast_effect() - at the hero/enemy
	# layer, not on top of every UI panel.
	move_child(ball, enemies_layer.get_index() + 1)

	var trail := CPUParticles2D.new()
	trail.local_coords = false
	trail.position = ball.size / 2.0
	trail.amount = int(30 * size_scale)
	trail.lifetime = 0.3 * sqrt(size_scale)
	if size_scale > 1.0:
		# A big ball sheds sparks from its whole body, not one point.
		trail.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
		trail.emission_sphere_radius = ball_size * 0.3
	trail.spread = 180.0
	trail.gravity = Vector2.ZERO
	trail.initial_velocity_min = 5.0
	trail.initial_velocity_max = 25.0
	trail.scale_amount_min = 2.0 * size_scale
	trail.scale_amount_max = 5.0 * size_scale
	trail.color = color
	ball.add_child(trail)
	trail.emitting = true

	var tween: Tween = ball.create_tween()
	tween.tween_method(
		func(t: float) -> void:
			var a: Vector2 = start.lerp(control_point, t)
			var b: Vector2 = control_point.lerp(end, t)
			ball.position = a.lerp(b, t) - ball.size / 2.0,
		0.0, 1.0, flight_time
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void:
		_play_orb_impact(end, color, size_scale)
		if is_instance_valid(to_node) and to_node is TextureRect:
			_flash_bounce_hit(to_node, flash_color)
		# Hide the ball but let the trail's last sparks finish fading.
		# (self_modulate hides the ball itself, not its trail child.)
		trail.emitting = false
		ball.self_modulate.a = 0.0
	)
	tween.tween_interval(trail.lifetime + 0.1)
	tween.tween_callback(ball.queue_free)


## The orb projectile's impact (see _play_orb_projectile()): a one-shot
## ring of `color` sparks at `pos`, scaled by `size_scale` (1.0 =
## Mist Coil's own size). Same CPUParticles2D one-shot-burst recipe as
## _spawn_lil_shredder_impact().
func _play_orb_impact(pos: Vector2, color: Color, size_scale: float) -> void:
	var lifetime: float = 0.45 * sqrt(size_scale)
	var particles := CPUParticles2D.new()
	particles.position = pos
	particles.emitting = false
	particles.one_shot = true
	particles.amount = int(28 * size_scale)
	particles.lifetime = lifetime
	particles.explosiveness = 1.0
	particles.spread = 180.0
	particles.gravity = Vector2.ZERO
	particles.initial_velocity_min = 80.0 * sqrt(size_scale)
	particles.initial_velocity_max = 170.0 * sqrt(size_scale)
	particles.damping_min = 120.0
	particles.damping_max = 200.0
	if size_scale > 1.0:
		# Bigger bursts read as shards - randomly rotated pieces.
		particles.angle_min = 0.0
		particles.angle_max = 360.0
	particles.scale_amount_min = 3.0 * sqrt(size_scale)
	particles.scale_amount_max = 6.0 * sqrt(size_scale)
	particles.color = color
	add_child(particles)
	move_child(particles, enemies_layer.get_index() + 1)
	particles.emitting = true

	get_tree().create_timer(lifetime + 0.2).timeout.connect(particles.queue_free)


## Purely cosmetic: Splinter Blast bursting on `from_node` (the blast's
## target) - an explosion of ice chunks and a cold flash right on it,
## then SPLINTER_SHARDS_PER_TARGET big, spinning ice chunks flung from
## there to each node in `to_nodes` (every unit its splinters hit),
## slightly spread and staggered so each volley reads as several
## pieces, shattering into a small burst on arrival. Positions are
## captured up front, so a unit killed by its splinter still gets its
## chunks. Same layering as _play_scatterblast_effect().
func _play_splinter_shards(from_node: Variant, to_nodes: Array) -> void:
	if not (from_node is Control) or not is_instance_valid(from_node):
		return
	var start: Vector2 = from_node.position + from_node.size / 2.0

	# The explosion on the target itself - the same shard burst the orb
	# projectile's impact uses, scaled well up.
	_play_orb_impact(start, SPLINTER_SHARD_COLOR, SPLINTER_EXPLOSION_SCALE)
	if from_node is TextureRect:
		_flash_bounce_hit(from_node, COLD_FEET_FLASH_COLOR)

	for to_node in to_nodes:
		if not (to_node is Control) or not is_instance_valid(to_node):
			continue
		var end: Vector2 = to_node.position + to_node.size / 2.0
		var travel: Vector2 = end - start
		if travel.length() < 1.0:
			continue
		var flight_time: float = clampf(travel.length() / 900.0, 0.2, 0.45)
		var normal: Vector2 = Vector2(-travel.y, travel.x).normalized()

		for i in SPLINTER_SHARDS_PER_TARGET:
			var chunk := ColorRect.new()
			chunk.color = SPLINTER_SHARD_COLOR
			var chunk_size: float = randf_range(SPLINTER_CHUNK_SIZE * 0.75, SPLINTER_CHUNK_SIZE * 1.15)
			chunk.size = Vector2(chunk_size, chunk_size * 0.7)
			chunk.pivot_offset = chunk.size / 2.0
			chunk.mouse_filter = Control.MOUSE_FILTER_IGNORE
			chunk.rotation = randf_range(0.0, TAU)
			# Each chunk aims at a slightly different spot on the target
			# and starts from a slightly different spot in the explosion.
			var chunk_start: Vector2 = start + Vector2(randf_range(-12.0, 12.0), randf_range(-12.0, 12.0))
			var chunk_end: Vector2 = end + normal * randf_range(-22.0, 22.0)
			chunk.position = chunk_start - chunk.pivot_offset
			chunk.modulate.a = 0.0
			add_child(chunk)
			move_child(chunk, enemies_layer.get_index() + 1)

			var tween: Tween = chunk.create_tween()
			tween.tween_interval(0.08 + i * 0.05)
			tween.tween_property(chunk, "modulate:a", 1.0, 0.03)
			tween.tween_property(chunk, "position", chunk_end - chunk.pivot_offset, flight_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tween.parallel().tween_property(chunk, "rotation", chunk.rotation + randf_range(-1.0, 1.0) * TAU, flight_time)
			# Only the last chunk of each volley shatters on arrival, so
			# a volley makes one burst rather than several stacked ones.
			if i == SPLINTER_SHARDS_PER_TARGET - 1:
				tween.tween_callback(func() -> void:
					_play_orb_impact(chunk_end, SPLINTER_SHARD_COLOR, 1.0)
				)
			tween.tween_property(chunk, "scale", Vector2(0.2, 0.2), 0.1)
			tween.parallel().tween_property(chunk, "modulate:a", 0.0, 0.1)
			tween.tween_callback(chunk.queue_free)


## Purely cosmetic: Ice Blast's big ice ball, flying from the caster to
## the blast's target - the same orb projectile as Mist Coil
## (_play_orb_projectile()), scaled up to ICE_BLAST_BALL_SIZE in pale
## ice with a white rim, bursting into ice shards and flashing the
## target icy-blue on impact. The frost left on everyone the blast's
## DoT landed on is _refresh_cold_feet_frost()'s.
func _play_ice_blast_effect(from_node: Variant, to_node: Variant) -> void:
	_play_orb_projectile(from_node, to_node, ICE_BLAST_BALL_COLOR, ICE_BLAST_RIM_COLOR, COLD_FEET_FLASH_COLOR, ICE_BLAST_BALL_SIZE)


## Activates (or, if already active, replaces outright, same as the
## player's own copy) Aphotic Shield on the rival, and dispels every
## negative effect currently on him - here that's whatever the
## player's own Entangle/Pounce/Curse of Avernus wrote directly onto
## this enemy Dictionary (see _apply_root()/_apply_curse_of_avernus_
## stack()), since a hero-fight boss is otherwise a completely ordinary
## entry in _enemies.
func _activate_enemy_aphotic_shield(enemy: Dictionary, level_data: Dictionary) -> void:
	_enemy_aphotic_shield_active = true
	_enemy_aphotic_shield_hp = float(level_data.get("shield_hp", 0))
	_enemy_aphotic_shield_aoe_damage = float(level_data.get("aoe_damage", 0))
	_enemy_aphotic_shield_radius = int(level_data.get("radius", 0))
	_enemy_aphotic_shield_turns_remaining = int(level_data.get("duration", 0))
	_enemy_aphotic_shield_duration_pending_start = true

	# Checked before the dispel below clears it all - only drives the
	# cleanse sparks in _show_aphotic_shell().
	var cleansed: bool = bool(enemy.get("curse_active", false))
	for field in ["root_turns_left", "silence_turns_left", "entangle_dot_turns_left", "stun_turns_left", "curse_stacks", "curse_dot_turns_left"]:
		if int(enemy.get(field, 0)) > 0:
			cleansed = true

	enemy["root_turns_left"] = 0
	enemy["silence_turns_left"] = 0
	enemy["entangle_dot_damage"] = 0.0
	enemy["entangle_dot_turns_left"] = 0
	enemy["stun_turns_left"] = 0
	enemy["curse_stacks"] = 0
	enemy["curse_active"] = false
	enemy["curse_dot_damage"] = 0.0
	enemy["curse_dot_turns_left"] = 0

	_show_aphotic_shell(enemy.get("node"), _enemy_aphotic_shield_hp, cleansed)


func _tick_enemy_aphotic_shield() -> void:
	if not _enemy_aphotic_shield_active:
		return
	if _enemy_aphotic_shield_duration_pending_start:
		_enemy_aphotic_shield_duration_pending_start = false
		return
	_enemy_aphotic_shield_turns_remaining -= 1
	if _enemy_aphotic_shield_turns_remaining <= 0:
		_end_enemy_aphotic_shield(false)


## Ends the rival's Aphotic Shield, whether its duration simply ran out
## (`exploded` false) or enough damage drained it to 0 HP (`exploded`
## true, from _deal_fixed_damage_to_enemy()) - in which case it deals
## the cast's own aoe_damage to the player, his illusions and his bear,
## each only if within the shield's own radius columns of the boss -
## the same radius-around-the-caster rule the player's own explosion
## uses (see _end_aphotic_shield()).
func _end_enemy_aphotic_shield(exploded: bool) -> void:
	var aoe_damage: float = _enemy_aphotic_shield_aoe_damage
	var radius: int = _enemy_aphotic_shield_radius
	var boss: Dictionary = _get_hero_fight_boss()

	_enemy_aphotic_shield_active = false
	_enemy_aphotic_shield_hp = 0.0
	_enemy_aphotic_shield_aoe_damage = 0.0
	_enemy_aphotic_shield_radius = 0
	_enemy_aphotic_shield_turns_remaining = 0
	_enemy_aphotic_shield_duration_pending_start = false

	_remove_aphotic_shell(boss.get("node"), exploded, radius)

	if not exploded:
		return

	# Same radius-around-the-boss check as his illusions/bear below - the
	# hero is only caught in it if he's actually standing close enough.
	var hero_in_range: bool = not boss.is_empty() and _distance(_hero_pos_index, boss["pos_index"]) <= radius
	if hero_in_range and not _is_hero_hidden():
		apply_damage(aoe_damage)
		# Same red hit-flash as Dark Pact.
		_flash_bounce_hit(hero_image)
	# The explosion is centered on the boss's own column, not the
	# player's - an illusion or the bear standing near him can still be
	# caught in it. Outside the stealth check above on purpose: the
	# hero hiding only protects the hero, not his illusions or bear.
	if not boss.is_empty():
		_deal_aoe_damage_to_illusions(boss["pos_index"], radius, aoe_damage, true)
		_deal_aoe_damage_to_bear(boss["pos_index"], radius, aoe_damage, true)


# ------------------------------------------------------------------
# Kunkka's Torrent, cast by the rival on the player - mirrors the
# player's own _resolve_torrent_cast(). Simplification versus that
# player-facing copy: like Dark Pact/Mist Coil, there's only one
# possible target in a hero fight (no other enemy, and no bear/column
# concept to splash onto), so the level-4 AoE radius has nothing extra
# to reach here - this always resolves as a single hit.
# ------------------------------------------------------------------

func _cast_enemy_torrent(level_data: Dictionary) -> void:
	if _enemy_skill_on_bear:
		_cast_enemy_torrent_on_bear(level_data)
		return
	var damage: float = float(level_data.get("damage", 0))
	_play_torrent_splash(hero_image)
	apply_damage(damage)
	# Torrent's own splash radius is centered on the impact point (the
	# player, the only possible target here) - an illusion near the
	# player can still be caught in it even though the single-hit
	# simplification above skips it for other creeps.
	var radius: int = int(level_data.get("radius", 0))
	_play_torrent_splash_on_illusions(_illusions, _hero_pos_index, radius)
	if _is_bear_alive() and _distance(_bear["pos_index"], _hero_pos_index) <= radius:
		_play_torrent_splash(_bear.get("node"))
	_deal_aoe_damage_to_illusions(_hero_pos_index, radius, damage)
	_deal_aoe_damage_to_bear(_hero_pos_index, radius, damage)
	_player_stun_turns_left = int(level_data.get("stun_turns", 1))
	_show_message_over_hero("Stunned!")


## Torrent's spray under every illusion in `illusions` (either side's
## array - `_illusions` or `_enemy_illusions`) within `radius` columns
## of `center_pos_index` - the same area check the matching
## _deal_aoe_damage_to_*illusions() helper uses. Called just BEFORE
## that damage, since a killed illusion's node gets freed.
func _play_torrent_splash_on_illusions(illusions: Array, center_pos_index: int, radius: int) -> void:
	for illusion in illusions:
		if _distance(illusion["pos_index"], center_pos_index) <= radius:
			_play_torrent_splash(illusion.get("node"))


## Purely cosmetic: Torrent erupting under `node` (an enemy hit by the
## player's Torrent, or the player's own hero_image when a rival casts
## it) - a geyser-like burst of water spray shooting up from its feet
## and falling back down. The position is captured up front, so a
## target killed by the hit still gets its splash.
func _play_torrent_splash(node: Variant) -> void:
	if not (node is Control) or not is_instance_valid(node):
		return

	var feet: Vector2 = node.position + Vector2(node.size.x / 2.0, node.size.y * 0.9)

	# The spray: a geyser-like burst straight up that rains back down.
	# Same CPUParticles2D one-shot-burst recipe as
	# _spawn_lil_shredder_impact().
	var lifetime: float = 0.8
	var spray := CPUParticles2D.new()
	spray.position = feet
	spray.emitting = false
	spray.one_shot = true
	spray.amount = 40
	spray.lifetime = lifetime
	spray.explosiveness = 0.85
	spray.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	spray.emission_rect_extents = Vector2(node.size.x * 0.12, 2.0)
	spray.direction = Vector2(0, -1)
	spray.spread = 12.0
	spray.gravity = Vector2(0, 700)
	spray.initial_velocity_min = 220.0
	spray.initial_velocity_max = 380.0
	spray.scale_amount_min = 3.0
	spray.scale_amount_max = 6.0
	spray.color = TORRENT_SPRAY_COLOR
	spray.hue_variation_min = -0.03
	spray.hue_variation_max = 0.03
	add_child(spray)
	# Same reasoning as _play_scatterblast_effect()'s own move_child()
	# call - render at the hero/enemy layer, not on top of every UI panel.
	move_child(spray, enemies_layer.get_index() + 1)
	spray.emitting = true

	get_tree().create_timer(lifetime + 0.2).timeout.connect(spray.queue_free)


# ------------------------------------------------------------------
# Kunkka's Tidebringer, on the rival - same plain-Attack counter as the
# player's own copy, just counting the rival's own Attacks on the
# player (see _resolve_enemy_hero_attack()) instead. No cleave here -
# same "only one possible target" simplification as Torrent's own
# enemy-side copy above.
# ------------------------------------------------------------------

func _get_enemy_tidebringer_level_data() -> Dictionary:
	if _enemy_hero_id == "":
		return {}
	var level: int = PlayerManager.get_npc_skill_level(_enemy_hero_id, "tidebringer")
	if level <= 0:
		return {}
	var skill: Dictionary = _find_enemy_skill("tidebringer")
	if skill.is_empty():
		return {}
	return GameManager.get_skill_level_data(skill, level)


func _maybe_consume_enemy_tidebringer_stack() -> Dictionary:
	var level_data: Dictionary = _get_enemy_tidebringer_level_data()
	if level_data.is_empty():
		return {}

	_enemy_tidebringer_attack_count += 1
	if _enemy_tidebringer_attack_count < int(level_data.get("hits_to_activate", 1)):
		return {}

	_enemy_tidebringer_attack_count = 0
	return level_data


# ------------------------------------------------------------------
# Kunkka's X Marks the Spot, cast by the rival - marks the player (the
# only other participant in a hero fight), so unlike the player's own
# copy there's nothing to remember but the fact that a mark is pending
# (_enemy_xmarks_pending) - see _enemy_hero_turn()'s own teleport check
# at its very top, which resolves it on the rival's next turn without
# spending that turn's action, mirroring _resolve_xmarks_teleport().
# ------------------------------------------------------------------

func _cast_enemy_xmarks() -> void:
	_enemy_xmarks_pending = true


# ------------------------------------------------------------------
# Kunkka's Ghostship, cast by the rival - mirrors the player's own
# _resolve_ghostship_cast(). Simplification versus that player-facing
# copy: the ship's whole path-of-enemies concept collapses to a single
# hit here, same "only one possible target" simplification Dark Pact/
# Mist Coil/Torrent already use - there's no bear-on-the-path concept
# for the rival AI to consider either, matching how it never targets
# the bear in the first place (see _enemy_hero_turn()'s own doc
# comment). Still plays the same _play_ghostship_animation() visual
# flourish as the player's own copy, just sailing from the boss's own
# column (enemy["pos_index"]) to the player's (_hero_pos_index) instead
# of the other way around.
# ------------------------------------------------------------------

func _cast_enemy_ghostship(enemy: Dictionary, level_data: Dictionary) -> void:
	var damage: float = float(level_data.get("damage", 0))
	apply_damage(damage)
	# The ship sails the whole line from the rival's own column to the
	# player's - an illusion standing anywhere along that path can still
	# be caught in it, same as every enemy along the player's own
	# Ghostship's path.
	_deal_line_aoe_damage_to_illusions(enemy["pos_index"], _hero_pos_index, damage)
	_deal_line_aoe_damage_to_bear(enemy["pos_index"], _hero_pos_index, damage)
	_play_ghostship_animation(enemy["pos_index"], _hero_pos_index)


# ------------------------------------------------------------------
# Abaddon's Curse of Avernus, cast by the rival - mirrors
# _apply_curse_of_avernus_stack()/_tick_curse_of_avernus_effects(),
# just building stacks on the player (via the _player_curse_* battle-
# local vars, since there's only one player to track state on) instead
# of on an enemy Dictionary, the same way Entangle's own root/silence/
# DoT is mirrored by the _player_root_*/_player_entangle_* vars above.
# ------------------------------------------------------------------

func _get_enemy_curse_of_avernus_level_data() -> Dictionary:
	if _enemy_hero_id == "":
		return {}
	var level: int = PlayerManager.get_npc_skill_level(_enemy_hero_id, "curse_of_avernus")
	if level <= 0:
		return {}
	var skill: Dictionary = _find_enemy_skill("curse_of_avernus")
	if skill.is_empty():
		return {}
	return GameManager.get_skill_level_data(skill, level)


## Called on every rival plain Attack against the player (see
## _resolve_enemy_hero_attack()): builds one stack, or - once this
## level's hits_to_activate is reached - consumes them all to actually
## curse the player (silence, sharing the same _player_silence_turns_
## left field Entangle uses; and a damage-over-time, ticked by
## _tick_enemy_curse_of_avernus_effects() below). No-ops entirely if
## the rival doesn't have this skill learned or the player is already
## cursed, same as the player's own copy.
func _apply_enemy_curse_of_avernus_stack() -> void:
	var level_data: Dictionary = _get_enemy_curse_of_avernus_level_data()
	if level_data.is_empty() or _player_curse_active:
		return

	_player_curse_last_hit_turn = _turn_count

	var stacks: int = _player_curse_stacks + 1
	var hits_to_activate: int = int(level_data.get("hits_to_activate", 1))
	if stacks < hits_to_activate:
		_player_curse_stacks = stacks
		return

	_player_curse_stacks = 0
	_player_curse_active = true
	_player_silence_turns_left = int(level_data.get("silence_turns", 0))
	_player_curse_dot_damage = float(level_data.get("dot_damage", 0))
	_player_curse_dot_turns_left = int(level_data.get("dot_duration", 0))
	_refresh_status_effects()


## The player-side mirror of _tick_curse_of_avernus_effects(): the
## curse's own DoT moved to _tick_player_turn_start_effects() along with
## every other DoT - this is only the leftover, turn-count-based decay
## for a not-yet-cursed player still carrying stacks, same rules as the
## enemy-side version.
func _tick_enemy_curse_of_avernus_effects() -> void:
	if not _player_curse_active and _player_curse_stacks > 0:
		if _turn_count - _player_curse_last_hit_turn >= CURSE_OF_AVERNUS_STACK_DECAY_TURNS:
			_player_curse_stacks = 0


# ------------------------------------------------------------------
# Abaddon's Borrowed Time, on the rival - mirrors
# _maybe_auto_activate_borrowed_time()/_tick_borrowed_time()/
# _end_borrowed_time(). Like the player's own copy, nothing "casts"
# this - the only entry point is _deal_fixed_damage_to_enemy() noticing
# the rival's HP has crossed this level's threshold.
# ------------------------------------------------------------------

func _get_enemy_borrowed_time_level_data() -> Dictionary:
	if _enemy_hero_id == "":
		return {}
	var level: int = PlayerManager.get_npc_skill_level(_enemy_hero_id, "borrowed_time")
	if level <= 0:
		return {}
	var skill: Dictionary = _find_enemy_skill("borrowed_time")
	if skill.is_empty():
		return {}
	return GameManager.get_skill_level_data(skill, level)


func _maybe_auto_activate_enemy_borrowed_time(enemy: Dictionary) -> void:
	if _enemy_borrowed_time_active or _enemy_skill_cooldowns.get("borrowed_time", 0) > 0:
		return

	var level_data: Dictionary = _get_enemy_borrowed_time_level_data()
	if level_data.is_empty():
		return

	var max_hp: float = _enemy_hero_effective_max_hp(enemy)
	if max_hp <= 0.0:
		return

	var hp_pct: float = float(enemy.get("current_hp", 0)) / max_hp
	if hp_pct > float(level_data.get("auto_activate_hp_pct", 0.3)):
		return

	_enemy_borrowed_time_active = true
	_enemy_borrowed_time_heal_conversion_pct = float(level_data.get("heal_conversion_pct", 1.0))
	_enemy_borrowed_time_turns_remaining = int(level_data.get("duration", 0))
	_enemy_borrowed_time_duration_pending_start = true
	_set_borrowed_time_visual(enemy.get("node"), true)

	_enemy_skill_cooldowns["borrowed_time"] = int(level_data.get("cooldown", 0))


func _tick_enemy_borrowed_time() -> void:
	if not _enemy_borrowed_time_active:
		return
	if _enemy_borrowed_time_duration_pending_start:
		_enemy_borrowed_time_duration_pending_start = false
		return
	_enemy_borrowed_time_turns_remaining -= 1
	if _enemy_borrowed_time_turns_remaining <= 0:
		_end_enemy_borrowed_time()


func _end_enemy_borrowed_time() -> void:
	_enemy_borrowed_time_active = false
	_enemy_borrowed_time_heal_conversion_pct = 0.0
	_enemy_borrowed_time_turns_remaining = 0
	_enemy_borrowed_time_duration_pending_start = false
	_set_borrowed_time_visual(_get_hero_fight_boss().get("node"), false)

	# Full cooldown from the moment it ends - see _end_borrowed_time().
	var level_data: Dictionary = _get_enemy_borrowed_time_level_data()
	if not level_data.is_empty():
		_enemy_skill_cooldowns["borrowed_time"] = int(level_data.get("cooldown", 0))


# ------------------------------------------------------------------
# Ancient Apparition's Cold Feet/Ice Vortex, cast by the rival on the
# player - mirrors the player-side _resolve_cold_feet_cast()/
# _resolve_ice_vortex_cast(), just arming the single-player _player_
# cold_feet_dot_*/_player_ice_vortex_dot_* vars instead of per-enemy
# Dictionary fields, since there's only one player to track them on
# (same simplification Entangle's own _player_entangle_dot_* fields
# already use). Ice Vortex's own AoE has nothing else to reach in a
# hero fight (there's no other enemy besides the player), same "only
# one possible target" simplification Dark Pact/Torrent's splash
# already use for a rival.
# ------------------------------------------------------------------

func _cast_enemy_cold_feet(level_data: Dictionary) -> void:
	if _enemy_skill_on_bear:
		_cast_enemy_cold_feet_on_bear(level_data)
		return
	_player_cold_feet_dot_damage = float(level_data.get("damage", 0))
	_player_cold_feet_dot_turns_left = int(level_data.get("duration", 0))
	_show_message_over_hero("Cold Feet!")
	_flash_bounce_hit(hero_image, COLD_FEET_FLASH_COLOR)
	_refresh_cold_feet_frost()


func _cast_enemy_ice_vortex(level_data: Dictionary) -> void:
	if _enemy_skill_on_bear:
		_cast_enemy_ice_vortex_on_bear(level_data)
		return
	var damage: float = float(level_data.get("damage", 0))
	var duration: int = int(level_data.get("duration", 0))
	# Same default as the player's own copy (_resolve_ice_vortex_cast()).
	var radius: int = int(level_data.get("radius", 1))
	_player_ice_vortex_dot_damage = damage
	_player_ice_vortex_dot_turns_left = duration
	_show_message_over_hero("Ice Vortex!")
	_flash_bounce_hit(hero_image, COLD_FEET_FLASH_COLOR)

	# Centered on the player (the vortex's only possible target here) -
	# his illusions and Spirit Bear within that radius get the same DoT,
	# ticked alongside his own in _tick_player_turn_start_effects().
	_mark_illusions_ice_vortex(_illusions, _hero_pos_index, radius, damage, duration)
	if _is_bear_alive() and _distance(_bear["pos_index"], _hero_pos_index) <= radius:
		_bear["ice_vortex_dot_damage"] = damage
		_bear["ice_vortex_dot_turns_left"] = duration
		if is_instance_valid(_bear.get("node")):
			_flash_bounce_hit(_bear["node"], COLD_FEET_FLASH_COLOR)

	_play_ice_vortex_swirl(hero_image, radius)
	_refresh_cold_feet_frost()


## Arms Ice Vortex's DoT (`damage` per turn for `duration` turns) onto
## every illusion in `illusions` - either side's array, `_illusions` or
## `_enemy_illusions` - within `radius` columns of `center_pos_index`,
## the same area check the enemy-side loop uses, and gives each one the
## cast's icy flash. Stored on the illusion's own Dictionary under the
## same ice_vortex_dot_* keys an enemy uses; ticked by
## _tick_enemy_illusions_ice_vortex()/_tick_player_allies_ice_vortex().
func _mark_illusions_ice_vortex(illusions: Array, center_pos_index: int, radius: int, damage: float, duration: int) -> void:
	for illusion in illusions:
		if _distance(illusion["pos_index"], center_pos_index) <= radius:
			illusion["ice_vortex_dot_damage"] = damage
			illusion["ice_vortex_dot_turns_left"] = duration
			if is_instance_valid(illusion.get("node")):
				_flash_bounce_hit(illusion["node"], COLD_FEET_FLASH_COLOR)


## Ticks Ice Vortex's DoT on the rival's own illusions - once per enemy
## turn, at its very start (see _enemy_turn()), the same timing every
## enemy's own DoT ticks at. Each tick is mitigated by the boss's own
## effective armor, the same way every other hit on one of his
## illusions is (see _deal_aoe_damage_to_enemy_illusions()).
func _tick_enemy_illusions_ice_vortex() -> void:
	if _enemy_illusions.is_empty():
		return
	var boss: Dictionary = _get_hero_fight_boss()
	var armor: float = _enemy_hero_effective_armor(boss) if not boss.is_empty() else 0.0
	for illusion in _enemy_illusions.duplicate():
		if illusion.get("ice_vortex_dot_turns_left", 0) <= 0:
			continue
		illusion["ice_vortex_dot_turns_left"] -= 1
		var dot: float = float(illusion.get("ice_vortex_dot_damage", 0))
		if dot > 0.0:
			_deal_damage_to_enemy_illusion(illusion, _apply_armor_reduction(dot, armor))


## Ticks Ice Vortex's DoT on the player's own illusions - called from
## _tick_player_turn_start_effects(), right alongside the hero's own
## tick. Illusions mitigate with the hero's own armor (same as every
## other hit on them - see _deal_aoe_damage_to_illusions()).
func _tick_player_allies_ice_vortex() -> void:
	var hero_armor: float = _hero_armor()
	for illusion in _illusions.duplicate():
		if illusion.get("ice_vortex_dot_turns_left", 0) <= 0:
			continue
		illusion["ice_vortex_dot_turns_left"] -= 1
		var dot: float = float(illusion.get("ice_vortex_dot_damage", 0))
		if dot > 0.0:
			_deal_damage_to_illusion(illusion, _apply_armor_reduction(dot, hero_armor))

	# The Spirit Bear's own Ice Vortex tick - along with every other DoT
	# a rival can put on it - lives in _tick_bear_turn_start_effects().


# ------------------------------------------------------------------
# Ancient Apparition's Chilling Touch, cast by the rival - mirrors the
# player's own _resolve_chilling_touch_cast(): the rival's own rolled
# Attack damage (_roll_enemy_hero_damage(), the enemy-side mirror of
# _roll_hero_damage()) plus this level's own flat bonus_damage on top.
# Like the player's own copy, this is SKILL damage, not the plain
# Attack action itself, so it never triggers Essence Shift's steal,
# Spirit Link's lifesteal, or Curse of Avernus's stacking - those stay
# scoped specifically to _resolve_enemy_hero_attack().
# ------------------------------------------------------------------

func _cast_enemy_chilling_touch(enemy: Dictionary, level_data: Dictionary) -> void:
	if _enemy_skill_on_bear:
		_cast_enemy_chilling_touch_on_bear(enemy, level_data)
		return
	apply_damage(_roll_enemy_hero_damage(enemy) + float(level_data.get("bonus_damage", 0)))


# ------------------------------------------------------------------
# Ancient Apparition's Ice Blast, cast by the rival - mirrors the
# player's own _resolve_ice_blast_cast().
# Like Dark Pact/Torrent/Ghostship's own rival copies, there's only one
# possible target in a hero fight (the player), so the "hit everyone
# within radius" AoE collapses to a single hit; the DoT/execute state
# lives in the single-player _player_ice_blast_* vars instead of a
# per-enemy Dictionary field for the same reason Cold Feet's/Ice
# Vortex's own rival copies do.
# ------------------------------------------------------------------

func _cast_enemy_ice_blast(level_data: Dictionary) -> void:
	if _enemy_skill_on_bear:
		_cast_enemy_ice_blast_on_bear(level_data)
		return
	var damage: float = float(level_data.get("damage", 0))
	_play_ice_blast_effect(_get_hero_fight_boss().get("node"), hero_image)
	apply_damage(damage)
	# Ice Blast's own splash radius is centered on the impact point (the
	# player, the only possible target here) - an illusion near the
	# player can still be caught in it.
	_deal_aoe_damage_to_illusions(_hero_pos_index, int(level_data.get("radius", 0)), damage)
	_deal_aoe_damage_to_bear(_hero_pos_index, int(level_data.get("radius", 0)), damage)
	_player_ice_blast_dot_damage = float(level_data.get("dot_damage", 0))
	_player_ice_blast_dot_turns_left = int(level_data.get("dot_duration", 0))
	_player_ice_blast_execute_pct = float(level_data.get("execute_pct", 0.0))
	_player_stun_turns_left = int(level_data.get("stun_turns", 1))
	_show_message_over_hero("Ice Blast!")
	_refresh_cold_feet_frost()



# ------------------------------------------------------------------
# Winter Wyvern's Arctic Burn, cast by the rival on themselves - mirrors
# the player's own _activate_arctic_burn()/_apply_arctic_burn_attack()/
# _tick_arctic_burn()/_end_arctic_burn(). _apply_enemy_arctic_burn_
# attack() is called from _resolve_enemy_hero_attack(), the enemy-side
# mirror of _apply_hero_attack()'s own call to _apply_arctic_burn_
# attack().
# ------------------------------------------------------------------

func _cast_enemy_arctic_burn(level_data: Dictionary) -> void:
	_enemy_arctic_burn_active = true
	_enemy_arctic_burn_bonus_damage = float(level_data.get("bonus_damage", 0))
	_enemy_arctic_burn_bonus_range = int(level_data.get("bonus_range", 0))
	_enemy_arctic_burn_attacks_remaining = int(level_data.get("attacks", 0))
	_enemy_arctic_burn_turns_remaining = int(level_data.get("duration", 0))
	_enemy_arctic_burn_duration_pending_start = true
	_show_message_over_hero("Arctic Burn!")


func _apply_enemy_arctic_burn_attack() -> void:
	if not _enemy_arctic_burn_active or _enemy_arctic_burn_attacks_remaining <= 0:
		return
	_enemy_arctic_burn_attacks_remaining -= 1
	if _enemy_arctic_burn_attacks_remaining <= 0:
		_end_enemy_arctic_burn()


func _tick_enemy_arctic_burn() -> void:
	if not _enemy_arctic_burn_active:
		return
	if _enemy_arctic_burn_duration_pending_start:
		_enemy_arctic_burn_duration_pending_start = false
		return
	_enemy_arctic_burn_turns_remaining -= 1
	if _enemy_arctic_burn_turns_remaining <= 0:
		_end_enemy_arctic_burn()


func _end_enemy_arctic_burn() -> void:
	_enemy_arctic_burn_active = false
	_enemy_arctic_burn_bonus_damage = 0.0
	_enemy_arctic_burn_bonus_range = 0
	_enemy_arctic_burn_attacks_remaining = 0
	_enemy_arctic_burn_turns_remaining = 0
	_enemy_arctic_burn_duration_pending_start = false


# ------------------------------------------------------------------
# Winter Wyvern's Splinter Blast, cast by the rival on the player -
# mirrors the player's own _resolve_splinter_blast_cast(). Simplification
# versus that player-facing copy: like Dark Pact/Mist Coil/Torrent,
# there's only one possible target in a hero fight, so the splash onto
# "every OTHER enemy within splinter_range" has nothing else to reach -
# this always resolves as a single hit.
# ------------------------------------------------------------------

func _cast_enemy_splinter_blast(level_data: Dictionary) -> void:
	if _enemy_skill_on_bear:
		_cast_enemy_splinter_blast_on_bear(level_data)
		return
	var splinter_range: int = int(level_data.get("splinter_range", 0))
	var shard_nodes: Array = []
	for illusion in _illusions:
		if _distance(illusion["pos_index"], _hero_pos_index) <= splinter_range:
			shard_nodes.append(illusion.get("node"))
	if _is_bear_alive() and _distance(_bear["pos_index"], _hero_pos_index) <= splinter_range:
		shard_nodes.append(_bear.get("node"))
	_play_splinter_shards(hero_image, shard_nodes)
	apply_damage(float(level_data.get("damage", 0)))
	# Splinter Blast's own splash (its lighter splinter_damage, not the
	# main hit) is centered on the impact point (the player, the only
	# possible target here) - an illusion near the player can still be
	# caught in it.
	_deal_aoe_damage_to_illusions(_hero_pos_index, int(level_data.get("splinter_range", 0)), float(level_data.get("splinter_damage", 0)))
	_deal_aoe_damage_to_bear(_hero_pos_index, int(level_data.get("splinter_range", 0)), float(level_data.get("splinter_damage", 0)))


# ------------------------------------------------------------------
# Winter Wyvern's Cold Embrace, cast by the rival on themselves -
# mirrors the player's own _activate_cold_embrace()/_dispel_all_hero_
# effects()/_tick_cold_embrace()/_end_cold_embrace(), including swapping
# the boss's own node texture to COLD_EMBRACE_IMAGE_PATH (and back once
# it ends) the same way the player's portrait swaps - see
# _activate_enemy_true_form()/_end_enemy_true_form() for the identical
# pattern already used for True Form's own bear portrait. Damage
# immunity is enforced in _deal_fixed_damage_to_enemy() (checked before
# Borrowed Time/Aphotic Shield, same as the player's own apply_damage()
# checks Cold Embrace before anything else); the full action lockout (no
# move, attack, OR skill cast - stricter than the player's own copy,
# which can still cast something else while encased) is enforced at the
# very top of _enemy_hero_turn().
# ------------------------------------------------------------------

func _cast_enemy_cold_embrace(level_data: Dictionary) -> void:
	_dispel_all_enemy_hero_effects()

	_enemy_cold_embrace_active = true
	_enemy_cold_embrace_heal_per_turn = float(level_data.get("heal", 0))
	_enemy_cold_embrace_turns_remaining = int(level_data.get("duration", 0))
	_enemy_cold_embrace_duration_pending_start = true
	_show_message_over_hero("Encased in ice!")

	var boss: Dictionary = _get_hero_fight_boss()
	if not boss.is_empty() and ResourceLoader.exists(COLD_EMBRACE_IMAGE_PATH) and is_instance_valid(boss["node"]):
		boss["node"].texture = load(COLD_EMBRACE_IMAGE_PATH)
		_flash_bounce_hit(boss["node"], COLD_FEET_FLASH_COLOR)
	_refresh_cold_feet_frost()


## Dispels every other effect currently on the rival, good or bad, right
## before Cold Embrace establishes its own state - the enemy-side mirror
## of the player's own _dispel_all_hero_effects(), enumerating the same
## kind of fields but from the "_enemy_*" block instead (this rival's
## own buffs) - there's nothing equivalent to the player's debuff-
## receiving fields to clear here, since nothing in this game currently
## lets a rival hero's own AI inflict a debuff on ITSELF.
func _dispel_all_enemy_hero_effects() -> void:
	if _enemy_arctic_burn_active:
		_end_enemy_arctic_burn()
	if _enemy_essence_shift_active:
		_end_enemy_essence_shift()
	if _enemy_shadow_dance_active:
		_end_enemy_shadow_dance()
	if _enemy_spirit_link_active:
		_end_enemy_spirit_link()
	if _enemy_true_form_active:
		_end_enemy_true_form()
	if _enemy_aphotic_shield_active:
		_end_enemy_aphotic_shield(false)
	if _enemy_borrowed_time_active:
		_end_enemy_borrowed_time()


func _tick_enemy_cold_embrace() -> void:
	if not _enemy_cold_embrace_active:
		return

	if _enemy_cold_embrace_duration_pending_start:
		_enemy_cold_embrace_duration_pending_start = false
		return

	var boss: Dictionary = _get_hero_fight_boss()
	if not boss.is_empty():
		var max_hp: float = _enemy_hero_effective_max_hp(boss)
		boss["current_hp"] = minf(max_hp, float(boss.get("current_hp", 0.0)) + _enemy_cold_embrace_heal_per_turn)

	_enemy_cold_embrace_turns_remaining -= 1
	if _enemy_cold_embrace_turns_remaining <= 0:
		_end_enemy_cold_embrace()


func _end_enemy_cold_embrace() -> void:
	_enemy_cold_embrace_active = false
	_enemy_cold_embrace_heal_per_turn = 0.0
	_enemy_cold_embrace_turns_remaining = 0
	_enemy_cold_embrace_duration_pending_start = false
	_refresh_cold_feet_frost()

	var boss: Dictionary = _get_hero_fight_boss()
	if boss.is_empty() or not is_instance_valid(boss["node"]):
		return
	var original_image: String = str(boss["static"].get("image", ""))
	if original_image != "" and ResourceLoader.exists(original_image):
		boss["node"].texture = load(original_image)


# ------------------------------------------------------------------
# Winter Wyvern's ultimate, Winter's Curse, cast by the rival - mirrors
# the player's own _resolve_winters_curse_cast()/_is_winters_curse_
# active(). Simplification versus that player-facing copy: the "every
# OTHER enemy within curse_range piles onto the frozen target instead
# of the caster" half of the effect has nothing to redirect in a hero
# fight - the rival's only possible "attacker" is the player himself,
# controlled directly rather than by the same AI _enemy_turn() redirect
# logic uses, so there's no second enemy to pull off of him. This
# collapses Winter's Curse down to freezing the player outright
# (reusing the shared _player_stun_turns_left field Torrent's/Pounce's/
# Ice Blast's own stun already use), the same "AoE/redirect skill with
# only one possible target" simplification Dark Pact/Splinter Blast/
# Ice Vortex already use for a rival.
# ------------------------------------------------------------------

func _cast_enemy_winters_curse(level_data: Dictionary) -> void:
	if _enemy_skill_on_bear:
		_cast_enemy_winters_curse_on_bear(level_data)
		return
	_player_stun_turns_left = int(level_data.get("duration", 0))
	_player_winters_curse_active = true
	_show_message_over_hero("Winter's Curse!")
	_flash_bounce_hit(hero_image, COLD_FEET_FLASH_COLOR)
	_refresh_cold_feet_frost()


# ------------------------------------------------------------------
# Crystal Maiden's Crystal Nova/Frostbite, cast by the rival on the
# player - mirror the player's own _resolve_crystal_nova_cast()/
# _resolve_frostbite_cast(). Simplification versus those player-facing
# copies: there's only one possible target in a hero fight (the player),
# so Crystal Nova's own "every other enemy within radius of the primary
# target" splash has nothing else to reach - same "AoE skill with only
# one possible target" simplification Dark Pact/Splinter Blast/Ice
# Vortex already use for a rival.
# ------------------------------------------------------------------

func _cast_enemy_crystal_nova(level_data: Dictionary) -> void:
	var damage: float = float(level_data.get("damage", 0))
	var radius: int = int(level_data.get("radius", 0))
	# Frosted before the hits land - a kill frees the node.
	_flash_frost_briefly(hero_image, CRYSTAL_NOVA_FROST_SECONDS)
	for illusion in _illusions:
		if _distance(illusion["pos_index"], _hero_pos_index) <= radius:
			_flash_frost_briefly(illusion.get("node"), CRYSTAL_NOVA_FROST_SECONDS)
	if _is_bear_alive() and _distance(_bear["pos_index"], _hero_pos_index) <= radius:
		_flash_frost_briefly(_bear.get("node"), CRYSTAL_NOVA_FROST_SECONDS)
	apply_damage(damage)
	# Crystal Nova's own splash (the same damage as the main hit) is
	# centered on the impact point (the player, the only possible
	# target here) - an illusion near the player can still be caught
	# in it.
	_deal_aoe_damage_to_illusions(_hero_pos_index, int(level_data.get("radius", 0)), damage)
	_deal_aoe_damage_to_bear(_hero_pos_index, int(level_data.get("radius", 0)), damage)
	_show_message_over_hero("Crystal Nova!")


func _cast_enemy_frostbite(level_data: Dictionary) -> void:
	if _enemy_skill_on_bear:
		_cast_enemy_frostbite_on_bear(level_data)
		return
	_player_frostbite_dot_damage = float(level_data.get("dot_damage", 0))
	_player_frostbite_dot_turns_left = int(level_data.get("dot_duration", 0))
	_player_stun_turns_left = int(level_data.get("stun_turns", 1))
	_show_message_over_hero("Frostbite!")
	_flash_bounce_hit(hero_image, COLD_FEET_FLASH_COLOR)
	_refresh_cold_feet_frost()



# ------------------------------------------------------------------
# Crystal Maiden's ultimate, Freezing Field, cast by the rival on
# herself - mirrors the player's own _activate_freezing_field()/_tick_
# freezing_field()/_end_freezing_field(). Damage is applied straight to
# the player via apply_damage() (which already checks the player's own
# Cold Embrace immunity, same as every other rival hit) rather than
# _deal_fixed_damage_to_enemy() (an enemy-side helper, for damage FROM
# the player), the same split every other "rival hits the player" cast
# above already uses.
# ------------------------------------------------------------------

func _cast_enemy_freezing_field(level_data: Dictionary) -> void:
	_enemy_freezing_field_active = true
	_enemy_freezing_field_damage_per_turn = float(level_data.get("damage", 0))
	_enemy_freezing_field_radius = int(level_data.get("radius", 0))
	_enemy_freezing_field_turns_remaining = int(level_data.get("duration", 0))
	_enemy_freezing_field_duration_pending_start = true
	_show_message_over_hero("Freezing Field!")


## Ticks Freezing Field's duration down once per End Turn, same timing
## (and same "the casting turn doesn't count" skip) as every other
## duration-based buff - dealing this level's own damage to the player
## whenever they're within radius columns of the rival's CURRENT
## position (re-checked fresh here, not fixed at cast time, mirroring
## the player's own _tick_freezing_field()). There's only one possible
## target in a hero fight, so this collapses to a single conditional hit
## rather than a loop over multiple enemies.
func _tick_enemy_freezing_field() -> void:
	if not _enemy_freezing_field_active:
		return

	if _enemy_freezing_field_duration_pending_start:
		_enemy_freezing_field_duration_pending_start = false
		return

	var boss: Dictionary = _get_hero_fight_boss()
	if not boss.is_empty():
		if _distance(boss["pos_index"], _hero_pos_index) <= _enemy_freezing_field_radius:
			apply_damage(_enemy_freezing_field_damage_per_turn)
		# Centered on the boss's own CURRENT position, same as the hero
		# check above - an illusion can be in range independently of
		# whether the hero himself currently is.
		_deal_aoe_damage_to_illusions(boss["pos_index"], _enemy_freezing_field_radius, _enemy_freezing_field_damage_per_turn)
		_deal_aoe_damage_to_bear(boss["pos_index"], _enemy_freezing_field_radius, _enemy_freezing_field_damage_per_turn)

	_enemy_freezing_field_turns_remaining -= 1
	if _enemy_freezing_field_turns_remaining <= 0:
		_end_enemy_freezing_field()


func _end_enemy_freezing_field() -> void:
	_enemy_freezing_field_active = false
	_enemy_freezing_field_damage_per_turn = 0.0
	_enemy_freezing_field_radius = 0
	_enemy_freezing_field_turns_remaining = 0
	_enemy_freezing_field_duration_pending_start = false


# ------------------------------------------------------------------
# Tusk's Ice Shards, cast by the rival on the player - mirrors the
# player's own _resolve_ice_shards_cast()/_tick_ice_shards()/_end_ice_
# shards(). Walls off `blocked_columns` columns starting on the rival's
# OWN column and continuing toward the player's, same directional walk
# the player's own copy uses, just from the other side.
# ------------------------------------------------------------------

func _cast_enemy_ice_shards(enemy: Dictionary, level_data: Dictionary) -> void:
	apply_damage(float(level_data.get("damage", 0)))

	var direction: int = _step_toward(enemy["pos_index"], _hero_pos_index)
	if direction == 0:
		direction = 1

	var blocked_columns: int = int(level_data.get("blocked_columns", 0))
	var columns: Array[int] = []
	var col: int = enemy["pos_index"]
	for i in range(blocked_columns):
		if col < 0 or col >= GRID_COLUMNS:
			break
		columns.append(col)
		col += direction

	_enemy_ice_shards_active = true
	_enemy_ice_shards_blocked_columns = columns
	_enemy_ice_shards_turns_remaining = int(level_data.get("duration", 0))
	_enemy_ice_shards_duration_pending_start = true
	_refresh_ice_shards_visuals()
	_show_message_over_hero("Ice Shards!")


func _tick_enemy_ice_shards() -> void:
	if not _enemy_ice_shards_active:
		return

	if _enemy_ice_shards_duration_pending_start:
		_enemy_ice_shards_duration_pending_start = false
		return

	_enemy_ice_shards_turns_remaining -= 1
	if _enemy_ice_shards_turns_remaining <= 0:
		_end_enemy_ice_shards()


func _end_enemy_ice_shards() -> void:
	_enemy_ice_shards_active = false
	_enemy_ice_shards_blocked_columns = []
	_enemy_ice_shards_turns_remaining = 0
	_enemy_ice_shards_duration_pending_start = false
	_refresh_ice_shards_visuals()


## Whether `col` is currently walled off by the RIVAL's own Ice Shards -
## checked from _hero_move() (and the movement helpers it delegates to)
## so the player can't move at all while standing in one, and can't step
## into one from outside it, mirroring the player's own _is_column_ice_
## shards_blocked() (which does the same to every enemy's own movement).
## Attacking, casting a skill, and using an item are all untouched
## either way, same as the player's own copy.
func _is_column_enemy_ice_shards_blocked(col: int) -> bool:
	return _enemy_ice_shards_active and col in _enemy_ice_shards_blocked_columns


# ------------------------------------------------------------------
# Tusk's Snowball, cast by the rival on the player - mirrors the
# player's own _resolve_snowball_cast(): moves the rival straight onto
# the player's own column, dealing damage and stunning on impact.
# ------------------------------------------------------------------

func _cast_enemy_snowball(enemy: Dictionary, level_data: Dictionary) -> void:
	if _enemy_skill_on_bear:
		_cast_enemy_snowball_on_bear(enemy, level_data)
		return
	apply_damage(float(level_data.get("damage", 0)))
	_player_stun_turns_left = int(level_data.get("stun_turns", 1))

	# The charge physically carries the rival across every column in
	# between, so the player's own Ice Shards wall in its path stops it
	# one column short - same rule the player's own Snowball charge
	# follows now (see _resolve_snowball_cast()).
	var charge_direction: int = _step_toward(enemy["pos_index"], _hero_pos_index)
	var landing_pos: int = enemy["pos_index"]
	while charge_direction != 0 and landing_pos != _hero_pos_index:
		var next_pos: int = landing_pos + charge_direction
		if _is_column_ice_shards_blocked(next_pos):
			break
		landing_pos = next_pos

	_move_enemy(enemy, landing_pos)
	_show_message_over_hero("Snowball!")


# ------------------------------------------------------------------
# Tusk's Tag Team, cast by the rival on himself - mirrors the player's
# own _activate_tag_team()/_tick_tag_team()/_end_tag_team(): a flat
# bonus_damage added to _roll_enemy_hero_damage() for the duration.
# ------------------------------------------------------------------

func _cast_enemy_tag_team(level_data: Dictionary) -> void:
	_enemy_tag_team_active = true
	_enemy_tag_team_bonus_damage = float(level_data.get("bonus_damage", 0))
	_enemy_tag_team_turns_remaining = int(level_data.get("duration", 0))
	_enemy_tag_team_duration_pending_start = true
	_show_message_over_hero("Tag Team!")


func _tick_enemy_tag_team() -> void:
	if not _enemy_tag_team_active:
		return

	if _enemy_tag_team_duration_pending_start:
		_enemy_tag_team_duration_pending_start = false
		return

	_enemy_tag_team_turns_remaining -= 1
	if _enemy_tag_team_turns_remaining <= 0:
		_end_enemy_tag_team()


func _end_enemy_tag_team() -> void:
	_enemy_tag_team_active = false
	_enemy_tag_team_bonus_damage = 0.0
	_enemy_tag_team_turns_remaining = 0
	_enemy_tag_team_duration_pending_start = false


# ------------------------------------------------------------------
# Tusk's ultimate, Walrus Punch, cast by the rival on the player -
# mirrors the player's own _resolve_walrus_punch_cast(): rolls the
# rival's own Attack damage (_roll_enemy_hero_damage(), already folding
# in Tag Team's bonus while active) times this level's own
# damage_multiplier, then works out how far the knockback actually
# carries - walking one column at a time, away from the rival's current
# facing (its node's own flip_h, the enemy-side mirror of the player's
# own hero_image.flip_h), for up to `knockback` columns, stopping early
# at the edge of the board or at the first column another living,
# targetable enemy already occupies (a reinforcement creep, during a
# hero fight that's gone on long enough to spawn one - see
# _spawn_reinforcements()'s own "hero fights still get reinforcements"
# note). Coming up short either way adds 50% more damage before it
# lands, then stuns the player in place if they survive.
# ------------------------------------------------------------------

func _cast_enemy_walrus_punch(enemy: Dictionary, level_data: Dictionary) -> void:
	if _enemy_skill_on_bear:
		_cast_enemy_walrus_punch_on_bear(enemy, level_data)
		return
	var multiplier: float = float(level_data.get("damage_multiplier", 1.0))
	var punch_damage: float = _roll_enemy_hero_damage(enemy) * multiplier

	var knockback_columns: int = int(level_data.get("knockback", 0))
	var direction: int = -1 if enemy["node"].flip_h else 1
	var pos: int = _hero_pos_index
	var actual_distance: int = 0
	for i in range(knockback_columns):
		var next_pos: int = pos + direction
		if next_pos < 0 or next_pos >= GRID_COLUMNS:
			break
		if not _get_enemy_at(next_pos).is_empty():
			break
		# Knocked straight into the rival's own Ice Shards wall (if
		# they've cast it) - stops here same as hitting the board edge
		# or another enemy, and counts as the same "hit_wall" bonus
		# damage below (a literal wall, this time).
		if _is_column_enemy_ice_shards_blocked(next_pos):
			break
		pos = next_pos
		actual_distance += 1

	var hit_wall: bool = actual_distance < knockback_columns
	if hit_wall:
		punch_damage *= 1.5

	apply_damage(punch_damage)

	if hit_wall:
		_show_message_over_hero("Wall hit!")

	if _recruited.get("current_hp", 0) > 0:
		_hero_pos_index = pos
		# Same facing convention as _hero_move()'s own copy - faces the
		# direction it just got knocked in, rather than staying turned
		# toward the boss that just punched it.
		hero_image.flip_h = direction < 0
		_update_hero_position()
		_player_stun_turns_left = int(level_data.get("stun_turns", 1))


# ------------------------------------------------------------------
# Treant Protector's Nature's Guise, cast by the rival on himself -
# mirrors the player's own _activate_natures_guise()/_tick_natures_
# guise()/_end_natures_guise(): functionally the same invisibility as
# Shadow Dance (folded into the very same _is_target_hidden()/_update_
# enemy_hero_visibility() checks), just with a root on the player
# instead of bonus damage for the Attack that breaks it - see
# _resolve_enemy_hero_attack()'s own "attacking_from_enemy_natures_
# guise" capture.
# ------------------------------------------------------------------

func _activate_enemy_natures_guise(level_data: Dictionary) -> void:
	_enemy_natures_guise_active = true
	_enemy_natures_guise_root_turns = int(level_data.get("root_turns", 0))
	_enemy_natures_guise_turns_remaining = int(level_data.get("duration", 0))
	_enemy_natures_guise_duration_pending_start = true
	_update_enemy_hero_visibility()


func _tick_enemy_natures_guise() -> void:
	if not _enemy_natures_guise_active:
		return
	if _enemy_natures_guise_duration_pending_start:
		_enemy_natures_guise_duration_pending_start = false
		return
	_enemy_natures_guise_turns_remaining -= 1
	if _enemy_natures_guise_turns_remaining <= 0:
		_end_enemy_natures_guise()


func _end_enemy_natures_guise() -> void:
	_enemy_natures_guise_active = false
	_enemy_natures_guise_root_turns = 0
	_enemy_natures_guise_turns_remaining = 0
	_enemy_natures_guise_duration_pending_start = false
	_update_enemy_hero_visibility()


# ------------------------------------------------------------------
# Treant Protector's Leech Seed, cast by the rival on the player -
# mirrors the player's own _resolve_leech_seed_cast(): no immediate
# damage, just arms this level's own dot_damage/heal_per_turn on the
# player's own dedicated _player_leech_seed_* fields, ticked once per
# turn (alongside every other rival-inflicted DoT) by _tick_player_
# turn_start_effects() - which, unlike every other DoT there, also heals
# the CASTER (the rival, via _get_hero_fight_boss()) each tick instead
# of the player.
# ------------------------------------------------------------------

func _cast_enemy_leech_seed(level_data: Dictionary) -> void:
	if _enemy_skill_on_bear:
		_cast_enemy_leech_seed_on_bear(level_data)
		return
	_player_leech_seed_dot_damage = float(level_data.get("dot_damage", 0))
	_player_leech_seed_heal_per_turn = float(level_data.get("heal_per_turn", 0))
	_player_leech_seed_dot_turns_left = int(level_data.get("duration", 0))
	_show_message_over_hero("Leech Seed!")


# ------------------------------------------------------------------
# Treant Protector's Living Armor, cast by the rival on himself - mirrors
# the player's own _activate_living_armor()/_tick_living_armor()/
# _end_living_armor(): bonus_armor folds into _enemy_hero_bonus_armor(),
# bonus_hp_regen heals the rival on top of his own baseline passive
# regen (_tick_enemy_passive_regen()) every tick, same "on top of the
# baseline, not instead of it" relationship the player's own copy has
# with _apply_passive_hero_regen().
# ------------------------------------------------------------------

func _activate_enemy_living_armor(level_data: Dictionary) -> void:
	_enemy_living_armor_active = true
	_enemy_living_armor_bonus_armor = float(level_data.get("bonus_armor", 0))
	_enemy_living_armor_bonus_hp_regen = float(level_data.get("bonus_hp_regen", 0))
	_enemy_living_armor_turns_remaining = int(level_data.get("duration", 0))
	_enemy_living_armor_duration_pending_start = true
	_show_message_over_hero("Living Armor!")


func _tick_enemy_living_armor() -> void:
	if not _enemy_living_armor_active:
		return
	if _enemy_living_armor_duration_pending_start:
		_enemy_living_armor_duration_pending_start = false
		return

	var boss: Dictionary = _get_hero_fight_boss()
	if not boss.is_empty():
		var max_hp: float = _enemy_hero_effective_max_hp(boss)
		boss["current_hp"] = minf(max_hp, float(boss.get("current_hp", 0.0)) + _enemy_living_armor_bonus_hp_regen)

	_enemy_living_armor_turns_remaining -= 1
	if _enemy_living_armor_turns_remaining <= 0:
		_end_enemy_living_armor()


func _end_enemy_living_armor() -> void:
	_enemy_living_armor_active = false
	_enemy_living_armor_bonus_armor = 0.0
	_enemy_living_armor_bonus_hp_regen = 0.0
	_enemy_living_armor_turns_remaining = 0
	_enemy_living_armor_duration_pending_start = false


# ------------------------------------------------------------------
# Treant Protector's ultimate, Overgrowth, cast by the rival - mirrors
# the player's own _activate_overgrowth(): every living, targetable
# enemy within `radius` columns of the rival's CURRENT position gets
# rooted (_player_root_turns_left, the same shared field Entangle's own
# root already uses - it can still attack and cast skills while rooted,
# same as any other rooted enemy) for `root_duration` turns, armed with
# that same level's own DoT (_player_overgrowth_dot_damage/_player_
# overgrowth_dot_turns_left, a dedicated pair so it never clobbers
# another skill's DoT on the player) for the same duration - ticked, at
# the start of the player's own turn, by _tick_player_turn_start_
# effects(). There's only one possible target in a hero fight, so this
# collapses to a single conditional hit rather than a loop over multiple
# enemies, same simplification every other AoE skill's own rival copy
# already uses.
# ------------------------------------------------------------------

func _cast_enemy_overgrowth(enemy: Dictionary, level_data: Dictionary) -> void:
	var radius: int = int(level_data.get("radius", 0))
	var dot_damage: float = float(level_data.get("dot_damage", 0))
	if _distance(enemy["pos_index"], _hero_pos_index) <= radius:
		var root_duration: int = int(level_data.get("root_duration", 0))
		_player_root_turns_left = root_duration
		_player_overgrowth_dot_damage = dot_damage
		_player_overgrowth_dot_turns_left = root_duration

	# Illusions have no root/DoT of their own to carry the way the hero
	# does above - just a one-time hit for whatever's caught in the
	# burst, centered on the caster's own column, same as the check
	# above.
	_deal_aoe_damage_to_illusions(enemy["pos_index"], radius, dot_damage)
	_deal_aoe_damage_to_bear(enemy["pos_index"], radius, dot_damage)

	_show_message_over_hero("Overgrowth!")


# ------------------------------------------------------------------
# Timbersaw's Whirling Death, cast by the rival on himself - mirrors the
# player's own _cast_whirling_death(): `level_data.damage` to the player
# whenever they're within `radius` columns of the rival's CURRENT
# position. There's only one possible target in a hero fight, so this
# collapses to a single conditional hit rather than a loop over multiple
# enemies, same simplification every other self-centered AoE's own
# rival copy already uses (see _cast_enemy_freezing_field()/_cast_enemy_
# overgrowth()). "Pure damage" and the primary-attribute reduction are
# both purely descriptive here - neither is mechanically implemented
# anywhere in this project (the player's own _cast_whirling_death() also
# just calls _deal_fixed_damage_to_enemy(), the same armor-mitigated
# path every other skill uses, and no reduction amount exists anywhere
# in its own level data), so this mirrors that exact behavior rather
# than inventing either one - see EnemySkillAI's own _timbersaw_
# whirling_death_modifier() for how the AI still accounts for the
# qualitative "a hero was hit" value without a real stat system behind
# it.
# ------------------------------------------------------------------

func _cast_enemy_whirling_death(enemy: Dictionary, level_data: Dictionary) -> void:
	var radius: int = int(level_data.get("radius", 0))
	var damage: float = float(level_data.get("damage", 0))
	if _distance(enemy["pos_index"], _hero_pos_index) <= radius:
		apply_damage(damage)
	# Centered on the caster's own column, same as the check above - an
	# illusion can be in range independently of whether the player
	# himself currently is.
	_deal_aoe_damage_to_illusions(enemy["pos_index"], radius, damage)
	_deal_aoe_damage_to_bear(enemy["pos_index"], radius, damage)
	_show_message_over_hero("Whirling Death!")


# ------------------------------------------------------------------
# Timbersaw's Timber Chain, cast by the rival on the player - mirrors
# the player's own _resolve_timber_chain_cast(): `level_data.damage` to
# the player (there's only one possible target/path occupant in a hero
# fight - see this section's own header comment above), then pulls the
# rival onto the player's own column, stopping one column short of a
# player-cast Ice Shards wall in the way, exactly the same "the damage
# still reaches the full line, only the physical landing spot is
# blocked" split the player's own copy uses.
# ------------------------------------------------------------------

func _cast_enemy_timber_chain(enemy: Dictionary, level_data: Dictionary) -> void:
	var damage: float = float(level_data.get("damage", 0))
	apply_damage(damage)
	# The chain reaches the whole line from the rival's own column to
	# the player's - an illusion standing anywhere along that path can
	# still be caught in it, same as every enemy along the player's own
	# Timber Chain's path. Read BEFORE the rival's own pull below moves
	# it off "enemy["pos_index"]".
	_deal_line_aoe_damage_to_illusions(enemy["pos_index"], _hero_pos_index, damage)
	_deal_line_aoe_damage_to_bear(enemy["pos_index"], _hero_pos_index, damage)

	var chain_direction: int = _step_toward(enemy["pos_index"], _hero_pos_index)
	var landing_pos: int = enemy["pos_index"]
	while chain_direction != 0 and landing_pos != _hero_pos_index:
		var next_pos: int = landing_pos + chain_direction
		if _is_column_ice_shards_blocked(next_pos):
			break
		landing_pos = next_pos

	_move_enemy(enemy, landing_pos)
	_show_message_over_hero("Timber Chain!")


# ------------------------------------------------------------------
# Timbersaw's Reactive Armor (passive) - mirrors the player's own
# _reactive_armor_stack_turns/_get_reactive_armor_level_data()/_apply_
# reactive_armor_stack()/_tick_reactive_armor_stacks()/_apply_reactive_
# armor_regen().
# ------------------------------------------------------------------

## Reactive Armor's level data for whatever level the rival has it at
## right now - {} if it isn't learned at all (level 0), the same "empty
## means locked" convention every other auto-triggered skill's own
## _get_*_level_data() helper uses.
func _get_enemy_reactive_armor_level_data() -> Dictionary:
	var level: int = PlayerManager.get_npc_skill_level(_enemy_hero_id, "reactive_armor")
	if level <= 0:
		return {}
	var skill: Dictionary = _find_enemy_skill("reactive_armor")
	if skill.is_empty():
		return {}
	return GameManager.get_skill_level_data(skill, level)


func _enemy_reactive_armor_bonus_armor() -> float:
	if _enemy_reactive_armor_stack_turns.is_empty():
		return 0.0
	var level_data: Dictionary = _get_enemy_reactive_armor_level_data()
	if level_data.is_empty():
		return 0.0
	return _enemy_reactive_armor_stack_turns.size() * float(level_data.get("bonus_armor_per_stack", 0.0))


func _apply_enemy_reactive_armor_stack() -> void:
	var level_data: Dictionary = _get_enemy_reactive_armor_level_data()
	if level_data.is_empty():
		return

	var max_stacks: int = int(level_data.get("max_stacks", 0))
	if _enemy_reactive_armor_stack_turns.size() >= max_stacks:
		_enemy_reactive_armor_stack_turns.pop_front()
	_enemy_reactive_armor_stack_turns.append(int(level_data.get("duration", 0)))


func _tick_enemy_reactive_armor_stacks() -> void:
	for i in range(_enemy_reactive_armor_stack_turns.size()):
		_enemy_reactive_armor_stack_turns[i] -= 1
	_enemy_reactive_armor_stack_turns = _enemy_reactive_armor_stack_turns.filter(func(turns_left): return turns_left > 0)


func _apply_enemy_reactive_armor_regen() -> void:
	var level_data: Dictionary = _get_enemy_reactive_armor_level_data()
	if level_data.is_empty() or _enemy_reactive_armor_stack_turns.is_empty():
		return

	var boss: Dictionary = _get_hero_fight_boss()
	if boss.is_empty():
		return

	var max_hp: float = _enemy_hero_effective_max_hp(boss)
	var heal_amount: float = _enemy_reactive_armor_stack_turns.size() * float(level_data.get("bonus_hp_regen_per_stack", 0.0))
	boss["current_hp"] = minf(max_hp, float(boss.get("current_hp", 0.0)) + heal_amount)


# ------------------------------------------------------------------
# Timbersaw's ultimate, Chakram, cast by the rival - mirrors the
# player's own _chakram field/_resolve_chakram_cast()/_tick_chakram()/
# _despawn_chakram(). There's only one possible initial-AoE target in a
# hero fight (the player), so this collapses the "every OTHER enemy
# within radius" splash to a single hit, same simplification every other
# rival AoE cast already uses.
# ------------------------------------------------------------------

func _cast_enemy_chakram(enemy: Dictionary, level_data: Dictionary) -> void:
	var pos_index: int = _hero_pos_index
	var cast_damage: float = float(level_data.get("cast_damage", 0))
	var radius: int = int(level_data.get("radius", 0))
	apply_damage(cast_damage)
	# Planted at the player's own position at cast time - an illusion
	# there (or nearby) takes the same initial burst.
	_deal_aoe_damage_to_illusions(pos_index, radius, cast_damage)
	_deal_aoe_damage_to_bear(pos_index, radius, cast_damage)

	_despawn_enemy_chakram()
	_enemy_chakram = {
		"pos_index": pos_index,
		"radius": int(level_data.get("radius", 0)),
		"damage_per_turn": float(level_data.get("damage_per_turn", 0)),
		"turns_remaining": int(level_data.get("duration", 0)),
		"duration_pending_start": true,
		"node": _spawn_chakram_marker(pos_index),
	}
	_show_message_over_hero("Chakram!")


## Ticks the rival's planted Chakram's duration down once per End Turn,
## same timing (and same "the casting turn doesn't count" skip) as every
## other duration-based buff - dealing this level's own damage_per_turn
## to the player whenever they're within radius columns of the FIXED
## position it was planted at (not re-checked against the player's
## current position - same as the player's own copy), on every tick that
## actually counts against the duration. A no-op while no chakram is
## planted.
func _tick_enemy_chakram() -> void:
	if _enemy_chakram.is_empty():
		return

	if _enemy_chakram.get("duration_pending_start", false):
		_enemy_chakram["duration_pending_start"] = false
		return

	var pos_index: int = int(_enemy_chakram["pos_index"])
	var radius: int = int(_enemy_chakram["radius"])
	var damage_per_turn: float = float(_enemy_chakram["damage_per_turn"])
	if _distance(_hero_pos_index, pos_index) <= radius:
		apply_damage(damage_per_turn)
	# Centered on the same FIXED planted position as the check above -
	# an illusion can be in range independently of whether the player
	# himself currently is.
	_deal_aoe_damage_to_illusions(pos_index, radius, damage_per_turn)
	_deal_aoe_damage_to_bear(pos_index, radius, damage_per_turn)

	_enemy_chakram["turns_remaining"] = int(_enemy_chakram["turns_remaining"]) - 1
	if int(_enemy_chakram["turns_remaining"]) <= 0:
		_despawn_enemy_chakram()


## Removes whatever chakram the rival currently has planted, if any -
## used both when a fresh cast replaces one still active and when its
## duration runs out, same reasoning as the player's own _despawn_
## chakram(). Scene teardown at battle end frees the node implicitly
## either way; also called from _reset_enemy_hero_state() so a marker
## from a PREVIOUS hero fight never lingers into a new one.
func _despawn_enemy_chakram() -> void:
	if _enemy_chakram.is_empty():
		return
	if is_instance_valid(_enemy_chakram.get("node")):
		_enemy_chakram["node"].queue_free()
	_enemy_chakram = {}


# ------------------------------------------------------------------
# Snapfire's Scatterblast, cast by the rival - mirrors the player's own
# _cast_scatterblast(): `level_data.damage` to the player, straight
# ahead of the rival in whichever direction it's currently facing. The
# directional "is the player actually ahead" check already happened
# before this was ever picked as a candidate (see _enemy_skill_in_
# range()'s own "scatterblast" case), so by the time this runs it's
# guaranteed to land - a plain hit, same as every other rival nuke.
# ------------------------------------------------------------------

func _cast_enemy_scatterblast(enemy: Dictionary, level_data: Dictionary) -> void:
	var damage: float = float(level_data.get("damage", 0))
	apply_damage(damage)
	# Directional, not a radius - same "ahead of the caster, in whichever
	# direction it's facing" cone _enemy_skill_in_range()'s own
	# Scatterblast case already checks against the player.
	var direction: int = -1 if bool(enemy["node"].flip_h) else 1
	_deal_directional_aoe_damage_to_illusions(int(enemy["pos_index"]), direction, int(level_data.get("range", 0)), damage)
	_deal_directional_aoe_damage_to_bear(int(enemy["pos_index"]), direction, int(level_data.get("range", 0)), damage)
	# Same particle cone the player's own cast gets (see
	# _play_scatterblast_effect()'s own comment), bursting from the
	# rival's own node instead of hero_image.
	_play_scatterblast_effect(enemy["node"], direction, int(level_data.get("range", 0)))
	_show_message_over_hero("Scatterblast!")


# ------------------------------------------------------------------
# Snapfire's Firesnap Cookie, cast by the rival - mirrors the player's
# own _activate_firesnap_cookie(): hops `jump_distance` columns in
# whichever direction the rival is currently facing (walked one column
# at a time here, stopping early at the board edge or a player-cast Ice
# Shards wall - Snapfire's own range_type is always "Range", so this
# never needs the melee "stop on top of an enemy" rule the way a
# point-blank hero's own copy would), then - on landing - deals damage
# and stuns the player if they're within `radius` columns of wherever it
# ends up. Never "fails" for lack of a target, same as the player's own
# copy - the hop itself always happens.
# ------------------------------------------------------------------

func _cast_enemy_firesnap_cookie(enemy: Dictionary, level_data: Dictionary) -> void:
	var jump_distance: int = int(level_data.get("jump_distance", 0))
	var direction: int = -1 if bool(enemy["node"].flip_h) else 1

	var landing_pos: int = enemy["pos_index"]
	for i in range(jump_distance):
		var next_pos: int = landing_pos + direction
		if next_pos < 0 or next_pos >= GRID_COLUMNS:
			break
		if _is_column_ice_shards_blocked(next_pos):
			break
		landing_pos = next_pos

	_move_enemy(enemy, landing_pos)

	var radius: int = int(level_data.get("radius", 0))
	var damage: float = float(level_data.get("damage", 0))
	if _distance(_hero_pos_index, landing_pos) <= radius:
		apply_damage(damage)
		if _recruited.get("current_hp", 0) > 0:
			_player_stun_turns_left = int(level_data.get("stun_turns", 0))
	# Centered on the landing spot, same as the check above - an
	# illusion can be in range independently of whether the player
	# himself currently is.
	_deal_aoe_damage_to_illusions(landing_pos, radius, damage)
	_deal_aoe_damage_to_bear(landing_pos, radius, damage)

	_show_message_over_hero("Firesnap Cookie!")


# ------------------------------------------------------------------
# Snapfire's Lil' Shredder, cast by the rival - mirrors the player's own
# _resolve_lil_shredder_cast(): fires this level's own `shots` count of
# separately-rolled hits at the player (each _roll_enemy_hero_damage()
# times damage_pct), each shot ALSO stacking armor_reduction_per_shot
# onto _player_armor_reduction - a battle-local runtime value folded
# into _hero_armor() as a straight subtraction, mirroring the player-
# side per-enemy "armor_reduction" field - so a later shot in the SAME
# volley already lands harder than the first, having shredded some of
# the player's armor away already. Stops early if the player dies
# partway through. The whole stack's own duration (this level's own
# `duration`) is only set once, after the last shot connects, same "the
# casting round is never counted against it for free" reasoning
# _tick_player_turn_start_effects() already follows for every other
# duration-based effect.
# ------------------------------------------------------------------

func _cast_enemy_lil_shredder(enemy: Dictionary, level_data: Dictionary) -> void:
	if _enemy_skill_on_bear:
		_cast_enemy_lil_shredder_on_bear(enemy, level_data)
		return
	var shots: int = int(level_data.get("shots", 3))
	var damage_pct: float = float(level_data.get("damage_pct", 0))
	var armor_reduction_per_shot: float = float(level_data.get("armor_reduction_per_shot", 0))

	for i in range(shots):
		if _recruited.get("current_hp", 0) <= 0:
			break
		var shot_damage: float = _roll_enemy_hero_damage(enemy) * damage_pct
		apply_damage(shot_damage)
		# Same staggered impact-spark volley the player's own shots get
		# (see _play_lil_shredder_shot_effect()'s own comment) - purely
		# position-based, so it works the same regardless of which side
		# is casting.
		_play_lil_shredder_shot_effect(_hero_pos_index, i * 0.15)
		if _recruited.get("current_hp", 0) <= 0:
			break
		_player_armor_reduction += armor_reduction_per_shot

	if _recruited.get("current_hp", 0) > 0:
		_player_armor_reduction_turns_left = int(level_data.get("duration", 0))

	_show_message_over_hero("Lil' Shredder!")


# ------------------------------------------------------------------
# Naga Siren's passive, Rip Tide, on the rival - mirrors the player's own
# _get_rip_tide_level_data(). Never a scored candidate of its own (see
# EnemySkillAI's own header comment) - its bonuses only ever reach Mirror
# Image/Song of the Siren/a plain Attack through _build_enemy_ai_
# context()'s own "rip_tide_*" fields. Its AoE splash (aoe_damage_pct/
# radius) never has an actual second target to reach in a real hero fight
# (there's only ever the one player to hit - same "no cleave" collapse
# Dark Pact's/Ghostship's/Whirling Death's own rival copies already have,
# see _cast_enemy_dark_pact()'s own docstring), so unlike the player's
# own _apply_rip_tide_cleave() there's no enemy-side cleave function here
# at all - "rip_tide_aoe_damage_pct" only ever feeds EnemySkillAI's own
# scoring (a splash EnemyHeroManager's own multi-enemy simulation CAN
# actually land, via its own "no columns, hit everyone" fallback - see
# that file's own "song_of_the_siren"/rip-tide-flavored comment).
# ------------------------------------------------------------------

## Rip Tide's level data for whatever level the rival has it at right
## now - {} if it isn't learned at all (level 0), the same "empty means
## locked" convention every other auto-triggered skill's own _get_enemy_
## *_level_data() helper uses.
func _get_enemy_rip_tide_level_data() -> Dictionary:
	var level: int = PlayerManager.get_npc_skill_level(_enemy_hero_id, "rip_tide")
	if level <= 0:
		return {}
	var skill: Dictionary = _find_enemy_skill("rip_tide")
	if skill.is_empty():
		return {}
	return GameManager.get_skill_level_data(skill, level)


# ------------------------------------------------------------------
# Naga Siren's Mirror Image, cast by the rival - mirrors the player's own
# _activate_mirror_image()/_spawn_illusion_node()/_tick_mirror_image()/
# _fire_mirror_image_attack()/_end_mirror_image()/_deal_damage_to_
# illusion()/_kill_illusion(). Unlike the player's own copy (which spawns
# decoys in the columns immediately in front of and behind the hero),
# there's only one possible target in a hero fight (the player), so
# _fire_enemy_mirror_image_attack() collapses to a single "every
# surviving illusion hits the player" loop rather than picking among
# multiple enemies, same "no cleave" simplification every other rival
# AoE cast already uses.
# ------------------------------------------------------------------

func _cast_enemy_mirror_image(enemy: Dictionary, level_data: Dictionary) -> void:
	_end_enemy_mirror_image()

	var rip_tide_level_data: Dictionary = _get_enemy_rip_tide_level_data()

	var direction: int = -1 if bool(enemy["node"].flip_h) else 1
	var caster_pos: int = int(enemy["pos_index"])
	var front_pos: int = clampi(caster_pos + direction, 0, GRID_COLUMNS - 1)
	var behind_pos: int = clampi(caster_pos - direction, 0, GRID_COLUMNS - 1)

	var illusions_count: int = int(level_data.get("illusions", 3)) + int(rip_tide_level_data.get("extra_illusion", 0))
	var illusion_hp: float = _enemy_hero_effective_max_hp(enemy) * float(level_data.get("hp_pct", 0.0))

	for i in range(illusions_count):
		var pos: int
		if i == 0:
			pos = front_pos
		elif i == 1:
			pos = behind_pos
		else:
			pos = front_pos if randf() < 0.5 else behind_pos
		_enemy_illusions.append({
			"pos_index": pos,
			"current_hp": illusion_hp,
			"max_hp": illusion_hp,
			"node": _spawn_enemy_illusion_node(pos, enemy["node"]),
		})

	_enemy_illusion_damage_pct = float(level_data.get("damage_pct", 0.0)) + float(rip_tide_level_data.get("illusion_damage_bonus_pct", 0.0))
	_enemy_illusion_hit_chance_pct = float(level_data.get("hit_chance_pct", 0.0))
	_enemy_illusions_turns_remaining = int(level_data.get("duration", 0)) + int(rip_tide_level_data.get("illusion_duration_bonus", 0))
	# The casting turn itself doesn't count - duration only starts
	# ticking (and the illusions only start attacking) from the turn
	# after (see _tick_enemy_mirror_image()), same as every other
	# duration-based buff.
	_enemy_illusions_duration_pending_start = true

	_show_message_over_hero("Mirror Image!")


## Purely visual: a copy of `source_node`'s own current texture, faded to
## HERO_ILLUSION_ALPHA so the real boss still reads clearly among its own
## decoys, positioned on `pos_index`'s own column - mirrors the player's
## own _spawn_illusion_node() exactly, just reading `source_node`'s own
## texture/flip_h/size instead of hero_image's.
func _spawn_enemy_illusion_node(pos_index: int, source_node: TextureRect) -> TextureRect:
	var tex_rect := TextureRect.new()
	tex_rect.texture = source_node.texture
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	tex_rect.size = source_node.size
	tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tex_rect.flip_h = source_node.flip_h
	tex_rect.modulate = Color(1, 1, 1, HERO_ILLUSION_ALPHA)
	tex_rect.position = Vector2(_index_to_x(pos_index), _creature_y())
	add_child(tex_rect)
	move_child(tex_rect, enemies_layer.get_index() + 1)
	return tex_rect


## Ticks the rival's Mirror Image duration down once per End Turn, same
## timing (and same "the casting turn doesn't count" skip) as every other
## duration-based buff - firing the illusions' own attack
## (_fire_enemy_mirror_image_attack()) on every tick that actually counts
## against the duration, then ending the effect once it runs out. A no-op
## once every illusion has already died in combat, and while none are up
## at all.
func _tick_enemy_mirror_image() -> void:
	if _enemy_illusions.is_empty():
		return

	if _enemy_illusions_duration_pending_start:
		_enemy_illusions_duration_pending_start = false
		return

	_fire_enemy_mirror_image_attack()

	_enemy_illusions_turns_remaining -= 1
	if _enemy_illusions_turns_remaining <= 0:
		_end_enemy_mirror_image()


## Every surviving illusion strikes the player - the only possible target
## in a hero fight - each illusion rolling its own rival-damage instance
## (_roll_enemy_hero_damage()) scaled by _enemy_illusion_damage_pct, same
## "own roll per hit" idiom the player's own _fire_mirror_image_attack()
## uses, mitigated by the player's own current armor via apply_damage().
## Stops early if that focus-fire finishes the player off partway
## through.
func _fire_enemy_mirror_image_attack() -> void:
	var boss: Dictionary = _get_hero_fight_boss()
	if boss.is_empty():
		return
	for illusion in _enemy_illusions.duplicate():
		if _recruited.get("current_hp", 0) <= 0:
			break
		var illusion_damage: float = _roll_enemy_hero_damage(boss) * _enemy_illusion_damage_pct
		apply_damage(illusion_damage)


## Ends the rival's Mirror Image, despawning every surviving illusion -
## called both when its duration runs out (_tick_enemy_mirror_image())
## and defensively at the top of _cast_enemy_mirror_image() so a recast
## mid-duration never leaks the old set's nodes, and from
## _reset_enemy_hero_state() so a set from a PREVIOUS hero fight never
## lingers into a new one.
func _end_enemy_mirror_image() -> void:
	for illusion in _enemy_illusions:
		if is_instance_valid(illusion.get("node")):
			illusion["node"].queue_free()
	_enemy_illusions.clear()
	_enemy_illusion_damage_pct = 0.0
	_enemy_illusion_hit_chance_pct = 0.0
	_enemy_illusions_turns_remaining = 0
	_enemy_illusions_duration_pending_start = false


## Applies `amount` of already-mitigated damage to `illusion` - the
## rival-side equivalent of the player's own _deal_damage_to_illusion(),
## just against _enemy_illusions instead of _illusions. Called from
## _deal_fixed_damage_to_enemy() whenever a hit redirects onto an
## illusion instead of the boss itself.
func _deal_damage_to_enemy_illusion(illusion: Dictionary, amount: float, is_critical: bool = false) -> void:
	illusion["current_hp"] = float(illusion.get("current_hp", 0.0)) - amount
	if is_instance_valid(illusion.get("node")):
		_show_damage_number(illusion["node"], amount, is_critical)
	if illusion["current_hp"] <= 0:
		_kill_enemy_illusion(illusion)


## Removes one illusion that's died in combat - the rival-side mirror of
## the player's own _kill_illusion(). Doesn't end Mirror Image outright
## even if this was the last one; _tick_enemy_mirror_image()'s own
## early-empty check just makes every remaining tick a no-op until the
## duration itself finally runs out.
func _kill_enemy_illusion(illusion: Dictionary) -> void:
	if is_instance_valid(illusion.get("node")):
		illusion["node"].queue_free()
	_enemy_illusions.erase(illusion)


## The boss's own effective armor for mitigating a hit onto one of its
## illusions - base armor plus its own borrowed bonuses (Reactive
## Armor's stack, Essence Shift, etc., via _enemy_hero_bonus_armor())
## minus Lil' Shredder's own shred, same three terms
## _deal_fixed_damage_to_enemy()'s own redirect branch already reads.
## An illusion is a copy of the boss, not a separate combatant with its
## own defense stat, so it mitigates exactly as if the boss had taken
## the hit itself.
func _enemy_hero_effective_armor(boss: Dictionary) -> float:
	return float(boss["static"].get("armor", 0)) + _enemy_hero_bonus_armor(boss) - float(boss.get("armor_reduction", 0.0))


## Any player AoE skill that damages the boss over an area should ALSO
## independently hit every surviving enemy illusion within that same
## area - the mirror of _deal_aoe_damage_to_illusions() for the rival's
## own Mirror Image. `amount` is the RAW, pre-mitigation damage the AoE
## would deal to the boss - each illusion mitigates it separately via
## the boss's own effective armor (_enemy_hero_effective_armor()). A
## no-op while no enemy illusions are up or there's no boss to read
## armor from (i.e. outside a hero fight).
## `flash_hits` gives each one hit the same red hit-flash as Moon
## Glaives' bounce (_flash_bounce_hit()) - off by default, opted into by
## Dark Pact.
func _deal_aoe_damage_to_enemy_illusions(center_pos_index: int, radius: int, amount: float, flash_hits: bool = false) -> void:
	if _enemy_illusions.is_empty() or amount <= 0.0:
		return

	var boss: Dictionary = _get_hero_fight_boss()
	if boss.is_empty():
		return

	var mitigated: float = _apply_armor_reduction(amount, _enemy_hero_effective_armor(boss))
	for illusion in _enemy_illusions.duplicate():
		if _distance(illusion["pos_index"], center_pos_index) <= radius:
			_deal_damage_to_enemy_illusion(illusion, mitigated)
			if flash_hits and is_instance_valid(illusion.get("node")):
				_flash_bounce_hit(illusion["node"])


## The line-shaped equivalent of _deal_aoe_damage_to_enemy_illusions()
## above - for Ghostship's/Timber Chain's own "every column between the
## caster and the target, inclusive of both ends" line. Same "amount is
## raw, each illusion mitigates it separately via the boss's own
## effective armor" contract.
func _deal_line_aoe_damage_to_enemy_illusions(start_pos_index: int, end_pos_index: int, amount: float) -> void:
	if _enemy_illusions.is_empty() or amount <= 0.0:
		return

	var boss: Dictionary = _get_hero_fight_boss()
	if boss.is_empty():
		return

	var start_col: int = mini(start_pos_index, end_pos_index)
	var end_col: int = maxi(start_pos_index, end_pos_index)
	var mitigated: float = _apply_armor_reduction(amount, _enemy_hero_effective_armor(boss))
	for illusion in _enemy_illusions.duplicate():
		var pos: int = illusion["pos_index"]
		if pos >= start_col and pos <= end_col:
			_deal_damage_to_enemy_illusion(illusion, mitigated)


## The directional-cone equivalent of the two AoE-shape helpers above -
## for the player's own Scatterblast facing-based cone. Same "amount is
## raw, each illusion mitigates it separately via the boss's own
## effective armor" contract.
func _deal_directional_aoe_damage_to_enemy_illusions(origin_pos_index: int, direction: int, range_columns: int, amount: float) -> void:
	if _enemy_illusions.is_empty() or amount <= 0.0:
		return

	var boss: Dictionary = _get_hero_fight_boss()
	if boss.is_empty():
		return

	var mitigated: float = _apply_armor_reduction(amount, _enemy_hero_effective_armor(boss))
	for illusion in _enemy_illusions.duplicate():
		var ahead: int = (illusion["pos_index"] - origin_pos_index) * direction
		if ahead >= 0 and ahead <= range_columns:
			_deal_damage_to_enemy_illusion(illusion, mitigated)


# ------------------------------------------------------------------
# Naga Siren's Ensnare, cast by the rival on the player - mirrors the
# player's own _resolve_ensnare_cast(): this level's own `damage`
# (through normal armor mitigation, via apply_damage()) plus a root for
# `root_turns` of the player's own turns (_player_root_turns_left, the
# same shared field Entangle's/Overgrowth's own root already use) -
# unlike Entangle, no silence/DoT fields are touched at all, so (per the
# design doc's own explicit "Ensnare is not a stun" instruction) the
# player can still attack/cast skills while rooted, just not move. Only
# roots if the hit actually left the player alive.
# ------------------------------------------------------------------

func _cast_enemy_ensnare(level_data: Dictionary) -> void:
	if _enemy_skill_on_bear:
		_cast_enemy_ensnare_on_bear(level_data)
		return
	apply_damage(float(level_data.get("damage", 0)))
	if _recruited.get("current_hp", 0) > 0:
		_player_root_turns_left = int(level_data.get("root_turns", 0))
	_show_message_over_hero("Ensnare!")


# ------------------------------------------------------------------
# Naga Siren's ultimate, Song of the Siren, cast by the rival - mirrors
# the player's own _cast_song_of_the_siren(): stuns (_player_stun_turns_
# left, the same shared field Pounce's/Torrent's/Firesnap Cookie's own
# stun already use) and shreds the armor (_player_armor_reduction/
# _player_armor_reduction_turns_left, the same per-instance runtime
# fields Lil' Shredder's own shred uses - stacking additively with any
# already there, but refreshing, not adding to, the turns left) of the
# player, if they're within this level's own radius of the rival's
# CURRENT position - there's only one possible target in a hero fight, so
# this collapses to a single conditional hit rather than a loop over
# multiple enemies, same simplification every other rival AoE cast
# already uses. Purely offensive - no damage of its own, and nothing
# about the rival itself changes (it and its illusions can still move/
# attack normally the whole time).
# ------------------------------------------------------------------

func _cast_enemy_song_of_the_siren(enemy: Dictionary, level_data: Dictionary) -> void:
	var radius: int = int(level_data.get("radius", 0))
	if _distance(enemy["pos_index"], _hero_pos_index) <= radius:
		_player_stun_turns_left = int(level_data.get("stun_turns", 0))
		_player_armor_reduction += float(level_data.get("armor_reduction", 0))
		_player_armor_reduction_turns_left = int(level_data.get("stun_turns", 0))

	_show_message_over_hero("Song of the Siren!")


# ------------------------------------------------------------------
# Slardar's Guardian Sprint, cast by the rival - mirrors the player's own
# _activate_guardian_sprint()/_guardian_sprint_move_target()/_tick_
# guardian_sprint()/_end_guardian_sprint(). Arms the buff exactly the
# same way (doesn't move the rival itself when cast); only its own
# fallback movement (_enemy_hero_turn()'s own "not hero_hidden and not
# rooted" tail, once no skill/attack is available) actually reads it,
# same "only the NEXT normal move changes" shape the player's own copy
# has in _hero_move().
# ------------------------------------------------------------------

func _cast_enemy_guardian_sprint(level_data: Dictionary) -> void:
	_enemy_guardian_sprint_bonus_movement = int(level_data.get("bonus_movement", 0))
	_enemy_guardian_sprint_charge_damage_pct = float(level_data.get("charge_damage_pct", 0.0))
	_enemy_guardian_sprint_turns_remaining = int(level_data.get("duration", 0))
	# The casting turn itself doesn't count - duration only starts
	# ticking from the turn after (see _tick_enemy_guardian_sprint()),
	# same as every other duration-based buff. The bonus itself is
	# already live the instant this returns.
	_enemy_guardian_sprint_duration_pending_start = true

	_show_message_over_hero("Guardian Sprint!")


## Guardian Sprint's own movement rule, on the rival's side - mirrors the
## player's own _guardian_sprint_move_target() exactly, just stopping on
## the PLAYER's own column instead of searching _enemies for one (there's
## only ever the one possible "enemy" to stop on in a hero fight - see
## this section's own header comment). Walks up to `distance` columns
## from `start` in `direction`, stopping early at the board edge, a
## player-cast Ice Shards wall, OR the player's own column - regardless
## of the rival's own type, same "stop on top of an enemy" rule every
## other rival gap-closer (Firesnap Cookie's hop, Timber Chain's pull)
## already follows. Returns both the landing column and whether it
## actually stopped on the player, for the caller to deal Guardian
## Sprint's own charge_damage to.
func _enemy_guardian_sprint_move_target(start: int, direction: int, distance: int) -> Dictionary:
	var pos: int = start
	var hit_player: bool = false

	for i in range(distance):
		var next_pos: int = pos + direction
		if next_pos < 0 or next_pos >= GRID_COLUMNS:
			break
		if _is_column_ice_shards_blocked(next_pos):
			break
		pos = next_pos

		if pos == _hero_pos_index:
			hit_player = true
			break

	return {"pos": pos, "hit_player": hit_player}


func _tick_enemy_guardian_sprint() -> void:
	if _enemy_guardian_sprint_turns_remaining <= 0:
		return

	if _enemy_guardian_sprint_duration_pending_start:
		_enemy_guardian_sprint_duration_pending_start = false
		return

	_enemy_guardian_sprint_turns_remaining -= 1
	if _enemy_guardian_sprint_turns_remaining <= 0:
		_end_enemy_guardian_sprint()


func _end_enemy_guardian_sprint() -> void:
	_enemy_guardian_sprint_turns_remaining = 0
	_enemy_guardian_sprint_bonus_movement = 0
	_enemy_guardian_sprint_charge_damage_pct = 0.0
	_enemy_guardian_sprint_duration_pending_start = false


# ------------------------------------------------------------------
# Slardar's Slithereen Crush, cast by the rival - mirrors the player's
# own _cast_slithereen_crush(): this level's own `damage` (through normal
# armor mitigation, via apply_damage()) plus a stun (_player_stun_turns_
# left, the same shared field Pounce's/Torrent's/Song of the Siren's own
# stun already use) for `stun_turns` of the player's own turns, if
# they're within `radius` columns of the rival's CURRENT position -
# there's only one possible target in a hero fight, so this collapses to
# a single conditional hit rather than a loop over multiple enemies, same
# simplification every other self-centered rival AoE cast already uses
# (see _cast_enemy_overgrowth()'s own docstring). Only stuns if the hit
# actually left the player alive. Centered on the caster's own column,
# same as the check above - an illusion/the player's own Spirit Bear can
# be in range independently of whether the player himself currently is,
# same "one-time hit for whatever's caught in the burst" reasoning
# _cast_enemy_whirling_death()'s own copy already follows (illusions have
# no stun of their own to carry, same as they have no root/DoT in
# Overgrowth's own copy).
# ------------------------------------------------------------------

func _cast_enemy_slithereen_crush(enemy: Dictionary, level_data: Dictionary) -> void:
	var radius: int = int(level_data.get("radius", 0))
	var damage: float = float(level_data.get("damage", 0))
	if _distance(enemy["pos_index"], _hero_pos_index) <= radius:
		apply_damage(damage)
		if _recruited.get("current_hp", 0) > 0:
			_player_stun_turns_left = int(level_data.get("stun_turns", 0))
	_deal_aoe_damage_to_illusions(enemy["pos_index"], radius, damage)
	_deal_aoe_damage_to_bear(enemy["pos_index"], radius, damage)

	_show_message_over_hero("Slithereen Crush!")


# ------------------------------------------------------------------
# Slardar's passive, Bash of the Deep, on the rival - mirrors the
# player's own _get_bash_of_the_deep_level_data()/_maybe_consume_bash_of_
# the_deep_stack()/_apply_bash_of_the_deep_knockback(). Never a scored
# candidate of its own (see EnemySkillAI's own header comment) - its
# progression only ever reaches Guardian Sprint/Slithereen Crush/
# Corrosive Haze/a plain Attack through _build_enemy_ai_context()'s own
# "bash_*" fields, and its actual bonus damage/knockback only ever land
# through _resolve_enemy_hero_attack()'s own plain-Attack path, same
# "only a real Attack builds/consumes the stack" rule the player's own
# copy follows.
# ------------------------------------------------------------------

func _get_enemy_bash_of_the_deep_level_data() -> Dictionary:
	var level: int = PlayerManager.get_npc_skill_level(_enemy_hero_id, "bash_of_the_deep")
	if level <= 0:
		return {}
	var skill: Dictionary = _find_enemy_skill("bash_of_the_deep")
	if skill.is_empty():
		return {}
	return GameManager.get_skill_level_data(skill, level)


func _maybe_consume_enemy_bash_of_the_deep_stack() -> Dictionary:
	var level_data: Dictionary = _get_enemy_bash_of_the_deep_level_data()
	if level_data.is_empty():
		return {}

	_enemy_bash_of_the_deep_attack_count += 1
	if _enemy_bash_of_the_deep_attack_count < int(level_data.get("attacks_required", 1)):
		return {}

	_enemy_bash_of_the_deep_attack_count = 0
	return level_data


## Knocks the player back this level's own `knockback` columns, away from
## the rival (its own distance-to-player direction, falling back to its
## own facing on the rare column-share tie, same "still shove SOMEWHERE"
## reasoning Pounce's own leap uses for the mirror-image case) - stopping
## early at the board edge or a player-cast Ice Shards wall. Repositions
## instantly via _hero_pos_index/_update_hero_position(), the same path
## every other player-repositioning effect in this file uses.
func _apply_enemy_bash_of_the_deep_knockback(enemy: Dictionary, level_data: Dictionary) -> void:
	var knockback_columns: int = int(level_data.get("knockback", 0))
	var direction: int = _step_toward(enemy["pos_index"], _hero_pos_index)
	if direction == 0:
		direction = -1 if bool(enemy["node"].flip_h) else 1
	var pos: int = _hero_pos_index

	for i in range(knockback_columns):
		var next_pos: int = pos + direction
		if next_pos < 0 or next_pos >= GRID_COLUMNS:
			break
		if _is_column_ice_shards_blocked(next_pos):
			break
		pos = next_pos

	if pos != _hero_pos_index:
		_hero_pos_index = pos
		_update_hero_position()


# ------------------------------------------------------------------
# Slardar's ultimate, Corrosive Haze, cast by the rival on the player -
# mirrors the player's own _resolve_corrosive_haze_cast(): reduces the
# player's own armor by this level's own `armor_reduction`
# (_player_armor_reduction, the same shared runtime field Lil' Shredder's
# own shred/Song of the Siren's own shred already use - stacking
# additively with any already there) and marks him with `bonus_damage_
# pct` (_player_corrosive_haze_bonus_pct, read by apply_damage() to boost
# every hit he takes from the rival's own attacks/skills - overwritten
# outright on recast, not stacked). Both share _player_armor_reduction_
# turns_left as their own turns-left counter, same "share the shred's own
# timer" convention the player-side copy uses. There's only one possible
# target in a hero fight, so - unlike the player's own copy, which needs
# to pick one among several enemies - this needs no separate targeting
# step at all, same simplification Entangle's/Torrent's own enemy-side
# copies already use. Deals no damage of its own - a pure debuff.
# ------------------------------------------------------------------

func _cast_enemy_corrosive_haze(level_data: Dictionary) -> void:
	if _enemy_skill_on_bear:
		_cast_enemy_corrosive_haze_on_bear(level_data)
		return
	_player_armor_reduction += float(level_data.get("armor_reduction", 0))
	_player_corrosive_haze_bonus_pct = float(level_data.get("bonus_damage_pct", 0.0))
	_player_armor_reduction_turns_left = int(level_data.get("duration", 0))

	_show_message_over_hero("Corrosive Haze!")


# ------------------------------------------------------------------
# Mirana's Starstorm, cast by the rival - mirrors the player's own
# _cast_starstorm(): this level's own `damage` (through normal armor
# mitigation, via apply_damage()) if the player is within `radius`
# columns of the rival's CURRENT position - there's only one possible
# target in a hero fight, so this collapses to a single conditional hit
# rather than a loop over multiple enemies, same simplification every
# other self-centered rival AoE cast already uses (see
# _cast_enemy_overgrowth()'s own docstring). No stun of its own - purely
# a damage nuke, same as the player-side copy. Centered on the caster's
# own column, same as the check above - an illusion/the player's own
# Spirit Bear can be in range independently of whether the player himself
# currently is, same "one-time hit for whatever's caught in the burst"
# reasoning _cast_enemy_whirling_death()'s own copy already follows.
# ------------------------------------------------------------------

func _cast_enemy_starstorm(enemy: Dictionary, level_data: Dictionary) -> void:
	var radius: int = int(level_data.get("radius", 0))
	var damage: float = float(level_data.get("damage", 0))
	if _distance(enemy["pos_index"], _hero_pos_index) <= radius:
		apply_damage(damage)
	_deal_aoe_damage_to_illusions(enemy["pos_index"], radius, damage)
	_deal_aoe_damage_to_bear(enemy["pos_index"], radius, damage)

	_show_message_over_hero("Starstorm!")


# ------------------------------------------------------------------
# Mirana's Sacred Arrow, cast by the rival on the player - mirrors the
# player's own _resolve_sacred_arrow_cast(): this level's own base_damage
# plus bonus_per_column for every column between the rival and the
# player at the moment it's cast (through normal armor mitigation, via
# apply_damage()), then stuns the player (_player_stun_turns_left, the
# same shared field Pounce's/Torrent's/Song of the Siren's own stun
# already use) for this level's own stun_turns, only if the hit left him
# alive. There's only one possible target in a hero fight, so - unlike
# the player's own copy, which needs a separate targeting click - this
# needs no separate targeting step at all, same simplification Entangle's/
# Torrent's own enemy-side copies already use.
# ------------------------------------------------------------------

func _cast_enemy_sacred_arrow(enemy: Dictionary, level_data: Dictionary) -> void:
	if _enemy_skill_on_bear:
		_cast_enemy_sacred_arrow_on_bear(enemy, level_data)
		return
	var distance: int = _distance(enemy["pos_index"], _hero_pos_index)
	var damage: float = float(level_data.get("base_damage", 0)) + float(level_data.get("bonus_per_column", 0)) * distance
	apply_damage(damage)
	if _recruited.get("current_hp", 0) > 0:
		_player_stun_turns_left = int(level_data.get("stun_turns", 0))
	# Same light-blue flight the player's own cast gets (see
	# _play_sacred_arrow_flight()'s own comment), just flying the other
	# way - from the rival's own node to hero_image.
	_play_sacred_arrow_flight(enemy["node"], hero_image, distance)

	_show_message_over_hero("Sacred Arrow!")


# ------------------------------------------------------------------
# Mirana's Leap, cast by the rival - mirrors the player's own
# _activate_leap(): hops `jump_distance` columns, always sailing clean
# over the player regardless of range_type (the unobstructed "walk
# straight through" rule _ranged_move_target() already uses), stopping
# only at the board edge or a player-cast Ice Shards wall. No damage, no
# target required - always "succeeds". Unlike a gap-closer that always
# steps toward the nearest enemy, the direction here is CHOSEN by the
# rival's own current danger, mirroring the exact hp_ratio threshold
# EnemySkillAI's own _mirana_leap_modifier() scores both directions
# against (see that function's own docstring for why the two must stay
# in lockstep): away from the player while genuinely threatened, toward
# the player otherwise (closing distance is the dominant, offensive use
# per the design doc's own framing).
# ------------------------------------------------------------------

func _cast_enemy_leap(enemy: Dictionary, level_data: Dictionary) -> void:
	var jump_distance: int = int(level_data.get("jump_distance", 0))

	var effective_max_hp: float = _enemy_hero_effective_max_hp(enemy)
	var hp_ratio: float = (float(enemy.get("current_hp", 0.0)) / effective_max_hp) if effective_max_hp > 0.0 else 1.0

	var toward_player: int = _step_toward(enemy["pos_index"], _hero_pos_index)
	var direction: int = toward_player
	if hp_ratio < 0.35 and toward_player != 0:
		direction = -toward_player
	elif toward_player == 0:
		direction = -1 if bool(enemy["node"].flip_h) else 1

	var pos: int = enemy["pos_index"]
	for i in range(jump_distance):
		var next_pos: int = pos + direction
		if next_pos < 0 or next_pos >= GRID_COLUMNS:
			break
		if _is_column_ice_shards_blocked(next_pos):
			break
		pos = next_pos

	_move_enemy(enemy, pos)
	_show_message_over_hero("Leap!")


# ------------------------------------------------------------------
# Mirana's ultimate, Moonlight Shadow, cast by the rival - mirrors the
# player's own _activate_moonlight_shadow()/_tick_moonlight_shadow()/
# _end_moonlight_shadow(). Arms the buff exactly the same way; its own
# targeting/visibility effects are enforced elsewhere (_is_target_
# hidden()/_update_enemy_hero_visibility(), both already extended to read
# this flag) and its own Attack bonus is folded into
# _resolve_enemy_hero_attack()'s own roll, same "only the NEXT Attack
# pays off" shape the player-side copy has in _apply_hero_attack().
# ------------------------------------------------------------------

func _cast_enemy_moonlight_shadow(level_data: Dictionary) -> void:
	_enemy_moonlight_shadow_active = true
	_enemy_moonlight_shadow_bonus_damage_pct = float(level_data.get("bonus_damage_pct", 0.0))
	_enemy_moonlight_shadow_turns_remaining = int(level_data.get("duration", 0))
	_enemy_moonlight_shadow_duration_pending_start = true

	_show_message_over_hero("Moonlight Shadow!")
	_update_enemy_hero_visibility()


func _tick_enemy_moonlight_shadow() -> void:
	if not _enemy_moonlight_shadow_active:
		return

	if _enemy_moonlight_shadow_duration_pending_start:
		_enemy_moonlight_shadow_duration_pending_start = false
		return

	_enemy_moonlight_shadow_turns_remaining -= 1
	if _enemy_moonlight_shadow_turns_remaining <= 0:
		_end_enemy_moonlight_shadow()


func _end_enemy_moonlight_shadow() -> void:
	var was_active: bool = _enemy_moonlight_shadow_active
	_enemy_moonlight_shadow_active = false
	_enemy_moonlight_shadow_bonus_damage_pct = 0.0
	_enemy_moonlight_shadow_turns_remaining = 0
	_enemy_moonlight_shadow_duration_pending_start = false

	if was_active:
		_update_enemy_hero_visibility()


# ------------------------------------------------------------------
# Luna's Moon Glaives, on the rival - a passive, so unlike every cast
# skill above there's no button/cast/mana/cooldown for it. Mirrors the
# player's own _get_moon_glaives_level_data()/_apply_moon_glaives_
# bounces(), simplified for the one real difference a hero fight has:
# there's no second real _enemies-style target the rival's own Attack
# could bounce onto besides the player himself (already the primary
# hit) - only the player's own illusions/Spirit Bear are real, separate
# occupants of their own columns near him, so those are the only actual
# bounce targets here, hit exactly the same "unconditional collateral,
# never counted toward the bounce cap" way the player-side copy already
# treats them (see that function's own comment).
# ------------------------------------------------------------------

func _get_enemy_moon_glaives_level_data() -> Dictionary:
	var level: int = PlayerManager.get_npc_skill_level(_enemy_hero_id, "moon_glaives")
	if level <= 0:
		return {}
	var skill: Dictionary = _find_enemy_skill("moon_glaives")
	if skill.is_empty():
		return {}
	return GameManager.get_skill_level_data(skill, level)


## `attack_damage` is the rival's own already-rolled Attack damage
## (already including Lunar Blessing - see _roll_enemy_hero_damage()'s
## own docstring), same raw, pre-mitigation figure the player-side copy
## bounces off of. A no-op while the skill isn't learned.
func _apply_enemy_moon_glaives_bounces(attack_damage: float) -> void:
	var level_data: Dictionary = _get_enemy_moon_glaives_level_data()
	if level_data.is_empty():
		return

	var bounce_damage: float = attack_damage * float(level_data.get("bounce_damage_pct", 0.0))
	if bounce_damage <= 0.0:
		return

	var radius: int = int(level_data.get("bounce_range", 0))
	_deal_aoe_damage_to_illusions(_hero_pos_index, radius, bounce_damage)
	_deal_aoe_damage_to_bear(_hero_pos_index, radius, bounce_damage)


# ------------------------------------------------------------------
# Luna's Lunar Blessing, on the rival - a passive, so unlike every cast
# skill above there's no button/cast/mana/cooldown for it. Just a
# permanent % increase to the rival's own Attack damage, read fresh off
# this level's own bonus_damage_pct by _roll_enemy_hero_damage() itself
# (see that function's own comment) rather than anything ticked or
# tracked here.
# ------------------------------------------------------------------

func _get_enemy_lunar_blessing_level_data() -> Dictionary:
	var level: int = PlayerManager.get_npc_skill_level(_enemy_hero_id, "lunar_blessing")
	if level <= 0:
		return {}
	var skill: Dictionary = _find_enemy_skill("lunar_blessing")
	if skill.is_empty():
		return {}
	return GameManager.get_skill_level_data(skill, level)


# ------------------------------------------------------------------
# Luna's Lucent Beam, cast by the rival on the player - mirrors the
# player's own _resolve_lucent_beam_cast(): this level's own flat
# `damage` (through normal armor mitigation, via apply_damage()), then
# stuns the player (_player_stun_turns_left, the same shared field
# Pounce's/Torrent's/Sacred Arrow's own stun already use) for this
# level's own stun_turns, only if the hit left him alive. There's only
# one possible target in a hero fight, so - unlike the player's own copy,
# which needs a separate targeting click - this needs no separate
# targeting step at all, same simplification Entangle's/Torrent's own
# enemy-side copies already use. No Moon Glaives bounce here - the
# player-side copy never applies it to Lucent Beam either (only a plain
# Attack triggers it - see _apply_hero_attack()'s own call site).
# ------------------------------------------------------------------

func _cast_enemy_lucent_beam(level_data: Dictionary) -> void:
	if _enemy_skill_on_bear:
		_cast_enemy_lucent_beam_on_bear(level_data)
		return
	apply_damage(float(level_data.get("damage", 0)))
	if _recruited.get("current_hp", 0) > 0:
		_player_stun_turns_left = int(level_data.get("stun_turns", 0))
	# Same falling-moonlight visual the player's own cast gets (see
	# _play_lucent_beam_impact()'s own comment) - hero_image is a
	# TextureRect just like an enemy's own node, so it drops onto him
	# exactly the same way.
	_play_lucent_beam_impact(hero_image)

	_show_message_over_hero("Lucent Beam!")


# ------------------------------------------------------------------
# Luna's ultimate, Eclipse, cast by the rival - mirrors the player's own
# _activate_eclipse()/_tick_eclipse()/_end_eclipse().
# ------------------------------------------------------------------

func _cast_enemy_eclipse(level_data: Dictionary) -> void:
	_enemy_eclipse_active = true
	_enemy_eclipse_damage_per_beam = float(level_data.get("damage", 0))
	_enemy_eclipse_radius = int(level_data.get("radius", 0))
	_enemy_eclipse_beams_remaining = int(level_data.get("beams", 0))
	# The casting turn itself doesn't count - beams only start landing
	# from the turn after (see _tick_enemy_eclipse()), same as every
	# other duration-based buff.
	_enemy_eclipse_duration_pending_start = true

	_show_message_over_hero("Eclipse!")


## Ticks Eclipse once per End Turn, same timing (and same "the casting
## turn doesn't count" skip) as the player-side copy - fires up to
## ECLIPSE_BEAMS_PER_TURN beams (or however many are left) this turn.
## Each beam independently rolls ONE random living, targetable candidate
## from the player himself (if within `radius` columns of the rival's
## CURRENT position, re-checked fresh here, not fixed at cast time), any
## of the player's own illusions within that same radius of the rival,
## and the player's own Spirit Bear if it's alive and in range too - the
## enemy-side mirror of the player-side copy's own "boss, or one of its
## illusions" pool, extended with the bear since (unlike the boss's own
## Spirit Bear, a genuine _enemies entry the player-side pool already
## reaches for free) the player's own bear is a separate structure with
## no equivalent array to fall into automatically. A beam with nothing in
## range still counts against the total, same as the player-side copy.
## Ends the instant every beam has landed.
func _tick_enemy_eclipse() -> void:
	if not _enemy_eclipse_active:
		return

	if _enemy_eclipse_duration_pending_start:
		_enemy_eclipse_duration_pending_start = false
		return

	var boss: Dictionary = _get_hero_fight_boss()
	if boss.is_empty():
		_end_enemy_eclipse()
		return

	for i in range(ECLIPSE_BEAMS_PER_TURN):
		if _enemy_eclipse_beams_remaining <= 0:
			break
		_enemy_eclipse_beams_remaining -= 1

		var candidates: Array = []
		if _distance(_hero_pos_index, boss["pos_index"]) <= _enemy_eclipse_radius:
			candidates.append({"kind": "player"})
		for illusion in _illusions:
			if _distance(illusion["pos_index"], boss["pos_index"]) <= _enemy_eclipse_radius:
				candidates.append({"kind": "illusion", "ref": illusion})
		if _is_bear_alive() and _distance(_bear["pos_index"], boss["pos_index"]) <= _enemy_eclipse_radius:
			candidates.append({"kind": "bear"})

		if not candidates.is_empty():
			var picked: Dictionary = candidates[randi() % candidates.size()]
			# Same falling-moonlight visual the player-side copy's own
			# beams land with (see _tick_eclipse()'s own comment/
			# _play_lucent_beam_impact()) - each Dictionary branch just
			# needs whichever TextureRect that beam actually struck.
			match picked["kind"]:
				"player":
					apply_damage(_enemy_eclipse_damage_per_beam)
					_play_lucent_beam_impact(hero_image)
				"illusion":
					var illusion_damage: float = _apply_armor_reduction(_enemy_eclipse_damage_per_beam, _hero_armor())
					_deal_damage_to_illusion(picked["ref"], illusion_damage)
					_play_lucent_beam_impact(picked["ref"].get("node"))
				"bear":
					_deal_damage_to_bear(_enemy_eclipse_damage_per_beam)
					_play_lucent_beam_impact(_bear.get("node"))

		if _battle_over:
			return

	if _enemy_eclipse_beams_remaining <= 0:
		_end_enemy_eclipse()


func _end_enemy_eclipse() -> void:
	_enemy_eclipse_active = false
	_enemy_eclipse_damage_per_beam = 0.0
	_enemy_eclipse_radius = 0
	_enemy_eclipse_beams_remaining = 0
	_enemy_eclipse_duration_pending_start = false


# ------------------------------------------------------------------
# Snapfire's ultimate, Mortimer Kisses, cast by the rival - mirrors the
# player's own _resolve_mortimer_kisses_cast()/_fire_mortimer_kisses_
# shot()/_end_mortimer_kisses(). There's only one possible target in a
# hero fight (the player), tracked live via _hero_pos_index rather than
# a "marked enemy" reference the way the player's own copy needs for a
# creep that could die and leave a corpse behind - the player never
# does, so there's no "last known column" fallback to implement here.
# ------------------------------------------------------------------

## Marks the player, fires the FIRST of this level's own `hits` shots
## immediately, and arms _enemy_mortimer_kisses_turns_left with however
## many are left (hits - 1) - _enemy_hero_turn()'s own top-of-function
## lockout auto-fires the rest, one per rival turn, with every other
## action locked out for as long as any remain.
func _cast_enemy_mortimer_kisses(level_data: Dictionary) -> void:
	_enemy_mortimer_kisses_level_data = level_data
	_enemy_mortimer_kisses_active = true
	_enemy_mortimer_kisses_turns_left = int(level_data.get("hits", 1)) - 1

	_fire_enemy_mortimer_kisses_shot()
	_show_message_over_hero("Mortimer Kisses!")


## Fires one Mortimer Kisses shot at the player: this level's own
## main_damage plus a refreshed burn DoT. Splash ("every OTHER enemy
## exactly 1 column away from the impact column") has nothing else to
## reach in a hero fight - the player is the only possible target - same
## "no cleave" simplification every other rival AoE cast already uses.
func _fire_enemy_mortimer_kisses_shot() -> void:
	var level_data: Dictionary = _enemy_mortimer_kisses_level_data
	var main_damage: float = float(level_data.get("main_damage", 0))
	var burn_per_turn: float = float(level_data.get("burn_per_turn", 0))
	var burn_duration: int = int(level_data.get("burn_duration", 0))

	apply_damage(main_damage)
	if _recruited.get("current_hp", 0) > 0 and burn_per_turn > 0.0:
		_player_mortimer_burn_dot_damage = burn_per_turn
		_player_mortimer_burn_dot_turns_left = burn_duration

	# The splash itself isn't simplified away like every other rival
	# AoE's "no cleave" note above - illusions and the Spirit Bear are
	# real occupants of their own columns, and (unlike the enemy-side
	# skill functions elsewhere, which are always centered on some
	# OTHER point) the impact here is always the player's own position,
	# so either can end up sharing it outright (the bear especially -
	# it starts there) rather than merely being adjacent. Exactly on the
	# impact column takes main_damage, one column either side takes
	# splash_damage - same split _fire_mortimer_kisses_shot()'s own
	# regular-enemy checks use for the player's copy, rather than the
	# single flat radius _deal_aoe_damage_to_illusions()/_deal_aoe_
	# damage_to_bear() would give (which can't tell the two apart).
	var splash_damage: float = float(level_data.get("splash_damage", 0))
	for illusion in _illusions.duplicate():
		var illusion_dist: int = _distance(illusion["pos_index"], _hero_pos_index)
		if illusion_dist == 0:
			_deal_damage_to_illusion(illusion, _apply_armor_reduction(main_damage, _hero_armor()))
		elif illusion_dist == 1:
			_deal_damage_to_illusion(illusion, _apply_armor_reduction(splash_damage, _hero_armor()))
	if _is_bear_alive():
		var bear_dist: int = _distance(_bear["pos_index"], _hero_pos_index)
		if bear_dist == 0:
			_deal_damage_to_bear(main_damage)
		elif bear_dist == 1:
			_deal_damage_to_bear(splash_damage)

	# Same burning-lava-pool flare the player's own shots land with
	# (see _play_mortimer_kisses_impact_effect()'s own comment) -
	# purely position-based, so it works the same regardless of which
	# side is casting.
	_play_mortimer_kisses_impact_effect(_hero_pos_index)


## Ends the rival's Mortimer Kisses channel - called once its last shot
## has fired (see _enemy_hero_turn()'s own top-of-function lockout).
func _end_enemy_mortimer_kisses() -> void:
	_enemy_mortimer_kisses_active = false
	_enemy_mortimer_kisses_turns_left = 0
	_enemy_mortimer_kisses_level_data = {}


## Moves an enemy to `new_pos` (clamped on-board) and syncs its node's
## screen position to match, flipping its art to face the direction it
## just moved in (same left/right art convention as _spawn_enemy()).
func _move_enemy(enemy: Dictionary, new_pos: int) -> void:
	var old_pos: int = enemy["pos_index"]
	enemy["pos_index"] = clampi(new_pos, 0, GRID_COLUMNS - 1)
	enemy["node"].position = Vector2(_index_to_x(enemy["pos_index"]), _creature_y())

	var direction: int = enemy["pos_index"] - old_pos
	if direction != 0:
		var native_faces_right: bool = enemy["static"].get("is_hero_fight", false)
		enemy["node"].flip_h = (direction < 0) if native_faces_right else (direction > 0)

	_refresh_enemy_overhead_labels()


const ATTACK_LUNGE_DISTANCE := 18.0
const ATTACK_LUNGE_OUT_DURATION := 0.09
const ATTACK_LUNGE_BACK_DURATION := 0.14


## A quick "slight shift" in the direction the attacker is currently
## facing, and back - every enemy attack's own visual tell, the enemy-
## side equivalent of the player clicking Attack (already an obvious,
## deliberate action he just took). Enemies otherwise act automatically
## with nothing on screen to show which one just hit something, so
## this plays at every creep/rival-hero attack call site (see
## _enemy_turn()/_resolve_enemy_hero_attack()) - purely cosmetic, the
## damage itself is already fully resolved by the time this starts.
##
## Deliberately keyed off the sprite's own facing (flip_h, same
## left/right art convention _move_enemy() already maintains) rather
## than the actual target's column: a melee attacker always shares its
## target's column outright (distance 0), so a direction-to-target
## computation would always come out to zero for exactly the case that
## needs this lunge the most.
func _play_enemy_attack_lunge(enemy: Dictionary) -> void:
	var node: Control = enemy.get("node")
	if node == null:
		return

	var native_faces_right: bool = enemy["static"].get("is_hero_fight", false)
	var facing_left: bool = node.flip_h if native_faces_right else not node.flip_h
	var direction: float = -1.0 if facing_left else 1.0

	var base_x: float = node.position.x
	var tween := create_tween()
	tween.tween_property(node, "position:x", base_x + direction * ATTACK_LUNGE_DISTANCE, ATTACK_LUNGE_OUT_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "position:x", base_x, ATTACK_LUNGE_BACK_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


## Picks a flee direction once and sticks with it - only flipping to
## the opposite direction when it actually hits a wall. Recalculating
## "away from hero" fresh every turn is what caused the back-and-forth
## pacing at the edge before: the enemy would re-decide "flee left" as
## soon as it was possible again, then immediately get blocked again.
func _get_flee_position(enemy: Dictionary) -> int:
	var enemy_pos: int = enemy["pos_index"]

	if not enemy.has("flee_direction"):
		enemy["flee_direction"] = -1 if enemy_pos < _hero_pos_index else 1

	var direction: int = enemy["flee_direction"]
	var next_pos: int = enemy_pos + direction

	if next_pos < 0 or next_pos >= GRID_COLUMNS:
		# Hit the wall - commit to the other direction from now on,
		# not just for this one turn.
		direction = -direction
		enemy["flee_direction"] = direction
		next_pos = clampi(enemy_pos + direction, 0, GRID_COLUMNS - 1)

	return next_pos


## The hero gets exactly one action per turn - move, attack, skill, or
## item. Once any of them is used, all four lock until End Turn. Cold
## Embrace locks all four too, same as a stun - see _cold_embrace_active
## and _end_turn()'s own tail, which auto-skips the turn entirely while
## either is still in effect rather than leaving these open with
## nothing the player can actually do with them.
func _update_action_buttons() -> void:
	var locked: bool = _battle_over or _has_acted_this_turn or _player_stun_turns_left > 0 or _cold_embrace_active or _mortimer_kisses_active
	move_left_button.disabled = locked
	move_right_button.disabled = locked
	attack_button.disabled = locked

	# Fleeing is free at any time in a real playthrough - never gated by
	# turn-lock/stun/cooldown here, so unlike the buttons above it never
	# gets a fresh baseline elsewhere in this function. _apply_tutorial_
	# gate() below only ever ADDS a disable on top of whatever's already
	# set (see its own comment) - without resetting this to false first,
	# a step that gates flee out (e.g. stage 2's "attack_while_low")
	# would leave it stuck disabled forever, even once a later step
	# (e.g. "must_flee") allows it again.
	flee_button.disabled = false

	for skill_id in _skill_buttons.keys():
		var on_cooldown: bool = _skill_cooldowns.get(skill_id, 0) > 0
		_skill_buttons[skill_id].disabled = locked or on_cooldown

	# Item buttons are rebuilt (not just toggled) since their count/
	# icon can also change from item use - _populate_item_grid() reads
	# _has_acted_this_turn itself to decide their disabled state.
	_populate_item_grid()

	# Progress checks BEFORE the gate: _apply_tutorial_gate() only ever
	# ADDS restrictions on top of whatever locked/cooldown state the
	# lines above just set - it never lifts one. A step transition
	# triggered by one of these checks (e.g. _advance_tutorial_stage1_
	# step()) calls the gate again itself with the NEW allowed list, but
	# that can't undo a disable the FIRST (stale-list) gate call already
	# applied to a button that just became allowed - it would get stuck
	# disabled with nothing left to ever re-enable it. Settling the step
	# (and its allowed-actions list) first means the one gate call at
	# the end always sees the final list for this pass.
	_check_tutorial_stage1_progress()
	_check_tutorial_stage2_progress()
	_apply_tutorial_gate()


# ------------------------------------------------------------------
# Tutorial support (TutorialManager's stage 1 script: recruit Kunkka
# with Torrent on Zone.tscn, then this file walks through using Torrent
# on the ranged creep and closing in on the melee ones). Every function
# here is a no-op unless TutorialManager.is_active, so none of it
# affects a real playthrough.
# ------------------------------------------------------------------

# Which forced step stage 1's script is currently on - "" outside the
# tutorial. Driving state for _check_tutorial_stage1_progress() (polled
# after every action via _update_action_buttons()) and the explicit
# advance from _resolve_torrent_cast() once the ranged creep is hit.
var _tutorial_stage1_step: String = ""

# One-shot flags so the reinforcements tip and the forced Tidebringer/
# Ghostship picks each only ever interrupt the player once - a second
# reinforcement wave, or a second level-up's skill point, are the
# player's own to handle freely from then on.
var _tutorial_shown_reinforcement_tip: bool = false
var _tutorial_taught_tidebringer: bool = false
var _tutorial_taught_ghostship: bool = false


## Which skill id (if any) the current tutorial stage is forcing the
## player's next skill point onto - "" once that stage's forced pick
## has already been made (or outside the tutorial entirely), meaning
## any further banked points are the player's own free choice again.
## Shared by _maybe_show_skill_choice_popup()/_refresh_skill_choice_
## popup(), so stage 1 (Tidebringer) and stage 3 (Ghostship) both force
## their pick through the same one code path.
func _tutorial_forced_skill_id() -> String:
	if not TutorialManager.is_active:
		return ""
	if TutorialManager.current_stage == 1 and not _tutorial_taught_tidebringer:
		return "tidebringer"
	if TutorialManager.current_stage == 3 and not _tutorial_taught_ghostship:
		return "ghostship"
	return ""


## Fully recomputes every action button's disabled state from scratch
## whenever the tutorial is active - deliberately NOT layered on top of
## whatever _update_action_buttons() happened to set earlier, since
## this can be (and often is) called well outside that function's own
## call chain: _advance_tutorial_stageN_step() calls this directly from
## spots like a failed skill cast (not enough mana) or a torrent/
## ghostship cast resolving, neither of which goes through
## _update_action_buttons() at all. An earlier version only ever ADDED
## disables on top of the current button state, which happened to work
## while every call site ran with a stable allowed-list, but broke the
## moment a button was disabled under an OLD allowed-list and needed to
## become enabled again under a NEW one from a call outside that flow -
## it had no way to undo a disable it hadn't just set (this hit Torrent,
## then Flee, then the Mana Potion, before landing on this fix). See
## TutorialManager.is_action_allowed() for the action id scheme
## ("move_left", "move_right", "attack", "flee", "skill:<id>",
## "item:<item_id>").
func _apply_tutorial_gate() -> void:
	if not TutorialManager.is_active:
		return

	# Same "one action per turn" lock _update_action_buttons() computes -
	# duplicated here since this needs to be authoritative on its own,
	# not dependent on that function having just run. Flee is
	# deliberately excluded, same as _update_action_buttons() - it's
	# never turn-locked in a real playthrough either.
	var locked: bool = _battle_over or _has_acted_this_turn or _player_stun_turns_left > 0 or _cold_embrace_active or _mortimer_kisses_active

	move_left_button.disabled = locked or not TutorialManager.is_action_allowed("move_left")
	move_right_button.disabled = locked or not TutorialManager.is_action_allowed("move_right")
	attack_button.disabled = locked or not TutorialManager.is_action_allowed("attack")
	flee_button.disabled = not TutorialManager.is_action_allowed("flee")

	for skill_id in _skill_buttons.keys():
		var on_cooldown: bool = _skill_cooldowns.get(skill_id, 0) > 0
		_skill_buttons[skill_id].disabled = locked or on_cooldown or not TutorialManager.is_action_allowed("skill:" + skill_id)

	for btn in items_grid.get_children():
		var item_id: String = btn.get_meta("tutorial_item_id", "")
		if item_id != "":
			btn.disabled = locked or not TutorialManager.is_action_allowed("item:" + item_id)

	_tutorial_update_glow()


# Tracks whichever single button is currently glowing (see
# _tutorial_update_glow()) so repeated _apply_tutorial_gate() calls -
# there are many, every turn - don't restart the pulse animation from
# scratch each time; only a change of target tears down the old glow
# and starts a new one.
var _tutorial_glow_button: Button = null
var _tutorial_glow_style: StyleBoxFlat = null
var _tutorial_glow_tween: Tween = null


## Which single button (if any) the tutorial's CURRENT allowed-actions
## list is forcing the player toward - the counterpart TutorialManager.
## make_glow_style() gets applied to. Returns null when nothing is
## forced (allowed list empty, e.g. mid-checkpoint) or more than one
## thing is allowed at once (battle.gd's own steps only ever force
## exactly one action at a time; Shop.gd's simultaneous health+mana
## forcing is handled separately, in Shop.gd itself).
func _tutorial_current_forced_button() -> Button:
	if not TutorialManager.is_active:
		return null

	var allowed: Array = TutorialManager.get_allowed_actions()
	if allowed.size() != 1:
		return null

	var action_id: String = allowed[0]
	if action_id == "move_left":
		return move_left_button
	if action_id == "move_right":
		return move_right_button
	if action_id == "attack":
		return attack_button
	if action_id == "flee":
		return flee_button
	if action_id.begins_with("skill:"):
		return _skill_buttons.get(action_id.substr(6), null)
	if action_id.begins_with("item:"):
		var item_id: String = action_id.substr(5)
		for btn in items_grid.get_children():
			if btn.get_meta("tutorial_item_id", "") == item_id:
				return btn
	return null


## Moves the glow (see TutorialManager.make_glow_style()) onto whatever
## _tutorial_current_forced_button() currently returns, tearing down
## the previous one first - a no-op if the target hasn't changed since
## last time, so the breathing animation isn't constantly restarted.
func _tutorial_update_glow() -> void:
	var target: Button = _tutorial_current_forced_button()
	if target == _tutorial_glow_button:
		return

	if _tutorial_glow_button != null and is_instance_valid(_tutorial_glow_button):
		_tutorial_glow_button.remove_theme_stylebox_override("normal")
		_tutorial_glow_button.remove_theme_stylebox_override("hover")
	if _tutorial_glow_tween:
		_tutorial_glow_tween.kill()

	_tutorial_glow_button = target
	_tutorial_glow_style = null
	_tutorial_glow_tween = null

	if target == null:
		return

	_tutorial_glow_style = TutorialManager.make_glow_style()
	target.add_theme_stylebox_override("normal", _tutorial_glow_style)
	target.add_theme_stylebox_override("hover", _tutorial_glow_style)
	_tutorial_glow_tween = TutorialManager.start_glow_pulse(_tutorial_glow_style, self)


## Advances stage 1's script to `step_id`: sets which action(s)
## TutorialManager will now allow, shows the popup explaining that
## step, and re-applies the gate immediately so the newly-(dis)allowed
## buttons don't wait for the next _update_action_buttons() pass.
func _advance_tutorial_stage1_step(step_id: String) -> void:
	_tutorial_stage1_step = step_id

	match step_id:
		"move_to_torrent_range":
			TutorialManager.set_allowed_actions(["move_right"])
			TutorialManager.show_popup(
				"The enemies are still out of range. Move toward them - Torrent reaches 3 columns, "
				+ "so you'll be able to use it well before you're close enough to be attacked back."
			)
		"cast_torrent_on_range":
			TutorialManager.set_allowed_actions(["skill:torrent"])
			TutorialManager.show_popup(
				"Torrent is in range now. Cast it on the ranged creep in the back - left alone, it'll "
				+ "keep its distance and shoot you from afar, or turn and flee if you close in on it "
				+ "instead."
			)
		"approach_melee":
			# Which direction actually closes the distance - a melee
			# creep always spawns at its own fixed column regardless of
			# wherever the hero currently is (see _spawn_enemy()), so on
			# a reinforcement recast the hero could just as easily have
			# drifted PAST that column already, needing "move_left"
			# instead of the "move_right" the very first approach in
			# stage 1 always needs.
			var melee_enemy: Dictionary = _tutorial_find_enemy_by_type("mele")
			var move_action: String = "move_right"
			if not melee_enemy.is_empty() and melee_enemy["pos_index"] < _hero_pos_index:
				move_action = "move_left"
			TutorialManager.set_allowed_actions([move_action])
			TutorialManager.show_popup(
				"That'll keep it stunned for a moment, but it's not dead yet. Close the distance on "
				+ "the melee creeps so you can start on them too."
			)
		"melee_in_range":
			# Re-entered every time a Torrent cast finishes off a ranged
			# creep (see _resolve_torrent_cast()) - the wording stays
			# generic enough to make sense on every visit, not just the
			# first.
			TutorialManager.set_allowed_actions(["attack"])
			TutorialManager.show_popup(
				"The melee creeps are in range - keep attacking them. Use Torrent again the moment "
				+ "it's ready if another ranged creep is still up."
			)
		"recast_torrent_on_range":
			TutorialManager.set_allowed_actions(["skill:torrent"])
			TutorialManager.show_popup(
				"Torrent is ready again. Use it on the ranged creep to finish it off, so you can go "
				+ "back to focusing entirely on the melee creeps."
			)
		"stage_cleared":
			_battle_over = true
			TutorialManager.set_allowed_actions([])
			_update_action_buttons()
			TutorialManager.show_checkpoint(
				"Stage cleared! That's the core loop: move into range, use skills the moment they're "
				+ "ready, attack in between, and spend skill points on whatever gets you more damage "
				+ "or more answers.\n\nContinue with the next tutorial stage, or stop here?",
				TutorialManager.start_stage2
			)

	_apply_tutorial_gate()


## Polled from _update_action_buttons() (i.e. after every move/attack/
## skill this battle resolves) - advances stage 1's script once its
## current step's own condition is met. The "cast Torrent on the ranged
## creep" step advances explicitly instead, from _resolve_torrent_cast()
## right as that cast lands, not from here.
func _check_tutorial_stage1_progress() -> void:
	if not TutorialManager.is_active or TutorialManager.current_stage != 1:
		return

	match _tutorial_stage1_step:
		"move_to_torrent_range":
			var range_enemy: Dictionary = _tutorial_find_enemy_by_type("range")
			if not range_enemy.is_empty() and _distance(range_enemy["pos_index"], _hero_pos_index) <= 3:
				_advance_tutorial_stage1_step("cast_torrent_on_range")
		"approach_melee":
			if not _get_enemy_at(_hero_pos_index).is_empty():
				_advance_tutorial_stage1_step("melee_in_range")
		"melee_in_range":
			# Watches for Torrent coming off cooldown with a ranged
			# creep actually WITHIN its cast range - true for the
			# original one (still alive after its first, non-lethal
			# cast) and again for whichever ranged creep reinforcements
			# bring in later. Checking range, not just "alive", matters:
			# a reinforcement spawns at a fixed column regardless of
			# where the hero is currently standing, so it can easily
			# start out too far away - forcing "skill:torrent" only
			# with nothing valid to cast it on would hard-lock the
			# battle, since Attack/Move would be the only way to let a
			# turn pass at all for it to approach. Staying in this step
			# instead just keeps attacking melee - a real turn still
			# passes, so the ranged creep's own AI gets to close the
			# distance on its own.
			var range_enemy: Dictionary = _tutorial_find_enemy_by_type("range")
			if _skill_cooldowns.get("torrent", 0) <= 0 and not range_enemy.is_empty() \
			and _distance(range_enemy["pos_index"], _hero_pos_index) <= 3:
				_advance_tutorial_stage1_step("recast_torrent_on_range")


func _tutorial_find_enemy_by_type(type: String) -> Dictionary:
	for enemy in _enemies:
		if enemy["static"].get("type", "") == type:
			return enemy
	return {}


## Explains the reinforcement mechanic the first time it fires during
## the tutorial - called from _spawn_reinforcements() alongside its own
## normal "Reinforcements arrived!" banner. Doesn't touch the current
## step or its allowed actions; it's a side note, not a forced step.
func _tutorial_maybe_explain_reinforcements() -> void:
	if not TutorialManager.is_active or TutorialManager.current_stage != 1 or _tutorial_shown_reinforcement_tip:
		return
	_tutorial_shown_reinforcement_tip = true
	TutorialManager.show_popup(
		"Reinforcements! Take too long to clear a stage and more enemies join the fight - so don't "
		+ "hold skills back waiting for a 'perfect' moment. Use them as soon as they're ready."
	)


## While stage 1's script calls for a specific target (Torrent needs to
## land on the ranged creep specifically - by the time it's in range,
## the melee creeps usually are too, since they stand one column
## closer), rejects a click on anything else. The popup already says
## which one to click; this just stops a stray click from skipping past
## it. Every other step - and anything outside the tutorial - allows
## any valid target, same as a real playthrough.
func _tutorial_allows_enemy_click(enemy: Dictionary) -> bool:
	if TutorialManager.is_active and TutorialManager.current_stage == 1 \
	and (_tutorial_stage1_step == "cast_torrent_on_range" or _tutorial_stage1_step == "recast_torrent_on_range"):
		return enemy["static"].get("type", "") == "range"
	return true


# ------------------------------------------------------------------
# Tutorial support (TutorialManager's stage 2 script: a manufactured
# mid-run scenario - see TutorialManager.start_stage2() - where Kunkka
# is already at level 5, deep into this zone's hardest stage, and
# critically low on HP/mana. Teaches attacking, taking a hit, and
# fleeing before it's too late; the Map/Shop side of the flee (forcing
# the shop open and buying potions) lives in Map.gd/Shop.gd instead.
# ------------------------------------------------------------------

var _tutorial_stage2_step: String = ""


## Called from _ready() once stage 2's manufactured state (level,
## HP/mana, stage 3 enemies) has already loaded normally - drops the
## hero straight onto the melee creeps' column instead of making them
## walk there again, since this scenario starts mid-fight, not fresh.
func _start_tutorial_stage2_battle() -> void:
	_hero_pos_index = 7
	_update_hero_position()
	_advance_tutorial_stage2_step("attack_while_low")


func _advance_tutorial_stage2_step(step_id: String) -> void:
	_tutorial_stage2_step = step_id

	match step_id:
		"attack_while_low":
			TutorialManager.set_allowed_actions(["attack"])
			TutorialManager.show_popup(
				"Kunkka's already taken a beating - level 5, deep into this zone's hardest stage, and "
				+ "critically low on HP and mana with no potions in reserve. You're right on top of the "
				+ "melee creeps here - go ahead and attack, but keep an eye on that health bar."
			)
		"must_flee":
			TutorialManager.set_allowed_actions(["flee"])
			TutorialManager.show_popup(
				"That hit brings you dangerously close to death. Staying to keep fighting isn't worth "
				+ "the risk - flee back to the map and restock on potions before pushing any further."
			)

	_apply_tutorial_gate()


## Polled from _update_action_buttons(), same as stage 1's own check -
## advances past the forced Attack once a full turn (the attack itself,
## then the enemies' own retaliation) has actually played out.
func _check_tutorial_stage2_progress() -> void:
	if not TutorialManager.is_active or TutorialManager.current_stage != 2:
		return

	if _tutorial_stage2_step == "attack_while_low" and _turn_count >= 1:
		_advance_tutorial_stage2_step("must_flee")


# ------------------------------------------------------------------
# Tutorial support (TutorialManager's stage 3 script: the final
# scripted scenario - see TutorialManager.start_stage3() - same setup
# as stage 2 but with the potions bought there still in reserve.
# Teaches drinking a potion mid-fight, picking up an ultimate on
# level-up, discovering it costs more mana than you have, and using a
# second potion to actually cast it.
# ------------------------------------------------------------------

var _tutorial_stage3_step: String = ""


## Called from _ready() once stage 3's manufactured state has already
## loaded normally - same "drop straight onto the melee creeps' column"
## reasoning as _start_tutorial_stage2_battle().
func _start_tutorial_stage3_battle() -> void:
	_hero_pos_index = 7
	_update_hero_position()
	_advance_tutorial_stage3_step("heal_up")


func _advance_tutorial_stage3_step(step_id: String) -> void:
	_tutorial_stage3_step = step_id

	match step_id:
		"heal_up":
			TutorialManager.set_allowed_actions(["item:health"])
			TutorialManager.show_popup(
				"Same rough spot as before - but this time you've got a Health Potion. Drink it before "
				+ "doing anything else."
			)
		"attack_to_level_up":
			TutorialManager.set_allowed_actions(["attack"])
			TutorialManager.show_popup(
				"Better. Now attack the melee creeps - one more kill should push you to level 6."
			)
		"attack_before_reinforcements":
			TutorialManager.set_allowed_actions(["attack"])
			TutorialManager.show_popup(
				"Ghostship is yours now - your single strongest hit. Keep attacking for the moment; "
				+ "you'll want it ready for when reinforcements show up."
			)
		"cast_ultimate":
			TutorialManager.set_allowed_actions(["skill:ghostship"])
			TutorialManager.show_popup(
				"Reinforcements are here - exactly what Ghostship is for. It hits everything caught "
				+ "between you and your target, so aim it at whichever enemy is farthest away to catch "
				+ "as many as possible. Cast it now."
			)
		"need_mana_potion":
			TutorialManager.set_allowed_actions(["item:mana"])
			TutorialManager.show_popup(
				"Not enough mana to cast it yet - drink your Mana Potion first."
			)
		"cast_ultimate_ready":
			TutorialManager.set_allowed_actions(["skill:ghostship"])
			TutorialManager.show_popup(
				"Mana's topped up - go ahead and cast Ghostship."
			)
		"mop_up":
			TutorialManager.set_allowed_actions(["attack"])
			TutorialManager.show_popup(
				"That should have thinned the crowd out considerably - finish off whatever's still "
				+ "standing."
			)
		"zone_cleared":
			_battle_over = true
			TutorialManager.set_allowed_actions([])
			_update_action_buttons()
			TutorialManager.show_popup(
				"That's every stage of your home zone cleared! From here you're free to roam Terrene "
				+ "and challenge other heroes to duels to prove yourself - each of them has their own "
				+ "unique, dangerous skills, so stay sharp.\n\nGood luck out there.",
				TutorialManager.exit_tutorial
			)

	_apply_tutorial_gate()


## Explains reinforcements the first time they arrive during stage 3
## (see _tutorial_maybe_explain_reinforcements() for stage 1's own,
## separate one-shot flag) - called from _spawn_reinforcements()
## alongside its own normal banner. Unlike stage 1's version, this one
## DOES drive the script forward: reinforcements arriving is exactly
## the cue to force Ghostship.
func _tutorial_maybe_advance_stage3_for_reinforcements() -> void:
	if not TutorialManager.is_active or TutorialManager.current_stage != 3 \
	or _tutorial_stage3_step != "attack_before_reinforcements":
		return
	_advance_tutorial_stage3_step("cast_ultimate")


func _handle_defeat() -> void:
	_battle_over = true
	_update_action_buttons()
	PlayerManager.record_high_score()

	# A rival hero that just won a duel restocks the potions it spent
	# surviving it, same as EnemyHeroManager's own simulated fights do
	# right after theirs (see restock_npc_potions()) - otherwise a
	# player who keeps losing to the same rival would slowly bleed it
	# dry of potions it can never buy back.
	if _in_hero_fight:
		EnemyHeroManager.restock_npc_potions(_enemy_hero_id)

	defeat_popup.visible = true
	print("Hero defeated.")


# ------------------------------------------------------------------
# The rival hero aiming single-target skills at the player's Spirit
# Bear (see ENEMY_BEAR_TARGETABLE_SKILLS). The player is still the
# default target; the bear is picked when the player can't be hit
# (out of range, hidden), isn't worth hitting (already carries that
# skill's DoT), or when the hit would likely finish the bear off - see
# _choose_enemy_skill_on_bear(). Everything a skill does to the player
# has a bear-side counterpart below, stored on the _bear Dictionary
# itself and ticked by _tick_bear_turn_start_effects()/_bear_turn().
# ------------------------------------------------------------------

## Whether `skill_id` would be worth casting on the player (`on_bear`
## false) or on his Spirit Bear (`on_bear` true) right now - only the
## DoT skills have a "not worth restarting" rule (see
## _enemy_skill_worth_casting()'s own comments); everything else is
## always worth it.
func _enemy_skill_worth_on_target(skill_id: String, on_bear: bool) -> bool:
	var field: String = ""
	match skill_id:
		"cold_feet":
			field = "cold_feet_dot_turns_left"
			if not on_bear:
				return _player_cold_feet_dot_turns_left <= 0
		"ice_vortex":
			field = "ice_vortex_dot_turns_left"
			if not on_bear:
				return _player_ice_vortex_dot_turns_left <= 0
		"frostbite":
			field = "frostbite_dot_turns_left"
			if not on_bear:
				return _player_frostbite_dot_turns_left <= 0
		"leech_seed":
			field = "leech_seed_dot_turns_left"
			if not on_bear:
				return _player_leech_seed_dot_turns_left <= 0
		_:
			return true
	return int(_bear.get(field, 0)) <= 0


## Which of the two possible targets `skill_id` could land on right
## now: {"hero": bool, "bear": bool}. The player needs to be visible
## (see _enemy_ai_hero_hidden) and in range; the bear needs to be out
## and in range - each also has to be worth hitting
## (_enemy_skill_worth_on_target()). `ignore_range` skips both range
## checks, same as _is_enemy_skill_ready()'s own flag.
func _enemy_skill_target_options(skill_id: String, enemy_type: String, hero_distance: int, enemy: Dictionary, ignore_range: bool = false) -> Dictionary:
	var hero_ok: bool = not _enemy_ai_hero_hidden \
		and (ignore_range or _enemy_skill_in_range(skill_id, enemy_type, hero_distance, enemy)) \
		and _enemy_skill_worth_on_target(skill_id, false)
	var bear_ok: bool = false
	if _is_bear_alive():
		var bear_distance: int = _distance(enemy["pos_index"], _bear["pos_index"])
		bear_ok = (ignore_range or _enemy_skill_reaches_distance(skill_id, enemy_type, bear_distance)) \
			and _enemy_skill_worth_on_target(skill_id, true)
	return {"hero": hero_ok, "bear": bear_ok}


## Decides, for one cast of a bear-targetable `skill_id`, whether the
## rival aims it at the player's Spirit Bear. The player stays the
## default; the bear gets it when the player isn't a valid target at
## all, or when this hit would likely kill the bear outright (an
## estimate - see _estimate_enemy_skill_hit_on_bear()).
func _choose_enemy_skill_on_bear(enemy: Dictionary, skill_id: String) -> bool:
	var enemy_type: String = enemy["static"].get("type", "")
	var hero_distance: int = _distance(enemy["pos_index"], _hero_pos_index)
	var options: Dictionary = _enemy_skill_target_options(skill_id, enemy_type, hero_distance, enemy)
	if not options["bear"]:
		return false
	if not options["hero"]:
		return true
	var level_data: Dictionary = _get_enemy_skill_level_data(skill_id)
	var estimated_hit: float = _estimate_enemy_skill_hit_on_bear(enemy, skill_id, level_data)
	return estimated_hit > 0.0 and estimated_hit >= float(_bear.get("current_hp", 0.0))


## Roughly how much damage `skill_id`'s own immediate hit would do to
## the bear after its armor - only used to judge whether a cast would
## finish it off. DoT-only skills (Entangle/Cold Feet/Ice Vortex/
## Frostbite/Leech Seed/Corrosive Haze/Winter's Curse) return 0.
func _estimate_enemy_skill_hit_on_bear(enemy: Dictionary, skill_id: String, level_data: Dictionary) -> float:
	var raw: float = 0.0
	match skill_id:
		"mist_coil", "torrent", "ensnare", "lucent_beam", "ice_blast", "splinter_blast", "snowball":
			raw = float(level_data.get("damage", 0))
		"sacred_arrow":
			var distance: int = _distance(enemy["pos_index"], _bear["pos_index"])
			raw = float(level_data.get("base_damage", 0)) + float(level_data.get("bonus_per_column", 0)) * distance
		"chilling_touch":
			raw = _roll_enemy_hero_damage(enemy) + float(level_data.get("bonus_damage", 0))
		"walrus_punch":
			raw = _roll_enemy_hero_damage(enemy) * float(level_data.get("damage_multiplier", 1.0))
		"lil_shredder":
			raw = _roll_enemy_hero_damage(enemy) * float(level_data.get("damage_pct", 0)) * int(level_data.get("shots", 3))
	if raw <= 0.0:
		return 0.0
	var bear_armor: float = float(_bear.get("armor", 0)) - float(_bear.get("armor_reduction", 0.0))
	return _apply_armor_reduction(raw * (1.0 + float(_bear.get("corrosive_haze_bonus_pct", 0.0))), bear_armor)


## Floating text over the bear (e.g. "Stunned!") - the bear-side
## counterpart of _show_message_over_hero().
func _show_message_over_bear(text: String) -> void:
	if _is_bear_alive() and is_instance_valid(_bear.get("node")):
		_show_message_over_enemy(_bear["node"], text)


## Every DoT/timed debuff a rival has put on the player's Spirit Bear,
## ticked once per turn at the start of the player's own turn (from
## _tick_player_turn_start_effects(), right after the hero's own) - the
## bear-side mirror of that function's own entries for the same
## skills. Stops as soon as the bear dies. Stun/root tick in
## _bear_turn() instead, when they're actually consulted.
func _tick_bear_turn_start_effects() -> void:
	if not _is_bear_alive():
		return

	for key in ["entangle", "cold_feet", "ice_vortex", "frostbite"]:
		var turns_key: String = key + "_dot_turns_left"
		if int(_bear.get(turns_key, 0)) > 0:
			_bear[turns_key] -= 1
			var dot: float = float(_bear.get(key + "_dot_damage", 0))
			if dot > 0.0:
				_deal_damage_to_bear(dot)
				if not _is_bear_alive():
					return

	if int(_bear.get("ice_blast_dot_turns_left", 0)) > 0:
		_bear["ice_blast_dot_turns_left"] -= 1
		var ice_blast_dot: float = float(_bear.get("ice_blast_dot_damage", 0))
		if ice_blast_dot > 0.0:
			_deal_damage_to_bear(ice_blast_dot)
			if not _is_bear_alive():
				return
		# Same execute rule the player's own Ice Blast tick uses.
		var execute_pct: float = float(_bear.get("ice_blast_execute_pct", 0.0))
		if execute_pct > 0.0 and float(_bear.get("current_hp", 0.0)) <= float(_bear.get("hp", 0.0)) * execute_pct:
			_show_message_over_bear("Shattered!")
			_kill_bear()
			return
		if int(_bear.get("ice_blast_dot_turns_left", 0)) <= 0:
			_bear["ice_blast_execute_pct"] = 0.0

	if int(_bear.get("leech_seed_dot_turns_left", 0)) > 0:
		_bear["leech_seed_dot_turns_left"] -= 1
		var leech_seed_dot: float = float(_bear.get("leech_seed_dot_damage", 0))
		if leech_seed_dot > 0.0:
			_deal_damage_to_bear(leech_seed_dot)
		# The healing half goes to the caster (the rival), same as the
		# player-side tick.
		var heal_per_turn: float = float(_bear.get("leech_seed_heal_per_turn", 0.0))
		if heal_per_turn > 0.0:
			var caster: Dictionary = _get_hero_fight_boss()
			if not caster.is_empty():
				var caster_max_hp: float = _enemy_hero_effective_max_hp(caster)
				caster["current_hp"] = minf(caster_max_hp, float(caster.get("current_hp", 0.0)) + heal_per_turn)
		if not _is_bear_alive():
			return

	if int(_bear.get("armor_reduction_turns_left", 0)) > 0:
		_bear["armor_reduction_turns_left"] -= 1
		if int(_bear.get("armor_reduction_turns_left", 0)) <= 0:
			_bear["armor_reduction"] = 0.0
			_bear["corrosive_haze_bonus_pct"] = 0.0


## Stuns the bear for `turns` of its own turns (see _bear_turn()) - only
## if it survived whatever hit came with the stun.
func _stun_bear(turns: int) -> void:
	if _is_bear_alive() and turns > 0:
		_bear["stun_turns_left"] = turns
		# A fresh stun from anything else replaces Winter's Curse's
		# freeze - _cast_enemy_winters_curse_on_bear() sets this back
		# right after calling here.
		_bear["winters_curse_active"] = false
		_show_message_over_bear("Stunned!")


## The hero caught by an AoE centered on the bear (Torrent's splash,
## Ice Blast's radius, Splinter Blast's splinters) - only while the
## rival can actually see him, the same visibility rule every other
## rival cast follows.
func _is_hero_in_bear_aoe(radius: int) -> bool:
	return not _enemy_ai_hero_hidden and _is_bear_alive() and _distance(_hero_pos_index, _bear["pos_index"]) <= radius


func _cast_enemy_entangle_on_bear(level_data: Dictionary) -> void:
	_bear["root_turns_left"] = int(level_data.get("root_turns", 0))
	_bear["entangle_dot_damage"] = float(level_data.get("dot_damage", 0))
	_bear["entangle_dot_turns_left"] = int(level_data.get("dot_duration", 0))
	_show_message_over_bear("Entangled!")
	_play_entangle_effect(_bear["node"])
	_refresh_entangle_tints()


func _cast_enemy_mist_coil_on_bear(enemy: Dictionary, level_data: Dictionary) -> void:
	_play_mist_coil_effect(enemy.get("node"), _bear["node"])
	_deal_damage_to_bear(float(level_data.get("damage", 0)))


func _cast_enemy_torrent_on_bear(level_data: Dictionary) -> void:
	var damage: float = float(level_data.get("damage", 0))
	var radius: int = int(level_data.get("radius", 0))
	var bear_pos: int = _bear["pos_index"]
	_play_torrent_splash(_bear["node"])
	# The splash is centered on the bear - the hero and his illusions
	# standing close enough get caught too.
	if _is_hero_in_bear_aoe(radius):
		_play_torrent_splash(hero_image)
		apply_damage(damage)
	_play_torrent_splash_on_illusions(_illusions, bear_pos, radius)
	_deal_aoe_damage_to_illusions(bear_pos, radius, damage)
	_deal_damage_to_bear(damage)
	_stun_bear(int(level_data.get("stun_turns", 1)))


func _cast_enemy_corrosive_haze_on_bear(level_data: Dictionary) -> void:
	_bear["armor_reduction"] = float(_bear.get("armor_reduction", 0.0)) + float(level_data.get("armor_reduction", 0))
	_bear["corrosive_haze_bonus_pct"] = float(level_data.get("bonus_damage_pct", 0.0))
	_bear["armor_reduction_turns_left"] = int(level_data.get("duration", 0))
	_show_message_over_bear("Corrosive Haze!")


func _cast_enemy_sacred_arrow_on_bear(enemy: Dictionary, level_data: Dictionary) -> void:
	var distance: int = _distance(enemy["pos_index"], _bear["pos_index"])
	var damage: float = float(level_data.get("base_damage", 0)) + float(level_data.get("bonus_per_column", 0)) * distance
	# Played before the hit, which may kill (and free) the bear.
	_play_sacred_arrow_flight(enemy["node"], _bear["node"], distance)
	_show_message_over_bear("Sacred Arrow!")
	_deal_damage_to_bear(damage)
	_stun_bear(int(level_data.get("stun_turns", 0)))


func _cast_enemy_lucent_beam_on_bear(level_data: Dictionary) -> void:
	_play_lucent_beam_impact(_bear["node"])
	_show_message_over_bear("Lucent Beam!")
	_deal_damage_to_bear(float(level_data.get("damage", 0)))
	_stun_bear(int(level_data.get("stun_turns", 0)))


func _cast_enemy_ensnare_on_bear(level_data: Dictionary) -> void:
	_show_message_over_bear("Ensnare!")
	_deal_damage_to_bear(float(level_data.get("damage", 0)))
	if _is_bear_alive():
		_bear["root_turns_left"] = int(level_data.get("root_turns", 0))


func _cast_enemy_cold_feet_on_bear(level_data: Dictionary) -> void:
	_bear["cold_feet_dot_damage"] = float(level_data.get("damage", 0))
	_bear["cold_feet_dot_turns_left"] = int(level_data.get("duration", 0))
	_show_message_over_bear("Cold Feet!")
	_flash_bounce_hit(_bear["node"], COLD_FEET_FLASH_COLOR)
	_refresh_cold_feet_frost()


func _cast_enemy_ice_vortex_on_bear(level_data: Dictionary) -> void:
	var damage: float = float(level_data.get("damage", 0))
	var duration: int = int(level_data.get("duration", 0))
	# Same default as the player's own copy (_resolve_ice_vortex_cast()).
	var radius: int = int(level_data.get("radius", 1))
	var bear_pos: int = _bear["pos_index"]

	_bear["ice_vortex_dot_damage"] = damage
	_bear["ice_vortex_dot_turns_left"] = duration
	_flash_bounce_hit(_bear["node"], COLD_FEET_FLASH_COLOR)
	_show_message_over_bear("Ice Vortex!")

	# Centered on the bear - the hero and his illusions nearby are
	# caught in it as well.
	if _is_hero_in_bear_aoe(radius):
		_player_ice_vortex_dot_damage = damage
		_player_ice_vortex_dot_turns_left = duration
		_flash_bounce_hit(hero_image, COLD_FEET_FLASH_COLOR)
	_mark_illusions_ice_vortex(_illusions, bear_pos, radius, damage, duration)

	_play_ice_vortex_swirl(_bear["node"], radius)
	_refresh_cold_feet_frost()


func _cast_enemy_chilling_touch_on_bear(enemy: Dictionary, level_data: Dictionary) -> void:
	_deal_damage_to_bear(_roll_enemy_hero_damage(enemy) + float(level_data.get("bonus_damage", 0)))


func _cast_enemy_ice_blast_on_bear(level_data: Dictionary) -> void:
	var damage: float = float(level_data.get("damage", 0))
	var radius: int = int(level_data.get("radius", 0))
	var bear_pos: int = _bear["pos_index"]
	_play_ice_blast_effect(_get_hero_fight_boss().get("node"), _bear["node"])
	_show_message_over_bear("Ice Blast!")
	# The blast's radius is centered on the bear - the hero and his
	# illusions nearby take its damage too (the DoT/execute/stun stay on
	# the bear, the one it was aimed at - same as the player-aimed copy
	# only arming them on the player).
	if _is_hero_in_bear_aoe(radius):
		apply_damage(damage)
	_deal_aoe_damage_to_illusions(bear_pos, radius, damage)
	_deal_damage_to_bear(damage)
	if not _is_bear_alive():
		return
	_bear["ice_blast_dot_damage"] = float(level_data.get("dot_damage", 0))
	_bear["ice_blast_dot_turns_left"] = int(level_data.get("dot_duration", 0))
	_bear["ice_blast_execute_pct"] = float(level_data.get("execute_pct", 0.0))
	_stun_bear(int(level_data.get("stun_turns", 1)))
	_refresh_cold_feet_frost()


func _cast_enemy_splinter_blast_on_bear(level_data: Dictionary) -> void:
	var splinter_range: int = int(level_data.get("splinter_range", 0))
	var splinter_damage: float = float(level_data.get("splinter_damage", 0))
	var bear_pos: int = _bear["pos_index"]
	var shard_nodes: Array = []
	if _is_hero_in_bear_aoe(splinter_range):
		shard_nodes.append(hero_image)
	for illusion in _illusions:
		if _distance(illusion["pos_index"], bear_pos) <= splinter_range:
			shard_nodes.append(illusion.get("node"))
	_play_splinter_shards(_bear["node"], shard_nodes)
	# Splinters fly out from the bear - the hero and his illusions
	# nearby take the splinter damage.
	if _is_hero_in_bear_aoe(splinter_range):
		apply_damage(splinter_damage)
	_deal_aoe_damage_to_illusions(bear_pos, splinter_range, splinter_damage)
	_deal_damage_to_bear(float(level_data.get("damage", 0)))


func _cast_enemy_winters_curse_on_bear(level_data: Dictionary) -> void:
	_show_message_over_bear("Winter's Curse!")
	_flash_bounce_hit(_bear["node"], COLD_FEET_FLASH_COLOR)
	_stun_bear(int(level_data.get("duration", 0)))
	# Marks this stun as the curse's freeze (cleared by any other stun,
	# see _stun_bear()) - drives the bear's frost for as long as it holds.
	_bear["winters_curse_active"] = true
	_refresh_cold_feet_frost()


func _cast_enemy_frostbite_on_bear(level_data: Dictionary) -> void:
	_bear["frostbite_dot_damage"] = float(level_data.get("dot_damage", 0))
	_bear["frostbite_dot_turns_left"] = int(level_data.get("dot_duration", 0))
	_show_message_over_bear("Frostbite!")
	_flash_bounce_hit(_bear["node"], COLD_FEET_FLASH_COLOR)
	_stun_bear(int(level_data.get("stun_turns", 1)))
	_refresh_cold_feet_frost()


func _cast_enemy_snowball_on_bear(enemy: Dictionary, level_data: Dictionary) -> void:
	var bear_pos: int = _bear["pos_index"]
	_show_message_over_bear("Snowball!")
	_deal_damage_to_bear(float(level_data.get("damage", 0)))
	_stun_bear(int(level_data.get("stun_turns", 1)))

	# Same charge as the player-aimed copy, just ending on the bear's
	# column (captured before the hit, in case it died).
	var charge_direction: int = _step_toward(enemy["pos_index"], bear_pos)
	var landing_pos: int = enemy["pos_index"]
	while charge_direction != 0 and landing_pos != bear_pos:
		var next_pos: int = landing_pos + charge_direction
		if _is_column_ice_shards_blocked(next_pos):
			break
		landing_pos = next_pos
	_move_enemy(enemy, landing_pos)


func _cast_enemy_walrus_punch_on_bear(enemy: Dictionary, level_data: Dictionary) -> void:
	var punch_damage: float = _roll_enemy_hero_damage(enemy) * float(level_data.get("damage_multiplier", 1.0))

	# Same knockback rules as the player-aimed copy, applied to the
	# bear: pushed the way the rival is facing, stopped by the board's
	# edge, an enemy's column or an Ice Shards wall - hitting one of
	# those deals 50% extra.
	var knockback_columns: int = int(level_data.get("knockback", 0))
	var direction: int = -1 if enemy["node"].flip_h else 1
	var pos: int = _bear["pos_index"]
	var actual_distance: int = 0
	for i in range(knockback_columns):
		var next_pos: int = pos + direction
		if next_pos < 0 or next_pos >= GRID_COLUMNS:
			break
		if not _get_enemy_at(next_pos).is_empty():
			break
		if _is_column_enemy_ice_shards_blocked(next_pos):
			break
		pos = next_pos
		actual_distance += 1

	var hit_wall: bool = actual_distance < knockback_columns
	if hit_wall:
		punch_damage *= 1.5
		_show_message_over_bear("Wall hit!")

	_deal_damage_to_bear(punch_damage)
	if not _is_bear_alive():
		return
	_bear["pos_index"] = pos
	_bear["node"].flip_h = direction < 0
	_bear["node"].position = Vector2(_index_to_x(pos), _creature_y())
	_stun_bear(int(level_data.get("stun_turns", 1)))


func _cast_enemy_leech_seed_on_bear(level_data: Dictionary) -> void:
	_bear["leech_seed_dot_damage"] = float(level_data.get("dot_damage", 0))
	_bear["leech_seed_heal_per_turn"] = float(level_data.get("heal_per_turn", 0))
	_bear["leech_seed_dot_turns_left"] = int(level_data.get("duration", 0))
	_show_message_over_bear("Leech Seed!")


func _cast_enemy_lil_shredder_on_bear(enemy: Dictionary, level_data: Dictionary) -> void:
	var shots: int = int(level_data.get("shots", 3))
	var damage_pct: float = float(level_data.get("damage_pct", 0))
	var armor_reduction_per_shot: float = float(level_data.get("armor_reduction_per_shot", 0))
	var bear_pos: int = _bear["pos_index"]

	_show_message_over_bear("Lil' Shredder!")
	for i in range(shots):
		if not _is_bear_alive():
			break
		_play_lil_shredder_shot_effect(bear_pos, i * 0.15)
		_deal_damage_to_bear(_roll_enemy_hero_damage(enemy) * damage_pct)
		if not _is_bear_alive():
			break
		_bear["armor_reduction"] = float(_bear.get("armor_reduction", 0.0)) + armor_reduction_per_shot

	if _is_bear_alive():
		_bear["armor_reduction_turns_left"] = int(level_data.get("duration", 0))


## The rival's Mist Coil on himself - the mirror of the player's own
## _resolve_mist_coil_self_cast(): pays `level_data.hp_cost` straight
## off his current HP (no armor, no shield - it's a cost, not a hit),
## then heals `level_data.heal`, capped at his effective max HP. Only
## ever reached when _enemy_mist_coil_self_ready() already confirmed he
## can afford the cost without dying.
func _cast_enemy_mist_coil_on_self(enemy: Dictionary, level_data: Dictionary) -> void:
	var hp_before: float = float(enemy.get("current_hp", 0.0))
	var max_hp: float = _enemy_hero_effective_max_hp(enemy)
	var after_cost: float = maxf(1.0, hp_before - float(level_data.get("hp_cost", 0)))
	enemy["current_hp"] = minf(max_hp, after_cost + float(level_data.get("heal", 0)))

	_play_mist_coil_effect(enemy.get("node"), enemy.get("node"))
	if is_instance_valid(enemy.get("node")):
		var gain: int = roundi(float(enemy["current_hp"]) - hp_before)
		_show_message_over_enemy(enemy["node"], "Mist Coil +%d" % gain)
	_refresh_enemy_overhead_labels()
