shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_disabled;
#include "res://shaders/creature_light.gdshaderinc"

// Pufferfish (Expansion 6, owner reference photos): one mesh with two shapes. Calm, it is an
// elongated porcupinefish with fins and flat-lying spines (VERTEX, NORMAL); puffed, every body
// point moves out onto the full sphere, the fins ride along on it and the spines stand straight
// out (CUSTOM0 = puffed position, CUSTOM1 = puffed normal). `inflate` morphs between them.
// COLOR.rgb is the part's colour; COLOR.a > 0.5 marks spotted skin.

uniform float inflate = 0.0;
uniform vec3 spot_col : source_color = vec3(0.16, 0.12, 0.08);

varying vec3 v_calm;
varying float v_spot;

void vertex() {
	v_calm = VERTEX;
	float k = smoothstep(0.0, 1.0, inflate);
	VERTEX = mix(VERTEX, CUSTOM0.xyz, k);
	NORMAL = normalize(mix(NORMAL, CUSTOM1.xyz, k));
	v_spot = COLOR.a;
}

float hash3(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.1, 0.2, 0.3));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

void fragment() {
	vec3 c = COLOR.rgb;
	if (v_spot > 0.5) {
		vec3 p = v_calm * 24.0;
		vec3 f = fract(p) - 0.5;
		float h = hash3(floor(p));
		float dot_ = step(h, 0.55) * (1.0 - smoothstep(0.2, 0.34, length(f)));
		c = mix(c, spot_col, dot_ * 0.85);
	}
	// Puffed up, it pales and yellows (the warning).
	c = mix(c, c * vec3(1.12, 1.06, 0.72), inflate * 0.5);
	ALBEDO = c;
	ROUGHNESS = 0.5;
	SPECULAR = 0.4;
	// The tank's caustic light on him/it (creature_light).
	EMISSION += creature_caustics(ALBEDO, VERTEX, NORMAL, INV_VIEW_MATRIX);
}
