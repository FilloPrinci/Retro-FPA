extends ColorRect
## Full-screen fade used by SceneManager during scene changes. Lives inside
## Main's UILayer, above every other UI element.

func _ready() -> void:
	color = Color.BLACK
	color.a = 0.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func fade_out(duration: float = 0.4) -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var tween := create_tween()
	tween.tween_property(self, "color:a", 1.0, duration)
	await tween.finished


func fade_in(duration: float = 0.4) -> void:
	var tween := create_tween()
	tween.tween_property(self, "color:a", 0.0, duration)
	await tween.finished
	mouse_filter = Control.MOUSE_FILTER_IGNORE
