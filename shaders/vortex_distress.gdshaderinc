// Hard Mode's remote distress on a vortex (ledger row 12; docs/research/2026-09-30-DEVICE_AUDIT.md §E2,
// owner rulings J-M). Each half of a connection signals for the sphere at its own end: the half from
// the midpoint to end A for sphere A, the other for sphere B, independently, through the stable u
// along the connection (0 = ball A, 0.5 = midpoint, 1 = ball B; the A pool, eye and debris are A's).
// The connection keeps its own hue: the tinted water pulses between darker and brighter versions of it
// (gain 1 +/- the level's luminance swing), the hue a little stronger per level in the foam (the deep
// body only brightens and darkens, so its hue never turns), and at S3 at most a
// 20 % lift toward white at the pulse's crest. Set by Vortex from HardMode; Normal leaves every value
// at zero and the shaders skip all of it (distress_any() is false).
uniform vec2 distress_a = vec2(0.0, 6.0);   // end A's half: (luminance swing, pulse period in s)
uniform vec2 distress_b = vec2(0.0, 6.0);   // end B's half
// Pulse phase of A and B (radians: Vortex advances them by 2 pi dt / period, from the link's own
// phase, so a period that crossfades never jumps), tint amount of A and B (0.50 = today's).
uniform vec4 distress_x = vec4(0.0, 0.0, 0.5, 0.5);

bool distress_any() {
	return distress_a.x > 0.0 || distress_b.x > 0.0;
}

// At u: x = brightness gain on the tinted water, y = extra tint amount, z = lift toward white.
vec3 distress_at(float u) {
	float mb = smoothstep(0.45, 0.55, u);
	float ma = 1.0 - mb;
	float pa = sin(distress_x.x);
	float pb = sin(distress_x.y);
	float gain = 1.0 + ma * distress_a.x * pa + mb * distress_b.x * pb;
	float more = ma * (distress_a.x > 0.0 ? max(distress_x.z - 0.5, 0.0) : 0.0) + mb * (distress_b.x > 0.0 ? max(distress_x.w - 0.5, 0.0) : 0.0);
	float white = 0.2 * (ma * smoothstep(0.25, 0.4, distress_a.x) * (0.5 + 0.5 * pa) + mb * smoothstep(0.25, 0.4, distress_b.x) * (0.5 + 0.5 * pb));
	return vec3(gain, more, white);
}
