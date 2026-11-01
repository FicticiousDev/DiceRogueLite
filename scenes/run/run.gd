extends Node3D

## Root of a run. Loads the current level of the run map, populates it, places the player and hands over to the
## turn controller. Once a level is clear its exit gates open; choosing one walks the player into it, folds the level
## away around that tile and carries the tile (player and all) to the next level's start. The run is saved as
## each level begins.

const MAIN_MENU_SCENE: String = "res://scenes/ui/main_menu/main_menu.tscn"

const PLAYER_SCENE: PackedScene = preload("res://scenes/pieces/player.tscn")
## Screen fraction kept clear for the turn plan panel
const PANEL_MARGIN: float = 0.22
const EDGE_MARGIN: float = 0.04
## Share of a level's enemy points used at the start of the run, plus this per level entered and per biome difficulty
const ENEMY_SHARE: float = 0.25
const ENEMY_SHARE_PER_DEPTH: float = 0.025
const ENEMY_SHARE_PER_DIFFICULTY: float = 0.04
const LOOT_SHARE: float = 0.2
const LOOT_SHARE_PER_DEPTH: float = 0.04
const CARRY_DURATION: float = 0.9
## Smallest area the camera frames, so tiny levels aren't blown up, and headroom for gates and their symbols
const MIN_FRAME_SIZE: Vector2 = Vector2(10.0, 7.0)
const FRAME_HEADROOM: float = 1.8

@onready var camera_rig: CameraRig = $CameraRig
@onready var level_root: Node3D = $Level
@onready var exit_button: TextureButton = %ExitButton
@onready var settings_button: TextureButton = %SettingsButton
@onready var debug_label: Label = %DebugLabel
@onready var action_list: ActionList = %ActionList
@onready var confirm_dialog: ConfirmDialog = $ConfirmDialog
@onready var sacrifice_dialog: SacrificeDialog = $SacrificeDialog
@onready var game_over: GameOverScreen = $GameOver
@onready var block_prompt: BlockPrompt = %BlockPrompt
@onready var character_picker: CharacterPicker = $CharacterPicker
@onready var top_bar: TopBar = %TopBar
@onready var dice_tray: DiceTray = $DiceTray
@onready var turn: TurnController = $TurnController

var board: Board
var player: Player
var _grid_overlay: GridOverlay
var _showcase_design: int = 0
var _loading: bool = false
var _map_view: RunMapView
var _challenge: ChallengeBanner
var _enemy_details: EnemyDetails
## Explains the hovered die's face after a short hover
var _die_tip_layer: CanvasLayer
var _die_tip: InfoPanel
var _die_tip_index: int = -1
var _die_tip_time: float = 0.0
var _hovered_exit: ExitGate


func _ready() -> void:
	exit_button.pressed.connect(_on_exit_pressed)
	settings_button.pressed.connect(Settings.show_settings)
	dice_tray.camera = camera_rig.camera
	turn.state_changed.connect(_on_turn_state_changed)
	top_bar.turn = turn
	SaveManager.settings_data.changed.connect(_apply_layout)
	_apply_layout()
	_map_view = RunMapView.new()
	add_child(_map_view)
	_challenge = ChallengeBanner.new()
	add_child(_challenge)
	_enemy_details = EnemyDetails.new()
	add_child(_enemy_details)
	turn.enemy_inspected.connect(_enemy_details.open)
	_die_tip_layer = CanvasLayer.new()
	_die_tip_layer.layer = 34
	add_child(_die_tip_layer)
	var run := SaveManager.run_data
	if run.character_id == "" or run.dice.is_empty():
		_start_run(await character_picker.pick())
	if not SaveManager.has_run():
		run.map = RunMap.generate()
		run.path = [0]
	load_level()


## Sets up a new run for [character_id]: its starting dice and full health.
func _start_run(character_id: StringName) -> void:
	var character: CharacterData = Database.get_content("characters", character_id)
	var run := SaveManager.run_data
	run.character_id = character_id
	run.dice.assign(character.starting_dice)
	run.max_health = character.max_hp
	run.health = character.max_hp


func _exit_tree() -> void:
	SaveManager.settings_data.changed.disconnect(_apply_layout)


