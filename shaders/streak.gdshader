shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

// A falling streak on a quad: bright head at the bottom (UV.y = 1), fading to nothing at the tail, soft sides.

uniform vec4 color : source_color = vec4(0.6, 0.7, 1.0, 0.5);

void fragment() {
	float across = 1.0 - abs(UV.x * 2.0 - 1.0);
	float along = UV.y * UV.y;
	ALBEDO = color.rgb;
	ALPHA = color.a * along * smoothstep(0.0, 0.8, across);
}
