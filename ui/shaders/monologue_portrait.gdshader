shader_type canvas_item;

// 旁白立绘：保留透明底，仅做轻微冷调、扫描线与底部渐隐，让立绘自然融合到画面。
uniform float reveal : hint_range(0.0, 1.0) = 1.0;
uniform float bottom_fade : hint_range(0.0, 0.35) = 0.035;
uniform float scan_strength : hint_range(0.0, 0.15) = 0.03;
uniform float scan_density = 1.5;
uniform vec4 tint : source_color = vec4(0.5, 0.85, 1.0, 1.0);
uniform float tint_amount : hint_range(0.0, 0.3) = 0.06;

void fragment() {
	vec4 color = texture(TEXTURE, UV);

	float luma = dot(color.rgb, vec3(0.299, 0.587, 0.114));
	color.rgb = mix(color.rgb, luma * tint.rgb * 1.2, tint_amount * 0.5);

	float scan = 0.5 + 0.5 * sin(FRAGCOORD.y * scan_density + TIME * 1.6);
	color.rgb *= 1.0 - scan_strength * scan;

	// 立绘下缘淡出，避免半身裁切处出现硬边。
	color.a *= smoothstep(0.0, bottom_fade, 1.0 - UV.y);
	color.a *= reveal;

	COLOR = color;
}
