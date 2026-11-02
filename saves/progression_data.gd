extends Resource
class_name ProgressionData

## How a run ended
enum Outcome { DEFEAT, VICTORY, ABANDONED }

## Stats
@export var runs: int = 0
@export var victories: int = 0
@export var turns: int = 0
@export var levels_cleared: int = 0
@export var gold_earned: int = 0
@export var gold_spent: int = 0
@export var gold_lost: int = 0
@export var enemies_defeated: int = 0
@export var bosses_defeated: int = 0
@export var dice_obtained: int = 0
@export var items_obtained: int = 0
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

## Cosmetics. Designs become unlockable collectables in a later phase
@export var die_design: String = "classic"
@export var unlocked_die_designs: Array[String] = ["classic", "sharp"]

## Bank
@export var gold_in_bank: int = 0


## Adds a finished run's stats.
func record_run(run: RunData, outcome: Outcome) -> void:
	runs += 1
	if outcome == Outcome.DEFEAT:
		deaths += 1
	elif outcome == Outcome.VICTORY:
		victories += 1
	turns += run.turns
	levels_cleared += run.levels_cleared
	enemies_defeated += run.enemies_defeated
	bosses_defeated += run.bosses_defeated
	gold_earned += run.gold_earned
	damage_dealt += run.damage_dealt
	damage_received += run.damage_received
	crits += run.crits
	misses += run.misses
	dice_obtained += run.dice_obtained
	items_obtained += run.items_obtained


## True if [type] can drop as loot: unlocked from the start, or unlocked since.
func is_die_unlocked(type: DieType) -> bool:
	return type.starts_unlocked or unlocked_dice.has(String(type.id))


## True if [item] can drop as loot: unlocked from the start, or unlocked since.
func is_item_unlocked(item: EquipmentData) -> bool:
	return item.starts_unlocked or unlocked_items.has(String(item.id))


## True if [character] can be picked: unlocked from the start, or unlocked since.
func is_character_unlocked(character: CharacterData) -> bool:
	return character.starts_unlocked or unlocked_characters.has(String(character.id))
