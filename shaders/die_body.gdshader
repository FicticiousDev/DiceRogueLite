shader_type spatial;

// Die body: rarity colour, optional pulsing surface glow, and dimming for used/disabled dice.

uniform vec4 body_color : source_color = vec4(0.92, 0.9, 0.85, 1.0);
uniform float roughness = 0.45;
uniform float metallic = 0.0;
// Surface glow: facing colour where the surface faces the camera, edge colour towards the silhouette
uniform vec4 glow_facing : source_color = vec4(1.0, 0.78, 0.25, 1.0);
uniform vec4 glow_edge : source_color = vec4(1.0, 0.12, 0.05, 1.0);
uniform float glow = 0.0;
uniform float dim = 0.0;

// [border] pushes towards the edge colour regardless of view angle (used for face borders)
vec3 surface_glow(vec3 normal, vec3 view, float border, float time) {
	float edge = max(pow(1.0 - clamp(dot(normal, view), 0.0, 1.0), 1.5), border);
	float pulse = 0.8 + 0.2 * sin(time * 3.0);
	return mix(glow_facing.rgb * 0.9, glow_edge.rgb * 2.4, edge) * glow * pulse;
}

void fragment() {
	ALBEDO = body_color.rgb * (1.0 - 0.6 * dim);
	ROUGHNESS = roughness;
	METALLIC = metallic;
	EMISSION = surface_glow(NORMAL, VIEW, 1.0, TIME) * (1.0 - dim);
}
