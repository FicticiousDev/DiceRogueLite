class_name TurnController
extends Node

## Runs the turn: roll the pool, apply buffs, plan a sequence of actions (move, attack), commit, resolve, then
## the enemy turn (enemies move and attack). Defence dice aren't planned: they're held for the whole turn and the
## player spends them whenever they're hit (retaliation, first strikes, enemy attacks). Planning works on a
## TurnState simulated from the start of the turn through the planned actions, rebuilt whenever the plan
## changes; actions that become invalid are dropped.

signal state_changed(state: State)
## The player clicked an enemy while no dice were selected
signal enemy_inspected(enemy: Enemy)
signal _block_confirmed
## Redirect: the player picked the enemy the hit goes to
signal _redirect_picked(enemy: Enemy)

enum State { IDLE, ROLL, PLAN, RESOLVE, ENEMY_TURN, LEVEL_CLEAR, GAME_OVER }

## Localisation keys of the state names shown in the turn plan header
const STATE_NAMES: Dictionary[State, String] = {
	State.IDLE: "STATE_IDLE", State.ROLL: "STATE_ROLL", State.PLAN: "STATE_PLAN", State.RESOLVE: "STATE_RESOLVE",
	State.ENEMY_TURN: "STATE_ENEMY_TURN", State.LEVEL_CLEAR: "STATE_LEVEL_CLEAR", State.GAME_OVER: "STATE_GAME_OVER",
}

const PATH_DOT_SPACING: float = 0.22
const ARROW_LENGTH: float = 0.55
## Row dice raise this far (tray units) when selected / hovered
const SELECTED_LIFT: float = 0.45
const HOVER_LIFT: float = 0.15
## Kill gold grows by this share of the enemy's gold per level entered
const GOLD_PER_DEPTH: float = 0.04

var state: State = State.IDLE
var turn_number: int = 0
var board: Board
var player: Player
var dice_tray: DiceTray
var action_list: ActionList
var confirm_dialog: ConfirmDialog
var sacrifice_dialog: SacrificeDialog
var block_prompt: BlockPrompt
var attack_preview: AttackPreview

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
## Shown once the level is clear; set by the run
var clear_hint: String = tr("HINT_LEVEL_CLEAR")

## Buff dice spent automatically when the row formed
var _auto_used: Array[int] = []
## Plan simulated up to the insertion point (end of the list, or the action being edited)
var _insert_state: TurnState
var _end_state: TurnState
var _move_ctx: MoveContext
var _reachable: Array[int] = []
## Enemy tiles the selected attack dice can target
var _targets: Array[int] = []
## Damage taken this turn
var _damage_taken: int = 0
## Resolution: one entry per strike an enemy made back this turn; each uses up one of its attacks in the enemy turn
var _retaliated: Array[Enemy] = []
## Held defence dice spent blocking hits
var _spent: Array[int] = []
## Active ability uses left (ability id -> uses; a cooldown active has 1 while ready); planning simulates its own copy in
## TurnState.uses
var _uses: Dictionary = {}
## Cooldown actives that have been used: ability id -> turn number they're ready again
var _ready_on: Dictionary = {}
## Effects lasting the rest of this turn (see Ability.grants_boosts)
var _boosts: Array[StringName] = []
## Planning: the move active armed (the next tile clicked is its target)
var _dashing: DashAbility
## Resolution: an enemy is striking back (retaliation or first strike), so a redirect can be offered
var _striking_back: bool = false
## Redirect: enemies the hit can be sent to while the player picks one, and the one picked
var _redirect_targets: Array[Enemy] = []
var _redirect_to: Enemy
## The player's fire came from a boss (counts against the no-boss-damage challenge)
var _burn_from_boss: bool = false
## Planning: attack actives armed for the next attack
var _armed: Array[Ability] = []
## Player attacks resolved this turn (the first can be a crit, see AttackContext.first_attack)
var _attacks_made: int = 0
## Block prompt: the block actives offered, and the one the player chose, if any
var _block_offer: Array[Ability] = []
var _block_with: Ability
## Block prompt: the enemy whose hit the player is choosing held defence dice for, and the dice chosen
var _blocking: Enemy
var _blocking_damage: int = 0
var _block_selected: Array[int] = []
## One turn plan entry per enemy attack on the player, as [line, note]
var _enemy_log: Array[Array] = []
## Shown in place of the usual hint until the plan next changes
var _hint_note: String = ""
## The last block used a dodge face
var _dodged: bool = false
## Enemies that attacked in a turn taken before the player's this round: they don't retaliate
var _attacked_first: Array[Enemy] = []
## True once the enemies have taken this round's turn before the player's, so there isn't another after it
var _enemies_acted: bool = false
var _order_prompt: TurnOrderPrompt
var _editing: PlannedAction
var _edit_index: int = -1
var _ghost: Cutout
var _path_dots: Node3D


func setup(run_board: Board, run_player: Player, tray: DiceTray, list: ActionList, dialog: ConfirmDialog, last_stand: SacrificeDialog, prompt: BlockPrompt, preview: AttackPreview) -> void:
	attack_preview = preview
	board = run_board
	player = run_player
	dice_tray = tray
	action_list = list
	confirm_dialog = dialog
	sacrifice_dialog = last_stand
	block_prompt = prompt
	# Active ability uses and cooldowns are per level; setup runs for every level
	_uses = new_uses()
	_ready_on.clear()
	if not block_prompt.block_pressed.is_connected(_block_confirmed.emit):
		block_prompt.block_pressed.connect(_block_confirmed.emit)
		block_prompt.take_pressed.connect(_take_hit)
		block_prompt.ability_pressed.connect(_block_with_ability)
	if not action_list.commit_pressed.is_connected(commit):
		action_list.commit_pressed.connect(commit)
		action_list.ability_pressed.connect(func(index: int): use_active(plan_actives()[index]))
		action_list.rewind_requested.connect(rewind_to)
		action_list.edit_requested.connect(edit)
		action_list.delete_requested.connect(delete)
	if _order_prompt == null:
		_order_prompt = TurnOrderPrompt.new()
		add_child(_order_prompt)
		_order_prompt.pressed.connect(_enemies_first_pressed)
	_create_previews()


## Rolls the pool and starts planning. [new_turn] false re-rolls the current turn (debug).
func start_turn(new_turn: bool = true) -> void:
	if new_turn:
		turn_number += 1
		SaveManager.run_data.turns += 1
		_tick_cooldowns()
		_boosts.clear()
		# Enemies set on fire last round burn now
		await _burn_tick()
	_sync_enemies()
	results.clear()
	_end_state = null
	actions.clear()
	selected.clear()
	_auto_used.clear()
	_spent.clear()
	_enemy_log.clear()
	_retaliated.clear()
	_attacked_first.clear()
	_enemies_acted = false
	_armed.clear()
	_editing = null
	_dashing = null
	_attacks_made = 0
	# Levels without enemies are clear from the start
	if board.get_enemies().is_empty():
		_set_state(State.LEVEL_CLEAR)
		_refresh()
		return
	# Player status effects come first: poison bites, fire burns, a stun (from the enemy turn) costs the whole turn
	if player.poisoned:
		player.popup(tr("POPUP_POISON"), Color(0.5, 1.0, 0.4))
		await _hurt_player(1, "-1")
		if _player_dead():
			await _game_over()
			return
	if player.burn > 0:
		var burn := player.burn
		player.burn = 0
		player.popup(tr("POPUP_BURNING"), Color(1.0, 0.55, 0.2))
		await _hurt_player(burn, "-%d" % burn, _burn_from_boss)
		_burn_from_boss = false
		if _player_dead():
			await _game_over()
			return
	# Poison and burning don't count against the end-of-turn heal, so a quiet turn can still cure the poison
	_damage_taken = 0
	# A freeze (from a hit in the last round) slows this turn's movement
	player.frozen = player.frozen_next
	player.frozen_next = false
	if player.stunned:
		await _offer_stun_cure()
	if _stun_blocks(player):
		_set_state(State.ENEMY_TURN)
		await get_tree().create_timer(Anim.t(0.5)).timeout
		await _finish_turn()
		return
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


## Movement search for [dice] from the simulated [sim] state; a teleport only if every die has the teleport symbol
## (or an ability makes every move one). Abilities can change costs, budget or teleport.
func move_context(sim: TurnState, dice: Array[int]) -> MoveContext:
	var ctx := MoveContext.new(sim.player_tile, dice_value(dice), board.move_cost, player)
	ctx.teleport = dice.size() > 0 and dice.all(_has_teleport)
	ctx.ignored = sim.dead_enemies()
	for ability in abilities():
		ability.modify_move(ctx)
	# Frozen: half the movement, rounded up - teleports aren't slowed
	if player.frozen and not ctx.teleport:
		ctx.budget = ceili(ctx.budget / 2.0)
	return ctx


