shader_type spatial;

// Die face for see-through finishes: both sides drawn so the far faces' symbols show through. See die_face.gdshaderinc.

render_mode blend_mix, cull_disabled, depth_draw_never;

#define GLASS
#include "res://shaders/die_face.gdshaderinc"
