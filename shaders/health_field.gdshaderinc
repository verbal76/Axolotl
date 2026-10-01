// Shared moss-ball "health field": 0 = parasite-damaged grey moss, 1 = lush. Restoration that has
// settled lives in the ball's health map (an equirectangular texture painted by MossBall, world
// expansion: no limit on how much can heal); splats still growing in (direction from the ball's
// centre + angular radius in radians) are added on top until they settle into it.
uniform sampler2D health_map : hint_default_black, filter_linear, repeat_enable;
uniform vec4 heals[64];
uniform int heal_count = 0;
uniform vec3 ball_center = vec3(0.0);
// Onboarding's first-parasite lesson (docs/ONBOARDING.md): PRESENTATION ONLY. The health above is
// already the true, settled result; inside stage_outer (radians round stage_dir) and beyond the
// reveal front stage_reveal, the moss is still drawn as it looked before the kill (health_base, a
// snapshot), so the restoration is seen spreading outward. stage_outer <= 0: off.
uniform sampler2D health_base : hint_default_black, filter_linear, repeat_enable;
uniform vec3 stage_dir = vec3(0.0, 1.0, 0.0);
uniform float stage_reveal = 0.0;
uniform float stage_outer = 0.0;
// Hard Mode (ledger row 12): each zone's vitality V (a 64x32 map painted by MossBall from HardMode) dims
// the drawn health to health x mix(0.35, 1, V). The permanent health map is never changed. Off (Normal):
// not sampled at all.
uniform sampler2D vitality_map : hint_default_white, filter_linear, repeat_enable;
uniform bool vitality_on = false;

vec2 health_uv(vec3 dir) {
	return vec2(atan(dir.x, dir.z) / 6.2831853 + 0.5, 0.5 - asin(clamp(dir.y, -1.0, 1.0)) / 3.1415927);
}

float health_at(vec3 dir) {
	float h = texture(health_map, health_uv(dir)).r;
	for (int i = 0; i < heal_count; i++) {
		vec4 s = heals[i];
		float ang = acos(clamp(dot(dir, s.xyz), -1.0, 1.0));
		h = max(h, 1.0 - smoothstep(s.w * 0.55, s.w, ang));
	}
	if (stage_outer > 0.0) {
		float a = acos(clamp(dot(dir, stage_dir), -1.0, 1.0));
		if (a < stage_outer) {
			// 0 inside the restored front, 1 ahead of it (a soft edge about 2.5 degrees wide).
			float ahead = smoothstep(stage_reveal - 0.045, stage_reveal, a);
			h = mix(h, min(h, texture(health_base, health_uv(dir)).r), ahead);
		}
	}
	if (vitality_on) {
		h *= mix(0.35, 1.0, texture(vitality_map, health_uv(dir)).r);
	}
	return h;
}

// Local water impulses (axolotl movement, tail swipes, landings): xyz = world pos, w = strength.
uniform vec4 impulses[8];

vec3 impulse_push(vec3 wpos, vec3 up) {
	vec3 push = vec3(0.0);
	for (int i = 0; i < 8; i++) {
		vec4 im = impulses[i];
		if (im.w <= 0.0) continue;
		vec3 d = wpos - im.xyz;
		d -= up * dot(d, up);
		float dist = length(d);
		float fall = im.w / (1.0 + dist * dist * 0.9);
		push += (d / max(dist, 0.05)) * fall;
	}
	return push;
}

// Interior moss cave darkening: up to four caves per ball (xyz = centre, w = radius; w <= 0 unused).
uniform vec4 caves[4];

float cave_factor(vec3 wpos) {
	float f = 0.0;
	for (int i = 0; i < 4; i++) {
		if (caves[i].w > 0.0) {
			f = max(f, 1.0 - smoothstep(caves[i].w * 0.75, caves[i].w, length(wpos - caves[i].xyz)));
		}
	}
	return f;
}
