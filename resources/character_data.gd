class_name CharacterData
extends Resource

## A playable character: look, health, attack range, passive abilities and starting dice.

@export var id: StringName
@export var display_name: String
@export var texture: Texture2D = preload("res://icon.svg")
@export var tint: Color = Color.WHITE
@export var max_hp: int = 10
@export var attack_range: int = 1
@export var abilities: Array[Ability] = []
@export var starting_dice: Array[StringName] = []
## Position on the character select screen (lowest first)
@export var order: int = 0
## Pickable from the first run. Otherwise it needs an entry in ProgressionData.unlocked_characters
@export var starts_unlocked: bool = true
