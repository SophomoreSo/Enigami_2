shader_type canvas_item;
render_mode unshaded;

// Foliage that sways in the wind and bends where something has moved through
// it, for `Foliage` (graphics/foliage.gd): aarthificial's pixel-art foliage
// shaders, from his PixelGraphics package (`grass_pixelart_shader` and
// `foliage_pixelart_shader`).
//
// The picture is never stretched. Each of its pixels is drawn from the pixel
// some whole number of pixels away — how far, the push the velocity buffer
// holds at that spot of the world plus the wind there, each weighed by the
// mask — so a blade leans as a staircase of whole pixels, the way it would be
// drawn by hand, and a pixel never lands between two.
//
// `any_way` is which of the package's two shaders this is. Off, grass: back
// and forth along the ground, the tip coming down as it leans, the way a blade
// pushed over is shorter. On, a bush: whichever way it is pushed.
//
// How far the tip comes down is not the package's. It drops the tip by
// (1 - cos(PI d)) / 2 of the push for a push of d, which is right while the
// push is about a plant's own height and lays a blade flat the moment it leans
// at all once the push is bigger — and here it is bigger, so a run through the
// grass reads at a glance. So the tip keeps its length instead: it leans on a
// circle round its root, and lies flat only once it has gone its whole height
// across. And a pixel moves by the nearest whole number of pixels, where the
// package's posterize floors — which moves it a whole pixel left for the
// faintest push that way, and not at all for the same push right.

// The velocity buffer (graphics/velocity_buffer.gd), as it hands itself to
// every shader: where the air at each pixel has been pushed to in R and G, the
// world rect it covers — nothing at all while its width is 0 — and the world's
// own clock, which stops with the game and slows with it.
global uniform sampler2D velocity_buffer;
global uniform vec4 velocity_area;
global uniform float velocity_time;

// How far each pixel may move, 0 to 1: R by a push, G by the wind. The base of
// a plant is 0 and does not move; its tip is 1.
uniform sampler2D mask : filter_nearest, repeat_disable;
uniform bool any_way = false;
uniform float push = 5.0;          // pixels a full push moves a pixel the mask lets go entirely
uniform float wind = 1.5;          // pixels the wind sways one
uniform float tall = 8.0;          // the tallest plant's height, in pixels: how far a tip has to come down to lie flat
uniform float reach = 8.0;         // the most any pixel moves either way: the clear margin round the picture
uniform float pixel = 2.0;         // world units to a pixel of the picture, and of the buffer
uniform vec2 wind_velocity = vec2(40.0, 0.0);   // which way the wind blows, and how fast, in world units a second
uniform float gust = 96.0;         // world units across a gust

varying vec2 world;
varying vec4 tint;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	tint = COLOR;
}

// Simplex noise in three dimensions, the package's wind: webgl-noise by Ian
// McEwan, Ashima Arts (MIT licence, https://github.com/ashima/webgl-noise),
// the same function its SimplexNoise3D.hlsl ports. About -1 to 1.
vec3 mod289_3(vec3 x) {
	return x - floor(x * (1.0 / 289.0)) * 289.0;
}

vec4 mod289_4(vec4 x) {
	return x - floor(x * (1.0 / 289.0)) * 289.0;
}

vec4 permute(vec4 x) {
	return mod289_4(((x * 34.0) + 1.0) * x);
}

vec4 taylor_inv_sqrt(vec4 r) {
	return 1.79284291400159 - 0.85373472095314 * r;
}

