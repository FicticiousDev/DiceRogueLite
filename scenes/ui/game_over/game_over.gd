class_name GameOverScreen
extends CanvasLayer

## Shown when the player dies. Ends the run and returns to the main menu.

const MAIN_MENU_SCENE: String = "res://scenes/ui/main_menu/main_menu.tscn"

@onready var panel: PanelContainer = %Panel
@onready var stats_label: Label = %Stats
@onready var menu_button: Button = %MenuButton


func _ready() -> void:
	menu_button.pressed.connect(_on_menu_pressed)


func show_screen(turns: int) -> void:
	var run := SaveManager.run_data
	stats_label.text = "Turns survived: %d\nGold: %d\nDice in pool: %d" % [turns, run.gold, run.dice.size()]
	visible = true
	panel.pivot_offset = panel.size / 2.0
	panel.scale = Vector2.ONE * 0.6
	panel.modulate.a = 0.0
	var tween := create_tween().set_parallel(true)
	tween.tween_property(panel, "scale", Vector2.ONE, Anim.t(0.5)).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "modulate:a", 1.0, Anim.t(0.3))


func _on_menu_pressed() -> void:
	var progression := SaveManager.progression_data
	progression.runs += 1
	progression.deaths += 1
	SaveManager.clear_run()
	SaveManager.save_data()
	SceneManager.change_scene(MAIN_MENU_SCENE)
