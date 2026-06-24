extends Node3D

@onready var settings_scene: SettingsScene = $Settings
@onready var exit_confirmation: ConfirmExit = $ConfirmExit
@onready var rulebook = $Rulebook
@onready var rules_ui = $RulesUI


## TODO - transition from rulebook screen to rule_ui to look like a tablet switching screen


func _ready() -> void:
	exit_confirmation.exit_confirmed.connect(_on_confirm_exit_pressed)
	exit_confirmation.cancel_exit.connect(_on_cancel_exit_pressed)
	rulebook.rules_pressed.connect(_on_rulebook_rules_pressed)
	rulebook.rules_showing.connect(_on_rulebook_rules_showing)
	rulebook.set_ui_targets(rules_ui, $Camera)
	rules_ui.close_requested.connect(_on_rules_close_requested)
	
	# Show UI briefly on startup to force layout computation, then hide it
	rules_ui.visible = true
	await get_tree().process_frame
	rules_ui.visible = false


func _on_rulebook_rules_pressed() -> void:
	rulebook.show_rules()


func _on_rulebook_rules_showing() -> void:
	rules_ui.visible = true


func _on_rules_close_requested() -> void:
	rules_ui.visible = false
	rulebook.hide_rules()


func _on_settings_button_settings_pressed() -> void:
	get_node("Settings").show_settings()


func _on_exit_button_exit_pressed() -> void:
	exit_confirmation.show_confirmation()


func _on_confirm_exit_pressed() -> void:
	SaveManager.save_data()
	get_tree().quit()


func _on_cancel_exit_pressed() -> void:
	exit_confirmation.hide_confirmation()
