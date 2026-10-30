extends Node3D

## Root of a run. Loads a level, frames the camera and (for now) shows debug tile hover.

const MAIN_MENU_SCENE: String = "res://scenes/ui/main_menu/main_menu.tscn"

@export var level_scene: PackedScene = preload("res://scenes/levels/test_01.tscn")

@onready var camera_rig: CameraRig = $CameraRig
@onready var level_root: Node3D = $Level
@onready var exit_button: TextureButton = %ExitButton
@onready var settings_button: TextureButton = %SettingsButton
@onready var debug_label: Label = %DebugLabel
@onready var confirm_dialog: ConfirmDialog = $ConfirmDialog

var board: Board
var _hovered: int = -1


func _ready() -> void:
	exit_button.pressed.connect(_on_exit_pressed)
	settings_button.pressed.connect(Settings.show_settings)
	load_level(level_scene)


func load_level(scene: PackedScene) -> void:
	if board:
		board.queue_free()
	board = scene.instantiate()
	level_root.add_child(board)
	camera_rig.frame(board.get_bounds())
	await board.play_intro()


func _process(_delta: float) -> void:
	if board:
		_update_hover()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_rebuild"):
		load_level(level_scene)


func _on_exit_pressed() -> void:
	if await confirm_dialog.ask("ABANDON RUN", "Return to the main menu?\nThe current run will be lost."):
		SaveManager.save_data()
		SceneManager.change_scene(MAIN_MENU_SCENE)


# ===========================================================================================================================================
# Debug hover - replaced by the turn controller in Phase 05
# ===========================================================================================================================================


func _update_hover() -> void:
	var tile_id := board.tile_at_screen(camera_rig.camera, get_viewport().get_mouse_position())
	if tile_id == _hovered:
		return
	_hovered = tile_id
	board.clear_highlights()
	if tile_id == -1:
		debug_label.text = ""
		return

	board.select(tile_id)
	var walkable: Array[int] = []
	var blocked: Array[int] = []
	for neighbour in board.get_neighbours(tile_id):
		if board.is_walkable(neighbour):
			walkable.append(neighbour)
		else:
			blocked.append(neighbour)
	board.highlight(walkable, HexTile.Highlight.VALID)
	board.highlight(blocked, HexTile.Highlight.INVALID)

	var tile := board.get_tile(tile_id)
	debug_label.text = "Cell %s  |  %s  |  cost %d  |  %d from start" % [
		tile.coords, Terrain.Type.keys()[tile.terrain], board.move_cost(tile_id), Hex.distance(board.player_start, tile.coords)]
