class_name TurnController
extends Node

## Runs the turn: roll the pool, apply buffs, plan a sequence of actions (move, attack, defend), commit,
## resolve, then the enemy turn (enemies move and attack; held defence dice block). Planning works on a TurnState simulated from the start of the turn through the planned actions,
## rebuilt whenever the plan changes; actions that become invalid are dropped.

signal state_changed(state: State)
signal _block_confirmed

enum State { IDLE, ROLL, PLAN, RESOLVE, ENEMY_TURN, LEVEL_CLEAR, GAME_OVER }

const PATH_DOT_SPACING: float = 0.22
const ARROW_LENGTH: float = 0.55
## Row dice raise this far (tray units) when selected / hovered
const SELECTED_LIFT: float = 0.45
const HOVER_LIFT: float = 0.15

var state: State = State.IDLE
var turn_number: int = 0
var board: Board
var player: Player
var dice_tray: DiceTray
var action_list: ActionList
var confirm_dialog: ConfirmDialog
var sacrifice_dialog: SacrificeDialog
var block_prompt: BlockPrompt

var results: Array[DieResult] = []
var actions: Array[PlannedAction] = []
## Pool indices currently selected for the next action
var selected: Array[int] = []
var hovered_tile: int = -1
var hovered_die: int = -1
## Debug: show line of sight from the planned position
var show_los: bool = false
## Debug: if set, the next roll uses these dice instead of the run's pool
var debug_pool: Array[DieType] = []
var debug_design: DieDesign

## Buff dice spent automatically when the row formed
var _auto_used: Array[int] = []
## Plan simulated up to the insertion point (end of the list, or the action being edited)
var _insert_state: TurnState
var _end_state: TurnState
var _move_ctx: MoveContext
var _reachable: Array[int] = []
## Enemy tiles the selected attack/defence dice can target
var _targets: Array[int] = []
## Resolution: defence assigned against each enemy, damage taken this turn
var _defence: Dictionary[Enemy, int] = {}
var _damage_taken: int = 0
## Resolution: enemy whose retaliation lands once the defend actions following its attack are done
var _retaliating: Enemy
## Resolution: enemies that struck back this turn - they move in the enemy turn but don't attack
var _retaliated: Array[Enemy] = []
## Held defence dice spent blocking enemy-turn attacks
var _spent: Array[int] = []
## Enemy turn: the enemy whose attack the player is choosing held defence dice for, and the dice chosen
var _blocking: Enemy
var _blocking_damage: int = 0
var _block_selected: Array[int] = []
## Enemy turn: one turn plan entry per enemy attack, as [line, note]
var _enemy_log: Array[Array] = []
var _editing: PlannedAction
var _edit_index: int = -1
var _ghost: Cutout
var _path_dots: Node3D


func setup(run_board: Board, run_player: Player, tray: DiceTray, list: ActionList, dialog: ConfirmDialog, last_stand: SacrificeDialog, prompt: BlockPrompt) -> void:
	board = run_board
	player = run_player
	dice_tray = tray
	action_list = list
	confirm_dialog = dialog
	sacrifice_dialog = last_stand
	block_prompt = prompt
	if not block_prompt.block_pressed.is_connected(_block_confirmed.emit):
		block_prompt.block_pressed.connect(_block_confirmed.emit)
		block_prompt.take_pressed.connect(_take_hit)
	if not action_list.commit_pressed.is_connected(commit):
		action_list.commit_pressed.connect(commit)
		action_list.rewind_requested.connect(rewind_to)
		action_list.edit_requested.connect(edit)
		action_list.delete_requested.connect(delete)
	_create_previews()


## Rolls the pool and starts planning. [new_turn] false re-rolls the current turn (debug).
func start_turn(new_turn: bool = true) -> void:
	if new_turn:
		turn_number += 1
	results.clear()
	_end_state = null
	actions.clear()
	selected.clear()
	_auto_used.clear()
	_spent.clear()
	_enemy_log.clear()
	_editing = null
	_set_state(State.ROLL)
	_refresh()
	results = await dice_tray.roll(_pool(), _design())
	await _apply_buffs()
	_set_state(State.PLAN)
	_replan()


