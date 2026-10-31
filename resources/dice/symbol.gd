class_name Symbol
extends RefCounted

## Die face symbols. Icons are soft-edged height masks (white = symbol) carved into the face.

# New types go at the end: saved faces store the numbers
enum Type { ATTACK, DEFENCE, MOVE, CRIT, INSTA_KILL, BLOCK_ALL, TELEPORT, BUFF, STUN, POISON, PENETRATE, RANGE }

## Shown once with their count as a number, rather than repeated
const NUMBERED: Array[Type] = [Type.PENETRATE, Type.RANGE]

const ICONS: Dictionary[Type, Texture2D] = {
	Type.ATTACK: preload("res://assets/dice/symbols/attack.png"),
	Type.DEFENCE: preload("res://assets/dice/symbols/defence.png"),
	Type.MOVE: preload("res://assets/dice/symbols/move.png"),
	Type.CRIT: preload("res://assets/dice/symbols/crit.png"),
	Type.INSTA_KILL: preload("res://assets/dice/symbols/insta_kill.png"),
	Type.BLOCK_ALL: preload("res://assets/dice/symbols/block_all.png"),
	Type.TELEPORT: preload("res://assets/dice/symbols/teleport.png"),
	Type.BUFF: preload("res://assets/dice/symbols/buff.png"),
	Type.STUN: preload("res://assets/dice/symbols/stun.png"),
	Type.POISON: preload("res://assets/dice/symbols/poison.png"),
	Type.PENETRATE: preload("res://assets/dice/symbols/penetrate.png"),
	Type.RANGE: preload("res://assets/dice/symbols/range.png"),
}

## Ink colour inside the carving, so results read at a glance
const INK: Dictionary[Type, Color] = {
	Type.ATTACK: Color(0.75, 0.16, 0.12),
	Type.DEFENCE: Color(0.16, 0.36, 0.75),
	Type.MOVE: Color(0.18, 0.58, 0.22),
	Type.CRIT: Color(0.85, 0.62, 0.1),
	Type.INSTA_KILL: Color(0.12, 0.1, 0.12),
	Type.BLOCK_ALL: Color(0.3, 0.55, 0.85),
	Type.TELEPORT: Color(0.55, 0.25, 0.75),
	Type.BUFF: Color(0.85, 0.62, 0.1),
	Type.STUN: Color(0.9, 0.5, 0.1),
	Type.POISON: Color(0.3, 0.6, 0.15),
	Type.PENETRATE: Color(0.45, 0.45, 0.5),
	Type.RANGE: Color(0.55, 0.35, 0.15),
}
