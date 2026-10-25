shader_type canvas_item;
render_mode unshaded, blend_add, skip_vertex_transform;

// The shadow one light throws off the edges of what stands in it
// (graphics/shadow_caster.gd), after aarthificial's deferred lights and the
// shadow meshes of Unity's 2D renderer it takes them from: every edge is a
// strip with no width, two of its corners on the edge and two more on top of
// them, and all four know which way the edge faces. Here, for an edge that
// faces away from the light, the second two are pushed out from the light
// further than it reaches — and the strip is the shadow that edge throws. A
// sun's light comes all one way, so its shadows are thrown all that way.
//
// The video draws each caster's whole mesh, counts in the stencil buffer how
// many cover a pixel, and takes the caster's own sprite away again, so a
// thing is lit across its own face and dark only in another's shadow. The
// edges alone come to the same picture and need no counting: a strip starts
// at the edge the light leaves the thing by, so the thing itself is never in
// its own shadow, and a pixel is dark if any strip covers it at all.
//
// A canvas has no stencil buffer to mark, so the mark is a colour of a
// picture of its own (`Lighting`): one of its three to a lamp, added, so
// three lamps share a picture and none touches another's. It is marked SOLID
// (lighting.gdshaderinc), which says the light does not reach there at all,
// beside the shadows a body throws out of a round light's plane, which are
// marked by how dark they are (figure_shadow.gdshader).
//
// Rock throws its shadows this way in every light. A body throws them this
// way only in a spot's or a sun's: a point or an area is in front of it or
// behind it, and it throws its shadow on the wall or at its feet instead.

uniform vec2 light;                 // where the light is, in the world
uniform bool parallel = false;      // a sun's: thrown `aim`, wherever the edge is
uniform vec2 aim = vec2(0.0, 1.0);
uniform float reach = 4096.0;       // how far an edge's shadow is thrown: past anything the light could light
uniform vec3 channel = vec3(1.0, 0.0, 0.0);  // the light's colour of the mask, times SOLID

void vertex() {
	vec2 at = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	// The way the edge faces, which a caster keeps where a picture's corner
	// would keep its place in the texture; and in red, whether this corner is
	// one of the two that go.
	vec2 facing = normalize(mat2(MODEL_MATRIX[0].xy, MODEL_MATRIX[1].xy) * UV);
	vec2 from = at - light;
	vec2 way = parallel ? aim : from / max(length(from), 0.0001);
	if (COLOR.r > 0.5 && dot(way, facing) > 0.0) {
		at += way * reach;
	}
	VERTEX = at;
}

void fragment() {
	COLOR = vec4(channel, 1.0);
}
