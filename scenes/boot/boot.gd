extends Node

## First scene of the game. Only the splash and the loading screen (shader compile) exist until that is done; then the
## main menu is loaded, added underneath the loading screen, drawn a few frames, and only then does the loading screen
## fade out. This scene frees itself afterwards and the menu becomes the current scene.

const MENU_SCENE: String = "res://scenes/ui/main_menu/main_menu.tscn"
## Frames the menu is drawn under the opaque loading screen before it fades (first draws build its own pipelines)
const MENU_DRAW_FRAMES: int = 3

@onready var splash: SplashScreen = $SplashScreen
@onready var loading_screen: LoadingScreen = $LoadingScreen


func _ready() -> void:
	_run()


func _run() -> void:
	await splash.play()
	# Fades in over the splash, compiles every shader, stays up for its minimum time
	await loading_screen.run(splash)

	# Only now is the menu touched at all
	ResourceLoader.load_threaded_request(MENU_SCENE)
	while ResourceLoader.load_threaded_get_status(MENU_SCENE) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		await get_tree().process_frame
	var packed := ResourceLoader.load_threaded_get(MENU_SCENE) as PackedScene
	if packed == null:
		push_error("Boot: can't load " + MENU_SCENE)
		return
	var menu := packed.instantiate()
	get_tree().root.add_child(menu)
	get_tree().current_scene = menu
	# Menu is ready and has been drawn (hidden under the loading screen) by the time the loading screen lets go
	for i in MENU_DRAW_FRAMES:
		await RenderingServer.frame_post_draw
	await loading_screen.close()
	queue_free()
