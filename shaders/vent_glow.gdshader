shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;

// The glow round a flowing bubble column's vent (Open Issue #2): a soft cyan ring that breathes,
// so a column reads as a way up even where the water is dim.
void fragment() {
	float d = length(UV - vec2(0.5)) * 2.0;
	float ring = exp(-pow((d - 0.55) / 0.22, 2.0)) + 0.35 * (1.0 - smoothstep(0.0, 0.55, d));
	float pulse = 0.75 + 0.25 * sin(TIME * 2.2);
	ALBEDO = vec3(0.35, 0.85, 1.0) * ring * pulse * 0.55 * (1.0 - smoothstep(0.85, 1.0, d));
}
