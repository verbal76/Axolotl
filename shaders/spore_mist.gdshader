shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

// A toxic spore bloom's mist (SporeBloom): soft, low, sickly-yellow billboards with a grainy,
// shifting density, no rim, per-instance colour (alpha in COLOR.a).

varying vec4 v_col;
varying float v_seed;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void vertex() {
	vec3 wp = MODEL_MATRIX[3].xyz;
	float s = length(MODEL_MATRIX[0].xyz);
	vec4 vp = VIEW_MATRIX * vec4(wp, 1.0);
	vp.xy += VERTEX.xy * s * vec2(1.6, 0.8);
	POSITION = PROJECTION_MATRIX * vp;
	v_col = COLOR;
	v_seed = fract(wp.x * 0.37 + wp.z * 0.61);
}

void fragment() {
	vec2 c = UV - vec2(0.5);
	float d = length(c) * 2.0;
	float soft = 1.0 - smoothstep(0.1, 1.0, d);
	float n = vnoise(UV * 4.0 + vec2(v_seed * 9.0, TIME * 0.35)) * 0.6 + vnoise(UV * 9.0 - vec2(TIME * 0.5, v_seed * 5.0)) * 0.4;
	// Fine floating spores in it: soft specks that drift and twinkle.
	float sp = vnoise(UV * 22.0 + vec2(TIME * 0.6, -TIME * 0.4) + v_seed * 13.0);
	float speck = smoothstep(0.78, 0.92, sp);
	ALBEDO = mix(v_col.rgb, vec3(0.95, 0.92, 0.45), speck * 0.5);
	ALPHA = v_col.a * soft * soft * (0.45 + 0.55 * n) * (1.0 + speck * 0.6);
}
