shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

// The vortex's water (owner, 2026-10-07, reference image: "broad, smooth, translucent streams of
// water twisting organically into a funnel", not the segmented corkscrew of tubes it replaces).
// A few broad ribbons lie on the funnel's surface and wind round the vortex's path, each its own
// width, radius, pace and twist (Vortex._ribbon_mesh); a few fine wisps run inside them. The look is
// all in this shader: soft, wispy edges, a brighter core, long streaks racing along the flow, and
// a luminous rim where a ribbon turns edge-on (aqua body, white foam, the connection's own tint).
// Everything else is as the jets were: the spiral revolves round the path (spin_phase; CUSTOM0 =
// path point and u, CUSTOM1 = path direction and ribbon index), the meandering current carries it
// (vortex_current.gdshaderinc), it grows out along u, and Hard Mode distress pulses it.
// UV.x = across the ribbon (0..1), UV.y = u along the connection (0 at A).

#include "res://shaders/vortex_current.gdshaderinc"
#include "res://shaders/vortex_distress.gdshaderinc"

uniform float grow = 0.0;          // visible fraction of the path (the spiral reaches out as it grows)
uniform float strength = 0.0;      // 0 a faint stir .. 1 a full hurricane
uniform float pulse = 0.0;
uniform float spin_phase = 0.0;
uniform float length_m = 40.0;
uniform float flow_speed = 9.0;
uniform float opacity = 1.0;
uniform vec3 deep : source_color = vec3(0.16, 0.62, 0.78);
uniform vec3 foam : source_color = vec3(0.9, 0.98, 1.0);
// The connection's own faint hue (Vortex.TINTS): the same at both ends, mostly in the bright water.
uniform vec3 tint : source_color = vec3(1.0);
uniform float tint_amt = 0.0;

varying float v_t;   // u along the connection (0 = ball A, 0.5 = midpoint, 1 = ball B)
varying float v_jet;

vec3 turn(vec3 v, vec3 k, float a) {
	// Rodrigues: v turned by a about the unit axis k.
	float c = cos(a);
	float s = sin(a);
	return v * c + cross(k, v) * s + k * dot(k, v) * (1.0 - c);
}

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

void vertex() {
	vec3 a = CUSTOM0.xyz;
	vec3 k = normalize(CUSTOM1.xyz);
	v_t = UV.y;
	v_jet = CUSTOM1.w;
	// The jets breathe a little as the water surges along them.
	vec3 rel = VERTEX - a;
	float surge = 1.0 + 0.06 * sin(UV.y * length_m * 0.9 - TIME * 5.0 + v_jet * 1.7);
	rel *= surge;
	VERTEX = a + turn(rel, k, spin_phase);
	vec3 nrm = turn(NORMAL, k, spin_phase);
	// The current: the ring moves with the centreline; its normal tilts with the bend (first order).
	float u = UV.y;
	vec3 d = current_offset(u);
	vec3 slope = (current_offset(min(u + 0.01, 1.0)) - current_offset(max(u - 0.01, 0.0))) / max(0.02 * length_m, 0.001);
	VERTEX += d;
	NORMAL = normalize(nrm - k * dot(nrm, slope));
}

void fragment() {
	float t = v_t;
	if (t > grow) {
		discard;
	}
	float tip = 1.0 - smoothstep(grow - 0.05, grow, t);
	float along = t * length_m;
	float x = UV.x;
	// Across the ribbon: soft, wispy edges (their width breathes along the flow), a brighter core.
	float e = 1.0 - abs(x * 2.0 - 1.0);
	float en = vnoise(vec2(along * 0.32 - TIME * flow_speed * 0.22, v_jet * 7.3));
	float soft = smoothstep(0.0, 0.5 + 0.35 * en, e);
	float core = e * e * e;
	// Water racing along the ribbon: long, stretched streaks in two layers.
	float n1 = vnoise(vec2(x * 2.6 + v_jet * 3.1, along * 0.22 - TIME * flow_speed * 0.32));
	float n2 = vnoise(vec2(x * 6.0 - v_jet * 1.3, along * 0.75 - TIME * flow_speed * 0.85));
	float streak = smoothstep(0.42, 0.88, n1 * 0.62 + n2 * 0.48);
	// Edge-on, a sheet of water shines (the luminous rims of the reference).
	float fres = pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 2.0);
	vec3 foam_t = mix(foam, tint, tint_amt);
	vec3 deep_t = mix(deep, deep * tint * 1.35, tint_amt * 0.7);
	vec3 ds = vec3(1.0, 0.0, 0.0);
	if (distress_any()) {
		// Hard Mode distress on this half (vortex_distress.gdshaderinc): the same hue, pulsing.
		ds = distress_at(t);
		foam_t = mix(foam, tint, tint_amt + ds.y) * ds.x;
		// (The deep body only brightens and darkens: a stronger tint there would turn its hue.)
		deep_t *= ds.x;
	}
	vec3 col = mix(deep_t, foam_t, clamp(0.22 + streak * 0.55 + fres * 0.55 + core * 0.3 + pulse * 0.3, 0.0, 1.0));
	// A touch over white in the brightest foam, so it glows a little with the scene's glow.
	col *= 1.0 + streak * 0.2 + streak * fres * 0.4;
	if (ds.z > 0.0) {
		col = mix(col, vec3(1.0), ds.z);
	}
	float end_fade = smoothstep(0.0, 0.015, t) * (1.0 - smoothstep(0.985, 1.0, t));
	float a = soft * (0.16 + streak * 0.32 + fres * 0.38 + core * 0.14) * (0.3 + strength * 0.7) * (1.0 + pulse * 0.5);
	ALBEDO = col;
	ALPHA = clamp(a * tip * end_fade * opacity, 0.0, 1.0);
}
