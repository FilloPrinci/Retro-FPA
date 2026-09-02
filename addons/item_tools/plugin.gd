@tool
extends EditorPlugin
## Item Tools — same philosophy as Dialogue Tools/NpcBody, applied to
## pickupable/physical objects. Nothing here needs the terminal:
##
## - The object's world presence needs no wizard — that's a WorldItem
##   node (core/world_item/world_item.gd), added the same way as any
##   other node (Create New Node > WorldItem). Toggle its `kind` between
##   a physical prop (RigidBody3D + Grabbable) and a pickup
##   (StaticBody3D + InteractableComponent + ItemPickup); it builds its
##   own boxed placeholder mesh + collision either way.
## - Dock button "Nuovo oggetto...": scaffolds an ItemData .tres (plus a
##   weapon behavior .tres with sensible defaults, for melee/ranged),
##   placeholder rows in translations/items.csv, and — if a WorldItem is
##   selected — assigns the result to it directly. See item_scaffolder.gd.
## - Dock button "Valida oggetti": runs item_validator.gd over every
##   resources/items/*.tres and prints the results right in the dock.

const DOCK_SCENE := preload("res://addons/item_tools/item_dock.tscn")
const WIZARD_SCENE := preload("res://addons/item_tools/new_item_dialog.tscn")

var _dock: Control
var _wizard: ConfirmationDialog
var _result_dialog: AcceptDialog


func _enter_tree() -> void:
	_dock = DOCK_SCENE.instantiate()
	add_control_to_bottom_panel(_dock, "Oggetti")
	_dock.new_item_requested.connect(_on_new_item_requested)

	_wizard = WIZARD_SCENE.instantiate()
	add_child(_wizard)
	_wizard.result_ready.connect(_on_wizard_result)

	_result_dialog = AcceptDialog.new()
	add_child(_result_dialog)


func _exit_tree() -> void:
	remove_control_from_bottom_panel(_dock)
	_dock.queue_free()
	_wizard.queue_free()
	_result_dialog.queue_free()


func _on_new_item_requested() -> void:
	var selected := get_editor_interface().get_selection().get_selected_nodes()
	var target: WorldItem = null
	if not selected.is_empty() and selected[0] is WorldItem:
		target = selected[0]
	_wizard.open_for_node(target)


func _on_wizard_result(result: Dictionary) -> void:
	_result_dialog.title = "Fatto" if result.ok else "Errore"
	_result_dialog.dialog_text = result.message
	_result_dialog.popup_centered()
	if result.ok:
		# The new ItemData/behavior .tres and the new translation rows
		# only exist on disk until the filesystem dock catches up.
		get_editor_interface().get_resource_filesystem().scan()
