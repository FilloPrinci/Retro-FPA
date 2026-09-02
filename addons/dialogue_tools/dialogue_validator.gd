class_name DialogueValidator
extends RefCounted
## Scans every resources/dialogues/*.tres for broken references and missing
## translations. Pure data-scanning, no editor dependency — usable from the
## Dialogue Tools dock (see dialogue_dock.gd) and from a plain headless
## script alike.
##
## Checks per file: duplicate/empty line ids, start_id resolves, every
## next_id (line or choice) resolves to an id in the same file, every
## non-empty text_key/speaker_name_key exists in some translations/*.csv,
## and (as a warning, not an error) every line is reachable from start_id.

const DIALOGUES_DIR := "res://resources/dialogues"
const TRANSLATIONS_DIR := "res://translations"


## Returns an Array of {severity: "error"|"warning", file: String, message: String}.
## Empty array means everything checked out clean.
static func validate_all() -> Array[Dictionary]:
	var issues: Array[Dictionary] = []
	var translation_keys := _load_translation_keys()

	var dir := DirAccess.open(DIALOGUES_DIR)
	if dir == null:
		return issues

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres"):
			issues.append_array(_validate_file("%s/%s" % [DIALOGUES_DIR, file_name], translation_keys))
		file_name = dir.get_next()
	dir.list_dir_end()

	return issues


static func _validate_file(path: String, translation_keys: Dictionary) -> Array[Dictionary]:
	var issues: Array[Dictionary] = []
	var data: DialogueData = load(path)
	if data == null:
		issues.append(_issue("error", path, "Impossibile caricare il file."))
		return issues
	if data.lines.is_empty():
		issues.append(_issue("error", path, "Nessuna riga (lines) definita."))
		return issues

	var ids := {}
	for line in data.lines:
		if line.id.is_empty():
			issues.append(_issue("error", path, "Una riga ha id vuoto."))
			continue
		if ids.has(line.id):
			issues.append(_issue("error", path, "Id duplicato: '%s'." % line.id))
		ids[line.id] = true

	var start_id := data.start_id if not data.start_id.is_empty() else data.lines[0].id
	var reached := {}
	if ids.has(start_id):
		reached[start_id] = true
	else:
		issues.append(_issue("error", path, "start_id '%s' non esiste tra le righe." % start_id))

	for line in data.lines:
		_check_key(line.speaker_name_key, translation_keys, path,
			"speaker_name_key della riga '%s'" % line.id, issues, true)
		_check_key(line.text_key, translation_keys, path,
			"text_key della riga '%s'" % line.id, issues, false)

		if line.choices.is_empty():
			_check_next_id(line.next_id, ids, reached, path,
				"la riga '%s'" % line.id, issues)
		for choice in line.choices:
			_check_key(choice.text_key, translation_keys, path,
				"text_key di una scelta sulla riga '%s'" % line.id, issues, false)
			_check_next_id(choice.next_id, ids, reached, path,
				"la scelta '%s' sulla riga '%s'" % [choice.text_key, line.id], issues)

	for line in data.lines:
		if not line.id.is_empty() and not reached.has(line.id):
			issues.append(_issue("warning", path,
				"La riga '%s' non è mai raggiungibile da start_id ('%s')." % [line.id, start_id]))

	return issues


static func _check_next_id(next_id: String, ids: Dictionary, reached: Dictionary, path: String, who: String, issues: Array[Dictionary]) -> void:
	if next_id.is_empty():
		return  # empty next_id ends the dialogue — valid.
	if ids.has(next_id):
		reached[next_id] = true
	else:
		issues.append(_issue("error", path, "%s punta a next_id '%s', che non esiste." % [who, next_id]))


static func _check_key(key: String, translation_keys: Dictionary, path: String, label: String, issues: Array[Dictionary], allow_empty: bool) -> void:
	if key.is_empty():
		if not allow_empty:
			issues.append(_issue("warning", path, "%s è vuota." % label))
		return
	if not translation_keys.has(key):
		issues.append(_issue("error", path, "%s ('%s') non è presente in nessun translations/*.csv." % [label, key]))


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
