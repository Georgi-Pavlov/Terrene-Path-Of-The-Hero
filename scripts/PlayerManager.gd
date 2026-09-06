extends Node
# ------------------------------------------------------------------
# PlayerManager (autoload / singleton)
# Handles the "players" file (username|password, one per line) and a
# separate per-player data file where hero/level/stats will live later.
#
# Files live under user:// which is a real writable folder on disk:
#   Windows:  %APPDATA%/Godot/app_userdata/Terrence Path of the Hero/
#   macOS:    ~/Library/Application Support/Godot/app_userdata/...
#   Linux:    ~/.local/share/godot/app_userdata/...
#   Android/iOS export: the app's private sandboxed storage.
# res:// (your project folder) is read-only once the game is exported,
# so runtime data can never be written there.
# ------------------------------------------------------------------

const PLAYERS_FILE := "user://players.txt"
const PLAYER_DATA_DIR := "user://players/"

## Switching players (login/logout/new game) flushes whatever the
## previous player had pending, then drops the cache below so the new
## player's data gets read fresh on next access. See the "Data cache"
## section further down for what actually backs get/set calls.
var current_player: String = "":
	set(value):
		if value != current_player:
			flush_player_data()
			_cache_loaded = false
			_data_cache = {}
		current_player = value

var selected_region := ""

func _ready() -> void:
	if not DirAccess.dir_exists_absolute(PLAYER_DATA_DIR):
		DirAccess.make_dir_recursive_absolute(PLAYER_DATA_DIR)
	if not FileAccess.file_exists(PLAYERS_FILE):
		var f := FileAccess.open(PLAYERS_FILE, FileAccess.WRITE)
		f.close()


## Autoloads live for the whole process, so this is the safety net for
## an abrupt quit (or the app losing focus/being backgrounded on
## mobile) leaving a dirty in-memory cache never explicitly flushed.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED \
	or what == NOTIFICATION_CRASH:
		flush_player_data()

## Returns true if a username already appears in players.txt
func player_exists(username: String) -> bool:
	var f := FileAccess.open(PLAYERS_FILE, FileAccess.READ)
	if f == null:
		return false
	while not f.eof_reached():
		var line := f.get_line()
		if line.strip_edges() == "":
			continue
		var parts := line.split("|")
		if parts.size() >= 1 and parts[0] == username:
			f.close()
			return true
	f.close()
	return false

## Adds "username|password" to players.txt and creates that player's
## own data file (for hero / level / stats you'll add later).
## Returns false if the name was already taken.
func register_player(username: String, password: String) -> bool:
	if player_exists(username):
		return false

	var f := FileAccess.open(PLAYERS_FILE, FileAccess.READ_WRITE)
	f.seek_end()
	f.store_line(username + "|" + password)
	f.close()

	var pf := FileAccess.open(PLAYER_DATA_DIR + username + ".txt", FileAccess.WRITE)
	pf.store_line("name=" + username)
	pf.store_line("hero=")
	pf.store_line("level=1")
	pf.store_line("gold=0")
	pf.store_line("stats=")
	pf.close()

	return true

## Checks username + password against players.txt
func validate_login(username: String, password: String) -> bool:
	var f := FileAccess.open(PLAYERS_FILE, FileAccess.READ)
	if f == null:
		return false
	while not f.eof_reached():
		var line := f.get_line()
		if line.strip_edges() == "":
			continue
		var parts := line.split("|")
		if parts.size() >= 2 and parts[0] == username and parts[1] == password:
			f.close()
			return true
	f.close()
	return false

## Convenience helper for later: path to the current player's data file.
func current_player_file() -> String:
	return PLAYER_DATA_DIR + current_player + ".txt"

## Reads a player's "key=value" data file into a Dictionary.
##
## Every getter and setter in this file funnels through here and
## _write_player_data() below - originally each call re-opened,
## re-parsed, or fully rewrote the data file from scratch, which was
## fine one-off but got very slow doing it dozens of times per hero
## across every NPC hero on every single Battle-scene load (see
## EnemyHeroManager.tick_all_npc_heroes). As of this optimization pass
## the *current* player's data is cached in memory after its first
## read and mutated in place; only flush_player_data() actually
## touches disk, and only if something changed since the last flush.
## A username other than current_player (shouldn't normally happen -
## every call site in this file passes current_player) bypasses the
## cache entirely and hits disk directly, so behavior for that edge
## case is unchanged.
func _read_player_data(username: String) -> Dictionary:
	if username != current_player:
		return _read_player_data_from_disk(username)

	if not _cache_loaded:
		_data_cache = _read_player_data_from_disk(username)
		_cache_loaded = true

	return _data_cache

## Updates the in-memory cache for the current player (marking it
## dirty so flush_player_data() knows to persist it) - or, for any
## other username, writes straight through to disk as before.
func _write_player_data(username: String, data: Dictionary) -> void:
	if username != current_player:
		_write_player_data_to_disk(username, data)
		return

	_data_cache = data
	_cache_loaded = true
	_cache_dirty = true


# ------------------------------------------------------------------
# Data cache: backs _read_player_data()/_write_player_data() above so
# a whole batch of field reads/writes (e.g. one tick_all_npc_heroes()
# pass over every rival hero) costs one disk read the first time it's
# touched and one disk write at the end, instead of one of each per
# field per hero. Nothing outside this file needs to know this cache
# exists - flush_player_data() is called automatically at the natural
# checkpoints below (end of an NPC tick batch, losing focus, quitting,
# switching players) so callers just keep using get_x()/set_x() as
# before.
# ------------------------------------------------------------------

var _data_cache: Dictionary = {}
var _cache_loaded: bool = false
var _cache_dirty: bool = false


## Actually persists the current player's cached data to disk, if
## anything has changed since the last flush - a no-op otherwise, so
## it's always safe to call opportunistically without worrying about
## redundant disk writes.
func flush_player_data() -> void:
	if not _cache_dirty or current_player == "":
		return
	_write_player_data_to_disk(current_player, _data_cache)
	_cache_dirty = false


