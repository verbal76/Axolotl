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
// - Near the camera the same samples also give the surface relief (bump from screen-space
//   derivatives: no extra fetches), so moss clumps and stone grain catch the light (E6f).
// - Anti-repetition (owner, 2026-10-07: "large streaks repeat across the moss balls"): the mid
//   layer (one tile every ~10 m, where the repeats and streaks were) is read on two grids turned
//   and scaled differently and cross-faded by the macro layer, so no two neighbouring tiles match;
//   the warp that smeared it into streaks is gentler; bare-earth patches and a slow hue drift
//   round the ball come from samples already taken (2 extra fetches in all, 10).

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
// How far the macro layer warps the mid one (m), and the height of the surface relief (m).
uniform float warp = 3.0;
uniform float relief = 0.035;
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

// `blur` widens the filter footprint (a coarser mip): 1 = normal.
vec4 tri4(vec3 p, Biplanar b, float sc, float blur) {
	vec3 q = p * sc;
	vec3 dx = dFdx(q) * blur;
	vec3 dy = dFdy(q) * blur;
	vec2 u1 = vec2(q[int(b.ma.y)], q[int(b.ma.z)]);
	vec2 u2 = vec2(q[int(b.me.y)], q[int(b.me.z)]);
	vec4 x = textureGrad(noise_tex, u1, vec2(dx[int(b.ma.y)], dx[int(b.ma.z)]), vec2(dy[int(b.ma.y)], dy[int(b.ma.z)]));
	vec4 y = textureGrad(noise_tex, u2, vec2(dx[int(b.me.y)], dx[int(b.me.z)]), vec2(dy[int(b.me.y)], dy[int(b.me.z)]));
	return (x * b.w.x + y * b.w.y) / (b.w.x + b.w.y);
}

// Bump from a height field with no extra texture fetches: the height's screen-space derivatives
// tilt the normal (surface-gradient bump mapping). `amp` is the relief in metres.
vec3 bump(vec3 n, vec3 p, float hgt, float amp) {
	vec3 dpx = dFdx(p);
	vec3 dpy = dFdy(p);
	vec3 r1 = cross(dpy, n);
	vec3 r2 = cross(n, dpx);
	float det = dot(dpx, r1);
	vec3 grad = (r1 * dFdx(hgt) + r2 * dFdy(hgt)) * sign(det) / max(abs(det), 1e-8);
	return normalize(n - grad * amp);
}

