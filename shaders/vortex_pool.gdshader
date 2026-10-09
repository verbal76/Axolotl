shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

// The vortex's mouth (Expansion 6): a swirling tidal pool lying on the moss, no solid funnel.
// A disc that follows the ground (built in Vortex._pool_mesh; UV.x = round, UV.y = 0 centre .. 1 rim,
// NORMAL = the ground's up). Spiral bands of water wind in toward a deep blue eye, foam on their
// crests, turning faster near the centre, the whole of it rippling. `reach` grows the pool from the
// eye as the vortex strengthens; it fades out softly at its edge into the moss.

uniform float strength = 0.0;
uniform float reach = 1.0;          // visible fraction of the radius
uniform float pulse = 0.0;
uniform float spin_phase = 0.0;
uniform float arms = 3.0;
uniform vec3 deep : source_color = vec3(0.05, 0.28, 0.42);
uniform vec3 water : source_color = vec3(0.2, 0.66, 0.8);
uniform vec3 foam : source_color = vec3(0.9, 0.98, 1.0);
// The connection's own faint hue (Vortex.TINTS), strongest in the churning ring round the eye.
uniform vec3 tint : source_color = vec3(1.0);
uniform float tint_amt = 0.0;
// Which end of the connection this pool is (u: 0 = ball A, 1 = ball B; ledger row 14, for Hard Mode).
// The current's offset is zero at the mouths (they are anchored), so the pool itself does not move.
uniform float u_end = 0.0;
// Platform state ring (Vortex.STATE_LOOK, set from Vortex.travel_ready()): colour, gain, dashes
// (0 = continuous), breathing swing and flow. Pattern, brightness and motion differ between the two
// states as well as hue, so it reads without red/green colour vision.
uniform vec3 state_col : source_color = vec3(0.7, 0.32, 0.22);
uniform float state_gain = 0.8;
uniform float state_dash = 1.0;
uniform float state_breathe = 0.3;
uniform float state_flow = 0.0;

#include "res://shaders/vortex_distress.gdshaderinc"

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float n2_pre(float ang, float r, float swirl) {
	float a = ang - swirl * 0.25;
	return vnoise(vec2(cos(a), sin(a)) * (r * 3.0 + 0.4) + 13.1);
}

void vertex() {
	float r = UV.y;
	// A gentle swell rolling round the pool, calm at the rim.
	float wave = sin(UV.x * 6.2832 * 3.0 - spin_phase * 2.0 + r * 9.0) * 0.05 * (1.0 - r) * strength;
	VERTEX += NORMAL * wave;
}

void fragment() {
	float r = UV.y / max(reach, 0.001);
	if (r > 1.0) {
		discard;
	}
	float ang = UV.x * 6.2832;
	// Spiral arms winding in toward the eye; the inner water turns faster.
	float swirl = spin_phase * (1.0 + 2.0 * (1.0 - r));
	float band = sin(ang * arms + log(r + 0.08) * 1.8 - swirl * 1.6 + (n2_pre(ang, r, swirl) - 0.5) * 2.5);
	// Noise in the pool's plane, turning with the water (no seam where UV.x wraps).
	float a1 = ang + swirl * 0.35;
	float n = vnoise(vec2(cos(a1), sin(a1)) * (r * 9.0 + 0.5) + vec2(0.0, TIME * 0.4));
	float n2 = vnoise(vec2(cos(ang - swirl * 0.2), sin(ang - swirl * 0.2)) * (r * 4.0 + 0.3) + 7.3);
	float crest = smoothstep(0.45, 1.05, band * 0.45 + n * 0.75 + n2 * 0.25 - 0.05);
	vec3 col = mix(water, deep, smoothstep(0.45, 0.0, r));
	col = mix(col, foam, crest * (0.25 + 0.45 * (1.0 - r)) + pulse * 0.2);
	col *= 0.92 + 0.16 * n2;
	// Churning white water round the eye, and a lip of foam where the pool meets the moss.
	// (Gaussian bands as x*x: pow() of a negative base is undefined on some mobile GPUs.)
	float xr = (r - 0.13) / 0.06;
	float ring = exp(-xr * xr) * (0.6 + 0.4 * n);
	float xl = (r - 0.82) / 0.07;
	float lip = exp(-xl * xl) * smoothstep(0.35, 0.7, n2 + n * 0.4);
	vec3 foam_t = mix(foam, tint, tint_amt * 1.2);
	vec3 ds = vec3(1.0, 0.0, 0.0);
	if (distress_any()) {
		// Hard Mode distress: the whole pool, eye and lip belong to its own end's half.
		ds = distress_at(u_end);
		foam_t = mix(foam, tint, (tint_amt + ds.y) * 1.2) * ds.x;
	}
	col = mix(col, foam_t, clamp(ring * 0.7 + lip * 0.6, 0.0, 1.0) * strength);
	// (A faint glow of the hue in the eye's water too.)
	col = mix(col, col * tint * 1.25 * ds.x, tint_amt * 0.45 * smoothstep(0.5, 0.0, r));
	if (ds.z > 0.0) {
		col = mix(col, vec3(1.0), ds.z * clamp(ring + lip, 0.0, 1.0));
	}
	float edge = 1.0 - smoothstep(0.8, 1.0, r);
	float a = (0.6 + crest * 0.3 + ring * 0.3 + lip * 0.3) * edge * (0.35 + strength * 0.65);
	// The pad's state (the owner's landing-pad indicator): the whole pool's water takes a muted wash
	// of the state colour (brighter when ready), and a ring just inside the foam lip carries the
	// pattern: dashed and breathing when not ready, continuous and flowing when ready.
	float wash = mix(0.5, 0.58, state_dash) * (1.0 - smoothstep(0.6, 1.0, r));
	col = mix(col, state_col * mix(1.45, 0.8, state_dash), wash);
	float xs = (r - 0.7) / 0.075;
	float sr = exp(-xs * xs);
	float dash = mix(1.0, smoothstep(0.3, 0.62, 0.5 + 0.5 * cos(ang * 9.0)), state_dash);
	float breathe = 1.0 - state_breathe * (0.5 + 0.5 * sin(TIME * 1.6));
	float flow = mix(1.0, 0.78 + 0.22 * sin(ang * 3.0 - TIME * 1.3 + r * 12.0), state_flow);
	float sg = clamp(sr * dash * breathe * flow * state_gain, 0.0, 1.0);
	col = mix(col, state_col * mix(1.8, 0.65, state_dash), sg);
	a = max(a, sg * 0.9 * edge);
	ALBEDO = col;
	ALPHA = clamp(a, 0.0, 0.95);
}
