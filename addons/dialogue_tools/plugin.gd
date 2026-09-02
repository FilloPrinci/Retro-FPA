@tool
extends EditorPlugin
## Dialogue Tools — everything from Project > Tools has been deliberately
## avoided in favor of one bottom-panel dock ("Dialoghi") plus native
## Inspector widgets, so setting up a talking NPC never needs the
## terminal or a headless script:
##
## - The NPC body itself needs no wizard here — it's core/npc/npc_body.gd
##   (NpcBody), a plain node you add the same way as any other (Create New
##   Node > NpcBody) that builds its own boxed mesh/collision on _ready().
## - Dock button "Nuovo dialogo NPC...": scaffolds a DialogueData .tres
##   (one starting line), an InteractableComponent + DialogueTrigger under
##   whichever node is selected in the scene, and placeholder rows in
##   translations/dialogue.csv — see dialogue_scaffolder.gd.
## - Inspector: DialogueLine/DialogueChoice's next_id and flag fields get
##   dropdown widgets instead of free-text — see dialogue_id_property.gd /
##   dialogue_flag_property.gd, wired in via dialogue_inspector_plugin.gd.
## - Dock button "Valida dialoghi": runs dialogue_validator.gd over every
##   resources/dialogues/*.tres and prints the results right in the dock.

const DOCK_SCENE := preload("res://addons/dialogue_tools/dialogue_dock.tscn")
const WIZARD_SCENE := preload("res://addons/dialogue_tools/new_dialogue_dialog.tscn")
const INSPECTOR_PLUGIN_SCRIPT := preload("res://addons/dialogue_tools/dialogue_inspector_plugin.gd")

var _dock: Control
var _wizard: ConfirmationDialog
var _result_dialog: AcceptDialog
var _inspector_plugin: EditorInspectorPlugin


func _enter_tree() -> void:
	_dock = DOCK_SCENE.instantiate()
	add_control_to_bottom_panel(_dock, "Dialoghi")
	_dock.new_dialogue_requested.connect(_on_new_dialogue_requested)

	_wizard = WIZARD_SCENE.instantiate()
	add_child(_wizard)
	_wizard.result_ready.connect(_on_wizard_result)

	_result_dialog = AcceptDialog.new()
	add_child(_result_dialog)

	_inspector_plugin = INSPECTOR_PLUGIN_SCRIPT.new()
	add_inspector_plugin(_inspector_plugin)


func _exit_tree() -> void:
	remove_inspector_plugin(_inspector_plugin)
	remove_control_from_bottom_panel(_dock)
	_dock.queue_free()
	_wizard.queue_free()
	_result_dialog.queue_free()


func _on_new_dialogue_requested() -> void:
	var selected := get_editor_interface().get_selection().get_selected_nodes()
	if selected.is_empty():
		_show_result({"ok": false, "message": "Seleziona prima il nodo dell'NPC nella scena."})
		return
	_wizard.open_for_node(selected[0])


func _on_wizard_result(result: Dictionary) -> void:
	_show_result(result)
	if result.ok:
		# The new DialogueTrigger/InteractableComponent nodes and the new
		# translation rows only exist on disk/in the open scene until the
		# filesystem dock and translation server catch up.
		get_editor_interface().get_resource_filesystem().scan()


func _show_result(result: Dictionary) -> void:
	_result_dialog.title = "Fatto" if result.ok else "Errore"
	_result_dialog.dialog_text = result.message
	_result_dialog.popup_centered()
