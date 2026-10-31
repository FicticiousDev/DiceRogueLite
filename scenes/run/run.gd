extends Node3D

## Root of a run. Loads a level, places the player and frames the camera. Debug movement/LOS until the
## turn controller arrives in Phase 05.

const MAIN_MENU_SCENE: String = "res://scenes/ui/main_menu/main_menu.tscn"

const PLAYER_SCENE: PackedScene = preload("res://scenes/pieces/player.tscn")
## Pool for a new run until characters define starting dice (Phase 08)
const STARTING_DICE: Array[String] = ["normal", "normal", "normal", "normal", "normal", "normal"]

@export var level_scene: PackedScene = preload("res://scenes/levels/test_01.tscn")
## Movement points for debug moves
@export var debug_move_budget: int = 4

@onready var camera_rig: CameraRig = $CameraRig
@onready var level_root: Node3D = $Level
@onready var exit_button: TextureButton = %ExitButton
@onready var settings_button: TextureButton = %SettingsButton
@onready var debug_label: Label = %DebugLabel
@onready var confirm_dialog: ConfirmDialog = $ConfirmDialog
@onready var dice_tray: DiceTray = $DiceTray

var board: Board
var player: Player
var _hovered: int = -1
var _busy: bool = false
var _move_ctx: MoveContext
var _reachable: Array[int] = []
var _show_los: bool = false
var _grid_overlay: GridOverlay
var _showcase_design: int = 0
var _last_roll: Array[DieResult] = []


func _ready() -> void:
	exit_button.pressed.connect(_on_exit_pressed)
	settings_button.pressed.connect(Settings.show_settings)
	dice_tray.camera = camera_rig.camera
	if SaveManager.run_data.dice.is_empty():
		SaveManager.run_data.dice.assign(STARTING_DICE)
	load_level(level_scene)


func load_level(scene: PackedScene) -> void:
	if board:
		board.queue_free()
	_grid_overlay = null
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
	elif event.is_action_pressed("debug_roll"):
		_debug_roll(false)
	elif event.is_action_pressed("debug_roll_showcase"):
		_debug_roll(true)
	elif event.is_action_pressed("debug_grid"):
		_toggle_grid_overlay()
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


## D rolls the run's pool with the selected design; F rolls one showcase die per rarity, alternating designs.
func _debug_roll(showcase: bool) -> void:
	if dice_tray.rolling:
		return
	var types: Array[DieType] = []
	var design: DieDesign
	if showcase:
		var all := Database.get_all("dice_debug")
		all.sort_custom(func(a: DieType, b: DieType): return a.rarity < b.rarity)
		types.assign(all)
		var designs := Database.get_all("die_designs")
		design = designs[_showcase_design % designs.size()]
		_showcase_design += 1
	else:
		for id in SaveManager.run_data.dice:
			types.append(Database.get_content("dice", id))
		design = Database.get_content("die_designs", SaveManager.progression_data.die_design)
	_last_roll = await dice_tray.roll(types, design)
	_update_debug_label()


func _toggle_grid_overlay() -> void:
	if _grid_overlay:
		_grid_overlay.queue_free()
		_grid_overlay = null
	else:
		_grid_overlay = GridOverlay.new()
		board.add_child(_grid_overlay)
		_grid_overlay.setup(board)
	_update_debug_label()


func _update_hover() -> void:
	var tile_id := board.tile_at_screen(camera_rig.camera, get_viewport().get_mouse_position())
	if _grid_overlay:
		_grid_overlay.show_pick(tile_id, board.last_pick_point)
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
	var text := "[Click player] move (%d)   [D] roll dice   [F] showcase dice   [L] line of sight %s   [G] grid %s   [R] rebuild" % [
		debug_move_budget, "ON" if _show_los else "off", "ON" if _grid_overlay else "off"]
	if _last_roll.size() > 0:
		text += "\nRolled: " + ", ".join(_last_roll.map(func(r: DieResult): return r.face().describe()))
	if _hovered != -1:
		var tile := board.get_tile(_hovered)
		text += "\nCell %s  |  %s  |  cost %d" % [tile.coords, Terrain.Type.keys()[tile.terrain], board.move_cost(_hovered)]
		if _move_ctx and _move_ctx.costs.has(_hovered):
			text += "  |  path cost %d" % _move_ctx.costs[_hovered]
		if tile.piece:
			text += "  |  " + tile.piece.name
	debug_label.text = text
