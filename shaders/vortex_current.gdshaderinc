// Vortex currents (ledger row 14): the tunnel's visible centreline meanders slowly in 3D like a moving
// water current, while the logical travel path (Vortex.points) stays fixed.
//
// D(u) = w(u) * B * S(u), with w(u) = sin(pi u)^1.5 (zero at both anchored mouths, freest mid-span) and
// S(u) = sum over three terms k of amp_k * sin(ph_k + kap_k * u), all per axis (componentwise), so each
// axis has three slow influences at different frequencies and phases. The CPU (Vortex.current_offset)
// advances the phases (ph_k = omega_k * time + phi_k, wrapped) and evaluates the very same formula for
// Gill's ride and the camera, so he stays inside the current the GPU draws.
//
// u is the stable normalised parameter along the connection: 0 = moss ball A, 0.5 = midpoint,
// 1 = moss ball B (Hard Mode animates either half from it).

uniform vec3 cur_amp0 = vec3(0.0);
uniform vec3 cur_amp1 = vec3(0.0);
uniform vec3 cur_amp2 = vec3(0.0);
uniform vec3 cur_ph0 = vec3(0.0);
uniform vec3 cur_ph1 = vec3(0.0);
uniform vec3 cur_ph2 = vec3(0.0);
uniform vec3 cur_kap0 = vec3(0.0);
uniform vec3 cur_kap1 = vec3(0.0);
uniform vec3 cur_kap2 = vec3(0.0);
// Columns: sideways, vertical, along the connection (depth), in this mesh's own space.
uniform mat3 cur_basis = mat3(1.0);

float current_weight(float u) {
	return pow(max(sin(3.14159265 * clamp(u, 0.0, 1.0)), 0.0), 1.5);
}

vec3 current_offset(float u) {
	vec3 s = cur_amp0 * sin(cur_ph0 + cur_kap0 * u) + cur_amp1 * sin(cur_ph1 + cur_kap1 * u) + cur_amp2 * sin(cur_ph2 + cur_kap2 * u);
	return cur_basis * (s * current_weight(u));
}
