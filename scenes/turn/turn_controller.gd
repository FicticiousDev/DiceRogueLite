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

enum State { IDLE, ROLL, PLAN, RESOLVE, ENEMY_TURN, LEVEL_CLEAR, GAME_OVER }

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
var clear_hint: String = "Level clear!"

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
## Active ability uses left this level (ability id -> uses); planning simulates its own copy in TurnState.uses
var _uses: Dictionary = {}
## Planning: attack actives armed for the next attack
var _armed: Array[Ability] = []
## Player attacks resolved this turn (the first can be a crit, see AttackContext.first_attack)
var _attacks_made: int = 0
## Block prompt: the block active the player chose, if any
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
	# Active ability uses are per level; setup runs for every level
	_uses = new_uses()
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
	_create_previews()


## Rolls the pool and starts planning. [new_turn] false re-rolls the current turn (debug).
func start_turn(new_turn: bool = true) -> void:
	if new_turn:
		turn_number += 1
		SaveManager.run_data.turns += 1
	results.clear()
	_end_state = null
	actions.clear()
	selected.clear()
	_auto_used.clear()
	_spent.clear()
	_enemy_log.clear()
	_armed.clear()
	_editing = null
	_attacks_made = 0
	# Levels without enemies are clear from the start
	if board.get_enemies().is_empty():
		_set_state(State.LEVEL_CLEAR)
		_refresh()
		return
	# Player status effects come first: poison bites, fire burns, a stun (from the enemy turn) costs the whole turn
	if player.poisoned:
		player.popup("POISON", Color(0.5, 1.0, 0.4))
		await _hurt_player(1, "-1")
		if _player_dead():
			await _game_over()
			return
	if player.burn > 0:
		var burn := player.burn
		player.burn = 0
		player.popup("BURNING", Color(1.0, 0.55, 0.2))
		await _hurt_player(burn, "-%d" % burn)
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


## Uses per level of every active, for a fresh level. Two copies of an item add up.
func new_uses() -> Dictionary:
	var uses := {}
	for ability in abilities():
		if ability.active:
			uses[ability.id] = uses.get(ability.id, 0) + ability.uses_per_level
	return uses


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
## [first]: it's the turn's first attack). [enemy] may be null to preview an attack with no target yet (no defence).
func player_attack_context(enemy: Enemy, dice: Array[int], used: Array[Ability] = [], first: bool = false) -> AttackContext:
	var ctx := AttackContext.new(player, enemy, 0, enemy.data.defence if enemy else 0)
	ctx.first_attack = first
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
	elif ability.use == Ability.Use.ACTION and _insert_state.uses.get(ability.id, 0) > 0:
		_finish_edit()
		actions.append(AbilityAction.new(ability))
		_replan()


## Stunned at the start of a turn: offers an unused action active that removes stun, which saves the turn.
func _offer_stun_cure() -> void:
	_sync_uses()
	for ability in actives_of(Ability.Use.ACTION):
		if ability.cures_stun() and _uses.get(ability.id, 0) > 0:
			if await confirm_dialog.ask("STUNNED", "You're stunned and will lose this turn.\nUse %s to shake it off?" % ability.display_name):
				spend_use(ability, _uses)
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
	player.popup("CURED" if cured else "No effect", Color(0.5, 1.0, 0.4))
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
	elif event.is_action_pressed("cancel") and (selected.size() > 0 or _editing or _armed.size() > 0):
		get_viewport().set_input_as_handled()
		_cancel()


func _click_die(index: int) -> void:
	var die := dice_tray.get_die(index)
	var result := results[index]
	if not is_die_available(index) or result.category() == DieFace.Category.DEFENCE:
		die.shake(dice_tray.camera.global_basis.x * 0.1 * dice_tray._scale)
		if result.category() == DieFace.Category.DEFENCE:
			_hint_note = "Defence dice aren't planned: they're kept to block hits this turn."
			_refresh()
		return
	if selected.has(index):
		selected.erase(index)
	else:
		# Only dice of one kind combine into an action; picking another kind starts a new selection
		if selected.size() > 0 and results[selected[0]].category() != result.category():
			selected.clear()
		selected.append(index)
	_replan()


func _click_tile(tile_id: int) -> void:
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
		player.frozen_next = false
		player.burn = 0
		await dice_tray.clear()
		# The turn that clears the level still heals if it was taken without damage
		if _damage_taken == 0:
			await heal_player(1)
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
	if _damage_taken == 0:
		await heal_player(1)
	start_turn()


