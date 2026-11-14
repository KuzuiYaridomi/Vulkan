shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;

uniform sampler2D leaf_texture : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform vec4 uv_region = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec4 tint : source_color = vec4(1.0);
uniform float alpha_cutoff : hint_range(0.0, 1.0) = 0.4;
uniform float wind_strength = 0.08;
uniform float wind_speed = 1.2;
uniform vec3 backlight_color : source_color = vec3(0.30, 0.38, 0.12);

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float w = COLOR.r * wind_strength;
	float t = TIME * wind_speed;
	VERTEX.x += (sin(t + wp.x * 0.6 + wp.y * 0.3) + 0.5 * sin(t * 2.3 + wp.z * 1.7)) * w;
	VERTEX.z += cos(t * 0.8 + wp.z * 0.5 + wp.y * 0.2) * w * 0.6;
	VERTEX.y += sin(t * 3.1 + wp.x + wp.z) * w * 0.3;
}

void fragment() {
	vec4 c = texture(leaf_texture, uv_region.xy + UV * uv_region.zw);
	ALBEDO = c.rgb * tint.rgb * mix(0.75, 1.15, COLOR.g);
	ALPHA = c.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_cutoff;
	ROUGHNESS = 0.85;
	SPECULAR = 0.25;
	BACKLIGHT = backlight_color;
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
}
