shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;

// Spinning hollow water tunnel / whirlpool. UV.x = around, UV.y = along (0 at source).

uniform float grow = 0.0;          // visible fraction of the tunnel length
uniform float strength = 0.0;      // 0 faint disturbance .. 1 strong
uniform float pulse = 0.0;
uniform float spin = 1.0;
uniform float along_scale = 30.0;
uniform float fade_end = 1.0;
uniform vec3 color : source_color = vec3(0.55, 0.9, 1.0);

void fragment() {
	float t = UV.y;
	if (t > grow) discard;
	float tipfade = 1.0 - smoothstep(grow - 0.06, grow, t);
	float stripes = sin((UV.x * 6.0 + t * along_scale * 0.35 - TIME * spin * 2.2) * 6.2831) * 0.5 + 0.5;
	float stripes2 = sin((UV.x * 3.0 - t * along_scale * 0.2 - TIME * spin * 1.3) * 6.2831) * 0.5 + 0.5;
	float flow = pow(stripes, 3.0) * 0.7 + pow(stripes2, 4.0) * 0.4;
	float rim = pow(1.0 - abs(dot(NORMAL, VIEW)), 1.5);
	float a = (0.08 + flow * 0.5 + rim * 0.3) * (0.25 + strength * 0.75) * tipfade * (1.0 + pulse);
	a *= smoothstep(0.0, 0.03, t) * (1.0 - smoothstep(fade_end - 0.03, fade_end, t));
	ALBEDO = color * a;
}