## Restores [amount] HP (up to max). If poisoned, the heal cures the poison instead.
func heal_player(amount: int) -> void:
	var run := SaveManager.run_data
	if player.poisoned:
		# Curing poison takes the place of the heal
		player.poisoned = false
		player.popup("CURED", Color(0.5, 1.0, 0.4))
	elif run.health < run.max_health:
		run.health = mini(run.health + amount, run.max_health)
		player.popup("+%d" % amount, Color(0.4, 1.0, 0.45))
	else:
		return
	await get_tree().create_timer(Anim.t(0.4)).timeout


## Unblocked damage to the player, offering a last stand if it would kill them. Returns true if it landed.
func _hurt_player(damage: int, text: String) -> bool:
	_damage_taken += damage
	if damage >= SaveManager.run_data.health and await _last_stand():
		player.popup("SACRIFICED", Color(1.0, 0.6, 0.3))
		return false
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
	piece.popup("STUNNED", Color(1.0, 0.8, 0.3))
	return true


## Player attacks [enemy]; it strikes first if it always attacks first, otherwise retaliates straight after if it
## survives. Either way the player may block with held defence dice.
func resolve_attack(enemy: Enemy, dice: Array[int], wanted: Array[Ability]) -> void:
	if not is_instance_valid(enemy) or enemy.is_dead():
		return
	# The target can have gone out of reach since the plan was made (a boss teleporting away)
	if not board.in_attack_range(player.tile_id, enemy.tile_id, attack_range(dice)):
		player.popup("OUT OF RANGE", Color(0.8, 0.8, 0.85))
		await get_tree().create_timer(Anim.t(0.3)).timeout
		return
	var enemy_first := enemy.data.attacks_first and not player_strikes_first()
	if enemy_first and not _stun_blocks(enemy):
		if await enemy_attack(enemy):
			_retaliated.append(enemy)
		if _player_dead():
			return
	var arc := await board.show_attack_arc(player, enemy)
	await player.lunge(enemy.position)
	var ctx := player_attack_context(enemy, dice, spend_uses(wanted, _uses), _attacks_made == 0)
	_attacks_made += 1
	if ctx.notes.size() > 0:
		player.popup(" + ".join(ctx.notes), Color(1.0, 0.85, 0.4))
	if ctx.crit:
		SaveManager.run_data.crits += 1
	# Health and shield before the hit, for bosses that react to losing them
	var before: Dictionary[Enemy, Vector2i] = { enemy: Vector2i(enemy.hp, enemy.shield) }
	_damage_enemy(enemy, ctx.damage())
	if arc:
		arc.fade_out()
	# Area hits; only the main target retaliates
	var hit: Array[Enemy] = [enemy]
	for tile_id in ctx.aoe_tiles:
		var other := board.get_piece(tile_id) as Enemy
		if other and not other.is_dead():
			before[other] = Vector2i(other.hp, other.shield)
			_damage_enemy(other, ctx.split(other, other.data.defence).damage())
			hit.append(other)
	for target in hit:
		if not target.is_dead():
			if ctx.stun and target.data.stun_immune:
				target.popup("IMMUNE", Color(0.8, 0.8, 0.85))
			elif ctx.stun and not target.stunned:
				target.stunned = true
				target.popup("STUNNED", Color(1.0, 0.8, 0.3))
			if ctx.poison and not target.poisoned:
				target.poisoned = true
				target.popup("POISONED", Color(0.5, 1.0, 0.4))
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
		if await enemy_attack(enemy):
			_retaliated.append(enemy)
	await get_tree().create_timer(Anim.t(0.25)).timeout


## [enemy] attacks the player if it can hit them. The roll is shown in the turn plan and the player may block
## with held defence dice. Returns true if it attacked.
func enemy_attack(enemy: Enemy) -> bool:
	if not enemy.can_hit(player.tile_id):
		return false
	await hit_player(enemy, AttackContext.roll_enemy(enemy, player))
	return true


