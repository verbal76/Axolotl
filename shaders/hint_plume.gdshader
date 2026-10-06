shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

// The restoration hint's plume (HintPlumes): a tall, soft, wispy column of pink haze rising from a
// target. Each instance: origin = its foot, INSTANCE_CUSTOM = (up.xyz, age 0..1). Drawn as a quad
// that stands along `up` and turns round it to face the camera; the smoke flows upward and sways.

uniform vec4 col : source_color = vec4(0.98, 0.6, 0.72, 0.62);
uniform float height = 9.0;
uniform float width = 2.4;

varying vec2 v_uv;
varying float v_age;
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
	vec3 foot = MODEL_MATRIX[3].xyz;
	vec3 up = normalize(INSTANCE_CUSTOM.xyz);
	vec3 to_cam = normalize(INV_VIEW_MATRIX[3].xyz - foot);
	vec3 right = cross(up, to_cam);
	right = length(right) > 0.001 ? normalize(right) : vec3(1.0, 0.0, 0.0);
	float y = VERTEX.y + 0.5;
	vec3 wp = foot + up * y * height + right * VERTEX.x * width * (0.55 + 0.9 * y);
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(wp, 1.0);
	v_uv = vec2(VERTEX.x + 0.5, y);
	v_age = INSTANCE_CUSTOM.w;
	v_seed = fract(foot.x * 0.137 + foot.z * 0.291);
}

void fragment() {
	float y = v_uv.y;
	// Sways more the higher it goes; the column breathes in width.
	float sway = (sin(y * 5.0 - TIME * 1.3 + v_seed * 20.0) * 0.5 + sin(y * 11.0 + TIME * 0.9) * 0.2) * 0.22 * y;
	float x = (v_uv.x - 0.5 - sway) * 2.0;
	float core = 1.0 - smoothstep(0.15, 1.0, abs(x));
	// Wisps: flowing noise, stretched upward, eats into the column.
	vec2 q = vec2(x * 2.2 + v_seed * 7.0, y * 4.0 - TIME * 0.9);
	float n = vnoise(q) * 0.6 + vnoise(q * 2.3 + 3.1) * 0.4;
	float wisp = smoothstep(0.25, 0.85, n);
	// Rises in: the top of the plume climbs with its age, and the whole fades at the end.
	float front = smoothstep(v_age * 1.7 + 0.05, v_age * 1.7 - 0.25, y);
	float ends = smoothstep(0.0, 0.06, y) * (1.0 - smoothstep(0.75, 1.0, y));
	float life = smoothstep(0.0, 0.12, v_age) * (1.0 - smoothstep(0.6, 1.0, v_age));
	ALBEDO = col.rgb * (0.9 + 0.2 * n);
	ALPHA = col.a * core * mix(0.35, 1.0, wisp) * front * ends * life;
}
