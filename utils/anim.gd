class_name Anim
extends RefCounted

## Animation helpers shared by all tweens.


## Scales a duration by the animation speed setting.
static func t(seconds: float) -> float:
	return seconds / SaveManager.settings_data.animation_speed