## [enemy]'s [ctx] lands on the player: through their abilities, then the block decision with held defence dice, then
## the damage and any status the hit gives. [swing]: draws a ranged arc and lunges - off for charges and flames, which
## aren't a swing at the player.
func hit_player(enemy: Enemy, ctx: AttackContext, swing: bool = true) -> void:
	apply_incoming(ctx)
	# A ranged attack draws its arc first and keeps it up through the block decision
	var arc: AttackArc = null
	if swing:
		arc = await board.show_attack_arc(enemy, player)
	var log_index := _enemy_log.size()
	_enemy_log.append(["", ""])
	_dodged = false
	if not ctx.miss and ctx.damage() > 0:
		ctx.defence += await _choose_block(enemy, ctx.damage(), log_index)
	var damage := ctx.damage()
	_enemy_log[log_index] = _attack_log(enemy, ctx)
	_refresh()
	if swing:
		await enemy.lunge(player.position)
	if ctx.miss:
		SaveManager.run_data.misses += 1
		player.popup("MISS", Color(0.8, 0.8, 0.8))
	elif ctx.negated:
		player.popup(" + ".join(ctx.notes).to_upper(), Color(0.45, 0.7, 1.0))
	elif damage == 0:
		player.popup("DODGED" if _dodged else "BLOCKED", Color(0.45, 0.7, 1.0))
	elif await _hurt_player(damage, ("CRIT -%d" if ctx.crit else "-%d") % damage) and not _player_dead():
		# A sacrificed hit still counts as damage taken (no heal) but doesn't pass on status effects
		_apply_hit_effects(enemy, damage)
	if arc:
		arc.fade_out()
	await get_tree().create_timer(Anim.t(0.35)).timeout


## The statuses [enemy]'s hit gives the player, for [damage] that got through.
func _apply_hit_effects(enemy: Enemy, damage: int) -> void:
	if enemy.data.applies_stun and not player.stunned:
		if player_prevents(&"stun"):
			player.popup("STUN RESISTED", Color(0.8, 0.8, 0.85))
		else:
			player.stunned = true
			player.popup("STUNNED", Color(1.0, 0.8, 0.3))
	if enemy.data.applies_poison and not player.poisoned:
		if player_prevents(&"poison"):
			player.popup("POISON RESISTED", Color(0.8, 0.8, 0.85))
		else:
			player.poisoned = true
			player.popup("POISONED", Color(0.5, 1.0, 0.4))
	if enemy.data.applies_freeze and not player.frozen_next:
		if player_prevents(&"freeze"):
			player.popup("FREEZE RESISTED", Color(0.8, 0.8, 0.85))
		else:
			player.frozen_next = true
			player.popup("FROZEN", Color(0.6, 0.85, 1.0))
	# Fire adds half of each damaging hit again at the start of the next turn
	if enemy.data.applies_fire and damage / 2 > 0:
		if player_prevents(&"fire"):
			player.popup("FIRE RESISTED", Color(0.8, 0.8, 0.85))
		else:
			player.burn += damage / 2
			player.popup("ON FIRE", Color(1.0, 0.55, 0.2))


## Turn plan entry for a resolved enemy attack.
func _attack_log(enemy: Enemy, ctx: AttackContext) -> Array:
	var name := enemy.data.display_name + (" (%s)" % ctx.source_note if ctx.source_note != "" else "")
	if ctx.miss:
		return ["%s missed you" % name, ""]
	var rolled := ctx.raw()
	var line := "%s %shit you for %d" % [name, "critically " if ctx.crit else "", rolled]
	if ctx.negated:
		return [line, "Blocked by " + " + ".join(ctx.notes)]
	if _dodged:
		return [line, "Dodged"]
	if ctx.defence <= 0:
		return [line, ""]
	return [line, "%s blocked, %d damage taken" % [AttackContext.value_text(mini(ctx.defence, rolled)), ctx.damage()]]


## Plays out a planned action active.
func resolve_ability(ability: Ability) -> void:
	if not spend_use(ability, _uses):
		return
	player.popup(ability.display_name, Color(1.0, 0.85, 0.4))
	await ability.perform(self)


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


## Each living enemy, nearest first: move (Gloomhaven rules), then attack unless it struck back this turn - or whatever
## its boss behaviour does instead. Stunned enemies lose the whole turn, and their stuns end with it. Bosses then get
## their end-of-round rules (an ice shield recovering, say).
func _enemy_turn() -> void:
	await _poison_tick()
	for enemy in _enemy_order():
		if not is_instance_valid(enemy) or enemy.is_dead():
			continue
		if _stun_blocks(enemy):
			await get_tree().create_timer(Anim.t(0.3)).timeout
			continue
		if enemy.data.behaviour:
			await enemy.data.behaviour.take_turn(self, enemy)
		else:
			await standard_enemy_turn(enemy)
		if _player_dead():
			return
		await get_tree().create_timer(Anim.t(0.15)).timeout
	for enemy in board.get_enemies():
		enemy.stunned = false
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


## Hurts [enemy], counting the health it actually lost as damage dealt.
func _damage_enemy(enemy: Enemy, amount: int) -> void:
	SaveManager.run_data.damage_dealt += mini(Enemy.through_shield(enemy.shield, amount), enemy.hp)
	enemy.take_damage(amount)


