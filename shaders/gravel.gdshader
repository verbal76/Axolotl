shader_type spatial;
render_mode diffuse_lambert;

uniform sampler2D gravel_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D grime_tex : filter_linear_mipmap, repeat_enable;
uniform float clean = 0.0;        // global aquarium restoration 0..1
uniform float tile = 0.02;
uniform vec3 dirt_color : source_color = vec3(0.27, 0.27, 0.2);

varying vec3 v_wpos;

void vertex() {
	v_wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 g = texture(gravel_tex, v_wpos.xz * tile).rgb;
	float grime = texture(grime_tex, v_wpos.xz * tile * 0.23).r;
	// Continuous cleanup: the film thins everywhere, and patches clear first where grime is thin.
	float film = clamp((grime * 0.9 + 0.35) - clean * 1.25, 0.0, 1.0);
	film = smoothstep(0.0, 0.45, film);
	float lum = dot(g, vec3(0.33));
	vec3 dull = mix(vec3(lum), g, 0.25) * 0.55;
	vec3 base = mix(g, dull, (1.0 - clean) * 0.7);
	ALBEDO = mix(base, dirt_color * (0.7 + grime * 0.5), film * 0.85);
	ROUGHNESS = mix(0.95, 0.5, clean);
}