## Sum of the values of [dice] (pool indices), including buffs.
func dice_value(dice: Array[int]) -> int:
	var total := 0
	for i in dice:
		total += results[i].value()
	return total


## Movement search for [dice] from the simulated [sim] state; a teleport only if every die has the teleport symbol.
func move_context(sim: TurnState, dice: Array[int]) -> MoveContext:
	var ctx := MoveContext.new(sim.player_tile, dice_value(dice), board.move_cost, player)
	ctx.teleport = dice.size() > 0 and dice.all(_has_teleport)
	ctx.ignored = sim.dead_enemies()
	return ctx


## The player's attack on [enemy] with [dice]. Crit/insta-kill symbols are applied in Phase 08.
func player_attack_context(enemy: Enemy, dice: Array[int]) -> AttackContext:
	return AttackContext.new(player, enemy, dice_value(dice), enemy.data.defence)


## True if teleport dice are combined with normal movement dice, losing the teleport.
func is_teleport_lost(dice: Array[int]) -> bool:
	return dice.any(_has_teleport) and not dice.all(_has_teleport)


func _has_teleport(index: int) -> bool:
	return results[index].face().has(Symbol.Type.TELEPORT)


func is_die_available(index: int) -> bool:
	return not _end_state.used_dice.has(index) and not _auto_used.has(index) and not _spent.has(index)


# ===========================================================================================================================================
# Input
# ===========================================================================================================================================


func _process(_delta: float) -> void:
	if not board or not (state == State.PLAN or _blocking):
		return
	var mouse := board.get_viewport().get_mouse_position()
	var die := dice_tray.get_die_at(mouse)
	var tile := -1 if die != -1 or _blocking else board.tile_at_screen(dice_tray.camera, mouse)
	if die != hovered_die or tile != hovered_tile:
		hovered_die = die
		hovered_tile = tile
		_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if _blocking:
		if event.is_action_pressed("select") and hovered_die != -1:
			_click_block_die(hovered_die)
		return
	if state != State.PLAN:
		return
	if event.is_action_pressed("select"):
		if hovered_die != -1:
			_click_die(hovered_die)
		elif hovered_tile != -1:
			_click_tile(hovered_tile)
	elif event.is_action_pressed("cancel") and (selected.size() > 0 or _editing):
		get_viewport().set_input_as_handled()
		_cancel()


func _click_die(index: int) -> void:
	var die := dice_tray.get_die(index)
	var result := results[index]
	if not is_die_available(index):
		die.shake(dice_tray.camera.global_basis.x * 0.1 * dice_tray._scale)
		return
	if selected.has(index):
		selected.erase(index)
	else:
		# Only dice of one kind combine into an action; picking another kind starts a new selection.
		# Special faces (insta-kill, block all) become usable in Phase 08.
		if not result.face().is_numeric():
			die.shake(dice_tray.camera.global_basis.x * 0.1 * dice_tray._scale)
			return
		if selected.size() > 0 and results[selected[0]].category() != result.category():
			selected.clear()
		selected.append(index)
	_replan()


func _click_tile(tile_id: int) -> void:
	if selected.is_empty():
		return
	var action: PlannedAction
	match _selected_category():
		DieFace.Category.MOVE:
			if _reachable.has(tile_id):
				action = MoveAction.new(selected, tile_id)
		DieFace.Category.ATTACK:
			if _targets.has(tile_id):
				action = AttackAction.new(selected, board.get_piece(tile_id))
		DieFace.Category.DEFENCE:
			if _targets.has(tile_id):
				action = DefendAction.new(selected, board.get_piece(tile_id))
	if action == null:
		return
	selected.clear()
	if _editing:
		actions.insert(_edit_index, action)
		_editing = null
	else:
		actions.append(action)
	_replan()


func _cancel() -> void:
	selected.clear()
	if _editing:
		actions.insert(_edit_index, _editing)
		_editing = null
	_replan()


# ===========================================================================================================================================
# Action list
# ===========================================================================================================================================


## Keeps actions up to and including [index].
func rewind_to(index: int) -> void:
	if state != State.PLAN:
		return
	_finish_edit()
	actions.resize(index + 1)
	selected.clear()
	_replan()


