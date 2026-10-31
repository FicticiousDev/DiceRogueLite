class_name DieType
extends Resource

## A kind of die: the combination of symbols on its six faces.
## Face order: 0 top, 1 right, 2 front, 3 back, 4 left, 5 bottom (opposite faces sum to 5).

@export var id: StringName
@export var display_name: String
@export var rarity: Rarity.Tier = Rarity.Tier.COMMON
@export var faces: Array[DieFace] = []
