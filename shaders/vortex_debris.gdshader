shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

// Sand, bits of moss and bubbles caught in the vortex (Expansion 6): each fleck is a tiny billboard
// in a MultiMesh at the mouth's origin (y = up), orbiting inward and rising into the jets, on a loop.
// INSTANCE_CUSTOM: x = phase, y = start radius, z = rise speed, w = size. COLOR = its colour.

uniform float strength = 0.0;
uniform float spin_phase = 0.0;
uniform float rise = 6.0;

varying float v_life;
varying vec2 v_uv;

void vertex() {
	float ph = INSTANCE_CUSTOM.x;
	float life = fract(TIME * INSTANCE_CUSTOM.z + ph);
	v_life = life;
	v_uv = UV;
	float r = INSTANCE_CUSTOM.y * (1.0 - life * 0.65);
	float a = ph * 6.2832 + life * 7.0 + spin_phase * 1.4;
	vec3 centre = vec3(cos(a) * r, life * life * rise + 0.08, sin(a) * r);
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
	ALBEDO = COLOR.rgb;
	ALPHA = (1.0 - smoothstep(0.5, 1.0, d)) * fade * COLOR.a * strength;
}
