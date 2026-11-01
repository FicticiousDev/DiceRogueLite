extends Resource
class_name RunData

## Data relevant to the current run
@export var character_id: String
@export var gold: int = 0
@export var health: int = 10
@export var max_health: int = 10
@export var items: Array[String] = []
@export var dice: Array[String] = []

## The run's level graph, generated up front (see RunMap)
@export var map: Array[Dictionary] = []
## Map indices of the levels entered, in order; the last is the current level
@export var path: Array = []

## TODO - track effects and upgraded dice
