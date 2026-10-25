shader_type canvas_item;
render_mode unshaded, blend_add;

// The patch of shadow a body leaves on the floor in a light
// (graphics/lighting.gd), marked in the light's own colour of a shadow mask
// the way shadow.gdshader marks what stops a light in it. What is marked is
// how dark the shadow is there — the draw's own colour, in red — and the light
// takes that share of itself off whatever is not a body (light.gdshader). A
// patch is drawn with no picture, so all of it is marked.

uniform vec3 channel = vec3(1.0, 0.0, 0.0);

varying float dark;

void vertex() {
	dark = COLOR.r;
}

void fragment() {
	if (texture(TEXTURE, UV).a < 0.5) {
		discard;
	}
	COLOR = vec4(channel * dark, 1.0);
}
