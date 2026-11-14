shader_type canvas_item;

uniform float glitch : hint_range(0.0, 1.0) = 0.0;
uniform float split = 1.0;
uniform float rows = 10.0;
uniform vec3 fringe_a : source_color = vec3(1.0, 0.15, 0.15);
uniform vec3 fringe_b : source_color = vec3(0.1, 0.9, 1.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec4 m = COLOR;
	vec2 uv = UV;
	float t = floor(TIME * 20.0);
	float band = floor(uv.y * rows);
	float jump = step(0.55, hash(vec2(band * 1.7, t + 3.0)));
	uv.x += (hash(vec2(band, t)) - 0.5) * glitch * 0.14 * jump;
	vec2 o = vec2(TEXTURE_PIXEL_SIZE.x * (split + glitch * 3.0), 0.0);
	vec4 c = texture(TEXTURE, uv);
	float a = step(0.5, c.a);
	float ar = step(0.5, texture(TEXTURE, uv - o).a);
	float ac = step(0.5, texture(TEXTURE, uv + o).a);
	vec4 outc = vec4(0.0);
	if (ar > 0.5) outc = vec4(fringe_a, 0.75);
	if (ac > 0.5) outc = (outc.a > 0.0) ? vec4(mix(outc.rgb, fringe_b, 0.5), 0.75) : vec4(fringe_b, 0.75);
	if (a > 0.5) outc = vec4(c.rgb / max(c.a, 0.001), 1.0);
	outc.a *= 1.0 - glitch * 0.35 * hash(vec2(t, 7.0));
	COLOR = outc * m;
}
