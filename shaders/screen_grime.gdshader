shader_type canvas_item;

// 第四关主控屏幕污渍层：用鼠标擦除蒙版控制透明度，露出下方底图。

uniform sampler2D mask_tex : filter_linear, repeat_disable;
uniform float edge_feather : hint_range(0.0, 0.2) = 0.05;
uniform float min_density : hint_range(0.0, 1.0) = 0.94;
uniform float reveal : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 fog = texture(TEXTURE, UV);
	float mask = texture(mask_tex, UV).r;
	vec2 edge = min(UV, vec2(1.0) - UV);
	float edge_fade = smoothstep(0.0, edge_feather, min(edge.x, edge.y));
	// 纹理透明处也保留一层基础雾密度，保证底图在擦除前基本不可读。
	float density = mix(min_density, 1.0, fog.a);
	float alpha = density * (1.0 - mask) * edge_fade * (1.0 - reveal);
	COLOR = vec4(fog.rgb, clamp(alpha, 0.0, 1.0));
}
