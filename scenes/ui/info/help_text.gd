class_name HelpText
extends RefCounted

## Player-facing explanations of die symbols, statuses and enemy stats, shared by tooltips and the enemy details.

const PLAYER_STUNNED: String = "Stunned: you lose your next turn – no roll, straight to the enemy turn."
const PLAYER_POISONED: String = "Poisoned: you take 1 damage at the start of each of your turns. The next heal cures it instead of restoring health."
const ENEMY_STUNNED: String = "Stunned: it skips its next action (a first strike, retaliation or its turn)."
const ENEMY_POISONED: String = "Poisoned: it takes 1 damage at the start of every enemy turn until it dies."
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
			return "Critical: the attack's damage is doubled."
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
			return "Stun: the target skips its next action."
		Symbol.Type.POISON:
			return "Poison: the target takes 1 damage at the start of each enemy turn until it dies."
		Symbol.Type.PENETRATE:
			return "Pierce %d: ignores %d of the target's defence." % [count, count]
		Symbol.Type.RANGE:
			return "Range +%d: this attack reaches %d tiles further." % [count, count]
	return ""


## Tooltip rows for every symbol on [face] (as shown, buffs included).
static func face_rows(face: DieFace) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for face_symbol in face.symbols:
		rows.append(InfoPanel.row(Symbol.ICONS[face_symbol.symbol], Symbol.INK[face_symbol.symbol].lightened(0.35),
			symbol(face_symbol.symbol, face_symbol.count, face), true))
	return rows
