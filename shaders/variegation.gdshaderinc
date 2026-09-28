// Variegated leaves (Expansion 6, owner reference: an earth star growing in their terrarium, and a
// "fire and ice" hosta): living leaves are not one flat green.
// x = across the leaf, 0 at the midrib .. 1 at the edge; t = base .. tip; ph = a per-plant phase.
// style 0 (earth star): a pink margin and cream stripes running the length of the leaf over green.
// style 1 (fire and ice): a white centre fading out to green margins, with a few pale streaks.
// Only on healthy leaves (the caller mixes this in by health), and softly toward the base.
vec3 variegate_leaf(vec3 green, float x, float t, float ph, float style, vec3 edge_col, vec3 stripe_col) {
	float along = smoothstep(0.03, 0.25, t);
	if (style < 0.5) {
		float edge = smoothstep(0.72, 0.92, x);
		// Few, soft, wavering stripes along the leaf (not candy-cane regular), over a pink blush.
		float xw = x + sin(t * 7.0 + ph * 6.2832) * 0.05;
		float wav = sin(xw * 15.0 + ph * 6.2832) * 0.5 + 0.5;
		float stripes = smoothstep(0.55, 0.95, wav) * (1.0 - edge) * along;
		vec3 c = mix(green, mix(stripe_col, edge_col, 0.18), stripes * 0.6);
		c = mix(c, edge_col, 0.14 * along * (1.0 - edge));
		return mix(c, edge_col, edge * mix(0.5, 0.95, along));
	}
	float centre = 1.0 - smoothstep(0.28, 0.55, x + sin(t * 11.0 + ph * 6.2832) * 0.05);
	float streak = smoothstep(0.75, 0.95, sin(x * 34.0 + ph * 5.0) * 0.5 + 0.5) * (1.0 - centre) * 0.4;
	return mix(green, stripe_col, clamp(centre * along * 0.9 + streak * along, 0.0, 1.0));
}
