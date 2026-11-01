shader_type canvas_item;
render_mode unshaded, blend_add;

#include "res://graphics/assets/shaders/lighting.gdshaderinc"

// One light (graphics/shine.gd), drawn the way aarthificial's deferred lights
// are: as a mesh over everything it can reach that looks up what the world
// has already drawn under each of its pixels and adds that colour, lit, to the
// picture. Light adds, so every light is its own pass over the same two
// textures and none has to know of another.
//
// How bright a pixel is under it is the video's four things multiplied: how
// bright the light is; how far off the pixel is; how far off the way the light
// points it is, for one that does not shine all round; and whether the
// surface there faces the light at all, which is what the normals are for.
// Times the light's colour, that is the light; times the colour the world drew
// there, what is added. A pixel that gives its own light takes none; nor does
// one out past a room (`is_out_there`), unless this light is out there too.
//
// What "how far off" is depends on the light's type, which is Blender's:
//
//   point  from the edge of a ball `radius` round it, out to `reach` past it
//   spot   the same, in a cone `cone` either side of `aim`, fading to the
//          cone's edge over `blend` of it
//   area   from the edge of a shape — a rectangle or an ellipse, `extent`
//          either way of its middle in its own frame, which shines down its
//          own y — out to `reach`, and inside `spread` either side of the way
//          it shines
//   sun    nothing at all: the same light everywhere, travelling `aim`
//
// And the video's volume: a share of the light added whatever is under it, as
// fog or dust in front of the picture would catch it, so a light shows in
// empty air. What a surface faces is nothing to the air in front of it, so
// the normals are left out of that share.
//
// A shadow is not a fifth thing to multiply by. A pixel in this light's
// shadow is not drawn at all, the way the video's stencil test drops it:
// neither the surface there nor the air in front of it is lit. The video
// marks shadows in the stencil buffer; a canvas has none to write to, so they
// are marked in a picture of their own (shadow.gdshader), one of its colours
// to a light.
//
// A body stands on the floor the light is on, and is lit across its face as
// the rock is. It stands up off that floor from its feet, so all of it is as
// far from the light as its feet are: a body whose head is drawn over a pool
// of light it is not standing in is not lit by it, and one standing at the far
// edge of a pool is lit to the top of its head (`bodies`, which says how far
// below each pixel of a body its feet are). It leaves a patch of shadow on
// the floor from its feet, away
// from the light (figure_shadow.gdshader), marked in the same colour of the
// mask as the rock's shadows, by how dark it is, and darkening whatever is
// there but a body (`bodies`) by that much.
//
// Everything is read by whole pixels: every buffer is on the picture's grid.

uniform sampler2D base : filter_nearest, repeat_disable;     // the world's colours
uniform sampler2D normals : filter_nearest, repeat_disable;  // and how it faces (lighting.gdshaderinc)
uniform sampler2D shade : filter_nearest, repeat_disable;    // where the lights that throw shadows do not reach
uniform vec3 channel = vec3(0.0);   // which of `shade`'s colours is this light's; none for one that throws no shadow
uniform sampler2D bodies : filter_nearest, repeat_disable;   // where a body stands, and how far below its feet are (bodies.gdshader)
uniform int type = 0;               // Shine.Type: 0 point, 1 sun, 2 spot, 3 area
uniform vec3 tint = vec3(1.0);
uniform float power = 1.0;
uniform vec2 half_size = vec2(1.0); // what the mesh's -1 to 1 is, in world units, in its own frame
uniform vec2 lift = vec2(0.0);      // where the mesh's middle is from the light, in its own frame: up the world, over the bodies standing in it
uniform vec2 turn = vec2(1.0, 0.0); // how the mesh's frame is turned in the world: its cosine and sine
uniform float radius = 0.0;
uniform float reach = 160.0;
uniform float falloff = 2.0;
uniform vec2 aim = vec2(0.0, 1.0);  // point, spot, sun: the way it shines, in the world
uniform float cone = 0.4;           // spot: half its cone, in radians
uniform float blend = 0.15;         // spot: the share of that it fades over
uniform int shape = 0;              // area: Shine.Shape, 0 rectangle, 1 ellipse
uniform vec2 extent = vec2(16.0, 2.0);  // area: half the shape each way, in its own frame
uniform float spread = 3.1416;      // area: half the angle it leaves the shape over, in radians
uniform float volume = 0.0;
uniform float close = 12.0;         // how near, in world units, what a surface faces starts to count for less
uniform bool beyond = false;        // whether the light is out past a room, and lights what is out there with it