## Takes the action out and re-selects its dice; picking a target puts it back in the same slot.
func edit(index: int) -> void:
	if state != State.PLAN:
		return
	_finish_edit()
	_edit_index = index
	_editing = actions[index]
	actions.remove_at(index)
	selected = _editing.dice.duplicate()
	_replan()


func delete(index: int) -> void:
	if state != State.PLAN:
		return
	_finish_edit()
	actions.remove_at(index)
	selected.clear()
	_replan()


## Restores an edit in progress before another list operation.
func _finish_edit() -> void:
	if _editing:
		actions.insert(_edit_index, _editing)
		_editing = null


# ===========================================================================================================================================
# Commit & resolve
# ===========================================================================================================================================


func commit() -> void:
	if state != State.PLAN:
		return
	_finish_edit()
	selected.clear()
	_replan()
	if SaveManager.settings_data.confirm_unused_dice and _unused_non_defence() > 0:
		var count := _unused_non_defence()
		if not await confirm_dialog.ask("UNUSED DICE", "%d %s will be discarded.\nCommit anyway?" % [count, "die" if count == 1 else "dice"]):
			return
	await _resolve()


func _unused_non_defence() -> int:
	var count := 0
	for result in results:
		if is_die_available(result.index) and result.category() != DieFace.Category.DEFENCE:
			count += 1
	return count


func _resolve() -> void:
	_set_state(State.RESOLVE)
	_refresh()
	_defence.clear()
	_damage_taken = 0
	_retaliating = null
	_retaliated.clear()
	for action in actions:
		if not _is_defending_retaliation(action, _retaliating):
			await _settle_retaliation()
			if _player_dead():
				await _game_over()
				return
		await action.resolve(self)
		if _player_dead():
			await _game_over()
			return
	await _settle_retaliation()
	if _player_dead():
		await _game_over()
		return
	if board.get_enemies().is_empty():
		await dice_tray.clear()
		_set_state(State.LEVEL_CLEAR)
		_refresh()
		return
	# Unused defence dice are held for the enemy turn; everything else is discarded
	var discarded: Array[int] = []
	for result in results:
		if not _held_dice().has(result.index):
			discarded.append(result.index)
	await dice_tray.discard(discarded)
	_set_state(State.ENEMY_TURN)
	_refresh()
	await _enemy_turn()
	if _player_dead():
		await _game_over()
		return
	await dice_tray.clear()
	var run := SaveManager.run_data
	if _damage_taken == 0 and run.health < run.max_health:
		run.health += 1
		player.popup("+1", Color(0.4, 1.0, 0.45))
		await get_tree().create_timer(Anim.t(0.4)).timeout
	start_turn()


func _player_dead() -> bool:
	return SaveManager.run_data.health <= 0


func _game_over() -> void:
	await dice_tray.clear()
	_set_state(State.GAME_OVER)
	_refresh()


## True if [action] defends against [enemy]'s pending retaliation, so it lands after the action.
func _is_defending_retaliation(action: PlannedAction, enemy: Enemy) -> bool:
	return enemy != null and action is DefendAction and action.defends_against(enemy)


func _settle_retaliation() -> void:
	if _retaliating == null:
		return
	var enemy := _retaliating
	_retaliating = null
	if is_instance_valid(enemy) and not enemy.is_dead():
		if await enemy_attack(enemy):
			_retaliated.append(enemy)


## Player attacks [enemy]; it strikes first if it always attacks first, otherwise retaliates if it survives
## (after any defend actions against it that directly follow).
func resolve_attack(enemy: Enemy, dice: Array[int]) -> void:
	if not is_instance_valid(enemy) or enemy.is_dead():
		return
	if enemy.data.attacks_first:
		if await enemy_attack(enemy):
			_retaliated.append(enemy)
		if _player_dead():
			return
	await player.lunge(enemy.position)
	enemy.take_damage(player_attack_context(enemy, dice).damage())
	if enemy.is_dead():
		SaveManager.run_data.gold += enemy.data.gold
		SaveManager.progression_data.enemies_defeated += 1
		player.popup("+%d gold" % enemy.data.gold, Color(1.0, 0.85, 0.3))
		await enemy.play_death()
	elif not enemy.data.attacks_first:
		_retaliating = enemy
	await get_tree().create_timer(Anim.t(0.25)).timeout