## Gold for killing an enemy of [data]: its own gold (higher for tougher biomes and bosses), plus a share per level
## entered this run.
static func kill_gold(data: EnemyData) -> int:
	return roundi(data.gold * (1.0 + GOLD_PER_DEPTH * maxi(SaveManager.run_data.path.size() - 1, 0)))


func _reward_kill(enemy: Enemy) -> void:
	var run := SaveManager.run_data
	var gold := kill_gold(enemy.data)
	run.add_gold(gold)
	run.enemies_defeated += 1
	if enemy.data.is_boss:
		run.bosses_defeated += 1
	player.popup("+%d gold" % gold, Color(1.0, 0.85, 0.3))


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
	if held.is_empty() and _block_actives().is_empty():
		return 0
	var chosen: Array[int] = []
	if SaveManager.settings_data.auto_spend_defence and held.size() > 0:
		chosen = _auto_block(held, damage)
	else:
		_blocking = enemy
		_blocking_damage = damage
		_block_selected.clear()
		_enemy_log[log_index] = ["%s hits you for %d" % [enemy.data.display_name, damage], "Block or take it?"]
		_refresh()
		enemy.popup("!", Color(1.0, 0.6, 0.2))
		var blockers := _block_actives()
		block_prompt.show_prompt(enemy.data.display_name, damage, blockers.map(func(a: Ability): return a.display_name))
		_block_with = null
		await _block_confirmed
		chosen = _block_selected.duplicate()
		_blocking = null
		_block_selected.clear()
		await block_prompt.hide_prompt()
		if _block_with and spend_use(_block_with, _uses):
			player.popup(_block_with.display_name, Color(1.0, 0.85, 0.4))
			_refresh()
			return AttackContext.BLOCK_ALL
	_spent.append_array(chosen)
	_dodged = chosen.any(func(i: int): return results[i].face().has(Symbol.Type.DODGE))
	_refresh()
	return dice_value(chosen)


## Block actives with uses left this level, for the block prompt.
func _block_actives() -> Array[Ability]:
	_sync_uses()
	return actives_of(Ability.Use.BLOCK).filter(func(a: Ability): return _uses.get(a.id, 0) > 0)


## Block prompt: the player chose the [index]th block active.
func _block_with_ability(index: int) -> void:
	_block_selected.clear()
	var blockers := _block_actives()
	_block_with = blockers[index] if index < blockers.size() else null
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
	boss.popup("SUMMON", Color(0.75, 0.55, 1.0))
	for tile_id in tiles:
		board.spawn_minion(boss, tile_id)
		await get_tree().create_timer(Anim.t(0.2)).timeout
	await get_tree().create_timer(Anim.t(0.3)).timeout


## [boss] charges through [path]; every piece along it takes an attack of its attack value. It ends on the last free
## tile of the path (or stays put if there is none). Awaitable.
func charge(boss: Enemy, path: Array[int]) -> void:
	var landing := boss.tile_id
	for tile_id in path:
		if board.get_piece(tile_id) == null:
			landing = tile_id
	await boss.charge_along(path, landing, func(tile_id: int): await _hit_piece(boss, tile_id, boss.data.attack, "charge"))


## [boss] bursts into flames: [damage] to every piece on the tiles up to [reach] along the six straight lines from it,
## which stop at walls and obstacles. Awaitable.
func flame_burst(boss: Enemy, reach: int, damage: int) -> void:
	boss.popup("FLAME BURST", Color(1.0, 0.55, 0.2))
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
	victim.take_damage(maxi(damage - victim.data.defence, 0))
	if victim.is_dead():
		victim.play_death()
		await victim.died
	else:
		await get_tree().create_timer(Anim.t(0.2)).timeout


## A boss that dies takes the minions it summoned with it (no gold).
func _dismiss_minions(boss: Enemy) -> void:
	var followers := boss.minions()
	for follower in followers:
		follower.hp = 0
		follower.play_death()
	if followers.size() > 0:
		await followers[0].died


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
			enemy.preview_skips_attack = state == State.ENEMY_TURN and _retaliated.count(enemy) >= enemy.data.attacks_per_turn
			enemy.preview_stunned = enemy.stunned
			enemy.preview_poisoned = enemy.poisoned
			enemy.cutout.flash = Color(0, 0, 0, 0)
			continue
		enemy.preview_hp = _end_state.enemy_hp.get(enemy, enemy.hp)
		enemy.preview_shield = _end_state.enemy_shield.get(enemy, enemy.shield)
		enemy.preview_skips_attack = _end_state.retaliated.count(enemy) >= enemy.data.attacks_per_turn
		enemy.preview_stunned = _end_state.stunned.has(enemy)
		enemy.preview_poisoned = _end_state.poisoned.has(enemy)
	# Hovering a target previews the selected attack (and any area hits) on top of the plan
	var preview := _hovered_attack()
	if planning and preview:
		var target := preview.target as Enemy
		_preview_damage(target, preview.damage())
		for tile_id in preview.aoe_tiles:
			var other := board.get_piece(tile_id) as Enemy
			if other and _end_state.is_alive(other):
				_preview_damage(other, preview.split(other, other.data.defence).damage())
	for enemy in board.get_enemies():
		if planning and _end_state:
			enemy.cutout.flash = Color(0.1, 0.08, 0.1, 0.6 if enemy.preview_hp <= 0 else 0.0)


