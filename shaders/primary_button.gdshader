shader_type canvas_item;
// The primary action pill (docs/UI_STYLE.md): a wide pill with crisp edges, filled with a few large,
// softly blended regions of aqua, turquoise, aquatic green and a little moss, like aquarium light
// through moving water. Drawn by UiStyle.make_primary() behind the button's own (crisp) text, on a
// rect `pad` px larger than the button on every side (room for the soft shadow).

uniform vec2 rect_size = vec2(340.0, 68.0);   // this control's size (px): the pill never stretches
uniform float pad = 8.0;                      // margin around the pill inside the rect (px)
uniform float seed = 0.0;                     // per button, so a family never looks cloned
uniform float lift = 0.0;                     // hover / focus: a little brighter
uniform float press = 0.0;                    // held: a little darker, sunk 1.5 px
uniform float dim = 0.0;                      // disabled: muted toward the panel

const vec3 AQUA = vec3(0.40, 0.85, 0.86);
const vec3 TURQ = vec3(0.24, 0.79, 0.75);
const vec3 SEA = vec3(0.40, 0.86, 0.58);
const vec3 MOSS = vec3(0.62, 0.80, 0.42);
const vec3 EDGE = vec3(0.02, 0.17, 0.16);

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

// Smooth value noise (quintic), so region boundaries are soft curves, never steps.
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

// Signed distance to a pill of half-size hs centred at the origin.
float pill(vec2 p, vec2 hs) {
	float r = hs.y;
	vec2 q = abs(p) - vec2(hs.x - r, 0.0);
	return length(max(q, 0.0)) - r;
}

void fragment() {
	vec2 px = UV * rect_size;
	vec2 hs = rect_size * 0.5 - vec2(pad);
	vec2 c = px - rect_size * 0.5 - vec2(0.0, press * 1.5);
	float d = pill(c, hs);
	float aa = max(fwidth(d), 0.0001);

	// Soft drop shadow under the pill (lower when raised, tighter when held).
	float ds = pill(c - vec2(0.0, 3.0 - press * 1.5), hs);
	float shadow = (1.0 - smoothstep(-2.0, 6.0, ds)) * 0.34 * (1.0 - dim * 0.6);

	// The fluid fill, in pill-height units so a wide button shows more regions, never stretched ones.
	// (Turned a little and drawn out sideways: on a pill five times wider than tall, round regions
	// would read as vertical stripes; these flow along it like light through water.)
	vec2 q = (c + hs) / (hs.y * 2.0);
	q = mat2(vec2(0.91, 0.42), vec2(-0.42, 0.91)) * q * vec2(0.55, 1.3);
	// (Still on purpose, no time input: judged against a slow drift, the still fill reads just as organic
	// and costs nothing per frame.)
	vec2 o = vec2(seed * 7.13, seed * 3.71);
	vec2 w = vec2(vnoise(q * 0.9 + o), vnoise(q * 0.9 + o + vec2(5.2, 1.3))) - 0.5;
	vec2 qw = q + w * 0.9;
	float n1 = smoothstep(0.22, 0.78, vnoise(qw * 0.85 + o + vec2(1.7, 9.2)));
	float n2 = smoothstep(0.25, 0.75, vnoise(qw * 0.7 - o * 0.7 + vec2(8.3, 2.8)));
	float n3 = smoothstep(0.55, 0.9, vnoise(qw * 0.6 + o * 0.5 + vec2(3.1, 6.4)));
	vec3 col = mix(TURQ, AQUA, n1);
	col = mix(col, SEA, n2 * 0.85);
	col = mix(col, MOSS, n3 * 0.55);
	// Refracted light from above: the upper half a touch brighter, fading softly to the lower edge.
	float v = clamp((c.y + hs.y) / (hs.y * 2.0), 0.0, 1.0);
	col *= mix(1.07, 0.93, smoothstep(0.0, 1.0, v));
	col = mix(col, col * 1.04 + 0.02, lift);
	col *= 1.0 - press * 0.12;
	// Disabled: a quiet deep-teal pill with only a hint of its colours (its text turns pale).
	vec3 muted = mix(vec3(dot(col, vec3(0.3, 0.55, 0.15))), col, 0.3) * 0.3 + vec3(0.03, 0.12, 0.12);
	col = mix(col, muted, dim);

	// Razor-clean edges: a hairline of light just inside the top rim and a dark hairline outline.
	float inner = 1.0 - smoothstep(0.0, 1.6, -d);
	float top = smoothstep(0.2, -0.6, c.y / hs.y);
	col = mix(col, vec3(1.0), inner * top * 0.45 * (1.0 - dim));
	float outline = 1.0 - smoothstep(0.0, aa * 1.5, abs(d + 0.75) - 0.75);
	col = mix(col, EDGE, outline * (0.55 + 0.25 * lift));

	// A whisper of dither so the soft blends never show 8-bit steps.
	col += (hash(floor(px * 2.0)) - 0.5) / 255.0;

	float body = 1.0 - smoothstep(-aa * 0.5, aa * 0.5, d);
	vec4 fill = vec4(col, 1.0);
	vec4 sh = vec4(0.0, 0.03, 0.03, shadow);
	COLOR = mix(sh, fill, body);
	COLOR.a = max(body, shadow * (1.0 - body));
}
