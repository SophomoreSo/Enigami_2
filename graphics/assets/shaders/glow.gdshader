shader_type canvas_item;
render_mode unshaded;

#include "res://graphics/assets/shaders/lighting.gdshaderinc"

// Something that gives its own light (`Lighting.glow`): a bolt, a spark, a
// number floating off a blow, a bar of health. In the world's picture it is
// drawn as anything is. In the picture of the world's normals it says so, as
// solidly as it is drawn, and the light leaves it as it is: no lamp makes it
// brighter and no dark room dims it.

void fragment() {
	if (drawing_normals(SCREEN_PIXEL_SIZE)) {
		COLOR = normal_pixel(vec2(0.0), 1.0, COLOR.a);
	}
}
