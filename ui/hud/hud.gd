extends Control
## Minimal HUD: crosshair, interact prompt, equipped item icon. Visible only
## while GameManager.state == PLAYING. Wires itself up reactively instead of
## being pushed around by a central controller — same pattern as the menus.

@onready var crosshair: Label = $Crosshair
@onready var interact_prompt: Label = $InteractPrompt
@onready var equipped_icon: TextureRect = $EquippedItemIcon
@onready var ammo_label: Label = $AmmoLabel

var _equipped_item: ItemData = null


func _ready() -> void:
	visible = GameManager.state == GameManager.GameState.PLAYING
	interact_prompt.visible = false
	equipped_icon.visible = false
	ammo_label.visible = false

	GameManager.state_changed.connect(_on_state_changed)
	GameManager.player_registered.connect(_on_player_registered)
	InventoryManager.item_equipped.connect(_on_item_equipped)
	InventoryManager.item_unequipped.connect(_on_item_unequipped)
	InventoryManager.inventory_changed.connect(_update_ammo)

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
	interact_prompt.text = "[%s] %s" % [_interact_key_label(), tr(prompt_text_key)]
	interact_prompt.visible = true


## Reads the actual key bound to "interact" from the Input Map instead of
## hardcoding "E", so a rebind (if this template ever gets a key-binding
## menu) keeps showing the right key without a code change. No icon/glyph
## asset exists for this yet, so a plain key name is what's shown for now.
func _interact_key_label() -> String:
	for event in InputMap.action_get_events("interact"):
		if event is InputEventKey:
			return OS.get_keycode_string(event.physical_keycode)
	return "?"


func _on_interactable_lost() -> void:
	interact_prompt.visible = false


func _on_item_equipped(item: ItemData) -> void:
	_equipped_item = item
	# The 2D icon is a fallback for items with no first-person view model
	# (EquippedItemView shows that instead, bottom-right of the screen) —
	# showing both at once looks redundant/broken.
	if item.view_model == null:
		equipped_icon.texture = item.icon
		equipped_icon.visible = item.icon != null
	else:
		equipped_icon.texture = null
		equipped_icon.visible = false
	_update_ammo()


func _on_item_unequipped() -> void:
	_equipped_item = null
	equipped_icon.texture = null
	equipped_icon.visible = false
	_update_ammo()


## Shows the equipped item's ammo count while it's a RangedWeaponBehavior,
## kept in sync with every inventory change (firing consumes ammo via
## InventoryManager.remove_item, which emits inventory_changed).
func _update_ammo() -> void:
	var behavior := _equipped_item.equip_behavior if _equipped_item else null
	if behavior is RangedWeaponBehavior and behavior.ammo_item:
		ammo_label.text = str(InventoryManager.get_item_count(behavior.ammo_item.id))
		ammo_label.visible = true
	else:
		ammo_label.visible = false
