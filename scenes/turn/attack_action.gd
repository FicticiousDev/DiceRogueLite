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
		_notes.append(tr("NOTE_RANGE_LOST"))
	var enemy_first := enemy.data.attacks_first and not turn.player_strikes_first()
	if enemy_first:
		_add_strike_note(state, turn, "NOTE_STRIKES_FIRST")
	var spent := TurnController.spend_uses(actives, state.uses)
	for ability in actives:
		if not spent.has(ability):
			_notes.append(tr("NOTE_NO_USES_LEFT") % ability.display_name)
	_ctx = turn.player_attack_context(enemy, dice, spent, state.attacks == 0, state.player_tile, state.boosts)
	state.attacks += 1
	# A crit boost goes on the first attack after it
	state.boosts.erase(&"crit")
	damage = _ctx.damage()
	_notes.append_array(_ctx.notes)
	state.hurt(enemy, damage, _ctx.shield_multiplier())
	for tile_id in _ctx.aoe_tiles:
		var other := turn.board.get_piece(tile_id) as Enemy
		if other and state.is_alive(other):
			var splash := _ctx.split(other, 0).damage()
			state.hurt(other, splash, _ctx.shield_multiplier())
			_notes.append("%s %s" % [other.data.display_name, tr("NOTE_KILLED") if state.enemy_hp[other] <= 0 else "-%d" % splash])
			if _ctx.fire and state.is_alive(other) and splash / 2 > 0 and not state.burning.has(other):
				state.burning.append(other)
	if state.enemy_hp[enemy] <= 0:
		_notes.append(tr("NOTE_KILLS_IT") % TurnController.kill_gold(enemy.data))
	else:
		if _ctx.fire and damage / 2 > 0:
			if not state.burning.has(enemy):
				state.burning.append(enemy)
			_notes.append(tr("NOTE_SETS_ON_FIRE") % (damage / 2))
		if _ctx.stun and enemy.data.stun_immune:
			_notes.append(tr("NOTE_IMMUNE_TO_STUN"))
		elif _ctx.stun and not state.stunned.has(enemy):
			state.stunned.append(enemy)
			_notes.append(tr("NOTE_STUNS_IT"))
		if _ctx.poison and not state.poisoned.has(enemy):
			state.poisoned.append(enemy)
			_notes.append(tr("NOTE_POISONS_IT"))
		if not enemy_first:
			_add_strike_note(state, turn, "NOTE_RETALIATES")
	if not state.attacked.has(enemy):
		state.attacked.append(enemy)
	state.used_dice.append_array(dice)
	return true


## Notes the enemy's attack back. Its hit (before crits) runs through the player's abilities, so a once-per-turn
## block is spent here in the plan just as it would be in resolution.
func _add_strike_note(state: TurnState, turn: TurnController, verb: String) -> void:
	if not enemy.can_hit(state.player_tile):
		return
	var noun := tr("NOTE_NOUN_FIRST_STRIKE") if verb == "NOTE_STRIKES_FIRST" else tr("NOTE_NOUN_RETALIATION")
	if state.stunned.has(enemy):
		_notes.append(tr("NOTE_STUNNED_NO_STRIKE") % noun)
		return
	if not turn.can_retaliate(enemy):
		_notes.append(tr("NOTE_ALREADY_ATTACKED_NO_STRIKE") % noun)
		return
	state.retaliated.append(enemy)
	var strike := AttackContext.new(enemy, turn.player, enemy.data.attack, 0)
	turn.apply_incoming(strike)
	var note := "%s %d" % [tr(verb), enemy.data.attack]
	if strike.negated:
		note += tr("NOTE_BLOCKED_BY_SUFFIX") % " + ".join(strike.notes)
	_notes.append(note)


func resolve(turn: TurnController) -> void:
	await turn.resolve_attack(enemy, dice, actives)


func describe(turn: TurnController) -> String:
	var target := enemy.data.display_name if is_instance_valid(enemy) else "?"
	if _ctx and _ctx.insta_kill:
		return tr("PLAN_INSTA_KILL") % target
	var extras := ""
	if _ctx and _ctx.crit:
		extras += tr("PLAN_EXTRA_CRIT")
	if _ctx and _ctx.penetrate > 0 and not _ctx.ignore_defence:
		extras += tr("PLAN_EXTRA_PIERCE") % _ctx.penetrate
	if _ctx and _ctx.multiplier > 1:
		extras += ", ×%d" % _ctx.multiplier
	return tr("PLAN_ATTACK") % [_ctx.base_damage if _ctx else turn.dice_value(dice), target, damage, extras]


func warning(_turn: TurnController) -> String:
	return " · ".join(_notes)


func target_tile() -> int:
	return enemy.tile_id
