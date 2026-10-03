shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;
// Ooze bubbles (RavineOoze's own pool, owner 2026-10-01): the approved soft yellow/purple dots, now
// swelling out of the ooze, wobbling up, swelling a touch and popping into a soft expanding ring.
// Per instance: COLOR (tint, alpha) and INSTANCE_CUSTOM.x: 0 = bubble, 1 = popping ring (y = 0..1).

varying vec4 v_col;
varying vec4 v_cus;

void vertex() {
	vec3 wp = MODEL_MATRIX[3].xyz;
	float s = length(MODEL_MATRIX[0].xyz);
	vec4 vp = VIEW_MATRIX * vec4(wp, 1.0);
	vp.xy += VERTEX.xy * s;
	POSITION = PROJECTION_MATRIX * vp;
	v_col = COLOR;
	v_cus = INSTANCE_CUSTOM;
}

void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float d = length(q);
	if (d > 1.0) {
		discard;
	}
	float a;
	vec3 c = v_col.rgb;
	if (v_cus.x < 0.5) {
		// A bubble: the same soft dot as before (the approved look: WaterFX's puff), tinted.
		float core = 1.0 - smoothstep(0.0, 1.0, d);
		float rim = smoothstep(0.6, 0.85, d) * (1.0 - smoothstep(0.85, 1.0, d)) * 0.6;
		a = clamp(core * core + rim, 0.0, 1.0);
	} else {
		// The pop: a thin ring that spreads and fades.
		float w = mix(0.22, 0.08, v_cus.y);
		a = smoothstep(1.0 - w * 2.0, 1.0 - w, d) * (1.0 - smoothstep(1.0 - w * 0.5, 1.0, d));
	}
	ALBEDO = c;
	ALPHA = a * v_col.a;
}
