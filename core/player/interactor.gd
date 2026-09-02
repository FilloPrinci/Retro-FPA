extends RayCast3D
## Casts forward from the camera to find InteractableComponents in view.
## Emits signals for the HUD prompt and fires the interaction itself on the
## "interact" input. Does not know about dialogue, inventory, doors, etc. —
## it only finds an InteractableComponent and lets it emit `interacted`.

signal interactable_changed(prompt_text_key: String)
signal interactable_lost

var _current: InteractableComponent = null


func _physics_process(_delta: float) -> void:
	if not GameManager.control_enabled:
		if _current:
			_clear_current()
		return

	# An interactable picked up (or otherwise freed) while it's still
	# _current leaves a dangling reference — Godot compares a freed Object
	# equal to null, so `found != _current` below would silently never
	# trip and the prompt would stay stuck forever. Clear it explicitly
	# first so that comparison is always against a live reference or null.
	if _current and not is_instance_valid(_current):
		_clear_current()

	var found := _find_interactable()
	if found != _current:
		_current = found
		if _current:
			interactable_changed.emit(_current.prompt_text_key)
		else:
			interactable_lost.emit()

	if _current and Input.is_action_just_pressed("interact"):
		_current.interacted.emit(get_owner())


func _find_interactable() -> InteractableComponent:
	if not is_colliding():
		return null
	var collider := get_collider()
	if collider == null:
		return null
	for child in collider.get_children():
		if child is InteractableComponent:
			return child
	return null


func _clear_current() -> void:
	_current = null
	interactable_lost.emit()
