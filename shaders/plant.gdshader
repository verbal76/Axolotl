shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_disabled;

// Large individual plants (stems, platform leaves, cave shells, roots). Colour follows the
// moss-ball health field sampled per vertex.

#include "res://shaders/health_field.gdshaderinc"

uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform vec3 healthy_a : source_color = vec3(0.12, 0.4, 0.12);
uniform vec3 healthy_b : source_color = vec3(0.4, 0.72, 0.25);
uniform vec3 dead_a : source_color = vec3(0.3, 0.29, 0.26);
uniform vec3 dead_b : source_color = vec3(0.5, 0.48, 0.43);
uniform float vein = 0.0;
uniform float health_bias = 0.0;
uniform float dark = 0.0;
uniform vec4 motes[6];
uniform int mote_count = 0;
uniform vec3 mote_color : source_color = vec3(0.55, 1.0, 0.75);
uniform float cam_fade = 0.0;

varying float v_health;
varying vec3 v_wpos;

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_health = clamp(health_at(normalize(wp - ball_center)) + health_bias, 0.0, 1.0);
	v_wpos = wp;
}

void fragment() {
	if (cam_fade > 0.0) {
		float d = length(VERTEX);
		if (d < cam_fade) {
			float r = fract(sin(dot(FRAGCOORD.xy, vec2(12.9898, 78.233))) * 43758.5453);
			if (r > d / cam_fade) discard;
		}
	}
	float n = texture(noise_tex, UV * vec2(2.0, 6.0)).r;
	float h = smoothstep(0.1, 0.9, clamp(v_health + (n - 0.5) * 0.4 * (1.0 - abs(v_health * 2.0 - 1.0)), 0.0, 1.0));
	vec3 alb = mix(mix(dead_a, dead_b, n), mix(healthy_a, healthy_b, UV.y * 0.6 + n * 0.4), h);
	float v = vein * (1.0 - smoothstep(0.0, 0.04, abs(UV.x - 0.5))) ;
	float side_veins = vein * 0.5 * (1.0 - smoothstep(0.0, 0.1, abs(fract((UV.y + abs(UV.x - 0.5) * 0.8) * 7.0) - 0.5)));
	alb *= 1.0 + (v + side_veins) * 0.25;
	alb *= 1.0 - dark;
	alb *= 1.0 - cave_factor(v_wpos) * 0.62;
	ALBEDO = alb;
	ROUGHNESS = 0.8;
	BACKLIGHT = alb * 0.3 * h;
	vec3 glow = vec3(0.0);
	for (int i = 0; i < mote_count; i++) {
		vec3 dd = v_wpos - motes[i].xyz;
		glow += motes[i].w / (1.0 + dot(dd, dd) * 0.9);
	}
	EMISSION = glow * mote_color * (alb * 1.6 + 0.1);
}
