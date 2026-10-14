shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;

// The tail swipe's water arc (AxolotlModel): drawn over the real hit area, its bright head riding
// the tail tip as the tail sweeps round, a fading trail behind it. UV.x runs along the arc
// (0 and 1 are its two front edges), UV.y from its inner to its outer edge.

uniform float head = 0.0;       // where the tail tip is along the arc (0..1)
uniform float dir = 1.0;        // which way the tail is sweeping (+1: toward UV.x = 1)
uniform float strength = 0.0;

void fragment() {
	float a = (UV.x - head) * dir;
	float trail = smoothstep(-0.6, 0.0, a) * (1.0 - smoothstep(0.0, 0.04, a));
	float radial = sin(UV.y * 3.14159);
	// Streaks of flung water along the sweep.
	float streak = 0.75 + 0.25 * sin(UV.y * 40.0 + a * 12.0);
	float alpha = trail * radial * streak * strength * 0.75;
	ALBEDO = vec3(0.6, 0.95, 1.0) * alpha;
	ALPHA = alpha;
}