## Adds defence against [enemy]'s next attack.
func resolve_defend(enemy: Enemy, amount: int) -> void:
	if not is_instance_valid(enemy) or enemy.is_dead():
		return
	_defence[enemy] = _defence.get(enemy, 0) + amount
	enemy.popup("+%d defence" % amount, Color(0.45, 0.7, 1.0))
	await get_tree().create_timer(Anim.t(0.3)).timeout


## [enemy] attacks the player if it can hit them, using up any defence assigned against it. With [can_block]
## (enemy turn) the roll is shown in the turn plan first and the player may add held defence dice.
## Returns true if it attacked.
func enemy_attack(enemy: Enemy, can_block: bool = false) -> bool:
	if not enemy.can_hit(player.tile_id):
		return false
	var assigned: int = _defence.get(enemy, 0)
	_defence.erase(enemy)
	var ctx := AttackContext.roll_enemy(enemy, player, assigned)
	var log_index := -1
	if can_block:
		log_index = _enemy_log.size()
		_enemy_log.append(["", ""])
		if not ctx.miss and ctx.damage() > 0:
			ctx.defence += await _choose_block(enemy, ctx.damage(), log_index)
	var damage := ctx.damage()
	if log_index != -1:
		_enemy_log[log_index] = _attack_log(enemy, ctx)
		_refresh()
	await enemy.lunge(player.position)
	if ctx.miss:
		player.popup("MISS", Color(0.8, 0.8, 0.8))
	elif damage == 0:
		player.popup("BLOCKED", Color(0.45, 0.7, 1.0))
	elif damage >= SaveManager.run_data.health and await _last_stand():
		player.popup("SACRIFICED", Color(1.0, 0.6, 0.3))
		# Still counts as a hit for the end-of-turn heal
		_damage_taken += damage
	else:
		player.hurt()
		player.popup(("CRIT -%d" if ctx.crit else "-%d") % damage, Color(1, 0.3, 0.25))
		var run := SaveManager.run_data
		run.health = maxi(run.health - damage, 0)
		_damage_taken += damage
		SaveManager.progression_data.damage_received += damage
	await get_tree().create_timer(Anim.t(0.35)).timeout
	return true


## Turn plan entry for a resolved enemy attack.
func _attack_log(enemy: Enemy, ctx: AttackContext) -> Array:
	var name := enemy.data.display_name
	if ctx.miss:
		return ["%s missed you" % name, ""]
	var rolled := ctx.base_damage * (2 if ctx.crit else 1)
	var line := "%s %shit you for %d" % [name, "critically " if ctx.crit else "", rolled]
	if ctx.defence <= 0:
		return [line, ""]
	return [line, "%d blocked, %d damage taken" % [mini(ctx.defence, rolled), ctx.damage()]]


## Lethal hit: offer to sacrifice a die from the pool instead. Returns true if one was sacrificed. A die
## sacrificed from this turn's roll also leaves the row.
func _last_stand() -> bool:
	var pool := SaveManager.run_data.dice
	# The pool can't be emptied
	if pool.size() <= 1:
		return false
	var index := await sacrifice_dialog.ask(pool)
	if index < 0:
		return false
	pool.remove_at(index)
	if debug_pool.is_empty() and dice_tray.get_die(index):
		_spent.append(index)
		await dice_tray.discard([index])
	return true


# ===========================================================================================================================================
# Enemy turn
# ===========================================================================================================================================


## Each living enemy, nearest first: move (Gloomhaven rules), then attack unless it struck back this turn.
func _enemy_turn() -> void:
	for enemy in _enemy_order():
		if not is_instance_valid(enemy) or enemy.is_dead():
			continue
		var path := EnemyAI.find_path(enemy, board, player.tile_id)
		if path.size() > 0:
			await enemy.move_along(path)
		if not _retaliated.has(enemy) and enemy.can_hit(player.tile_id):
			await enemy_attack(enemy, true)
			if _player_dead():
				return
		await get_tree().create_timer(Anim.t(0.15)).timeout


