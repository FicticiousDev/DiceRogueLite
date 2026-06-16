extends CanvasLayer



func _on_done_button_pressed():
	SaveManager.save_data()
	call_deferred("free")
