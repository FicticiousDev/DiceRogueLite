extends Node3D

## Root of a run. Loads a level, places the player, frames the camera and hands over to the turn controller.

const MAIN_MENU_SCENE: String = "res://scenes/ui/main_menu/main_menu.tscn"

const PLAYER_SCENE: PackedScene = preload("res://scenes/pieces/player.tscn")
const ENEMY_INFO_SCENE: PackedScene = preload("res://scenes/ui/enemy_info/enemy_info.tscn")
## Screen fraction kept clear for the turn plan panel
const PANEL_MARGIN: float = 0.22
const EDGE_MARGIN: float = 0.04

## Pool for a new run until characters define starting dice (Phase 08)
const STARTING_DICE: Array[String] = ["normal", "normal", "normal", "normal", "normal", "normal"]

@export var level_scene: PackedScene = preload("res://scenes/levels/test_01.tscn")

@onready var camera_rig: CameraRig = $CameraRig
@onready var level_root: Node3D = $Level
@onready var exit_button: TextureButton = %ExitButton
@onready var settings_button: TextureButton = %SettingsButton
@onready var debug_label: Label = %DebugLabel
@onready var action_list: ActionList = %ActionList
@onready var enemy_infos: Control = %EnemyInfos
@onready var confirm_dialog: ConfirmDialog = $ConfirmDialog
@onready var dice_tray: DiceTray = $DiceTray
@onready var turn: TurnController = $TurnController

var board: Board
var player: Player
var _grid_overlay: GridOverlay
var _showcase_design: int = 0
var _loading: bool = false


func _ready() -> void:
	exit_button.pressed.connect(_on_exit_pressed)
	settings_button.pressed.connect(Settings.show_settings)
	dice_tray.camera = camera_rig.camera
	if SaveManager.run_data.dice.is_empty():
		SaveManager.run_data.dice.assign(STARTING_DICE)
		SaveManager.run_data.health = SaveManager.run_data.max_health
	SaveManager.settings_data.changed.connect(_apply_layout)
	_apply_layout()
	load_level(level_scene)


func _exit_tree() -> void:
	SaveManager.settings_data.changed.disconnect(_apply_layout)


## Puts the turn plan on the chosen side and centres the board, tray and dice row in the rest of the screen.
func _apply_layout() -> void:
	var left := SaveManager.settings_data.turn_plan_left
	action_list.set_side(left)
	var margin_left := PANEL_MARGIN if left else EDGE_MARGIN
	var margin_right := EDGE_MARGIN if left else PANEL_MARGIN
	camera_rig.frame_margins.x = margin_left
	camera_rig.frame_margins.z = margin_right
	var centre := (margin_left + 1.0 - margin_right) / 2.0
	dice_tray.tray_screen_point.x = centre
	dice_tray.row_screen_x = centre
	if board:
		camera_rig.frame(board.get_bounds(), false)


func load_level(scene: PackedScene) -> void:
	_loading = true
	await turn.reset()
	if board:
		board.queue_free()
	_grid_overlay = null
	board = scene.instantiate()
	level_root.add_child(board)
	player = PLAYER_SCENE.instantiate()
	board.add_piece(player, board.player_start)
	turn.setup(board, player, dice_tray, action_list, confirm_dialog)
	for enemy in board.get_enemies():
		var info: EnemyInfo = ENEMY_INFO_SCENE.instantiate()
		info.setup(enemy, camera_rig.camera)
		enemy_infos.add_child(info)
	camera_rig.frame(board.get_bounds())
	await board.play_intro()
	_loading = false
	turn.start_turn()


func _process(_delta: float) -> void:
	if not board:
		return
	if _grid_overlay:
		_grid_overlay.show_pick(turn.hovered_tile, board.last_pick_point)
	_update_debug_label()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_rebuild") and _can_debug(true):
		SaveManager.run_data.health = SaveManager.run_data.max_health
		load_level(level_scene)
	elif event.is_action_pressed("debug_roll") and _can_debug():
		turn.debug_pool.clear()
		turn.start_turn(false)
	elif event.is_action_pressed("debug_roll_showcase") and _can_debug():
		_debug_showcase()
	elif event.is_action_pressed("debug_grid"):
		_toggle_grid_overlay()
	elif event.is_action_pressed("debug_los"):
		turn.show_los = not turn.show_los
		turn._refresh()


func _on_exit_pressed() -> void:
	if await confirm_dialog.ask("ABANDON RUN", "Return to the main menu?\nThe current run will be lost."):
		SaveManager.save_data()
		SceneManager.change_scene(MAIN_MENU_SCENE)


# ===========================================================================================================================================
# Debug
# ===========================================================================================================================================


func _can_debug(allow_finished: bool = false) -> bool:
	var finished := turn.state in [TurnController.State.LEVEL_CLEAR, TurnController.State.GAME_OVER]
	return not _loading and (turn.state == TurnController.State.PLAN or (allow_finished and finished))


## Re-rolls this turn with one showcase die per rarity, alternating designs.
func _debug_showcase() -> void:
	var all := Database.get_all("dice_debug")
	all.sort_custom(func(a: DieType, b: DieType): return a.rarity < b.rarity)
	turn.debug_pool.assign(all)
	var designs := Database.get_all("die_designs")
	turn.debug_design = designs[_showcase_design % designs.size()]
	_showcase_design += 1
	turn.start_turn(false)


func _toggle_grid_overlay() -> void:
	if _grid_overlay:
		_grid_overlay.queue_free()
		_grid_overlay = null
	else:
		_grid_overlay = GridOverlay.new()
		board.add_child(_grid_overlay)
		_grid_overlay.setup(board)


func _update_debug_label() -> void:
	var text := "[D] re-roll   [F] showcase dice   [L] line of sight %s   [G] grid %s   [R] rebuild" % [
		"ON" if turn.show_los else "off", "ON" if _grid_overlay else "off"]
	if turn.results.size() > 0:
		text += "\nRolled: " + ", ".join(turn.results.map(func(r: DieResult): return r.describe()))
	if turn.hovered_tile != -1:
		var tile := board.get_tile(turn.hovered_tile)
		text += "\nCell %s  |  %s  |  cost %d" % [tile.coords, Terrain.Type.keys()[tile.terrain], board.move_cost(turn.hovered_tile)]
		if turn._move_ctx and turn._move_ctx.costs.has(turn.hovered_tile):
			text += "  |  path cost %d" % turn._move_ctx.costs[turn.hovered_tile]
		if tile.piece:
			text += "  |  " + tile.piece.name
	debug_label.text = text
