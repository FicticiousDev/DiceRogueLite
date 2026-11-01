class_name BiomeData
extends Resource

## An area of the run: its place in the run order, difficulty, tile colours and enemies.

@export var id: StringName
@export var display_name: String
## Run order: 1 first, then 2 or 3, then 4 or 5, then 6
@export var order: int = 1
## Raises how many of a level's enemy and loot points are used
@export var difficulty: int = 1
## Exit gates and map symbols leading into this biome
@export var color: Color = Color.WHITE
## Tile colour per Terrain.Type
@export var terrain_colors: Array[Color] = []
@export var enemy_ids: Array[StringName] = []
@export var boss_id: StringName