## Puts the turn plan on the chosen side and centres the board, tray and dice row in the rest of the screen.
func _apply_layout() -> void:
	var left := SaveManager.settings_data.turn_plan_side == SettingsData.SIDE_LEFT
	action_list.set_side(left)
	var margin_left := PANEL_MARGIN if left else EDGE_MARGIN
	var margin_right := EDGE_MARGIN if left else PANEL_MARGIN
	camera_rig.frame_margins.x = margin_left
	camera_rig.frame_margins.z = margin_right
	var centre := (margin_left + 1.0 - margin_right) / 2.0
	dice_tray.tray_screen_point.x = centre
	dice_tray.row_screen_x = centre
	if board:
		camera_rig.frame(_frame_bounds(), false)
	dice_tray.refresh_row()


# ===========================================================================================================================================
# Levels
# ===========================================================================================================================================


## Builds the run's current level, saves the run and starts the first turn. [carried] is the exit tile from the
## last level, with the player on it: it glides to the new start and the new level grows out from it.
func load_level(carried: HexTile = null) -> void:
	_loading = true
	SaveManager.checkpoint_run()
	await turn.reset()
	if _grid_overlay:
		_toggle_grid_overlay()
	var run := SaveManager.run_data
	var index := RunMap.current_index(run)
	var old_board := board
	board = RunMap.level(run, index).scene.instantiate()
	board.biome = RunMap.biome(run, index)
	level_root.add_child(board)
	_populate(index)

	if carried:
		await _carry(carried)
		old_board.queue_free()
		player.reparent(board.pieces_root)
		player.tile_id = -1
		player.place(board, Hex.id(board.player_start))
	else:
		if old_board:
			old_board.queue_free()
		player = PLAYER_SCENE.instantiate()
		player.character = Database.get_content("characters", run.character_id)
		player.moved.connect(_on_player_moved)
		board.add_piece(player, board.player_start)
		camera_rig.frame(_frame_bounds())
	turn.clear_hint = "Level clear!  Click an open gate to choose your next level.  [M] map" if RunMap.next(run, index).size() > 0 \
		else "Run complete!  (The run end screen arrives in Phase 10.)"
	turn.setup(board, player, dice_tray, action_list, confirm_dialog, sacrifice_dialog, block_prompt)
	_challenge.start(turn, 0)
	await board.play_intro(carried != null)
	var level := RunMap.level(run, index)
	if level.type == LevelData.Type.CHALLENGE:
		await _challenge.start(turn, level.turn_limit)
	_loading = false
	turn.start_turn()


## The board's bounds, grown to the minimum frame size and with headroom for tall pieces.
func _frame_bounds() -> AABB:
	var bounds := board.get_bounds()
	bounds.size.y += FRAME_HEADROOM
	var grow := Vector3(maxf(MIN_FRAME_SIZE.x - bounds.size.x, 0.0), 0.0, maxf(MIN_FRAME_SIZE.y - bounds.size.z, 0.0))
	return AABB(bounds.position - grow / 2.0, bounds.size + grow)


