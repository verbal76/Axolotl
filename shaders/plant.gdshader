shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_disabled;

// Large individual plants (stems, platform leaves, cave shells, roots). Colour follows the
// moss-ball health field sampled per vertex.

#include "res://shaders/variegation.gdshaderinc"
#include "res://shaders/health_field.gdshaderinc"
#include "res://shaders/aquarium_light.gdshaderinc"

uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform vec3 healthy_a : source_color = vec3(0.12, 0.4, 0.12);
uniform vec3 healthy_b : source_color = vec3(0.4, 0.72, 0.25);
uniform vec3 dead_a : source_color = vec3(0.3, 0.29, 0.26);
uniform vec3 dead_b : source_color = vec3(0.5, 0.48, 0.43);
uniform float vein = 0.0;
// Variegation (shaders/variegation.gdshaderinc): 0 = plain green.
uniform float variegate = 0.0;
uniform float vari_style = 0.0;
uniform vec3 vari_edge : source_color = vec3(0.95, 0.45, 0.62);
uniform vec3 vari_stripe : source_color = vec3(0.95, 0.93, 0.8);
uniform float health_bias = 0.0;
uniform float dark = 0.0;
uniform vec4 motes[6];
uniform int mote_count = 0;
uniform vec3 mote_color : source_color = vec3(0.55, 1.0, 0.75);
uniform float cam_fade = 0.0;
// Ambient underwater motion (dev-000024 playtest: leaves looked static). A small flap, each leaf
// on its own phase, pace and size; the attachment stays put. Leaves (leaf_data): UV.y runs base
// to tip and CUSTOM0 holds the leaf's up (mesh space) and its phase (MeshLib._leaf_into).
// Otherwise (hanging roots) the mesh hangs from its origin and swings sideways, reaching full
// swing `flutter_reach` from it. `flutter` is the tip's swing in metres; 0 is rigid (stems).
// Keep in step with Vegetation.leaf_flutter (the CPU mirror the tests use).
uniform float flutter = 0.0;
uniform float flutter_speed = 1.1;
uniform bool leaf_data = false;
uniform float flutter_reach = 5.0;
// Platform leaves (leaf_data), owner 2026-10-01 (LeafMotion drives these, one set per ball):
// `press` = world point and depth (m) of the give under a landing, springing back and settling;
// `cur_axis` / `cur_strength` = the ball's own water current (MossBall.current_at), which leans the
// blades along the flow with a slow per-leaf wave. Base and stalk stay put (UV.y = 0 there).
uniform vec4 press = vec4(0.0);
uniform vec3 cur_axis = vec3(0.0, 1.0, 0.0);
uniform float cur_strength = 0.0;
// Golden-pothos look (00040-plants, ledger row 15): the climbable leaves (the ones with leaf_data
// CUSTOM0, so never stalks or roots sharing the material) take a lively mid-green with irregular
// cream-to-yellow variegation streaking out from a pale midrib along the veins, paler edges in
// places and a soft sheen; every leaf its own (its CUSTOM0 phase and where it stands). Surface only:
// the shape, thickness and collision are untouched (shaders/variegation.gdshaderinc, pothos_leaf).
uniform float pothos = 0.0;
uniform vec3 pothos_green : source_color = vec3(0.29, 0.56, 0.13);
uniform vec3 pothos_cream : source_color = vec3(0.94, 0.92, 0.7);
uniform vec3 pothos_yellow : source_color = vec3(0.86, 0.85, 0.38);

varying float v_health;
varying float v_leaf;
varying float v_lph;
varying vec3 v_wpos;
varying vec3 v_wnorm;

float flutter_wave(float ph, float pace, float t) {
	return sin(t * pace + ph * 6.2832) * 0.75 + sin(t * pace * 2.37 + ph * 17.1) * 0.25;
}

