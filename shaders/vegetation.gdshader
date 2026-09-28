shader_type spatial;
render_mode cull_disabled, world_vertex_coords, diffuse_lambert, specular_disabled;

// Instanced moss-ball vegetation. Mesh convention: UV.y = 0 at the base, 1 at the tip.
// Health comes from the same splat field as the moss, so restored areas regrow colour,
// height and motion together.
// Movement (docs/VEGETATION.md): gentle ambient sway with each plant's own phase and slow gusts
// crossing the field; the aquarium current; water impulses; and the wake of movers (the
// axolotl's head, body, tail and trail, and nearby parasites): plants near a wake point bend
// away from it and along its motion. Per plant, from its base (one value for the whole plant).

#include "res://shaders/health_field.gdshaderinc"

uniform vec3 healthy_a : source_color = vec3(0.1, 0.35, 0.1);
uniform vec3 healthy_b : source_color = vec3(0.45, 0.75, 0.25);
uniform vec3 dead_a : source_color = vec3(0.3, 0.29, 0.26);
uniform vec3 dead_b : source_color = vec3(0.52, 0.5, 0.44);
uniform float sway = 0.18;
uniform float sway_speed = 1.3;
uniform vec3 current_axis = vec3(0.0, 1.0, 0.0);
uniform float current_strength = 0.0;
uniform float impulse_gain = 1.0;
uniform float cam_fade = 1.8;
// Wake (scripts/world/wake.gd): a = position + radius, b = velocity + strength.
uniform vec4 wake_a[24];
uniform vec4 wake_b[24];
uniform int wake_count = 0;
uniform vec4 wake_bounds = vec4(0.0);
// How strongly this family answers the wake, and its full height (for movers passing over it).
uniform float wake_gain = 1.0;
uniform float plant_height = 0.5;
uniform vec4 motes[6];
uniform int mote_count = 0;
uniform vec3 mote_color : source_color = vec3(0.55, 1.0, 0.75);

// Keep in step with Wake.bend_at (the CPU mirror the tests use).
vec3 wake_bend(vec3 base, vec3 up, float plant_h) {
	vec3 sum = vec3(0.0);
	float wsum = 0.0;
	float strongest = 0.0;
	if (wake_count == 0 || distance(base, wake_bounds.xyz) > wake_bounds.w) {
		return sum;
	}
	for (int i = 0; i < wake_count; i++) {
		vec3 pos = wake_a[i].xyz;
		float r = wake_a[i].w;
		vec3 d = base - pos;
		float above = -dot(d, up);
		d -= up * dot(d, up);
		float dist = length(d);
		if (dist > r * 2.5) continue;
		float fall = wake_b[i].w * (1.0 - smoothstep(r * 0.5, r * 2.5, dist)) * (1.0 - smoothstep(plant_h * 0.85, plant_h + r, above));
		if (fall <= 0.0) continue;
		vec3 vel = wake_b[i].xyz;
		vel -= up * dot(vel, up);
		// Direction: pushes averaged by strength; size: the strongest point (no stacking).
		vec3 push = d / max(dist, 0.05) + vel * 0.12;
		sum += push * fall;
		wsum += fall;
		strongest = max(strongest, fall * length(push));
	}
	if (wsum <= 0.0) return vec3(0.0);
	vec3 b = sum / wsum;
	float m = length(b);
	return m < 0.0001 ? vec3(0.0) : b / m * min(strongest, 1.6);
}

varying float v_health;
varying float v_t;
varying vec3 v_wpos;

void vertex() {
	vec3 base = MODEL_MATRIX[3].xyz;
	vec3 up = normalize(base - ball_center);
	float hlt = health_at(up);
	float t = UV.y;
	vec3 off = VERTEX - base;
	float shrink = mix(0.62, 1.0, hlt);
	float len = length(off) * shrink;
	VERTEX = base + off * shrink;
	float w = t * t;
	// Each plant its own phase and pace (no field waving in unison), plus slow gusts that roll
	// across the ball.
	float hsh = fract(sin(dot(base, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
	float ph = hsh * 6.2832;
	float pace = sway_speed * mix(0.8, 1.25, fract(hsh * 7.31));
	vec3 side = normalize(cross(up, normalize(vec3(0.31, 0.87, 0.42))));
	vec3 side2 = cross(up, side);
	float gust = 0.55 + 0.45 * sin(dot(base, vec3(0.21, 0.17, 0.23)) - TIME * 0.7);
	vec3 bend = (side * sin(TIME * pace + ph) + side2 * cos(TIME * pace * 0.73 + ph * 1.7) * 0.5) * sway * mix(0.35, 1.0, hlt) * gust;
	// Aquarium current: a band of flow around current_axis (Moss Ball #2).
	vec3 flow = cross(current_axis, up);
	float band = 1.0 - smoothstep(0.45, 0.8, abs(dot(up, current_axis)));
	bend += flow * current_strength * band * (0.85 + 0.3 * sin(TIME * 2.3 + ph * 3.0));
	bend += impulse_push(base, up) * impulse_gain;
	// The wake: this plant's own height (the instance's scale times the family's height).
	bend += wake_bend(base, up, plant_height * length(MODEL_MATRIX[1].xyz)) * wake_gain;
	bend += side * (1.0 - hlt) * 0.35;
	VERTEX += bend * w * len * 0.6;
	VERTEX -= up * min(dot(bend, bend), 1.2) * w * len * 0.22;
	v_health = hlt;
	v_t = t;
	v_wpos = VERTEX;
}

void fragment() {
	float d = length(VERTEX);
	if (d < cam_fade) {
		float r = fract(sin(dot(FRAGCOORD.xy, vec2(12.9898, 78.233))) * 43758.5453);
		if (r > d / cam_fade) discard;
	}
	float h = smoothstep(0.1, 0.9, v_health);
	vec3 healthy = mix(healthy_a, healthy_b, v_t);
	vec3 dead = mix(dead_a, dead_b, v_t);
	vec3 alb = mix(dead, healthy, h) * mix(0.55, 1.0, v_t) * COLOR.rgb;
	ALBEDO = alb;
	ALBEDO *= 1.0 - cave_factor(v_wpos) * 0.62;
	ROUGHNESS = 0.9;
	BACKLIGHT = alb * 0.4 * h;
	vec3 glow = vec3(0.0);
	for (int i = 0; i < mote_count; i++) {
		vec3 dd = v_wpos - motes[i].xyz;
		glow += motes[i].w / (1.0 + dot(dd, dd) * 0.9);
	}
	EMISSION = glow * mote_color * (alb * 1.6 + 0.1);
}