## Turn order: nearest to the player first (sortable, so initiative can be added later).
func _enemy_order() -> Array[Enemy]:
	var order := board.get_enemies()
	var from := Hex.coords(player.tile_id)
	order.sort_custom(func(a: Enemy, b: Enemy): return Hex.distance(Hex.coords(a.tile_id), from) < Hex.distance(Hex.coords(b.tile_id), from))
	return order


## Unused defence dice still in the row.
func _held_dice() -> Array[int]:
	var held: Array[int] = []
	for result in results:
		if is_die_available(result.index) and result.category() == DieFace.Category.DEFENCE and result.face().is_numeric():
			held.append(result.index)
	return held


## Lets the player pick held defence dice against [enemy]'s rolled [damage] (or spends them automatically, if
## set), shown as entry [log_index] in the turn plan. Returns the total defence chosen.
func _choose_block(enemy: Enemy, damage: int, log_index: int) -> int:
	var held := _held_dice()
	if held.is_empty():
		return 0
	var chosen: Array[int] = []
	if SaveManager.settings_data.auto_spend_defence:
		chosen = _auto_block(held, damage)
	else:
		_blocking = enemy
		_blocking_damage = damage
		_block_selected.clear()
		_enemy_log[log_index] = ["%s hits you for %d" % [enemy.data.display_name, damage], "Block or take it?"]
		_refresh()
		enemy.popup("!", Color(1.0, 0.6, 0.2))
		block_prompt.show_prompt(enemy.data.display_name, damage)
		await _block_confirmed
		chosen = _block_selected.duplicate()
		_blocking = null
		_block_selected.clear()
		await block_prompt.hide_prompt()
	_spent.append_array(chosen)
	_refresh()
	return dice_value(chosen)


## Fewest dice that cover [needed]: all of them if they can't, else the smallest single die that does,
## else the largest first.
func _auto_block(held: Array[int], needed: int) -> Array[int]:
	if needed <= 0:
		return []
	var by_value := held.duplicate()
	by_value.sort_custom(func(a: int, b: int): return results[a].value() < results[b].value())
	if dice_value(by_value) <= needed:
		return by_value
	for index in by_value:
		if results[index].value() >= needed:
			var single: Array[int] = [index]
			return single
	var chosen: Array[int] = []
	for i in range(by_value.size() - 1, -1, -1):
		chosen.append(by_value[i])
		if dice_value(chosen) >= needed:
			break
	return chosen


func _take_hit() -> void:
	_block_selected.clear()
	_block_confirmed.emit()


func _click_block_die(index: int) -> void:
	if not _held_dice().has(index):
		dice_tray.get_die(index).shake(dice_tray.camera.global_basis.x * 0.1 * dice_tray._scale)
		return
	if _block_selected.has(index):
		_block_selected.erase(index)
	else:
		_block_selected.append(index)
	block_prompt.set_block_value(dice_value(_block_selected))
	_refresh()


# ===========================================================================================================================================
# Planning
# ===========================================================================================================================================


## Re-simulates the plan from the start of the turn, dropping invalid actions, and updates all previews.
func _replan() -> void:
	var insert_at := _edit_index if _editing else actions.size()
	var sim := TurnState.new(player.tile_id, board.get_enemies())
	var valid: Array[PlannedAction] = []
	_insert_state = null
	for i in actions.size():
		if i == insert_at:
			_insert_state = sim.copy()
		if sim.retaliation and not _is_defending_retaliation(actions[i], sim.retaliation.enemy):
			sim.retaliation.settle_retaliation(sim)
		if actions[i].simulate(sim, self):
			valid.append(actions[i])
	actions = valid
	if sim.retaliation:
		sim.retaliation.settle_retaliation(sim)
	_end_state = sim
	if _insert_state == null:
		_insert_state = sim.copy()
	if _editing:
		# The edited action's dice are free to re-use while it's out of the list
		_edit_index = mini(_edit_index, actions.size())

	# Selected dice must still be free
	selected = selected.filter(func(i: int): return is_die_available(i))
	_move_ctx = null
	_reachable.clear()
	_targets.clear()
	match _selected_category():
		DieFace.Category.MOVE:
			_move_ctx = move_context(_insert_state, selected)
			_reachable = board.find_reachable(_move_ctx)
		DieFace.Category.ATTACK:
			for enemy in _living_enemies(_insert_state):
				if board.in_attack_range(_insert_state.player_tile, enemy.tile_id, player.attack_range):
					_targets.append(enemy.tile_id)
		DieFace.Category.DEFENCE:
			for enemy in _living_enemies(_insert_state):
				_targets.append(enemy.tile_id)
	_refresh()


