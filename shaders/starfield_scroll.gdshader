shader_type canvas_item;

// Slow parallax scroll for the cockpit viewport starfield.
uniform vec2 scroll_speed = vec2(0.004, 0.0);
uniform float brightness = 0.9;
uniform float twinkle = 0.05;
uniform float tint_strength : hint_range(0.0, 1.0) = 0.12;
uniform vec4 tint_color : source_color = vec4(0.35, 0.75, 1.0, 1.0);

void fragment() {
	vec2 uv = fract(UV + TIME * scroll_speed);
	vec3 c = texture(TEXTURE, uv).rgb * brightness;
	float pulse = 1.0 + sin(TIME * 0.7) * twinkle;
	c = mix(c, tint_color.rgb, tint_strength * 0.18);
	COLOR = vec4(c * pulse, 1.0);
}
