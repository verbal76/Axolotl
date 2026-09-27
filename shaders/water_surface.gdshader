shader_type spatial;
render_mode unshaded, cull_disabled;

uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform float clean = 0.0;

void fragment() {
	vec2 uv = UV * 6.0;
	float a = texture(noise_tex, uv + vec2(TIME * 0.02, TIME * 0.013)).g;
	float b = texture(noise_tex, uv * 1.3 - vec2(TIME * 0.017, -TIME * 0.02)).g;
	float c = pow(1.0 - abs(a - b) * 2.0, 6.0);
	vec3 murky = vec3(0.35, 0.42, 0.3);
	vec3 clear = vec3(0.65, 0.88, 0.95);
	ALBEDO = mix(murky, clear, clean) * (0.42 + c * 0.22 * (0.4 + clean * 0.6));
}
