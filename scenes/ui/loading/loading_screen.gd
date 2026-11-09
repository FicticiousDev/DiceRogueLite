class_name LoadingScreen
extends CanvasLayer

## Game name on black with a status line, shown once per launch after the splash. Fades in over everything (the name sits
## exactly over the one embossed in the splash's die, so it seems to lift off it), compiles all
## shaders (ShaderWarmup, list in ShaderList) and stays up for at least [constant MIN_DURATION]. It then waits, fully
## opaque, until the caller has the next scene loaded and showing and calls [method close], which fades it out and frees
## it. Not part of the splash, so the skip-splash setting doesn't affect it. See scenes/boot/boot.gd.
## Use: await loading_screen.run(splash) ... await loading_screen.close()

## Seconds the screen is fully shown, even if compiling finishes sooner
const MIN_DURATION: float = 1.0
const STATUS_TEXT: String = "Compiling shaders"

## Set once run so returning to the main menu doesn't show it again
static var has_run: bool = false

## Fade out, and fade in (the black comes in over this long, the name and status inside it)
@export var fade_time: float = 0.5
@export var fade_in_time: float = 1.4

@onready var root: Control = %Root
@onready var warmup_host: Control = %Warmup
@onready var status: Label = %Status
@onready var background: ColorRect = %Background
@onready var game_name: TextureRect = %Name


func _ready() -> void:
	# Invisible until run() fades it in
	background.modulate.a = 0.0
	game_name.modulate.a = 0.0
	status.modulate.a = 0.0


## Fades in and compiles, then returns with the screen still fully shown. [behind] (e.g. the splash) is freed as soon as
## this screen is fully opaque.
func run(behind: Node = null) -> void:
	if has_run:
		if behind:
			behind.queue_free()
		return
	has_run = true
	_layout()
	await _fade_in()
	if behind:
		behind.queue_free()
	var shown_at := Time.get_ticks_msec()
	var warmup := ShaderWarmup.new()
	add_child(warmup)
	await warmup.run(warmup_host, _on_progress)
	warmup.queue_free()
	var remaining := MIN_DURATION - (Time.get_ticks_msec() - shown_at) / 1000.0
	if remaining > 0.0:
		await get_tree().create_timer(remaining).timeout


## Fades out and frees the screen. Call once whatever is behind it is loaded and drawn.
func close() -> void:
	await _fade(0.0)
	queue_free()


## Puts the name where the splash's die carries it and the status line under it.
func _layout() -> void:
	var view := get_viewport().get_visible_rect().size
	var image := game_name.texture.get_image()
	if image.is_compressed():
		image.decompress()
	var used := image.get_used_rect()
	if not used.has_area():
		used = Rect2i(Vector2i.ZERO, image.get_size())
	var rect := SplashScreen.final_logo_rect(view, used)
	# Scaled to exactly the size it is shown at (the source is much larger), so it stays crisp instead of aliasing
	var shown := image.get_region(used)
	shown.resize(maxi(roundi(rect.size.x), 1), maxi(roundi(rect.size.y), 1), Image.INTERPOLATE_LANCZOS)
	game_name.texture = ImageTexture.create_from_image(shown)
	game_name.set_anchors_preset(Control.PRESET_TOP_LEFT)
	game_name.size = Vector2(shown.get_size())
	game_name.position = rect.position
	status.set_anchors_preset(Control.PRESET_TOP_LEFT)
	status.size = Vector2(800.0, 60.0)
	status.position = Vector2(view.x * 0.5 - 400.0, rect.end.y + view.y * 0.06)


## Black fades in slowly over what's behind, the name (already in place on the die) a little ahead of it, the status last.
func _fade_in() -> void:
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.modulate.a = 1.0
	background.modulate.a = 0.0
	game_name.modulate.a = 0.0
	status.modulate.a = 0.0
	var time := Anim.t(fade_in_time)
	var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(background, "modulate:a", 1.0, time)
	tween.tween_property(game_name, "modulate:a", 1.0, time * 0.6)
	tween.tween_property(status, "modulate:a", 1.0, time * 0.5).set_delay(time * 0.5)
	await tween.finished


func _fade(alpha: float) -> void:
	root.mouse_filter = Control.MOUSE_FILTER_STOP if alpha > 0.0 else Control.MOUSE_FILTER_IGNORE
	await create_tween().tween_property(root, "modulate:a", alpha, Anim.t(fade_time)).finished


func _on_progress(done: int, total: int) -> void:
	status.text = "%s  %d%%" % [STATUS_TEXT, 100 * done / maxi(total, 1)]