void fragment() {
	vec3 wn = normalize(v_wnorm);
	Biplanar bl = biplanar(wn);
	// (The macro layer on a rotated grid, and the mid layer warped by it: on the big balls these
	// repeat dozens of times round the circumference, and without this the repeats line up into
	// stripes seen from afar. The macro layer is read from a coarse mip (E6f): its fine grain,
	// magnified by the warp, smeared the moss into marble swirls and streaks up close.)
	vec4 macro = tri4(vec3(v_wpos.x * 0.6 - v_wpos.z * 0.8, v_wpos.y, v_wpos.x * 0.8 + v_wpos.z * 0.6) + 41.0, bl, tex_scale * 0.18, 24.0);
	vec4 mid_a = tri4(v_wpos + (macro.rgb - 0.5) * warp, bl, tex_scale * 0.6, 1.0);
	// The second grid: turned about 37 degrees on another axis pair and 1.37x the scale, so its
	// tiles never line up with the first; the macro layer picks between them in soft patches.
	vec3 p2 = vec3(v_wpos.x * 0.8 - v_wpos.y * 0.6, v_wpos.x * 0.6 + v_wpos.y * 0.8, v_wpos.z) + 73.0;
	vec4 mid_b = tri4(p2 + (macro.gbr - 0.5) * warp, bl, tex_scale * 0.6 * 1.37, 1.0);
	vec4 mid = mix(mid_a, mid_b, smoothstep(0.35, 0.65, macro.g * 0.7 + macro.r * 0.3));
	vec4 det = tri4(v_wpos, bl, tex_scale * 2.2, 1.0);
	// Tufts on a rotated, non-aligned grid, so the fine pattern does not visibly repeat.
	vec4 tuft = tri4(vec3(v_wpos.x * 0.8 + v_wpos.z * 0.6, v_wpos.y, v_wpos.z * 0.8 - v_wpos.x * 0.6) + 17.0, bl, tex_scale * 13.1, 1.0);

	// Where moss grows: faces turned away from the ball, broken up at mid scale, plus patches
	// and drips on steep faces; caves are mostly bare.
	float slope = dot(wn, v_dir);
	float in_cave = cave_factor(v_wpos);
	// (Flat ground stays moss: the noise can only lower "grow" to about 0.8, above the blend.)
	// Bare earth on open ground (reference: moss with brown, earthy patches): soft-edged islands
	// where the macro and mid layers both run low, a few metres across, never a grid.
	float earth = smoothstep(0.58, 0.74, (1.0 - macro.b) * 0.55 + (1.0 - mid.g) * 0.45) * (1.0 - in_cave);
	float grow = slope + (mid.b - 0.5) * 0.4 + smoothstep(0.62, 0.8, macro.b) * 0.3 - in_cave * 0.25 - earth * 0.55;
	float cover = smoothstep(moss_slope - moss_blend, moss_slope + moss_blend, grow);

	// Moss: health breaks up at the edges of healed patches, as before.
	float n1 = mid.r;
	float edge = 1.0 - abs(v_health * 2.0 - 1.0);
	float h = smoothstep(0.15, 0.85, clamp(v_health + (n1 - 0.5) * 0.7 * edge, 0.0, 1.0));
	vec3 healthy = mix(healthy_a, healthy_b, smoothstep(0.25, 0.8, n1));
	healthy = mix(healthy, moss_tint, smoothstep(0.55, 0.85, macro.g) * 0.45);
	// A slow drift of hue round the whole ball (tens of metres; no texture): deeper, bluer greens in
	// places and warmer, yellower ones in others, so distant ground never reads as one repeated tile.
	float drift = sin(dot(v_dir, vec3(3.1, 2.3, 1.7)) * 2.0 + sin(dot(v_dir, vec3(-1.3, 2.9, 2.2)) * 3.0)) * 0.5 + 0.5;
	healthy *= mix(vec3(0.86, 0.95, 1.04), vec3(1.1, 1.04, 0.84), drift);
	vec3 dead = mix(dead_a, dead_b, n1);
	float crack = smoothstep(0.86, 0.95, mid.g) * (1.0 - h);
	dead *= 1.0 - crack * 0.55;
	vec3 moss = mix(dead, healthy, h);
	// Cushions of moss (E6f; owner reference: a sprouted moss ball): clumps a few centimetres
	// across on lumps a hand wide, shaded gaps between them, and paler tips on the tallest strands.
	// (The finest layer, 0.48 m tiles, fades out by mid-distance: there it is under a pixel and, at a
	// grazing view, aliased into fine streaks across the slope.)
	float fine = 1.0 - smoothstep(6.0, 18.0, length(VERTEX));
	float clump = mix(0.5, tuft.r, fine) * 0.65 + det.g * 0.35;
	moss *= mix(0.68, 1.1, smoothstep(0.22, 0.78, clump));
	moss = mix(moss, moss * vec3(1.12, 1.12, 0.86) + vec3(0.02, 0.025, 0.0), smoothstep(0.62, 0.86, tuft.r) * 0.5 * h);

	// Earth and stone: faint strata following the ball's layers, grains and dark seams.
	float alt = length(v_wpos - ball_center);
	float strata = sin(alt * 4.0 + (mid.g - 0.5) * 9.0 + (macro.b - 0.5) * 6.0) * 0.5 + 0.5;
	float grain = strata * 0.4 + det.r * 0.6 + tuft.b * 0.2;
	vec3 stone = mix(stone_a, stone_b, smoothstep(0.1, 1.0, grain));
	stone *= mix(0.8, 1.08, tuft.g);
	float seam = smoothstep(0.78, 0.92, det.b);
	stone *= 1.0 - seam * 0.45;
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
	// Relief (E6f): the moss clumps, and the stone's grain, strata and sunken seams, catch the
	// light. Faded out with distance, where it would only shimmer. (No branch round it: screen-space
	// derivatives are undefined in divergent control flow.)
	float near_ = 1.0 - smoothstep(10.0, 32.0, length(VERTEX));
	float hgt = mix(grain * 0.7 + tuft.g * 0.3 - seam * 0.6, clump * 1.3, cover);
	vec3 bn = bump(wn, v_wpos, hgt, relief * near_);
	NORMAL = normalize((VIEW_MATRIX * vec4(bn, 0.0)).xyz);
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