## The actual disk read, unconditionally - what _read_player_data()
## used to be before caching was added.
func _read_player_data_from_disk(username: String) -> Dictionary:
	var data := {}
	var f := FileAccess.open(PLAYER_DATA_DIR + username + ".txt", FileAccess.READ)
	if f == null:
		return data
	while not f.eof_reached():
		var line := f.get_line()
		if line.strip_edges() == "":
			continue
		var idx := line.find("=")
		if idx == -1:
			continue
		var key := line.substr(0, idx)
		var value := line.substr(idx + 1)
		data[key] = value
	f.close()
	return data

## The actual disk write, unconditionally - what _write_player_data()
## used to be before caching was added.
func _write_player_data_to_disk(username: String, data: Dictionary) -> void:
	var f := FileAccess.open(PLAYER_DATA_DIR + username + ".txt", FileAccess.WRITE)
	for key in data.keys():
		f.store_line(str(key) + "=" + str(data[key]))
	f.close()

## Adds a skill id to the current player's learned skills.
## Stored as a comma-separated list under the "skills" key, e.g.
## "skills=essence_shift,dark_pact"
func learn_skill(skill_id: String) -> void:
	if current_player == "":
		print("ERROR: No current player set - can't save learned skill.")
		return

	var data := _read_player_data(current_player)
	var skills_str: String = data.get("skills", "")
	var skills: Array = [] if skills_str == "" else skills_str.split(",")

	if not skills.has(skill_id):
		skills.append(skill_id)

	data["skills"] = ",".join(skills)
	_write_player_data(current_player, data)


## Records the accepted hero: every stat, the one chosen skill, and a
## starting XP of 0 (level 1). Also sets current_hp/current_mana to
## full - these are the values the Battle scene will read from and
## drain as HP/mana get used or lost.
## Each stat is stored under its own "hero_stat_<key>" line so the
## file stays plain-text and human-readable, e.g.:
##   hero=slark
##   hero_name=Slark
##   hero_stat_strength=20
##   hero_stat_hp=560
##   hero_skill_id=essence_shift
##   hero_skill_name=Essence Shift
##   hero_xp=0
##   hero_current_hp=560
##   hero_current_mana=260
func recruit_hero(hero: Dictionary, skill: Dictionary) -> void:
	if current_player == "":
		print("ERROR: No current player set - can't save recruited hero.")
		return

	var data := _read_player_data(current_player)

	data["hero"] = hero.get("id", "")
	data["hero_name"] = hero.get("name", "")

	var stats: Dictionary = hero.get("stats", {})
	for stat_key in stats.keys():
		data["hero_stat_" + str(stat_key)] = str(stats[stat_key])

	data["hero_skill_id"] = skill.get("id", "")
	data["hero_skill_name"] = skill.get("name", "")

	# The starting skill is learned at level 1 - that's the one skill
	# point a hero level 1 already grants (see check_level_up), so
	# skill_points starts at 0 rather than 1.
	data["skill_level_" + str(skill.get("id", ""))] = "1"
	data["skill_points"] = "0"

	data["hero_xp"] = "0"
	data["hero_current_hp"] = str(stats.get("hp", 0))
	data["hero_current_mana"] = str(stats.get("mana", 0))

	# Every hero starts with one Health Potion and one Mana Potion,
	# in that order, in the first two item slots.
	data["inventory"] = "health:1,mana:1"

	_write_player_data(current_player, data)


## Reconstructs the recruited hero from the player's data file into a
## Dictionary the Battle scene can use directly:
## { id, name, skill_id, skill_name, xp, current_hp, current_mana,
##   stats: { strength: .., hp: .., mana: .., ... } }
## Returns {} if this player hasn't recruited a hero yet.
func get_recruited_hero() -> Dictionary:
	if current_player == "":
		return {}

	var data := _read_player_data(current_player)
	if data.get("hero", "") == "":
		return {}

	var stats := {}
	for key: String in data.keys():
		if key.begins_with("hero_stat_"):
			var stat_name: String = key.substr("hero_stat_".length())
			var raw_value: String = data[key]
			# Numeric stats stay numeric; things like damage ("55-61")
			# or speed ("fast") stay as strings.
			stats[stat_name] = float(raw_value) if raw_value.is_valid_float() else raw_value

	# hp/mana/armor/damage are derived from how far strength/agility/
	# intelligence have grown past the hero's base stats, rather than
	# being stored/grown directly - see GameManager.compute_derived_stats.
	# Equipment items (anything with effect "stat" still sitting in the
	# inventory - Blades of Attack, Gauntlets of Strength, Circlet,
	# etc.) add their bonus on top of the hero's own stats here, so it
	# only counts for as long as the item is actually owned.
	var hero_static: Dictionary = GameManager.get_hero_by_id(data.get("hero", ""))
	if not hero_static.is_empty():
		var strength: float = float(stats.get("strength", 0)) + get_inventory_stat_bonus("strength")
		var agility: float = float(stats.get("agility", 0)) + get_inventory_stat_bonus("agility")
		var intelligence: float = float(stats.get("intelligence", 0)) + get_inventory_stat_bonus("intelligence")

		stats["strength"] = strength
		stats["agility"] = agility
		stats["intelligence"] = intelligence

		var derived: Dictionary = GameManager.compute_derived_stats(hero_static, strength, agility, intelligence)
		stats["hp"] = derived["hp"]
		stats["mana"] = derived["mana"]
		stats["armor"] = derived["armor"] + get_inventory_stat_bonus("armor")
		stats["damage"] = _add_flat_bonus_to_range(derived["damage"], get_inventory_stat_bonus("damage"))

	return {
		"id": data.get("hero", ""),
		"name": data.get("hero_name", ""),
		"skill_id": data.get("hero_skill_id", ""),
		"skill_name": data.get("hero_skill_name", ""),
		"xp": float(data.get("hero_xp", "0")),
		"current_hp": float(data.get("hero_current_hp", "0")),
		"current_mana": float(data.get("hero_current_mana", "0")),
		"stats": stats,
		"learned_skills": _learned_skills_from_data(data),
	}


