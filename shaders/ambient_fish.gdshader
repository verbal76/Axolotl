shader_type spatial;
// Ambient aquarium fish (scripts/world/ambient_fish.gd): vertex colour carries the pattern; UV.x runs
// from the snout (0) to the tail tip (1+) and drives a travelling side-to-side swimming wave that
// grows toward the tail. `swim` (0.2..2.5) is how hard it is swimming; `phase` desynchronises fish.
render_mode cull_disabled;

instance uniform float phase = 0.0;
instance uniform float wag = 5.0;
instance uniform float swim = 1.0;
// Half the body length (m): the wave scales with the fish.
instance uniform float size = 1.0;

void vertex() {
	float u = UV.x;
	// Body length along local Z: the wave's size scales with it (the mesh is built per kind).
	float amp = (0.015 + 0.14 * smoothstep(0.15, 1.1, u) * u) * (0.35 + 0.45 * swim);
	float w = sin(TIME * wag * (0.6 + 0.5 * swim) + phase - u * 5.0);
	VERTEX.x += w * amp * size;
}

// Seen from the room the fish are drawn larger (AmbientFish.display_scale) and read through murky
// water: a touch more colour and a little self-light keep them fish, not grey specks.
instance uniform float pop = 0.0;

void fragment() {
	vec3 c = COLOR.rgb;
	float l = dot(c, vec3(0.3, 0.59, 0.11));
	c = mix(vec3(l), c, 1.0 + 0.35 * pop);
	ALBEDO = c;
	EMISSION = c * 0.22 * pop;
	ROUGHNESS = 0.55;
	SPECULAR = 0.35 + 0.2 * pop;
	RIM = 0.35 + 0.3 * pop;
	RIM_TINT = 0.4;
}
