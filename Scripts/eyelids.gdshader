shader_type canvas_item;

uniform float open : hint_range(0.0, 1.0) = 1.0;
uniform float softness = 0.06;

void fragment() {
	float x = (UV.x - 0.5) * 2.0;
	float h = open * 0.62 * (1.0 - 0.35 * x * x);
	float d = abs(UV.y - 0.5);
	float a = smoothstep(h - softness, h + softness, d);
	COLOR = vec4(0.0, 0.0, 0.0, a);
}
