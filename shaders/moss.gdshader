shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_disabled;

// Mote's terrain material (docs/TERRAIN.md): living moss over earth and stone. Used by every moss
// ball's ground, the moss cushions/mounds and the caves, so a new ball gets the same vocabulary.
// - Moss grows where the surface faces away from the ball (tops, gentle slopes); steep faces,
//   overhangs and cave walls show the earthy stone underneath. The boundary is broken by noise,
//   with patches and drips of moss on steep faces.
// - Textures follow the surface normal (biplanar: the two planes facing it most), so steep faces
//   never stretch.
// - Health (restoration) turns the moss from grey to green; the stone only greys a little.
// - Four noise scales, two fetches each (8 fetches; the proof-of-concept material used 9): macro
//   variation, the moss/stone boundary and strata, detail, and moss tufts.

#include "res://shaders/health_field.gdshaderinc"
#include "res://shaders/aquarium_light.gdshaderinc"

uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform vec3 healthy_a : source_color = vec3(0.12, 0.36, 0.1);
uniform vec3 healthy_b : source_color = vec3(0.32, 0.62, 0.2);
uniform vec3 dead_a : source_color = vec3(0.33, 0.32, 0.29);
uniform vec3 dead_b : source_color = vec3(0.5, 0.48, 0.42);
// Earth/stone under the moss, and a second moss tint for large-scale variation.
uniform vec3 stone_a : source_color = vec3(0.24, 0.2, 0.15);
uniform vec3 stone_b : source_color = vec3(0.46, 0.41, 0.33);
uniform vec3 moss_tint : source_color = vec3(0.42, 0.55, 0.14);
uniform float tex_scale = 0.16;
uniform float fuzz = 0.35;
uniform float sheen = 0.35;
// How steep a face must be before stone shows (0 = vertical, 1 = flat), and how wide the blend is.
uniform float moss_slope = 0.5;
uniform float moss_blend = 0.22;
// Nearby Regeneration Motes (xyz = world position, w = intensity). Cheap fake local light.
uniform vec4 motes[6];
uniform int mote_count = 0;
uniform vec3 mote_color : source_color = vec3(0.55, 1.0, 0.75);

varying float v_health;
varying vec3 v_dir;
varying vec3 v_wpos;
varying vec3 v_wnorm;

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_dir = normalize(wp - ball_center);
	v_wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	v_health = health_at(v_dir);
	float n = texture(noise_tex, wp.xz * 0.11 + wp.y * 0.07).r * 0.5 + texture(noise_tex, wp.zy * 0.09).r * 0.5;
	// Moss is soft and lumpy; bare stone faces are firmer.
	float flat_ = smoothstep(moss_slope - 0.25, moss_slope + 0.15, dot(v_wnorm, v_dir));
	VERTEX += NORMAL * (n - 0.5) * fuzz * mix(0.55, 1.0, v_health) * mix(0.35, 1.0, flat_);
	v_wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// Biplanar projection (two samples per scale, not three): the two planes most facing the surface,
// chosen once per pixel, with explicit gradients so there is no seam where the choice changes.
struct Biplanar { vec3 ma; vec3 me; vec2 w; };

Biplanar biplanar(vec3 n) {
	vec3 a = abs(n);
	Biplanar b;
	// Major axis first, then the middle one; each returned as a basis for (u, v) and the weight axis.
	if (a.x > a.y && a.x > a.z) {
		b.ma = vec3(0.0, 1.0, 2.0);
		b.me = a.y > a.z ? vec3(1.0, 2.0, 0.0) : vec3(2.0, 0.0, 1.0);
	} else if (a.y > a.z) {
		b.ma = vec3(1.0, 2.0, 0.0);
		b.me = a.x > a.z ? vec3(0.0, 1.0, 2.0) : vec3(2.0, 0.0, 1.0);
	} else {
		b.ma = vec3(2.0, 0.0, 1.0);
		b.me = a.x > a.y ? vec3(0.0, 1.0, 2.0) : vec3(1.0, 2.0, 0.0);
	}
	vec2 w = vec2(a[int(b.ma.x)], a[int(b.me.x)]);
	w = clamp((w - 0.5773) / (1.0 - 0.5773), 0.0, 1.0);
	b.w = w * w * w + vec2(0.0001, 0.0);
	return b;
}

