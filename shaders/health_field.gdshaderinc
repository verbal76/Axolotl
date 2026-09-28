// Shared moss-ball "health field": 0 = parasite-damaged grey moss, 1 = lush. Restoration that has
// settled lives in the ball's health map (an equirectangular texture painted by MossBall, world
// expansion: no limit on how much can heal); splats still growing in (direction from the ball's
// centre + angular radius in radians) are added on top until they settle into it.
uniform sampler2D health_map : hint_default_black, filter_linear, repeat_enable;
uniform vec4 heals[64];
uniform int heal_count = 0;
uniform vec3 ball_center = vec3(0.0);

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
