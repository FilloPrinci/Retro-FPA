@tool
extends ConfirmationDialog
## "Nuovo oggetto" wizard popup — open_for_node() is called by plugin.gd
## with whatever WorldItem is selected in the scene (or null) when
## "Nuovo oggetto..." is pressed. Pressing the (renamed) OK button runs
## ItemScaffolder.create() and reports the outcome via result_ready,
## instead of the dock/plugin having to know anything about this dialog's
## internals — same pattern as Dialogue Tools' new_dialogue_dialog.gd.
##
## If a WorldItem was selected, the newly created ItemData is assigned to
## its `item` field automatically (and its kind flipped to PICKUPABLE if
## it wasn't already) — no separate drag-and-drop step needed.

signal result_ready(result: Dictionary)

@onready var target_label: Label = $VBox/TargetLabel
@onready var slug_edit: LineEdit = $VBox/SlugRow/SlugEdit
@onready var name_edit: LineEdit = $VBox/NameRow/NameEdit
@onready var description_edit: LineEdit = $VBox/DescriptionRow/DescriptionEdit
@onready var kind_option: OptionButton = $VBox/KindRow/KindOption
@onready var icon_row: HBoxContainer = $VBox/IconRow

var _target_node: WorldItem = null
var _icon_picker: EditorResourcePicker


func _ready() -> void:
	title = "Nuovo oggetto"
	get_ok_button().text = "Crea"
	confirmed.connect(_on_confirmed)

	kind_option.add_item("Oggetto normale", ItemScaffolder.WeaponKind.NONE)
	kind_option.add_item("Arma da mischia", ItemScaffolder.WeaponKind.MELEE)
	kind_option.add_item("Arma da fuoco", ItemScaffolder.WeaponKind.RANGED)

	_icon_picker = EditorResourcePicker.new()
	_icon_picker.base_type = "Texture2D"
	_icon_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	icon_row.add_child(_icon_picker)


func open_for_node(node: WorldItem) -> void:
	_target_node = node
	if node:
		target_label.text = "Nodo selezionato: %s (verrà assegnato automaticamente)" % node.name
	else:
		target_label.text = "Nessun WorldItem selezionato — verrà creato solo il file."
	slug_edit.text = ""
	name_edit.text = ""
	description_edit.text = ""
	kind_option.selected = 0
	_icon_picker.edited_resource = null
	popup_centered()
	slug_edit.grab_focus()


func _on_confirmed() -> void:
	var weapon_kind: int = kind_option.get_item_id(kind_option.selected)
	var icon := _icon_picker.edited_resource as Texture2D
	var result := ItemScaffolder.create(
		slug_edit.text, name_edit.text, description_edit.text, icon, weapon_kind
	)

	if result.ok and _target_node:
		_target_node.kind = WorldItem.Kind.PICKUPABLE
		_target_node.item = result.item

	result_ready.emit(result)
