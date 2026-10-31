class_name Player
extends BoardPiece

## The player's piece, built from the run's [CharacterData]. The Run places it on each board's player start.

var character: CharacterData
var attack_range: int = 1


func _ready() -> void:
	if character:
		cutout.texture = character.texture
		cutout.tint = character.tint
		attack_range = character.attack_range
