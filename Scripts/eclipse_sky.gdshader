shader_type sky;

uniform vec3 zenith_color : source_color = vec3(0.012, 0.013, 0.018);
uniform vec3 horizon_color : source_color = vec3(0.06, 0.062, 0.072);
uniform vec3 ground_color : source_color = vec3(0.02, 0.02, 0.024);

uniform sampler2D cloud_noise : repeat_enable, filter_linear_mipmap;
uniform float cloud_coverage : hint_range(0.0, 1.0) = 0.6;
uniform float cloud_scale = 0.35;
uniform float cloud_speed = 0.003;
uniform vec3 cloud_color : source_color = vec3(0.15, 0.15, 0.165);

uniform float moon_radius = 0.045;
uniform vec3 corona_color : source_color = vec3(0.95, 0.9, 0.85);
uniform float corona_intensity = 4.0;
uniform float halo_intensity = 0.7;
uniform vec3 umbra_color : source_color = vec3(0.07, 0.03, 0.025);
uniform bool follow_light = false;
uniform vec3 moon_direction = vec3(0.0, 0.829, 0.559);

void sky() {
	vec3 dir = EYEDIR;
	float h = dir.y;

	vec3 col = mix(horizon_color, zenith_color, smoothstep(0.0, 0.55, h));
	if (h < 0.0) {
		col = mix(horizon_color, ground_color, smoothstep(0.0, -0.15, h));
	}

	vec3 md = (follow_light && LIGHT0_ENABLED) ? LIGHT0_DIRECTION : normalize(moon_direction);
	float ang = acos(clamp(dot(dir, md), -1.0, 1.0));
	float edge = max(ang - moon_radius, 0.0);
	vec2 rim = vec2(dot(dir, normalize(cross(md, vec3(0.0, 1.0, 0.0)))), dir.y - md.y);
	float streak = 0.75 + 0.25 * sin(atan(rim.y, rim.x) * 9.0) * sin(atan(rim.y, rim.x) * 5.0 + 1.3);
	float corona = exp(-edge * 45.0) * corona_intensity * streak + exp(-edge * 5.0) * halo_intensity;
	float disc = 1.0 - smoothstep(moon_radius - 0.0015, moon_radius, ang);
	col += corona_color * corona * (1.0 - disc);
	col = mix(col, umbra_color, disc);

	if (h > 0.0) {
		vec2 cuv = dir.xz / (h + 0.12) * cloud_scale;
		float n = texture(cloud_noise, cuv + vec2(TIME * cloud_speed, 0.0)).r * 0.65
				+ texture(cloud_noise, cuv * 2.3 - vec2(0.0, TIME * cloud_speed * 1.6)).r * 0.35;
		float c = smoothstep(1.0 - cloud_coverage, 1.0 - cloud_coverage + 0.3, n);
		c *= smoothstep(0.0, 0.12, h);
		vec3 lit = cloud_color + corona_color * (exp(-edge * 10.0) * 0.6) * (1.0 - c * 0.5);
		col = mix(col, lit, c * 0.92);
	}

	COLOR = col;
}
