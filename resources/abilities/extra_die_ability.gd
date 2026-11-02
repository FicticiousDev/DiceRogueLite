class_name ExtraDieAbility
extends Ability

## Passive: rolls an extra die every turn whose every face is [count] [symbol] (e.g. a defence 1 die from armour).
## Its colour comes from [rarity].

@export var symbol: Symbol.Type = Symbol.Type.DEFENCE
@export_range(1, 6) var count: int = 1
@export var rarity: Rarity.Tier = Rarity.Tier.COMMON

var _die: DieType


func extra_dice() -> Array[DieType]:
	if _die == null:
		_die = DieType.new()
		_die.id = StringName("extra_%s" % id)
		_die.display_name = display_name
		_die.rarity = rarity
		for i in 6:
			var face_symbol := FaceSymbol.new()
			face_symbol.symbol = symbol
			face_symbol.count = count
			var face := DieFace.new()
			face.symbols.append(face_symbol)
			_die.faces.append(face)
	return [_die]
