shader_type canvas_item;

// Frosted glass veil used behind modal panels.
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float blur_radius : hint_range(0.0, 6.0) = 2.2;
uniform float darken : hint_range(0.0, 1.0) = 0.62;
uniform float tint : hint_range(0.0, 1.0) = 0.35;
uniform vec4 tint_color : source_color = vec4(0.03, 0.07, 0.09, 1.0);
uniform float fade : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 px = vec2(0.0016, 0.0016) * blur_radius;

	vec3 c = texture(screen_texture, uv).rgb * 0.20;
	c += texture(screen_texture, uv + vec2(px.x, 0.0)).rgb * 0.09;
	c += texture(screen_texture, uv - vec2(px.x, 0.0)).rgb * 0.09;
	c += texture(screen_texture, uv + vec2(0.0, px.y)).rgb * 0.09;
	c += texture(screen_texture, uv - vec2(0.0, px.y)).rgb * 0.09;
	c += texture(screen_texture, uv + vec2(px.x, px.y) * 0.72).rgb * 0.06;
	c += texture(screen_texture, uv + vec2(px.x, -px.y) * 0.72).rgb * 0.06;
	c += texture(screen_texture, uv + vec2(-px.x, px.y) * 0.72).rgb * 0.06;
	c += texture(screen_texture, uv + vec2(-px.x, -px.y) * 0.72).rgb * 0.06;
	c += texture(screen_texture, uv + vec2(px.x * 2.0, 0.0)).rgb * 0.04;
	c += texture(screen_texture, uv - vec2(px.x * 2.0, 0.0)).rgb * 0.04;
	c += texture(screen_texture, uv + vec2(0.0, px.y * 2.0)).rgb * 0.04;
	c += texture(screen_texture, uv - vec2(0.0, px.y * 2.0)).rgb * 0.04;
	c /= 0.87;

	c = mix(c, tint_color.rgb, tint * 0.35);
	c *= 1.0 - darken;

	COLOR = vec4(c, fade);
}
