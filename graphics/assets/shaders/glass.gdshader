shader_type canvas_item;
render_mode unshaded, blend_disabled;

#include "res://graphics/assets/shaders/glazing.gdshaderinc"

// What a pane of glass draws (graphics/glass.gd), into the glazing's marks and
// nowhere else: that it is glass, which kind, and for a mirror, the way from
// each of its pixels to what that pixel shows — across the nearest of the
// faces the pane was told of, as far beyond the face as the pixel is inside
// it, which is an odd number of pixels away: the pixel right under a floor's
// face shows the one right over it. A back mirror faces the eye, as clear
// glass does, and the way from each of its pixels to what it shows is the
// same for all of them: the pane's colour.
//
// Each pane is a quad whose UV is the pixel of the pane, from its top-left,
// and whose colour is where its faces are (Glass._draw): how far up from its
// first row the face above it lies, how far down from its first row the face
// below it, how far left of its first column the one to its left, and how far
// right of its first column the one to its right; less than nothing for none.
// It is drawn over what is behind it, not blended: a mark is a mark.

// Which kind of glass: 0 clear, 1 a mirror across its faces, 2 a back mirror
// (Glass.Kind).
uniform int kind = 0;

void fragment() {
	vec2 at = floor(UV);
	vec4 faces = COLOR;
	vec2 to = vec2(0.0);
	if (kind == 2) {
		to = floor(faces.xy + 0.5);
	} else if (kind == 1) {
		float nearest = 1.0e9;
		if (faces.x >= 0.0 && at.y + faces.x < nearest) {
			nearest = at.y + faces.x;
			to = vec2(0.0, -(2.0 * nearest + 1.0));
		}
		if (faces.y >= 0.0 && faces.y - at.y < nearest) {
			nearest = faces.y - at.y;
			to = vec2(0.0, 2.0 * nearest + 1.0);
		}
		if (faces.z >= 0.0 && at.x + faces.z < nearest) {
			nearest = at.x + faces.z;
			to = vec2(-(2.0 * nearest + 1.0), 0.0);
		}
		if (faces.w >= 0.0 && faces.w - at.x < nearest) {
			nearest = faces.w - at.x;
			to = vec2(2.0 * nearest + 1.0, 0.0);
		}
	}
	COLOR = glass_mark(kind == 1, to);
}