## Pulls {skill_id: level} out of a raw player-data Dictionary's
## "skill_level_<id>" keys, skipping any at level 0.
func _learned_skills_from_data(data: Dictionary) -> Dictionary:
	var learned := {}
	for key: String in data.keys():
		if key.begins_with("skill_level_"):
			var level: int = int(data[key])
			if level > 0:
				learned[key.substr("skill_level_".length())] = level
	return learned


## Reduces current HP by amount (clamped at 0) and persists it.
## Call this whenever the hero takes damage.
## Reduces current HP by amount (clamped at 0) and persists it.
## Call this whenever the hero takes damage.
func damage_hero(amount: float) -> void:
	_adjust_current_stat("hero_current_hp", -amount, "hp")


## Reduces current mana by amount (clamped at 0) and persists it.
## Call this whenever a skill is used.
func use_mana(amount: float) -> void:
	_adjust_current_stat("hero_current_mana", -amount, "mana")


## Heals HP back up (clamped at the hero's max hp) and persists it.
func heal_hero(amount: float) -> void:
	_adjust_current_stat("hero_current_hp", amount, "hp")


## Restores mana (clamped at the hero's max mana) and persists it.
func restore_mana(amount: float) -> void:
	_adjust_current_stat("hero_current_mana", amount, "mana")


## Adds XP and persists it. No level-up curve yet - this just
## accumulates a raw total for now, ready for enemies to call into
## once combat/kills are added.
func add_xp(amount: float) -> void:
	if current_player == "":
		return
	var data := _read_player_data(current_player)
	var xp: float = float(data.get("hero_xp", "0")) + amount
	data["hero_xp"] = str(xp)
	_write_player_data(current_player, data)


## Checks the current player's XP against GameManager's level curve
## and applies any level-ups that have been earned - possibly more
## than one, if a single XP gain crosses several thresholds at once.
## `hero_xp` tracks progress within the current level: each time a
## level is gained, the level's requirement is subtracted from it
## (any leftover carries into progress toward the next level) rather
## than hero_xp being a lifetime total.
##
## For every level gained, each stat in the hero's static `level_up`
## growth dict (strength/agility/intelligence) is added to that
## stat's current value. Max HP/mana/armor/damage aren't stored
## directly - they're derived from strength/agility/intelligence (see
## GameManager.compute_derived_stats) - so current_hp/current_mana are
## bumped here by the same amount that growth just added to the
## derived max, keeping the hero's HP/mana percentage unchanged by
## leveling up.
##
## Returns an Array of {new_level, old_stats, new_stats} dictionaries,
## one per level gained, in order - each stats dict has the six stats
## the level-up popup cares about (strength, agility, intelligence,
## hp, mana, damage). Empty array if no level was gained. Damage has
## no level-up growth yet, so it's just read through unchanged for
## display.
func check_level_up(hero_static: Dictionary) -> Array:
	if current_player == "":
		return []

	var data := _read_player_data(current_player)
	var level: int = int(data.get("level", "1"))
	var xp: float = float(data.get("hero_xp", "0"))
	var level_up_growth: Dictionary = hero_static.get("level_up", {})

	var results: Array = []

	while true:
		var xp_required: int = GameManager.get_xp_required_for_level(level)
		if xp_required <= 0 or xp < float(xp_required):
			break

		var old_stats := _snapshot_display_stats(data, hero_static)

		xp -= xp_required
		level += 1

		for stat_key in level_up_growth.keys():
			var growth: float = float(level_up_growth[stat_key])
			var stat_data_key: String = "hero_stat_" + str(stat_key)
			var new_value: float = float(data.get(stat_data_key, "0")) + growth
			data[stat_data_key] = str(new_value)

			# hp/mana are derived from strength/intelligence (see
			# GameManager.compute_derived_stats) rather than grown
			# directly, so current_hp/current_mana are bumped here by
			# the same amount that growth just added to the derived
			# max - keeping the hero's HP/mana percentage unchanged by
			# leveling up.
			if stat_key == "strength":
				data["hero_current_hp"] = str(float(data.get("hero_current_hp", "0")) + growth * GameManager.HP_PER_STRENGTH)
			elif stat_key == "intelligence":
				data["hero_current_mana"] = str(float(data.get("hero_current_mana", "0")) + growth * GameManager.MANA_PER_INTELLIGENCE)

		var new_stats := _snapshot_display_stats(data, hero_static)

		results.append({
			"new_level": level,
			"old_stats": old_stats,
			"new_stats": new_stats,
		})

	if not results.is_empty():
		data["level"] = str(level)
		data["hero_xp"] = str(xp)
		# One skill point per level, but never more than 1 banked at
		# once - spend it before leveling again, or the extra is
		# capped off rather than stacking up.
		data["skill_points"] = str(mini(1, int(data.get("skill_points", "0")) + results.size()))
		_write_player_data(current_player, data)

	return results


## Reads the six stats the level-up popup displays, as of the current
## point in a player-data Dictionary (as returned by
## _read_player_data). strength/agility/intelligence are read
## directly; hp/mana/damage are derived from them via
## GameManager.compute_derived_stats, matching what get_recruited_hero()
## would report if saved at this exact moment.
func _snapshot_display_stats(data: Dictionary, hero_static: Dictionary) -> Dictionary:
	var strength: float = float(data.get("hero_stat_strength", "0"))
	var agility: float = float(data.get("hero_stat_agility", "0"))
	var intelligence: float = float(data.get("hero_stat_intelligence", "0"))
	var derived: Dictionary = GameManager.compute_derived_stats(hero_static, strength, agility, intelligence)

	return {
		"strength": strength,
		"agility": agility,
		"intelligence": intelligence,
		"hp": derived["hp"],
		"mana": derived["mana"],
		"damage": derived["damage"],
	}


## Returns the current player's level (defaults to 1 if never set).
func get_level() -> int:
	if current_player == "":
		return 1
	var data := _read_player_data(current_player)
	return int(data.get("level", "1"))