## Takes [amount] off the planned shield and health shown for [enemy].
func _preview_damage(enemy: Enemy, amount: int) -> void:
	var through := Enemy.through_shield(enemy.preview_shield, amount)
	enemy.preview_shield -= amount - through
	enemy.preview_hp -= through


## The selected attack dice aimed at the hovered target, or null.
func _hovered_attack() -> AttackContext:
	if state != State.PLAN or _selected_category() != DieFace.Category.ATTACK or not _targets.has(hovered_tile):
		return null
	return player_attack_context(board.get_piece(hovered_tile), selected, _armed, _first_planned())


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
	action_list.set_header("TURN %d  ·  %s" % [turn_number, State.keys()[state].replace("_", " ")])
	action_list.set_commit_enabled(state == State.PLAN)
	var buttons: Array[Dictionary] = []
	var total := new_uses()
	for ability in plan_actives():
		var left: int = uses_preview().get(ability.id, total.get(ability.id, 0))
		var armed := _armed.has(ability)
		buttons.append({
			"text": "%s  (%d/%d)" % [ability.display_name.to_upper(), left, total.get(ability.id, 0)],
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
	# An ice shield counts as health to get through
	var target_hp: int = _end_state.enemy_hp.get(target, target.hp) + _end_state.enemy_shield.get(target, target.shield) if target else 0
	attack_preview.show_attack(chosen, player_attack_context(target, dice, _armed, _first_planned()), _armed, target, target_hp)


## True if an attack added to the plan now would be the turn's first.
func _first_planned() -> bool:
	return _insert_state != null and _insert_state.attacks == 0


func _hint() -> String:
	if _blocking:
		return "%s hits you for %d.  Block with held defence dice or TAKE HIT." % [_blocking.data.display_name, _blocking_damage]
	if _hint_note != "" and state == State.PLAN:
		return _hint_note
	match state:
		State.ROLL:
			return "Rolling..."
		State.RESOLVE:
			return "Resolving your actions..."
		State.ENEMY_TURN:
			if results.is_empty() and actions.is_empty():
				return "You are stunned and lose this turn."
			return "Enemy turn..."
		State.LEVEL_CLEAR:
			return clear_hint
		State.GAME_OVER:
			return "Defeated."
	var armed_names := " + ".join(_armed.map(func(a: Ability): return a.display_name))
	var armed_note := "  %s will be used on this attack." % armed_names if _armed.size() > 0 else ""
	match _selected_category():
		DieFace.Category.ATTACK:
			var range_note := "  Range lost by combining with dice without it." if is_range_lost(selected) else ""
			return "Attack %d (range %d): click a highlighted enemy.  Click more attack dice to combine them.%s%s  Right-click to cancel." % [dice_value(selected), attack_range(selected), range_note, armed_note]
	if selected.size() > 0:
		if is_teleport_lost(selected):
			return "Move %d: teleport lost by combining with normal movement.  Click a highlighted tile.  Right-click to cancel." % dice_value(selected)
		if _move_ctx and _move_ctx.teleport:
			return "Teleport %d: click a highlighted tile in line of sight.  Right-click to cancel." % _move_ctx.budget
		var frozen_note := " (frozen: half of %d)" % dice_value(selected) if player.frozen and _move_ctx and not _move_ctx.teleport else ""
		return "Move %d%s: click a highlighted tile.  Click more movement dice to combine them.  Right-click to cancel." % [_move_ctx.budget if _move_ctx else dice_value(selected), frozen_note]
	if _editing:
		return "Editing: choose dice, then a target.  Right-click to cancel."
	if _armed.size() > 0:
		return "%s armed: choose attack dice, then a target.  Right-click to cancel." % armed_names
	return "Click dice to plan moves and attacks, then COMMIT.  Defence dice are kept to block hits."


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
