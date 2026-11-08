shader_type spatial;

// Die body for see-through finishes: both sides drawn so the far side shows through. See die_body.gdshaderinc.

render_mode blend_mix, cull_disabled, depth_draw_never;

#define GLASS
#include "res://shaders/die_body.gdshaderinc"