## Sets the current player's level and persists it.
func set_level(value: int) -> void:
	if current_player == "":
		return
	var data := _read_player_data(current_player)
	data["level"] = str(value)
	_write_player_data(current_player, data)


## Returns the current player's gold (defaults to 0 if never set).
func get_gold() -> int:
	if current_player == "":
		return 0
	var data := _read_player_data(current_player)
	return int(data.get("gold", "0"))


## Adds (or, with a negative amount, spends) gold and persists it.
## Clamped at 0 so gold can never go negative.
func add_gold(amount: int) -> void:
	if current_player == "":
		return
	var data := _read_player_data(current_player)
	var gold: int = int(data.get("gold", "0")) + amount
	gold = max(gold, 0)
	data["gold"] = str(gold)
	_write_player_data(current_player, data)


# ------------------------------------------------------------------
# Zone stage progress: a zone's battle runs through up to
# GameManager.MAX_ZONE_STAGE waves in one sitting (see battle.gd).
# Fleeing or losing partway through just means starting over from
# stage 1 next visit - nothing to track for that. The only thing worth
# persisting is whether the zone has EVER been fully cleared in one
# continuous run, since that permanently unlocks starting on the final
# stage every time afterward.
# ------------------------------------------------------------------

## True if `zone_id` has ever been fully cleared (every stage beaten
## in one run, without fleeing).
func is_zone_cleared(zone_id: String) -> bool:
	if current_player == "" or zone_id == "":
		return false
	var data := _read_player_data(current_player)
	return data.get("zone_cleared_" + zone_id, "0") == "1"


## Marks `zone_id` as fully cleared - call this once, when the final
## stage is beaten without having fled earlier in that same run.
func set_zone_cleared(zone_id: String) -> void:
	if current_player == "" or zone_id == "":
		return
	var data := _read_player_data(current_player)
	data["zone_cleared_" + zone_id] = "1"
	_write_player_data(current_player, data)


## Which stage a fresh battle in `zone_id` should open on: the final
## stage if it's already been fully cleared, otherwise always stage 1.
func get_zone_start_stage(zone_id: String) -> int:
	return GameManager.MAX_ZONE_STAGE if is_zone_cleared(zone_id) else 1


# ------------------------------------------------------------------
# Hero fight tracking: once a specific rival hero is defeated (see
# battle.gd's hero-fight flow after clearing a zone's final stage),
# that exact hero won't be offered again for a rematch - a different
# undefeated hero from the same zone gets picked next time, until
# every hero in that zone has been defeated.
# ------------------------------------------------------------------

func get_defeated_heroes() -> Array:
	if current_player == "":
		return []
	var data := _read_player_data(current_player)
	var raw: String = data.get("defeated_heroes", "")
	if raw == "":
		return []
	return raw.split(",")


func is_hero_defeated(hero_id: String) -> bool:
	return hero_id in get_defeated_heroes()


## Marks `hero_id` as defeated - permanent, until a new game clears it.
## Also queues the kill-notification events Map's popup will surface
## (see the "Event queue" section below): one for this hero's own
## death, plus a follow-up if it was the last hero standing in its
## zone. Both are skipped if the hero was already marked defeated, so
## this only ever fires once per hero.
func mark_hero_defeated(hero_id: String) -> void:
	if current_player == "" or hero_id == "" or is_hero_defeated(hero_id):
		return
	var defeated: Array = get_defeated_heroes()
	defeated.append(hero_id)
	var data := _read_player_data(current_player)
	data["defeated_heroes"] = ",".join(defeated)
	_write_player_data(current_player, data)

	_queue_hero_defeat_events(hero_id)


## Builds and queues the event(s) for `hero_id` just having been
## defeated. Doesn't need to know who did the killing - it fires from
## mark_hero_defeated() itself, which every death path (the player
## winning a hero fight in battle.gd, or a rival hero winning one in
## EnemyHeroManager) already funnels through - so a single hook here
## covers every kill uniformly.
func _queue_hero_defeat_events(hero_id: String) -> void:
	var hero_static: Dictionary = GameManager.get_hero_by_id(hero_id)
	var hero_name: String = hero_static.get("name", hero_id)
	queue_event(hero_name + " has been slain!")

	var zone_id: String = GameManager.get_zone_id_for_hero(hero_id)
	if zone_id == "":
		return
	var zone_heroes: Array = GameManager.get_zone(zone_id).get("heroes", [])
	if zone_heroes.is_empty():
		return
	for hero in zone_heroes:
		if not is_hero_defeated(hero.get("id", "")):
			# Someone in this zone (possibly the player's own hero,
			# which never appears in defeated_heroes while alive) is
			# still standing, so the zone-wipe message isn't due yet.
			return

	var zone_name: String = GameManager.get_zone(zone_id).get("name", zone_id)
	queue_event("All " + zone_name + " protectors are dead!")


# ------------------------------------------------------------------
# Event queue: one-time notifications (hero kill messages, zone-wipe
# announcements - see _queue_hero_defeat_events above) that accumulate
# in the background while the player is off in a Battle scene, then
# get surfaced once as a Map popup and cleared. Stored as an ordered
# "event_0".."event_<N-1>" list plus an "event_count" line, rather
# than one comma-joined line like defeated_heroes, since event text is
# free-form sentences that could themselves contain commas.
# ------------------------------------------------------------------

## Appends one event message to the end of the queue.
func queue_event(text: String) -> void:
	if current_player == "" or text == "":
		return
	var data := _read_player_data(current_player)
	var count: int = int(data.get("event_count", "0"))
	data["event_" + str(count)] = text
	data["event_count"] = str(count + 1)
	_write_player_data(current_player, data)


## Every queued event message, oldest first - empty if none are
## waiting. Does not clear anything; call clear_queued_events()
## separately once they've actually been shown.
func get_queued_events() -> Array:
	if current_player == "":
		return []
	var data := _read_player_data(current_player)
	var count: int = int(data.get("event_count", "0"))
	var events: Array = []
	for i in range(count):
		events.append(data.get("event_" + str(i), ""))
	return events