# ===========================================================================================================================================
# Abilities & attack contexts
# ===========================================================================================================================================


## Every ability in play: the character's, then each equipped item's.
func abilities() -> Array[Ability]:
	var result: Array[Ability] = []
	if player.character:
		result.append_array(player.character.abilities)
	for item in SaveManager.run_data.equipped():
		result.append_array(item.abilities)
	return result


## Every active ability (the ones the player chooses when to use), once each.
func actives() -> Array[Ability]:
	var result: Array[Ability] = []
	for ability in abilities():
		if ability.active and not result.has(ability):
			result.append(ability)
	return result


## Actives used a particular way, e.g. Ability.Use.BLOCK.
func actives_of(use: Ability.Use) -> Array[Ability]:
	return actives().filter(func(a: Ability): return a.use == use)


## Uses of every active for a fresh level: its uses per level (two copies of an item add up), or 1 for a cooldown active
## (ready).
func new_uses() -> Dictionary:
	var uses := {}
	for ability in abilities():
		if ability.active:
			uses[ability.id] = 1 if ability.cooldown > 0 else uses.get(ability.id, 0) + ability.uses_per_level
	return uses


## Cooldown actives whose cooldown has passed are ready again.
func _tick_cooldowns() -> void:
	for id in _ready_on.keys():
		if turn_number >= _ready_on[id]:
			_uses[id] = 1
			_ready_on.erase(id)


## Spends a use of [ability] for real, starting its cooldown if it has one.
func _spend(ability: Ability) -> bool:
	if not spend_use(ability, _uses):
		return false
	if ability.cooldown > 0:
		_ready_on[ability.id] = turn_number + ability.cooldown
	return true


## Attack actives from [wanted] that can still be paid for, spent for real.
func _spend_all(wanted: Array[Ability]) -> Array[Ability]:
	var spent: Array[Ability] = []
	for ability in wanted:
		if _spend(ability):
			spent.append(ability)
	return spent


## How an active stands, for buttons and the top bar: uses left of the total ("1/2"), or for a cooldown active tr("HUD_ABILITY_READY")
## or the turns until it is (counting a use planned this turn).
func active_status(ability: Ability) -> String:
	var left: int = uses_preview().get(ability.id, 0)
	if ability.cooldown <= 0:
		return "%d/%d" % [left, new_uses().get(ability.id, 0)]
	if left > 0:
		return tr("HUD_ABILITY_READY")
	var wait: int = _ready_on.get(ability.id, turn_number + ability.cooldown) - turn_number
	return tr("HUD_ABILITY_WAIT_ONE") if wait == 1 else tr("HUD_ABILITY_WAIT_MANY") % wait


## True if the player heals every round, whatever damage they took.
func _regenerates() -> bool:
	return abilities().any(func(a: Ability): return a.heals_every_turn())


## Miss chance multiplier for attacks on the player of the run [run] (its character and items).
static func miss_scale_for(run: RunData) -> float:
	var scale := 1.0
	var character: CharacterData = Database.get_content("characters", run.character_id)
	var list: Array[Ability] = []
	if character:
		list.append_array(character.abilities)
	for item in run.equipped():
		list.append_array(item.abilities)
	for ability in list:
		scale *= ability.miss_chance_multiplier()
	return scale


## Applies the player's abilities to every enemy on the board (ranged enemies' range, say). Run whenever enemies may
## have appeared (each turn, after summons).
func _sync_enemies() -> void:
	var change := 0
	for ability in abilities():
		change += ability.enemy_range_change()
	for enemy in board.get_enemies():
		if enemy.range_reduction != -change:
			enemy.range_reduction = -change
			enemy.stats_changed.emit()


## Gives actives equipped mid-level (e.g. from a chest) their uses for this level. Actives already counted keep
## what's left, so swapping an item out and back in doesn't refill it.
func _sync_uses() -> void:
	var fresh := new_uses()
	for id in fresh:
		if not _uses.has(id):
			_uses[id] = fresh[id]


## Uses left as they'll be after the plan (while planning), or as they are now.
func uses_preview() -> Dictionary:
	return _end_state.uses if state == State.PLAN and _end_state else _uses


## Spends one use of [ability] from [uses] if any are left.
static func spend_use(ability: Ability, uses: Dictionary) -> bool:
	if ability == null or uses.get(ability.id, 0) <= 0:
		return false
	uses[ability.id] -= 1
	return true


func player_strikes_first() -> bool:
	return abilities().any(func(a: Ability): return a.strikes_first())


## Attack range with [dice]: the character's plus their range modifier. Combined dice only keep the range they all
## share (the smallest), so a die without range removes it from the whole attack.
func attack_range(dice: Array[int]) -> int:
	var bonus := -1
	for i in dice:
		var face_range := results[i].face().count(Symbol.Type.RANGE)
		bonus = face_range if bonus == -1 else mini(bonus, face_range)
	return player.attack_range + maxi(bonus, 0)


## True if some of [dice] have more range than the combined attack keeps (see [method attack_range]).
func is_range_lost(dice: Array[int]) -> bool:
	return dice.any(func(i: int): return player.attack_range + results[i].face().count(Symbol.Type.RANGE) > attack_range(dice))


## The player's attack on [enemy] with [dice]: modifier symbols, then abilities ([used]: the actives spent on it;
## [first]: it's the turn's first attack; [from_tile]: where the player attacks from, default their tile; [boosts]: the
## turn's boosts so far). [enemy] may be null to preview an attack with no target yet (no defence).
func player_attack_context(enemy: Enemy, dice: Array[int], used: Array[Ability] = [], first: bool = false, from_tile: int = -1,
		boosts: Array[StringName] = []) -> AttackContext:
	var ctx := AttackContext.new(player, enemy, 0, 0)
	ctx.first_attack = first
	if enemy:
		ctx.distance = Hex.distance(Hex.coords(player.tile_id if from_tile == -1 else from_tile), Hex.coords(enemy.tile_id))
	var crits := 0
	for i in dice:
		var face := results[i].face()
		# Each die is its own part, so a crit (and Ambush) doubles just one of them: the highest
		var part := ctx.add_part(results[i].value())
		crits += face.count(Symbol.Type.CRIT)
		if face.has(Symbol.Type.INSTA_KILL):
			ctx.insta_kill = true
			ctx.insta_kill_parts.append(part)
		ctx.stun = ctx.stun or face.has(Symbol.Type.STUN)
		ctx.poison = ctx.poison or face.has(Symbol.Type.POISON)
		ctx.penetrate += face.count(Symbol.Type.PENETRATE)
	if ctx.insta_kill and enemy and enemy.data.is_boss:
		crits += ctx.resist_insta_kill()
	# Each crit doubles the highest die at that point, so several crits stack
	for crit in crits:
		ctx.crit_part(ctx.highest_part())
	if boosts.has(&"crit") and not ctx.insta_kill and ctx.parts.size() > 0:
		ctx.crit_part(ctx.highest_part())
		ctx.notes.append(tr("NOTE_CRIT"))
	if boosts.has(&"pierce") and not ctx.ignore_defence:
		ctx.ignore_defence = true
		ctx.notes.append(tr("NOTE_PIERCE"))
	for ability in abilities():
		ability.modify_attack(ctx, used.has(ability))
	return ctx


## Attack actives from [wanted] that [uses] can still pay for, spending them.
static func spend_uses(wanted: Array[Ability], uses: Dictionary) -> Array[Ability]:
	var spent: Array[Ability] = []
	for ability in wanted:
		if spend_use(ability, uses):
			spent.append(ability)
	return spent


## True if the player can't be given [status] (&"stun" or &"poison").
func player_prevents(status: StringName) -> bool:
	return abilities().any(func(a: Ability): return a.prevents_status(status))


## Runs an attack on the player through the abilities.
func apply_incoming(ctx: AttackContext) -> void:
	for ability in abilities():
		ability.modify_incoming_attack(ctx)


## Actives that can be pressed in the turn plan: attack actives (armed for the next attack) and action actives
## (added to the plan). Block actives are used from the block prompt.
func plan_actives() -> Array[Ability]:
	return actives().filter(func(a: Ability): return a.use != Ability.Use.BLOCK)


