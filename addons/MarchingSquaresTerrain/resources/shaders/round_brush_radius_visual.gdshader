shader_type spatial;
render_mode unshaded, depth_test_disabled;

uniform sampler2D curve_texture : source_color;

uniform bool falloff_visible = false;

void fragment() {
	if (falloff_visible) {
		float t = 1.0 - distance(vec2(UV.x, UV.y), vec2(0.25, 0.75)) * 4.0;
		float sample = texture(curve_texture, vec2(clamp(t, 0.01, 0.99), 0)).r;
		ALPHA = clamp(sample, 0.0, 1.0) * 0.6;
	} else {
		ALPHA = 0.25;
	}
}