// Where this pixel is from the light, in world units, in the mesh's own frame.
varying vec2 local;

void vertex() {
	local = VERTEX * half_size + lift;
}

// A way in the mesh's own frame, in the world's.
vec2 in_world(vec2 v) {
	return vec2(v.x * turn.x - v.y * turn.y, v.x * turn.y + v.y * turn.x);
}

// A way in the world, in the mesh's own frame.
vec2 in_frame(vec2 v) {
	return vec2(v.x * turn.x + v.y * turn.y, -v.x * turn.y + v.y * turn.x);
}

// 1 well inside `edge`, 0 past it, easing down over the last `soft` of it.
float inside(float off, float edge, float soft) {
	float fade = max(edge * soft, 0.0001);
	return 1.0 - smoothstep(edge - fade, edge, off);
}

void fragment() {
	ivec2 here = ivec2(FRAGCOORD.xy);
	float marked = dot(texelFetch(shade, here, 0).rgb, channel);
	if (marked >= SOLID * 0.5) {
		discard;
	}
	vec4 body = texelFetch(bodies, here, 0);
	bool on_body = body.g > 0.5;
	// The patch a body leaves on the floor falls on what is not a body.
	float shaded = on_body ? 0.0 : clamp(marked, 0.0, 1.0);
	// Where on the floor this is: here, or for a body, the feet it stands on.
	vec2 at = on_body ? local + in_frame(vec2(0.0, body.r)) : local;
	float lit = power;
	// The way to the light from here, in the world; nothing for a pixel inside
	// what gives it, which is lit from every way at once.
	vec2 toward = -aim;
	// How far what gives the light is from here.
	float away = 1.0e6;
	if (type == 1) {
		// A sun: no distance to it, and no falling off.
	} else if (type == 3) {
		vec2 near;
		if (shape == 1) {
			vec2 p = at / max(extent, vec2(0.0001));
			near = dot(p, p) <= 1.0 ? at : extent * normalize(p);
		} else {
			near = clamp(at, -extent, extent);
		}
		vec2 out_of_it = at - near;
		away = length(out_of_it);
		if (away >= reach) {
			discard;
		}
		lit *= pow(1.0 - away / reach, falloff);
		toward = vec2(0.0);
		if (away > 0.001) {
			if (spread < 3.1415) {
				lit *= inside(acos(clamp(out_of_it.y / away, -1.0, 1.0)), spread, 0.15);
			}
			toward = in_world(-out_of_it / away);
		}
	} else {
		float far = length(at);
		away = max(far - radius, 0.0);
		if (away >= reach) {
			discard;
		}
		lit *= pow(1.0 - away / reach, falloff);
		toward = vec2(0.0);
		if (far > 0.001) {
			vec2 out_from_it = at / far;
			if (type == 2) {
				lit *= inside(acos(clamp(dot(out_from_it, aim), -1.0, 1.0)), cone, blend);
			}
			toward = -out_from_it;
		}
	}
	if (lit <= 0.0) {
		discard;
	}
	vec4 surface = texelFetch(normals, here, 0);
	vec2 facing = facing_of(surface);
	// Right under a light the way to it turns right round from one pixel to
	// the next, so what a surface faces fades out there. A sun is never near.
	float close_by = type == 1 ? 1.0 : clamp(away / max(close, 0.0001), 0.0, 1.0);
	float own = beyond && is_out_there(surface) ? 0.0 : glow_of(surface);
	vec3 colour = texelFetch(base, here, 0).rgb;
	float counts = length(facing) * close_by;
	float faced = 1.0;
	if (counts > 0.0 && dot(toward, toward) > 0.25) {
		faced = 1.0 - counts * (1.0 - clamp(dot(toward, normalize(facing)), 0.0, 1.0));
	}
	COLOR = vec4(tint * lit * (colour * faced * (1.0 - own) + volume) * (1.0 - shaded), 1.0);
}
