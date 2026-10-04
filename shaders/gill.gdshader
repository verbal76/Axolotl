shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_schlick_ggx;
// Feathery external gill. Vertex colour carries the warm-core to hot-pink-fringe gradient;
// UV.y runs base (0) to tip (1), UV.x is distance from the stalk (0) to the fringe (1).
// These gills double as the axolotl's health display (see AxolotlModel._update_gills).

uniform float glow = 0.8;        // emission strength (active health pulses this)
uniform float desat = 0.0;       // 0 vivid .. 1 grey (a lost gill)
uniform float flutter = 1.0;     // water flutter amount
uniform float phase = 0.0;       // per-gill offset so they never move in lockstep
uniform vec3 glow_tint : source_color = vec3(1.0, 0.45, 0.7);

varying vec3 v_col;

void vertex() {
	float t = UV.y;
	float e = UV.x;
	float slow = sin(TIME * 5.3 + phase + t * 5.0) * 0.010 * t;
	float fine = sin(TIME * 17.0 + phase * 2.3 + t * 30.0 + e * 9.0) * 0.005 * e;
	VERTEX.z += (slow + fine) * flutter;
	v_col = COLOR.rgb;
}

void fragment() {
	vec3 c = v_col;
	float l = dot(c, vec3(0.3, 0.59, 0.11));
	vec3 grey = vec3(l) * vec3(0.78, 0.68, 0.7);
	c = mix(c, grey, desat);
	ALBEDO = c;
	ROUGHNESS = 0.42;
	SPECULAR = 0.2;
	RIM = 0.25;
	RIM_TINT = 0.7;
	float fringe = smoothstep(0.35, 1.0, UV.x);
	EMISSION = mix(c, glow_tint, 0.35 + 0.4 * fringe) * glow * (1.0 - desat);
}
