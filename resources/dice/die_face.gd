class_name DieFace
extends Resource

## One face of a die: any mix of symbols. Symbol counts are the face's values.

## Row grouping, in display order
enum Category { ATTACK, DEFENCE, MOVE, OTHER }

@export var symbols: Array[FaceSymbol] = []


## Total of [type] symbols on the face.
func count(type: Symbol.Type) -> int:
	var total := 0
	for face_symbol in symbols:
		if face_symbol.symbol == type:
			total += face_symbol.count
	return total


func total() -> int:
	var sum := 0
	for face_symbol in symbols:
		sum += face_symbol.count
	return sum


## First of attack/defence/move present on the face, otherwise OTHER.
func category() -> Category:
	if count(Symbol.Type.ATTACK) > 0:
		return Category.ATTACK
	if count(Symbol.Type.DEFENCE) > 0:
		return Category.DEFENCE
	if count(Symbol.Type.MOVE) > 0:
		return Category.MOVE
	return Category.OTHER


## Identifies the face's look, for texture caching.
func key() -> String:
	var parts: PackedStringArray = []
	for face_symbol in symbols:
		parts.append("%d:%d" % [face_symbol.symbol, face_symbol.count])
	return ",".join(parts)


func describe() -> String:
	var parts: PackedStringArray = []
	for face_symbol in symbols:
		parts.append("%d %s" % [face_symbol.count, Symbol.Type.keys()[face_symbol.symbol]])
	return " + ".join(parts) if parts.size() > 0 else "blank"
