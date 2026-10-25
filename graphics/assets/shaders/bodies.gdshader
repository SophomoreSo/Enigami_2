shader_type canvas_item;
render_mode unshaded;

// Where a body stands in the picture, and how far forward it is drawn among
// the lights (graphics/lighting.gd): its figure, solid where its picture is,
// in red how far forward — the draw's own colour — and in green that a body is
// there at all. They are drawn back to front, so where two overlap the one in
// front is what is kept. A round light drawn further back than the body at a
// pixel is behind it, and lights its rim and little of its face
// (light.gdshader).

varying float forward;

void vertex() {
	forward = COLOR.r;
}

void fragment() {
	if (texture(TEXTURE, UV).a < 0.5) {
		discard;
	}
	COLOR = vec4(forward, 1.0, 0.0, 1.0);
}
