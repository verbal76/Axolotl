shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;

// Suspended aquarium particulate. Positions wrap in a box around the camera so the cloud is
// infinite but stable in world space. Local impulses push particles; nearby Motes light them.

uniform vec3 box = vec3(36.0, 36.0, 36.0);
uniform vec3 cam_pos = vec3(0.0);
uniform vec3 flow = vec3(0.0);
uniform float murk = 1.0;
uniform float size = 0.05;
uniform vec3 tint : source_color = vec3(0.75, 0.8, 0.62);
uniform vec4 impulses[8];
uniform vec4 motes[6];
uniform int mote_count = 0;
uniform vec3 mote_color : source_color = vec3(0.55, 1.0, 0.75);
uniform vec3 water_color : source_color = vec3(0.2, 0.35, 0.3);

varying float v_alpha;
varying vec3 v_col;

void vertex() {
	vec3 seed = MODEL_MATRIX[3].xyz;   // 0..1 per instance
	vec3 drift = vec3(sin(seed.x * 40.0 + TIME * 0.3), sin(seed.y * 31.0 + TIME * 0.23), sin(seed.z * 27.0 + TIME * 0.27)) * 0.6;
	vec3 p = seed * box + flow * TIME + drift - cam_pos + box * 0.5;
	p = mod(p, box) - box * 0.5;
	vec3 wp = p + cam_pos;
	for (int i = 0; i < 8; i++) {
		vec4 im = impulses[i];
		if (im.w <= 0.0) continue;
		vec3 d = wp - im.xyz;
		float dist = length(d);
		wp += (d / max(dist, 0.05)) * im.w * 0.9 / (1.0 + dist * dist * 0.6);
	}
	vec3 glow = vec3(0.0);
	for (int i = 0; i < mote_count; i++) {
		vec3 d = wp - motes[i].xyz;
		glow += mote_color * motes[i].w * 2.5 / (1.0 + dot(d, d) * 1.5);
	}
	float edge = 1.0 - smoothstep(0.35, 0.5, max(max(abs(p.x) / box.x, abs(p.y) / box.y), abs(p.z) / box.z));
	float d_cam = length(p);
	v_alpha = edge * smoothstep(0.3, 1.2, d_cam) * mix(0.25, 0.75, murk) * (0.6 + seed.x * 0.4);
	v_col = mix(tint, water_color, clamp(d_cam / 25.0, 0.0, 1.0)) + glow;
	vec4 vp = VIEW_MATRIX * vec4(wp, 1.0);
	float sz = size * (0.6 + seed.y * 0.8) * (1.0 + murk * 0.6);
	vp.xy += VERTEX.xy * sz;
	POSITION = PROJECTION_MATRIX * vp;
}

void fragment() {
	float d = length(UV - vec2(0.5)) * 2.0;
	ALBEDO = v_col;
	ALPHA = v_alpha * (1.0 - smoothstep(0.3, 1.0, d));
}
