class_name DieResult
extends RefCounted

## The rolled face of one die. The turn system refers to dice by [index] into the rolled pool.

var index: int
var die_type: DieType
var face_index: int


func _init(pool_index: int, type: DieType, rolled_face: int) -> void:
	index = pool_index
	die_type = type
	face_index = rolled_face


func face() -> DieFace:
	return die_type.faces[face_index]
