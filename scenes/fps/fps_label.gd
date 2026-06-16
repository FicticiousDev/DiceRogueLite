extends Label


func _process(_delta) -> void:
	visible = SaveManager.settings_data.show_fps
	if visible:
		set_text(str(Engine.get_frames_per_second()))

