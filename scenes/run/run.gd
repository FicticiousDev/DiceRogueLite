extends Node3D

## Root of a run. Placeholder until Phase 02 adds the board.

const MAIN_MENU_SCENE: String = "res://scenes/ui/main_menu/main_menu.tscn"

@onready var exit_button: TextureButton = %ExitButton
@onready var settings_button: TextureButton = %SettingsButton
@onready var confirm_dialog: ConfirmDialog = $ConfirmDialog


func _ready() -> void:
	exit_button.pressed.connect(_on_exit_pressed)
	settings_button.pressed.connect(Settings.show_settings)


func _on_exit_pressed() -> void:
	if await confirm_dialog.ask("ABANDON RUN", "Return to the main menu?\nThe current run will be lost."):
		SaveManager.save_data()
		SceneManager.change_scene(MAIN_MENU_SCENE)
