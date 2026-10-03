shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;

// A beam of the ceiling light through the water (Expansion 6, docs/LIGHTING.md; owner, 2026-10-02:
// soft diffused beams, not white stripes). Soft right across (bright in its middle, melting away
// toward its edges rather than ending at a line), brightest a little below the surface and dying
// away with depth and distance, with a slow broad shimmer from the rippling surface drifting down it.
// It fades out near the camera so it is never a solid cone in the face; it strengthens as the water
// clears (`strength`, Aquarium.apply). `gain` dims the wide faint halo drawn round each beam.

uniform float strength = 0.1;
uniform float gain = 1.0;
uniform vec3 color : source_color = vec3(0.8, 0.95, 0.85);
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;

void fragment() {
	// (Across the beam: a soft bell from its middle to its edges.)
	float across = abs(dot(NORMAL, VIEW));
	float edge = across * across * across;
	// (Down the beam, UV.y from the surface.)
	float fall = smoothstep(0.0, 0.22, UV.y) * (1.0 - smoothstep(0.3, 1.0, UV.y));
	// (Broad, low-contrast shimmer drifting down: the surface's ripples, never hard streaks.)
	float s = texture(noise_tex, vec2(UV.x * 1.5 + TIME * 0.018, UV.y * 0.22 - TIME * 0.035)).r;
	float s2 = texture(noise_tex, vec2(UV.x * 2.5 - TIME * 0.013, UV.y * 0.45 - TIME * 0.02)).g;
	float shimmer = 0.72 + 0.5 * (s * 0.6 + s2 * 0.4);
	float d = length(VERTEX);
	float near = smoothstep(4.0, 38.0, d);
	float haze = 1.0 - 0.6 * smoothstep(160.0, 420.0, d);
	ALBEDO = color * edge * fall * shimmer * near * haze * strength * gain;
}
