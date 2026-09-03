class_name DialogueScaffolder
extends RefCounted
## Creates everything a new NPC dialogue needs in one step: a DialogueData
## .tres (with one starting line), an InteractableComponent +
## DialogueTrigger under the target node (reusing either if the node
## already has one), and placeholder rows in translations/dialogue.csv for
## the generated keys. Used by NewDialogueDialog (the wizard popup) — kept
## separate from it so the file/node-creation logic isn't tangled up with
## dialog-box UI code, and so it can be exercised without an editor.

const DIALOGUES_DIR := "res://resources/dialogues"
const DIALOGUE_CSV := "res://translations/dialogue.csv"

const INTERACTABLE_SCRIPT := "res://core/interaction/interactable_component.gd"
const DIALOGUE_TRIGGER_SCRIPT := "res://core/dialogue/dialogue_trigger.gd"


## Returns {"ok": bool, "message": String, "dialogue_path": String}.
static func create(npc_node: Node, slug: String, speaker_display_name: String) -> Dictionary:
	var clean_slug := slugify(slug)
	if clean_slug.is_empty():
		return _fail("Invalid dialogue name (use letters, numbers, underscore).")
	if npc_node == null:
		return _fail("No node selected in the scene.")

	var dialogue_path := "%s/%s.tres" % [DIALOGUES_DIR, clean_slug]
	if FileAccess.file_exists(dialogue_path):
		return _fail("A dialogue '%s.tres' already exists." % clean_slug)

	var slug_upper := clean_slug.to_upper()
	var speaker_key := "NPC_%s_NAME" % slug_upper
	var start_text_key := "DIALOGUE_%s_START" % slug_upper

	# --- DialogueData resource, one starting line ---
	var dialogue := DialogueData.new()
	var start_line := DialogueLine.new()
	start_line.id = "start"
	start_line.speaker_name_key = speaker_key
	start_line.text_key = start_text_key
	dialogue.lines.append(start_line)
	dialogue.start_id = "start"

	if not DirAccess.dir_exists_absolute(DIALOGUES_DIR):
		DirAccess.make_dir_recursive_absolute(DIALOGUES_DIR)
	var save_err := ResourceSaver.save(dialogue, dialogue_path)
	if save_err != OK:
		return _fail("Couldn't save '%s' (error %d)." % [dialogue_path, save_err])

	# Reload from disk so DialogueTrigger references the saved file by
	# path, not the in-memory instance — same ext_resource pattern every
	# other hand-authored scene in this project uses.
	dialogue = load(dialogue_path)

	# --- InteractableComponent (reuse if the node already has one) ---
	var interactable := _find_child_named(npc_node, "InteractableComponent")
	if interactable == null:
		interactable = Node.new()
		interactable.name = "InteractableComponent"
		interactable.set_script(load(INTERACTABLE_SCRIPT))
		interactable.set("prompt_text_key", "UI_INTERACT_TALK")
		_add_child(npc_node, interactable)

	# --- DialogueTrigger (reuse if present, just repoint it) ---
	var trigger := _find_child_named(npc_node, "DialogueTrigger")
	if trigger == null:
		trigger = Node.new()
		trigger.name = "DialogueTrigger"
		trigger.set_script(load(DIALOGUE_TRIGGER_SCRIPT))
		_add_child(npc_node, trigger)
	trigger.set("dialogue", dialogue)

	# --- Placeholder translation rows ---
	var display_name := speaker_display_name if not speaker_display_name.is_empty() else clean_slug.capitalize()
	_append_csv_row(DIALOGUE_CSV, speaker_key, display_name, display_name)
	_append_csv_row(DIALOGUE_CSV, start_text_key,
		"TODO: %s start line" % clean_slug, "TODO: battuta iniziale di %s" % clean_slug)

	return {"ok": true, "message": "Dialogue '%s' created." % clean_slug, "dialogue_path": dialogue_path}


## Lowercase, [a-z0-9_] only, single underscores as separators, no
## leading/trailing underscore.
static func slugify(text: String) -> String:
	var lowered := text.strip_edges().to_lower()
	var result := ""
	for c in lowered:
		if (c >= "a" and c <= "z") or (c >= "0" and c <= "9"):
			result += c
		elif (c == "_" or c == "-" or c == " ") and not result.ends_with("_"):
			result += "_"
	while result.ends_with("_"):
		result = result.substr(0, result.length() - 1)
	return result


static func _find_child_named(node: Node, child_name: String) -> Node:
	for child in node.get_children():
		if child.name == child_name:
			return child
	return null


static func _add_child(parent: Node, child: Node) -> void:
	parent.add_child(child)
	# The scene root has owner == null (Godot convention); every other
	# node's owner is that root. Falls back to `parent` itself when parent
	# IS the root.
	child.owner = parent.owner if parent.owner else parent


static func _append_csv_row(path: String, key: String, en: String, it: String) -> void:
	var file_exists := FileAccess.file_exists(path)

	if file_exists:
		var existing := FileAccess.open(path, FileAccess.READ)
		var header_skipped := false
		while not existing.eof_reached():
			var row := existing.get_csv_line()
			if row.size() == 0 or (row.size() == 1 and row[0].is_empty()):
				continue
			if not header_skipped:
				header_skipped = true
				continue
			if row[0] == key:
				existing.close()
				return  # already present — don't duplicate on a re-run.
		existing.close()

	var file: FileAccess
	if file_exists:
		file = FileAccess.open(path, FileAccess.READ_WRITE)
		file.seek_end()
	else:
		file = FileAccess.open(path, FileAccess.WRITE)
		file.store_csv_line(["keys", "en", "it"])
	if file == null:
		return
	file.store_csv_line([key, en, it])
	file.close()


static func _fail(message: String) -> Dictionary:
	return {"ok": false, "message": message, "dialogue_path": ""}
