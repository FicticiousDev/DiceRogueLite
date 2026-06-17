extends Node3D


@onready var rules_button = get_node("Buttons/RulesButton")
@onready var exit_button = get_node("Buttons/ExitButton")
@onready var settings_button = get_node("Buttons/SettingsButton")


func _ready() -> void:
	rules_button.rules_pressed.connect(_on_rules_button_rules_pressed)
	settings_button.settings_pressed.connect(_on_settings_button_settings_pressed)
	exit_button.exit_pressed.connect(_on_exit_button_exit_pressed)


func _on_rules_button_rules_pressed() -> void:
	print("rules pressed")


func _on_settings_button_settings_pressed() -> void:
	get_node("Settings").show_settings()


func _on_exit_button_exit_pressed() -> void:
	# TODO - shut down gracefully, communicate with Steam?
	SaveManager.save_data()
	get_tree().quit()