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
## Counts for unlock challenges, added from each finished run (RunData.counters), plus "flawless_victory" (runs won
## without taking damage from a boss)
@export var counters: Dictionary = {}
## Per character id, the ids of the bosses (EnemyData) it has defeated, shown as gems on its card (CharacterPicker)
@export var bosses_defeated_by: Dictionary = {}

## Unlocks
@export var unlocked_characters: Array[String] = []
@export var unlocked_items: Array[String] = []
@export var unlocked_dice: Array[String] = []

## Cosmetics: the die design (shape) and its finishes (DieFinish) - the main one, and the trim's for designs that have
## one. Designs that don't start unlocked are unlocked by challenges (UnlockChallenge)
@export var die_design: String = "classic"
@export var die_finish: String = "plastic"
@export var die_trim_finish: String = "brass"
@export var unlocked_die_designs: Array[String] = ["classic", "sharp"]

## Order of the designs and finishes in the dice designer, least impressive first; designs unlocked last go last.
## Ids not listed follow, by id.
const DIE_DESIGN_ORDER: Array[StringName] = [
	&"classic", &"sharp", &"chamfer", &"pebble", &"ember", &"venom", &"thunder", &"blink", &"gilded",
	&"bog", &"glacier", &"sandstorm", &"iron", &"inferno", &"void", &"crowned",
]
const DIE_FINISH_ORDER: Array[StringName] = [
	&"plastic", &"wood", &"flecked", &"rust", &"marble", &"metal", &"brass", &"pearl", &"glass",
	&"obsidian", &"galaxy",
]

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
	gold_spent += run.gold_spent
	damage_dealt += run.damage_dealt
	damage_received += run.damage_received
	crits += run.crits
	misses += run.misses
	dice_obtained += run.dice_obtained
	items_obtained += run.items_obtained
	for key in run.counters:
		counters[key] = int(counters.get(key, 0)) + int(run.counters[key])
	if outcome == Outcome.VICTORY and int(run.counters.get("boss_damage", 0)) == 0:
		counters["flawless_victory"] = int(counters.get("flawless_victory", 0)) + 1
	_record_bosses(run)


## Adds the bosses [run] defeated (its "boss_defeated:<boss id>" counters) to its character's.
func _record_bosses(run: RunData) -> void:
	var beaten: Array = bosses_defeated_by.get(run.character_id, [])
	for key in run.counters:
		var boss := String(key).trim_prefix("boss_defeated:")
		if boss != String(key) and boss not in beaten:
			beaten.append(boss)
	if not beaten.is_empty():
		bosses_defeated_by[run.character_id] = beaten


## True if [character_id] has defeated the boss [boss_id] in a finished run.
func has_defeated(character_id: StringName, boss_id: StringName) -> bool:
	return String(boss_id) in bosses_defeated_by.get(String(character_id), [])


## True if [type] can drop as loot: unlocked from the start, or unlocked since.
func is_die_unlocked(type: DieType) -> bool:
	return type.starts_unlocked or unlocked_dice.has(String(type.id))


## True if [item] can drop as loot: unlocked from the start, or unlocked since.
func is_item_unlocked(item: EquipmentData) -> bool:
	return item.starts_unlocked or unlocked_items.has(String(item.id))


## Loot dice and items not unlocked yet, as DieType / EquipmentData. A Mystery piece unlocks one of them.
func locked_content() -> Array[Resource]:
	var result: Array[Resource] = []
	for type: DieType in Database.get_all("dice"):
		if type.loot and not is_die_unlocked(type):
			result.append(type)
	for item: EquipmentData in Database.get_all("equipment"):
		if item.loot and not is_item_unlocked(item):
			result.append(item)
	return result


## Unlocks [content] (a DieType or EquipmentData) for good, so loot, rewards and shops can offer it.
func unlock(content: Resource) -> void:
	if content is DieType and not unlocked_dice.has(String(content.id)):
		unlocked_dice.append(String(content.id))
	elif content is EquipmentData and not unlocked_items.has(String(content.id)):
		unlocked_items.append(String(content.id))


## Debug: unlocks every character, die, item and die design, whatever their challenges. Caller saves.
func unlock_all() -> void:
	unlocked_characters.assign(_ids("characters"))
	unlocked_dice.assign(_ids("dice"))
	unlocked_items.assign(_ids("equipment"))
	unlocked_die_designs.assign(_ids("die_designs"))


func _ids(category: String) -> Array[String]:
	var ids: Array[String] = []
	for content in Database.get_all(category):
		ids.append(String(content.id))
	return ids


## [items] (resources with an id) sorted as listed in [order]; ids not listed go last, by id.
static func sorted_by_order(items: Array, order: Array[StringName]) -> Array:
	var sorted := items.duplicate()
	var rank := func(item: Resource) -> int:
		var index := order.find(item.id)
		return index if index != -1 else order.size()
	sorted.sort_custom(func(a: Resource, b: Resource):
		var ra: int = rank.call(a)
		var rb: int = rank.call(b)
		return ra < rb if ra != rb else String(a.id) < String(b.id))
	return sorted


## True if [character] can be picked: unlocked from the start, or unlocked since.
func is_character_unlocked(character: CharacterData) -> bool:
	return character.starts_unlocked or unlocked_characters.has(String(character.id))


# ===========================================================================================================================================
# Challenges
# ===========================================================================================================================================


## A stat for challenges: one of the lifetime stats above (e.g. "crits", "victories") or a counter, plus the same in
## [run] if given (the run in progress, not yet recorded).
func stat_value(stat: String, run: RunData = null) -> int:
	var total := int(get(stat)) if stat in self else int(counters.get(stat, 0))
	if run:
		total += int(run.get(stat)) if stat in run else int(run.counters.get(stat, 0))
	return total


## True if [design] can be picked: unlocked from the start, or unlocked since.
func is_design_unlocked(design: DieDesign) -> bool:
	return design.starts_unlocked or unlocked_die_designs.has(String(design.id))


## True if what [challenge] unlocks is already unlocked.
func is_rewarded(challenge: UnlockChallenge) -> bool:
	match challenge.reward:
		UnlockChallenge.Reward.CHARACTER:
			return unlocked_characters.has(String(challenge.reward_id))
		_:
			return unlocked_die_designs.has(String(challenge.reward_id))


## The challenge that unlocks [reward_id] (a character or die design id), or null.
func challenge_for(reward_id: StringName) -> UnlockChallenge:
	for challenge: UnlockChallenge in Database.get_all("challenges"):
		if challenge.reward_id == reward_id:
			return challenge
	return null


## Unlocks the reward of every challenge now complete (counting [run] in progress, if given) that wasn't before.
## Returns those challenges; the caller saves and announces them.
func complete_challenges(run: RunData = null) -> Array[UnlockChallenge]:
	var done: Array[UnlockChallenge] = []
	for challenge: UnlockChallenge in Database.get_all("challenges"):
		if not is_rewarded(challenge) and challenge.is_complete(self, run):
			if challenge.reward == UnlockChallenge.Reward.CHARACTER:
				unlocked_characters.append(String(challenge.reward_id))
			else:
				unlocked_die_designs.append(String(challenge.reward_id))
			done.append(challenge)
	return done
