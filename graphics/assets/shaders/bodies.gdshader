shader_type canvas_item;
render_mode unshaded;

// Where a body stands in the picture (graphics/lighting.gd): its figure,
// solid where its picture is, in green that a body is there at all. The patch
// a body leaves on the floor darkens what is not a body (light.gdshader).

void fragment() {
	if (texture(TEXTURE, UV).a < 0.5) {
		discard;
	}
	COLOR = vec4(1.0, 1.0, 0.0, 1.0);
}
