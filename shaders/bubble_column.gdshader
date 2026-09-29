shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;

// A bubble column on a moss ball (world expansion traversal toy), fully GPU-driven like the
// aquarium bubbler but rising along `up_dir` from `base_pos`. Instance origin xyz = seed (0..1).
uniform vec3 base_pos = vec3(0.0);
uniform vec3 up_dir = vec3(0.0, 1.0, 0.0);
uniform float radius = 0.9;
uniform float height = 6.0;
uniform float speed = 2.6;

varying float v_a;

void vertex() {
	vec3 seed = MODEL_MATRIX[3].xyz;
	vec3 u = normalize(up_dir);
	vec3 s = normalize(cross(u, abs(u.y) < 0.9 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0)));
	vec3 f = cross(s, u);
	float t = fract(seed.x + TIME * speed / height * (0.75 + seed.y * 0.5));
	float a = seed.z * 6.2832 + TIME * (0.8 + seed.y);
	float r = radius * sqrt(fract(seed.y * 7.13)) * (0.7 + 0.3 * sin(TIME * 2.0 + seed.x * 11.0));
	vec3 wp = base_pos + u * (t * height) + s * cos(a) * r + f * sin(a) * r;
	float sz = (0.05 + seed.z * 0.12) * (1.0 + t * 0.5);
	vec4 vp = VIEW_MATRIX * vec4(wp, 1.0);
	vp.xy += VERTEX.xy * sz;
	POSITION = PROJECTION_MATRIX * vp;
	v_a = smoothstep(0.0, 0.05, t) * (1.0 - smoothstep(0.88, 1.0, t));
}

void fragment() {
	float d = length(UV - vec2(0.5)) * 2.0;
	float rim = smoothstep(0.6, 0.9, d) * (1.0 - smoothstep(0.9, 1.0, d));
	float hi = 1.0 - smoothstep(0.0, 0.25, length(UV - vec2(0.35, 0.35)) * 2.0);
	ALBEDO = vec3(0.85, 0.96, 1.0);
	ALPHA = (rim * 0.8 + hi * 0.9 + 0.08 * step(d, 1.0)) * v_a;
}
