shader_type spatial;
render_mode diffuse_lambert;

#include "res://shaders/aquarium_light.gdshaderinc"

uniform sampler2D gravel_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D grime_tex : filter_linear_mipmap, repeat_enable;
uniform float clean = 0.0;        // global aquarium restoration 0..1
uniform float tile = 0.02;
uniform vec3 dirt_color : source_color = vec3(0.27, 0.27, 0.2);
// Pebbles (Expansion 6): each one a single stone colour taken from the gravel at its position,
// not a patch of the texture (which read as confetti).
uniform bool pebble = false;

varying vec3 v_wpos;
varying vec3 v_origin;
varying vec3 v_wnorm;

void vertex() {
	v_wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_origin = MODEL_MATRIX[3].xyz;
	v_wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 g;
	if (pebble) {
		g = textureLod(gravel_tex, v_origin.xz * 0.013, 4.0).rgb;
		g *= mix(0.8, 1.1, texture(grime_tex, v_wpos.xz * 0.4 + v_wpos.y * 0.3).r);
	} else {
		g = texture(gravel_tex, v_wpos.xz * tile, 1.5).rgb;
	}
	// A kid's coloured gravel, but softened: pastel stone rather than confetti.
	float lum0 = dot(g, vec3(0.33));
	g = mix(vec3(lum0), g, 0.62);
	float grime = texture(grime_tex, v_wpos.xz * tile * 0.23).r;
	// Continuous cleanup: the film thins everywhere, and patches clear first where grime is thin.
	float film = clamp((grime * 0.9 + 0.35) - clean * 1.25, 0.0, 1.0);
	film = smoothstep(0.0, 0.45, film);
	float lum = dot(g, vec3(0.33));
	vec3 dull = mix(vec3(lum), g, 0.25) * 0.55;
	vec3 base = mix(g, dull, (1.0 - clean) * 0.7);
	vec3 alb = mix(base, dirt_color * (0.7 + grime * 0.5), film * 0.85);
	ALBEDO = alb;
	ROUGHNESS = mix(0.95, 0.6, clean);
	EMISSION = aquarium_light(grime_tex, alb, v_wpos, v_wnorm, 0.0, TIME);
}
