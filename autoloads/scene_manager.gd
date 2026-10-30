extends CanvasLayer

## Changes scenes behind a fade to black.

const FADE_TIME: float = 0.25

var _fade: ColorRect


func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_fade)


## Fades out, swaps to the scene at [path], then fades back in.
func change_scene(path: String) -> void:
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	await create_tween().tween_property(_fade, "color:a", 1.0, Anim.t(FADE_TIME)).finished
	get_tree().change_scene_to_file(path)
	await get_tree().scene_changed
	await create_tween().tween_property(_fade, "color:a", 0.0, Anim.t(FADE_TIME)).finished
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
