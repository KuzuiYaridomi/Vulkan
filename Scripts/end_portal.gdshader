shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, shadows_disabled;

uniform float intensity = 1.8;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float ang = atan(p.y, p.x);
	float swirl = 0.5 + 0.5 * sin(ang * 6.0 + r * 14.0 - TIME * 4.0);
	float core = 1.0 - smoothstep(0.0, 0.92, r);
	float rim = smoothstep(0.72, 0.92, r) * (1.0 - smoothstep(0.92, 1.0, r));
	ALBEDO = vec3(1.0) * intensity * (0.85 + 0.3 * swirl);
	ALPHA = clamp(core * (0.7 + 0.3 * swirl) + rim, 0.0, 1.0) * (1.0 - smoothstep(0.96, 1.0, r));
}
