shader_type spatial;
render_mode cull_disabled, specular_schlick_ggx;
// Owner, 2026-10-01: the floor of a ravine (where a fall costs a frond) is a pool of toxic green
// ooze, styled after a harmful algal bloom (owner's reference photos): bright pea-soup green,
// marbled "spilled paint" swirls, thick floating scum mats, a wet sheen, slow heave and bubbles.
// UV.x: metres along the ravine; UV.y: 0..1 across. COLOR.a: how far into the floor (edges cut).

uniform vec4 soup : source_color = vec4(0.30, 0.62, 0.06, 1.0);
uniform vec4 streak : source_color = vec4(0.62, 0.92, 0.18, 1.0);
uniform vec4 dark : source_color = vec4(0.10, 0.30, 0.04, 1.0);
uniform vec4 scum : source_color = vec4(0.70, 0.95, 0.32, 1.0);
uniform float flow = 0.16;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
float fbm(vec2 p) { return noise(p) * 0.5 + noise(p * 2.03 + 3.7) * 0.28 + noise(p * 4.1 - 1.3) * 0.14 + noise(p * 8.3 + 7.1) * 0.08; }

varying vec2 sp;

void vertex() {
	sp = vec2(UV.x, UV.y * 3.0);
	float h = (fbm(sp * 0.5 + vec2(TIME * flow, TIME * 0.04)) - 0.5) * 0.14;
	VERTEX += NORMAL * h * COLOR.a;
}

void fragment() {
	if (COLOR.a < 0.5 + (noise(sp * 2.0) - 0.5) * 0.3) {
		discard;
	}
	vec2 q = sp * 0.7 + vec2(TIME * flow, 0.0);
	// Domain-warped marbling: the "spilled paint" swirls of a bloom.
	vec2 w = vec2(fbm(q + vec2(0.0, TIME * 0.05)), fbm(q + vec2(5.2, 1.3) - TIME * 0.04));
	float m = fbm(q + w * 2.2);
	float swirl = sin((m * 9.0 + w.x * 4.0)) * 0.5 + 0.5;
	vec3 col = mix(dark.rgb, soup.rgb, smoothstep(0.25, 0.6, m));
	col = mix(col, streak.rgb, smoothstep(0.75, 0.95, swirl) * 0.7);
	// Thick floating scum mats, drifting slower than the water under them.
	float mat = fbm(sp * 1.3 + vec2(TIME * flow * 0.6, 0.0));
	float scum_a = smoothstep(0.58, 0.68, mat);
	float fleck = step(0.86, noise(sp * 14.0 + vec2(TIME * flow * 0.6, 0.0))) * scum_a;
	col = mix(col, scum.rgb * (0.85 + 0.3 * fleck), scum_a * 0.85);
	// Bubbles: one per cell, swelling then popping, each on its own clock.
	vec2 c = sp * 1.6;
	vec2 id = floor(c);
	float r = hash(id);
	float ph = fract(TIME * (0.25 + r * 0.35) + r * 7.0);
	vec2 ctr = id + 0.5 + (vec2(hash(id + 1.3), hash(id + 2.7)) - 0.5) * 0.5;
	float d = length(c - ctr);
	float rad = 0.3 * smoothstep(0.0, 0.85, ph) * step(0.4, r);
	float dome = smoothstep(rad, rad - 0.05, d) * (1.0 - smoothstep(0.85, 1.0, ph));
	float rim = dome * smoothstep(rad - 0.1, rad - 0.02, d);
	col = mix(col, scum.rgb, dome * 0.25 + rim * 0.5);
	ALBEDO = col;
	// Wet and glossy where open, matte on the scum.
	ROUGHNESS = mix(0.12, 0.7, scum_a) - dome * 0.08;
	SPECULAR = 0.65;
	// A faint toxic glow so it reads in dim water and caves.
	EMISSION = col * (0.16 + 0.25 * rim);
}
