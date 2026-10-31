shader_type spatial;
render_mode cull_disabled;

// Cardboard cut-out layer. The front layer shows the texture with an outline border; inner/back layers
// draw the same silhouette (texture + outline) in a flat edge colour to fake the board's thickness.

uniform sampler2D texture_albedo : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 tint : source_color = vec4(1.0);
uniform vec4 outline_color : source_color = vec4(1.0);
uniform vec4 edge_color : source_color = vec4(0.62, 0.48, 0.32, 1.0);
// Outline thickness in texture UV units
uniform float outline_width = 0.04;
// Fraction of the quad on each side reserved for the outline
uniform float padding = 0.08;
uniform bool is_edge = false;
// Overlay colour, alpha = strength (hit flashes, planned-death preview)
uniform vec4 flash : source_color = vec4(1.0, 1.0, 1.0, 0.0);

float alpha_at(vec2 uv) {
	if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) {
		return 0.0;
	}
	return texture(texture_albedo, uv).a;
}

void fragment() {
	vec2 uv = (UV - vec2(padding)) / (1.0 - 2.0 * padding);
	vec4 color = texture(texture_albedo, clamp(uv, 0.0, 1.0));
	float inside = alpha_at(uv);

	// Silhouette grown by the outline width
	float outline = inside;
	for (int i = 0; i < 16; i++) {
		float angle = float(i) * TAU / 16.0;
		outline = max(outline, alpha_at(uv + vec2(cos(angle), sin(angle)) * outline_width));
	}

	if (is_edge) {
		ALBEDO = edge_color.rgb;
	} else {
		ALBEDO = mix(outline_color.rgb, color.rgb * tint.rgb, step(0.5, inside));
	}
	ALBEDO = mix(ALBEDO, flash.rgb, flash.a);
	ROUGHNESS = 1.0;
	ALPHA = outline;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}
