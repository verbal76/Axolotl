shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_disabled;

// Gill's skin (Expansion 6): soft, moist axolotl skin rather than shiny pink plastic.
// - Tone: a warmer, slightly deeper pink along the back, a pale peach belly, and a faint mottle.
// - Freckles: small darker spots scattered over the back and flanks (fewer toward the belly),
//   attached to the surface (they ride the body as it bends).
// - Moist, not glossy: a soft broad sheen (roughness ~0.6) and a little light through the skin
//   at the silhouette when it is back-lit. A gentle self-glow keeps him readable in murky water.
// `mode`: 0 body (UV.x round the body, 0/1 on top; UV.y head to tail tip), 1 rigid part (head,
// limbs: mapped from object position), 2 fin membrane (UV.x base to edge, UV.y along).

uniform int mode = 0;
uniform vec3 base_color : source_color = vec3(0.98, 0.58, 0.66);
uniform vec3 back_tint : source_color = vec3(0.9, 0.48, 0.57);
uniform vec3 belly_tint : source_color = vec3(1.0, 0.8, 0.77);
uniform vec3 freckle_color : source_color = vec3(0.72, 0.34, 0.44);
uniform float freckles = 1.0;
uniform float glow = 0.08;
uniform float spot_scale = 1.0;
// A pattern (owner request: GillLook), in place of the freckles: `pattern_mode` 0 paints it as
// markings in the freckle colour (a stencil: its alpha, or its dark parts when it has none), 1 lays
// the picture on in its own colours. It repeats `pattern_scale` times round his body (whole
// repeats, so no seam) and as often along it; head and limbs take it by a three-way projection.
uniform sampler2D pattern_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform float pattern_on = 0.0;
uniform int pattern_mode = 0;
uniform float pattern_scale = 3.0;
uniform float pattern_alpha = 0.0;

varying vec3 v_obj;
varying vec3 v_onrm;

void vertex() {
	v_obj = VERTEX;
	v_onrm = NORMAL;
}

vec4 pattern_at(vec2 uv) {
	return texture(pattern_tex, uv);
}

// The pattern here: its colour and how much of it shows (0..1).
vec4 pattern_sample(vec2 uv_body) {
	vec4 t;
	if (mode == 0) {
		t = pattern_at(uv_body * pattern_scale);
	} else {
		vec3 w = pow(abs(normalize(v_onrm + vec3(0.0001))), vec3(4.0));
		w /= w.x + w.y + w.z;
		vec3 q = v_obj * pattern_scale / 1.26;
		t = pattern_at(q.zy) * w.x + pattern_at(q.xz) * w.y + pattern_at(q.xy) * w.z;
	}
	float lum = dot(t.rgb, vec3(0.299, 0.587, 0.114));
	float mask = pattern_alpha > 0.5 ? t.a : (1.0 - lum) * t.a;
	return vec4(t.rgb, pattern_mode == 0 ? mask : t.a);
}

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

// Soft round spots on a jittered grid (one chance per cell), `wrap` cells round in x (0 = none).
float spot_field(vec2 p, float wrap) {
	vec2 c = floor(p);
	float m = 0.0;
	for (int dy = -1; dy <= 1; dy++) {
		for (int dx = -1; dx <= 1; dx++) {
			vec2 cc = c + vec2(float(dx), float(dy));
			vec2 key = cc;
			if (wrap > 0.0) {
				key.x = mod(key.x, wrap);
			}
			if (hash21(key + 3.1) > 0.42) {
				continue;
			}
			vec2 o = cc + 0.2 + 0.6 * vec2(hash21(key + 7.7), hash21(key + 1.9));
			float r = mix(0.1, 0.24, hash21(key + 5.3));
			m = max(m, 1.0 - smoothstep(r * 0.55, r, length(p - o)));
		}
	}
	return m;
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x), mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	float top;
	float spots;
	float mottle;
	if (mode == 0) {
		top = cos(UV.x * 6.2832) * 0.5 + 0.5;
		spots = spot_field(vec2(UV.x * 18.0, UV.y * 22.0) * spot_scale, 18.0 * spot_scale);
		mottle = value_noise(vec2(UV.x * 7.0, UV.y * 9.0));
	} else if (mode == 1) {
		vec3 d = normalize(v_obj + vec3(0.0001));
		top = d.y * 0.5 + 0.5;
		spots = spot_field(vec2(atan(d.x, d.z) * 3.0, d.y * 5.0) * spot_scale, 0.0);
		mottle = value_noise(v_obj.xz * 18.0 + v_obj.y * 7.0);
	} else {
		top = 1.0;
		spots = 0.0;
		mottle = value_noise(vec2(UV.x * 3.0, UV.y * 14.0));
	}
	vec3 c = mix(belly_tint, base_color, smoothstep(0.15, 0.55, top));
	c = mix(c, back_tint, smoothstep(0.6, 1.0, top) * 0.75);
	c *= mix(0.93, 1.05, mottle);
	// Freckles mostly on the back and flanks (or the chosen pattern in their place).
	float fk = spots * freckles * smoothstep(0.35, 0.75, top) * (1.0 - pattern_on);
	c = mix(c, freckle_color, fk * 0.8);
	if (pattern_on > 0.5 && mode != 2) {
		vec4 pt = pattern_sample(UV);
		float belly = mix(0.55, 1.0, smoothstep(0.1, 0.5, top));
		// (Markings a shade deeper than freckles, so a pattern reads from the game camera.)
		if (pattern_mode == 0) {
			c = mix(c, freckle_color * 0.82, pt.a * belly);
		} else {
			c = mix(c, pt.rgb * mix(0.93, 1.05, mottle), pt.a * belly);
		}
	}
	if (mode == 2) {
		// Fin membrane: pale at the body, pinker toward a slightly darker edge, fine rays.
		float rays = 0.5 + 0.5 * sin(UV.y * 140.0);
		c = mix(belly_tint, base_color, UV.x) * mix(0.96, 1.02, rays);
		c = mix(c, back_tint, smoothstep(0.75, 1.0, UV.x) * 0.6);
		BACKLIGHT = c * 0.55;
	} else {
		BACKLIGHT = c * 0.28;
	}
	ALBEDO = c;
	// Moist, not plastic: a broad soft sheen.
	ROUGHNESS = mode == 2 ? 0.55 : 0.6;
	SPECULAR = 0.36;
	RIM = 0.12;
	RIM_TINT = 0.6;
	EMISSION = c * glow;
}
