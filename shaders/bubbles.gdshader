shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;

// Bubbler column, fully GPU-driven. Instance origin xyz = random seed (0..1).
uniform vec3 base_pos = vec3(0.0);
uniform float height = 260.0;
uniform float speed = 22.0;

varying float v_a;

void vertex() {
	vec3 seed = MODEL_MATRIX[3].xyz;
	float t = fract(seed.x + TIME * speed / height * (0.7 + seed.y * 0.6));
	float wob = sin(TIME * 3.0 + seed.z * 20.0) * (0.5 + t * 2.5);
	vec3 wp = base_pos + vec3(wob + (seed.y - 0.5) * 2.0, t * height, cos(TIME * 2.6 + seed.x * 17.0) * (0.5 + t * 2.0));
	float sz = (0.4 + seed.z * 0.9) * (1.0 + t * 0.6);
	vec4 vp = VIEW_MATRIX * vec4(wp, 1.0);
	vp.xy += VERTEX.xy * sz;
	POSITION = PROJECTION_MATRIX * vp;
	v_a = smoothstep(0.0, 0.03, t) * (1.0 - smoothstep(0.95, 1.0, t));
}

void fragment() {
	float d = length(UV - vec2(0.5)) * 2.0;
	float rim = smoothstep(0.6, 0.9, d) * (1.0 - smoothstep(0.9, 1.0, d));
	float hi = 1.0 - smoothstep(0.0, 0.25, length(UV - vec2(0.35, 0.35)) * 2.0);
	ALBEDO = vec3(0.85, 0.95, 1.0);
	ALPHA = (rim * 0.8 + hi * 0.9 + 0.06 * step(d, 1.0)) * v_a;
}