## True if there's at least one queued event waiting to be shown.
func has_queued_events() -> bool:
	return current_player != "" and int(_read_player_data(current_player).get("event_count", "0")) > 0


## Wipes every queued event - call this once the Map popup showing
## them has been dismissed.
func clear_queued_events() -> void:
	if current_player == "":
		return
	var data := _read_player_data(current_player)
	var count: int = int(data.get("event_count", "0"))
	for i in range(count):
		data.erase("event_" + str(i))
	data.erase("event_count")
	_write_player_data(current_player, data)


# ------------------------------------------------------------------
# Home-zone lock: the player can only enter their own recruited
# hero's home zone until it's genuinely done with - not just
# is_zone_cleared() (which flips true the moment the FIRST hero fight
# there is won, since re-clearing that same zone offers a different
# hero each time), but every hero in it defeated. Every other zone
# opens up once that's true.
# ------------------------------------------------------------------

## True once `zone_id` has been cleared at all (see is_zone_cleared)
## AND every hero in that zone's own roster - other than
## `exclude_hero_id`, if given - has been individually defeated (a
## zone with no other heroes only needs the first part). Excluding a
## hero matters for the player's own recruited hero: it can never
## appear in defeated_heroes (see _get_eligible_hero_fight_heroes in
## battle.gd, which never offers a fight against yourself), so without
## excluding it here, a hero's own home zone could never register as
## fully cleared.
func is_zone_fully_cleared(zone_id: String, exclude_hero_id: String = "") -> bool:
	if not is_zone_cleared(zone_id):
		return false
	for hero in GameManager.get_zone(zone_id).get("heroes", []):
		var hero_id: String = hero.get("id", "")
		if hero_id == exclude_hero_id:
			continue
		if not is_hero_defeated(hero_id):
			return false
	return true


## The player's own recruited hero's home zone id - "" if it can't be
## determined (e.g. no hero recruited yet).
func get_home_zone_id() -> String:
	return GameManager.get_zone_id_for_hero(get_recruited_hero().get("id", ""))


## True once the home zone is fully cleared - the condition that
## unlocks every other zone on the Map. Defaults to true if the home
## zone can't be determined, so a data problem never locks the player
## out of the whole game.
func is_home_zone_cleared() -> bool:
	var home_zone_id: String = get_home_zone_id()
	if home_zone_id == "":
		return true
	return is_zone_fully_cleared(home_zone_id, get_recruited_hero().get("id", ""))


# ------------------------------------------------------------------
# NPC hero state: every rival hero the EnemyHeroManager autoload
# simulates progress for gets its own slice of this same save file,
# namespaced "npc_<hero_id>_<field>" so many rival heroes' state can
# coexist without colliding with each other or with the player's own
# "hero_*"/"skill_*" keys above. This is pure storage - the actual
# simulated fighting/leveling/shopping decisions live in
# EnemyHeroManager, which calls through these accessors.
# ------------------------------------------------------------------

func _npc_key(hero_id: String, field: String) -> String:
	return "npc_" + hero_id + "_" + field


## Generic read for any NPC field, e.g. get_npc_field("timbersaw", "gold").
## Prefer the typed wrappers below where one exists - this is the
## fallback for anything that doesn't have one yet.
func get_npc_field(hero_id: String, field: String, default_value: String = "0") -> String:
	if current_player == "" or hero_id == "":
		return default_value
	var data := _read_player_data(current_player)
	return data.get(_npc_key(hero_id, field), default_value)


func set_npc_field(hero_id: String, field: String, value: String) -> void:
	if current_player == "" or hero_id == "":
		return
	var data := _read_player_data(current_player)
	data[_npc_key(hero_id, field)] = value
	_write_player_data(current_player, data)


## True once `hero_id` has been simulated at least once (i.e.
## initialize_npc_hero() has run for it). Used to decide whether a
## freshly-encountered rival hero needs its starting state set up.
func npc_is_initialized(hero_id: String) -> bool:
	if current_player == "" or hero_id == "":
		return false
	var data := _read_player_data(current_player)
	return data.has(_npc_key(hero_id, "level"))


func get_npc_level(hero_id: String) -> int:
	return int(get_npc_field(hero_id, "level", "1"))


func set_npc_level(hero_id: String, level: int) -> void:
	set_npc_field(hero_id, "level", str(level))


## Progress toward this NPC's next level - same semantics as the
## player's own hero_xp: resets (carrying any overflow) each level
## gained, rather than being a running lifetime total.
func get_npc_xp(hero_id: String) -> float:
	return float(get_npc_field(hero_id, "xp", "0"))


func set_npc_xp(hero_id: String, xp: float) -> void:
	set_npc_field(hero_id, "xp", str(xp))


func get_npc_gold(hero_id: String) -> int:
	return int(get_npc_field(hero_id, "gold", "0"))


func add_npc_gold(hero_id: String, amount: int) -> void:
	set_npc_field(hero_id, "gold", str(maxi(0, get_npc_gold(hero_id) + amount)))


## Strength/agility/intelligence only - hp/mana/armor/damage stay
## derived from these via GameManager.compute_derived_stats, same as
## the player's own hero.
func get_npc_stat(hero_id: String, stat_key: String) -> float:
	return float(get_npc_field(hero_id, "stat_" + stat_key, "0"))


func set_npc_stat(hero_id: String, stat_key: String, value: float) -> void:
	set_npc_field(hero_id, "stat_" + stat_key, str(value))


func get_npc_skill_level(hero_id: String, skill_id: String) -> int:
	return int(get_npc_field(hero_id, "skill_level_" + skill_id, "0"))


func set_npc_skill_level(hero_id: String, skill_id: String, level: int) -> void:
	set_npc_field(hero_id, "skill_level_" + skill_id, str(level))


func get_npc_skill_points(hero_id: String) -> int:
	return int(get_npc_field(hero_id, "skill_points", "0"))


func set_npc_skill_points(hero_id: String, points: int) -> void:
	set_npc_field(hero_id, "skill_points", str(maxi(0, points)))