## Category of the selected dice, or OTHER if none are selected.
func _selected_category() -> DieFace.Category:
	return results[selected[0]].category() if selected.size() > 0 else DieFace.Category.OTHER


func _living_enemies(sim: TurnState) -> Array[Enemy]:
	var living: Array[Enemy] = []
	for enemy in board.get_enemies():
		if sim.is_alive(enemy):
			living.append(enemy)
	return living


## Each buff die adds 1 to every numeric face of its target category, then is spent.
func _apply_buffs() -> void:
	for buff in results:
		if not buff.face().is_buff():
			continue
		_auto_used.append(buff.index)
		var buff_die := dice_tray.get_die(buff.index)
		buff_die.pop()
		await get_tree().create_timer(Anim.t(0.2)).timeout
		for result in results:
			if result != buff and not result.face().is_buff() and result.face().is_numeric() and result.category() == buff.face().buff_category():
				result.bonus += 1
				dice_tray.get_die(result.index).set_face_display(result.face_index, result.display_face())
		buff_die.set_state(Die3D.State.USED)
		await get_tree().create_timer(Anim.t(0.25)).timeout


# ===========================================================================================================================================
# Previews
# ===========================================================================================================================================


func _refresh() -> void:
	if not board:
		return
	_refresh_dice()
	_refresh_board()
	_refresh_list()


func _refresh_dice() -> void:
	for result in results:
		var die := dice_tray.get_die(result.index)
		if die == null:
			continue
		var die_state := Die3D.State.IDLE
		if _end_state and not is_die_available(result.index):
			die_state = Die3D.State.USED
		elif selected.has(result.index) or _block_selected.has(result.index):
			die_state = Die3D.State.SELECTED
		if die.state != die_state:
			die.set_state(die_state)
		var lift := 0.0
		if die_state == Die3D.State.SELECTED:
			lift = SELECTED_LIFT
		elif result.index == hovered_die and die_state == Die3D.State.IDLE and (state == State.PLAN or _blocking):
			lift = HOVER_LIFT
		die.lift(dice_tray.camera.global_basis.y * lift * dice_tray._scale)


func _refresh_board() -> void:
	board.clear_highlights()
	var planning := state == State.PLAN
	_ghost.visible = planning and _end_state != null and _end_state.player_tile != player.tile_id
	if _ghost.visible:
		_ghost.position = board.cell_top_local(Hex.coords(_end_state.player_tile))
	_draw_planned_paths(planning)
	_refresh_enemies(planning)
	if not planning:
		return

	if show_los:
		var from := _insert_state.player_tile
		var visible_ids: Array[int] = []
		var hidden_ids: Array[int] = []
		for tile_id in board.tiles:
			if tile_id != from:
				(visible_ids if board.has_line_of_sight(from, tile_id) else hidden_ids).append(tile_id)
		board.highlight(visible_ids, HexTile.Highlight.VALID)
		board.highlight(hidden_ids, HexTile.Highlight.INVALID)
	if _move_ctx:
		board.highlight(_reachable, HexTile.Highlight.MOVABLE)
		if _reachable.has(hovered_tile):
			board.highlight(_move_ctx.path_to(hovered_tile), HexTile.Highlight.VALID)
	match _selected_category():
		DieFace.Category.ATTACK:
			var out_of_range: Array[int] = []
			for enemy in _living_enemies(_insert_state):
				if not _targets.has(enemy.tile_id):
					out_of_range.append(enemy.tile_id)
			board.highlight(out_of_range, HexTile.Highlight.INVALID)
			board.highlight(_targets, HexTile.Highlight.TARGET)
		DieFace.Category.DEFENCE:
			board.highlight(_targets, HexTile.Highlight.VALID)
	board.select(hovered_tile)


