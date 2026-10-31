shader_type spatial;

// Die face: body colour with symbols carved in. Inside the carving the surface is shaded darker and
// tinted with the symbol's ink; the normal map gives the recess its depth.

uniform vec4 body_color : source_color = vec4(0.92, 0.9, 0.85, 1.0);
uniform sampler2D ink_texture : source_color, filter_linear_mipmap;
uniform sampler2D normal_texture : hint_normal, filter_linear_mipmap;
uniform float roughness = 0.45;
uniform float metallic = 0.0;
// Surface glow: facing colour where the surface faces the camera, edge colour towards the silhouette
uniform vec4 glow_facing : source_color = vec4(1.0, 0.78, 0.25, 1.0);
uniform vec4 glow_edge : source_color = vec4(1.0, 0.12, 0.05, 1.0);
uniform float glow = 0.0;
// How much darker the carving is on glowing dice, so symbols stand out against the glow
uniform float glow_symbol_darken = 0.75;
uniform float dim = 0.0;
// How dark the bottom of the carving is
uniform float recess_shade = 0.45;
uniform float normal_depth = 2.2;

// [border] pushes towards the edge colour regardless of view angle (used for face borders)
vec3 surface_glow(vec3 normal, vec3 view, float border, float time) {
	float edge = max(pow(1.0 - clamp(dot(normal, view), 0.0, 1.0), 1.5), border);
	float pulse = 0.8 + 0.2 * sin(time * 3.0);
	return mix(glow_facing.rgb * 0.9, glow_edge.rgb * 2.4, edge) * glow * pulse;
}

void fragment() {
	vec4 ink = texture(ink_texture, UV);
	vec3 carved = mix(body_color.rgb * recess_shade, ink.rgb, 0.7) * (1.0 - glow_symbol_darken * glow);
	ALBEDO = mix(body_color.rgb, carved, ink.a) * (1.0 - 0.6 * dim);
	NORMAL_MAP = texture(normal_texture, UV).rgb;
	NORMAL_MAP_DEPTH = normal_depth;
	ROUGHNESS = mix(roughness, 0.8, ink.a);
	METALLIC = metallic;
	// No glow inside the carving so the symbols stay readable
	// Gold in the middle of the face, red towards its border
	float border = smoothstep(0.2, 0.5, max(abs(UV.x - 0.5), abs(UV.y - 0.5)));
	EMISSION = surface_glow(NORMAL, VIEW, border, TIME) * (1.0 - ink.a) * (1.0 - dim);
}
