shader_type spatial;
render_mode diffuse_lambert;
// Aquarium gravel (docs/AQUARIUM.md). Two uses:
// - the floor (a displaced height mesh with real piles and hollows): the pebble texture
//   (gravel2_albedo: colour + height, gravel2_normal) sampled twice, at different scales and
//   rotations, blended by height through a slow mask, so it never repeats as a grid; the pebbles'
//   own normals light it, and the crevices stay dark;
// - 3D pebbles and stones (pebble = true, instanced): each one colour (INSTANCE_CUSTOM.rgb), with
//   fine grit from the texture, darker toward where it sinks into the gravel (vertex colour).
// Both carry the film of grime that clears as the tank is restored (`clean`).

#include "res://shaders/aquarium_light.gdshaderinc"

uniform sampler2D gravel_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D gravel_nrm : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grime_tex : filter_linear_mipmap, repeat_enable;
uniform float clean = 0.0;        // global aquarium restoration 0..1
// World units per texture repeat (the texture shows pebbles of ~1.5-5 units).
uniform float tile = 0.0049;
uniform vec3 dirt_color : source_color = vec3(0.27, 0.27, 0.2);
uniform bool pebble = false;

varying vec3 v_wpos;
varying vec3 v_wnorm;
varying vec3 v_col;
varying float v_bury;

void vertex() {
	v_wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	v_col = pebble ? INSTANCE_CUSTOM.rgb : vec3(1.0);
	v_bury = COLOR.r;
}

vec3 ts_to_world(vec3 n_ts, float ang, vec3 geo) {
	// The floor's texture axes are world X and Z (rotated by `ang` for the second sample).
	vec3 ax = vec3(cos(ang), 0.0, sin(ang));
	vec3 az = vec3(-sin(ang), 0.0, cos(ang));
	return normalize(geo * n_ts.z + ax * n_ts.x + az * n_ts.y);
}

void fragment() {
	vec3 g;
	vec3 nw = v_wnorm;
	float hgt = 0.5;
	if (pebble) {
		// Mottled stone (fine noise, never the pebble texture: that drew rings on each stone).
		float m1 = texture(grime_tex, v_wpos.xz * 0.21 + v_wpos.y * 0.17).r;
		float m2 = texture(grime_tex, v_wpos.zy * 0.47 + v_wpos.x * 0.11).r;
		g = v_col * (0.62 + 0.22 * m1 + 0.1 * m2);
		g *= mix(0.4, 1.0, v_bury);
		hgt = 0.7 * v_bury;
	} else {
		float a1 = 1.1;
		vec2 ua = v_wpos.xz * tile;
		vec2 ub = mat2(vec2(cos(a1), sin(a1)), vec2(-sin(a1), cos(a1))) * v_wpos.xz * tile * 0.71 + vec2(0.37, 0.61);
		vec4 sa = texture(gravel_tex, ua);
		vec4 sb = texture(gravel_tex, ub);
		float m = texture(grime_tex, v_wpos.xz * 0.0031).r;
		float ha = sa.a + (m - 0.5) * 1.1;
		float hb = sb.a - (m - 0.5) * 1.1;
		float w = smoothstep(-0.1, 0.1, ha - hb);
		g = mix(sb.rgb, sa.rgb, w);
		hgt = mix(sb.a, sa.a, w);
		vec3 na = texture(gravel_nrm, ua).xyz * 2.0 - 1.0;
		vec3 nb = texture(gravel_nrm, ub).xyz * 2.0 - 1.0;
		vec3 wa = ts_to_world(vec3(na.x, -na.y, na.z), 0.0, v_wnorm);
		vec3 wb = ts_to_world(vec3(nb.x, -nb.y, nb.z), a1, v_wnorm);
		nw = normalize(mix(wb, wa, w));
		// Broad variation: warmer and cooler, lighter and darker drifts of stones.
		float drift = texture(grime_tex, v_wpos.xz * 0.0017 + vec2(0.3, 0.1)).r;
		g *= mix(vec3(0.9, 0.92, 0.96), vec3(1.08, 1.02, 0.94), drift) * mix(0.85, 1.1, m);
	}
	float grime = texture(grime_tex, v_wpos.xz * 0.0046).r;
	// Continuous cleanup: the film thins everywhere, and patches clear first where grime is thin.
	float film = clamp((grime * 0.9 + 0.35) - clean * 1.25, 0.0, 1.0);
	film = smoothstep(0.0, 0.45, film) * mix(1.0, 0.6, hgt);
	float lum = dot(g, vec3(0.33));
	vec3 dull = mix(vec3(lum), g, 0.35) * 0.62;
	vec3 base = mix(g, dull, (1.0 - clean) * 0.6);
	vec3 alb = mix(base, dirt_color * (0.7 + grime * 0.5), film * 0.8);
	ALBEDO = alb;
	NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);
	ROUGHNESS = mix(0.95, 0.78, clean * hgt);
	SPECULAR = 0.18;
	// (Caustics toned down here: their web is about a pebble wide, and at full strength it traced
	// bright rings round every stone.)
	EMISSION = aquarium_light(grime_tex, alb, v_wpos, nw, 0.0, TIME) * (pebble ? 0.25 : 0.5);
}