## Turn plan button for [ability]: arms / disarms an attack active, or adds an action active to the plan.
func use_active(ability: Ability) -> void:
	if state != State.PLAN:
		return
	if ability.use == Ability.Use.ATTACK:
		if _armed.has(ability):
			_armed.erase(ability)
		elif _insert_state.uses.get(ability.id, 0) > 0:
			_armed.append(ability)
		_replan()
	elif ability.use == Ability.Use.MOVE:
		if _dashing == ability:
			_dashing = null
		elif _insert_state.uses.get(ability.id, 0) > 0:
			_dashing = ability as DashAbility
			selected.clear()
		_replan()
	elif ability.use == Ability.Use.ACTION and _insert_state.uses.get(ability.id, 0) > 0:
		_finish_edit()
		actions.append(AbilityAction.new(ability))
		_replan()


## Stunned at the start of a turn: offers an unused action active that removes stun, which saves the turn.
func _offer_stun_cure() -> void:
	_sync_uses()
	for ability in actives_of(Ability.Use.ACTION):
		if ability.cures_stun() and _uses.get(ability.id, 0) > 0:
			if await confirm_dialog.ask(tr("POPUP_STUNNED"), tr("DIALOG_STUNNED_MESSAGE") % ability.display_name):
				_spend(ability)
				player.popup(ability.display_name, Color(1.0, 0.85, 0.4))
				await ability.perform(self)
			return


## Removes poison and/or stun from the player.
func cure_player(poison: bool, stun: bool) -> void:
	var cured := false
	if poison and player.poisoned:
		player.poisoned = false
		cured = true
	if stun and player.stunned:
		player.stunned = false
		cured = true
	player.popup(tr("POPUP_CURED") if cured else tr("POPUP_NO_EFFECT"), Color(0.5, 1.0, 0.4))
	await get_tree().create_timer(Anim.t(0.4)).timeout


## True if teleport dice are combined with normal movement dice, losing the teleport (not when every move teleports).
func is_teleport_lost(dice: Array[int]) -> bool:
	if _moves_teleport():
		return false
	return dice.any(_has_teleport) and not dice.all(_has_teleport)


## True if an ability makes every move a teleport.
func _moves_teleport() -> bool:
	var probe := MoveContext.new(-1, 0, Callable())
	for ability in abilities():
		ability.modify_move(probe)
	return probe.teleport


func _has_teleport(index: int) -> bool:
	return results[index].face().has(Symbol.Type.TELEPORT)


func is_die_available(index: int) -> bool:
	return not _end_state.used_dice.has(index) and not _auto_used.has(index) and not _spent.has(index)


# ===========================================================================================================================================
# Input
# ===========================================================================================================================================


func _process(_delta: float) -> void:
	if not board or not (state == State.PLAN or _blocking or _redirect_targets.size() > 0):
		return
	var mouse := board.get_viewport().get_mouse_position()
	var die := dice_tray.get_die_at(mouse)
	var tile := -1 if die != -1 or _blocking else board.tile_at_screen(dice_tray.camera, mouse)
	if die != hovered_die or tile != hovered_tile:
		hovered_die = die
		hovered_tile = tile
		_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if _redirect_targets.size() > 0:
		if event.is_action_pressed("select"):
			var target := board.get_piece(hovered_tile) as Enemy
			if target and _redirect_targets.has(target):
				_redirect_picked.emit(target)
		return
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
	elif event.is_action_pressed("cancel") and (selected.size() > 0 or _editing or _armed.size() > 0 or _dashing):
		get_viewport().set_input_as_handled()
		_cancel()


func _click_die(index: int) -> void:
	var die := dice_tray.get_die(index)
	var result := results[index]
	if not is_die_available(index) or result.category() == DieFace.Category.DEFENCE:
		die.shake(dice_tray.camera.global_basis.x * 0.1 * dice_tray._scale)
		if result.category() == DieFace.Category.DEFENCE:
			_hint_note = tr("HINT_DEFENCE_NOT_PLANNED")
			_refresh()
		return
	_dashing = null
	if selected.has(index):
		selected.erase(index)
	else:
		# Only dice of one kind combine into an action; picking another kind starts a new selection
		if selected.size() > 0 and results[selected[0]].category() != result.category():
			selected.clear()
		selected.append(index)
	_replan()


func _click_tile(tile_id: int) -> void:
	if _dashing:
		if _reachable.has(tile_id):
			var dash := DashAction.new(_dashing, tile_id)
			_dashing = null
			if _editing:
				_finish_edit()
			actions.append(dash)
			_replan()
		return
	if selected.is_empty():
		var piece := board.get_piece(tile_id)
		if piece is Enemy:
			enemy_inspected.emit(piece)
		return
	var action: PlannedAction
	match _selected_category():
		DieFace.Category.MOVE:
			if _reachable.has(tile_id):
				action = MoveAction.new(selected, tile_id)
		DieFace.Category.ATTACK:
			if _targets.has(tile_id):
				action = AttackAction.new(selected, board.get_piece(tile_id), _armed)
	if action == null:
		return
	var index := _edit_index if _editing else actions.size()
	if action is AttackAction:
		_armed.clear()
		attack_preview.fly_to(action_list, index)
	selected.clear()
	if _editing:
		actions.insert(_edit_index, action)
		_editing = null
	else:
		actions.append(action)
	_replan()


func _cancel() -> void:
	selected.clear()
	_armed.clear()
	_dashing = null
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
	# Actions without dice (ability actions) have nothing to re-pick
	if actions[index].dice.is_empty():
		return
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
		if not await confirm_dialog.ask(tr("DIALOG_UNUSED_DICE_TITLE"), tr("DIALOG_UNUSED_DICE_ONE") if count == 1 else tr("DIALOG_UNUSED_DICE_MANY") % count, &"confirm_unused_dice"):
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
	_retaliated.clear()
	for action in actions:
		# Stunned during the plan (e.g. by a retaliation): the rest of it is lost
		if _stun_blocks(player):
			await get_tree().create_timer(Anim.t(0.4)).timeout
			continue
		await action.resolve(self)
		if _player_dead():
			await _game_over()
			return
	await _finish_turn()


## After the player's actions (or a stunned turn): level clear check, enemy turn, end-of-turn healing, next turn.
func _finish_turn() -> void:
	# A stun lasts until the end of the stunned piece's own turn, a freeze until the end of the turn it slowed
	player.stunned = false
	player.frozen = false
	if board.get_enemies().is_empty():
		await _clear_level()
		return
	# Unused defence dice are held for the enemy turn; everything else is discarded (all of it if the enemies already
	# had their turn this round)
	var discarded: Array[int] = []
	for result in results:
		if _enemies_acted or not _held_dice().has(result.index):
			discarded.append(result.index)
	await dice_tray.discard(discarded)
	_set_state(State.ENEMY_TURN)
	_refresh()
	if _enemies_acted:
		await _end_round()
	else:
		await _enemy_turn()
	if _player_dead():
		await _game_over()
		return
	await dice_tray.clear()
	if _damage_taken == 0 or _regenerates():
		await heal_player(1)
	start_turn()


## The last enemy is gone: the player's frozen / burning state ends and the turn still heals if it was taken without
## damage.
func _clear_level() -> void:
	player.frozen_next = false
	player.burn = 0
	await dice_tray.clear()
	if _damage_taken == 0 or _regenerates():
		await heal_player(1)
	_set_state(State.LEVEL_CLEAR)
	_refresh()


## Restores [amount] HP (up to max). If poisoned, the heal cures the poison instead.
func heal_player(amount: int) -> void:
	var run := SaveManager.run_data
	if player.poisoned:
		# Curing poison takes the place of the heal
		player.poisoned = false
		player.popup(tr("POPUP_CURED"), Color(0.5, 1.0, 0.4))
	elif run.health < run.max_health:
		var healed := mini(amount, run.max_health - run.health)
		run.health += healed
		run.count(&"healed", healed)
		player.popup("+%d" % amount, Color(0.4, 1.0, 0.45))
	else:
		return
	await get_tree().create_timer(Anim.t(0.4)).timeout


## Unblocked damage to the player, offering a last stand if it would kill them. Returns true if it landed. [from_boss]:
## the damage came from a boss (tracked for an unlock challenge).
func _hurt_player(damage: int, text: String, from_boss: bool = false) -> bool:
	_damage_taken += damage
	if damage >= SaveManager.run_data.health and await _last_stand():
		player.popup(tr("POPUP_SACRIFICED"), Color(1.0, 0.6, 0.3))
		return false
	if from_boss:
		SaveManager.run_data.count(&"boss_damage", damage)
	player.hurt()
	player.popup(text, Color(1, 0.3, 0.25))
	var run := SaveManager.run_data
	run.health = maxi(run.health - damage, 0)
	run.damage_received += damage
	return true


