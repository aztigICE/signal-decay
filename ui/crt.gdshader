shader_type canvas_item;
// Cheap CRT look for the terminal screen: scanlines + dark corners.

uniform float line_count = 300.0;
uniform float scanline_strength = 0.22;
uniform float vignette_strength = 0.65;

void fragment() {
	float s = 0.5 + 0.5 * sin(UV.y * line_count * 3.14159);
	float v = smoothstep(0.35, 0.78, distance(UV, vec2(0.5)));
	COLOR = vec4(0.0, 0.0, 0.0, scanline_strength * s + vignette_strength * v);
}
