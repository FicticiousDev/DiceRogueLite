class_name Terrain
extends RefCounted

## Terrain types painted into a level's Layout layer (TileSet custom data "terrain").

enum Type { NORMAL, DIFFICULT, EXTREME, WATER, WALL }

## Movement cost per tile entered. -1 = impassable.
const COSTS: Dictionary[Type, int] = {
	Type.NORMAL: 1,
	Type.DIFFICULT: 2,
	Type.EXTREME: 3,
	Type.WATER: 2,
	Type.WALL: -1,
}

const COLORS: Dictionary[Type, Color] = {
	Type.NORMAL: Color(0.45, 0.62, 0.35),
	Type.DIFFICULT: Color(0.59, 0.47, 0.31),
	Type.EXTREME: Color(0.47, 0.31, 0.41),
	Type.WATER: Color(0.31, 0.51, 0.75),
	Type.WALL: Color(0.45, 0.45, 0.5),
}

## Height of the tile's top surface in world units.
const HEIGHTS: Dictionary[Type, float] = {
	Type.NORMAL: 0.3,
	Type.DIFFICULT: 0.35,
	Type.EXTREME: 0.4,
	Type.WATER: 0.18,
	Type.WALL: 0.9,
}


static func cost(type: Type) -> int:
	return COSTS[type]


static func is_walkable(type: Type) -> bool:
	return COSTS[type] > 0
