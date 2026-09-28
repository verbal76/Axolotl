shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;

// Billboarded pooled particles (bubbles, sparkles, dissolve motes). Per-instance COLOR.

varying vec4 v_col;

void vertex() {
	vec3 wp = MODEL_MATRIX[3].xyz;
	float s = length(MODEL_MATRIX[0].xyz);
	vec4 vp = VIEW_MATRIX * vec4(wp, 1.0);
	vp.xy += VERTEX.xy * s;
	POSITION = PROJECTION_MATRIX * vp;
	v_col = COLOR;
}

void fragment() {
	float d = length(UV - vec2(0.5)) * 2.0;
	float core = 1.0 - smoothstep(0.0, 1.0, d);
	float rim = smoothstep(0.6, 0.85, d) * (1.0 - smoothstep(0.85, 1.0, d)) * 0.6;
	ALBEDO = v_col.rgb;
	EMISSION = v_col.rgb * 0.5;
	ALPHA = v_col.a * clamp(core * core + rim, 0.0, 1.0);
}
