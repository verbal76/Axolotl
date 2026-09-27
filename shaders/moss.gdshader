shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_disabled;

#include "res://shaders/health_field.gdshaderinc"

uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform vec3 healthy_a : source_color = vec3(0.12, 0.36, 0.1);
uniform vec3 healthy_b : source_color = vec3(0.32, 0.62, 0.2);
uniform vec3 dead_a : source_color = vec3(0.33, 0.32, 0.29);
uniform vec3 dead_b : source_color = vec3(0.5, 0.48, 0.42);
uniform float tex_scale = 0.16;
uniform float fuzz = 0.35;
uniform float sheen = 0.35;
// Nearby Regeneration Motes (xyz = world position, w = intensity). Cheap fake local light.
uniform vec4 motes[6];
uniform int mote_count = 0;
uniform vec3 mote_color : source_color = vec3(0.55, 1.0, 0.75);

varying float v_health;
varying vec3 v_dir;
varying vec3 v_wpos;

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_dir = normalize(wp - ball_center);
	v_health = health_at(v_dir);
	float n = texture(noise_tex, wp.xz * 0.11 + wp.y * 0.07).r * 0.5 + texture(noise_tex, wp.zy * 0.09).r * 0.5;
	VERTEX += NORMAL * (n - 0.5) * fuzz * mix(0.55, 1.0, v_health);
	v_wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float tri(vec3 p, vec3 bl, float sc, int ch) {
	vec4 a = texture(noise_tex, p.yz * sc);
	vec4 b = texture(noise_tex, p.xz * sc);
	vec4 c = texture(noise_tex, p.xy * sc);
	vec4 r = a * bl.x + b * bl.y + c * bl.z;
	return ch == 0 ? r.r : (ch == 1 ? r.g : r.b);
}

void fragment() {
	vec3 bl = abs(v_dir);
	bl /= (bl.x + bl.y + bl.z);
	float n1 = tri(v_wpos, bl, tex_scale * 0.35, 0);
	float n2 = tri(v_wpos, bl, tex_scale * 2.2, 1);
	float n3 = tri(v_wpos, bl, tex_scale * 0.9, 2);
	float edge = 1.0 - abs(v_health * 2.0 - 1.0);
	float h = clamp(v_health + (n1 - 0.5) * 0.7 * edge, 0.0, 1.0);
	h = smoothstep(0.15, 0.85, h);
	vec3 healthy = mix(healthy_a, healthy_b, smoothstep(0.25, 0.8, n1));
	vec3 dead = mix(dead_a, dead_b, n1);
	float crack = smoothstep(0.86, 0.95, n3) * (1.0 - h);
	dead *= 1.0 - crack * 0.55;
	vec3 alb = mix(dead, healthy, h) * mix(0.72, 1.12, n2);
	ALBEDO = alb;
	ALBEDO *= 1.0 - cave_factor(v_wpos) * 0.62;
	ROUGHNESS = 1.0;
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.2);
	vec3 em = healthy_b * fres * sheen * h * 0.5;
	vec3 glow = vec3(0.0);
	for (int i = 0; i < mote_count; i++) {
		vec3 d = v_wpos - motes[i].xyz;
		glow += motes[i].w / (1.0 + dot(d, d) * 0.9);
	}
	em += glow * mote_color * (alb * 1.6 + 0.12);
	EMISSION = em;
}