## Planned HP / defence for the overhead info; enemies killed by the plan are darkened.
func _refresh_enemies(planning: bool) -> void:
	for enemy in board.get_enemies():
		if not planning or _end_state == null:
			enemy.preview_hp = enemy.hp
			enemy.preview_defence = 0
			enemy.preview_skips_attack = state == State.ENEMY_TURN and _retaliated.has(enemy)
			enemy.cutout.flash = Color(0, 0, 0, 0)
			continue
		enemy.preview_hp = _end_state.enemy_hp.get(enemy, enemy.hp)
		enemy.preview_defence = _end_state.defence.get(enemy, 0)
		enemy.preview_skips_attack = _end_state.retaliated.has(enemy)
		# Hovering a target previews the selected attack on top of the plan
		if _selected_category() == DieFace.Category.ATTACK and enemy.tile_id == hovered_tile and _targets.has(hovered_tile):
			enemy.preview_hp -= player_attack_context(enemy, selected).damage()
		enemy.cutout.flash = Color(0.1, 0.08, 0.1, 0.6 if enemy.preview_hp <= 0 else 0.0)


## Dotted line along every planned move; teleports get an arrow out of the start and one into the target.
## The hovered teleport target is previewed the same way.
func _draw_planned_paths(show: bool) -> void:
	for dot in _path_dots.get_children():
		dot.queue_free()
	if not show:
		return
	var from := player.tile_id
	for action in actions:
		if action is MoveAction:
			if action.teleport:
				_add_teleport_arrows(from, action.target)
			else:
				_add_dotted_path(from, action.path)
			from = action.target
	if _move_ctx and _move_ctx.teleport and _reachable.has(hovered_tile):
		_add_teleport_arrows(_insert_state.player_tile, hovered_tile)


func _add_dotted_path(from: int, path: Array[int]) -> void:
	var points: Array[Vector3] = [_path_point(from)]
	for tile_id in path:
		points.append(_path_point(tile_id))
	for i in range(1, points.size()):
		var steps := maxi(1, int(points[i - 1].distance_to(points[i]) / PATH_DOT_SPACING))
		for s in steps:
			_add_marker(_dot_mesh, points[i - 1].lerp(points[i], float(s) / steps))


func _add_teleport_arrows(from: int, to: int) -> void:
	var a := _path_point(from)
	var b := _path_point(to)
	var direction := Vector3(b.x - a.x, 0.0, b.z - a.z).normalized()
	var facing := Basis.looking_at(direction)
	# Out of the start, and ending just short of the target's centre
	_add_marker(_arrow_mesh, a + direction * 0.12, facing)
	_add_marker(_arrow_mesh, b - direction * (ARROW_LENGTH + 0.05), facing)


func _path_point(tile_id: int) -> Vector3:
	return board.cell_top_local(Hex.coords(tile_id)) + Vector3.UP * 0.08


func _add_marker(mesh: Mesh, at: Vector3, facing: Basis = Basis.IDENTITY) -> void:
	var marker := MeshInstance3D.new()
	marker.mesh = mesh
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	marker.transform = Transform3D(facing, at)
	_path_dots.add_child(marker)


func _refresh_list() -> void:
	var listed := actions.duplicate()
	if _editing:
		listed.insert(_edit_index, _editing)
	var lines: Array[String] = []
	var warnings: Array[String] = []
	for action in listed:
		lines.append(action.describe(self))
		warnings.append(action.warning(self))
	# Enemy attacks follow the plan as read-only entries
	for entry in _enemy_log:
		if entry[0] != "":
			lines.append(entry[0])
			warnings.append(entry[1])
	action_list.show_actions(lines, warnings, _edit_index if _editing else -1, listed.size(), state == State.PLAN)
	action_list.set_header("TURN %d  ·  %s" % [turn_number, State.keys()[state].replace("_", " ")])
	action_list.set_commit_enabled(state == State.PLAN)
	action_list.set_hint(_hint())


