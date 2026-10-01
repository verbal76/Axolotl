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

// Golden pothos (00040-plants, ledger row 15; owner reference photo of a variegated golden pothos),
// for the platform leaves (MeshLib._leaf_into: UV.x = 0.5 at the midrib, its offset the fraction of
// the leaf's half-width times MeshLib.leaf_profile(t); UV.y = t, base to tip). A lively mid-green;
// cream-to-yellow streaks that start at a pale midrib and run outward and forward along the
// lateral veins, broken and irregular, more near the midrib; paler edges in places. `ph` (0..1) is
// the leaf's own phase: how variegated it is and where its streaks fall, so no two leaves match.
// Returns the colour and, in .a, how much sheen (the waxy green more than the matte cream).
float pothos_profile(float t) {
	float tc = clamp(t, 0.0, 1.0);
	float neck = 0.22 + 0.78 * smoothstep(0.0, 0.2, tc);
	return neck * pow(sin(3.14159 * tc), 0.42) * (1.0 - 0.12 * tc);
}

vec4 pothos_leaf(sampler2D tex, vec2 uv, float ph, vec3 green, vec3 cream, vec3 yellow) {
	float t = uv.y;
	float xs = (uv.x - 0.5) * 2.0;
	float xn = clamp(abs(xs) / max(pothos_profile(t), 0.06), 0.0, 1.0);
	float sg = xs < 0.0 ? 0.0 : 1.0;
	// Lateral veins leave the midrib and curve forward toward the tip.
	float u = t - 0.3 * pow(xn, 1.25);
	vec2 o = vec2(ph * 3.17 + sg * 0.41, ph * 1.93 + sg * 0.29);
	// Streaks: fast across the veins, slow along them; ragged edges from a finer sample.
	float ns = texture(tex, vec2(u * 1.9, xn * 0.38) + o).g;
	float nf = texture(tex, vec2(u * 6.5, xn * 1.6) + o * 1.7).r;
	float amount = mix(-0.07, 0.08, fract(ph * 5.31));
	float thr = mix(0.5, 0.66, xn) - amount;
	float streak = smoothstep(thr, thr + 0.06, ns + (nf - 0.5) * 0.24);
	// The pale midrib, strongest toward the base; the leaf's stalk end stays green.
	float rib = (1.0 - smoothstep(0.035, 0.1, xn)) * mix(0.85, 0.45, t);
	// Paler edges in places along the margin.
	float edge = smoothstep(0.8, 0.98, xn) * smoothstep(0.5, 0.72, texture(tex, vec2(t * 1.7 + ph * 2.3, sg * 0.5 + ph)).b) * 0.55;
	float along = smoothstep(0.02, 0.1, t) * (1.0 - smoothstep(0.93, 1.0, t) * 0.5);
	vec3 pale = mix(cream, yellow, smoothstep(0.3, 0.75, texture(tex, vec2(u * 1.3, xn * 0.4) - o).b));
	// The green itself varies a little, darker along the veins.
	float vein = 1.0 - smoothstep(0.0, 0.08, abs(fract(u * 8.0 + ph) - 0.5) - 0.38);
	vec3 g = green * mix(0.86, 1.1, nf) * (1.0 - 0.08 * vein);
	vec3 c = mix(g, pale, clamp(streak * 0.92 + rib, 0.0, 1.0) * along);
	c = mix(c, mix(green * 1.35, cream, 0.35), edge * along);
	return vec4(c, (1.0 - streak * 0.6) * along);
}
