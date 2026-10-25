shader_type canvas_item;
render_mode unshaded, blend_disabled;

#include "res://graphics/assets/shaders/glazing.gdshaderinc"

// The picture with the glass in it (graphics/glazing.gd): the last thing done
// to it before it is shown, over all of it, reading the picture as it came —
// lit, or as drawn — and the glazing's marks under each of its pixels.
//
// Where there is no glass the picture is as it came. Under clear glass, what
// is behind the glass is what the picture already has there, and it is shown
// a little tinted. Under a mirror, what the picture has across the mirror's
// face (glass_to) is shown over what the mirror itself was drawn as: most of
// it at the face, less the deeper into the mirror the pixel lies, and nothing
// past `mirror_deep`, or for what is off the picture altogether. Whatever stands
// in front of the glass has wiped its mark out, and is shown as it is.
//
// Under a back mirror, what it was drawn as, as clear glass would show it,
// and over that whatever stands in front of it the mirror's way off: read off
// the marks, which have everything the world draws in front of the back of the
// picture — and nothing behind any glass, which the glass's own mark covers —
// as its colours, and nothing where nothing was drawn. The back of the
// picture, a room's tile field, is not in them, and no back mirror shows it.
//
// Everything is read by whole pixels: both buffers are on the picture's grid.

uniform sampler2D picture : filter_nearest, repeat_disable;  // the picture as it came
uniform sampler2D marks : filter_nearest, repeat_disable;    // where the glass is (glazing.gdshaderinc)
// What clear glass does to what is seen through it; what a mirror does to what
// it shows, how much of that it shows at its face, and how deep into it, in
// pixels, that has faded to nothing. Set by the glazing (Glazing.CLEAR_TINT and
// the rest).
uniform vec3 clear_tint = vec3(1.0);
uniform vec3 mirror_tint = vec3(1.0);
uniform float mirror_shows = 0.0;
uniform float mirror_deep = 1.0;
// How much a back mirror shows of what stands in front of it.
uniform float back_shows = 0.0;

void fragment() {
	ivec2 here = ivec2(FRAGCOORD.xy);
	vec3 seen = texelFetch(picture, here, 0).rgb;
	vec4 mark = texelFetch(marks, here, 0);
	float cover = glass_cover(mark);
	vec3 glazed = seen;
	if (cover > 0.0) {
		vec2 to = glass_to(mark);
		ivec2 size = textureSize(picture, 0);
		ivec2 from = here + ivec2(to);
		bool on_it = all(greaterThanEqual(from, ivec2(0))) && all(lessThan(from, size));
		if (glass_mirror(mark)) {
			float shows = 0.0;
			if (to != vec2(0.0) && on_it) {
				float deep = (max(abs(to.x), abs(to.y)) - 1.0) * 0.5;
				shows = mirror_shows * (1.0 - clamp(deep / mirror_deep, 0.0, 1.0));
			}
			vec3 shown = texelFetch(picture, clamp(from, ivec2(0), size - ivec2(1)), 0).rgb;
			glazed = mix(seen, shown * mirror_tint, shows);
		} else {
			glazed = seen * clear_tint;
			if (to != vec2(0.0) && on_it) {
				// A back mirror: what stands in front of it, the colour drawn there
				// over nothing — as much of it as was drawn — and nothing where it
				// is only more glass.
				vec4 front = texelFetch(marks, from, 0);
				if (glass_cover(front) <= 0.0) {
					float stands = clamp(front.a, 0.0, 1.0) * back_shows;
					glazed = glazed * (1.0 - stands) + max(front.rgb, vec3(0.0)) * mirror_tint * back_shows;
				}
			}
		}
	}
	COLOR = vec4(mix(seen, glazed, cover), 1.0);
}
