shader_type spatial;
render_mode unshaded, depth_test_disabled;

uniform bool falloff_visible = false;

void fragment() {
	if (falloff_visible) {
		vec2 uv = (UV - 0.5) * 2.0;
		float t = max(abs(uv.x), abs(uv.y));
		float sample = smoothstep(1.0, 0.0, t);
		ALPHA = sample * 0.6;
	} else {
		ALPHA = 0.25;
	}
}