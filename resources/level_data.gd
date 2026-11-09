class_name LevelData
extends Resource

## A level layout. Levels belong to a biome stage (1 = the run's first biome ... 4 = the last), getting bigger each
## stage; the biome supplies the tile colours and enemies. Shops (stage 0) fit any stage.

enum Type { NORMAL, SHOP, SHOP_BANK, CHALLENGE, BOSS }

## Symbol shown on exit gates and the run map for each level type
const ICONS: Dictionary[Type, Texture2D] = {
	Type.NORMAL: preload("res://assets/ui/icons/sword.png"),
	Type.SHOP: preload("res://assets/ui/icons/coin.png"),
	Type.SHOP_BANK: preload("res://assets/ui/icons/bank.png"),
	Type.CHALLENGE: preload("res://assets/ui/icons/star.png"),
	Type.BOSS: preload("res://assets/ui/icons/crown.png"),
}
## Localisation keys of the level type names: wrap in tr() where shown
const NAMES: Dictionary[Type, String] = {
	Type.NORMAL: "LEVEL_BATTLE",
	Type.SHOP: "LEVEL_SHOP",
	Type.SHOP_BANK: "LEVEL_SHOP_BANK",
	Type.CHALLENGE: "LEVEL_CHALLENGE",
	Type.BOSS: "LEVEL_BOSS",
}

@export var id: StringName
@export var type: Type = Type.NORMAL
@export var scene: PackedScene
## Exit markers in the scene: the most connections a level of this layout can have
@export var exit_count: int = 3
## Challenge levels: clear within this many turns for the challenge reward (0 = no limit)
@export var turn_limit: int = 0
## Biome stage the layout is sized for (BiomeData.stage); 0 = any stage (shops). Combat levels with 0 are unused
@export_range(0, 4) var stage: int = 0
