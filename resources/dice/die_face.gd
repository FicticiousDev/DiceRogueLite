class_name DieFace
extends Resource

## One face of a die. Every face holds a single action:
## - attack: 1-5 ATTACK, optionally with modifiers: CRIT, STUN, POISON, PENETRATE n, RANGE n (n shown as a number)
## - defence: 1-5 DEFENCE, or a DODGE (avoids a whole hit)
## - move: 1-5 MOVE, optionally with a TELEPORT
## - insta-kill: a single INSTA_KILL
## - buff: a single BUFF plus [buff_target]; once in the row it adds 1 to every rolled face of that category

## Row grouping and action type, in display order
enum Category { ATTACK, DEFENCE, MOVE, OTHER }

@export var symbols: Array[FaceSymbol] = []
## What a BUFF face buffs (ATTACK, DEFENCE or MOVE). Ignored on other faces.
@export var buff_target: Symbol.Type = Symbol.Type.ATTACK


## Total of [type] symbols on the face.
func count(type: Symbol.Type) -> int:
	var total := 0
	for face_symbol in symbols:
		if face_symbol.symbol == type:
			total += face_symbol.count
	return total


func has(type: Symbol.Type) -> bool:
	return count(type) > 0


func is_buff() -> bool:
	return has(Symbol.Type.BUFF)


func category() -> Category:
	if is_buff():
		return Category.OTHER
	if has(Symbol.Type.ATTACK) or has(Symbol.Type.CRIT) or has(Symbol.Type.INSTA_KILL):
		return Category.ATTACK
	if has(Symbol.Type.DEFENCE) or has(Symbol.Type.DODGE):
		return Category.DEFENCE
	if has(Symbol.Type.MOVE) or has(Symbol.Type.TELEPORT):
		return Category.MOVE
	return Category.OTHER


## The counted symbol: ATTACK, DEFENCE or MOVE for numeric faces, otherwise the face's single symbol.
func main_symbol() -> Symbol.Type:
	for type in [Symbol.Type.ATTACK, Symbol.Type.DEFENCE, Symbol.Type.MOVE]:
		if has(type):
			return type
	return symbols[0].symbol if symbols.size() > 0 else Symbol.Type.ATTACK


## Number of main symbols (sword/shield/move count).
func value() -> int:
	return count(main_symbol())


## True if the face has a sword/shield/move count that buffs can add to.
func is_numeric() -> bool:
	return main_symbol() in [Symbol.Type.ATTACK, Symbol.Type.DEFENCE, Symbol.Type.MOVE] and value() > 0


## Category a BUFF face buffs.
func buff_category() -> Category:
	match buff_target:
		Symbol.Type.DEFENCE:
			return Category.DEFENCE
		Symbol.Type.MOVE:
			return Category.MOVE
	return Category.ATTACK


## Copy with [amount] extra main symbols, for showing buffed results.
func with_bonus(amount: int) -> DieFace:
	if amount == 0 or not is_numeric():
		return self
	var face: DieFace = duplicate(true)
	for face_symbol in face.symbols:
		if face_symbol.symbol == main_symbol():
			face_symbol.count += amount
			break
	return face


## Symbols as drawn, including a buff's target.
func display_symbols() -> Array[FaceSymbol]:
	var result: Array[FaceSymbol] = symbols.duplicate()
	if is_buff():
		var target := FaceSymbol.new()
		target.symbol = buff_target
		result.append(target)
	return result


## Identifies the face's look, for texture caching.
func key() -> String:
	var parts: PackedStringArray = []
	for face_symbol in display_symbols():
		parts.append("%d:%d" % [face_symbol.symbol, face_symbol.count])
	return ",".join(parts)


func describe() -> String:
	if is_buff():
		return tr("DIE_FACE_BUFF") % Symbol.Type.keys()[buff_target]
	var parts: PackedStringArray = []
	for face_symbol in symbols:
		parts.append("%d %s" % [face_symbol.count, Symbol.Type.keys()[face_symbol.symbol]])
	return " + ".join(parts) if parts.size() > 0 else tr("DIE_FACE_BLANK")
