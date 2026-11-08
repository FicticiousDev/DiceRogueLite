// Die body pass (die_body / die_body_glass): its finish (die_finish.gdshaderinc) in the rarity colour, optional pulsing
// surface glow, and dimming for used/disabled dice. With GLASS defined the finish's alpha is used.

#include "res://shaders/die_finish.gdshaderinc"

void vertex() {
	die_position = (pattern_transform * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 albedo;
	float rough;
	float metal;
	vec3 emission;
	float alpha;
	die_finish(die_position, NORMAL, VIEW, TIME, albedo, rough, metal, emission, alpha);
	ALBEDO = albedo * (1.0 - 0.6 * dim);
	ROUGHNESS = rough;
	METALLIC = metal;
	EMISSION = (emission + surface_glow(NORMAL, VIEW, 1.0, TIME)) * (1.0 - dim);
#ifdef GLASS
	ALPHA = alpha;
#endif
}
