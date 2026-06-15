extends Resource
class_name SettingsData

## Graphics
@export var resolution: Vector2 = Vector2i(1920, 1080)
@export var fullscreen: bool = false
@export var borderless: bool = false
@export var vsync: bool = true
@export var brightness: float = 1.0
@export var contrast: float = 1.0
@export var antialiasing: bool = true
@export var shadows: bool = true
@export var ui_scale: float = 1.0

## Audio
@export var music_volume: float = 1.0
@export var sfx_volume: float = 1.0
@export var ui_volume: float = 1.0
@export var master_volume: float = 1.0

## Gameplay
@export var skip_splash: bool = false
@export var show_fps: bool = false
@export var skip_tutorials: bool = false
