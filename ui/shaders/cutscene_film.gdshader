shader_type canvas_item;

// 过场黑场质感：近黑底色、极淡的胶片颗粒、扫描线与暗角，
// 外加一条缓慢漂移的横向光带，让“黑屏”保留一点磁带档案的呼吸感。

uniform vec4 base_color : source_color = vec4(0.006, 0.010, 0.013, 1.0);
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform float grain_amount : hint_range(0.0, 0.1) = 0.02;
uniform float scanline_amount : hint_range(0.0, 0.1) = 0.012;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.55;
uniform float band_strength : hint_range(0.0, 0.08) = 0.012;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void fragment() {
	vec2 uv = UV;
	vec3 col = base_color.rgb;

	// 极淡的冷色中心光池，避免纯黑死板
	vec2 cp = (uv - vec2(0.5)) * vec2(1.35, 1.0);
	col += vec3(0.010, 0.020, 0.024) * exp(-dot(cp, cp) * 5.0);

	// 缓慢上下漂移的横向光带
	float band_y = 0.5 + sin(TIME * 0.22) * 0.08;
	float band = exp(-pow((uv.y - band_y) * 6.0, 2.0));
	col += vec3(0.05, 0.09, 0.10) * band * band_strength;

	// 扫描线
	col *= 1.0 - scanline_amount * (0.5 + 0.5 * sin(uv.y * 1000.0));

	// 暗角
	vec2 vd = (uv - vec2(0.5)) * vec2(1.06, 1.0);
	float vig = 1.0 - smoothstep(0.18, 0.86, length(vd));
	col *= mix(1.0 - vignette_strength, 1.0, vig);

	// 动态胶片颗粒
	float n = hash21(uv * vec2(1920.0, 1080.0) + fract(TIME) * 173.0);
	col += (n - 0.5) * grain_amount;

	COLOR = vec4(max(col, vec3(0.0)) * intensity, 1.0);
}
