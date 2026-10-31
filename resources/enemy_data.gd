class_name EnemyData
extends Resource

## An enemy type. Stats are fixed per type.

@export var id: StringName
@export var display_name: String
@export var texture: Texture2D = preload("res://icon.svg")
@export var tint: Color = Color.WHITE
@export var hp: int = 5
@export var move: int = 2
@export var attack_min: int = 1
@export var attack_max: int = 2
@export_range(0.0, 1.0) var crit_chance: float = 0.1
@export_range(0.0, 1.0) var miss_chance: float = 0.1
@export var attack_range: int = 1
@export var defence: int = 0
## Strikes before the player's attack when retaliating
@export var attacks_first: bool = false
@export var gold: int = 2
## Status effects its damaging hits give the player
@export var applies_stun: bool = false
@export var applies_poison: bool = false
