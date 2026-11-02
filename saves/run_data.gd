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

## Stats for the run end summary, added to ProgressionData when the run ends. Kept here rather than in
## ProgressionData so a level resumed from its checkpoint doesn't count twice.
@export var turns: int = 0
@export var levels_cleared: int = 0
@export var enemies_defeated: int = 0
@export var bosses_defeated: int = 0
@export var gold_earned: int = 0
@export var damage_dealt: int = 0
@export var damage_received: int = 0
## Player attacks that crit
@export var crits: int = 0
## Enemy attacks that missed the player
@export var misses: int = 0

## TODO - track effects and upgraded dice


## Adds [amount] gold, counting it as earned.
func add_gold(amount: int) -> void:
	gold += amount
	gold_earned += amount
