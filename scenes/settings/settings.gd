extends CanvasLayer


func show_settings() -> void:
	visible = true
	process_mode = Node.PROCESS_MODE_ALWAYS



func hide_settings() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED



func _on_done_button_pressed():
	SaveManager.save_data()
	hide_settings()
