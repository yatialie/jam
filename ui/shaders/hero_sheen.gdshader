shader_type canvas_item;

// Intro light sweep, masked by the hero artwork alpha.
uniform float progress : hint_range(-0.4, 1.4) = 1.2;
uniform float width : hint_range(0.01, 0.4) = 0.10;
uniform float strength : hint_range(0.0, 1.0) = 0.55;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float axis = UV.x * 0.72 + UV.y * 0.28;
	float band = 1.0 - smoothstep(0.0, width, abs(axis - progress));
	float edge = smoothstep(0.0, 0.25, tex.a);
	float a = tex.a * band * strength;
	COLOR = vec4(vec3(0.80, 0.94, 1.0), a);
}
