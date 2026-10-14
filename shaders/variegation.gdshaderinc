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

float pothos_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Driven by leaf space, not isotropic noise: xn = distance from the midrib (0) to the margin (1);
// u = t - k * xn^1.3 is constant along each lateral vein (they leave the midrib and curve toward
// the tip), so the leaf splits into vein bands. Each band (per side) draws its own cream streak:
// it starts at the midrib and reaches its own distance out, narrowing as it goes, split into a few
// fine feathers that run along the vein and break into long dashes; most cream near the midrib.
vec4 pothos_leaf(sampler2D tex, vec2 uv, float ph, vec3 green, vec3 cream, vec3 yellow) {
	float t = uv.y;
	float xs = (uv.x - 0.5) * 2.0;
	float xn = clamp(abs(xs) / max(pothos_profile(t), 0.06), 0.0, 1.0);
	float sg = xs < 0.0 ? 0.0 : 1.0;
	float u = t - 0.42 * pow(xn, 1.3);
	// Vein bands: about seven per side, offset per leaf and per side.
	// (Warped a little so the bands are uneven, never a fishbone.)
	float warp = texture(tex, vec2(u * 0.9 + sg * 0.37, xn * 0.45) + vec2(ph * 2.1, ph * 1.3)).g - 0.5;
	float v = u * 7.0 + ph * 3.7 + sg * 0.53 + warp * 1.4;
	float vi = floor(v);
	float d = abs(fract(v) - 0.5) * 2.0;
	vec2 key = vec2(vi + sg * 31.0, floor(ph * 97.0));
	float r1 = pothos_hash(key);
	float r2 = pothos_hash(key + vec2(3.1, 1.7));
	float r3 = pothos_hash(key + vec2(7.7, 5.3));
	// How variegated this leaf is, and how far out this band's streak reaches.
	float leaf_amt = mix(0.7, 1.2, fract(ph * 5.31));
	float reach = mix(0.25, 1.05, r1) * leaf_amt;
	float taper = clamp(1.0 - xn / max(reach, 0.05), 0.0, 1.0);
	// The band's streak: wide at the midrib, narrowing outward, centred off the vein a little.
	float wv = mix(0.3, 0.85, r2) * pow(taper, 0.6);
	// Ragged, feathered edges from a fine sample running along the vein.
	float rag = texture(tex, vec2(xn * 4.3 + r3 * 5.0, v * 0.61)).r - 0.5;
	float band = 1.0 - smoothstep(wv - 0.3, wv + 0.1, abs(d - mix(0.0, 0.5, r3) * (1.0 - taper)) + rag * 0.45);
	// Feathers: fine parallel strands along the vein, and long breaks along it.
	float fe = abs(fract(v * 3.0 + r3 * 2.0) - 0.5) * 2.0;
	float strand = 1.0 - smoothstep(0.35, 0.95, fe);
	float brk = texture(tex, vec2(xn * 1.6 + r2 * 3.0, vi * 0.137 + sg * 0.31 + ph)).r;
	float dash = smoothstep(0.25, 0.55, brk + taper * 0.35);
	float streak = band * mix(1.0, strand, 0.5 * (1.0 - taper * 0.6)) * dash * step(0.1, r1);
	// Fine flecks out toward the margin, along the veins too.
	float fleck = (1.0 - smoothstep(0.08, 0.2, abs(fract(v * 2.0 + r2) - 0.5) + rag * 0.3)) * smoothstep(0.62, 0.78, brk) * smoothstep(0.2, 0.5, xn);
	streak = max(streak, fleck * 0.85);
	// The pale midrib, strongest toward the base; the leaf's stalk end stays green.
	float rib = (1.0 - smoothstep(0.03, 0.09, xn)) * mix(0.9, 0.5, t);
	// Paler edge patches in places along the margin.
	float edge = smoothstep(0.82, 0.98, xn) * smoothstep(0.55, 0.75, texture(tex, vec2(t * 1.7 + ph * 2.3, sg * 0.5 + ph)).b) * 0.5;
	float along = smoothstep(0.02, 0.1, t) * (1.0 - smoothstep(0.93, 1.0, t) * 0.5);
	// Creamier near the midrib, more yellow toward the ends of the streaks.
	vec3 pale = mix(cream, yellow, clamp(0.35 + xn * 0.9 + (r2 - 0.5) * 0.4, 0.0, 1.0));
	// The green varies gently, a touch darker along the veins.
	float vein = 1.0 - smoothstep(0.0, 0.1, d - 0.85);
	vec3 g = green * mix(0.9, 1.08, brk) * (1.0 - 0.07 * vein);
	vec3 c = mix(g, pale, clamp(streak * 0.85 + rib, 0.0, 1.0) * along);
	c = mix(c, mix(green * 1.35, cream, 0.35), edge * along);
	return vec4(c, (1.0 - streak * 0.6) * along);
}
