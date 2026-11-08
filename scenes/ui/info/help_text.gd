class_name HelpText
extends RefCounted

## Player-facing explanations of die symbols, statuses and enemy stats, shared by tooltips and the enemy details.

const PLAYER_STUNNED: String = "Stunned: you can't act until the next round. Stunned during your turn, the rest of your plan is skipped; stunned in the enemy turn, you lose your next turn – no roll, straight to the enemy turn."
const PLAYER_POISONED: String = "Poisoned: you take 1 damage at the start of each of your turns. The next heal cures it instead of restoring health."
const ENEMY_STUNNED: String = "Stunned: it can't act until the next round – no first strike, retaliation, move or attack."
const ENEMY_POISONED: String = "Poisoned: it takes 1 damage at the start of every enemy turn until it dies."
const PLAYER_FROZEN: String = "Frozen: your movement is halved (rounded up) for your next turn. Teleporting is not affected."
const PLAYER_BURNING: String = "Burning: you take half the damage of the hit that set you on fire (rounded down) at the start of your next turn, then the flames go out."
const STUN_IMMUNE: String = "Immune to stun."
const FREEZING_HITS: String = "Freezing hits: a hit that damages you freezes you – your movement is halved (rounded up) on your next turn. Teleporting is not affected."
const FIRE_HITS: String = "Fiery hits: a hit that damages you sets you on fire – half that damage again (rounded down) at the start of your next turn."
const ATTACKS_FIRST: String = "Strikes first: when you attack it, it hits you before your attack lands."


## What one symbol on a rolled face does. [count] is how many of it the face shows.
static func symbol(type: Symbol.Type, count: int, face: DieFace) -> String:
	match type:
		Symbol.Type.ATTACK:
			return "Attack %d: deals %d damage, less the target's defence. Combine attack dice for one bigger hit." % [count, count]
		Symbol.Type.DEFENCE:
			return "Defence %d: blocks %d damage from a hit. Kept all turn and spent when you're hit." % [count, count]
		Symbol.Type.MOVE:
			return "Move %d: move up to %d tiles; difficult terrain costs more. Combine move dice to go further." % [count, count]
		Symbol.Type.CRIT:
			return "Critical: doubles the highest die in the attack – this one or another die combined with it."
		Symbol.Type.INSTA_KILL:
			return "Insta-kill: kills any normal enemy outright. A boss takes %d damage with a crit instead." % AttackContext.BOSS_INSTA_KILL_DAMAGE
		Symbol.Type.DODGE:
			return "Dodge: avoids one whole hit. Kept all turn and spent when you're hit."
		Symbol.Type.TELEPORT:
			return "Teleport: blink to any free tile in range and line of sight, ignoring terrain. Lost if combined with normal move dice."
		Symbol.Type.BUFF:
			return "Buff: +1 to every other rolled %s die this turn (no die goes above %d). Used automatically." % [
				Symbol.Type.keys()[face.buff_target].to_lower(), DieResult.MAX_BUFFED]
		Symbol.Type.STUN:
			return "Stun: the target can't act until the next round – no first strike, retaliation, move or attack."
		Symbol.Type.POISON:
			return "Poison: the target takes 1 damage at the start of each enemy turn until it dies."
		Symbol.Type.PENETRATE:
			return "Pierce %d: ignores %d of the target's defence, and deals double damage to an ice shield." % [count, count]
		Symbol.Type.RANGE:
			return "Range +%d: this attack reaches %d tiles further. Combined with a die without range, the range is lost." % [count, count]
	return ""


## Short names for face summaries
const SYMBOL_NAMES: Dictionary[Symbol.Type, String] = {
	Symbol.Type.ATTACK: "Attack", Symbol.Type.DEFENCE: "Defence", Symbol.Type.MOVE: "Move", Symbol.Type.CRIT: "Crit",
	Symbol.Type.INSTA_KILL: "Insta-kill", Symbol.Type.DODGE: "Dodge", Symbol.Type.TELEPORT: "Teleport",
	Symbol.Type.BUFF: "Buff", Symbol.Type.STUN: "Stun", Symbol.Type.POISON: "Poison", Symbol.Type.PENETRATE: "Pierce",
	Symbol.Type.RANGE: "Range +",
}


## One line naming what [face] does, e.g. "Attack 3 + Crit".
static func face_summary(face: DieFace) -> String:
	if face.is_buff():
		return "Buff: +1 %s" % SYMBOL_NAMES[face.buff_target].to_lower()
	var parts: PackedStringArray = []
	for face_symbol in face.symbols:
		var name: String = SYMBOL_NAMES[face_symbol.symbol]
		if face_symbol.symbol in [Symbol.Type.ATTACK, Symbol.Type.DEFENCE, Symbol.Type.MOVE, Symbol.Type.PENETRATE]:
			name += " %d" % face_symbol.count
		elif face_symbol.symbol == Symbol.Type.RANGE:
			name += str(face_symbol.count)
		parts.append(name)
	return " + ".join(parts)


## Tooltip rows for every symbol on [face] (as shown, buffs included).
static func face_rows(face: DieFace) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for face_symbol in face.symbols:
		rows.append(InfoPanel.row(Symbol.ICONS[face_symbol.symbol], Symbol.INK[face_symbol.symbol].lightened(0.35),
			symbol(face_symbol.symbol, face_symbol.count, face), true))
	return rows
