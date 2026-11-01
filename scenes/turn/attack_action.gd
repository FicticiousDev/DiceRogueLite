class_name AttackAction
extends PlannedAction

## Attack an enemy in range and line of sight with the combined value of one or more attack dice. Modifiers
## (crit, insta-kill, stun, poison, penetrate, range) and abilities change it; [use_active] spends the
## character's active ability on it. A surviving enemy retaliates straight after; enemies that attack first strike
## before the player (unless the player always strikes first). The player blocks either with held defence dice.

var enemy: Enemy
var use_active: bool = false
## Simulated outcome, for the action list
var damage: int
var _ctx: AttackContext
var _notes: PackedStringArray = []


func _init(attack_dice: Array[int], target: Enemy, active: bool = false) -> void:
	dice = attack_dice.duplicate()
	enemy = target
	use_active = active


func simulate(state: TurnState, turn: TurnController) -> bool:
	if not is_instance_valid(enemy) or not state.is_alive(enemy):
		return false
	if not turn.board.in_attack_range(state.player_tile, enemy.tile_id, turn.attack_range(dice)):
		return false
	_notes.clear()
	var enemy_first := enemy.data.attacks_first and not turn.player_strikes_first()
	if enemy_first:
		_add_strike_note(state, turn, "Strikes first")
	var spend := use_active and TurnController.spend_use(turn.active_ability(), state.uses)
	if use_active and not spend:
		_notes.append("No %s uses left" % turn.active_ability().display_name)
	_ctx = turn.player_attack_context(enemy, dice, spend)
	damage = _ctx.damage()
	_notes.append_array(_ctx.notes)
	state.enemy_hp[enemy] -= damage
	for tile_id in _ctx.aoe_tiles:
		var other := turn.board.get_piece(tile_id) as Enemy
		if other and state.is_alive(other):
			var splash := _ctx.split(other, other.data.defence).damage()
			state.enemy_hp[other] -= splash
			_notes.append("%s %s" % [other.data.display_name, "killed" if state.enemy_hp[other] <= 0 else "-%d" % splash])
	if state.enemy_hp[enemy] <= 0:
		_notes.append("Kills it (+%d gold)" % enemy.data.gold)
	else:
		if _ctx.stun and not state.stunned.has(enemy):
			state.stunned.append(enemy)
			_notes.append("Stuns it")
		if _ctx.poison and not state.poisoned.has(enemy):
			state.poisoned.append(enemy)
			_notes.append("Poisons it")
		if not enemy_first:
			_add_strike_note(state, turn, "Retaliates")
	if not state.attacked.has(enemy):
		state.attacked.append(enemy)
	state.used_dice.append_array(dice)
	return true


## Notes the enemy's attack back. Its strongest hit runs through the player's abilities, so a once-per-turn
## block is spent here in the plan just as it would be in resolution.
func _add_strike_note(state: TurnState, turn: TurnController, verb: String) -> void:
	if not enemy.can_hit(state.player_tile):
		return
	if state.stunned.has(enemy):
		state.stunned.erase(enemy)
		_notes.append("Stunned: no %s" % ("first strike" if verb == "Strikes first" else "retaliation"))
		return
	if not state.retaliated.has(enemy):
		state.retaliated.append(enemy)
	var strike := AttackContext.new(enemy, turn.player, enemy.data.attack_max, 0)
	turn.apply_incoming(strike)
	var note := "%s %d–%d" % [verb, enemy.data.attack_min, enemy.data.attack_max]
	if strike.negated:
		note += ", blocked by " + " + ".join(strike.notes)
	_notes.append(note)


func resolve(turn: TurnController) -> void:
	await turn.resolve_attack(enemy, dice, use_active)


func describe(turn: TurnController) -> String:
	var target := enemy.data.display_name if is_instance_valid(enemy) else "?"
	if _ctx and _ctx.insta_kill:
		return "Insta-kill  →  %s" % target
	var extras := ""
	if _ctx and _ctx.crit:
		extras += ", crit"
	if _ctx and _ctx.penetrate > 0 and not _ctx.ignore_defence:
		extras += ", pierce %d" % _ctx.penetrate
	if _ctx and _ctx.multiplier > 1:
		extras += ", ×%d" % _ctx.multiplier
	return "Attack %d  →  %s  (%d dmg%s)" % [_ctx.base_damage if _ctx else turn.dice_value(dice), target, damage, extras]


func warning(_turn: TurnController) -> String:
	return " · ".join(_notes)


func target_tile() -> int:
	return enemy.tile_id
