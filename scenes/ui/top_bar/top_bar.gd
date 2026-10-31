class_name TopBar
extends PanelContainer

## Status bar along the top: HP, gold, banked gold (greyed while the bank is empty).

const HEART: Texture2D = preload("res://assets/ui/icons/heart.png")
const COIN: Texture2D = preload("res://assets/ui/icons/coin.png")
const BANK: Texture2D = preload("res://assets/ui/icons/bank.png")

@onready var stats: HBoxContainer = %Stats

var _hp: StatIcon
var _gold: StatIcon
var _bank: StatIcon


func _ready() -> void:
	_hp = _add(HEART, Color(1, 0.35, 0.35))
	_gold = _add(COIN, Color(1, 0.82, 0.3))
	_bank = _add(BANK, Color(0.75, 0.8, 0.9))


func _process(_delta: float) -> void:
	var run := SaveManager.run_data
	var low := run.health <= run.max_health / 3
	_hp.set_value("%d / %d" % [run.health, run.max_health], Color(1, 0.4, 0.35) if low else Color.WHITE)
	_gold.set_value(str(run.gold))
	var bank := SaveManager.progression_data.gold_in_bank
	_bank.set_value(str(bank))
	_bank.modulate.a = 1.0 if bank > 0 else 0.35


func _add(texture: Texture2D, color: Color) -> StatIcon:
	var stat := StatIcon.create(texture, color, 24, 30)
	stats.add_child(stat)
	return stat
