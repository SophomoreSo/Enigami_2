shader_type canvas_item;
render_mode unshaded, blend_add;

// The shadow a body throws out of a round light's plane (graphics/lighting.gd),
// marked in the light's own colour of a shadow mask the way shadow.gdshader
// marks what stops a light in it: the body's figure, thrown onto the wall
// behind it by a light in front of it, or the patch at its feet a light behind
// it leaves. What is marked is how dark the shadow is there — the draw's own
// colour, in red — and the light takes that share of itself off whatever is
// not a body (light.gdshader). A figure's picture marks only where it is
// solid; a patch, drawn with no picture, all of it.

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
