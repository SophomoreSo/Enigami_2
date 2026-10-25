shader_type canvas_item;
render_mode unshaded;

#include "res://graphics/assets/shaders/lighting.gdshaderinc"

// Status colouring for actor sprites. `tint` multiplies (chill, burn, boss
// phase); `flash` blends the whole silhouette towards `flash_color` for hit
// flashes and telegraphs, which a plain modulate cannot do.
//
// And in the picture of the world's normals (`Lighting`), how the body faces:
// out at its edge, as if it were a slice of something round, so a lamp
// lights the side of it that is turned to it. As far as it is flashing it
// gives its own light instead — a blow, or a wind-up, reads in a dark room.

uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float flash : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	c.rgb *= tint.rgb;
	c.a *= tint.a;
	c.rgb = mix(c.rgb, flash_color.rgb, flash);
	if (drawing_normals(SCREEN_PIXEL_SIZE)) {
		vec2 facing;
		EDGE_FACING(TEXTURE, UV, REGION_RECT, facing)
		COLOR = normal_pixel(facing, flash, c.a);
	} else {
		COLOR = c;
	}
}
