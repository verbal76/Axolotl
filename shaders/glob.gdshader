shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_opaque, cull_back, shadows_disabled;

// A spitter's glob (owner, 2026-10-07: "a fluid blob, a soft biological mass", not a glowing ball).
// The mesh is a low sphere; this shader makes it a squishy, living blob: it stretches into a
// teardrop along its flight (the node faces -Z along its velocity), its surface wobbles in a few
// slow lumps of its own, it pulses, and `squash` flattens it for a moment when it is batted or
// splats. Translucent slime: a bright, denser nucleus, a glowing rim, darker flecks inside.

uniform vec3 core_col : source_color = vec3(0.86, 1.0, 0.32);
uniform vec3 rim_col : source_color = vec3(0.55, 0.95, 0.25);
uniform float stretch = 0.45;
uniform float wobble = 1.0;
uniform float squash = 0.0;
uniform float fade = 1.0;
uniform float seed = 0.0;

varying vec3 v_obj;

void vertex() {
	vec3 p = VERTEX;
	float r = 1.0;
	// Lumps: three slow travelling waves over the surface, each blob its own (seed).
	// (Low frequencies over the unit sphere: soft lobes, never facets.)
	float w = sin(TIME * 6.0 + seed + dot(p, vec3(2.3, 1.7, 1.9))) * 0.07
			+ sin(TIME * 4.3 + seed * 1.7 + p.y * 3.1 + p.x * 1.3) * 0.05
			+ sin(TIME * 8.0 + seed * 2.3 + p.z * 3.7) * 0.03;
	p += NORMAL * r * w * wobble;
	// A teardrop along the flight: the trailing side (+Z) drawn out, the front a little blunted.
	p.z *= 1.0 + stretch * (p.z > 0.0 ? 1.2 : 0.25);
	// Breathing, and the squash of a hit (wide and flat, then back).
	float pulse = 1.0 + 0.06 * sin(TIME * 7.0 + seed);
	p *= pulse;
	p.z *= 1.0 - squash * 0.55;
	p.xy *= 1.0 + squash * 0.45;
	VERTEX = p;
	v_obj = p;
}

float hash(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

void fragment() {
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rim = pow(1.0 - facing, 2.0);
	// Denser and brighter toward the middle (the nucleus), clear and glowing at the edge.
	vec3 col = mix(rim_col, core_col, facing * facing);
	col += rim_col * rim * 0.8;
	// A few darker flecks drifting inside.
	float fleck = step(0.975, hash(floor(v_obj * 9.0 + vec3(0.0, TIME * 0.6, 0.0))));
	col *= 1.0 - fleck * 0.35 * facing;
	ALBEDO = col;
	ALPHA = clamp((0.42 + facing * 0.3 + rim * 0.4) * fade, 0.0, 1.0);
}
