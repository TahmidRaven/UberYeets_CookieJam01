shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;

uniform vec4 color_top : source_color = vec4(1.0, 0.85, 0.25, 1.0);
uniform vec4 color_bottom : source_color = vec4(0.75, 0.15, 0.05, 1.0);
uniform vec4 glow_color : source_color = vec4(1.0, 0.65, 0.15, 1.0);
uniform float tint_strength : hint_range(0.0, 1.0) = 0.5;
uniform float darken : hint_range(0.0, 1.0) = 0.3;
uniform float stripe_speed : hint_range(0.0, 5.0) = 0.5;
uniform float stripe_count : hint_range(4.0, 60.0) = 20.0;
uniform float stripe_intensity : hint_range(0.0, 1.0) = 0.1;
uniform float scanline_intensity : hint_range(0.0, 1.0) = 0.12;
uniform float scanline_count : hint_range(100.0, 2000.0) = 400.0;
uniform float glow_strength : hint_range(0.0, 2.0) = 0.45;
uniform float vignette_strength : hint_range(0.0, 3.0) = 1.1;

void fragment() {
	vec3 scene = texture(screen_texture, SCREEN_UV).rgb;
	vec2 uv = UV;

	vec3 grade = mix(color_bottom.rgb, color_top.rgb, clamp(uv.y * 1.15, 0.0, 1.0));
	vec3 col = mix(scene, scene * grade * 1.3, tint_strength);
	col = mix(col, vec3(0.0), darken);

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
