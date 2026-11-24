shader_type spatial;
render_mode unshaded;
// Diegetic monitor: shows a SubViewport through an RGB subpixel (LCD) mask.
// The mask fades out at a distance to avoid moire.

uniform sampler2D screen_tex : source_color, filter_linear;
uniform vec2 pixel_grid = vec2(160.0, 120.0);   // LCD pixels across / down
uniform float mask_strength : hint_range(0.0, 1.0) = 0.85;
uniform float brightness = 1.3;

void fragment() {
	vec3 col = texture(screen_tex, UV).rgb;
	vec2 g = UV * pixel_grid;
	vec2 cell = fract(g);
	float sub = floor(cell.x * 3.0);
	vec3 stripe = vec3(float(sub == 0.0), float(sub == 1.0), float(sub == 2.0));
	float row_gap = smoothstep(0.8, 0.95, cell.y);
	float k = mask_strength * (1.0 - smoothstep(0.6, 1.5, fwidth(g.x * 3.0)));
	vec3 mask = mix(vec3(1.0), stripe * 2.4 + 0.12, k) * (1.0 - 0.45 * row_gap * k);
	ALBEDO = col * mask * brightness;
}
