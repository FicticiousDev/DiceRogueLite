shader_type canvas_item;

// Draws a height-mask icon (white symbol on black, no alpha) as a flat icon in the modulate colour.
void fragment() {
	COLOR = vec4(COLOR.rgb, texture(TEXTURE, UV).r * COLOR.a);
}
