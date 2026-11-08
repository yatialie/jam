shader_type canvas_item;

// 屏幕边缘描线高亮：只绘制屏幕轮廓，不覆盖原贴图内容，
// 这样贴图叠在关卡背景上时不会出现重采样缝隙。

uniform vec4 outline_color : source_color = vec4(0.38, 0.92, 1.0, 1.0);
uniform float outline_width : hint_range(0.0, 12.0) = 3.0;
uniform float glow : hint_range(0.0, 1.0) = 0.0;
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform float pulse_speed : hint_range(0.0, 12.0) = 2.6;

void fragment() {
	float base_alpha = texture(TEXTURE, UV).a;
	vec2 step_uv = TEXTURE_PIXEL_SIZE * outline_width;

	float near_alpha = 0.0;
	near_alpha = max(near_alpha, texture(TEXTURE, UV + vec2(step_uv.x, 0.0)).a);
	near_alpha = max(near_alpha, texture(TEXTURE, UV - vec2(step_uv.x, 0.0)).a);
	near_alpha = max(near_alpha, texture(TEXTURE, UV + vec2(0.0, step_uv.y)).a);
	near_alpha = max(near_alpha, texture(TEXTURE, UV - vec2(0.0, step_uv.y)).a);
	near_alpha = max(near_alpha, texture(TEXTURE, UV + step_uv).a);
	near_alpha = max(near_alpha, texture(TEXTURE, UV - step_uv).a);
	near_alpha = max(near_alpha, texture(TEXTURE, UV + vec2(step_uv.x, -step_uv.y)).a);
	near_alpha = max(near_alpha, texture(TEXTURE, UV + vec2(-step_uv.x, step_uv.y)).a);

	vec2 halo_uv = step_uv * 2.2;
	float halo_alpha = 0.0;
	halo_alpha = max(halo_alpha, texture(TEXTURE, UV + vec2(halo_uv.x, 0.0)).a);
	halo_alpha = max(halo_alpha, texture(TEXTURE, UV - vec2(halo_uv.x, 0.0)).a);
	halo_alpha = max(halo_alpha, texture(TEXTURE, UV + vec2(0.0, halo_uv.y)).a);
	halo_alpha = max(halo_alpha, texture(TEXTURE, UV - vec2(0.0, halo_uv.y)).a);
	halo_alpha = max(halo_alpha, texture(TEXTURE, UV + halo_uv).a);
	halo_alpha = max(halo_alpha, texture(TEXTURE, UV - halo_uv).a);
	halo_alpha = max(halo_alpha, texture(TEXTURE, UV + vec2(halo_uv.x, -halo_uv.y)).a);
	halo_alpha = max(halo_alpha, texture(TEXTURE, UV + vec2(-halo_uv.x, halo_uv.y)).a);

	float edge = step(0.35, near_alpha) * (1.0 - step(0.35, base_alpha));
	float halo = step(0.35, halo_alpha) * (1.0 - step(0.35, near_alpha));

	float wave = 0.5 + 0.5 * sin(UV.x * 7.0 - TIME * pulse_speed);
	float strength = clamp(glow + flash, 0.0, 1.6);
	float alpha = edge * outline_color.a * strength * (0.55 + 0.45 * wave + flash * 0.7);
	alpha += halo * outline_color.a * strength * (0.10 + 0.14 * wave);

	COLOR = vec4(outline_color.rgb, clamp(alpha, 0.0, 1.0));
}
