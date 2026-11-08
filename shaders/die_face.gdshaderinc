// Die face pass (die_face / die_face_glass): the body's finish (die_finish.gdshaderinc) with symbols carved in. Inside
// the carving the surface is shaded darker and tinted with the symbol's ink; the normal map gives the recess its depth.
// With GLASS defined only the carving is drawn (the glass body shows through the rest).

#include "res://shaders/die_finish.gdshaderinc"

uniform sampler2D ink_texture : source_color, filter_linear_mipmap;
uniform sampler2D normal_texture : hint_normal, filter_linear_mipmap;
// How much darker the carving is on glowing dice, so symbols stand out against the glow
uniform float glow_symbol_darken = 0.75;
// How dark the bottom of the carving is
uniform float recess_shade = 0.45;
uniform float normal_depth = 2.2;
// How much of the carving is the symbol's own colour (the rest is the face's colour); 1 for full-colour artwork
uniform float ink_strength = 0.7;

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
	vec4 ink = texture(ink_texture, UV);
	vec3 carved = mix(albedo * recess_shade, ink.rgb, ink_strength) * (1.0 - glow_symbol_darken * glow);
	ALBEDO = mix(albedo, carved, ink.a) * (1.0 - 0.6 * dim);
	NORMAL_MAP = texture(normal_texture, UV).rgb;
	NORMAL_MAP_DEPTH = normal_depth;
	ROUGHNESS = mix(rough, 0.8, ink.a);
	METALLIC = mix(metal, 0.0, ink.a);
	// No glow inside the carving so the symbols stay readable
	// Gold in the middle of the face, red towards its border
	float border = smoothstep(0.2, 0.5, max(abs(UV.x - 0.5), abs(UV.y - 0.5)));
	EMISSION = (emission + surface_glow(NORMAL, VIEW, border, TIME)) * (1.0 - ink.a) * (1.0 - dim);
#ifdef GLASS
	// The body under the face is already the glass; the face only adds its carving
	ALPHA = ink.a;
#endif
}
