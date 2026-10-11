// Mote's one light model (owner, 2026-10-11: "all the assets need to fit the same style and level
// of polish"). Every world and creature material includes this instead of the engine's default
// lighting, so moss, stone, plants, Gill and the creatures turn from light to shade the same way:
// a soft wrapped terminator on a smooth S-curve (clean, sculpted gradients, no harsh black side),
// a gentle rim where the light grazes the silhouette, and one restrained highlight.
// Set before the include: MOTE_SHADE_TWO_SIDED for thin cards and blades (lit from either side),
// MOTE_SHADE_SPEC to the highlight strength (undefined = none), MOTE_SHADE_RIM to the rim strength.

#ifndef MOTE_SHADE_RIM
#define MOTE_SHADE_RIM 0.18
#endif

void light() {
	float ndl = dot(NORMAL, LIGHT);
#ifdef MOTE_SHADE_TWO_SIDED
	ndl = abs(ndl) * 0.85;
#endif
	// Wrapped (the shade side keeps a little light) and eased: a smooth, sculpted turn.
	float wrap = clamp((ndl + 0.3) / 1.3, 0.0, 1.0);
	float ramp = wrap * wrap * (3.0 - 2.0 * wrap);
	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * ramp / PI;
	// Rim: the silhouette catches the light it faces, which separates shapes from the background.
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * fres * smoothstep(-0.2, 0.6, ndl) * MOTE_SHADE_RIM / PI;
#ifdef MOTE_SHADE_SPEC
	vec3 hv = normalize(LIGHT + VIEW);
	float s = pow(clamp(dot(NORMAL, hv), 0.0, 1.0), 40.0);
	SPECULAR_LIGHT += LIGHT_COLOR * ATTENUATION * smoothstep(0.2, 0.6, s) * MOTE_SHADE_SPEC;
#endif
}
