extends Node3D


@onready var settings_scene: SettingsScene = $Settings
@onready var exit_confirmation: ConfirmExit = $ConfirmExit
@onready var rules_button = $Rulebook



func _ready() -> void:
	exit_confirmation.exit_confirmed.connect(_on_confirm_exit_pressed)
	exit_confirmation.cancel_exit.connect(_on_cancel_exit_pressed)
	rules_button.rules_pressed.connect(_on_rules_button_rules_pressed)


func _on_rules_button_rules_pressed() -> void:
	# TODO - move rulebook rect up to camera
	print("rules pressed")


func _on_rules_closed() -> void:
	## TODO - move rulebook rect back down to original position
	pass


func _on_settings_button_settings_pressed() -> void:
	get_node("Settings").show_settings()


func _on_exit_button_exit_pressed() -> void:
	exit_confirmation.show_confirmation()


func _on_confirm_exit_pressed() -> void:
	SaveManager.save_data()
	get_tree().quit()


func _on_cancel_exit_pressed() -> void:
	exit_confirmation.hide_confirmation()