## potion_id is "health" or "mana" - the only items a simulated hero
## ever holds. Kept at a target of 3 each by EnemyHeroManager's
## shopping step, not enforced here.
func get_npc_potion_count(hero_id: String, potion_id: String) -> int:
	return int(get_npc_field(hero_id, "potion_" + potion_id, "0"))


func set_npc_potion_count(hero_id: String, potion_id: String, count: int) -> void:
	set_npc_field(hero_id, "potion_" + potion_id, str(maxi(0, count)))


## Which zone this NPC is currently grinding - their own home zone
## until they're freed (see is_npc_freed), an invasion target's zone
## afterward.
func get_npc_current_zone(hero_id: String) -> String:
	return get_npc_field(hero_id, "current_zone", "")


func set_npc_current_zone(hero_id: String, zone_id: String) -> void:
	set_npc_field(hero_id, "current_zone", zone_id)


## Which of that zone's stages (1-3) this NPC is on. Advances by 1 on
## a full clear, resets to 1 on anything less (loss, stalemate, or an
## incomplete clear) - mirrors the player's own reset-on-failure rule.
func get_npc_current_stage(hero_id: String) -> int:
	return int(get_npc_field(hero_id, "current_stage", "1"))


func set_npc_current_stage(hero_id: String, stage: int) -> void:
	set_npc_field(hero_id, "current_stage", str(stage))


## True once this NPC has fully cleared their own home zone (final
## stage, plus any zone-mate hero fight) and is free to invade another
## hero's zone instead.
func is_npc_freed(hero_id: String) -> bool:
	return get_npc_field(hero_id, "freed", "0") == "1"


func set_npc_freed(hero_id: String) -> void:
	set_npc_field(hero_id, "freed", "1")


## Which hero id this freed NPC has committed to invading - "" if none
## chosen yet (or not freed). Cleared and re-rolled if the target dies
## to someone else first.
func get_npc_invasion_target(hero_id: String) -> String:
	return get_npc_field(hero_id, "invasion_target", "")


func set_npc_invasion_target(hero_id: String, target_hero_id: String) -> void:
	set_npc_field(hero_id, "invasion_target", target_hero_id)


## Sets up a rival hero's simulated progress the first time they're
## ever ticked (see EnemyHeroManager) - level 1, one random starting
## STANDARD skill at level 1 (an ultimate would be far above what a
## level-1 hero could actually unlock), 1 Health + 1 Mana potion, and
## grinding starts in their own home zone at stage 1. Mirrors what a
## player gets from recruit_hero(), just auto-chosen instead of
## picked. Does nothing if this hero already has simulated state.
func initialize_npc_hero(hero_static: Dictionary, home_zone_id: String) -> void:
	var hero_id: String = hero_static.get("id", "")
	if current_player == "" or hero_id == "" or npc_is_initialized(hero_id):
		return

	var base_stats: Dictionary = hero_static.get("stats", {})
	set_npc_level(hero_id, 1)
	set_npc_xp(hero_id, 0.0)
	set_npc_field(hero_id, "gold", "0")
	set_npc_skill_points(hero_id, 0)
	set_npc_stat(hero_id, "strength", float(base_stats.get("strength", 0)))
	set_npc_stat(hero_id, "agility", float(base_stats.get("agility", 0)))
	set_npc_stat(hero_id, "intelligence", float(base_stats.get("intelligence", 0)))
	set_npc_potion_count(hero_id, "health", 1)
	set_npc_potion_count(hero_id, "mana", 1)
	set_npc_current_zone(hero_id, home_zone_id)
	set_npc_current_stage(hero_id, 1)

	var standard_skills: Array = []
	for skill in hero_static.get("skills", []):
		if skill.get("type", "standard") == "standard":
			standard_skills.append(skill)
	if not standard_skills.is_empty():
		var starting_skill: Dictionary = standard_skills[randi() % standard_skills.size()]
		set_npc_skill_level(hero_id, starting_skill.get("id", ""), 1)


## Shared helper: adjusts a "hero_current_*" field by delta, clamped
## between 0 and the hero's derived max for `stat_type` ("hp" or
## "mana" - see GameManager.compute_derived_stats), then saves.
func _adjust_current_stat(current_key: String, delta: float, stat_type: String) -> void:
	if current_player == "":
		return
	var data := _read_player_data(current_player)

	var max_value: float = float(data.get("hero_stat_" + stat_type, "0"))
	var hero_id: String = data.get("hero", "")
	if hero_id != "":
		var hero_static: Dictionary = GameManager.get_hero_by_id(hero_id)
		if not hero_static.is_empty():
			var strength: float = float(data.get("hero_stat_strength", "0")) + get_inventory_stat_bonus("strength")
			var agility: float = float(data.get("hero_stat_agility", "0")) + get_inventory_stat_bonus("agility")
			var intelligence: float = float(data.get("hero_stat_intelligence", "0")) + get_inventory_stat_bonus("intelligence")
			var derived: Dictionary = GameManager.compute_derived_stats(hero_static, strength, agility, intelligence)
			max_value = float(derived.get(stat_type, max_value))

	var current_value: float = float(data.get(current_key, "0")) + delta
	current_value = clamp(current_value, 0.0, max_value)
	data[current_key] = str(current_value)
	_write_player_data(current_player, data)


# ------------------------------------------------------------------
# Inventory
# Stored as one "inventory" line: "id:count,id:count,...", preserving
# the order items were first picked up (Godot Dictionaries keep
# insertion order), so slot 1/2 stay Health/Mana as promised.
# ------------------------------------------------------------------

## Reads the current player's inventory as an ordered {item_id: count}.
# ------------------------------------------------------------------
# Inventory: a fixed number of slots (matches the 3x2 grid shown in
# the Battle scene's item panel). Stackable items (health/mana - see
# GameManager's "stackable" item field) share a single slot no matter
# how many are held; every other item takes its own individual slot
# per unit, even if it's identical to one already held (2 Blades of
# Attack = 2 separate slots).
# ------------------------------------------------------------------

