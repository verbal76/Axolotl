shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_back, shadows_disabled;

// The vortex's water jets (Expansion 6, owner: "a spiral of water jets ... a revolving tidal pool
// spinning hurricane jet of water that he's circling through", never a solid tube).
// Each jet is a tube wound as a helix round the vortex's path (built in Vortex._jet_mesh). The whole
// spiral revolves round the path: every vertex turns about its own point on the path (CUSTOM0.xyz)
// and the path's direction there (CUSTOM1.xyz) by `spin_phase`, which the script advances so it knows
// where the jets are (Gill rides beside one). UV.x = round the jet, UV.y = t along the path (0 at A).
// Water rushes along each jet: bright foam streaks over a glassy aqua body, lighter at the edges.

uniform float grow = 0.0;          // visible fraction of the path (the spiral reaches out as it grows)
uniform float strength = 0.0;      // 0 a faint stir .. 1 a full hurricane
uniform float pulse = 0.0;
uniform float spin_phase = 0.0;
uniform float length_m = 40.0;
uniform float flow_speed = 9.0;
uniform float opacity = 1.0;
uniform vec3 deep : source_color = vec3(0.16, 0.62, 0.78);
uniform vec3 foam : source_color = vec3(0.9, 0.98, 1.0);
// The connection's own faint hue (Vortex.TINTS): the same at both ends, mostly in the bright water.
uniform vec3 tint : source_color = vec3(1.0);
uniform float tint_amt = 0.0;

varying float v_t;
varying float v_jet;

vec3 turn(vec3 v, vec3 k, float a) {
	// Rodrigues: v turned by a about the unit axis k.
	float c = cos(a);
	float s = sin(a);
	return v * c + cross(k, v) * s + k * dot(k, v) * (1.0 - c);
}

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

void vertex() {
	vec3 a = CUSTOM0.xyz;
	vec3 k = normalize(CUSTOM1.xyz);
	v_t = UV.y;
	v_jet = CUSTOM1.w;
	// The jets breathe a little as the water surges along them.
	vec3 rel = VERTEX - a;
	float surge = 1.0 + 0.06 * sin(UV.y * length_m * 0.9 - TIME * 5.0 + v_jet * 1.7);
	rel *= surge;
	VERTEX = a + turn(rel, k, spin_phase);
	NORMAL = turn(NORMAL, k, spin_phase);
}

void fragment() {
	float t = v_t;
	if (t > grow) {
		discard;
	}
	float tip = 1.0 - smoothstep(grow - 0.05, grow, t);
	// Water rushing along the jet: long streaks that race toward the far end.
	float along = t * length_m;
	// (Round the jet by cos/sin, so the pattern has no seam where UV.x wraps.)
	vec2 rd = vec2(cos(UV.x * 6.2832), sin(UV.x * 6.2832));
	float n1 = vnoise(vec2(rd.x * 0.8 + v_jet * 3.1, along * 0.55 - TIME * flow_speed * 0.55 + rd.y * 0.8));
	float n2 = vnoise(vec2(rd.x * 1.4 - v_jet * 1.3, along * 1.3 - TIME * flow_speed * 1.1 + rd.y * 1.4));
	float streak = smoothstep(0.45, 0.8, n1 * 0.65 + n2 * 0.45);
	float fres = pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 2.0);
	vec3 foam_t = mix(foam, tint, tint_amt);
	vec3 deep_t = mix(deep, deep * tint * 1.35, tint_amt * 0.7);
	vec3 col = mix(deep_t, foam_t, clamp(streak * 0.85 + fres * 0.45 + pulse * 0.3, 0.0, 1.0));
	float end_fade = smoothstep(0.0, 0.015, t) * (1.0 - smoothstep(0.985, 1.0, t));
	float a = (0.42 + fres * 0.4 + streak * 0.4) * (0.25 + strength * 0.75) * (1.0 + pulse * 0.5);
	ALBEDO = col;
	ALPHA = clamp(a * tip * end_fade * opacity, 0.0, 1.0);
}
