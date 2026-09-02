extends RayCast3D
## Casts forward from the camera to find InteractableComponents in view.
## Emits signals for the HUD prompt and fires the interaction itself on the
## "interact" input. Does not know about dialogue, inventory, doors, etc. —
## it only finds an InteractableComponent and lets it emit `interacted`.

signal interactable_changed(prompt_text_key: String)
signal interactable_lost

var _current: InteractableComponent = null
## Tracked separately from _current's own nullness/truthiness: a freed
## Object compares EQUAL to null and is falsy in GDScript (Godot's
## "stale reference" safety), so once the thing we're pointing at is
## queue_free()'d (e.g. picked up), `_current` can no longer be told
## apart from "nothing" by `if _current:` or `== / !=` — those all
## silently agree it's null even though is_instance_valid() correctly
## says otherwise. _has_current is the only reliable "is there something"
## check; is_instance_valid() is the only reliable "is it still alive" one.
var _has_current: bool = false


func _physics_process(_delta: float) -> void:
	if not GameManager.control_enabled:
		_clear_current()
		return

	if _has_current and not is_instance_valid(_current):
		_clear_current()

	# _current is now guaranteed to be either null or a live reference
	# (the freed case was just handled above via _has_current, never by
	# comparing the stale reference itself), so this compare is safe.
	var found := _find_interactable()
	if found != _current:
		_current = found
		_has_current = found != null
		if _has_current:
			interactable_changed.emit(_current.prompt_text_key)
		else:
			interactable_lost.emit()

	if _has_current and Input.is_action_just_pressed("interact"):
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
	if not _has_current:
		return
	_current = null
	_has_current = false
	interactable_lost.emit()