func _hint() -> String:
	match state:
		State.ROLL:
			return "Rolling..."
		State.RESOLVE:
			return "Resolving your actions..."
		State.ENEMY_TURN:
			if _blocking:
				return "%s hits you for %d.  Block with held defence dice or TAKE HIT." % [
					_blocking.data.display_name, _blocking_damage]
			return "Enemy turn..."
		State.LEVEL_CLEAR:
			return "Level clear!  [R] to rebuild (exits arrive in Phase 09)."
		State.GAME_OVER:
			return "Defeated."
	match _selected_category():
		DieFace.Category.ATTACK:
			return "Attack %d: click a highlighted enemy in range.  Click more attack dice to combine them.  Right-click to cancel." % dice_value(selected)
		DieFace.Category.DEFENCE:
			return "Defend %d: click an enemy to block its next attack.  Click more defence dice to combine them.  Right-click to cancel." % dice_value(selected)
	if selected.size() > 0:
		if is_teleport_lost(selected):
			return "Move %d: teleport lost by combining with normal movement.  Click a highlighted tile.  Right-click to cancel." % dice_value(selected)
		if _move_ctx and _move_ctx.teleport:
			return "Teleport %d: click a highlighted tile in line of sight.  Right-click to cancel." % dice_value(selected)
		return "Move %d: click a highlighted tile.  Click more movement dice to combine them.  Right-click to cancel." % dice_value(selected)
	if _editing:
		return "Editing: choose dice, then a target.  Right-click to cancel."
	return "Click dice to plan moves, attacks and defence, then COMMIT."


var _dot_mesh: SphereMesh
var _arrow_mesh: ArrayMesh


func _create_previews() -> void:
	if _path_dots and is_instance_valid(_path_dots):
		_path_dots.queue_free()
	if _ghost and is_instance_valid(_ghost):
		_ghost.queue_free()
	_path_dots = Node3D.new()
	board.add_child(_path_dots)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1.0, 0.95, 0.7)
	_dot_mesh = SphereMesh.new()
	_dot_mesh.radius = 0.04
	_dot_mesh.height = 0.08
	_dot_mesh.radial_segments = 8
	_dot_mesh.rings = 4
	_dot_mesh.material = material
	_arrow_mesh = _create_arrow_mesh(material)

	# Ghost of the player at the planned end position
	_ghost = Cutout.new()
	_ghost.texture = player.cutout.texture
	_ghost.tint = Color(0.85, 0.92, 1.0)
	_ghost.casts_shadow = false
	_ghost.visible = false
	board.add_child(_ghost)


## Clears everything ready for a new level.
func reset() -> void:
	turn_number = 0
	results.clear()
	actions.clear()
	selected.clear()
	_end_state = null
	_editing = null
	_set_state(State.IDLE)
	if dice_tray:
		await dice_tray.clear()


## Flat arrow lying on the XZ plane, pointing along -Z from the origin.
func _create_arrow_mesh(material: Material) -> ArrayMesh:
	var shaft := 0.07
	var head := 0.2
	var head_start := -ARROW_LENGTH * 0.55
	var points := PackedVector3Array([
		Vector3(-shaft, 0, 0), Vector3(shaft, 0, 0), Vector3(shaft, 0, head_start),
		Vector3(-shaft, 0, 0), Vector3(shaft, 0, head_start), Vector3(-shaft, 0, head_start),
		Vector3(-head, 0, head_start), Vector3(head, 0, head_start), Vector3(0, 0, -ARROW_LENGTH),
	])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = points
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var arrow_material: StandardMaterial3D = material.duplicate()
	arrow_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.surface_set_material(0, arrow_material)
	return mesh


func _set_state(new_state: State) -> void:
	state = new_state
	state_changed.emit(state)


func _pool() -> Array[DieType]:
	var types: Array[DieType] = []
	if debug_pool.size() > 0:
		types = debug_pool.duplicate()
	else:
		for id in SaveManager.run_data.dice:
			types.append(Database.get_content("dice", id))
	return types


func _design() -> DieDesign:
	if debug_pool.size() > 0 and debug_design:
		return debug_design
	return Database.get_content("die_designs", SaveManager.progression_data.die_design)
