class_name DefenceBonusAbility
extends Ability

## Passive: every rolled defence die gets [amount] extra shields, like a defence buff.

@export var amount: int = 1


func modify_result(result: DieResult) -> bool:
	if result.category() != DieFace.Category.DEFENCE or not result.face().is_numeric():
		return false
	result.bonus += amount
	return true