func _player_dead() -> bool:
	return SaveManager.run_data.health <= 0


func _game_over() -> void:
	await dice_tray.clear()
	_set_state(State.GAME_OVER)
	_refresh()


## True (with a popup) if [piece] is stunned and so can't act. A stun lasts until the end of the piece's own turn:
## an enemy stunned in the player's turn doesn't strike first, retaliate, move or attack until the next round; a
## player stunned mid-plan loses the rest of it, and one stunned in the enemy turn loses their next turn.
func _stun_blocks(piece: BoardPiece) -> bool:
	if not piece.stunned:
		return false
	piece.popup(tr("POPUP_STUNNED"), Color(1.0, 0.8, 0.3))
	return true


## Player attacks [enemy]; it strikes first if it always attacks first, otherwise retaliates straight after if it
## survives. Either way the player may block with held defence dice.
func resolve_attack(enemy: Enemy, dice: Array[int], wanted: Array[Ability]) -> void:
	if not is_instance_valid(enemy) or enemy.is_dead():
		return
	# The target can have gone out of reach since the plan was made (a boss teleporting away)
	if not board.in_attack_range(player.tile_id, enemy.tile_id, attack_range(dice)):
		player.popup(tr("POPUP_OUT_OF_RANGE"), Color(0.8, 0.8, 0.85))
		await get_tree().create_timer(Anim.t(0.3)).timeout
		return
	var enemy_first := enemy.data.attacks_first and not player_strikes_first()
	if enemy_first and not _stun_blocks(enemy):
		if await _strike_back(enemy):
			_retaliated.append(enemy)
		if _player_dead():
			return
	var arc := await board.show_attack_arc(player, enemy)
	await player.lunge(enemy.position)
	var ctx := player_attack_context(enemy, dice, _spend_all(wanted), _attacks_made == 0, -1, _boosts)
	_attacks_made += 1
	_boosts.erase(&"crit")
	if ctx.notes.size() > 0:
		player.popup(" + ".join(ctx.notes), Color(1.0, 0.85, 0.4))
	if ctx.crit:
		SaveManager.run_data.crits += 1
		SaveManager.run_data.progress_changed = true
	# Health and shield before the hit, for bosses that react to losing them
	var before: Dictionary[Enemy, Vector2i] = { enemy: Vector2i(enemy.hp, enemy.shield) }
	var dealt: Dictionary[Enemy, int] = { enemy: ctx.damage() }
	_damage_enemy(enemy, ctx.damage(), ctx.shield_multiplier())
	if arc:
		arc.fade_out()
	# Area hits; only the main target retaliates
	var hit: Array[Enemy] = [enemy]
	for tile_id in ctx.aoe_tiles:
		var other := board.get_piece(tile_id) as Enemy
		if other and not other.is_dead():
			before[other] = Vector2i(other.hp, other.shield)
			dealt[other] = ctx.split(other, 0).damage()
			_damage_enemy(other, dealt[other], ctx.shield_multiplier())
			hit.append(other)
	for target in hit:
		if not target.is_dead():
			if ctx.stun and target.data.stun_immune:
				target.popup(tr("POPUP_IMMUNE"), Color(0.8, 0.8, 0.85))
			elif ctx.stun and not target.stunned:
				target.stunned = true
				target.popup(tr("POPUP_STUNNED"), Color(1.0, 0.8, 0.3))
				SaveManager.run_data.count(&"stun")
			if ctx.poison and not target.poisoned:
				target.poisoned = true
				target.popup(tr("POPUP_POISONED"), Color(0.5, 1.0, 0.4))
				SaveManager.run_data.count(&"poison")
			# Fire: half the damage dealt again at the start of the next round
			if ctx.fire and dealt[target] / 2 > 0:
				target.burn += dealt[target] / 2
				target.popup(tr("POPUP_ON_FIRE"), Color(1.0, 0.55, 0.2))
				SaveManager.run_data.count(&"burn")
	var deaths: Array[Enemy] = []
	deaths.assign(hit.filter(func(e: Enemy): return e.is_dead()))
	for dead in deaths:
		_reward_kill(dead)
		dead.play_death()
	if deaths.size() > 0:
		await deaths[0].died
	for dead in deaths:
		await _dismiss_minions(dead)
	await _react_to_damage(before)
	if not enemy.is_dead() and not enemy_first and not _stun_blocks(enemy):
		if await _strike_back(enemy):
			_retaliated.append(enemy)
	await get_tree().create_timer(Anim.t(0.25)).timeout


## False if [enemy] already attacked this round in a turn taken before the player's, so it has nothing left to strike
## back with. (Stun is checked separately.)
func can_retaliate(enemy: Enemy) -> bool:
	return not _attacked_first.has(enemy)


## [enemy] strikes back at the player's attack (retaliation or first strike) - the hits a redirect can be used on.
func _strike_back(enemy: Enemy) -> bool:
	if not can_retaliate(enemy):
		return false
	_striking_back = true
	var attacked := await enemy_attack(enemy)
	_striking_back = false
	return attacked


## [enemy] attacks the player if it can hit them. The roll is shown in the turn plan and the player may block
## with held defence dice. Returns true if it attacked.
func enemy_attack(enemy: Enemy) -> bool:
	if not enemy.can_hit(player.tile_id):
		return false
	await hit_player(enemy, AttackContext.roll_enemy(enemy, player, 0, _miss_scale()))
	return true


## How much likelier enemy attacks are to miss, from the player's abilities.
func _miss_scale() -> float:
	var scale := 1.0
	for ability in abilities():
		scale *= ability.miss_chance_multiplier()
	return scale


## [enemy]'s [ctx] lands on the player: through their abilities, then the block decision with held defence dice, then
## the damage and any status the hit gives. [swing]: draws a ranged arc and lunges - off for charges and flames, which
## aren't a swing at the player.
func hit_player(enemy: Enemy, ctx: AttackContext, swing: bool = true) -> void:
	if _enemies_acted and state == State.ENEMY_TURN and not _striking_back and not _attacked_first.has(enemy):
		_attacked_first.append(enemy)
	apply_incoming(ctx)
	# A ranged attack draws its arc first and keeps it up through the block decision
	var arc: AttackArc = null
	if swing:
		arc = await board.show_attack_arc(enemy, player)
	var log_index := _enemy_log.size()
	_enemy_log.append(["", ""])
	_dodged = false
	_redirect_to = null
	if not ctx.miss and ctx.damage() > 0:
		var rolled := ctx.damage()
		ctx.defence += await _choose_block(enemy, rolled, log_index)
		if _redirect_to:
			ctx.defence -= AttackContext.BLOCK_ALL
			ctx.negated = true
			ctx.notes.append(tr("NOTE_REDIRECTED"))
	if _dodged and enemy.data.is_boss:
		SaveManager.run_data.count(StringName("dodged_boss:%s" % enemy.base.id))
	var damage := ctx.damage()
	_enemy_log[log_index] = _attack_log(enemy, ctx)
	_refresh()
	if swing:
		await enemy.lunge(player.position)
	if ctx.miss:
		SaveManager.run_data.misses += 1
		player.popup(tr("POPUP_MISS"), Color(0.8, 0.8, 0.8))
	elif ctx.negated:
		player.popup(" + ".join(ctx.notes).to_upper(), Color(0.45, 0.7, 1.0))
	elif damage == 0:
		player.popup(tr("POPUP_DODGED") if _dodged else tr("POPUP_BLOCKED"), Color(0.45, 0.7, 1.0))
	elif await _hurt_player(damage, (tr("POPUP_CRIT_DAMAGE") if ctx.crit else "-%d") % damage, enemy.data.is_boss) and not _player_dead():
		# A sacrificed hit still counts as damage taken (no heal) but doesn't pass on status effects
		_apply_hit_effects(enemy, damage)
	if arc:
		arc.fade_out()
	if _redirect_to:
		var target := _redirect_to
		_redirect_to = null
		await _redirect_hit(target, ctx.raw())
	await get_tree().create_timer(Anim.t(0.35)).timeout


## A redirected hit of [damage] lands on [target] (its defence soaks it), as the player's attack: kills give gold.
func _redirect_hit(target: Enemy, damage: int) -> void:
	if not is_instance_valid(target) or target.is_dead():
		return
	var arc := await board.show_attack_arc(player, target)
	await player.lunge(target.position)
	var before: Dictionary[Enemy, Vector2i] = { target: Vector2i(target.hp, target.shield) }
	_damage_enemy(target, damage)
	SaveManager.run_data.count(&"redirect")
	if arc:
		arc.fade_out()
	if target.is_dead():
		_reward_kill(target)
		target.play_death()
		await target.died
		await _dismiss_minions(target)
	await _react_to_damage(before)


