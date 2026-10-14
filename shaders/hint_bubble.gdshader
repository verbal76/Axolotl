shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;

// The restoration hint's string of bubbles (GuideBubbles): billboarded, a clear bubble with a bright
// rim and a highlight, per-instance alpha (COLOR.a) and a quick swell as one pops (COLOR.r).

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
	float rim = smoothstep(0.62, 0.86, d) * (1.0 - smoothstep(0.88, 1.0, d));
	float hi = 1.0 - smoothstep(0.0, 0.3, length(UV - vec2(0.36, 0.34)) * 2.0);
	float body = 0.10 * (1.0 - smoothstep(0.85, 1.0, d));
	ALBEDO = mix(vec3(0.86, 0.97, 1.0), vec3(1.0), hi);
	ALPHA = clamp(rim * 0.85 + hi * 0.9 + body, 0.0, 1.0) * v_col.a;
}
