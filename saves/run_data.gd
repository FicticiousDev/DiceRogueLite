extends Resource
class_name RunData

## Data relevant to the current run
@export var character_id: String
@export var gold: int = 0
## Map index of the level whose bank has been used (one transaction per visit), or -1
@export var bank_used_at: int = -1
@export var health: int = 10
@export var max_health: int = 10
@export var items: Array[String] = []
@export var dice: Array[String] = []
## Equipped item ids by slot (see [constant SLOTS]); "" for an empty slot
@export var equipment: Array[String] = ["", "", "", ""]

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
@export var gold_spent: int = 0
@export var damage_dealt: int = 0
@export var damage_received: int = 0
## Player attacks that crit
@export var crits: int = 0
## Enemy attacks that missed the player
@export var misses: int = 0
## Dice added to the pool (awards, chests; swaps included)
@export var dice_obtained: int = 0
## Items equipped from loot (replacements included)
@export var items_obtained: int = 0

## TODO - track effects and upgraded dice


## The slot type of each equipment slot: 1 armour, 1 boots, 2 charms.
const SLOTS: Array[int] = [EquipmentData.Slot.ARMOUR, EquipmentData.Slot.BOOTS, EquipmentData.Slot.CHARM, EquipmentData.Slot.CHARM]


## Equipped items, in slot order (empty slots skipped).
func equipped() -> Array[EquipmentData]:
	var result: Array[EquipmentData] = []
	for id in equipment:
		if id != "":
			var item: EquipmentData = Database.get_content("equipment", id)
			if item:
				result.append(item)
	return result


## Item in slot [index], or null.
func item_in(index: int) -> EquipmentData:
	return Database.get_content("equipment", equipment[index]) if index < equipment.size() and equipment[index] != "" else null


## Slots [item] can go in.
static func slots_for(item: EquipmentData) -> Array[int]:
	var result: Array[int] = []
	for i in SLOTS.size():
		if SLOTS[i] == item.slot:
			result.append(i)
	return result


## Puts [item] in slot [index], replacing what was there. Maximum health follows the items' bonuses; gaining a bonus
## also heals by it, losing one never takes health below 1.
func equip(item: EquipmentData, index: int) -> void:
	equipment.resize(SLOTS.size())
	var old := item_in(index)
	if old:
		max_health -= old.max_hp
	equipment[index] = String(item.id)
	max_health += item.max_hp
	health = clampi(health + maxi(item.max_hp, 0), 1, max_health)


## Adds [amount] gold, counting it as earned.
func add_gold(amount: int) -> void:
	gold += amount
	gold_earned += amount


## Takes [amount] gold, counting it as spent (shops).
func spend_gold(amount: int) -> void:
	gold -= amount
	gold_spent += amount