## The statuses [enemy]'s hit gives the player, for [damage] that got through.
func _apply_hit_effects(enemy: Enemy, damage: int) -> void:
	if enemy.data.applies_stun and not player.stunned:
		if player_prevents(&"stun"):
			player.popup(tr("POPUP_STUN_RESISTED"), Color(0.8, 0.8, 0.85))
		else:
			player.stunned = true
			player.popup(tr("POPUP_STUNNED"), Color(1.0, 0.8, 0.3))
	if enemy.data.applies_poison and not player.poisoned:
		if player_prevents(&"poison"):
			player.popup(tr("POPUP_POISON_RESISTED"), Color(0.8, 0.8, 0.85))
		else:
			player.poisoned = true
			player.popup(tr("POPUP_POISONED"), Color(0.5, 1.0, 0.4))
	if enemy.data.applies_freeze and not player.frozen_next:
		if player_prevents(&"freeze"):
			player.popup(tr("POPUP_FREEZE_RESISTED"), Color(0.8, 0.8, 0.85))
		else:
			player.frozen_next = true
			player.popup(tr("POPUP_FROZEN"), Color(0.6, 0.85, 1.0))
	# Fire adds half of each damaging hit again at the start of the next turn
	if enemy.data.applies_fire and damage / 2 > 0:
		if player_prevents(&"fire"):
			player.popup(tr("POPUP_FIRE_RESISTED"), Color(0.8, 0.8, 0.85))
		else:
			player.burn += damage / 2
			_burn_from_boss = _burn_from_boss or enemy.data.is_boss
			player.popup(tr("POPUP_ON_FIRE"), Color(1.0, 0.55, 0.2))


## Turn plan entry for a resolved enemy attack.
func _attack_log(enemy: Enemy, ctx: AttackContext) -> Array:
	var name := enemy.data.display_name + (" (%s)" % ctx.source_note if ctx.source_note != "" else "")
	if ctx.miss:
		return [tr("LOG_MISSED_YOU") % name, ""]
	var rolled := ctx.raw()
	var line := (tr("LOG_CRIT_HIT_YOU") if ctx.crit else tr("LOG_HIT_YOU")) % [name, rolled]
	if ctx.negated and _redirect_to:
		return [line, tr("LOG_REDIRECTED_TO") % _redirect_to.data.display_name]
	if ctx.negated:
		return [line, tr("LOG_BLOCKED_BY") % " + ".join(ctx.notes)]
	if _dodged:
		return [line, tr("LOG_DODGED")]
	if ctx.defence <= 0:
		return [line, ""]
	return [line, tr("LOG_BLOCKED_DAMAGE_TAKEN") % [AttackContext.value_text(mini(ctx.defence, rolled)), ctx.damage()]]


## Plays out a planned action active; boosts it grants last the rest of the turn.
func resolve_ability(ability: Ability) -> void:
	if not _spend(ability):
		return
	player.popup(ability.display_name, Color(1.0, 0.85, 0.4))
	_boosts.append_array(ability.grants_boosts())
	await ability.perform(self)


## Movement search for a move active from the simulated [sim] state: a teleport up to its reach.
func dash_context(sim: TurnState, ability: DashAbility) -> MoveContext:
	var ctx := MoveContext.new(sim.player_tile, ability.reach, board.move_cost, player)
	ctx.teleport = true
	ctx.ignored = sim.dead_enemies()
	return ctx


## Enemies on the straight line between [from] and [to] (both excluded), in order from [from].
func dash_victims(from: int, to: int) -> Array[Enemy]:
	var victims: Array[Enemy] = []
	for tile_id in dash_line(from, to).slice(1, -1):
		var enemy := board.get_piece(tile_id) as Enemy
		if enemy and not enemy.is_dead():
			victims.append(enemy)
	return victims


## Tile ids on the straight line from [from] to [to], inclusive.
func dash_line(from: int, to: int) -> Array[int]:
	var tiles: Array[int] = []
	for cell in Hex.line(Hex.coords(from), Hex.coords(to)):
		tiles.append(Hex.id(cell))
	return tiles


## Damage [ability] deals to [enemy] it passes.
func dash_damage(ability: DashAbility, _enemy: Enemy) -> int:
	return ability.damage


## Plays out a planned move active: hits (and maybe knocks aside) every enemy on the line, then blinks to [target]
## (or the nearest free tile, if something has landed on it since). Boosts it grants last the rest of the turn.
func resolve_dash(ability: DashAbility, target: int) -> void:
	if not _spend(ability):
		return
	player.popup(ability.display_name, Color(1.0, 0.85, 0.4))
	var line := dash_line(player.tile_id, target)
	if ability.damage > 0:
		var before: Dictionary[Enemy, Vector2i] = {}
		var deaths: Array[Enemy] = []
		for enemy in dash_victims(player.tile_id, target):
			before[enemy] = Vector2i(enemy.hp, enemy.shield)
			_damage_enemy(enemy, dash_damage(ability, enemy), 2 if ability.ignore_defence else 1)
			if enemy.is_dead():
				deaths.append(enemy)
			elif ability.knockback:
				await knock_aside(enemy, line, [target])
		for dead in deaths:
			_reward_kill(dead)
			dead.play_death()
		if deaths.size() > 0:
			await deaths[0].died
		for dead in deaths:
			await _dismiss_minions(dead)
		await _react_to_damage(before)
	if board.get_piece(target) != null:
		target = board.nearest_free(target)
	if target != -1 and target != player.tile_id:
		await player.teleport_to(target)
	SaveManager.run_data.count(&"teleport")
	_boosts.append_array(ability.grants_boosts())
	await get_tree().create_timer(Anim.t(0.2)).timeout


## Shoves [piece] (on [line]) onto a free tile beside the line - ahead and to the side first - avoiding [keep_clear].
## Stays put if there's no room. Awaitable.
func knock_aside(piece: BoardPiece, line: Array[int], keep_clear: Array[int] = []) -> void:
	var at := line.find(piece.tile_id)
	if at < 0:
		return
	var cell := Hex.coords(piece.tile_id)
	var ahead := (Hex.coords(line[at + 1]) - cell) if at + 1 < line.size() else (cell - Hex.coords(line[at - 1]))
	var forward := Hex.NEIGHBOUR_OFFSETS.find(ahead)
	if forward < 0:
		return
	for side in [1, 5, 2, 4]:
		var tile_id := Hex.id(cell + Hex.NEIGHBOUR_OFFSETS[(forward + side) % 6])
		if board.is_walkable(tile_id) and board.get_piece(tile_id) == null and not line.has(tile_id) and not keep_clear.has(tile_id):
			piece.popup(tr("POPUP_KNOCKED_ASIDE"), Color(0.85, 0.85, 0.9))
			await piece.shove_to(tile_id)
			return


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


## The enemies' turn at the end of the round: [method _enemy_phase], then [method _end_round].
func _enemy_turn() -> void:
	await _enemy_phase()
	if _player_dead():
		return
	await _end_round()


## The "enemies go first" button was pressed: only possible while nothing is planned.
func _enemies_first_pressed() -> void:
	if state != State.PLAN or not actions.is_empty() or _editing or _enemies_acted:
		return
	selected.clear()
	_armed.clear()
	_dashing = null
	if await _enemies_go_first():
		_set_state(State.PLAN)
		_replan()


## Shows the "enemies go first" button beside the dice row while the turn is untouched - nothing planned or edited, and
## the enemies haven't gone yet.
func _refresh_order_button() -> void:
	var row_end := dice_tray.row_end_screen()
	if state == State.PLAN and _end_state != null and actions.is_empty() and not _editing and not _enemies_acted and row_end.x >= 0.0:
		_order_prompt.show_at(row_end)
	else:
		_order_prompt.hide_button()


## The player let the enemies go first: they take their turn now, with the dice just rolled held to block. Those that
## attack can't retaliate this round, and there is no enemy turn after the player's. Returns false if the round ended
## here (the player died or lost the turn to a stun, or the level cleared).
func _enemies_go_first() -> bool:
	_enemies_acted = true
	_enemy_log.clear()
	_set_state(State.ENEMY_TURN)
	_refresh()
	await _enemy_phase()
	if _player_dead():
		await _game_over()
		return false
	if board.get_enemies().is_empty():
		await _clear_level()
		return false
	_enemy_log.clear()
	# Stunned by the enemies' blows: the turn is lost before it starts
	if player.stunned:
		await _offer_stun_cure()
	if _stun_blocks(player):
		await get_tree().create_timer(Anim.t(0.5)).timeout
		await _finish_turn()
		return false
	return true


