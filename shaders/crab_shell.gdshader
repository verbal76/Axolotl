shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
#include "res://shaders/creature_light.gdshaderinc"

// The crab guardian's carapace (Expansion 6, owner reference photo): a dark, wet, domed shell
// speckled with pale flecks and faint grooves, a red-orange rim band round its edge, and a pale
// cream underside. Object space: y = 0 at the rim, the dome above, the underside below.

uniform vec3 top_col : source_color = vec3(0.17, 0.11, 0.09);
uniform vec3 mid_col : source_color = vec3(0.36, 0.14, 0.08);
uniform vec3 rim_col : source_color = vec3(0.86, 0.24, 0.1);
uniform vec3 under_col : source_color = vec3(0.93, 0.8, 0.62);
uniform float dome = 0.26;
uniform float flash = 0.0;

varying vec3 v_obj;

void vertex() {
	v_obj = VERTEX;
}

float hash3(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.1, 0.2, 0.3));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

void fragment() {
	vec3 c;
	if (v_obj.y < -0.005) {
		c = under_col * mix(0.85, 1.0, hash3(floor(v_obj * 40.0)));
	} else {
		float h = clamp(v_obj.y / dome, 0.0, 1.0);
		c = mix(rim_col, mix(mid_col, top_col, smoothstep(0.25, 0.7, h)), smoothstep(0.04, 0.22, h));
		// Pale flecks.
		vec3 cell = floor(v_obj * 55.0);
		float f = step(0.9, hash3(cell));
		c = mix(c, vec3(0.86, 0.74, 0.56), f * 0.65 * smoothstep(0.1, 0.35, h));
		// Faint grooves: the H across the middle of a crab's back.
		float groove = 1.0 - smoothstep(0.0, 0.025, abs(abs(v_obj.x) - 0.17 - v_obj.z * 0.2));
		groove *= step(-0.25, v_obj.z) * step(v_obj.z, 0.2);
		c *= 1.0 - groove * 0.35 * h;
	}
	ALBEDO = c + vec3(flash * 0.4);
	ROUGHNESS = 0.32;
	SPECULAR = 0.55;
	// The tank's caustic light on him/it (creature_light).
	EMISSION += creature_caustics(ALBEDO, VERTEX, NORMAL, INV_VIEW_MATRIX);
}
