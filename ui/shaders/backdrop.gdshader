shader_type canvas_item;

// Ambient tape-archive backdrop: deep teal gradient, soft practical lights,
// CRT scanlines, animated grain and a very slow diagonal sheen.

uniform vec4 color_top : source_color = vec4(0.058, 0.082, 0.098, 1.0);
uniform vec4 color_bottom : source_color = vec4(0.018, 0.029, 0.036, 1.0);
uniform vec4 warm_glow : source_color = vec4(1.0, 0.56, 0.24, 1.0);
uniform vec4 cool_glow : source_color = vec4(0.20, 0.78, 0.88, 1.0);
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.78;
uniform float grain_amount : hint_range(0.0, 0.1) = 0.026;
uniform float scanline_amount : hint_range(0.0, 0.1) = 0.016;
uniform float glow_strength : hint_range(0.0, 0.4) = 0.11;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void fragment() {
	vec2 uv = UV;
	vec3 col = mix(color_top.rgb, color_bottom.rgb, smoothstep(0.0, 1.0, uv.y));

	// cool pool of light behind the cassette
	vec2 cp = (uv - vec2(0.79, 0.40)) * vec2(1.6, 1.0);
	col += cool_glow.rgb * glow_strength * exp(-dot(cp, cp) * 6.0);

	// faint warm leak from the upper left
	vec2 wp = (uv - vec2(0.0, -0.06)) * vec2(1.15, 1.0);
	col += warm_glow.rgb * 0.045 * exp(-dot(wp, wp) * 5.0);

	// soft horizontal haze bands
	float band = sin(uv.y * 26.0 + TIME * 0.10) * 0.5 + 0.5;
	col += vec3(0.05, 0.09, 0.10) * band * 0.028;

	// vignette
	vec2 vd = (uv - vec2(0.5)) * vec2(1.05, 1.0);
	float vig = 1.0 - smoothstep(0.16, 0.80, length(vd));
	col *= mix(1.0 - vignette_strength, 1.0, vig);

	// scanlines
	col *= 1.0 - scanline_amount * (0.5 + 0.5 * sin(uv.y * 1500.0));

	// animated film grain
	float n = hash21(uv * vec2(1920.0, 1080.0) + fract(TIME) * 137.0);
	col += (n - 0.5) * grain_amount;

	// slow diagonal sheen
	float sweep = uv.x * 0.85 + uv.y * 0.45 - fract(TIME * 0.035) * 2.2 + 0.25;
	float sheen = 1.0 - smoothstep(0.0, 0.07, abs(sweep));
	col += vec3(0.32, 0.70, 0.78) * sheen * 0.03;

	COLOR = vec4(col, 1.0);
}
