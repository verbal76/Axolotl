shader_type spatial;
render_mode diffuse_lambert;

// Parasite body segment. Stolen vitality makes it vivid; damage drains colour from the head
// toward the rear. seg_t = 0 at the head, 1 at the tail tip.

instance uniform float seg_t = 0.0;
uniform float gray_front = 0.0;
uniform vec3 color_a : source_color = vec3(0.95, 0.2, 0.6);
uniform vec3 color_b : source_color = vec3(1.0, 0.6, 0.1);
uniform vec3 spot : source_color = vec3(0.4, 1.0, 0.3);
uniform float flash = 0.0;
uniform float windup = 0.0;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;

void fragment() {
	float n = texture(noise_tex, UV * vec2(3.0, 2.0)).r;
	vec3 vivid = mix(color_a, color_b, seg_t);
	float spots = smoothstep(0.62, 0.7, n);
	vivid = mix(vivid, spot, spots * 0.6);
	float lum = dot(vivid, vec3(0.3, 0.55, 0.15));
	vec3 grey = vec3(lum * 0.6 + 0.18) * vec3(0.95, 0.95, 0.92);
	float g = 1.0 - smoothstep(gray_front - 0.001, gray_front + 0.001, seg_t);
	g = gray_front >= 0.999 ? 1.0 : g;
	vec3 col = mix(vivid, grey, g);
	ALBEDO = col + vec3(flash);
	ROUGHNESS = mix(0.35, 0.9, g);
	float glow = (1.0 - g) * (0.25 + spots * 0.8 + windup * 1.5);
	EMISSION = vivid * glow + vec3(flash * 0.8);
}
