shader_type canvas_item;

// How the world's picture is graded as it is shown (`PixelCamera`): what the
// state of the world does to how all of it looks, laid over the picture after
// the light and the glass.
//
// `slow` is time dilated (`TimeCtl`), the way Katana Zero's slow motion looks:
// the world sinks into a deep violet-to-cyan duotone by how bright each pixel
// is, the colours split a pixel apart along the row, and the corners go dark.
// What is bright or saturated — a body, a blast, a bolt in flight — keeps
// most of its own colour, so the fight stays readable while the place it is
// in, which is dark and grey, changes.
//
// `grey` is magic off (`Magic`): the colour drained out of the picture, by how
// bright each pixel is to the eye. It goes on last, over the slow, since magic
// off is the stronger of the two.
uniform float grey : hint_range(0.0, 1.0) = 0.0;
uniform float slow : hint_range(0.0, 1.0) = 0.0;

const vec3 LUMA = vec3(0.299, 0.587, 0.114);
// The duotone, dark to light: a near-black indigo, violet, and a pale cyan.
const vec3 DEEP = vec3(0.05, 0.03, 0.15);
const vec3 MID = vec3(0.24, 0.18, 0.62);
const vec3 HIGH = vec3(0.62, 0.96, 1.0);

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	if (slow > 0.0) {
		// The split is a whole pixel of the picture or none — half a pixel on
		// a nearest-sampled picture would flicker between the two as it eased.
		vec2 split = vec2(TEXTURE_PIXEL_SIZE.x * step(0.5, slow), 0.0);
		c.r = texture(TEXTURE, UV + split).r;
		c.b = texture(TEXTURE, UV - split).b;
		float lum = dot(c.rgb, LUMA);
		vec3 tone = lum < 0.5 ? mix(DEEP, MID, lum * 2.0) : mix(MID, HIGH, (lum - 0.5) * 2.0);
		float hi = max(max(c.r, c.g), c.b);
		float lo = min(min(c.r, c.g), c.b);
		float sat = hi > 0.0 ? (hi - lo) / hi : 0.0;
		float stands_out = clamp(max(sat * 1.6, (lum - 0.3) * 2.5), 0.0, 1.0);
		float hold = mix(0.92, 0.2, stands_out);
		c.rgb = mix(c.rgb, tone, slow * hold);
		vec2 d = (UV - 0.5) * vec2(1.0, 0.8);
		float corner = smoothstep(0.32, 0.8, length(d));
		c.rgb *= 1.0 - corner * 0.5 * slow;
	}
	float g = dot(c.rgb, LUMA);
	COLOR = vec4(mix(c.rgb, vec3(g), grey), c.a);
}
