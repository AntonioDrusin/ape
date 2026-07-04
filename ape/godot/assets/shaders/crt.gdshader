shader_type canvas_item;

// Full-screen CRT post-process. Reads the finished frame via hint_screen_texture,
// so the node this runs on must draw after everything else — crt_overlay.tscn puts
// it on CanvasLayer 100; anything on a higher layer would escape the effect.
uniform sampler2D screen_tex : hint_screen_texture, filter_linear, repeat_disable;

uniform float warp_amount : hint_range(0.0, 0.3) = 0.1;
uniform float scanline_count : hint_range(50.0, 1080.0) = 240.0;
uniform float scanline_strength : hint_range(0.0, 1.0) = 0.22;
// All *_px uniforms are in reference pixels at a 648-tall window and are scaled
// with the actual window height, so the effect stays proportional on resize
// instead of thinning out to invisibility on a large window.
uniform float reference_height = 648.0;
uniform float edge_blur_px : hint_range(0.0, 8.0) = 2.5;
uniform float aberration_px : hint_range(0.0, 5.0) = 1.0;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.3;
uniform float mask_strength : hint_range(0.0, 1.0) = 0.08;
// Scanlines + mask darken the image overall; this compensates so the game
// doesn't read dimmer with the overlay on.
uniform float brightness : hint_range(0.5, 2.0) = 1.15;

// Barrel curvature: pulls sample coordinates outward toward the corners, so the
// image bulges like curved glass and the corners fall off-screen (drawn black below).
vec2 warp(vec2 uv) {
	vec2 cc = uv - 0.5;
	return 0.5 + cc * (1.0 + warp_amount * dot(cc, cc));
}

// Cheap 5-tap box blur; radius varies per pixel to fake the beam losing focus
// toward the tube edges (real CRTs defocused there, it wasn't just aberration).
vec3 sample_screen(vec2 uv, float radius_px, vec2 px) {
	vec3 col = texture(screen_tex, uv).rgb;
	if (radius_px > 0.05) {
		vec2 r = radius_px * px;
		col += texture(screen_tex, uv + r).rgb;
		col += texture(screen_tex, uv - r).rgb;
		col += texture(screen_tex, uv + vec2(r.x, -r.y)).rgb;
		col += texture(screen_tex, uv + vec2(-r.x, r.y)).rgb;
		col /= 5.0;
	}
	return col;
}

void fragment() {
	vec2 uv = warp(SCREEN_UV);

	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		COLOR = vec4(0.0, 0.0, 0.0, 1.0);
	} else {
		vec2 cc = uv - 0.5;
		// One reference pixel in UV space: 1/reference_height vertically, with the
		// aspect ratio folded into x so offsets stay square on screen.
		vec2 ref_px = vec2(SCREEN_PIXEL_SIZE.x / SCREEN_PIXEL_SIZE.y, 1.0) / reference_height;
		// 0 at screen center, 1 at the corners; squared below so the middle of
		// the screen stays sharp and the falloff piles up near the edges.
		float edge = clamp(dot(cc, cc) * 2.0, 0.0, 1.0);
		float blur_radius = edge_blur_px * edge * edge;

		// Slight convergence error: red/blue sampled a touch off along the radial
		// direction, growing with distance from center like a misaligned gun trio.
		vec2 ab = cc * aberration_px * 2.0 * ref_px;
		vec3 col;
		col.r = sample_screen(uv + ab, blur_radius, ref_px).r;
		col.g = sample_screen(uv, blur_radius, ref_px).g;
		col.b = sample_screen(uv - ab, blur_radius, ref_px).b;

		// Scanlines use the *warped* uv so they curve with the glass instead of
		// staying ruler-straight over a bulged image.
		float scan = 1.0 - scanline_strength * (0.5 + 0.5 * cos(uv.y * scanline_count * TAU));
		col *= scan;

		// Vertical RGB triad mask, one phosphor stripe per *reference* pixel column
		// (FRAGCOORD is physical pixels, so rescale to keep triad size proportional).
		float stripe = mod(FRAGCOORD.x * SCREEN_PIXEL_SIZE.y * reference_height, 3.0);
		vec3 mask = vec3(1.0 - mask_strength);
		if (stripe < 1.0) {
			mask.r = 1.0;
		} else if (stripe < 2.0) {
			mask.g = 1.0;
		} else {
			mask.b = 1.0;
		}
		col *= mask;

		col *= 1.0 - vignette_strength * edge;
		col *= brightness;

		// Soften the black border a couple of pixels so the curved edge isn't aliased.
		vec2 soft = ref_px * 2.0;
		float border = smoothstep(0.0, soft.x, uv.x) * smoothstep(1.0, 1.0 - soft.x, uv.x)
			* smoothstep(0.0, soft.y, uv.y) * smoothstep(1.0, 1.0 - soft.y, uv.y);
		col *= border;

		COLOR = vec4(col, 1.0);
	}
}
