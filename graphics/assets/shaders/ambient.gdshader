shader_type canvas_item;
render_mode unshaded, blend_disabled;

#include "res://graphics/assets/shaders/lighting.gdshaderinc"

// The light there is with no lamp lit (graphics/lighting.gd): the video's
// global light, which covers the whole picture and is the same everywhere —
// no falling off, and nothing to do with which way anything faces. It is the
// first thing drawn into the picture the lamps add to, over all of it: every
// colour the world drew, times this.
//
// What gives its own light is drawn as it is, however dark the room.

uniform sampler2D base : filter_nearest, repeat_disable;     // the world's colours
uniform sampler2D normals : filter_nearest, repeat_disable;  // and how it faces (lighting.gdshaderinc)
uniform vec3 ambient = vec3(1.0);

void fragment() {
	ivec2 here = ivec2(FRAGCOORD.xy);
	float glow = glow_of(texelFetch(normals, here, 0));
	COLOR = vec4(texelFetch(base, here, 0).rgb * mix(ambient, vec3(1.0), glow), 1.0);
}
