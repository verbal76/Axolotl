shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

// A Regeneration Mote's trailing tentacles (Expansion 6): they sway gently in the water and trail
// behind as it swims (`drag`: its velocity in the mote's own space), more toward their tips.
// UV.y runs root (0) to tip (1); COLOR.r is each tentacle's own phase.

instance uniform vec3 drag = vec3(0.0);
instance uniform float glow = 1.0;
uniform vec3 color : source_color = vec3(0.55, 1.0, 0.72);

void vertex() {
	float t = UV.y;
	float ph = COLOR.r * 6.2832;
	vec3 sway = vec3(sin(TIME * 2.4 + ph + t * 4.0), 0.0, cos(TIME * 1.9 + ph * 1.3 + t * 3.5)) * 0.03 * t * t;
	VERTEX += sway - drag * 0.075 * t * t;
}

void fragment() {
	ALBEDO = color * 0.4;
	EMISSION = color * (1.8 - UV.y * 0.9) * glow;
}
