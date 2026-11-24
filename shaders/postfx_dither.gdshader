shader_type canvas_item;
// Full-screen retro filter: ordered Bayer dithering + per-channel posterization.

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform float color_levels = 16.0;       // levels per channel (16 = 4-bit)
uniform float dither_strength : hint_range(0.0, 2.0) = 1.0;
uniform bool use_8x8 = false;            // false = 4x4 matrix, true = 8x8
uniform float pixel_scale : hint_range(1.0, 4.0) = 1.0; // dither cell size in screen pixels

const float BAYER4[16] = float[16](
	0.0, 8.0, 2.0, 10.0,
	12.0, 4.0, 14.0, 6.0,
	3.0, 11.0, 1.0, 9.0,
	15.0, 7.0, 13.0, 5.0);

const float BAYER8[64] = float[64](
	0.0, 32.0, 8.0, 40.0, 2.0, 34.0, 10.0, 42.0,
	48.0, 16.0, 56.0, 24.0, 50.0, 18.0, 58.0, 26.0,
	12.0, 44.0, 4.0, 36.0, 14.0, 46.0, 6.0, 38.0,
	60.0, 28.0, 52.0, 20.0, 62.0, 30.0, 54.0, 22.0,
	3.0, 35.0, 11.0, 43.0, 1.0, 33.0, 9.0, 41.0,
	51.0, 19.0, 59.0, 27.0, 49.0, 17.0, 57.0, 25.0,
	15.0, 47.0, 7.0, 39.0, 13.0, 45.0, 5.0, 37.0,
	63.0, 31.0, 55.0, 23.0, 61.0, 29.0, 53.0, 21.0);

void fragment() {
	vec3 col = texture(screen_tex, SCREEN_UV).rgb;
	ivec2 p = ivec2(floor(FRAGCOORD.xy / pixel_scale));
	float threshold;
	if (use_8x8) {
		threshold = (BAYER8[(p.y % 8) * 8 + (p.x % 8)] + 0.5) / 64.0;
	} else {
		threshold = (BAYER4[(p.y % 4) * 4 + (p.x % 4)] + 0.5) / 16.0;
	}
	float steps = max(color_levels - 1.0, 1.0);
	vec3 q = floor(col * steps + 0.5 + (threshold - 0.5) * dither_strength) / steps;
	COLOR = vec4(clamp(q, 0.0, 1.0), 1.0);
}
