class_name ItemValidator
extends RefCounted
## Scans every resources/items/*.tres for missing translations and other
## easy-to-forget mistakes. Pure data-scanning, no editor dependency —
## usable from the Item Tools dock and from a plain headless script alike.
## Mirrors Dialogue Tools' DialogueValidator.
##
## Checks: duplicate/empty ids across items, non-empty
## display_name_key/description_key exist in some translations/*.csv, and
## (as a warning) a RangedWeaponBehavior with no ammo_item assigned —
## valid to leave for later, but easy to forget about.

const ITEMS_DIR := "res://resources/items"
const TRANSLATIONS_DIR := "res://translations"


## Returns an Array of {severity: "error"|"warning", file: String, message: String}.
static func validate_all() -> Array[Dictionary]:
	var issues: Array[Dictionary] = []
	var translation_keys := _load_translation_keys()
	var ids := {}

	var dir := DirAccess.open(ITEMS_DIR)
	if dir == null:
		return issues

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres"):
			issues.append_array(_validate_file("%s/%s" % [ITEMS_DIR, file_name], translation_keys, ids))
		file_name = dir.get_next()
	dir.list_dir_end()

	return issues


static func _validate_file(path: String, translation_keys: Dictionary, ids: Dictionary) -> Array[Dictionary]:
	var issues: Array[Dictionary] = []
	var item: ItemData = load(path)
	if item == null:
		issues.append(_issue("error", path, "Couldn't load the file."))
		return issues

	if item.id.is_empty():
		issues.append(_issue("error", path, "empty id."))
	elif ids.has(item.id):
		issues.append(_issue("error", path, "duplicate id: '%s' (already used by %s)." % [item.id, ids[item.id]]))
	else:
		ids[item.id] = path.get_file()

	_check_key(item.display_name_key, translation_keys, path, "display_name_key", issues)
	_check_key(item.description_key, translation_keys, path, "description_key", issues)

	if item.equip_behavior is RangedWeaponBehavior:
		var ranged := item.equip_behavior as RangedWeaponBehavior
		if ranged.ammo_item == null:
			issues.append(_issue("warning", path, "Firearm with no ammo_item assigned on its behavior."))

	return issues


static func _check_key(key: String, translation_keys: Dictionary, path: String, label: String, issues: Array[Dictionary]) -> void:
	if key.is_empty():
		issues.append(_issue("warning", path, "%s is empty." % label))
		return
	if not translation_keys.has(key):
		issues.append(_issue("error", path, "%s ('%s') isn't present in any translations/*.csv." % [label, key]))


static func _load_translation_keys() -> Dictionary:
	var keys := {}
	var dir := DirAccess.open(TRANSLATIONS_DIR)
	if dir == null:
		return keys

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".csv"):
			_collect_csv_keys("%s/%s" % [TRANSLATIONS_DIR, file_name], keys)
		file_name = dir.get_next()
	dir.list_dir_end()

	return keys


static func _collect_csv_keys(path: String, keys: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return

	var header_skipped := false
	while not file.eof_reached():
		var row := file.get_csv_line()
		if row.size() == 0 or (row.size() == 1 and row[0].is_empty()):
			continue
		if not header_skipped:
			header_skipped = true
			continue
		keys[row[0]] = true
	file.close()


static func _issue(severity: String, path: String, message: String) -> Dictionary:
	return {"severity": severity, "file": path.get_file(), "message": message}
