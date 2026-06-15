extends Resource
class_name ProgressionData

## Stats
@export var runs: int = 0
@export var gold_earned: int = 0
@export var gold_spent: int = 0
@export var gold_lost: int = 0
@export var enemies_defeated: int = 0
@export var bosses_defeated: int = 0
@export var dice_obtained: int = 0
@export var dice_upgraded: int = 0
@export var rerolls: int = 0
@export var deaths: int = 0
@export var damage_dealt: int = 0
@export var damage_received: int = 0
@export var crits: int = 0
@export var misses: int = 0

## Unlocks
@export var unlocked_characters: Array[String] = []
@export var unlocked_items: Array[String] = []
@export var unlocked_dice: Array[String] = []

## Bank
@export var gold_in_bank: int = 0
