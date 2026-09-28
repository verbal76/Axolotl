shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled;

// A Regeneration Mote's bell (Expansion 6): a soft translucent jelly, brightest at its rim (seen
// edge on), faint through its middle, where the glowing nucleus shows.

instance uniform float glow = 1.0;
uniform vec3 color : source_color = vec3(0.5, 1.0, 0.72);

void fragment() {
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	ALBEDO = color * (0.18 + rim * 1.1) * glow;
}
