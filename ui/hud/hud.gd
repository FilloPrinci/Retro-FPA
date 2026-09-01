extends Control
## Minimal HUD: crosshair, interact prompt, equipped item icon. Visible only
## while GameManager.state == PLAYING. Wires itself up reactively instead of
## being pushed around by a central controller — same pattern as the menus.

@onready var crosshair: Label = $Crosshair
@onready var interact_prompt: Label = $InteractPrompt
@onready var equipped_icon: TextureRect = $EquippedItemIcon


func _ready() -> void:
	visible = GameManager.state == GameManager.GameState.PLAYING
	interact_prompt.visible = false
	equipped_icon.visible = false

	GameManager.state_changed.connect(_on_state_changed)
	GameManager.player_registered.connect(_on_player_registered)
	InventoryManager.item_equipped.connect(_on_item_equipped)
	InventoryManager.item_unequipped.connect(_on_item_unequipped)

	if GameManager.get_player():
		_on_player_registered(GameManager.get_player())


func _on_state_changed(new_state: GameManager.GameState) -> void:
	visible = new_state == GameManager.GameState.PLAYING


func _on_player_registered(player: Node3D) -> void:
	var interactor := player.get_node_or_null("Head/Camera3D/InteractionRay")
	if interactor == null:
		return
	interactor.interactable_changed.connect(_on_interactable_changed)
	interactor.interactable_lost.connect(_on_interactable_lost)


func _on_interactable_changed(prompt_text_key: String) -> void:
	interact_prompt.text = tr(prompt_text_key)
	interact_prompt.visible = true


func _on_interactable_lost() -> void:
	interact_prompt.visible = false


func _on_item_equipped(item: ItemData) -> void:
	equipped_icon.texture = item.icon
	equipped_icon.visible = item.icon != null


func _on_item_unequipped() -> void:
	equipped_icon.texture = null
	equipped_icon.visible = false
