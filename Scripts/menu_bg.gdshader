shader_type canvas_item;

uniform sampler2D noise_tex : repeat_enable, filter_linear;
uniform vec3 base_color : source_color = vec3(0.02, 0.02, 0.025);
uniform vec3 fog_color : source_color = vec3(0.16, 0.16, 0.18);
uniform vec2 eclipse_pos = vec2(0.5, 0.22);
uniform float eclipse_radius = 0.075;

void fragment() {
	vec2 uv = UV;
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec2 p = vec2(uv.x * aspect, uv.y);
	float n = texture(noise_tex, p * 0.8 + vec2(TIME * 0.01, TIME * 0.004)).r * 0.6
			+ texture(noise_tex, p * 1.9 - vec2(TIME * 0.006, 0.0)).r * 0.4;
	vec3 col = mix(base_color, fog_color, smoothstep(0.35, 0.9, n) * 0.55);
	vec2 e = vec2(eclipse_pos.x * aspect, eclipse_pos.y);
	float d = length(p - e);
	float edge = max(d - eclipse_radius, 0.0);
	col += vec3(0.9, 0.88, 0.85) * (exp(-edge * 40.0) * 0.55 + exp(-edge * 7.0) * 0.12);
	col = mix(col, vec3(0.01), 1.0 - smoothstep(eclipse_radius - 0.002, eclipse_radius, d));
	COLOR = vec4(col, 1.0);
}
