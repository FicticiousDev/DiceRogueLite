class_name AttackAction
extends PlannedAction

## Attack an enemy in range and line of sight with the combined value of one or more attack dice. Modifiers
## (crit, insta-kill, stun, poison, penetrate, range) and abilities change it; [actives] are the attack actives
## spent on it (character or equipment). A surviving enemy retaliates straight after; enemies that attack first strike
## before the player (unless the player always strikes first). The player blocks either with held defence dice.

var enemy: Enemy
var actives: Array[Ability] = []
## Simulated outcome, for the action list
var damage: int
var _ctx: AttackContext
var _notes: PackedStringArray = []


func _init(attack_dice: Array[int], target: Enemy, armed: Array[Ability] = []) -> void:
	dice = attack_dice.duplicate()
	enemy = target
	actives = armed.duplicate()


func simulate(state: TurnState, turn: TurnController) -> bool:
	if not is_instance_valid(enemy) or not state.is_alive(enemy):
		return false
	if not turn.board.in_attack_range(state.player_tile, enemy.tile_id, turn.attack_range(dice)):
		return false
	_notes.clear()
	if turn.is_range_lost(dice):
		_notes.append("Range lost: combined with dice without it")
	var enemy_first := enemy.data.attacks_first and not turn.player_strikes_first()
	if enemy_first:
		_add_strike_note(state, turn, "Strikes first")
	var spent := TurnController.spend_uses(actives, state.uses)
	for ability in actives:
		if not spent.has(ability):
			_notes.append("No %s uses left" % ability.display_name)
	_ctx = turn.player_attack_context(enemy, dice, spent, state.attacks == 0)
	state.attacks += 1
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
		_notes.append("Kills it (+%d gold)" % TurnController.kill_gold(enemy.data))
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


## Notes the enemy's attack back. Its hit (before crits) runs through the player's abilities, so a once-per-turn
## block is spent here in the plan just as it would be in resolution.
func _add_strike_note(state: TurnState, turn: TurnController, verb: String) -> void:
	if not enemy.can_hit(state.player_tile):
		return
	if state.stunned.has(enemy):
		_notes.append("Stunned: no %s" % ("first strike" if verb == "Strikes first" else "retaliation"))
		return
	if not state.retaliated.has(enemy):
		state.retaliated.append(enemy)
	var strike := AttackContext.new(enemy, turn.player, enemy.data.attack, 0)
	turn.apply_incoming(strike)
	var note := "%s %d" % [verb, enemy.data.attack]
	if strike.negated:
		note += ", blocked by " + " + ".join(strike.notes)
	_notes.append(note)


func resolve(turn: TurnController) -> void:
	await turn.resolve_attack(enemy, dice, actives)


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
