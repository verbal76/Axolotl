shader_type spatial;
render_mode cull_disabled, specular_schlick_ggx;
// Owner, 2026-10-01: the floor of a ravine (where a fall costs a frond) is a pool of toxic
// tie-dyed orange-and-purple ooze with the texture of a harmful algal bloom (owner's reference photos):
// marbled "spilled paint" swirls (the owner liked the pea-soup and thick glossy Florida bloom photos), thick floating scum mats, a wet sheen, slow heave and bubbles.
// UV.x: metres along the ravine; UV.y: 0..1 across. COLOR.a: how far into the floor (edges cut).

uniform vec4 soup : source_color = vec4(0.98, 0.48, 0.08, 1.0);    // orange
uniform vec4 streak : source_color = vec4(0.58, 0.16, 0.78, 1.0);  // purple
uniform vec4 dark : source_color = vec4(0.28, 0.06, 0.38, 1.0);    // deep purple
uniform vec4 scum : source_color = vec4(1.0, 0.72, 0.28, 1.0);     // pale orange
uniform float flow = 0.16;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
float fbm(vec2 p) { return noise(p) * 0.5 + noise(p * 2.03 + 3.7) * 0.28 + noise(p * 4.1 - 1.3) * 0.14 + noise(p * 8.3 + 7.1) * 0.08; }

varying vec2 sp;   // isotropic-ish metres (bubbles, heave, edge)
varying vec2 fp;   // flow space: stretched along the valley so smears run with it, not across

void vertex() {
	sp = vec2(UV.x, UV.y * 5.5);
	fp = vec2(UV.x * 0.22, UV.y * 2.2);
	float h = (fbm(sp * 0.5 + vec2(TIME * flow, TIME * 0.04)) - 0.5) * 0.14;
	VERTEX += NORMAL * h * COLOR.a;
}

void fragment() {
	// A soft, slowly wobbling edge (a fluid meniscus), never jagged.
	if (COLOR.a < 0.5 + (noise(sp * 0.8 + TIME * 0.05) - 0.5) * 0.18) {
		discard;
	}
	// Smears drift down the valley (along UV.x), long and thin like a slow current.
	vec2 q = fp + vec2(TIME * flow * 0.35, 0.0);
	// Domain-warped marbling: the "spilled paint" swirls of a bloom.
	vec2 w = vec2(fbm(q + vec2(0.0, TIME * 0.05)), fbm(q + vec2(5.2, 1.3) - TIME * 0.04));
	float m = fbm(q + w * 2.2);
	float swirl = sin((m * 9.0 + w.x * 4.0)) * 0.5 + 0.5;
	// Tie-dye (owner, 2026-10-01): orange and purple swirled together, never green (it read as
	// shiny moss) and never red (lava).
	vec3 col = mix(dark.rgb, soup.rgb, smoothstep(0.3, 0.55, m));
	col = mix(col, streak.rgb, smoothstep(0.35, 0.65, swirl) * 0.85);
	// Thick floating scum mats, drifting slower than the water under them.
	float mat = fbm(fp * 2.0 + vec2(TIME * flow * 0.25, 0.0));
	float scum_a = smoothstep(0.52, 0.64, mat);
	float fleck = step(0.86, noise(sp * 6.0 + vec2(TIME * flow * 0.6, 0.0))) * scum_a;
	col = mix(col, scum.rgb * (0.85 + 0.3 * fleck), scum_a * 0.85);
	// Bubbles: one per cell, swelling then popping, each on its own clock.
	vec2 c = sp * 0.9;
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
