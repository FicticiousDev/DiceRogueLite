class_name UnlockChallenge
extends Resource

## A goal that unlocks a character or a die design for good (data/challenges/). Progress is read from the lifetime
## stats and counters (ProgressionData.stat_value) plus the run in progress, so it can complete mid-run.
## - no [member subjects]: [member stat] must reach [member target]
## - subjects, TOTAL: the "stat:subject" counters added up must reach [member target]
## - subjects, EACH: every "stat:subject" counter must reach [member target]

enum Reward { CHARACTER, DIE_DESIGN }
enum Mode { TOTAL, EACH }

@export var id: StringName
## How to unlock it, shown on locked characters and designs. Localised: the key is CHALLENGE_<ID>_DESC
var description: String:
	get: return tr("CHALLENGE_%s_DESC" % String(id).to_upper())
@export var reward: Reward = Reward.CHARACTER
@export var reward_id: StringName
@export var stat: StringName
@export var subjects: Array[StringName] = []
@export var mode: Mode = Mode.TOTAL
@export var target: int = 1


## Progress so far, out of [method goal].
func progress(progression: ProgressionData, run: RunData = null) -> int:
	if subjects.is_empty():
		return progression.stat_value(String(stat), run)
	var total := 0
	for subject in subjects:
		var value := progression.stat_value("%s:%s" % [stat, subject], run)
		total += (1 if value >= target else 0) if mode == Mode.EACH else value
	return total


func goal() -> int:
	return subjects.size() if mode == Mode.EACH and subjects.size() > 0 else target


func is_complete(progression: ProgressionData, run: RunData = null) -> bool:
	return progress(progression, run) >= goal()


## "3 / 5", capped at the goal.
func progress_text(progression: ProgressionData, run: RunData = null) -> String:
	return "%d / %d" % [mini(progress(progression, run), goal()), goal()]


## What it unlocks, e.g. "Monk" or "Glacier die design".
func reward_name() -> String:
	if reward == Reward.CHARACTER:
		var character: CharacterData = Database.get_content("characters", reward_id)
		return character.display_name if character else String(reward_id)
	var design: DieDesign = Database.get_content("die_designs", reward_id)
	return tr("UNLOCK_DIE_DESIGN_REWARD") % (design.display_name if design else String(reward_id))
