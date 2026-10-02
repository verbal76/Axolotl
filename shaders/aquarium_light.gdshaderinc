// Mote's aquarium light (Expansion 6, docs/LIGHTING.md). The tank sits in a bedroom: the ceiling
// light falls through the rippling water surface, daylight comes through the side glass from the
// window. How much of it reaches the moss depends on how clear the water and glass are
// (`clarity`, the aquarium's restoration): murky and flat at first, clear and alive when healed.
// Shared by the terrain (moss), plant and vegetation materials; set per ball with the heal field.

// 0 = murky, neglected tank; 1 = clear (Aquarium.apply).
uniform float clarity = 0.0;
// Unit direction toward the ceiling light (where light enters through the surface).
uniform vec3 lamp_dir = vec3(0.29, 0.95, -0.1);

#include "res://shaders/caustic_web.gdshaderinc"

// Caustic light on a surface of colour `alb` at `wpos` facing `wn`: where it faces the ceiling
// light, stronger nearer the surface and in clear water. `shade` (0..1) is how enclosed the point
// is (caves): enclosed places get none. (The window's daylight is a real light: Aquarium.)
vec3 aquarium_light(sampler2D tex, vec3 alb, vec3 wpos, vec3 wn, float shade, float t) {
	float open_ = 1.0 - shade;
	// (Only where the light falls onto the surface: steep sides it merely grazes would smear the
	// projected web into streaks.)
	float facing = smoothstep(0.45, 0.9, dot(wn, lamp_dir));
	float depth = smoothstep(-110.0, 150.0, wpos.y);
	float c = caustic_web(tex, wpos, t, lamp_dir) * facing * open_ * mix(0.18, 1.0, clarity) * mix(0.55, 1.0, depth);
	// (Light, not paint: mostly the light's own pale colour, a little of the surface's, like sun on sand.)
	return (alb * 0.45 + vec3(0.5, 0.6, 0.55)) * c * 1.05;
}
