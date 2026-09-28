shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;

// A shaft of the ceiling light through the water (Expansion 6, docs/LIGHTING.md): soft-edged,
// streaked by the rippling surface above (slowly drifting), brightest a little below the surface
// and dying away with depth. It fades out near the camera, so it is never a solid cone in the
// face; and it strengthens as the water clears (`strength`, Aquarium.apply).

uniform float strength = 0.1;
uniform vec3 color : source_color = vec3(0.8, 0.95, 0.85);
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;

void fragment() {
	float edge = pow(abs(dot(NORMAL, VIEW)), 1.6);
	// UV.y runs down the shaft from the surface.
	float fall = smoothstep(0.0, 0.18, UV.y) * (1.0 - smoothstep(0.45, 1.0, UV.y));
	float s = texture(noise_tex, vec2(UV.x * 4.0 + TIME * 0.006, UV.y * 0.35 - TIME * 0.012)).r;
	float s2 = texture(noise_tex, vec2(UV.x * 9.0 - TIME * 0.004, UV.y * 0.8)).g;
	float streak = 0.35 + 1.3 * s * s * (0.6 + 0.4 * s2);
	float near = smoothstep(6.0, 34.0, length(VERTEX));
	ALBEDO = color * edge * fall * streak * near * strength;
}
