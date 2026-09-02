@tool
extends ConfirmationDialog
## "Nuovo dialogo NPC" wizard popup — open_for_node() is called by
## plugin.gd with whatever node is selected in the Scene dock when
## "Nuovo dialogo NPC..." is pressed. Pressing the (renamed) OK button
## runs DialogueScaffolder.create() and reports the outcome via
## result_ready, instead of the dock/plugin having to know anything about
## this dialog's internals.

signal result_ready(result: Dictionary)

@onready var selected_node_label: Label = $VBox/SelectedNodeLabel
@onready var slug_edit: LineEdit = $VBox/SlugRow/SlugEdit
@onready var speaker_edit: LineEdit = $VBox/SpeakerRow/SpeakerEdit

var _target_node: Node = null


func _ready() -> void:
	title = "Nuovo dialogo NPC"
	get_ok_button().text = "Crea"
	confirmed.connect(_on_confirmed)


func open_for_node(node: Node) -> void:
	_target_node = node
	selected_node_label.text = "Nodo selezionato: %s" % (node.name if node else "(nessuno)")
	slug_edit.text = ""
	speaker_edit.text = ""
	popup_centered()
	slug_edit.grab_focus()


func _on_confirmed() -> void:
	var result := DialogueScaffolder.create(_target_node, slug_edit.text, speaker_edit.text)
	result_ready.emit(result)
