extends Node3D

## Root of a run. Loads a level, places the player and frames the camera. Debug movement/LOS until the
## turn controller arrives in Phase 05.

const MAIN_MENU_SCENE: String = "res://scenes/ui/main_menu/main_menu.tscn"

const PLAYER_SCENE: PackedScene = preload("res://scenes/pieces/player.tscn")

@export var level_scene: PackedScene = preload("res://scenes/levels/test_01.tscn")
## Movement points for debug moves
@export var debug_move_budget: int = 4

@onready var camera_rig: CameraRig = $CameraRig
@onready var level_root: Node3D = $Level
@onready var exit_button: TextureButton = %ExitButton
@onready var settings_button: TextureButton = %SettingsButton
@onready var debug_label: Label = %DebugLabel
@onready var confirm_dialog: ConfirmDialog = $ConfirmDialog

var board: Board
var player: Player
var _hovered: int = -1
var _busy: bool = false
var _move_ctx: MoveContext
var _reachable: Array[int] = []
var _show_los: bool = false


func _ready() -> void:
	exit_button.pressed.connect(_on_exit_pressed)
	settings_button.pressed.connect(Settings.show_settings)
	load_level(level_scene)


func load_level(scene: PackedScene) -> void:
	if board:
		board.queue_free()
	board = scene.instantiate()
	level_root.add_child(board)
	player = PLAYER_SCENE.instantiate()
	board.add_piece(player, board.player_start)
	_cancel_move()
	camera_rig.frame(board.get_bounds())
	_busy = true
	await board.play_intro()
	_busy = false


func _process(_delta: float) -> void:
	if board:
		_update_hover()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_rebuild"):
		load_level(level_scene)
	elif event.is_action_pressed("debug_los"):
		_show_los = not _show_los
		_refresh_highlights()
	elif event.is_action_pressed("select"):
		_on_select()
	elif event.is_action_pressed("cancel") and _move_ctx:
		get_viewport().set_input_as_handled()
		_cancel_move()


func _on_exit_pressed() -> void:
	if await confirm_dialog.ask("ABANDON RUN", "Return to the main menu?\nThe current run will be lost."):
		SaveManager.save_data()
		SceneManager.change_scene(MAIN_MENU_SCENE)


# ===========================================================================================================================================
# Debug movement & line of sight - replaced by the turn controller in Phase 05
# ===========================================================================================================================================


## Click the player to show its move range; click a highlighted tile to move there.
func _on_select() -> void:
	if _busy or _hovered == -1:
		return
	if _hovered == player.tile_id:
		_cancel_move() if _move_ctx else _start_move()
	elif _move_ctx and _reachable.has(_hovered):
		var path := _move_ctx.path_to(_hovered)
		_cancel_move()
		_busy = true
		await player.move_along(path)
		_busy = false
		_refresh_highlights()


func _start_move() -> void:
	_move_ctx = MoveContext.new(player.tile_id, debug_move_budget, board.move_cost)
	_reachable = board.find_reachable(_move_ctx)
	_refresh_highlights()


func _cancel_move() -> void:
	_move_ctx = null
	_reachable.clear()
	if board:
		_refresh_highlights()


func _update_hover() -> void:
	var tile_id := board.tile_at_screen(camera_rig.camera, get_viewport().get_mouse_position())
	if tile_id != _hovered:
		_hovered = tile_id
		_refresh_highlights()


func _refresh_highlights() -> void:
	board.clear_highlights()
	if _show_los and not _busy:
		var visible_ids: Array[int] = []
		var hidden_ids: Array[int] = []
		for tile_id in board.tiles:
			if tile_id != player.tile_id:
				(visible_ids if board.has_line_of_sight(player.tile_id, tile_id) else hidden_ids).append(tile_id)
		board.highlight(visible_ids, HexTile.Highlight.VALID)
		board.highlight(hidden_ids, HexTile.Highlight.INVALID)
	if _move_ctx:
		board.highlight(_reachable, HexTile.Highlight.MOVABLE)
		if _reachable.has(_hovered):
			board.highlight(_move_ctx.path_to(_hovered), HexTile.Highlight.VALID)
	board.select(_hovered)
	_update_debug_label()


func _update_debug_label() -> void:
	var text := "[Click player] move (%d)   [L] line of sight %s   [R] rebuild" % [debug_move_budget, "ON" if _show_los else "off"]
	if _hovered != -1:
		var tile := board.get_tile(_hovered)
		text += "\nCell %s  |  %s  |  cost %d" % [tile.coords, Terrain.Type.keys()[tile.terrain], board.move_cost(_hovered)]
		if _move_ctx and _move_ctx.costs.has(_hovered):
			text += "  |  path cost %d" % _move_ctx.costs[_hovered]
		if tile.piece:
			text += "  |  " + tile.piece.name
	debug_label.text = text