void vertex() {
	vec3 o = MODEL_MATRIX[3].xyz;
	float node_ph = fract(sin(dot(o, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
	v_leaf = (leaf_data && dot(CUSTOM0.xyz, CUSTOM0.xyz) > 0.25) ? 1.0 : 0.0;
	v_lph = fract(CUSTOM0.w * 7.13 + node_ph);
	if (flutter > 0.0) {
		if (leaf_data) {
			float ph = fract(CUSTOM0.w + node_ph);
			float pace = flutter_speed * mix(0.75, 1.3, fract(ph * 7.31));
			float amp = flutter * mix(0.6, 1.25, fract(ph * 3.17));
			VERTEX += CUSTOM0.xyz * flutter_wave(ph, pace, TIME) * amp * UV.y * UV.y;
		} else {
			float k = clamp(length(VERTEX) / flutter_reach, 0.0, 1.0);
			float pace = flutter_speed * mix(0.75, 1.3, fract(node_ph * 7.31));
			VERTEX.xz += vec2(flutter_wave(node_ph, pace, TIME), flutter_wave(fract(node_ph + 0.37), pace * 0.83, TIME)) * flutter * k * k;
		}
	}
	if (v_leaf > 0.5 && (press.w != 0.0 || cur_strength > 0.0)) {
		vec3 wp0 = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
		float along = UV.y;
		if (press.w != 0.0) {
			float d = distance(wp0, press.xyz);
			VERTEX -= CUSTOM0.xyz * press.w * exp(-d * d / 2.6) * smoothstep(0.0, 0.35, along);
		}
		if (cur_strength > 0.0) {
			vec3 up = normalize(wp0 - ball_center);
			float band = 1.0 - smoothstep(0.45, 0.8, abs(dot(up, cur_axis)));
			vec3 flow = normalize(cross(cur_axis, up) + vec3(1e-5));
			float k = cur_strength * band * (0.024 + 0.012 * sin(TIME * mix(0.9, 1.4, v_lph) + v_lph * 6.2832));
			VERTEX += transpose(mat3(MODEL_MATRIX)) * flow * k * along * along;
		}
	}
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_health = clamp(health_at(normalize(wp - ball_center)) + health_bias, 0.0, 1.0);
	v_wpos = wp;
	v_wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

// An even 4x4 ordered dither (Expansion 6: random per-pixel dither read as noise on a phone).
float bayer4(vec2 fc) {
	int x = int(mod(fc.x, 4.0));
	int y = int(mod(fc.y, 4.0));
	int i = x + y * 4;
	int m[16] = int[](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
	return (float(m[i]) + 0.5) / 16.0;
}

void fragment() {
	if (cam_fade > 0.0) {
		float d = length(VERTEX);
		if (d < cam_fade) {
			float r = bayer4(FRAGCOORD.xy);
			if (r > d / cam_fade) discard;
		}
	}
	float n = texture(noise_tex, UV * vec2(2.0, 6.0)).r;
	float h = smoothstep(0.1, 0.9, clamp(v_health + (n - 0.5) * 0.4 * (1.0 - abs(v_health * 2.0 - 1.0)), 0.0, 1.0));
	vec3 green = mix(healthy_a, healthy_b, UV.y * 0.6 + n * 0.4);
	if (variegate > 0.0) {
		green = mix(green, variegate_leaf(green, abs(UV.x - 0.5) * 2.0, UV.y, fract(v_wpos.x * 0.37 + v_wpos.z * 0.21), vari_style, vari_edge, vari_stripe), variegate);
	}
	float sheen = 0.0;
	if (pothos > 0.0 && v_leaf > 0.5) {
		vec4 pl = pothos_leaf(noise_tex, UV, v_lph, pothos_green, pothos_cream, pothos_yellow);
		green = mix(green, pl.rgb, pothos);
		sheen = pl.a * pothos;
	}
	vec3 alb = mix(mix(dead_a, dead_b, n), green, h);
	float v = vein * (1.0 - smoothstep(0.0, 0.04, abs(UV.x - 0.5))) ;
	float side_veins = vein * 0.5 * (1.0 - smoothstep(0.0, 0.1, abs(fract((UV.y + abs(UV.x - 0.5) * 0.8) * 7.0) - 0.5)));
	alb *= 1.0 + (v + side_veins) * 0.25;
	alb *= 1.0 - dark;
	float in_cave = cave_factor(v_wpos);
	alb *= 1.0 - in_cave * 0.62;
	ALBEDO = alb;
	ROUGHNESS = 0.8;
	BACKLIGHT = alb * 0.3 * h;
	vec3 glow = vec3(0.0);
	for (int i = 0; i < mote_count; i++) {
		vec3 dd = v_wpos - motes[i].xyz;
		glow += motes[i].w / (1.0 + dot(dd, dd) * 0.9);
	}
	EMISSION = glow * mote_color * (alb * 1.6 + 0.1);
	// (Two-sided: the face turned toward the camera is the one lit.)
	EMISSION += aquarium_light(noise_tex, alb, v_wpos, FRONT_FACING ? v_wnorm : -v_wnorm, max(in_cave, dark), TIME);
	if (sheen > 0.0) {
		// A soft, waxy sheen: a broad highlight toward the ceiling light, a little more at grazing
		// angles; dimmer in murky water, none in caves.
		vec3 nv = FRONT_FACING ? NORMAL : -NORMAL;
		vec3 lv = normalize((VIEW_MATRIX * vec4(lamp_dir, 0.0)).xyz);
		float spec = pow(max(dot(nv, normalize(lv + VIEW)), 0.0), 18.0);
		float rim = pow(1.0 - max(dot(nv, VIEW), 0.0), 3.0);
		EMISSION += vec3(0.9, 1.0, 0.85) * (spec * 0.16 + rim * 0.05) * sheen * h * mix(0.45, 1.0, clarity) * (1.0 - max(in_cave, dark));
	}
}
