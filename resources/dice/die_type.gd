class_name DieType
extends Resource

## A kind of die: the combination of symbols on its six faces.
## Face order: 0 top, 1 right, 2 front, 3 back, 4 left, 5 bottom (opposite faces sum to 5).

@export var id: StringName
## Localised name. The key is DIE_<ID>_NAME (localisation/strings.csv); code-made dice (extra dice from items) set their own
var display_name: String:
	get: return _name_override if _name_override != "" else tr("DIE_%s_NAME" % String(id).to_upper())
	set(value): _name_override = value
var _name_override: String = ""
@export var rarity: Rarity.Tier = Rarity.Tier.COMMON
@export var faces: Array[DieFace] = []
## Can be awarded as loot (level clears, chests). Starting dice are not.
@export var loot: bool = false
## Can drop from the start; otherwise only once unlocked by a Mystery piece (ProgressionData.unlocked_dice)
@export var starts_unlocked: bool = true
