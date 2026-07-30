shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;

uniform float curvature : hint_range(1.0, 20.0) = 6.0;
uniform float scanline_intensity : hint_range(0.0, 1.0) = 0.25;
uniform float scanline_count : hint_range(100.0, 2000.0) = 540.0;
uniform float vignette_strength : hint_range(0.0, 3.0) = 1.2;
uniform float aberration : hint_range(0.0, 0.01) = 0.0025;
uniform float noise_amount : hint_range(0.0, 0.2) = 0.03;
uniform float flicker_speed : hint_range(0.0, 20.0) = 6.0;
uniform float flicker_amount : hint_range(0.0, 0.2) = 0.03;
uniform float brightness : hint_range(0.5, 2.0) = 1.05;

float rand(vec2 co) {
	return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

vec2 curve_uv(vec2 uv) {
	uv = uv * 2.0 - 1.0;
	vec2 offset = abs(uv.yx) / curvature;
	uv += uv * offset * offset;
	uv = uv * 0.5 + 0.5;
	return uv;
}

void fragment() {
	vec2 uv = curve_uv(SCREEN_UV);
	bool outside = uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0;
	vec2 suv = clamp(uv, 0.0, 1.0);

	vec2 ab = vec2(aberration, 0.0);
	float r = texture(screen_texture, suv - ab).r;
	float g = texture(screen_texture, suv).g;
	float b = texture(screen_texture, suv + ab).b;
	vec3 col = vec3(r, g, b);

	float scan = sin(suv.y * scanline_count) * 0.5 + 0.5;
	col *= mix(1.0, scan, scanline_intensity);

	vec2 centered = suv - 0.5;
	float vig = 1.0 - dot(centered, centered) * vignette_strength;
	col *= clamp(vig, 0.0, 1.0);

	float flicker = 1.0 + sin(TIME * flicker_speed) * flicker_amount;
	col *= flicker;

	float n = (rand(suv + fract(TIME)) - 0.5) * noise_amount;
	col += n;

	col *= brightness;
	col = outside ? vec3(0.0) : col;

	COLOR = vec4(col, 1.0);
}
