shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

// The vortex's mouth (Expansion 6): a swirling tidal pool lying on the moss, no solid funnel.
// A disc that follows the ground (built in Vortex._pool_mesh; UV.x = round, UV.y = 0 centre .. 1 rim,
// NORMAL = the ground's up). Spiral bands of water wind in toward a deep blue eye, foam on their
// crests, turning faster near the centre, the whole of it rippling. `reach` grows the pool from the
// eye as the vortex strengthens; it fades out softly at its edge into the moss.

uniform float strength = 0.0;
uniform float reach = 1.0;          // visible fraction of the radius
uniform float pulse = 0.0;
uniform float spin_phase = 0.0;
uniform float arms = 3.0;
uniform vec3 deep : source_color = vec3(0.05, 0.28, 0.42);
uniform vec3 water : source_color = vec3(0.2, 0.66, 0.8);
uniform vec3 foam : source_color = vec3(0.9, 0.98, 1.0);

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float n2_pre(float ang, float r, float swirl) {
	float a = ang - swirl * 0.25;
	return vnoise(vec2(cos(a), sin(a)) * (r * 3.0 + 0.4) + 13.1);
}

void vertex() {
	float r = UV.y;
	// A gentle swell rolling round the pool, calm at the rim.
	float wave = sin(UV.x * 6.2832 * 3.0 - spin_phase * 2.0 + r * 9.0) * 0.05 * (1.0 - r) * strength;
	VERTEX += NORMAL * wave;
}

void fragment() {
	float r = UV.y / max(reach, 0.001);
	if (r > 1.0) {
		discard;
	}
	float ang = UV.x * 6.2832;
	// Spiral arms winding in toward the eye; the inner water turns faster.
	float swirl = spin_phase * (1.0 + 2.0 * (1.0 - r));
	float band = sin(ang * arms + log(r + 0.08) * 1.8 - swirl * 1.6 + (n2_pre(ang, r, swirl) - 0.5) * 2.5);
	// Noise in the pool's plane, turning with the water (no seam where UV.x wraps).
	float a1 = ang + swirl * 0.35;
	float n = vnoise(vec2(cos(a1), sin(a1)) * (r * 9.0 + 0.5) + vec2(0.0, TIME * 0.4));
	float n2 = vnoise(vec2(cos(ang - swirl * 0.2), sin(ang - swirl * 0.2)) * (r * 4.0 + 0.3) + 7.3);
	float crest = smoothstep(0.45, 1.05, band * 0.45 + n * 0.75 + n2 * 0.25 - 0.05);
	vec3 col = mix(water, deep, smoothstep(0.45, 0.0, r));
	col = mix(col, foam, crest * (0.25 + 0.45 * (1.0 - r)) + pulse * 0.2);
	col *= 0.92 + 0.16 * n2;
	// Churning white water round the eye, and a lip of foam where the pool meets the moss.
	float ring = exp(-pow((r - 0.13) / 0.06, 2.0)) * (0.6 + 0.4 * n);
	float lip = exp(-pow((r - 0.82) / 0.07, 2.0)) * smoothstep(0.35, 0.7, n2 + n * 0.4);
	col = mix(col, foam, clamp(ring * 0.7 + lip * 0.6, 0.0, 1.0) * strength);
	float edge = 1.0 - smoothstep(0.8, 1.0, r);
	float a = (0.6 + crest * 0.3 + ring * 0.3 + lip * 0.3) * edge * (0.35 + strength * 0.65);
	ALBEDO = col;
	ALPHA = clamp(a, 0.0, 0.95);
}
