class_name HelpText
extends RefCounted

## Player-facing explanations of die symbols, statuses and enemy stats, shared by tooltips and the enemy details.
## The constants below are localisation keys: wrap them in tr() where they are shown.

const PLAYER_STUNNED: String = "HELP_PLAYER_STUNNED"
const PLAYER_POISONED: String = "HELP_PLAYER_POISONED"
const ENEMY_STUNNED: String = "HELP_ENEMY_STUNNED"
const ENEMY_POISONED: String = "HELP_ENEMY_POISONED"
const PLAYER_FROZEN: String = "HELP_PLAYER_FROZEN"
const PLAYER_BURNING: String = "HELP_PLAYER_BURNING"
const STUN_IMMUNE: String = "HELP_STUN_IMMUNE"
const FREEZING_HITS: String = "HELP_FREEZING_HITS"
const FIRE_HITS: String = "HELP_FIRE_HITS"
const ATTACKS_FIRST: String = "HELP_ATTACKS_FIRST"


## What one symbol on a rolled face does. [count] is how many of it the face shows.
static func symbol(type: Symbol.Type, count: int, face: DieFace) -> String:
	match type:
		Symbol.Type.ATTACK:
			return TranslationServer.translate("HELP_SYMBOL_ATTACK") % [count, count]
		Symbol.Type.DEFENCE:
			return TranslationServer.translate("HELP_SYMBOL_DEFENCE") % [count, count]
		Symbol.Type.MOVE:
			return TranslationServer.translate("HELP_SYMBOL_MOVE") % [count, count]
		Symbol.Type.CRIT:
			return TranslationServer.translate("HELP_SYMBOL_CRIT")
		Symbol.Type.INSTA_KILL:
			return TranslationServer.translate("HELP_SYMBOL_INSTA_KILL") % AttackContext.BOSS_INSTA_KILL_DAMAGE
		Symbol.Type.DODGE:
			return TranslationServer.translate("HELP_SYMBOL_DODGE")
		Symbol.Type.TELEPORT:
			return TranslationServer.translate("HELP_SYMBOL_TELEPORT")
		Symbol.Type.BUFF:
			return TranslationServer.translate("HELP_SYMBOL_BUFF") % [
				TranslationServer.translate(BUFF_TARGETS[face.buff_target]), DieResult.MAX_BUFFED]
		Symbol.Type.STUN:
			return TranslationServer.translate("HELP_SYMBOL_STUN")
		Symbol.Type.POISON:
			return TranslationServer.translate("HELP_SYMBOL_POISON")
		Symbol.Type.PENETRATE:
			return TranslationServer.translate("HELP_SYMBOL_PIERCE") % [count, count]
		Symbol.Type.RANGE:
			return TranslationServer.translate("HELP_SYMBOL_RANGE") % [count, count]
	return ""


## Short names for face summaries (localisation keys)
const SYMBOL_NAMES: Dictionary[Symbol.Type, String] = {
	Symbol.Type.ATTACK: "SYMBOL_ATTACK", Symbol.Type.DEFENCE: "SYMBOL_DEFENCE", Symbol.Type.MOVE: "SYMBOL_MOVE", Symbol.Type.CRIT: "SYMBOL_CRIT",
	Symbol.Type.INSTA_KILL: "SYMBOL_INSTA_KILL", Symbol.Type.DODGE: "SYMBOL_DODGE", Symbol.Type.TELEPORT: "SYMBOL_TELEPORT",
	Symbol.Type.BUFF: "SYMBOL_BUFF", Symbol.Type.STUN: "SYMBOL_STUN", Symbol.Type.POISON: "SYMBOL_POISON", Symbol.Type.PENETRATE: "SYMBOL_PIERCE",
	Symbol.Type.RANGE: "SYMBOL_RANGE",
}

## Lower-case names of what a buff face boosts (localisation keys)
const BUFF_TARGETS: Dictionary[Symbol.Type, String] = {
	Symbol.Type.ATTACK: "BUFF_TARGET_ATTACK", Symbol.Type.DEFENCE: "BUFF_TARGET_DEFENCE", Symbol.Type.MOVE: "BUFF_TARGET_MOVE",
}


## One line naming what [face] does, e.g. "Attack 3 + Crit".
static func face_summary(face: DieFace) -> String:
	if face.is_buff():
		return TranslationServer.translate("HELP_FACE_BUFF") % TranslationServer.translate(BUFF_TARGETS[face.buff_target])
	var parts: PackedStringArray = []
	for face_symbol in face.symbols:
		var name: String = TranslationServer.translate(SYMBOL_NAMES[face_symbol.symbol])
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