const MAX_INVENTORY_SLOTS: int = 6


## Returns every occupied slot as {"item_id": String, "count": int},
## in slot order. A stackable item's count can be >1 within its one
## slot; a non-stackable item's count is always 1, though several
## slots can hold the same item_id.
func get_inventory_slots() -> Array:
	if current_player == "":
		return []

	var data := _read_player_data(current_player)
	var inventory_str: String = data.get("inventory", "")
	var slots: Array = []
	if inventory_str == "":
		return slots

	for entry in inventory_str.split(","):
		if entry == "":
			continue
		var parts := entry.split(":")
		var item_id: String = parts[0]
		var stackable: bool = GameManager.get_item(item_id).get("stackable", false)

		if parts.size() == 2:
			var count: int = int(parts[1])
			if stackable:
				slots.append({"item_id": item_id, "count": count})
			else:
				# A non-stackable item saved with a count (e.g. from
				# before slots existed) - unpack it into that many
				# individual slots instead of one merged one.
				for i in range(count):
					slots.append({"item_id": item_id, "count": 1})
		else:
			slots.append({"item_id": item_id, "count": 1})

	return slots


func _save_inventory_slots(slots: Array) -> void:
	if current_player == "":
		return
	var entries: Array = []
	for slot in slots:
		var item_id: String = slot["item_id"]
		var count: int = slot["count"]
		entries.append(item_id + ":" + str(count) if count > 1 else item_id)
	var data := _read_player_data(current_player)
	data["inventory"] = ",".join(entries)
	_write_player_data(current_player, data)


func get_max_inventory_slots() -> int:
	return MAX_INVENTORY_SLOTS


func has_free_inventory_slot() -> bool:
	return get_inventory_slots().size() < MAX_INVENTORY_SLOTS


## True if there's room to add one more of `item_id` right now.
## Stackable items just need an existing slot to merge into (or a
## free slot if this would be the first one) - non-stackable items
## always need a free slot, since each unit is its own.
func can_add_item(item_id: String) -> bool:
	if current_player == "" or item_id == "":
		return false

	if GameManager.get_item(item_id).get("stackable", false):
		for slot in get_inventory_slots():
			if slot["item_id"] == item_id:
				return true

	return has_free_inventory_slot()


## {item_id: total count across all its slots} - a display/summary
## convenience (e.g. the Shop's sell list groups by item name) rather
## than the slot-accurate representation used for the 6-slot cap.
func get_inventory() -> Dictionary:
	var grouped := {}
	for slot in get_inventory_slots():
		grouped[slot["item_id"]] = grouped.get(slot["item_id"], 0) + slot["count"]
	return grouped


## Adds `count` of item_id, respecting the slot cap - see
## can_add_item(). Stackable items merge into their existing slot (or
## take one new slot if they don't have one yet); non-stackable items
## take one new slot per unit, stopping early if slots run out mid-add.
## Returns false if it couldn't fit anything at all.
func add_item(item_id: String, count: int = 1) -> bool:
	if current_player == "" or count <= 0 or not can_add_item(item_id):
		return false

	var slots: Array = get_inventory_slots()
	var stackable: bool = GameManager.get_item(item_id).get("stackable", false)

	if stackable:
		var found: bool = false
		for slot in slots:
			if slot["item_id"] == item_id:
				slot["count"] += count
				found = true
				break
		if not found:
			slots.append({"item_id": item_id, "count": count})
	else:
		for i in range(count):
			if slots.size() >= MAX_INVENTORY_SLOTS:
				break
			slots.append({"item_id": item_id, "count": 1})

	_save_inventory_slots(slots)
	return true


## Consumes one unit of item_id if available - decrementing its slot
## (removing the slot entirely once it hits 0; a non-stackable item's
## slot is always removed immediately, since its count is always 1).
## Returns false if none were held.
func use_item(item_id: String) -> bool:
	if current_player == "":
		return false

	var slots: Array = get_inventory_slots()
	for i in range(slots.size()):
		if slots[i]["item_id"] == item_id:
			slots[i]["count"] -= 1
			if slots[i]["count"] <= 0:
				slots.remove_at(i)
			_save_inventory_slots(slots)
			return true

	return false


# ------------------------------------------------------------------
# Equipment bonuses: health/mana potions are the only consumables -
# everything else with effect "stat" (Blades of Attack, Gauntlets of
# Strength, Circlet, etc.) is passive gear that contributes its bonus
# for as long as it sits in the inventory, and stops the moment it's
# sold or otherwise removed. So there's nothing to store here - the
# bonus is just summed fresh from the current inventory every time.
# ------------------------------------------------------------------

## Total bonus to `stat_key` from every "stat" item currently in the
## inventory, each counted once per copy owned (2 Blades of Attack
## gives double the bonus of 1). Items whose "stat" is a list (like
## Circlet's all-attributes bonus) count toward every stat in that list.
func get_inventory_stat_bonus(stat_key: String) -> float:
	if current_player == "" or stat_key == "":
		return 0.0

	var total: float = 0.0
	var inventory := get_inventory()
	for item_id in inventory.keys():
		var item_data: Dictionary = GameManager.get_item(item_id)
		if item_data.get("effect", "") != "stat":
			continue

		var stat_field = item_data.get("stat", "")
		var grants_this_stat: bool = stat_field.has(stat_key) if stat_field is Array else stat_field == stat_key
		if not grants_this_stat:
			continue

		total += float(item_data.get("value", 0)) * inventory[item_id]

	return total


## Adds a flat bonus to both ends of a "min-max" damage string (e.g.
## "55-61" + 9 -> "64-70"). Returns `range_str` unchanged if there's
## nothing to add.
func _add_flat_bonus_to_range(range_str: String, bonus: float) -> String:
	if bonus == 0:
		return range_str
	var parts: PackedStringArray = range_str.split("-")
	var min_value: float = float(parts[0]) if parts.size() > 0 else 0.0
	var max_value: float = float(parts[1]) if parts.size() > 1 else min_value
	return "%d-%d" % [roundi(min_value + bonus), roundi(max_value + bonus)]


