class_name TerrainEffect
extends Node3D

## One-shot landing effect. Restarts every particle child, then frees itself.
## Each biome has its own set (BiomeData.terrain_effects); all are drawn during the loading screen (ShaderWarmup).


func play() -> void:
	var longest := start()
	await get_tree().create_timer(longest + 0.1).timeout
	queue_free()


## Restarts every particle child and returns the longest lifetime in seconds.
func start() -> float:
	var longest := 0.0
	for child in get_children():
		if child is CPUParticles3D:
			child.speed_scale = SaveManager.settings_data.animation_speed
			child.restart()
			longest = maxf(longest, child.lifetime / child.speed_scale)
	return longest
