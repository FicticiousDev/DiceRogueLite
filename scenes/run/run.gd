extends Node3D

## Root of a run. Loads the current level of the run map, populates it, places the player and hands over to the
## turn controller. Once a level is clear its exit gates open; choosing one walks the player into it, folds the level
## away around that tile and carries the tile (player and all) to the next level's start. The run is saved as
## each level begins. A new run starts on the character select; death or clearing the final boss ends it with
## the run summary. Streaks and the odd die fall through the void behind the board (Backdrop).
## Clearing a level (shops aside) may award a die before the gates open; chests may hold one too. The pool is
## capped at RunData.max_dice: a die found with a full pool is swapped in for another or left (DieAward). Defeating
## a boss raises max health and the pool cap by one, fully heals, clears statuses and always awards a die.
## Items (EquipmentAward) come from chests, bosses and some challenge rooms (EquipmentLoot).
## Shop levels have a shop and maybe a bank (Building pieces): clicking one once the level is clear opens its menu
## (ShopMenu, BankMenu).
## Most biomes hide a Mystery piece on one of their levels (RunMap): moving onto or through it before the level is
## clear unlocks a locked loot die or item for good, celebrated by the UnlockReveal.
## Hovering a tile names it above the dice row (TileInfo). Developer commands live in the DebugMenu.

const MAIN_MENU_SCENE: String = "res://scenes/ui/main_menu/main_menu.tscn"

const PLAYER_SCENE: PackedScene = preload("res://scenes/pieces/player.tscn")
## Screen fraction kept clear for the turn plan panel
const PANEL_MARGIN: float = 0.22
const EDGE_MARGIN: float = 0.04
## A level has at most this share of ranged enemies (rounded up), and each ranged type is this much less likely to be
## drawn than a melee one
const MAX_RANGED_SHARE: float = 0.25
const RANGED_WEIGHT: float = 0.5
const LOOT_SHARE: float = 0.2
const LOOT_SHARE_PER_DEPTH: float = 0.04
const CARRY_DURATION: float = 0.9
## Pause between clearing the final boss and the run summary
const VICTORY_DELAY: float = 1.2
## Headroom above the tiles for pieces, gates and their symbols
const FRAME_HEADROOM: float = 1.8

## Most dice the pool can hold at the start of a run (RunData.max_dice)
@export var starting_max_dice: int = 5
## Chance of a new die when a normal level is cleared (bosses always give one)
@export_range(0.0, 1.0) var die_award_chance: float = 0.53
## Chance a chest also holds a die
@export_range(0.0, 1.0) var chest_die_chance: float = 0.15
## Chance a chest holds an item instead (never both)
@export_range(0.0, 1.0) var chest_item_chance: float = 0.1
## Chance a boss also drops an item
@export_range(0.0, 1.0) var boss_item_chance: float = 0.5
## Chance a challenge room's reward is an item (at the biome's rarity or higher) rather than a die
@export_range(0.0, 1.0) var challenge_item_chance: float = 0.5

@onready var camera_rig: CameraRig = $CameraRig
@onready var level_root: Node3D = $Level
@onready var hud: CanvasLayer = $HUD
@onready var exit_button: TextureButton = %ExitButton
@onready var settings_button: TextureButton = %SettingsButton
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
var _award: DieAward
var _item_award: EquipmentAward
var _unlock_reveal: UnlockReveal
var _unlock_toast: UnlockToast
var _attack_preview: AttackPreview
var _pool_view: DicePoolView
## Explains the hovered die's face after a short hover
var _die_tip_layer: CanvasLayer
var _die_tip: InfoPanel
var _die_tip_index: int = -1
var _die_tip_time: float = 0.0
var _shop_menu: ShopMenu
var _bank_menu: BankMenu
## The open gate, shop or bank under the mouse
var _hovered: BoardPiece
## Set once the run has ended (summary showing)
var _ended: bool = false
var _tile_info: TileInfo
## The board tile under the mouse, -1 for none (or while something covers the board)
var _info_tile: int = -1
var _debug: DebugMenu


