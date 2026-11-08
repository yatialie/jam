shader_type canvas_item;

// 第四关主控屏幕底图：中心保持清晰，靠近边缘逐渐模糊并羽化，融进玻璃面板。

uniform float blur_radius : hint_range(0.0, 24.0) = 8.0;
uniform float edge_width : hint_range(0.01, 0.35) = 0.1;
uniform float feather : hint_range(0.0, 0.2) = 0.05;

void fragment() {
	vec2 texel = TEXTURE_PIXEL_SIZE * blur_radius;
	vec2 edge = min(UV, vec2(1.0) - UV);
	float edge_factor = smoothstep(0.0, edge_width, min(edge.x, edge.y));
	vec4 sharp = texture(TEXTURE, UV);
	vec4 blurred = texture(TEXTURE, UV) * 0.2;
	blurred += texture(TEXTURE, UV + vec2(texel.x, 0.0)) * 0.12;
	blurred += texture(TEXTURE, UV - vec2(texel.x, 0.0)) * 0.12;
	blurred += texture(TEXTURE, UV + vec2(0.0, texel.y)) * 0.12;
	blurred += texture(TEXTURE, UV - vec2(0.0, texel.y)) * 0.12;
	blurred += texture(TEXTURE, UV + texel) * 0.08;
	blurred += texture(TEXTURE, UV - texel) * 0.08;
	blurred += texture(TEXTURE, UV + vec2(texel.x, -texel.y)) * 0.08;
	blurred += texture(TEXTURE, UV + vec2(-texel.x, texel.y)) * 0.08;
	vec4 col = mix(blurred, sharp, edge_factor);
	float alpha = smoothstep(0.0, feather, min(edge.x, edge.y));
	COLOR = vec4(col.rgb, col.a * alpha);
}
