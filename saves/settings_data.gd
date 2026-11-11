extends Resource
class_name SettingsData

const SIDE_LEFT: int = 0
const SIDE_RIGHT: int = 1

## Gameplay
@export var show_fps: bool = true
@export var skip_splash: bool = false
@export var animation_speed: float = 1.0
@export var fast_dice: bool = false
@export var screen_shake: bool = true
@export var confirm_unused_dice: bool = true
@export var auto_spend_defence: bool = false
## Side of the board the turn plan panel sits on (SIDE_LEFT / SIDE_RIGHT, the option button order)
@export_enum("Left", "Right") var turn_plan_side: int = SIDE_RIGHT
## Gamepad prompt icons: 0 follows the connected controller, 1 Xbox, 2 PlayStation (InputMode.PadScheme)
@export_enum("Auto", "Xbox", "PlayStation") var controller_scheme: int = 0

## Graphics
@export var resolution: Vector2 = Vector2i(1920, 1080)
@export var resolution_scale: float = 100.0
@export var resolution_scaler: int = Viewport.SCALING_3D_MODE_BILINEAR
@export var fsr_profile: int = 3
@export var antialiasing: int = 0
@export var screen_space_aa: int = 0
@export var fullscreen: bool = false
@export var borderless: bool = false
@export var vsync: bool = true
@export var max_fps: int = 0
@export var shadow_quality: int = 2
@export var screen: int = 0
@export var brightness: float = 1.0
@export var contrast: float = 1.0

## Audio
@export var master_volume: float = 0.7
@export var music_volume: float = 1.0
@export var sfx_volume: float = 1.0
@export var ui_volume: float = 1.0