## Poison bites, then each living enemy, nearest first: move (Gloomhaven rules), then attack unless it struck back this
## turn - or whatever its boss behaviour does instead. Stunned enemies lose their turn, and their stuns end with it.
func _enemy_phase() -> void:
	await _poison_tick()
	for enemy in _enemy_order():
		if not is_instance_valid(enemy) or enemy.is_dead():
			continue
		if _stun_blocks(enemy):
			enemy.stunned = false
			await get_tree().create_timer(Anim.t(0.3)).timeout
			continue
		if enemy.data.behaviour:
			await enemy.data.behaviour.take_turn(self, enemy)
		else:
			await standard_enemy_turn(enemy)
		if _player_dead():
			return
		await get_tree().create_timer(Anim.t(0.15)).timeout


## Every enemy gets a defence segment back; bosses get their end-of-round rules (an ice shield recovering, say).
func _end_round() -> void:
	for enemy in board.get_enemies():
		enemy.recover_defence()
		if enemy.data.behaviour:
			await enemy.data.behaviour.end_of_round(self, enemy)
		enemy.damaged_this_round = false


## The usual enemy turn: move into position (Gloomhaven rules), then attack.
func standard_enemy_turn(enemy: Enemy) -> void:
	var path := EnemyAI.find_path(enemy, board, player.tile_id)
	if path.size() > 0:
		await enemy.move_along(path)
	await enemy_strikes(enemy)


## The enemy's attacks for its turn ([member EnemyData.attacks_per_turn], each blocked separately) if the player is in
## reach - each strike it made back this round used up one.
func enemy_strikes(enemy: Enemy) -> void:
	for i in maxi(enemy.data.attacks_per_turn - _retaliated.count(enemy), 0):
		if _player_dead() or not enemy.can_hit(player.tile_id):
			return
		await enemy_attack(enemy)


## Poisoned enemies take 1 damage each.
func _poison_tick() -> void:
	var deaths: Array[Enemy] = []
	var before: Dictionary[Enemy, Vector2i] = {}
	for enemy in board.get_enemies():
		if enemy.poisoned:
			before[enemy] = Vector2i(enemy.hp, enemy.shield)
			_damage_enemy(enemy, 1)
			if enemy.is_dead():
				deaths.append(enemy)
	for dead in deaths:
		_reward_kill(dead)
		dead.play_death()
	if deaths.size() > 0:
		await deaths[0].died
	for dead in deaths:
		await _dismiss_minions(dead)
	await _react_to_damage(before)


## Enemies on fire take what's left of the burn at the start of the round, then it goes out.
func _burn_tick() -> void:
	var deaths: Array[Enemy] = []
	var before: Dictionary[Enemy, Vector2i] = {}
	for enemy in board.get_enemies():
		if enemy.burn > 0:
			before[enemy] = Vector2i(enemy.hp, enemy.shield)
			enemy.popup(tr("POPUP_BURNING"), Color(1.0, 0.55, 0.2))
			_damage_enemy(enemy, enemy.burn)
			enemy.burn = 0
			if enemy.is_dead():
				deaths.append(enemy)
	for dead in deaths:
		_reward_kill(dead)
		dead.play_death()
	if deaths.size() > 0:
		await deaths[0].died
	for dead in deaths:
		await _dismiss_minions(dead)
	await _react_to_damage(before)


## Hurts [enemy], counting the health it actually lost as damage dealt. [shield_multiplier]: shield taken per point (2
## for armour piercing attacks).
func _damage_enemy(enemy: Enemy, amount: int, shield_multiplier: int = 1) -> void:
	SaveManager.run_data.damage_dealt += mini(Enemy.health_loss(enemy.defence, enemy.shield, amount, shield_multiplier), enemy.hp)
	enemy.take_damage(amount, shield_multiplier)


## Gold for killing an enemy of [data]: its own gold (higher for tougher biomes and bosses), plus a share per level
## entered this run.
static func kill_gold(data: EnemyData) -> int:
	return roundi(data.gold * (1.0 + GOLD_PER_DEPTH * maxi(SaveManager.run_data.path.size() - 1, 0)))


func _reward_kill(enemy: Enemy) -> void:
	var run := SaveManager.run_data
	var gold := kill_gold(enemy.data)
	run.add_gold(gold)
	run.enemies_defeated += 1
	run.progress_changed = true
	if enemy.base.attack_range > 1:
		run.count(&"ranged_kill")
	if enemy.data.is_boss:
		run.bosses_defeated += 1
		run.count(StringName("boss_defeated:%s" % enemy.base.id))
		# Down to the last health point with a pool below its cap
		if run.health == 1 and run.dice.size() < run.max_dice:
			run.count(&"clutch_boss_kill")
	player.popup(tr("POPUP_GOLD") % gold, Color(1.0, 0.85, 0.3))


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
		if is_die_available(result.index) and result.category() == DieFace.Category.DEFENCE:
			held.append(result.index)
	return held


## Lets the player pick held defence dice against [enemy]'s rolled [damage] (or spends them automatically, if
## set), shown as entry [log_index] in the turn plan. Returns the total defence chosen; sets [_dodged] if a dodge
## face was among them.
func _choose_block(enemy: Enemy, damage: int, log_index: int) -> int:
	var held := _held_dice()
	if held.is_empty() and _block_actives(enemy).is_empty():
		return 0
	var chosen: Array[int] = []
	if SaveManager.settings_data.auto_spend_defence and held.size() > 0:
		chosen = _auto_block(held, damage)
	else:
		_blocking = enemy
		_blocking_damage = damage
		_block_selected.clear()
		_enemy_log[log_index] = [tr("LOG_HITS_YOU") % [enemy.data.display_name, damage], tr("LOG_BLOCK_OR_TAKE")]
		_refresh()
		enemy.popup("!", Color(1.0, 0.6, 0.2))
		var blockers := _block_actives(enemy)
		block_prompt.show_prompt(enemy.data.display_name, damage, blockers.map(func(a: Ability): return a.display_name))
		_block_with = null
		_block_offer = blockers
		await _block_confirmed
		chosen = _block_selected.duplicate()
		_blocking = null
		_block_selected.clear()
		await block_prompt.hide_prompt()
		if _block_with and _block_with.redirects():
			var target := await _pick_redirect(enemy)
			if target and _spend(_block_with):
				_redirect_to = target
				player.popup(_block_with.display_name, Color(1.0, 0.85, 0.4))
				_refresh()
				return AttackContext.BLOCK_ALL
		elif _block_with and _spend(_block_with):
			player.popup(_block_with.display_name, Color(1.0, 0.85, 0.4))
			_refresh()
			return AttackContext.BLOCK_ALL
	_spent.append_array(chosen)
	_dodged = chosen.any(func(i: int): return results[i].face().has(Symbol.Type.DODGE))
	_refresh()
	return dice_value(chosen)


## Block actives ready to use against [enemy]'s hit, for the block prompt. A redirect is only offered against an enemy
## striking back, with somewhere to send the hit.
func _block_actives(enemy: Enemy) -> Array[Ability]:
	_sync_uses()
	return actives_of(Ability.Use.BLOCK).filter(func(a: Ability): return _uses.get(a.id, 0) > 0 \
			and (not a.redirects() or (_striking_back and redirect_targets(enemy).size() > 0)))


## Enemies [striker]'s hit can be redirected to: within as many tiles of the player as [striker] stands, in line of sight.
func redirect_targets(striker: Enemy) -> Array[Enemy]:
	var reach := Hex.distance(Hex.coords(player.tile_id), Hex.coords(striker.tile_id))
	var targets: Array[Enemy] = []
	for enemy in board.get_enemies():
		if board.in_attack_range(player.tile_id, enemy.tile_id, reach):
			targets.append(enemy)
	return targets


## Lets the player click the enemy [striker]'s hit goes to (or the only one there is). Returns it.
func _pick_redirect(striker: Enemy) -> Enemy:
	var targets := redirect_targets(striker)
	if targets.size() <= 1:
		return targets[0] if targets.size() == 1 else null
	_redirect_targets = targets
	_hint_note = ""
	_refresh()
	var ids: Array[int] = []
	for target in targets:
		ids.append(target.tile_id)
	board.highlight(ids, HexTile.Highlight.TARGET)
	var picked: Enemy = await _redirect_picked
	_redirect_targets.clear()
	board.clear_highlights()
	_refresh()
	return picked


