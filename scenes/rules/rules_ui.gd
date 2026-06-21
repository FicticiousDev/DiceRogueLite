extends CanvasLayer

signal close_requested

@onready var scroll_container: ScrollContainer = $AspectRatioContainer/Rules/RulesSection/ScrollContainer
@onready var rules_section: Control = $AspectRatioContainer/Rules/RulesSection
@onready var rules_rect: Control = $AspectRatioContainer/Rules
@onready var sections_vbox: VBoxContainer = $AspectRatioContainer/Rules/RulesSection/ScrollContainer/MarginContainer/SectionsVBox

@onready var intro_section: Control = $AspectRatioContainer/Rules/RulesSection/ScrollContainer/MarginContainer/SectionsVBox/Introduction
@onready var combat_section: Control = $AspectRatioContainer/Rules/RulesSection/ScrollContainer/MarginContainer/SectionsVBox/Combat
@onready var progression_section: Control = $AspectRatioContainer/Rules/RulesSection/ScrollContainer/MarginContainer/SectionsVBox/Progression
@onready var credits_section: Control = $AspectRatioContainer/Rules/RulesSection/ScrollContainer/MarginContainer/SectionsVBox/Credits

var _scroll_tween: Tween


func _ready() -> void:
	# Connect bookmarks
	$AspectRatioContainer/Rules/BookmarksPanel/VBox/IntroductionBtn.pressed.connect(func(): scroll_to_section(intro_section))
	$AspectRatioContainer/Rules/BookmarksPanel/VBox/CombatBtn.pressed.connect(func(): scroll_to_section(combat_section))
	$AspectRatioContainer/Rules/BookmarksPanel/VBox/ProgressionBtn.pressed.connect(func(): scroll_to_section(progression_section))
	$AspectRatioContainer/Rules/BookmarksPanel/VBox/CreditsBtn.pressed.connect(func(): scroll_to_section(credits_section))
	
	# Connect exit button
	$AspectRatioContainer/Rules/BookmarksPanel/VBox/ExitBtn.pressed.connect(_on_exit_pressed)


func get_rules_rect() -> Control:
	return rules_rect


func scroll_to_section(target_node: Control) -> void:
	if _scroll_tween:
		_scroll_tween.kill()
	
	# Calculate target vertical position relative to the VBoxContainer
	var target_y = target_node.position.y
	
	_scroll_tween = create_tween()
	_scroll_tween.tween_property(scroll_container, "scroll_vertical", int(target_y), 0.4)\
		.set_ease(Tween.EASE_OUT)\
		.set_trans(Tween.TRANS_QUAD)


func _on_exit_pressed() -> void:
	emit_signal("close_requested")
