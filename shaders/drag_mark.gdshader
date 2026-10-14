shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, shadows_disabled, specular_disabled;

// A drag mark scraped in the moss or gravel by a braced foot (WaterFX.drag_mark; ledger row 19).
// A small flat strip on the ground: UV.x across, UV.y along the skid (0 where the foot dug in, 1
// where it is now). Per instance: COLOR.a the fade; INSTANCE_CUSTOM.x the length (m), .y a variant
// (0..1), .w how far the moss material lifts or sinks its surface here (its fuzz, as moss.gdshader
// displaces it), so the strip lies on the drawn moss rather than on the smooth ground under it.
// Three toe furrows of paler exposed silt with a dark shadowed edge, over a faint scuff, and a little
// pushed-up silt at the far end.

uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;

varying vec4 v_col;
varying vec4 v_cus;

void vertex() {
	v_col = COLOR;
	v_cus = INSTANCE_CUSTOM;
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float n = texture(noise_tex, wp.xz * 0.11 + wp.y * 0.07).r * 0.5 + texture(noise_tex, wp.zy * 0.09).r * 0.5;
	VERTEX.y += (n - 0.5) * INSTANCE_CUSTOM.w;
}

void fragment() {
	float len = max(v_cus.x, 0.01);
	float across = abs(UV.x - 0.5) * 2.0;
	float m = UV.y * len;
	float end_a = smoothstep(0.0, 0.02, m);
	float end_b = 1.0 - smoothstep(len - 0.025, len, m);
	float body = 1.0 - smoothstep(0.45, 1.0, length(vec2(across, UV.y * 2.0 - 1.0)));
	float pale = 0.0;
	float shade = 0.0;
	for (int k = 0; k < 3; k++) {
		float c = 0.27 + 0.23 * float(k) + (v_cus.y - 0.5) * 0.08 * float(k - 1);
		// (Widest and deepest where the toe dug in, narrowing along the skid.)
		float w = mix(0.07, 0.045, UV.y);
		float x = UV.x - c;
		pale = max(pale, 1.0 - smoothstep(0.0, w, abs(x)));
		shade = max(shade, smoothstep(w * 0.6, w * 1.1, x) * (1.0 - smoothstep(w * 1.1, w * 1.9, x)));
	}
	float along = end_a * end_b * mix(1.0, 0.75, UV.y);
	pale *= along;
	shade *= along;
	float lip = smoothstep(len - 0.045, len - 0.02, m) * (1.0 - smoothstep(len - 0.02, len, m)) * (1.0 - smoothstep(0.3, 0.9, across));
	vec3 silt = vec3(0.82, 0.72, 0.54);
	vec3 dark = vec3(0.05, 0.045, 0.03);
	vec3 col = mix(dark, silt, pale / max(pale + shade, 0.001));
	col = mix(col, silt * 1.1, lip);
	float a = max(max(pale * 0.9, shade * 0.75), max(body * 0.28, lip * 0.8));
	ALBEDO = mix(dark * 2.0, col, clamp((pale + shade + lip) * 2.0, 0.0, 1.0));
	ROUGHNESS = 1.0;
	ALPHA = clamp(a * v_col.a, 0.0, 1.0);
}