func _ready() -> void:
	UITheme.watch(hud)
	exit_button.pressed.connect(_on_exit_pressed)
	settings_button.pressed.connect(Settings.show_settings)
	dice_tray.camera = camera_rig.camera
	var backdrop := Backdrop.new()
	backdrop.rig = camera_rig
	camera_rig.camera.add_child(backdrop)
	turn.state_changed.connect(_on_turn_state_changed)
	top_bar.turn = turn
	_tile_info = TileInfo.new()
	hud.add_child(_tile_info)
	_tile_info.row_y = dice_tray.row_screen_y
	_debug = DebugMenu.new()
	hud.add_child(_debug)
	_debug.command.connect(_on_debug_command)
	SaveManager.settings_data.changed.connect(_apply_layout)
	_apply_layout()
	_map_view = RunMapView.new()
	add_child(_map_view)
	_challenge = ChallengeBanner.new()
	add_child(_challenge)
	_enemy_details = EnemyDetails.new()
	add_child(_enemy_details)
	turn.enemy_inspected.connect(_enemy_details.open)
	_award = DieAward.new()
	add_child(_award)
	_item_award = EquipmentAward.new()
	add_child(_item_award)
	_unlock_reveal = UnlockReveal.new()
	add_child(_unlock_reveal)
	_unlock_toast = UnlockToast.new()
	add_child(_unlock_toast)
	_attack_preview = AttackPreview.new()
	hud.add_child(_attack_preview)
	hud.move_child(_attack_preview, 0)
	_attack_preview.anchor = action_list
	_shop_menu = ShopMenu.new()
	add_child(_shop_menu)
	_bank_menu = BankMenu.new()
	add_child(_bank_menu)
	_pool_view = DicePoolView.new()
	add_child(_pool_view)
	top_bar.pool_pressed.connect(_toggle_pool_view)
	_die_tip_layer = CanvasLayer.new()
	_die_tip_layer.layer = 34
	add_child(_die_tip_layer)
	var run := SaveManager.run_data
	if run.character_id == "" or run.dice.is_empty():
		var character_id := await character_picker.pick()
		if character_id == &"":
			SceneManager.change_scene(MAIN_MENU_SCENE)
			return
		_start_run(character_id)
	if not SaveManager.has_run():
		run.map = RunMap.generate()
		run.path = [0]
	load_level()


## Sets up a new run for [character_id]: its starting dice, pool cap and full health.
func _start_run(character_id: StringName) -> void:
	var character: CharacterData = Database.get_content("characters", character_id)
	var run := SaveManager.run_data
	run.character_id = character_id
	run.dice.assign(character.starting_dice)
	run.max_dice = starting_max_dice
	run.max_health = character.max_hp
	run.health = character.max_hp


func _exit_tree() -> void:
	SaveManager.settings_data.changed.disconnect(_apply_layout)


## Puts the turn plan (and the attack preview under it) on the chosen side, the debug menu on the other, and centres
## the board, tray, dice row and tile info in the rest of the screen.
func _apply_layout() -> void:
	var left := SaveManager.settings_data.turn_plan_side == SettingsData.SIDE_LEFT
	action_list.set_side(left)
	_debug.set_side(not left)
	var margin_left := PANEL_MARGIN if left else EDGE_MARGIN
	var margin_right := EDGE_MARGIN if left else PANEL_MARGIN
	camera_rig.frame_margins.x = margin_left
	camera_rig.frame_margins.z = margin_right
	var centre := (margin_left + 1.0 - margin_right) / 2.0
	dice_tray.tray_screen_point.x = centre
	dice_tray.row_screen_x = centre
	_tile_info.center_x = centre
	if board:
		camera_rig.frame_points(_frame_points(), false)
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
		camera_rig.frame_points(_frame_points())
	turn.clear_hint = _clear_hint(index)
	turn.setup(board, player, dice_tray, action_list, confirm_dialog, sacrifice_dialog, block_prompt, _attack_preview)
	_challenge.start(turn, 0)
	await board.play_intro(carried != null)
	var level := RunMap.level(run, index)
	if level.type == LevelData.Type.CHALLENGE:
		await _challenge.start(turn, level.turn_limit)
	_loading = false
	turn.start_turn()


## The turn plan's text once the level is clear, naming the shop / bank while they're open.
func _clear_hint(index: int) -> String:
	if RunMap.next(SaveManager.run_data, index).is_empty():
		return tr("HINT_RUN_COMPLETE")
	var shop_open := false
	var bank_open := false
	for building in board.get_buildings():
		if not building.closed:
			if building.kind == Building.Kind.SHOP:
				shop_open = true
			else:
				bank_open = true
	if shop_open and bank_open:
		return tr("HINT_CLEAR_SHOP_BANK")
	if shop_open:
		return tr("HINT_CLEAR_SHOP")
	if bank_open:
		return tr("HINT_CLEAR_BANK")
	return tr("HINT_LEVEL_CLEAR_GATES")


## What the camera fits in the free space: every tile's outline at its top, and again raised by the headroom for
## tall pieces - so the level's own shape fills the screen whatever its size.
func _frame_points() -> PackedVector3Array:
	var points := PackedVector3Array()
	for tile: HexTile in board.tiles.values():
		var top := board.to_global(board.cell_top_local(tile.coords))
		for i in 6:
			var angle := TAU * i / 6.0
			var corner := top + Vector3(sin(angle), 0.0, cos(angle)) * tile.radius
			points.append(corner)
			points.append(corner + Vector3.UP * FRAME_HEADROOM)
	return points


