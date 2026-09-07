extends Node
## Save/load system for the current run. Autoload singleton.
##
## Built entirely on top of the public APIs the other autoloads already
## expose — GameManager.set_flag/get_flag/get_all_flags,
## InventoryManager's slots, SceneManager.change_scene — never reaching
## into their internals. This is exactly the layer GameManager's own doc
## comment describes: "flags only live for the current play session... a
## specific game can add real persistence on top of get_flag/set_flag
## without changing anything that reads them."
##
## One slot = one JSON file under user://saves/. slot 0 is the implicit
## default for a game that only ever needs a single "Continue" — every
## method still takes an explicit slot number for a game that wants a
## proper multi-slot save screen later, without changing this API.
##
## What's captured: which level, the player's exact position/orientation
## (not just "which SpawnPoint" — resuming a horror game mid-room matters
## more than most genres), every GameManager flag, and the full inventory
## (every slot's item + quantity, and which one is equipped). Flag values
## must be JSON-safe (bool/int/float/String/Array/Dictionary) — the same
## constraint set_flag/get_flag never enforced because nothing previously
## needed to serialize them; a flag holding anything else silently fails
## to round-trip through save/load, same as it would through any other
## JSON-based save system. JSON has no separate int type either, so an int
## flag comes back out of load_game() as a float of the same value (e.g.
## set_flag("count", 3) round-trips as 3.0) — harmless for the usual
## == comparisons dialogue/quest flags do, but worth knowing if something
## ever relies on `is` or int-specific behavior.

signal save_completed(slot: int)
signal load_completed(slot: int)
## Emitted when save_game()/load_game() fails — reason is a short,
## untranslated code (see the calls below), meant for a developer/log,
## not shown to the player as-is.
signal save_failed(slot: int, reason: String)
signal load_failed(slot: int, reason: String)

const SAVE_DIR := "user://saves/"
const SAVE_VERSION := 1


func has_save(slot: int = 0) -> bool:
	return FileAccess.file_exists(_save_path(slot))


func delete_save(slot: int = 0) -> void:
	if has_save(slot):
		DirAccess.remove_absolute(_save_path(slot))


## Captures the current run into `slot` and writes it to disk. Fails if
## there's no active level/player to capture from (e.g. called from the
## main menu, or mid scene-transition) — nothing meaningful to save yet.
func save_game(slot: int = 0) -> bool:
	var player := GameManager.get_player()
	var level_path := SceneManager.get_current_level_path()
	if player == null or level_path.is_empty():
		save_failed.emit(slot, "no_active_level")
		return false

	var data := {
		"version": SAVE_VERSION,
		"level_path": level_path,
		"player_transform": var_to_str(player.global_transform),
		"flags": GameManager.get_all_flags(),
		"inventory": _serialize_inventory(),
	}

	var dir_error := DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	if dir_error != OK and dir_error != ERR_ALREADY_EXISTS:
		save_failed.emit(slot, "dir_error")
		return false

	var file := FileAccess.open(_save_path(slot), FileAccess.WRITE)
	if file == null:
		save_failed.emit(slot, "file_error")
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()

	save_completed.emit(slot)
	return true


## Loads `slot` and jumps the current run straight into it: clears flags
## and inventory first (same as start_new_game()), loads the saved level
## through SceneManager.change_scene() exactly like any other level
## transition (fade included) — passing the saved player transform as
## change_scene()'s own override so the player is placed there *before*
## fade_in reveals anything, rather than popping into view at the
## level's SpawnPoint first and only teleporting to the real spot once
## the screen's already visible — then restores every flag and the full
## inventory on top. Awaited — false if the slot doesn't exist or the
## level failed to load, with nothing changed either way (flags/inventory
## are only cleared once change_scene() has actually succeeded).
func load_game(slot: int = 0) -> bool:
	if not has_save(slot):
		load_failed.emit(slot, "no_save")
		return false

	var file := FileAccess.open(_save_path(slot), FileAccess.READ)
	if file == null:
		load_failed.emit(slot, "file_error")
		return false
	var text := file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		load_failed.emit(slot, "corrupt")
		return false
	var data: Dictionary = parsed

	var level_path: String = data.get("level_path", "")
	if level_path.is_empty():
		load_failed.emit(slot, "corrupt")
		return false

	GameManager.clear_flags()
	InventoryManager.clear()

	var transform_override: Variant = null
	if data.has("player_transform"):
		transform_override = str_to_var(data["player_transform"])

	if not await SceneManager.change_scene(level_path, "default", true, transform_override):
		load_failed.emit(slot, "level_load_failed")
		return false

	var flags: Dictionary = data.get("flags", {})
	for key in flags:
		GameManager.set_flag(key, flags[key])

	_deserialize_inventory(data.get("inventory", {}))

	load_completed.emit(slot)
	return true


func _save_path(slot: int) -> String:
	return SAVE_DIR + "save_%d.json" % slot


func _serialize_inventory() -> Dictionary:
	var slots_data: Array = []
	for slot in InventoryManager.get_slots():
		if slot.is_empty():
			slots_data.append(null)
		else:
			slots_data.append({
				"item_path": slot.item.resource_path,
				"quantity": slot.quantity,
			})
	return {
		"equipped_index": InventoryManager.get_equipped_index(),
		"slots": slots_data,
	}


## Re-adds every saved slot's item in order via InventoryManager.add_item()
## rather than poking _slots directly — InventoryManager.clear() (called
## by load_game() before this) guarantees every slot is empty going in, so
## each add_item() call lands in a fresh slot in the same order the data
## was captured in, reproducing the original slot indices exactly (needed
## for equipped_index below to still point at the right item).
func _deserialize_inventory(inv_data: Dictionary) -> void:
	var slots_data: Array = inv_data.get("slots", [])
	for entry in slots_data:
		if entry == null:
			continue
		var item_path: String = entry.get("item_path", "")
		if item_path.is_empty() or not ResourceLoader.exists(item_path):
			continue
		var item: ItemData = load(item_path)
		if item == null:
			continue
		InventoryManager.add_item(item, entry.get("quantity", 1))

	var equipped_index: int = inv_data.get("equipped_index", -1)
	if equipped_index >= 0:
		InventoryManager.equip_slot(equipped_index)
