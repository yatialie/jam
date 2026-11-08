shader_type canvas_item;

// Fades the bottom of the hero art so the arm dissolves into the backdrop
// instead of ending on a hard image edge.
uniform float fade_start : hint_range(0.0, 1.0) = 0.84;
uniform float fade_softness : hint_range(0.001, 0.5) = 0.14;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = 1.0 - smoothstep(fade_start, fade_start + fade_softness, UV.y);
	COLOR = vec4(c.rgb, c.a * a);
}
