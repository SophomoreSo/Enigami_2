shader_type canvas_item;
render_mode unshaded;

// Where a body stands in the picture (graphics/lighting.gd): its figure,
// solid where its picture is, in green that a body is there at all, and in red
// how far below each pixel of it its feet are, in world units. A body stands
// up off the floor from its feet, and is lit as the floor there is, wherever
// in the picture the rest of it is drawn (light.gdshader). The patch a body
// leaves on the floor darkens what is not a body.

// Where the body's feet are, down the world.
uniform float feet = 0.0;

varying float down_the_world;

void vertex() {
	down_the_world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).y;
}

void fragment() {
	if (texture(TEXTURE, UV).a < 0.5) {
		discard;
	}
	COLOR = vec4(feet - down_the_world, 1.0, 0.0, 1.0);
}
