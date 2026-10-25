// What every shader that has to do with the light shares
// (graphics/lighting.gd): how to tell which of the world's two pictures is
// being drawn, and how a normal is written into the second and read back.
//
// The world is drawn twice, after aarthificial's deferred lights ("Deferred
// Lights - Pixel Renderer Devlog #1",
// https://www.youtube.com/watch?v=R6vQ9VmMz2w): once for its colours and once
// for its normals, the two textures of his g-buffer. He fills both in one
// pass. A canvas has one target, so here the second picture is a second
// viewport over the same world, and a shader with something to say in it has
// to ask which of the two it is drawing into. All a canvas shader is told
// about its viewport is how big a pixel of it is, so the buffer the normals
// are drawn into is one pixel wider than the picture and gives its size out
// as a global: a shader drawing into a viewport of exactly that size is
// drawing normals.
//
// A pixel of that buffer: R and G the way the surface faces across the
// picture, as long as it counts for — nothing for a surface that faces the
// eye and takes any light alike, 1 for an edge that is lit only from its own
// side. The video keeps how much a normal counts in blue; here that is how
// long the normal is, which leaves blue for something its picture has no
// place for: how much of its own light the pixel gives, 0 to 1. All three are
// written RELIEF times over. Most of what is drawn knows none of this and
// draws its colours into the buffer as it would anywhere, and a colour is
// never more than 1 — against RELIEF, nothing — so whatever says nothing is
// flat and lit, and whatever is drawn over a normal afterwards wipes it out
// by as much as it covers it.

// The size of the buffer the normals are drawn into, in pixels: nothing while
// no picture is being lit. Declared in project.godot.
global uniform vec2 normals_size;

const float RELIEF = 256.0;

// What a light's colour of a shadow mask is marked with where its light does
// not reach at all — rock in its way, or a body in a spot's or a sun's
// (shadow.gdshader). Under it, what is marked is how dark the shadow a body
// throws out of a round light's plane is there (figure_shadow.gdshader): no
// number of those ever adds up to it. `Lighting.SOLID` is the same number.
const float SOLID = 64.0;

// Whether this is the picture of the world's normals, for a fragment told
// its SCREEN_PIXEL_SIZE.
bool drawing_normals(vec2 screen_pixel_size) {
	return normals_size.x > 0.0
		&& all(lessThan(abs(1.0 / screen_pixel_size - normals_size), vec2(0.5)));
}

// A pixel of the normals: facing `facing` — no longer than 1 — giving `glow`
// of its own light, and `alpha` of it there at all.
vec4 normal_pixel(vec2 facing, float glow, float alpha) {
	return vec4(facing * (1.0 - glow) * RELIEF, glow * RELIEF, alpha);
}

// The way a pixel of the normals faces, no longer than 1: nothing for a
// colour that was only drawn there.
vec2 facing_of(vec4 pixel) {
	vec2 facing = pixel.rg / RELIEF;
	float counts = length(facing);
	if (counts < 0.02) {
		return vec2(0.0);
	}
	return facing * (min(counts, 1.0) / counts);
}

// How much of its own light a pixel of the normals gives: none for a colour
// that was only drawn there.
float glow_of(vec4 pixel) {
	return clamp((pixel.b - 1.0) / (RELIEF - 1.0), 0.0, 1.0);
}

// A pixel of the normals for what is seen out past a room — the sky through
// its arches (out_there.gdshader). To whatever is in the room it gives its
// own light, all of it: no lamp in the room lights it and no darkness in the
// room dims it. It says so twice over, which nothing else does, so a light
// that is out there with it can tell it from what gives its own light
// anywhere, and light it.
vec4 out_there_pixel() {
	return vec4(0.0, 0.0, 2.0 * RELIEF, 1.0);
}

// Whether a pixel of the normals is out past a room.
bool is_out_there(vec4 pixel) {
	return pixel.b > 1.5 * RELIEF;
}

// The way a sprite faces at `uv` of `picture`, as the video's meshes do with
// no normal map of their own: outward, as if the sprite were a slice of
// something round. Out is wherever nothing is drawn within two pixels — out
// of the `region` of the sheet the sprite is cut from as well as in a gap of
// its own — so a pixel of the edge faces out at its full length, the pixel
// behind it a little, and the middle of the sprite not at all. A limb a pixel
// or two wide has nothing on either side and faces the eye.
//
// Worked out in the texture's pixels and turned into the picture's, by how
// the texture lies across the picture here: a sprite turned round, or turned
// over, faces the way it is drawn.
//
// EDGE_FACING(picture, uv, region, facing) sets `facing`. It is a macro and
// not a function because what it reads is the sprite's own TEXTURE, and a
// shader that hands that to a function has the engine complain of it every
// time it is loaded with no screen to draw on — `--headless`, which is how
// most of the tests run. Everything in it that needs no texture is a
// function below.

// How much the pixel `o` away counts toward which way is out: nearer for
// more, and nothing past two pixels off.
vec2 out_toward(vec2 o) {
	float far = dot(o, o);
	if (far < 0.5 || far > 4.5) {
		return vec2(0.0);
	}
	return o / far;
}

// Whether nothing is drawn at the texture's pixel `at`, given how solid the
// texture is there: nothing ever is outside `lo` to `hi`, the sprite's own
// part of its sheet.
float nothing_at(float solid, vec2 at, vec2 lo, vec2 hi) {
	if (at.x < lo.x || at.y < lo.y || at.x >= hi.x || at.y >= hi.y) {
		return 1.0;
	}
	return 1.0 - step(0.5, solid);
}

// The way out of a sprite in its texture's pixels, `open`, as the way it
// faces across the picture: turned by how the texture lies there, and no
// longer than 1.
vec2 across_the_picture(vec2 open, vec2 uv, vec2 size) {
	mat2 across = mat2(dFdx(uv) * size, dFdy(uv) * size);
	if (abs(determinant(across)) < 0.000001) {
		return vec2(0.0);
	}
	vec2 out_of_it = inverse(across) * open;
	float counts = length(out_of_it);
	if (counts < 0.001) {
		return vec2(0.0);
	}
	return out_of_it / counts * min(counts * 0.5, 1.0);
}

#define EDGE_FACING(picture, uv, region, facing) \
	{ \
		vec2 ef_size = vec2(textureSize(picture, 0)); \
		vec2 ef_here = floor(uv * ef_size); \
		vec2 ef_lo = floor(region.xy * ef_size + 0.5); \
		vec2 ef_hi = ef_lo + floor(abs(region.zw) * ef_size + 0.5); \
		vec2 ef_open = vec2(0.0); \
		for (int ef_y = -2; ef_y <= 2; ef_y++) { \
			for (int ef_x = -2; ef_x <= 2; ef_x++) { \
				vec2 ef_at = ef_here + vec2(float(ef_x), float(ef_y)); \
				float ef_solid = texelFetch(picture, ivec2(clamp(ef_at, ef_lo, ef_hi - vec2(1.0))), 0).a; \
				ef_open += out_toward(ef_at - ef_here) * nothing_at(ef_solid, ef_at, ef_lo, ef_hi); \
			} \
		} \
		facing = across_the_picture(ef_open, uv, ef_size); \
	}
