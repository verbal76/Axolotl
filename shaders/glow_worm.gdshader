shader_type spatial;
render_mode unshaded, cull_disabled;
// Cave glow-worms (scripts/actors/critters/glow_worms.gd): each instance is a silk thread hanging
// from the ceiling with a bead of light. Near the axolotl a worm dims and draws its thread up.

uniform vec3 player_pos = vec3(1e6);
uniform vec4 glow : source_color = vec4(0.45, 1.0, 0.85, 1.0);

varying float k;
varying float bead;

void vertex() {
	vec3 origin = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	k = smoothstep(1.3, 3.2, distance(origin, player_pos));
	// Thread drawn up to a quarter of its length when he is close.
	VERTEX.y *= mix(0.25, 1.0, k);
	bead = COLOR.r;
}

void fragment() {
	float b = step(0.5, bead);
	// Unshaded: the colour is the light. The bead glows, dimming near the axolotl; the thread is
	// faint silk.
	ALBEDO = mix(vec3(0.35, 0.45, 0.42), glow.rgb * mix(0.25, 1.8, k), b);
}
