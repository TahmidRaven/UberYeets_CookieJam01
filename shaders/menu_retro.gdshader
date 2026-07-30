shader_type canvas_item;

uniform vec4 color_top : source_color = vec4(1.0, 0.85, 0.25, 1.0);
uniform vec4 color_bottom : source_color = vec4(0.75, 0.15, 0.05, 1.0);
uniform vec4 glow_color : source_color = vec4(1.0, 0.65, 0.15, 1.0);
uniform float stripe_speed : hint_range(0.0, 5.0) = 0.5;
uniform float stripe_count : hint_range(4.0, 60.0) = 20.0;
uniform float stripe_intensity : hint_range(0.0, 1.0) = 0.18;
uniform float scanline_intensity : hint_range(0.0, 1.0) = 0.2;
uniform float scanline_count : hint_range(100.0, 2000.0) = 400.0;
uniform float glow_strength : hint_range(0.0, 2.0) = 0.9;
uniform float vignette_strength : hint_range(0.0, 3.0) = 1.0;

void fragment() {
	vec2 uv = UV;
	vec3 col = mix(color_bottom.rgb, color_top.rgb, clamp(uv.y * 1.15, 0.0, 1.0));

	float stripes = sin((uv.y + TIME * stripe_speed * 0.08) * stripe_count * 6.28318);
	stripes = smoothstep(0.9, 1.0, stripes);
	col += stripes * stripe_intensity;

	vec2 centered = (uv - vec2(0.5, 0.4)) * vec2(1.0, 1.4);
	float glow = 1.0 - smoothstep(0.0, 0.85, length(centered));
	col += glow * glow_strength * glow_color.rgb;

	float scan = sin(uv.y * scanline_count) * 0.5 + 0.5;
	col *= mix(1.0, scan, scanline_intensity);

	vec2 vig_uv = uv - 0.5;
	float vig = 1.0 - dot(vig_uv, vig_uv) * vignette_strength;
	col *= clamp(vig, 0.0, 1.0);

	COLOR = vec4(col, 1.0);
}
