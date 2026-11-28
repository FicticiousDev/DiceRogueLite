class_name Terrain
extends RefCounted

## Terrain types painted into a level's Layout layer (TileSet custom data "terrain").

enum Type { NORMAL, DIFFICULT, HAZARDOUS, WATER, WALL }

## Movement cost per tile entered. -1 = impassable.
const COSTS: Dictionary[Type, int] = {
	Type.NORMAL: 1,
	Type.DIFFICULT: 2,
	Type.HAZARDOUS: 1,
	Type.WATER: 2,
	Type.WALL: -1,
}

const COLORS: Dictionary[Type, Color] = {
	Type.NORMAL: Color(0.45, 0.62, 0.35),
	Type.DIFFICULT: Color(0.59, 0.47, 0.31),
	Type.HAZARDOUS: Color(0.47, 0.31, 0.41),
	Type.WATER: Color(0.31, 0.51, 0.75),
	Type.WALL: Color(0.45, 0.45, 0.5),
}

## Height of the tile's top surface in world units. Must match the height of the model in MESHES.
const HEIGHTS: Dictionary[Type, float] = {
	Type.NORMAL: 0.3,
	Type.DIFFICULT: 0.35,
	Type.HAZARDOUS: 0.3,
	Type.WATER: 0.18,
	Type.WALL: 0.9,
}

## Tile model per type, shared by every biome (each biome textures it, see BiomeData.terrain_textures).
## A biome can swap in its own model through BiomeData.terrain_meshes
const MESHES: Dictionary[Type, Mesh] = {
	Type.NORMAL: preload("res://assets/tiles/models/normal.obj"),
	Type.DIFFICULT: preload("res://assets/tiles/models/difficult.obj"),
	# Asset files keep the name of the terrain this replaced
	Type.HAZARDOUS: preload("res://assets/tiles/models/extreme.obj"),
	Type.WATER: preload("res://assets/tiles/models/water.obj"),
	Type.WALL: preload("res://assets/tiles/models/wall.obj"),
}

## Damage taken by a piece that starts its turn on the terrain, ignoring defence dice, defence and shields
const HAZARD_DAMAGE: Dictionary[Type, int] = {
	Type.HAZARDOUS: 1,
}

## Effect played when a piece lands on the terrain
const EFFECTS: Dictionary[Type, PackedScene] = {
	Type.NORMAL: preload("res://scenes/board/effects/grass_blades.tscn"),
	Type.DIFFICULT: preload("res://scenes/board/effects/dust_puff.tscn"),
	Type.HAZARDOUS: preload("res://scenes/board/effects/stone_chips.tscn"),
	Type.WATER: preload("res://scenes/board/effects/water_splash.tscn"),
}


static func cost(type: Type) -> int:
	return COSTS[type]


static func is_walkable(type: Type) -> bool:
	return COSTS[type] > 0


static func hazard_damage(type: Type) -> int:
	return HAZARD_DAMAGE.get(type, 0)