# ------------------------------------------------------------------
# Skill levels & points: skills start unlearned (level 0), except the
# one chosen at recruit_hero() which starts at level 1. A skill point
# is earned per hero level gained (see check_level_up) and spent
# through spend_skill_point() to learn a new skill or push a learned
# one up a level, gated by GameManager's per-skill-type unlock
# schedule.
# ------------------------------------------------------------------

## The level the player currently has in `skill_id` (0 = not learned).
func get_skill_level(skill_id: String) -> int:
	if current_player == "" or skill_id == "":
		return 0
	var data := _read_player_data(current_player)
	return int(data.get("skill_level_" + skill_id, "0"))


## How many unspent skill points the player currently has banked.
func get_skill_points() -> int:
	if current_player == "":
		return 0
	var data := _read_player_data(current_player)
	return int(data.get("skill_points", "0"))


## Looks up `skill_id`'s definition (type, max level, etc.) within a
## hero's static "skills" array. Returns {} if not found.
func _find_skill_static(hero_static: Dictionary, skill_id: String) -> Dictionary:
	for skill in hero_static.get("skills", []):
		if skill.get("id", "") == skill_id:
			return skill
	return {}


## True if putting a point into `skill_id` right now (learning it if
## unlearned, or advancing it a level if already learned) is currently
## legal: there's a banked point, the skill isn't already at its
## type's max level, and the hero's current level meets that skill's
## next-level requirement.
func can_spend_skill_point_on(skill_id: String, hero_static: Dictionary) -> bool:
	if get_skill_points() <= 0:
		return false

	var skill_data: Dictionary = _find_skill_static(hero_static, skill_id)
	if skill_data.is_empty():
		return false

	var skill_type: String = skill_data.get("type", "standard")
	var next_level: int = get_skill_level(skill_id) + 1
	if next_level > GameManager.get_max_skill_level(skill_type):
		return false

	var required_hero_level: int = GameManager.get_skill_level_unlock_requirement(skill_type, next_level)
	return required_hero_level >= 0 and get_level() >= required_hero_level


## True if there's at least one skill on this hero the player could
## currently learn or upgrade with a banked point - used to decide
## whether to prompt for a skill choice at all after a level-up.
func has_spendable_skill_action(hero_static: Dictionary) -> bool:
	if get_skill_points() <= 0:
		return false
	for skill in hero_static.get("skills", []):
		if can_spend_skill_point_on(skill.get("id", ""), hero_static):
			return true
	return false


## Spends one banked skill point on `skill_id` - learning it (0 -> 1)
## if unlearned, or advancing it a level if already learned. Returns
## false (spending nothing) if can_spend_skill_point_on() would say no.
func spend_skill_point(skill_id: String, hero_static: Dictionary) -> bool:
	if current_player == "" or not can_spend_skill_point_on(skill_id, hero_static):
		return false

	var data := _read_player_data(current_player)
	var next_level: int = int(data.get("skill_level_" + skill_id, "0")) + 1
	data["skill_level_" + skill_id] = str(next_level)
	data["skill_points"] = str(int(data.get("skill_points", "0")) - 1)
	_write_player_data(current_player, data)
	return true


# ------------------------------------------------------------------
# Skill cooldowns: stored per-skill so they carry over across battles
# (clearing a zone and starting a new one doesn't reset them) - only
# a brand new game (clear_recruited_hero) wipes them.
# ------------------------------------------------------------------

## Turns remaining before `skill_id` can be used again (0 = ready).
func get_skill_cooldown(skill_id: String) -> int:
	if current_player == "" or skill_id == "":
		return 0
	var data := _read_player_data(current_player)
	return int(data.get("skill_cooldown_" + skill_id, "0"))


## Sets (and persists) how many turns are left on `skill_id`'s
## cooldown, clamped at 0.
func set_skill_cooldown(skill_id: String, turns_remaining: int) -> void:
	if current_player == "" or skill_id == "":
		return
	var data := _read_player_data(current_player)
	data["skill_cooldown_" + skill_id] = str(maxi(0, turns_remaining))
	_write_player_data(current_player, data)


## Wipes everything recruit_hero() set, unlocking hero choice again.
## Call this from PostLogin's "New Game" button before going to the
## map, so a fresh playthrough can pick a different hero.
func clear_recruited_hero() -> void:
	if current_player == "":
		return

	var data := _read_player_data(current_player)
	var keys_to_clear: Array = []

	for key in data.keys():
		if key == "hero" or key == "hero_name" or key == "hero_xp" \
		or key == "hero_current_hp" or key == "hero_current_mana" \
		or key == "inventory" or key == "skill_points" or key == "defeated_heroes" \
		or key.begins_with("hero_stat_") or key.begins_with("hero_skill_") \
		or key.begins_with("skill_cooldown_") or key.begins_with("skill_level_") \
		or key.begins_with("zone_cleared_") or key.begins_with("npc_") \
		or key.begins_with("event_"):
			keys_to_clear.append(key)

	for key in keys_to_clear:
		data.erase(key)

	# A new game also means a fresh start on progression that isn't
	# tied to the hero dictionary above: gold and level reset too.
	data["gold"] = "0"
	data["level"] = "1"

	_write_player_data(current_player, data)


# ------------------------------------------------------------------
# High score: the most XP this player's hero has ever earned in a
# single run, kept even after that hero dies or a new one is chosen.
# ------------------------------------------------------------------

## Compares the current hero's XP against the stored high score and
## keeps whichever is higher. Call this at the natural end of a run -
## hero death or clearing every enemy in a zone.
func record_high_score() -> void:
	if current_player == "":
		return
	var data := _read_player_data(current_player)
	var current_xp: float = float(data.get("hero_xp", "0"))
	var high_score: float = float(data.get("high_score", "0"))
	if current_xp > high_score:
		data["high_score"] = str(current_xp)
		_write_player_data(current_player, data)


func get_high_score() -> float:
	if current_player == "":
		return 0.0
	var data := _read_player_data(current_player)
	return float(data.get("high_score", "0"))
