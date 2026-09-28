shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, diffuse_lambert, fog_disabled;

// Aquarium glass: grime film plus algae growth that recede continuously with restoration.

uniform sampler2D algae_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D grime_tex : filter_linear_mipmap, repeat_enable;
uniform float clean = 0.0;
uniform vec2 scale = vec2(1.0, 1.0);
uniform vec3 algae_a : source_color = vec3(0.16, 0.32, 0.1);
uniform vec3 algae_b : source_color = vec3(0.35, 0.5, 0.18);
uniform vec3 film_color : source_color = vec3(0.3, 0.36, 0.26);
// Water between the camera and the glass (the bedroom beyond is fog-free, so the haze of the
// water column is composited here).
uniform float water_density = 0.017;
uniform vec3 water_color : source_color = vec3(0.2, 0.26, 0.17);

varying vec3 v_wpos;

void vertex() {
	v_wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = UV * scale;
	float m = texture(algae_tex, uv).r;
	float gr = texture(grime_tex, uv * 1.7).r;
	// Algae survive where the mask exceeds a threshold that rises with restoration; the
	// highest-mask corners keep a little healthy detail at full restoration.
	float thresh = mix(0.18, 0.93, clean);
	float algae = smoothstep(thresh, thresh + 0.06, m);
	float film = clamp(mix(0.9, 0.03, clean) * (0.8 + gr * 0.4), 0.0, 1.0);
	vec3 col = mix(film_color, mix(algae_a, algae_b, m), algae);
	float ga = clamp(max(film, algae * 0.92), 0.0, 1.0);
	float T = exp(-water_density * length(VERTEX));
	float A = 1.0 - T * (1.0 - ga);
	// The water column is not one flat colour (Expansion 6): brighter and greener toward the
	// surface, where the ceiling light comes in, deeper and bluer toward the gravel.
	float hy = clamp((v_wpos.y + 110.0) / 260.0, 0.0, 1.0);
	vec3 wc = mix(water_color * vec3(0.6, 0.72, 0.9), water_color * vec3(1.22, 1.2, 1.08), smoothstep(0.0, 1.0, hy));
	vec3 C = (wc * (1.0 - T) + T * ga * col) / max(A, 0.001);
	ALBEDO = vec3(0.0);
	EMISSION = C;
	ROUGHNESS = 1.0;
	ALPHA = A;
}
