// Die finishes (DieFinish): the material look of a die's body and faces, tinted by its rarity colour. Patterns are
// worked out in die space (die_position, set in vertex() through pattern_transform) so the face quads match the body.

uniform vec4 body_color : source_color = vec4(0.92, 0.9, 0.85, 1.0);
// DieFinish.Pattern: 0 plastic, 1 metal, 2 glass, 3 rust, 4 marble, 5 obsidian, 6 galaxy, 7 flecked, 8 wood, 9 pearl
uniform int pattern = 0;
uniform vec4 base_color : source_color = vec4(1.0);
// Share of the rarity colour in the finish's colour
uniform float tint = 1.0;
uniform vec4 detail_color : source_color = vec4(0.2, 0.2, 0.2, 1.0);
uniform float roughness = 0.45;
uniform float metallic = 0.0;
uniform float pattern_scale = 1.0;
// See-through finishes (glass): alpha where the surface faces the camera, rising towards the silhouette. Only the
// *_glass shaders use it
uniform float opacity = 1.0;
// Darkens a trim so it reads apart from the body
uniform float trim_shade = 1.0;
// From this mesh's space to die space (face quads sit on the die's faces)
uniform mat4 pattern_transform = mat4(1.0);
// Surface glow: facing colour where the surface faces the camera, edge colour towards the silhouette
uniform vec4 glow_facing : source_color = vec4(1.0, 0.78, 0.25, 1.0);
uniform vec4 glow_edge : source_color = vec4(1.0, 0.12, 0.05, 1.0);
uniform float glow = 0.0;
uniform float dim = 0.0;

varying vec3 die_position;

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

float noise3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	vec3 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash13(i), hash13(i + vec3(1.0, 0.0, 0.0)), u.x), mix(hash13(i + vec3(0.0, 1.0, 0.0)), hash13(i + vec3(1.0, 1.0, 0.0)), u.x), u.y),
		mix(mix(hash13(i + vec3(0.0, 0.0, 1.0)), hash13(i + vec3(1.0, 0.0, 1.0)), u.x), mix(hash13(i + vec3(0.0, 1.0, 1.0)), hash13(i + vec3(1.0, 1.0, 1.0)), u.x), u.y), u.z);
}

float fbm(vec3 p) {
	float total = 0.0;
	float amplitude = 0.5;
	for (int i = 0; i < 4; i++) {
		total += noise3(p) * amplitude;
		p = p * 2.03 + vec3(1.7, 9.2, 3.1);
		amplitude *= 0.5;
	}
	return total;
}

// Round spots on a grid of [density] cells, [chance] of a cell having one: 1 inside a spot
float spots(vec3 p, float density, float chance, float radius) {
	vec3 cell = floor(p * density);
	float on = step(1.0 - chance, hash13(cell + 13.7));
	return on * (1.0 - smoothstep(radius * 0.5, radius, length(fract(p * density) - 0.5)));
}

// [border] pushes the glow towards the edge colour regardless of view angle (used for face borders)
vec3 surface_glow(vec3 normal, vec3 view, float border, float time) {
	float edge = max(pow(1.0 - clamp(dot(normal, view), 0.0, 1.0), 1.5), border);
	float pulse = 0.8 + 0.2 * sin(time * 3.0);
	return mix(glow_facing.rgb * 0.9, glow_edge.rgb * 2.4, edge) * glow * pulse;
}

// [position]: die space (die_position); [time]: TIME
void die_finish(vec3 position, vec3 normal, vec3 view, float time, out vec3 albedo, out float rough, out float metal, out vec3 emission,
		out float alpha) {
	vec3 p = position * pattern_scale;
	vec3 base = mix(base_color.rgb, body_color.rgb, tint);
	float fresnel = pow(1.0 - clamp(dot(normal, view), 0.0, 1.0), 3.0);
	albedo = base;
	rough = roughness;
	metal = metallic;
	emission = vec3(0.0);
	alpha = 1.0;
	if (pattern == 1) {
		// Brushed metal: fine streaks along one axis
		float streak = noise3(p * vec3(60.0, 3.0, 3.0));
		albedo = base * (0.82 + 0.18 * streak);
		rough = roughness + 0.12 * streak;
	} else if (pattern == 2) {
		// Glass: see-through in the rarity colour, solid-looking towards the edges, with a bright rim and the odd bubble
		float depth = fbm(p * 3.0);
		albedo = base * (0.8 + 0.2 * depth);
		emission = base * fresnel * 0.6 + vec3(spots(p, 28.0, 0.04, 0.3) * 0.35);
		alpha = mix(opacity, 0.9, fresnel);
	} else if (pattern == 3) {
		// Rusted metal: patches of rough, flaking rust over the metal
		float rust = smoothstep(0.42, 0.62, fbm(p * 4.0));
		vec3 flake = detail_color.rgb * (0.65 + 0.35 * noise3(p * 25.0));
		albedo = mix(base * 0.9, flake, rust);
		metal = mix(metallic, 0.0, rust);
		rough = mix(roughness, 0.95, rust);
	} else if (pattern == 4) {
		// Marble: light stone with thin dark veins
		float wave = sin(p.x * 5.0 + p.y * 3.0 + p.z * 2.0 + fbm(p * 2.5) * 9.0);
		float vein = 1.0 - smoothstep(0.0, 0.14, abs(wave));
		albedo = mix(mix(base, vec3(1.0), 0.12), mix(detail_color.rgb, base * 0.35, 0.5), vein * 0.8);
	} else if (pattern == 5) {
		// Obsidian: glassy black; the rarity colour shows in the sheen
		albedo = base * 0.6;
		emission = body_color.rgb * fresnel * 0.7;
	} else if (pattern == 6) {
		// Galaxy: night sky with a nebula in the rarity colour and twinkling stars
		float cloud = smoothstep(0.35, 0.8, fbm(p * 2.2 + vec3(0.0, time * 0.03, 0.0)));
		vec3 nebula = mix(body_color.rgb, detail_color.rgb, noise3(p * 1.5) * 0.45) * cloud;
		float twinkle = 0.6 + 0.4 * sin(time * 4.0 + hash13(floor(p * 26.0)) * 30.0);
		albedo = base + nebula * 0.25;
		emission = nebula * 0.55 + vec3(spots(p, 26.0, 0.06, 0.22) * 1.6 * twinkle);
	} else if (pattern == 7) {
		// Flecked: speckles of the detail colour
		albedo = mix(base, detail_color.rgb, spots(p, 45.0, 0.18, 0.4));
	} else if (pattern == 8) {
		// Wood: growth rings bent by noise
		float rings = fract(length(p.xz + vec2(0.7, 0.3)) * 9.0 + fbm(p * 3.0) * 1.6);
		albedo = mix(base, mix(base * 0.5, detail_color.rgb, 0.5), smoothstep(0.35, 0.75, rings));
	} else if (pattern == 9) {
		// Pearl: soft white with an oily rainbow sheen at grazing angles
		vec3 rainbow = 0.5 + 0.5 * cos(6.2831 * (fresnel * 1.3 + fbm(p * 2.0) * 0.5 + vec3(0.0, 0.33, 0.67)));
		albedo = mix(base, vec3(1.0), 0.12);
		emission = rainbow * fresnel * 0.4;
	}
	albedo *= trim_shade;
}