vec4 tri4(vec3 p, Biplanar b, float sc) {
	vec3 q = p * sc;
	vec3 dx = dFdx(q);
	vec3 dy = dFdy(q);
	vec2 u1 = vec2(q[int(b.ma.y)], q[int(b.ma.z)]);
	vec2 u2 = vec2(q[int(b.me.y)], q[int(b.me.z)]);
	vec4 x = textureGrad(noise_tex, u1, vec2(dx[int(b.ma.y)], dx[int(b.ma.z)]), vec2(dy[int(b.ma.y)], dy[int(b.ma.z)]));
	vec4 y = textureGrad(noise_tex, u2, vec2(dx[int(b.me.y)], dx[int(b.me.z)]), vec2(dy[int(b.me.y)], dy[int(b.me.z)]));
	return (x * b.w.x + y * b.w.y) / (b.w.x + b.w.y);
}

void fragment() {
	vec3 wn = normalize(v_wnorm);
	Biplanar bl = biplanar(wn);
	vec4 macro = tri4(v_wpos, bl, tex_scale * 0.18);
	vec4 mid = tri4(v_wpos, bl, tex_scale * 0.6);
	vec4 det = tri4(v_wpos, bl, tex_scale * 2.2);
	// Tufts on a rotated, non-aligned grid, so the fine pattern does not visibly repeat.
	vec4 tuft = tri4(vec3(v_wpos.x * 0.8 + v_wpos.z * 0.6, v_wpos.y, v_wpos.z * 0.8 - v_wpos.x * 0.6) + 17.0, bl, tex_scale * 13.1);

	// Where moss grows: faces turned away from the ball, broken up at mid scale, plus patches
	// and drips on steep faces; caves are mostly bare.
	float slope = dot(wn, v_dir);
	float in_cave = cave_factor(v_wpos);
	// (Flat ground stays moss: the noise can only lower "grow" to about 0.8, above the blend.)
	float grow = slope + (mid.b - 0.5) * 0.4 + smoothstep(0.62, 0.8, macro.b) * 0.3 - in_cave * 0.25;
	float cover = smoothstep(moss_slope - moss_blend, moss_slope + moss_blend, grow);

	// Moss: health breaks up at the edges of healed patches, as before.
	float n1 = mid.r;
	float edge = 1.0 - abs(v_health * 2.0 - 1.0);
	float h = smoothstep(0.15, 0.85, clamp(v_health + (n1 - 0.5) * 0.7 * edge, 0.0, 1.0));
	vec3 healthy = mix(healthy_a, healthy_b, smoothstep(0.25, 0.8, n1));
	healthy = mix(healthy, moss_tint, smoothstep(0.55, 0.85, macro.g) * 0.45);
	vec3 dead = mix(dead_a, dead_b, n1);
	float crack = smoothstep(0.86, 0.95, mid.g) * (1.0 - h);
	dead *= 1.0 - crack * 0.55;
	vec3 moss = mix(dead, healthy, h);
	// Tufts: a soft fine grain of brighter clumps and darker gaps.
	moss *= mix(0.86, 1.08, tuft.r) * mix(0.9, 1.06, det.g);

	// Earth and stone: faint strata following the ball's layers, grains and dark seams.
	float alt = length(v_wpos - ball_center);
	float strata = sin(alt * 4.0 + (mid.g - 0.5) * 9.0 + (macro.b - 0.5) * 6.0) * 0.5 + 0.5;
	vec3 stone = mix(stone_a, stone_b, smoothstep(0.1, 1.0, strata * 0.4 + det.r * 0.6 + tuft.b * 0.2));
	stone *= mix(0.8, 1.08, tuft.g);
	stone *= 1.0 - smoothstep(0.78, 0.92, det.b) * 0.45;
	// Stone near sick moss is a little greyer.
	stone = mix(stone, vec3(dot(stone, vec3(0.33))), (1.0 - h) * 0.2);

	// A soft dark lip where moss meets stone, so the moss reads as a layer on top.
	float lip = cover * (1.0 - cover) * 4.0;
	vec3 alb = mix(stone, moss, cover) * (1.0 - lip * 0.18);
	alb *= mix(0.94, 1.05, macro.r);
	alb *= 1.0 - in_cave * 0.62;
	ALBEDO = alb;
	ROUGHNESS = 1.0;
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.2);
	vec3 em = healthy_b * fres * sheen * h * 0.5 * cover;
	vec3 glow = vec3(0.0);
	for (int i = 0; i < mote_count; i++) {
		vec3 d = v_wpos - motes[i].xyz;
		glow += motes[i].w / (1.0 + dot(d, d) * 0.9);
	}
	em += glow * mote_color * (alb * 1.6 + 0.12);
	em += aquarium_light(noise_tex, alb, v_wpos, wn, in_cave, TIME);
	EMISSION = em;
}
