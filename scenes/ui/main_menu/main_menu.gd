extends Node3D

## Main menu with a placeholder 3D backdrop.

const RUN_SCENE: String = "res://scenes/run/run.tscn"

@onready var new_run_button: Button = %NewRunButton
@onready var continue_button: Button = %ContinueButton
@onready var settings_button: Button = %SettingsButton
@onready var quit_button: Button = %QuitButton
@onready var confirm_dialog: ConfirmDialog = $ConfirmDialog
@onready var hex: MeshInstance3D = $Hex
@onready var piece: Sprite3D = $Hex/Piece


func _ready() -> void:
	new_run_button.pressed.connect(_on_new_run_pressed)
	settings_button.pressed.connect(Settings.show_settings)
	quit_button.pressed.connect(_on_quit_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	continue_button.disabled = not SaveManager.has_run()
	_bob_piece()


func _process(delta: float) -> void:
	hex.rotate_y(delta * 0.3)


func _on_new_run_pressed() -> void:
	if SaveManager.has_run():
		if not await confirm_dialog.ask("NEW RUN", "Start a new run?\nYour saved run will be lost."):
			return
		SaveManager.end_run(ProgressionData.Outcome.ABANDONED)
	else:
		SaveManager.clear_run()
		SaveManager.save_data()
	SceneManager.change_scene(RUN_SCENE)


func _on_continue_pressed() -> void:
	SceneManager.change_scene(RUN_SCENE)


func _on_quit_pressed() -> void:
	if await confirm_dialog.ask("QUIT", "Are you sure you want to quit?"):
		SaveManager.save_data()
		get_tree().quit()


func _bob_piece() -> void:
	var tween := create_tween().set_loops()
	tween.tween_property(piece, "position:y", piece.position.y + 0.12, 0.6).set_trans(Tween.TRANS_SINE)
	tween.tween_property(piece, "position:y", piece.position.y, 0.6).set_trans(Tween.TRANS_SINE)
