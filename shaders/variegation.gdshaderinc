// Variegated leaves (Expansion 6, owner reference: an earth star growing in their terrarium, and a
// "fire and ice" hosta): living leaves are not one flat green.
// x = across the leaf, 0 at the midrib .. 1 at the edge; t = base .. tip; ph = a per-plant phase.
// style 0 (earth star): a pink margin and cream stripes running the length of the leaf over green.
// style 1 (fire and ice): a white centre fading out to green margins, with a few pale streaks.
// Only on healthy leaves (the caller mixes this in by health), and softly toward the base.
vec3 variegate_leaf(vec3 green, float x, float t, float ph, float style, vec3 edge_col, vec3 stripe_col) {
	float along = smoothstep(0.03, 0.25, t);
	if (style < 0.5) {
		float edge = smoothstep(0.7, 0.9, x);
		float wav = sin(x * 26.0 + ph * 6.2832 + t * 2.0) * 0.5 + 0.5;
		float stripes = smoothstep(0.62, 0.9, wav) * (1.0 - edge) * along;
		vec3 c = mix(green, stripe_col, stripes * 0.8);
		// A second, thinner set of pale-green lines between the cream ones.
		c = mix(c, mix(green, stripe_col, 0.45), smoothstep(0.8, 0.95, sin(x * 61.0 + ph * 3.1) * 0.5 + 0.5) * 0.5 * (1.0 - edge));
		return mix(c, edge_col, edge * mix(0.55, 1.0, along));
	}
	float centre = 1.0 - smoothstep(0.28, 0.55, x + sin(t * 11.0 + ph * 6.2832) * 0.05);
	float streak = smoothstep(0.75, 0.95, sin(x * 34.0 + ph * 5.0) * 0.5 + 0.5) * (1.0 - centre) * 0.4;
	return mix(green, stripe_col, clamp(centre * along * 0.9 + streak * along, 0.0, 1.0));
}
