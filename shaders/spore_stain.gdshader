shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled;

// The unhealthy patch under a toxic spore bloom: a dull olive-brown, mottled stain on the moss that
// fades out at its edge (SporeBloom).

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

void fragment() {
	vec2 c = UV - vec2(0.5);
	float d = length(c) * 2.0;
	float n = vnoise(UV * 7.0) * 0.6 + vnoise(UV * 17.0) * 0.4;
	float edge = 1.0 - smoothstep(0.35 + n * 0.3, 0.95, d);
	ALBEDO = mix(vec3(0.16, 0.14, 0.05), vec3(0.34, 0.31, 0.1), n);
	ROUGHNESS = 0.95;
	ALPHA = edge * (0.4 + 0.3 * n);
}
