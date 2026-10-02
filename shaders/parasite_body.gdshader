shader_type spatial;
render_mode diffuse_lambert;
#include "res://shaders/creature_light.gdshaderinc"

// Parasite body (Expansion 6): one continuous, flexible, tapering body instead of a chain of
// beads. A shared tube mesh (UV.x round the body, UV.y head to tail with rounded caps beyond both
// ends) is laid along a smooth curve through the creature's segment points, which it sends every
// frame (`pts`: position + radius, `ups`: each segment's up). Faint rings along the body keep it
// a segmented worm. Colour as shaders/parasite.gdshader (stolen vitality, draining head to rear
// with damage), with t = UV.y in place of the per-segment seg_t.

uniform vec4 pts[12];
uniform vec4 ups[12];
uniform int npts = 3;
uniform float cap = 0.12;
uniform float gray_front = 0.0;
uniform vec3 color_a : source_color = vec3(0.95, 0.2, 0.6);
uniform vec3 color_b : source_color = vec3(1.0, 0.6, 0.1);
uniform vec3 spot : source_color = vec3(0.4, 1.0, 0.3);
uniform float flash = 0.0;
uniform float windup = 0.0;
// Where the markings start in the noise (lower: more of the body marked).
uniform float spot_lo = 0.62;
// Self-glow of stolen vitality (parasites); low for creatures that do not glow.
uniform float glow_gain = 1.0;
// Parasites only (owner 2026-10-01: "a smooth leech", not beads): no rings, a flatter body, soft
// lengthwise markings and a dorsal stripe instead of blotches, a wetter sheen.
uniform float leech = 0.0;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;

varying float v_t;

vec3 P(int i) {
	int n = npts;
	if (i < 0) {
		return pts[0].xyz * 2.0 - pts[1].xyz;
	}
	if (i > n - 1) {
		return pts[n - 1].xyz * 2.0 - pts[n - 2].xyz;
	}
	return pts[i].xyz;
}

void vertex() {
	float s = UV.y * (1.0 + 2.0 * cap) - cap;
	float t = clamp(s, 0.0, 1.0);
	float over = (s < 0.0 ? -s : max(s - 1.0, 0.0)) / cap;
	float f = t * float(npts - 1);
	int i = min(int(floor(f)), npts - 2);
	float u = f - float(i);
	vec3 p0 = P(i - 1);
	vec3 p1 = P(i);
	vec3 p2 = P(i + 1);
	vec3 p3 = P(i + 2);
	// Catmull-Rom through the segment points, and its direction.
	float u2 = u * u;
	float u3 = u2 * u;
	vec3 pos = 0.5 * ((2.0 * p1) + (-p0 + p2) * u + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * u2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * u3);
	vec3 tan = 0.5 * ((-p0 + p2) + 2.0 * (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * u + 3.0 * (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * u2);
	tan = length(tan) > 0.00001 ? normalize(tan) : vec3(0.0, 0.0, 1.0);
	vec3 up = normalize(mix(ups[i].xyz, ups[i + 1].xyz, u));
	vec3 side = cross(tan, up);
	side = length(side) > 0.00001 ? normalize(side) : vec3(1.0, 0.0, 0.0);
	vec3 up2 = normalize(cross(side, tan));
	float r = mix(pts[i].w, pts[i + 1].w, smoothstep(0.0, 1.0, u));
	// Faint rings between segments (a soft segmented worm, never beads).
	r *= 1.0 + 0.06 * (1.0 - leech) * cos(f * 6.2832);
	// Rounded head beyond the first point, a longer pointed tail beyond the last.
	if (s < 0.0) {
		pos -= tan * over * r * 1.05;
		r *= sqrt(max(1.0 - over * over, 0.0));
	} else if (s > 1.0) {
		pos += tan * over * r * 1.6;
		r *= 1.0 - over;
	}
	float a = UV.x * 6.2832;
	// A slightly flattened belly.
	vec3 off = side * cos(a) * mix(1.0, 1.12, leech) + up2 * sin(a) * (sin(a) < 0.0 ? mix(0.72, 0.42, leech) : mix(0.9, 0.62, leech));
	vec3 wp = pos + off * r;
	VERTEX = wp - MODEL_MATRIX[3].xyz;
	NORMAL = normalize(side * cos(a) + up2 * sin(a));
	v_t = t;
}

void fragment() {
	float n = texture(noise_tex, UV * mix(vec2(3.0, 5.0), vec2(5.0, 2.0), leech)).r;
	vec3 vivid = mix(color_a, color_b, v_t);
	float spots = smoothstep(spot_lo, spot_lo + 0.08, n) * mix(1.0, 0.45, leech);
	float stripe = leech * (1.0 - smoothstep(0.025, 0.07, abs(UV.x - 0.25)));
	vivid = mix(vivid, spot, max(spots * 0.6, stripe * 0.55));
	// Darker along the back ridge and between the rings, paler underneath.
	vivid *= mix(1.08, 0.84, sin(UV.x * 6.2832) * 0.5 + 0.5);
	float lum = dot(vivid, vec3(0.3, 0.55, 0.15));
	vec3 grey = vec3(lum * 0.6 + 0.18) * vec3(0.95, 0.95, 0.92);
	float g = 1.0 - smoothstep(gray_front - 0.001, gray_front + 0.001, v_t);
	g = gray_front >= 0.999 ? 1.0 : g;
	vec3 col = mix(vivid, grey, g);
	ALBEDO = col + vec3(flash);
	ROUGHNESS = mix(mix(0.45, 0.3, leech), 0.9, g);
	float glow = (1.0 - g) * (0.25 + spots * 0.8 + windup * 1.5) * glow_gain;
	EMISSION = vivid * glow + vec3(flash * 0.8);
	// The tank's caustic light on him/it (creature_light).
	EMISSION += creature_caustics(ALBEDO, VERTEX, NORMAL, INV_VIEW_MATRIX);
}
