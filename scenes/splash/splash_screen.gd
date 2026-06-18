extends CanvasLayer

@export var fade_in_time: float = 0.5
@export var fade_out_label_time: float = 0.1
@export var fade_out_time: float = 0.5
@export var hold_time: float = 1.5
@export var translate_time: float = 0.5
@export var start_delay: float = 0.8

@onready var background: ColorRect = $Background
@onready var studio: Control = $Studio
@onready var engine: Control = $Engine
@onready var game: Control = $Game


func _ready() -> void:
	if not SaveManager.settings_data.skip_splash:
		await get_tree().create_timer(start_delay).timeout
		await show_logo(studio)
		await show_logo(engine)
		show_game_name()
	else:
		queue_free()


func show_logo(logo: Control) -> void:
	await fade_in_and_hold(logo)
	
	# Fade out label and move image
	var fade_out_label_tween := create_tween().tween_property(logo.get_node("Label"), "modulate", Color(1,1,1,0), fade_out_label_time)
	await translate_iamge_to_target(logo.get_node("Image"), logo.get_node("Target"))


func fade_in_and_hold(control: Control) -> void:
	# Fade in
	var fade_in_tween := create_tween().tween_property(control, "modulate", Color(1,1,1,1), fade_in_time)
	await fade_in_tween.finished
	# Hold
	await get_tree().create_timer(hold_time).timeout


func translate_iamge_to_target(source: TextureRect, target: TextureRect) -> void:
	var translate_tween := create_tween()
	translate_tween.set_parallel(true)
	translate_tween.tween_property(source, "position", target.position, translate_time)
	translate_tween.tween_property(source, "scale", target.scale, translate_time)
	translate_tween.tween_property(source, "rotation", target.rotation, translate_time)
	await translate_tween.finished


func show_game_name() -> void:
	await fade_in_and_hold(game)
	fade_out(background)
	fade_out(studio)
	fade_out(engine)
	await translate_iamge_to_target(game.get_node("Image"), game.get_node("Target"))
	await fade_out(game)
	queue_free()


func fade_out(target: Control) -> void:
	var fade_out_tween := create_tween().tween_property(target, "modulate", Color(1,1,1,0), fade_out_time)
	await fade_out_tween.finished
