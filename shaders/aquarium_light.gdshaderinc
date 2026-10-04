// Mote's aquarium light (Expansion 6, docs/LIGHTING.md). The tank sits in a bedroom: the ceiling
// light falls through the rippling water surface, daylight comes through the side glass from the
// window. How much of it reaches the moss depends on how clear the water and glass are
// (`clarity`, the aquarium's restoration): murky and flat at first, clear and alive when healed.
// Shared by the terrain (moss), plant and vegetation materials; set per ball with the heal field.

// 0 = murky, neglected tank; 1 = clear (Aquarium.apply).
uniform float clarity = 0.0;
// Unit direction toward the ceiling light (where light enters through the surface).
uniform vec3 lamp_dir = vec3(0.29, 0.95, -0.1);

// The moving web of light the rippling surface focuses onto everything below it, projected along
// the lamp so it falls where the light does. Two drifting samples of the noise; where they nearly
// agree the light gathers into thin bright lines. Slow, like the water.
float caustic_web(sampler2D tex, vec3 p, float t) {
	vec2 uv = (p.xz - lamp_dir.xz / max(lamp_dir.y, 0.3) * p.y) * 0.3;
	float a = texture(tex, uv + vec2(t * 0.021, t * 0.014)).r;
	float b = texture(tex, uv * 1.37 + vec2(-t * 0.017, t * 0.023) + vec2(0.37, 0.61)).r;
	float w = clamp(1.0 - abs(a - b) * 6.0, 0.0, 1.0);
	return w * w * w;
}

// Caustic light on a surface of colour `alb` at `wpos` facing `wn`: where it faces the ceiling
// light, stronger nearer the surface and in clear water. `shade` (0..1) is how enclosed the point
// is (caves): enclosed places get none. (The window's daylight is a real light: Aquarium.)
vec3 aquarium_light(sampler2D tex, vec3 alb, vec3 wpos, vec3 wn, float shade, float t) {
	float open_ = 1.0 - shade;
	float facing = clamp(dot(wn, lamp_dir) * 0.8 + 0.2, 0.0, 1.0);
	float depth = smoothstep(-110.0, 150.0, wpos.y);
	float c = caustic_web(tex, wpos, t) * facing * open_ * mix(0.18, 1.0, clarity) * mix(0.55, 1.0, depth);
	return alb * c * vec3(0.85, 1.0, 0.95) * 0.95;
}
