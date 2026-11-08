shader_type canvas_item;

// 角色/敌人走到高物件后方时，在物件上开一个跟随目标的圆形透明窗口，
// 让玩家能看到被挡住的角色、敌人和物件后面的场景。
//
// 每个可透视目标用一个 vec4 描述：
//   xy = 圆形窗口中心（画布坐标）
//   z  = 目标脚底深度（用于判断目标是否位于物件后方）
//   w  = 该目标的窗口半径

const int MAX_REVEALS = 16;

uniform vec4 reveals[16];
uniform float prop_z = 0.0;
uniform float reveal_softness = 10.0;
uniform float reveal_alpha : hint_range(0.0, 1.0) = 0.08;

varying vec2 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec4 color = texture(TEXTURE, UV);
	float reveal = 0.0;
	for (int i = 0; i < MAX_REVEALS; i++) {
		vec4 target = reveals[i];
		// 只有目标脚底高于物件落地点（目标在物件后方）时才开窗。
		if (target.z < prop_z) {
			float dist = distance(world_pos, target.xy);
			reveal = max(reveal, 1.0 - smoothstep(target.w - reveal_softness, target.w + reveal_softness, dist));
		}
	}
	color.a *= mix(1.0, reveal_alpha, reveal);
	COLOR = color;
}
