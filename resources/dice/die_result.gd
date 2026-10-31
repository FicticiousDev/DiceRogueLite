class_name DieResult
extends RefCounted

## The rolled face of one die. The turn system refers to dice by [index] into the rolled pool.

var index: int
var die_type: DieType
var face_index: int
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
	return face().with_bonus(bonus)


func value() -> int:
	return face().value() + (bonus if face().is_numeric() else 0)


func category() -> DieFace.Category:
	return face().category()


func describe() -> String:
	return display_face().describe()
