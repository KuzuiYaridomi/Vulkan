shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear, repeat_disable;
uniform float saturation : hint_range(0.0, 1.0) = 0.06;
uniform float lit_saturation : hint_range(0.0, 1.0) = 1.0;
uniform float lit_threshold_low = 0.36;
uniform float lit_threshold_high = 0.6;
uniform float contrast = 1.1;
uniform float brightness = 0.02;
uniform vec3 tint : source_color = vec3(0.93, 0.96, 1.0);
uniform float grain : hint_range(0.0, 0.5) = 0.07;
uniform float scanlines : hint_range(0.0, 0.5) = 0.07;
uniform float aberration = 0.0012;
uniform float wobble = 0.0012;
uniform float vignette : hint_range(0.0, 2.0) = 0.7;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	float band = floor(uv.y * 180.0);
	float t = floor(TIME * 15.0);
	uv.x += (hash(vec2(band, t)) - 0.5) * wobble;
	float roll = fract(TIME * 0.07);
	uv.x += smoothstep(0.012, 0.0, abs(uv.y - roll)) * 0.006 * (hash(vec2(t, 3.0)) - 0.5);

	vec3 c;
	c.r = texture(screen_tex, uv + vec2(aberration, 0.0)).r;
	c.g = texture(screen_tex, uv).g;
	c.b = texture(screen_tex, uv - vec2(aberration, 0.0)).b;

	float l = dot(c, vec3(0.299, 0.587, 0.114));
	float lit = smoothstep(lit_threshold_low, lit_threshold_high, l);
	c = mix(vec3(l), c, mix(saturation, lit_saturation, lit));
	c = (c - 0.5) * contrast + 0.5 + brightness;
	c *= mix(tint, vec3(1.0), lit);

	float px_y = SCREEN_UV.y / SCREEN_PIXEL_SIZE.y;
	c *= 1.0 - scanlines * (0.5 + 0.5 * sin(px_y * 3.14159));
	c += (hash(SCREEN_UV / SCREEN_PIXEL_SIZE + fract(TIME) * 913.0) - 0.5) * grain;

	vec2 d = SCREEN_UV - 0.5;
	c *= clamp(1.0 - dot(d, d) * vignette * 1.6, 0.0, 1.0);

	COLOR = vec4(clamp(c, 0.0, 1.0), 1.0);
}
