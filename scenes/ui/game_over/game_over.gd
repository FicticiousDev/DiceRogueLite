class_name GameOverScreen
extends CanvasLayer

## Run end summary, for a defeat or a completed run: where it ended, the run's stats and the lifetime totals.
## The run has already been ended (SaveManager.end_run) when this shows; MAIN MENU just leaves.

const MAIN_MENU_SCENE: String = "res://scenes/ui/main_menu/main_menu.tscn"
const DEFEAT_COLOR: Color = Color(1, 0.35, 0.3)
const VICTORY_COLOR: Color = Color(1.0, 0.82, 0.35)
const VALUE_COLOR: Color = Color(1.0, 0.92, 0.75)

@onready var panel: PanelContainer = %Panel
@onready var title: Label = %Title
@onready var subtitle: Label = %Subtitle
@onready var stats: GridContainer = %Stats
@onready var lifetime: Label = %Lifetime
@onready var menu_button: Button = %MenuButton


func _ready() -> void:
	menu_button.pressed.connect(_on_menu_pressed)


## Shows the summary of [run], which ended with [outcome]. [unlocked]: challenges the run's end completed.
func show_screen(run: RunData, outcome: ProgressionData.Outcome, unlocked: Array[UnlockChallenge] = []) -> void:
	var won := outcome == ProgressionData.Outcome.VICTORY
	title.text = "RUN COMPLETE" if won else "DEFEATED"
	title.add_theme_color_override("font_color", VICTORY_COLOR if won else DEFEAT_COLOR)
	var character: CharacterData = Database.get_content("characters", run.character_id)
	var biome := RunMap.biome(run, RunMap.current_index(run))
	subtitle.text = "%s  ·  %s %s  ·  level %d" % [character.display_name if character else "?",
		"conquered the" if won else "fell in the", biome.display_name, run.path.size()]

	for child in stats.get_children():
		child.queue_free()
	var rows: Array[Control] = []
	for entry in [
		["Levels cleared", run.levels_cleared],
		["Turns", run.turns],
		["Enemies defeated", run.enemies_defeated],
		["Bosses defeated", run.bosses_defeated],
		["Gold earned", run.gold_earned],
		["Gold spent", run.gold_spent],
		["Damage dealt", run.damage_dealt],
		["Damage taken", run.damage_received],
		["Critical hits", run.crits],
		["Enemy misses", run.misses],
		["Dice obtained", run.dice_obtained],
		["Items obtained", run.items_obtained],
		["Dice in pool", run.dice.size()],
	]:
		rows.append(_label(entry[0], Color(0.8, 0.8, 0.85), HORIZONTAL_ALIGNMENT_LEFT))
		rows.append(_label(str(entry[1]), VALUE_COLOR, HORIZONTAL_ALIGNMENT_RIGHT))
	for row in rows:
		stats.add_child(row)
	var progression := SaveManager.progression_data
	lifetime.text = "All runs: %d played  ·  %d won  ·  %d lost" % [progression.runs, progression.victories, progression.deaths]
	if unlocked.size() > 0:
		lifetime.text += "\nUnlocked: " + ", ".join(unlocked.map(func(c: UnlockChallenge): return c.reward_name()))

	visible = true
	panel.pivot_offset = panel.size / 2.0
	panel.scale = Vector2.ONE * 0.6
	panel.modulate.a = 0.0
	var tween := create_tween().set_parallel(true)
	tween.tween_property(panel, "scale", Vector2.ONE, Anim.t(0.5)).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "modulate:a", 1.0, Anim.t(0.3))
	# Stats appear a line at a time (fade only: the grid owns their positions)
	for i in rows.size():
		rows[i].modulate.a = 0.0
		create_tween().tween_property(rows[i], "modulate:a", 1.0, Anim.t(0.15)).set_delay(Anim.t(0.3 + 0.07 * int(i / 2.0)))


func _label(text: String, color: Color, align: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = align
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", color)
	return label


func _on_menu_pressed() -> void:
	menu_button.disabled = true
	SceneManager.change_scene(MAIN_MENU_SCENE)