## Moves [carried] and the player from the old level's exit to the new level's start while the camera follows.
func _carry(carried: HexTile) -> void:
	var start := board.to_global(board.cell_to_local(board.player_start))
	var from := carried.global_position
	var lift := player.global_position - from
	camera_rig.glide(_frame_points(), CARRY_DURATION)
	var tween := create_tween()
	tween.tween_method(func(t: float):
		carried.global_position = from.lerp(start, t)
		player.global_position = carried.global_position + lift, 0.0, 1.0, Anim.t(CARRY_DURATION)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished


## Chooses which of the level's enemy and loot points are used - more the deeper the run and the harder the biome -
## puts gates on as many exit points as the level has connections, and a shop / bank on their points. Seeded by the
## map node, so a resumed level matches (the shop's stock included).
func _populate(index: int) -> void:
	var run := SaveManager.run_data
	var rng := RandomNumberGenerator.new()
	rng.seed = int(RunMap.node(run, index).seed)
	var level := RunMap.level(run, index)
	var biome := board.biome
	var depth := run.path.size() - 1

	# Enemies per level come from the biome (BiomeData.enemy_count): a normal level rolls in that range, a boss level
	# is the boss plus one fewer, a challenge level uses every enemy point (the range's top + 2)
	var enemy_cells := _shuffled(board.get_marker_cells(Board.Marker.ENEMY), rng)
	var count := rng.randi_range(biome.enemy_count.x, biome.enemy_count.y)
	if level.type == LevelData.Type.BOSS:
		_spawn_boss(biome.boss_id, enemy_cells)
		# Nothing else lives on a boss level
		enemy_cells.clear()
	if level.type == LevelData.Type.CHALLENGE:
		count = enemy_cells.size()
	var chosen := _enemy_cells_for(enemy_cells, count)
	var nearest := _nearest_to_start(chosen)
	var ranged_left := ceili(chosen.size() * MAX_RANGED_SHARE)
	for cell in chosen:
		# The enemy nearest the start is always a melee one: it walks up to the player rather than shooting from afar
		var data := _roll_enemy(biome, rng, ranged_left > 0 and cell != nearest)
		if data.attack_range > 1:
			ranged_left -= 1
		board.spawn_enemy(data, cell)

	var loot_cells := _shuffled(board.get_marker_cells(Board.Marker.LOOT), rng)
	# Chest dice are fully random each time the level is played, and kept off the level's seeded generator
	var dice_rng := RandomNumberGenerator.new()
	dice_rng.randomize()
	for cell in loot_cells.slice(0, _share_of(loot_cells.size(), LOOT_SHARE + LOOT_SHARE_PER_DEPTH * depth, true)):
		var roll := dice_rng.randf()
		var die: DieType = DiceLoot.roll(dice_rng, biome.difficulty) if roll < chest_die_chance else null
		var item: EquipmentData = EquipmentLoot.roll(dice_rng, biome.difficulty) if not die and roll < chest_die_chance + chest_item_chance else null
		board.spawn_loot(rng.randi_range(2, 4) + biome.difficulty, cell, die.id if die else &"", item.id if item else &"")

	# Gates top to bottom on screen match the next levels top to bottom on the map
	var links := RunMap.next(run, index)
	links.sort_custom(func(a: int, b: int): return float(RunMap.node(run, a).row) < float(RunMap.node(run, b).row))
	var exit_cells := _shuffled(board.get_marker_cells(Board.Marker.EXIT), rng).slice(0, links.size())
	exit_cells.sort_custom(func(a: Vector2i, b: Vector2i): return board.cell_to_local(a).z < board.cell_to_local(b).z)
	for i in exit_cells.size():
		board.spawn_exit(links[i], LevelData.ICONS[RunMap.level(run, links[i]).type], RunMap.biome(run, links[i]).color, exit_cells[i])

	# Shop rarity rises with each biome visited; a bank used on this level stays closed if it's resumed
	for cell in board.get_marker_cells(Board.Marker.SHOP):
		var shop := board.spawn_building(Building.Kind.SHOP, cell)
		shop.stock = ShopStock.roll(rng, biome.stage())
		shop.sold.resize(shop.stock.size())
	for cell in board.get_marker_cells(Board.Marker.BANK):
		var bank := board.spawn_building(Building.Kind.BANK, cell)
		if run.bank_used_at == index:
			bank.close(false)

	# The Mystery piece, from its own generator so the rest stays as it was
	if RunMap.has_unlock(run, index) and not SaveManager.progression_data.locked_content().is_empty():
		var mystery_rng := RandomNumberGenerator.new()
		mystery_rng.seed = rng.seed + 1
		var cells := _mystery_cells(Hex.id(board.player_start))
		if cells.size() > 0:
			board.spawn_mystery(cells[mystery_rng.randi() % cells.size()])


## The first [count] of the shuffled enemy [cells], with the point nearest the player's start swapped in if the draw
## missed it, so there is always a fight within reach on the first turn.
func _enemy_cells_for(cells: Array[Vector2i], count: int) -> Array[Vector2i]:
	var chosen: Array[Vector2i] = []
	chosen.assign(cells.slice(0, count))
	if chosen.is_empty() or chosen.size() == cells.size():
		return chosen
	var nearest := _nearest_to_start(cells)
	if not chosen.has(nearest):
		chosen[chosen.size() - 1] = nearest
	return chosen


## The cell in [cells] closest to the player's start (the first of them on a tie).
func _nearest_to_start(cells: Array[Vector2i]) -> Vector2i:
	var nearest := cells[0] if cells.size() > 0 else board.player_start
	for cell in cells:
		if Hex.distance(cell, board.player_start) < Hex.distance(nearest, board.player_start):
			nearest = cell
	return nearest


## One of the biome's regular enemies. Ranged types are [constant RANGED_WEIGHT] as likely as melee ones, and left out
## altogether if [ranged_allowed] is false.
func _roll_enemy(biome: BiomeData, rng: RandomNumberGenerator, ranged_allowed: bool) -> EnemyData:
	var pool: Array[EnemyData] = []
	var weights: Array[float] = []
	var total := 0.0
	for id in biome.enemy_ids:
		var data: EnemyData = Database.get_content("enemies", id)
		var ranged := data.attack_range > 1
		if ranged and not ranged_allowed:
			continue
		pool.append(data)
		weights.append(RANGED_WEIGHT if ranged else 1.0)
		total += weights[-1]
	var roll := rng.randf() * total
	for i in pool.size():
		roll -= weights[i]
		if roll < 0.0:
			return pool[i]
	return pool[-1]


## The biome's boss on the enemy point farthest from the start, with its starting minions on the next points.
func _spawn_boss(boss_id: StringName, cells: Array[Vector2i]) -> void:
	if cells.is_empty():
		return
	cells.sort_custom(func(a: Vector2i, b: Vector2i): return Hex.distance(a, board.player_start) > Hex.distance(b, board.player_start))
	var data: EnemyData = Database.get_content("enemies", boss_id)
	var boss := board.spawn_enemy(data, cells.pop_front())
	for cell in cells.slice(0, data.starting_minions):
		board.spawn_enemy(data.minion, cell).master = boss
	if data.behaviour:
		data.behaviour.setup(boss, board)


## Where a Mystery piece can go: free tiles the player can walk to, on the board's edge, at least half the board's
## reach (the farthest tile from the start) away from the player. Failing that, tiles next to the edge, then the
## farthest free tiles. [from] is the player's tile.
func _mystery_cells(from: int) -> Array[Vector2i]:
	# Reachable on foot: enemies move, so only obstacles and other fixed pieces block
	var reachable: Dictionary[int, int] = { from: 0 }
	var frontier: Array[int] = [from]
	while frontier.size() > 0:
		var current: int = frontier.pop_front()
		for next in board.get_neighbours(current):
			var piece := board.get_piece(next)
			if reachable.has(next) or not board.is_walkable(next) or (piece and piece.blocks_movement and not (piece is Enemy)):
				continue
			reachable[next] = reachable[current] + 1
			frontier.append(next)
	var start := Hex.coords(from)
	var reach := 0
	for tile_id in board.tiles:
		reach = maxi(reach, Hex.distance(start, Hex.coords(tile_id)))
	var looted: Array[int] = []
	for piece in board.pieces_root.get_children():
		if piece is Loot or piece is Mystery:
			looted.append(piece.tile_id)
	var free: Array[int] = []
	for tile_id in reachable:
		if tile_id != from and board.get_piece(tile_id) == null and not looted.has(tile_id):
			free.append(tile_id)

	var edge := func(tile_id: int) -> bool: return board.get_neighbours(tile_id).size() < 6
	var near_edge := func(tile_id: int) -> bool: return edge.call(tile_id) or board.get_neighbours(tile_id).any(edge)
	var far := func(tile_id: int) -> bool: return Hex.distance(start, Hex.coords(tile_id)) * 2 >= reach
	var result: Array[Vector2i] = []
	for test: Callable in [edge, near_edge]:
		for tile_id in free:
			if test.call(tile_id) and far.call(tile_id):
				result.append(Hex.coords(tile_id))
		if result.size() > 0:
			return result
	var farthest := 0
	for tile_id in free:
		farthest = maxi(farthest, Hex.distance(start, Hex.coords(tile_id)))
	for tile_id in free:
		if Hex.distance(start, Hex.coords(tile_id)) == farthest:
			result.append(Hex.coords(tile_id))
	return result


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


## Takes any chest or Mystery piece on the player's new tile. A die or item in the chest is awarded straight away, and
## a Mystery piece's unlock revealed, with the game paused mid-move.
func _on_player_moved(_from_id: int, to_id: int) -> void:
	var contents := board.collect_loot(to_id)
	var gold: int = contents.get("gold", 0)
	if gold > 0:
		SaveManager.run_data.add_gold(gold)
		player.popup("+%d" % gold, Color(1, 0.82, 0.3))
	var die_id: StringName = contents.get("die", &"")
	var item_id: StringName = contents.get("item", &"")
	var mystery := board.collect_mystery(to_id)
	if die_id != &"" or item_id != &"" or mystery:
		get_tree().paused = true
		if die_id != &"":
			await _award.present(Database.get_content("dice", die_id), tr("REWARD_FOUND_IN_CHEST"), SaveManager.run_data.max_dice)
		if item_id != &"":
			await _item_award.present(Database.get_content("equipment", item_id), tr("REWARD_FOUND_IN_CHEST"))
		if mystery:
			await _unlock()
		get_tree().paused = false


## Unlocks a random locked die or item for good and reveals it. Saved straight away, with the level marked in both
## the run and its checkpoint, so resuming the level doesn't bring the piece back.
func _unlock() -> void:
	var progression := SaveManager.progression_data
	var locked := progression.locked_content()
	if locked.is_empty():
		return
	var content: Resource = locked.pick_random()
	progression.unlock(content)
	var index := RunMap.current_index(SaveManager.run_data)
	for run: RunData in [SaveManager.run_data, SaveManager.run_checkpoint]:
		if run:
			run.map[index]["unlock"] = false
	SaveManager.save_data()
	await _unlock_reveal.present(content)


## Rewards for clearing the current level, all fully random (replaying a level can give different ones):
## - normal levels: [member die_award_chance] of a die, rarity by the biome (DiceLoot)
## - bosses: always a die, from the better rarity table (as a challenge gives), and [member boss_item_chance] of an item at
##   the biome's rarity or higher. The boss bonus (_boss_bonus) comes first, so the die has a free slot
## - a challenge beaten within its turn limit: always a reward - an item at the biome's rarity or higher
##   ([member challenge_item_chance]) or else a die from the better rarity table. Over the limit, nothing
## - shops: nothing
func _level_award() -> void:
	var run := SaveManager.run_data
	var index := RunMap.current_index(run)
	var level := RunMap.level(run, index)
	var difficulty := RunMap.biome(run, index).difficulty
	if level.type in [LevelData.Type.SHOP, LevelData.Type.SHOP_BANK]:
		return
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	if level.type == LevelData.Type.CHALLENGE:
		if turn.turn_number > level.turn_limit:
			return
		var item := EquipmentLoot.roll(rng, difficulty, true) if rng.randf() < challenge_item_chance else null
		if item:
			await _item_award.present(item, tr("REWARD_CHALLENGE"))
			return
		var top := DiceLoot.roll(rng, difficulty, true)
		if top:
			await _award.present(top, tr("REWARD_CHALLENGE"), SaveManager.run_data.max_dice)
		return
	var boss := level.type == LevelData.Type.BOSS
	if boss or rng.randf() < die_award_chance:
		var die := DiceLoot.roll(rng, difficulty, boss)
		if die:
			await _award.present(die, tr("REWARD_BOSS") if boss else tr("REWARD_LEVEL_CLEAR"), SaveManager.run_data.max_dice)
	if boss and rng.randf() < boss_item_chance:
		var drop := EquipmentLoot.roll(rng, difficulty, true)
		if drop:
			await _item_award.present(drop, tr("REWARD_BOSS"))


func _toggle_pool_view() -> void:
	if not _award.visible and not _item_award.visible and not _unlock_reveal.visible and not character_picker.visible and not _menu_open():
		_pool_view.toggle()


func _menu_open() -> bool:
	return _shop_menu.visible or _bank_menu.visible


# ===========================================================================================================================================
# Exits, shops & banks
# ===========================================================================================================================================


## Highlights the open gate, shop or bank under the mouse once the level is clear.
func _update_hover() -> void:
	var hovered: BoardPiece = null
	if turn.state == TurnController.State.LEVEL_CLEAR and not _loading and not _map_view.visible:
		var piece := board.get_piece(board.tile_at_screen(camera_rig.camera, get_viewport().get_mouse_position()))
		if (piece is ExitGate and piece.unlocked) or (piece is Building and not piece.closed):
			hovered = piece
	if hovered != _hovered:
		if is_instance_valid(_hovered):
			_hovered.set_hovered(false)
		_hovered = hovered
		if hovered:
			hovered.set_hovered(true)


func _choose_exit(exit: ExitGate) -> void:
	var run := SaveManager.run_data
	var biome := RunMap.biome(run, exit.target)
	var type := RunMap.level(run, exit.target).type
	_loading = true
	if not await confirm_dialog.ask(tr("DIALOG_TRAVEL_TITLE"), tr("DIALOG_TRAVEL_MESSAGE") % [biome.display_name, tr(LevelData.NAMES[type])]):
		_loading = false
		return
	var target := exit.target
	var tile_id := exit.tile_id
	exit.set_hovered(false)
	_hovered = null
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


## Opens the building's menu; the board waits until it's closed.
func _use_building(building: Building) -> void:
	_loading = true
	building.set_hovered(false)
	_hovered = null
	if building.kind == Building.Kind.SHOP:
		await _shop(building)
	else:
		await _bank(building)
	_loading = false


## The shop menu until the player closes it. Buying shows the die or item as an award (with the swap / replace when
## the pool or slots are full); the price is only paid if it's taken, and it's sold out after.
func _shop(shop: Building) -> void:
	var run := SaveManager.run_data
	while true:
		var index := await _shop_menu.choose(shop.stock, shop.sold)
		if index == -1:
			return
		var offer := shop.stock[index]
		var price := ShopStock.price(offer)
		var source := tr("SHOP_SOURCE_PRICE") % price
		var taken: bool
		if offer is DieType:
			taken = await _award.present(offer, source, SaveManager.run_data.max_dice)
		else:
			taken = await _item_award.present(offer, source)
		if taken:
			run.spend_gold(price)
			shop.sold[index] = true
			player.popup("-%d" % price, Color(1, 0.82, 0.3))


## One deposit or withdrawal, then the bank closes. Banked gold lives in the progression, which is saved straight
## away - so the level's checkpoint takes the same change, or quitting and resuming the level would bank it twice.
func _bank(bank: Building) -> void:
	var amount := await _bank_menu.choose()
	if amount == 0:
		return
	var index := RunMap.current_index(SaveManager.run_data)
	for run: RunData in [SaveManager.run_data, SaveManager.run_checkpoint]:
		if run:
			run.gold = maxi(run.gold - amount, 0)
			run.bank_used_at = index
	SaveManager.progression_data.gold_in_bank += amount
	SaveManager.save_data()
	bank.close()
	turn.clear_hint = _clear_hint(index)
	turn._refresh()
	bank.popup(tr("POPUP_BANKED") % amount if amount > 0 else "+%d" % -amount, Color(1, 0.82, 0.3))


func _process(delta: float) -> void:
	if not board:
		return
	_update_hover()
	_update_die_tip(delta)
	if _grid_overlay:
		_grid_overlay.show_pick(turn.hovered_tile, board.last_pick_point)
	_update_tile_info()
	_update_debug_menu()
	_check_challenges()


## Unlocks (and announces) the reward of any challenge the run in progress has just completed. Saved straight away: an
## unlock is for good, even if the level is later resumed from its checkpoint.
func _check_challenges() -> void:
	var run := SaveManager.run_data
	if not run.progress_changed or _ended:
		return
	run.progress_changed = false
	var earned := SaveManager.progression_data.complete_challenges(run)
	if earned.size() > 0:
		SaveManager.save_data()
		_unlock_toast.announce(earned)


## True while a screen over the board takes the input.
func _overlay_open() -> bool:
	return _enemy_details.visible or _ended or _award.visible or _item_award.visible or _unlock_reveal.visible or _menu_open()


func _unhandled_input(event: InputEvent) -> void:
	if _overlay_open():
		return
	if event.is_action_pressed("dice_pool"):
		_toggle_pool_view()
	elif _pool_view.visible:
		return
	elif event.is_action_pressed("map") and not character_picker.visible:
		_map_view.toggle()
	elif _map_view.visible:
		return
	elif event.is_action_pressed("select") and _hovered is ExitGate:
		_choose_exit(_hovered)
	elif event.is_action_pressed("select") and _hovered is Building:
		_use_building(_hovered)
	elif event.is_action_pressed("debug_menu"):
		_debug.toggle()
	elif _debug.command_for(event) != -1:
		_on_debug_command(_debug.command_for(event))


func _on_turn_state_changed(state: TurnController.State) -> void:
	if state == TurnController.State.GAME_OVER:
		_end_run(ProgressionData.Outcome.DEFEAT)
	elif state == TurnController.State.LEVEL_CLEAR:
		var run := SaveManager.run_data
		run.levels_cleared += 1
		if RunMap.next(run, RunMap.current_index(run)).is_empty():
			_end_run(ProgressionData.Outcome.VICTORY)
			return
		# Chests left behind are lost, and the gates stay shut until the award is dealt with
		_loading = true
		await board.clear_loot()
		if RunMap.level(run, RunMap.current_index(run)).type == LevelData.Type.BOSS:
			await _boss_bonus()
		await _level_award()
		_loading = false
		for exit in board.get_exits():
			exit.unlock()


## Defeating a boss (the final one aside - the run ends): +1 max health and a full heal, statuses cleared, and one
## more die slot.
func _boss_bonus() -> void:
	var run := SaveManager.run_data
	run.max_health += 1
	run.health = run.max_health
	run.max_dice += 1
	player.poisoned = false
	player.stunned = false
	player.frozen_next = false
	player.burn = 0
	player.popup(tr("POPUP_LEVEL_UP"), Color(0.5, 1.0, 0.4))
	await get_tree().create_timer(Anim.t(0.8)).timeout


## Ends the run (stats into the progression, save cleared) and shows the summary over the board.
func _end_run(outcome: ProgressionData.Outcome) -> void:
	_ended = true
	if _map_view.visible:
		_map_view.toggle()
	if outcome == ProgressionData.Outcome.VICTORY:
		await get_tree().create_timer(Anim.t(VICTORY_DELAY)).timeout
	var finished := SaveManager.end_run(outcome)
	# Challenges only the run's end can complete (winning a run, say)
	var earned := SaveManager.progression_data.complete_challenges()
	if earned.size() > 0:
		SaveManager.save_data()
	hud.visible = false
	_challenge.visible = false
	game_over.show_screen(finished, outcome, earned)


func _on_exit_pressed() -> void:
	if await confirm_dialog.ask(tr("DIALOG_MAIN_MENU_TITLE"), tr("DIALOG_MAIN_MENU_MESSAGE")):
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
		var title := "%s  ·  %s" % [result.die_type.display_name, Rarity.display_name(result.die_type.rarity)]
		_die_tip = InfoPanel.create(title, HelpText.face_rows(result.display_face()), 340.0, 24)
		_die_tip_layer.add_child(_die_tip)
	if _die_tip:
		# Above and to the right of the mouse, kept on screen
		var mouse := get_viewport().get_mouse_position()
		var screen := get_viewport().get_visible_rect().size
		var at := mouse + Vector2(24, -_die_tip.size.y - 16)
		_die_tip.position = at.clamp(Vector2.ZERO, screen - _die_tip.size)


## Names the tile under the mouse above the dice row - not while the mouse is over a die or a panel, or something
## covers the board.
func _update_tile_info() -> void:
	_info_tile = -1
	if not (_loading or _overlay_open() or _map_view.visible or _pool_view.visible or character_picker.visible or dice_tray.rolling):
		var mouse := get_viewport().get_mouse_position()
		if get_viewport().gui_get_hovered_control() == null and dice_tray.get_die_at(mouse) == -1:
			_info_tile = board.tile_at_screen(camera_rig.camera, mouse)
	if board.has_tile(_info_tile):
		_tile_info.show_tile(board, _info_tile)
	else:
		_tile_info.clear()


# ===========================================================================================================================================
# Debug
# ===========================================================================================================================================


func _on_debug_command(id: DebugMenu.Command) -> void:
	if _overlay_open() or _map_view.visible or _pool_view.visible:
		return
	match id:
		DebugMenu.Command.REROLL:
			if _can_debug():
				turn.debug_pool.clear()
				turn.start_turn(false)
		DebugMenu.Command.SHOWCASE:
			if _can_debug():
				_debug_showcase()
		DebugMenu.Command.RESTART:
			if _can_debug(true):
				SaveManager.run_data.health = SaveManager.run_data.max_health
				load_level()
		DebugMenu.Command.SHOP_HERE:
			if _can_debug(true):
				_debug_shop()
		DebugMenu.Command.BOSS:
			if _can_debug(true):
				_debug_boss()
		DebugMenu.Command.NEXT_SHOP:
			if _can_force_next():
				_debug_next_shop(LevelData.Type.SHOP)
		DebugMenu.Command.NEXT_SHOP_BANK:
			if _can_force_next():
				_debug_next_shop(LevelData.Type.SHOP_BANK)
		DebugMenu.Command.MYSTERY:
			if _can_debug():
				_debug_mystery()
		DebugMenu.Command.LINE_OF_SIGHT:
			turn.show_los = not turn.show_los
			turn._refresh()
		DebugMenu.Command.GRID:
			_toggle_grid_overlay()


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


## Turns the current level into the Shop & Bank (for good, in this run's map) with 100 extra gold, and restarts it.
func _debug_shop() -> void:
	var run := SaveManager.run_data
	var node := RunMap.node(run, RunMap.current_index(run))
	node.level = "shop_bank_01"
	node.type = LevelData.Type.SHOP_BANK
	run.gold += 100
	load_level()


## Turns the current level into a biome's boss level - the next biome's each press, in run order, starting with the
## current biome's - for good in this run's map and its checkpoint, and restarts it at full health. The level's exits
## may not match the boss level's, so it's only for trying a fight out.
func _debug_boss() -> void:
	var run := SaveManager.run_data
	var index := RunMap.current_index(run)
	var biomes := Database.get_all("biomes")
	biomes.sort_custom(func(a: BiomeData, b: BiomeData): return a.order < b.order)
	var at := biomes.find_custom(func(b: BiomeData): return b.id == RunMap.biome(run, index).id)
	if RunMap.level(run, index).type == LevelData.Type.BOSS:
		at += 1
	var biome: BiomeData = biomes[at % biomes.size()]
	for data: RunData in [run, SaveManager.run_checkpoint]:
		if data:
			RunMap.node(data, index).biome = String(biome.id)
			RunMap.node(data, index).level = String(biome.boss_level)
	run.health = run.max_health
	load_level()
	player.popup(tr("POPUP_NEXT_BOSS") % biome.display_name, Color(1.0, 0.45, 0.85))


func _can_force_next() -> bool:
	return not _loading and not RunMap.next(SaveManager.run_data, RunMap.current_index(SaveManager.run_data)).is_empty()


## Turns every level the current one leads to into a level of [type] (Shop or Shop & Bank), for good in this run's map
## and its checkpoint (so it survives quitting), and changes the gates' symbols to match.
func _debug_next_shop(type: LevelData.Type) -> void:
	var levels := Database.get_all("levels").filter(func(level: LevelData): return level.type == type)
	var index := RunMap.current_index(SaveManager.run_data)
	for target in RunMap.next(SaveManager.run_data, index):
		var level_id := String(levels.pick_random().id)
		for run: RunData in [SaveManager.run_data, SaveManager.run_checkpoint]:
			if run:
				RunMap.node(run, target).level = level_id
	for exit in board.get_exits():
		exit.set_icon(LevelData.ICONS[type])
	player.popup(tr("POPUP_NEXT_LEVEL") % tr(LevelData.NAMES[type]), Color(1.0, 0.45, 0.85))


## Puts a Mystery piece on this level now (where one would go), if anything is still locked and there isn't one already.
func _debug_mystery() -> void:
	var exists := board.pieces_root.get_children().any(func(piece: Node): return piece is Mystery)
	var cells := _mystery_cells(player.tile_id)
	if exists or cells.is_empty() or SaveManager.progression_data.locked_content().is_empty():
		player.popup("Nothing to unlock" if not exists else "Already here", Color(0.8, 0.8, 0.85))
		return
	board.spawn_mystery(cells.pick_random()).play_intro()


func _toggle_grid_overlay() -> void:
	if _grid_overlay:
		_grid_overlay.queue_free()
		_grid_overlay = null
	else:
		_grid_overlay = GridOverlay.new()
		board.add_child(_grid_overlay)
		_grid_overlay.setup(board)


## Keeps the open debug menu's buttons, toggles and readout (rolled dice, hovered cell and path cost) current.
func _update_debug_menu() -> void:
	if not _debug.is_open():
		return
	var plan := _can_debug()
	var plan_or_clear := _can_debug(true)
	var next := _can_force_next()
	_debug.set_enabled(DebugMenu.Command.REROLL, plan)
	_debug.set_enabled(DebugMenu.Command.SHOWCASE, plan)
	_debug.set_enabled(DebugMenu.Command.RESTART, plan_or_clear)
	_debug.set_enabled(DebugMenu.Command.SHOP_HERE, plan_or_clear)
	_debug.set_enabled(DebugMenu.Command.BOSS, plan_or_clear)
	_debug.set_enabled(DebugMenu.Command.NEXT_SHOP, next)
	_debug.set_enabled(DebugMenu.Command.NEXT_SHOP_BANK, next)
	_debug.set_enabled(DebugMenu.Command.MYSTERY, plan)
	_debug.set_toggled(DebugMenu.Command.LINE_OF_SIGHT, turn.show_los)
	_debug.set_toggled(DebugMenu.Command.GRID, _grid_overlay != null)
	var lines := PackedStringArray()
	if turn.results.size() > 0:
		lines.append("Rolled: " + ", ".join(turn.results.map(func(r: DieResult): return r.describe())))
	if board.has_tile(_info_tile):
		var line := "Cell %s" % board.get_tile(_info_tile).coords
		if turn._move_ctx and turn._move_ctx.costs.has(_info_tile):
			line += "  |  path cost %d" % turn._move_ctx.costs[_info_tile]
		lines.append(line)
	_debug.set_info("\n".join(lines))
