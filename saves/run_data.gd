extends Resource
class_name RunData

## Data relevant to the current run
@export var character_id: String
@export var gold: int = 0
@export var health: int = 1
@export var items: Array[String] = []
@export var dice: Array[String] = []

@export var area: int = 0
@export var area_stage: int = 0
@export var shop_visited: bool = false
@export var levels_completed: int = 0

## TODO - track effects and upgraded dice
