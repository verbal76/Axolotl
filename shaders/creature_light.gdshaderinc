// The tank's caustic light on the creatures (owner, 2026-10-02: on the ground, Gill and creatures
// alike). Reads the game-wide values the aquarium keeps current (project shader globals): how clear
// the water is and where the lamp is. Add the result to EMISSION at the end of fragment().
#include "res://shaders/caustic_web.gdshaderinc"

global uniform float mote_clarity;
global uniform vec3 mote_lamp_dir;
global uniform sampler2D mote_caustic_tex : filter_linear_mipmap, repeat_enable;

vec3 creature_caustics(vec3 alb, vec3 vertex, vec3 normal, mat4 inv_view) {
	vec3 wpos = (inv_view * vec4(vertex, 1.0)).xyz;
	vec3 wn = normalize((inv_view * vec4(normal, 0.0)).xyz);
	float facing = smoothstep(0.45, 0.9, dot(wn, mote_lamp_dir));
	float depth = smoothstep(-110.0, 150.0, wpos.y);
	float c = caustic_web(mote_caustic_tex, wpos, TIME, mote_lamp_dir) * facing * mix(0.15, 1.0, mote_clarity) * mix(0.55, 1.0, depth);
	return (alb * 0.45 + vec3(0.5, 0.6, 0.55)) * c * 0.9;
}