## Moves [carried] and the player from the old level's exit to the new level's start while the camera follows.
func _carry(carried: HexTile) -> void:
	var start := board.to_global(board.cell_to_local(board.player_start))
	var from := carried.global_position
	var lift := player.global_position - from
	camera_rig.glide(_frame_bounds(), CARRY_DURATION)
	var tween := create_tween()
	tween.tween_method(func(t: float):
		carried.global_position = from.lerp(start, t)
		player.global_position = carried.global_position + lift, 0.0, 1.0, Anim.t(CARRY_DURATION)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished


## Chooses which of the level's enemy and loot points are used - more the deeper the run and the harder the biome -
## and puts gates on as many exit points as the level has connections. Seeded by the map node, so a resumed level
## matches.
func _populate(index: int) -> void:
	var run := SaveManager.run_data
	var rng := RandomNumberGenerator.new()
	rng.seed = int(RunMap.node(run, index).seed)
	var level := RunMap.level(run, index)
	var biome := board.biome
	var depth := run.path.size() - 1

	var enemy_cells := _shuffled(board.get_marker_cells(Board.Marker.ENEMY), rng)
	var share := ENEMY_SHARE + ENEMY_SHARE_PER_DEPTH * depth + ENEMY_SHARE_PER_DIFFICULTY * biome.difficulty
	if level.type == LevelData.Type.BOSS and enemy_cells.size() > 0:
		# The boss takes the enemy point farthest from the start
		enemy_cells.sort_custom(func(a: Vector2i, b: Vector2i): return Hex.distance(a, board.player_start) > Hex.distance(b, board.player_start))
		board.spawn_enemy(Database.get_content("enemies", biome.boss_id), enemy_cells.pop_front())
	var count := enemy_cells.size() if level.type == LevelData.Type.CHALLENGE else _share_of(enemy_cells.size(), share, level.type == LevelData.Type.NORMAL)
	for cell in enemy_cells.slice(0, count):
		board.spawn_enemy(Database.get_content("enemies", biome.enemy_ids[rng.randi() % biome.enemy_ids.size()]), cell)

	var loot_cells := _shuffled(board.get_marker_cells(Board.Marker.LOOT), rng)
	for cell in loot_cells.slice(0, _share_of(loot_cells.size(), LOOT_SHARE + LOOT_SHARE_PER_DEPTH * depth, true)):
		board.spawn_loot(rng.randi_range(2, 4) + biome.difficulty, cell)

	# Gates top to bottom on screen match the next levels top to bottom on the map
	var links := RunMap.next(run, index)
	links.sort_custom(func(a: int, b: int): return float(RunMap.node(run, a).row) < float(RunMap.node(run, b).row))
	var exit_cells := _shuffled(board.get_marker_cells(Board.Marker.EXIT), rng).slice(0, links.size())
	exit_cells.sort_custom(func(a: Vector2i, b: Vector2i): return board.cell_to_local(a).z < board.cell_to_local(b).z)
	for i in exit_cells.size():
		board.spawn_exit(links[i], LevelData.ICONS[RunMap.level(run, links[i]).type], RunMap.biome(run, links[i]).color, exit_cells[i])


## round(total * share), clamped to the total, and at least one if [at_least_one].
static func _share_of(total: int, share: float, at_least_one: bool) -> int:
	return clampi(roundi(total * share), 1 if at_least_one and total > 0 else 0, total)


static func _shuffled(cells: Array[Vector2i], rng: RandomNumberGenerator) -> Array[Vector2i]:
	cells.sort()
	for i in range(cells.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap := cells[i]
		cells[i] = cells[j]
		cells[j] = swap
	return cells


func _on_player_moved(_from_id: int, to_id: int) -> void:
	var gold := board.collect_loot(to_id)
	if gold > 0:
		SaveManager.run_data.gold += gold
		player.popup("+%d" % gold, Color(1, 0.82, 0.3))


# ===========================================================================================================================================
# Exits
# ===========================================================================================================================================


func _update_exit_hover() -> void:
	var exit: ExitGate = null
	if turn.state == TurnController.State.LEVEL_CLEAR and not _loading and not _map_view.visible:
		var piece := board.get_piece(board.tile_at_screen(camera_rig.camera, get_viewport().get_mouse_position()))
		if piece is ExitGate and piece.unlocked:
			exit = piece
	if exit != _hovered_exit:
		if is_instance_valid(_hovered_exit):
			_hovered_exit.set_hovered(false)
		_hovered_exit = exit
		if exit:
			exit.set_hovered(true)


func _choose_exit(exit: ExitGate) -> void:
	var run := SaveManager.run_data
	var biome := RunMap.biome(run, exit.target)
	var type := RunMap.level(run, exit.target).type
	_loading = true
	if not await confirm_dialog.ask("TRAVEL", "Head to the %s: %s?" % [biome.display_name, LevelData.NAMES[type]]):
		_loading = false
		return
	var target := exit.target
	var tile_id := exit.tile_id
	exit.set_hovered(false)
	_hovered_exit = null
	exit.open()
	var path := board.find_path(player.tile_id, tile_id)
	if path.is_empty():
		await player.teleport_to(tile_id)
	else:
		await player.move_along(path)
	exit.vanish()
	await board.play_outro(tile_id)
	run.path.append(target)
	load_level(board.get_tile(tile_id))


func _process(delta: float) -> void:
	if not board:
		return
	_update_exit_hover()
	_update_die_tip(delta)
	if _grid_overlay:
		_grid_overlay.show_pick(turn.hovered_tile, board.last_pick_point)
	_update_debug_label()


func _unhandled_input(event: InputEvent) -> void:
	if _enemy_details.visible:
		return
	if event.is_action_pressed("map") and not character_picker.visible:
		_map_view.toggle()
	elif _map_view.visible:
		return
	elif event.is_action_pressed("select") and _hovered_exit:
		_choose_exit(_hovered_exit)
	elif event.is_action_pressed("debug_rebuild") and _can_debug(true):
		SaveManager.run_data.health = SaveManager.run_data.max_health
		load_level()
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


func _on_turn_state_changed(state: TurnController.State) -> void:
	if state == TurnController.State.GAME_OVER:
		game_over.show_screen(turn.turn_number)
	elif state == TurnController.State.LEVEL_CLEAR:
		for exit in board.get_exits():
			exit.unlock()


func _on_exit_pressed() -> void:
	if await confirm_dialog.ask("MAIN MENU", "Return to the main menu?\nContinue picks up from the start of this level."):
		SaveManager.save_data()
		SceneManager.change_scene(MAIN_MENU_SCENE)


## Seconds a die must be hovered before its tooltip shows
const DIE_TIP_DELAY: float = 0.35


## Shows what the hovered die's symbols do, next to the mouse, while it stays hovered.
func _update_die_tip(delta: float) -> void:
	var index := turn.hovered_die if turn.hovered_die < turn.results.size() else -1
	if index != _die_tip_index:
		_die_tip_index = index
		_die_tip_time = 0.0
		if _die_tip:
			_die_tip.queue_free()
			_die_tip = null
	if index == -1:
		return
	_die_tip_time += delta
	if _die_tip == null and _die_tip_time >= DIE_TIP_DELAY:
		var result := turn.results[index]
		var title := "%s  ·  %s" % [result.die_type.display_name, Rarity.Tier.keys()[result.die_type.rarity].capitalize()]
		_die_tip = InfoPanel.create(title, HelpText.face_rows(result.display_face()), 340.0, 17)
		_die_tip_layer.add_child(_die_tip)
	if _die_tip:
		# Above and to the right of the mouse, kept on screen
		var mouse := get_viewport().get_mouse_position()
		var screen := get_viewport().get_visible_rect().size
		var at := mouse + Vector2(24, -_die_tip.size.y - 16)
		_die_tip.position = at.clamp(Vector2.ZERO, screen - _die_tip.size)


# ===========================================================================================================================================
# Debug
# ===========================================================================================================================================


func _can_debug(allow_cleared: bool = false) -> bool:
	var cleared := turn.state == TurnController.State.LEVEL_CLEAR
	return not _loading and (turn.state == TurnController.State.PLAN or (allow_cleared and cleared))


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
	var text := "[D] re-roll   [F] showcase dice   [L] line of sight %s   [G] grid %s   [R] restart level" % [
		"ON" if turn.show_los else "off", "ON" if _grid_overlay else "off"]
	if turn.results.size() > 0:
		text += "\nRolled: " + ", ".join(turn.results.map(func(r: DieResult): return r.describe()))
	if board.has_tile(turn.hovered_tile):
		var tile := board.get_tile(turn.hovered_tile)
		text += "\nCell %s  |  %s  |  cost %d" % [tile.coords, Terrain.Type.keys()[tile.terrain], board.move_cost(turn.hovered_tile)]
		if turn._move_ctx and turn._move_ctx.costs.has(turn.hovered_tile):
			text += "  |  path cost %d" % turn._move_ctx.costs[turn.hovered_tile]
		if tile.piece:
			# Node names get made unique (@Enemy@12) when a type repeats, so name enemies by their data
			text += "  |  " + (tile.piece.data.display_name if tile.piece is Enemy else String(tile.piece.name))
	debug_label.text = text