float snoise(vec3 v) {
	const vec2 C = vec2(1.0 / 6.0, 1.0 / 3.0);
	const vec4 D = vec4(0.0, 0.5, 1.0, 2.0);
	vec3 i = floor(v + dot(v, C.yyy));
	vec3 x0 = v - i + dot(i, C.xxx);
	vec3 g = step(x0.yzx, x0.xyz);
	vec3 l = 1.0 - g;
	vec3 i1 = min(g.xyz, l.zxy);
	vec3 i2 = max(g.xyz, l.zxy);
	vec3 x1 = x0 - i1 + C.xxx;
	vec3 x2 = x0 - i2 + C.yyy;
	vec3 x3 = x0 - D.yyy;
	i = mod289_3(i);
	vec4 p = permute(permute(permute(
			i.z + vec4(0.0, i1.z, i2.z, 1.0))
			+ i.y + vec4(0.0, i1.y, i2.y, 1.0))
			+ i.x + vec4(0.0, i1.x, i2.x, 1.0));
	float n_ = 0.142857142857;
	vec3 ns = n_ * D.wyz - D.xzx;
	vec4 j = p - 49.0 * floor(p * ns.z * ns.z);
	vec4 x_ = floor(j * ns.z);
	vec4 y_ = floor(j - 7.0 * x_);
	vec4 x = x_ * ns.x + ns.yyyy;
	vec4 y = y_ * ns.x + ns.yyyy;
	vec4 h = 1.0 - abs(x) - abs(y);
	vec4 b0 = vec4(x.xy, y.xy);
	vec4 b1 = vec4(x.zw, y.zw);
	vec4 s0 = floor(b0) * 2.0 + 1.0;
	vec4 s1 = floor(b1) * 2.0 + 1.0;
	vec4 sh = -step(h, vec4(0.0));
	vec4 a0 = b0.xzyw + s0.xzyw * sh.xxyy;
	vec4 a1 = b1.xzyw + s1.xzyw * sh.zzww;
	vec3 p0 = vec3(a0.xy, h.x);
	vec3 p1 = vec3(a0.zw, h.y);
	vec3 p2 = vec3(a1.xy, h.z);
	vec3 p3 = vec3(a1.zw, h.w);
	vec4 norm = taylor_inv_sqrt(vec4(dot(p0, p0), dot(p1, p1), dot(p2, p2), dot(p3, p3)));
	p0 *= norm.x;
	p1 *= norm.y;
	p2 *= norm.z;
	p3 *= norm.w;
	vec4 m = max(0.6 - vec4(dot(x0, x0), dot(x1, x1), dot(x2, x2), dot(x3, x3)), 0.0);
	m = m * m;
	return 42.0 * dot(m * m, vec4(dot(p0, x0), dot(p1, x1), dot(p2, x2), dot(p3, x3)));
}

// How a blade's tip gives to being moved `across` pixels: across by all of
// it, and down by as much as a tip `tall` from its root comes down going that
// far round it.
vec2 lean(float across) {
	float b = clamp(across / tall, -1.0, 1.0);
	return vec2(across, tall * (1.0 - sqrt(1.0 - b * b)));
}

void fragment() {
	vec2 size = vec2(textureSize(TEXTURE, 0));
	vec2 texel = floor(UV * size);
	vec4 weight = texelFetch(mask, ivec2(texel), 0);
	// This pixel's place on the world's grid, which the buffer shares.
	vec2 spot = floor(world / pixel);
	vec2 pushed = vec2(0.0);
	if (velocity_area.z > 0.0) {
		ivec2 b = ivec2(spot - floor(velocity_area.xy / pixel));
		ivec2 cover = ivec2(velocity_area.zw / pixel);
		if (b.x >= 0 && b.y >= 0 && b.x < cover.x && b.y < cover.y) {
			pushed = texelFetch(velocity_buffer, b, 0).xy;
		}
	}
	vec3 air = vec3((spot * pixel + wind_velocity * velocity_time) / gust, 0.0);
	float n = snoise(air);
	vec2 by_push;
	vec2 by_wind;
	if (any_way) {
		by_push = push * pushed;
		by_wind = wind * vec2(n, snoise(air + vec3(0.0, 0.0, 10.0)));
	} else {
		by_push = lean(push * pushed.x);
		by_wind = lean(wind * n);
	}
	vec2 offset = clamp(floor(weight.r * by_push + weight.g * by_wind + 0.5), vec2(-reach), vec2(reach));
	vec2 from = texel - offset;
	if (from.x < 0.0 || from.y < 0.0 || from.x >= size.x || from.y >= size.y) {
		COLOR = vec4(0.0);
	} else {
		COLOR = texelFetch(TEXTURE, ivec2(from), 0) * tint;
	}
}
