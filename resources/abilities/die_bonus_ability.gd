class_name DieBonusAbility
extends Ability

## Passive: every rolled die of [category] gets [amount] extra symbols, like a buff (capped as buffs are).

@export var category: DieFace.Category = DieFace.Category.MOVE
@export var amount: int = 1


func modify_result(result: DieResult) -> bool:
	if result.category() != category or not result.can_buff():
		return false
	result.bonus += amount
	return true