## Block prompt: the player chose the [index]th block active offered.
func _block_with_ability(index: int) -> void:
	_block_selected.clear()
	_block_with = _block_offer[index] if index < _block_offer.size() else null
	_block_confirmed.emit()


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
# Bosses
# ===========================================================================================================================================


## Spawns [boss]'s minion on each of [tiles], popping in one after another. Awaitable.
func summon(boss: Enemy, tiles: Array[int]) -> void:
	boss.popup(tr("POPUP_SUMMON"), Color(0.75, 0.55, 1.0))
	for tile_id in tiles:
		board.spawn_minion(boss, tile_id)
		await get_tree().create_timer(Anim.t(0.2)).timeout
	_sync_enemies()
	await get_tree().create_timer(Anim.t(0.3)).timeout


## [boss] charges through [path]; every piece along it takes an attack of its attack value and is knocked aside onto a
## free tile beside the path. It ends on the last free tile of the path (or stays put if there is none). Awaitable.
func charge(boss: Enemy, path: Array[int]) -> void:
	var line: Array[int] = [boss.tile_id]
	line.append_array(path)
	await boss.charge_along(path, func(tile_id: int):
		var piece := board.get_piece(tile_id)
		await _hit_piece(boss, tile_id, boss.data.attack, "charge")
		if is_instance_valid(piece) and piece == board.get_piece(tile_id) and not _player_dead() and not (piece is Enemy and (piece as Enemy).is_dead()):
			await knock_aside(piece, line))


## [boss] bursts into flames: [damage] to every piece on the tiles up to [reach] along the six straight lines from it,
## which stop at walls and obstacles. Awaitable.
func flame_burst(boss: Enemy, reach: int, damage: int) -> void:
	boss.popup(tr("POPUP_FLAME_BURST"), Color(1.0, 0.55, 0.2))
	var tiles: Array[int] = []
	for offset in Hex.NEIGHBOUR_OFFSETS:
		var cell := Hex.coords(boss.tile_id)
		for step in reach:
			cell += offset
			var tile_id := Hex.id(cell)
			if not board.has_tile(tile_id) or board.blocks_sight(tile_id):
				break
			tiles.append(tile_id)
	board.highlight(tiles, HexTile.Highlight.TARGET)
	await get_tree().create_timer(Anim.t(0.6)).timeout
	for tile_id in tiles:
		board.spawn_terrain_effect(tile_id)
	for tile_id in tiles:
		if _player_dead():
			break
		await _hit_piece(boss, tile_id, damage, "flames")
	board.clear_highlights()


## An attack of [damage] by [attacker] on whatever stands on [tile_id]: the player (who may block) or another enemy.
func _hit_piece(attacker: Enemy, tile_id: int, damage: int, note: String) -> void:
	var piece := board.get_piece(tile_id)
	if piece == player:
		var ctx := AttackContext.new(attacker, player, damage, 0)
		ctx.source_note = note
		await hit_player(attacker, ctx, false)
	elif piece is Enemy and piece != attacker:
		await _hit_enemy(piece, damage)


## A boss's attack landing on one of its own side: defence applies, no gold or kill counted.
func _hit_enemy(victim: Enemy, damage: int) -> void:
	if victim.is_dead():
		return
	victim.take_damage(damage)
	if victim.is_dead():
		victim.play_death()
		await victim.died
	else:
		await get_tree().create_timer(Anim.t(0.2)).timeout


## A boss that dies takes the minions it summoned with it (no gold).
func _dismiss_minions(boss: Enemy) -> void:
	var followers: Array[Enemy] = []
	for follower in boss.minions():
		if not follower.dying:
			followers.append(follower)
	for follower in followers:
		follower.hp = 0
		follower.preview_hp = 0
		follower.play_death()
	# They all fall on the same frame in the order they started, so the last one's death means every one is done
	if followers.size() > 0:
		await followers.back().died


## Lets bosses react to damage they took: [before] is each damaged enemy's health and shield (x, y) as they were.
func _react_to_damage(before: Dictionary[Enemy, Vector2i]) -> void:
	for target in before:
		if is_instance_valid(target) and not target.is_dead() and target.data.behaviour \
				and (target.hp < before[target].x or target.shield < before[target].y):
			await target.data.behaviour.on_damaged(self, target, before[target].x)


# ===========================================================================================================================================
# Planning
# ===========================================================================================================================================


## Re-simulates the plan from the start of the turn, dropping invalid actions, and updates all previews.
func _replan() -> void:
	var insert_at := _edit_index if _editing else actions.size()
	_hint_note = ""
	_sync_uses()
	var sim := TurnState.new(player.tile_id, board.get_enemies())
	sim.uses = _uses.duplicate()
	var valid: Array[PlannedAction] = []
	_insert_state = null
	for i in actions.size():
		if i == insert_at:
			_insert_state = sim.copy()
		if actions[i].simulate(sim, self):
			valid.append(actions[i])
	actions = valid
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
	# Armed actives the plan can no longer pay for drop out
	_armed = _armed.filter(func(a: Ability): return _insert_state.uses.get(a.id, 0) > 0)
	if _dashing and _insert_state.uses.get(_dashing.id, 0) <= 0:
		_dashing = null
	if _dashing:
		_move_ctx = dash_context(_insert_state, _dashing)
		_reachable = board.find_reachable(_move_ctx)
	match _selected_category():
		DieFace.Category.MOVE:
			_move_ctx = move_context(_insert_state, selected)
			_reachable = board.find_reachable(_move_ctx)
		DieFace.Category.ATTACK:
			for enemy in _living_enemies(_insert_state):
				if board.in_attack_range(_insert_state.player_tile, enemy.tile_id, attack_range(selected)):
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
			if result != buff and not result.face().is_buff() and result.can_buff() and result.category() == buff.face().buff_category():
				result.bonus += 1
				dice_tray.get_die(result.index).set_face_display(result.face_index, result.display_face())
		buff_die.set_state(Die3D.State.USED)
		await get_tree().create_timer(Anim.t(0.25)).timeout
	# Passive abilities that change rolled dice (e.g. +1 to every defence die)
	for ability in abilities():
		var changed := false
		for result in results:
			if not _auto_used.has(result.index) and ability.modify_result(result):
				dice_tray.get_die(result.index).set_face_display(result.face_index, result.display_face())
				changed = true
		if changed:
			player.popup(ability.display_name, Color(1.0, 0.85, 0.4))
			await get_tree().create_timer(Anim.t(0.3)).timeout


# ===========================================================================================================================================
# Previews
# ===========================================================================================================================================


func _refresh() -> void:
	if not board:
		return
	_refresh_dice()
	_refresh_board()
	_refresh_list()
	_refresh_order_button()


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
	if _redirect_targets.size() > 0:
		var ids: Array[int] = []
		for target in _redirect_targets:
			ids.append(target.tile_id)
		board.highlight(ids, HexTile.Highlight.TARGET)
		board.select(hovered_tile)
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
			# A move active hits the enemies on its line
			if _dashing and _dashing.damage > 0:
				var hit: Array[int] = []
				for enemy in dash_victims(_insert_state.player_tile, hovered_tile):
					hit.append(enemy.tile_id)
				board.highlight(hit, HexTile.Highlight.TARGET)
	match _selected_category():
		DieFace.Category.ATTACK:
			var out_of_range: Array[int] = []
			for enemy in _living_enemies(_insert_state):
				if not _targets.has(enemy.tile_id):
					out_of_range.append(enemy.tile_id)
			board.highlight(out_of_range, HexTile.Highlight.INVALID)
			var preview := _hovered_attack()
			if preview:
				board.highlight(preview.aoe_tiles, HexTile.Highlight.VALID)
			board.highlight(_targets, HexTile.Highlight.TARGET)
	board.select(hovered_tile)


