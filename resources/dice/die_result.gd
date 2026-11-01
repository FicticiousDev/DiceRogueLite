class_name DieResult
extends RefCounted

## The rolled face of one die. The turn system refers to dice by [index] into the rolled pool.

var index: int
var die_type: DieType
var face_index: int
## Buffs can't raise a face above this (crits still double it)
const MAX_BUFFED: int = 6

## Added by buffs once the dice are in the row
var bonus: int = 0


func _init(pool_index: int, type: DieType, rolled_face: int) -> void:
	index = pool_index
	die_type = type
	face_index = rolled_face


## The face as rolled.
func face() -> DieFace:
	return die_type.faces[face_index]


## The face including buff bonuses.
func display_face() -> DieFace:
	return face().with_bonus(applied_bonus())


func value() -> int:
	if face().has(Symbol.Type.DODGE):
		return AttackContext.BLOCK_ALL
	return face().value() + applied_bonus()


## The bonus that counts: buffs stop at MAX_BUFFED.
func applied_bonus() -> int:
	if not face().is_numeric():
		return 0
	return clampi(bonus, 0, maxi(MAX_BUFFED - face().value(), 0))


## True if a buff would still raise it.
func can_buff() -> bool:
	return face().is_numeric() and face().value() + applied_bonus() < MAX_BUFFED


func category() -> DieFace.Category:
	return face().category()


func describe() -> String:
	return display_face().describe()
