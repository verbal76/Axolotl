// The moving web of light the rippling water surface focuses onto everything below it (owner,
// 2026-10-02: like sunlight on a sandy bottom, plainly moving). Projected along the lamp so it falls
// where the light does. Two drifting layers at different scales; where two drifting samples nearly
// agree the light gathers into thin bright lines with a soft glow round them.
float caustic_layer(sampler2D tex, vec2 uv, float t) {
	float a = texture(tex, uv + vec2(t * 0.055, t * 0.038)).r;
	float b = texture(tex, uv * 1.37 + vec2(-t * 0.046, t * 0.061) + vec2(0.37, 0.61)).r;
	float d = abs(a - b);
	float line = clamp(1.0 - d * 7.0, 0.0, 1.0);
	return line * line * line + 0.25 * clamp(1.0 - d * 2.5, 0.0, 1.0);
}

float caustic_web(sampler2D tex, vec3 p, float t, vec3 lamp) {
	vec2 uv = (p.xz - lamp.xz / max(lamp.y, 0.3) * p.y) * 0.3;
	return caustic_layer(tex, uv, t) * 0.75 + caustic_layer(tex, uv * 1.9 + vec2(0.21, 0.47), t * 1.3) * 0.4;
}
