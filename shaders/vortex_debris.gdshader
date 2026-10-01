shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

// Sand, bits of moss and bubbles caught in the vortex (Expansion 6): each fleck is a tiny billboard
// in a MultiMesh at the mouth's origin (y = up), orbiting inward and rising into the jets, on a loop.
// INSTANCE_CUSTOM: x = phase, y = start radius, z = rise speed, w = size. COLOR = its colour.
// Vortex currents (ledger row 14): as a fleck rises into the jets it is carried by the current's
// offset at its height (u from the mouth: u_end = 0 at ball A, 1 at ball B; cur_basis in mouth space).

#include "res://shaders/vortex_current.gdshaderinc"

uniform float strength = 0.0;
uniform float spin_phase = 0.0;
uniform float rise = 6.0;
uniform vec3 tint : source_color = vec3(1.0);
uniform float tint_amt = 0.0;
uniform float u_end = 0.0;
uniform float length_m = 40.0;

varying float v_life;
varying float v_u;   // u along the connection (0 = ball A, 0.5 = midpoint, 1 = ball B)
varying vec2 v_uv;

void vertex() {
	float ph = INSTANCE_CUSTOM.x;
	float life = fract(TIME * INSTANCE_CUSTOM.z + ph);
	v_life = life;
	v_uv = UV;
	float r = INSTANCE_CUSTOM.y * (1.0 - life * 0.65);
	float a = ph * 6.2832 + life * 7.0 + spin_phase * 1.4;
	vec3 centre = vec3(cos(a) * r, life * life * rise + 0.08, sin(a) * r);
	float ul = clamp(centre.y / max(length_m, 1.0), 0.0, 0.5);
	v_u = mix(ul, 1.0 - ul, u_end);
	centre += current_offset(v_u);
	// Face the camera.
	vec3 cam_r = (inverse(MODELVIEW_MATRIX) * vec4(1.0, 0.0, 0.0, 0.0)).xyz;
	vec3 cam_u = (inverse(MODELVIEW_MATRIX) * vec4(0.0, 1.0, 0.0, 0.0)).xyz;
	float s = INSTANCE_CUSTOM.w * strength;
	VERTEX = centre + (cam_r * VERTEX.x + cam_u * VERTEX.y) * s;
}

void fragment() {
	float d = length(v_uv - 0.5) * 2.0;
	if (d > 1.0) {
		discard;
	}
	float fade = smoothstep(0.0, 0.1, v_life) * (1.0 - smoothstep(0.75, 1.0, v_life));
	ALBEDO = mix(COLOR.rgb, COLOR.rgb * tint * 1.2, tint_amt * 0.6);
	ALPHA = (1.0 - smoothstep(0.5, 1.0, d)) * fade * COLOR.a * strength;
}
