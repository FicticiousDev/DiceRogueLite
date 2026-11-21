class_name BiomeData
extends Resource

## An area of the run: its place in the run order, difficulty, tile colours and enemies.

@export var id: StringName
## Localised name. The key is BIOME_<ID>_NAME (localisation/strings.csv)
var display_name: String:
	get: return tr("BIOME_%s_NAME" % String(id).to_upper())
## Run order: 1 first, then 2 or 3, then 4 or 5, then 6
@export var order: int = 1
## Raises how many of a level's enemy and loot points are used
@export var difficulty: int = 1
## Exit choices and map symbols leading into this biome
@export var color: Color = Color.WHITE
## Tile colour per Terrain.Type
@export var terrain_colors: Array[Color] = []
## Landing effect per Terrain.Type; a missing or empty entry uses Terrain.EFFECTS
@export var terrain_effects: Array[PackedScene] = []
@export var enemy_ids: Array[StringName] = []
@export var boss_id: StringName
## The boss's level (LevelData id): fixed, never picked at random
@export var boss_level: StringName
## Enemies on a normal level (min, max); boss levels have only the boss (and its minions), challenge levels the max + 2
@export var enemy_count: Vector2i = Vector2i(3, 4)


## The landing effect for [type] in this biome, or null if it has none.
func terrain_effect(type: Terrain.Type) -> PackedScene:
	if type < terrain_effects.size() and terrain_effects[type]:
		return terrain_effects[type]
	return Terrain.EFFECTS.get(type)


## Place in the run, 1 (first biome) to 4 (last): biomes 1, 2-3, 4-5, 6. Picks the level sizes (LevelData.stage).
func stage() -> int:
	return order / 2 + 1