## Planned HP and statuses for the overhead info; enemies killed by the plan are darkened.
func _refresh_enemies(planning: bool) -> void:
	for enemy in board.get_enemies():
		if not planning or _end_state == null:
			enemy.preview_hp = enemy.hp
			enemy.preview_shield = enemy.shield
			enemy.preview_defence = enemy.defence
			enemy.preview_skips_attack = state == State.ENEMY_TURN and _retaliated.count(enemy) >= enemy.data.attacks_per_turn
			enemy.preview_stunned = enemy.stunned
			enemy.preview_poisoned = enemy.poisoned
			enemy.preview_burning = enemy.burn > 0
			enemy.cutout.flash = Color(0, 0, 0, 0)
			_update_retaliation(enemy)
			continue
		enemy.preview_hp = _end_state.enemy_hp.get(enemy, enemy.hp)
		enemy.preview_shield = _end_state.enemy_shield.get(enemy, enemy.shield)
		enemy.preview_defence = _end_state.enemy_defence.get(enemy, enemy.defence)
		# No enemy turn follows once the enemies have gone first, so nothing is lost by retaliating
		enemy.preview_skips_attack = not _enemies_acted and _end_state.retaliated.count(enemy) >= enemy.data.attacks_per_turn
		enemy.preview_stunned = _end_state.stunned.has(enemy)
		enemy.preview_poisoned = _end_state.poisoned.has(enemy)
		enemy.preview_burning = _end_state.burning.has(enemy)
		_update_retaliation(enemy)
	# Hovering a target previews the selected attack (and any area hits) on top of the plan
	var preview := _hovered_attack()
	if planning and preview:
		var target := preview.target as Enemy
		_preview_damage(target, preview.damage(), preview.shield_multiplier())
		for tile_id in preview.aoe_tiles:
			var other := board.get_piece(tile_id) as Enemy
			if other and _end_state.is_alive(other):
				_preview_damage(other, preview.split(other, 0).damage(), preview.shield_multiplier())
	for enemy in board.get_enemies():
		if planning and _end_state:
			enemy.cutout.flash = Color(0.1, 0.08, 0.1, 0.6 if enemy.preview_hp <= 0 else 0.0)


## Retaliation badge: shown on the player's turn, lit if [enemy] would strike back if attacked now.
func _update_retaliation(enemy: Enemy) -> void:
	enemy.show_retaliation = not results.is_empty() and (state == State.ROLL or state == State.PLAN or state == State.RESOLVE)
	enemy.can_retaliate = not (enemy.stunned or enemy.preview_stunned) and can_retaliate(enemy)


## Takes [amount] off the planned defence, shield ([shield_multiplier] per point) and health shown for [enemy].
func _preview_damage(enemy: Enemy, amount: int, shield_multiplier: int = 1) -> void:
	var past := Enemy.past_defence(enemy.preview_defence, amount, shield_multiplier)
	enemy.preview_defence -= Enemy.defence_loss(enemy.preview_defence, amount, shield_multiplier)
	var through := Enemy.through_shield(enemy.preview_shield, past, shield_multiplier)
	enemy.preview_shield -= Enemy.shield_loss(enemy.preview_shield, past, shield_multiplier)
	enemy.preview_hp -= through


## The selected attack dice aimed at the hovered target, or null.
func _hovered_attack() -> AttackContext:
	if state != State.PLAN or _selected_category() != DieFace.Category.ATTACK or not _targets.has(hovered_tile):
		return null
	return player_attack_context(board.get_piece(hovered_tile), selected, _armed, _first_planned(), _insert_state.player_tile, _insert_state.boosts)


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
		elif action is DashAction:
			_add_teleport_arrows(from, action.target)
			from = action.target
		elif action is AttackAction:
			_add_attack_arc(from, action.enemy.tile_id)
	if _move_ctx and _move_ctx.teleport and _reachable.has(hovered_tile):
		_add_teleport_arrows(_insert_state.player_tile, hovered_tile)
	if _hovered_attack():
		_add_attack_arc(_insert_state.player_tile, hovered_tile)


## Planned ranged attack: the same red arc, drawn in full (nothing for melee).
func _add_attack_arc(from: int, to: int) -> void:
	if Hex.distance(Hex.coords(from), Hex.coords(to)) <= 1:
		return
	var arc := AttackArc.new()
	_path_dots.add_child(arc)
	arc.setup(board.cell_top_local(Hex.coords(from)), board.cell_top_local(Hex.coords(to)))


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
	action_list.set_header(tr("HUD_TURN_HEADER") % [turn_number, tr(STATE_NAMES[state])])
	action_list.set_commit_enabled(state == State.PLAN)
	var buttons: Array[Dictionary] = []
	for ability in plan_actives():
		var left: int = uses_preview().get(ability.id, 0)
		var armed := _armed.has(ability) or _dashing == ability
		buttons.append({
			"text": "%s  (%s)" % [ability.display_name.to_upper(), active_status(ability)],
			"tooltip": ability.description,
			"enabled": state == State.PLAN and (left > 0 or armed),
			"armed": armed,
		})
	action_list.set_abilities(buttons)
	action_list.set_hint(_hint())
	_refresh_attack_preview()


## The attack being planned (selected attack dice and armed actives), aimed at the hovered target if any.
func _refresh_attack_preview() -> void:
	if attack_preview == null:
		return
	var attacking := _selected_category() == DieFace.Category.ATTACK
	if state != State.PLAN or not (attacking or (selected.is_empty() and _armed.size() > 0)):
		attack_preview.hide_preview()
		return
	var dice: Array[int] = []
	if attacking:
		dice.assign(selected)
	var target: Enemy = board.get_piece(hovered_tile) as Enemy if _targets.has(hovered_tile) else null
	var chosen: Array[DieResult] = []
	for i in dice:
		chosen.append(results[i])
	var ctx := player_attack_context(target, dice, _armed, _first_planned(), _insert_state.player_tile, _insert_state.boosts)
	# An ice shield counts as health to get through, and so does defence unless the attack pierces
	var target_hp: int = 0
	if target:
		target_hp = _end_state.enemy_hp.get(target, target.hp) + _end_state.enemy_shield.get(target, target.shield)
		if not ctx.pierces():
			target_hp += _end_state.enemy_defence.get(target, target.defence)
	attack_preview.show_attack(chosen, ctx, _armed, target, target_hp)


## True if an attack added to the plan now would be the turn's first.
func _first_planned() -> bool:
	return _insert_state != null and _insert_state.attacks == 0


func _hint() -> String:
	if _redirect_targets.size() > 0:
		return tr("HINT_CHOOSE_REDIRECT_TARGET")
	if _blocking:
		return tr("HINT_BLOCK_OR_TAKE_HIT") % [_blocking.data.display_name, _blocking_damage]
	if _hint_note != "" and state == State.PLAN:
		return _hint_note
	match state:
		State.ROLL:
			return tr("HINT_ROLLING")
		State.RESOLVE:
			return tr("HINT_RESOLVING")
		State.ENEMY_TURN:
			if results.is_empty() and actions.is_empty():
				return tr("HINT_STUNNED_LOSE_TURN")
			return tr("HINT_ENEMY_TURN")
		State.LEVEL_CLEAR:
			return clear_hint
		State.GAME_OVER:
			return tr("HINT_DEFEATED")
	var armed_names := " + ".join(_armed.map(func(a: Ability): return a.display_name))
	var armed_note := "  " + tr("HINT_ARMED_NOTE") % armed_names if _armed.size() > 0 else ""
	match _selected_category():
		DieFace.Category.ATTACK:
			var range_note := "  " + tr("HINT_RANGE_LOST_NOTE") if is_range_lost(selected) else ""
			return tr("HINT_ATTACK") % [dice_value(selected), attack_range(selected), range_note, armed_note]
	if selected.size() > 0:
		if is_teleport_lost(selected):
			return tr("HINT_MOVE_TELEPORT_LOST") % dice_value(selected)
		if _move_ctx and _move_ctx.teleport:
			return tr("HINT_TELEPORT") % _move_ctx.budget
		var frozen_note := " " + tr("HINT_FROZEN_NOTE") % dice_value(selected) if player.frozen and _move_ctx and not _move_ctx.teleport else ""
		return tr("HINT_MOVE") % [_move_ctx.budget if _move_ctx else dice_value(selected), frozen_note]
	if _dashing:
		return tr("HINT_DASH") % [_dashing.display_name, _dashing.reach]
	if _editing:
		return tr("HINT_EDITING")
	if _armed.size() > 0:
		return tr("HINT_ARMED") % armed_names
	if _enemies_acted:
		return tr("HINT_ENEMIES_ACTED")
	if actions.is_empty():
		return tr("HINT_PLAN_OR_ENEMIES_FIRST")
	return tr("HINT_PLAN")


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
	hovered_tile = -1
	hovered_die = -1
	results.clear()
	actions.clear()
	selected.clear()
	_end_state = null
	_editing = null
	_set_state(State.IDLE)
	if _order_prompt:
		_order_prompt.hide_button()
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
	# Extra dice from abilities (e.g. armour) come after the pool, so pool indices stay put
	for ability in abilities():
		types.append_array(ability.extra_dice())
	return types


func _design() -> DieDesign:
	if debug_pool.size() > 0 and debug_design:
		return debug_design
	return Database.get_content("die_designs", SaveManager.progression_data.die_design)
