shader_type canvas_item;
render_mode unshaded, blend_disabled;

// One step of the velocity buffer (graphics/velocity_buffer.gd), the way
// aarthificial's PixelGraphics runs it (`SimulateVelocity`, in
// Runtime/Shaders/VelocitySimulation.hlsl): every pixel a spring. R and G are
// how far the air at that pixel has been pushed, B and A how fast it is
// moving. Each step a pixel is blurred toward its four neighbours, so a push
// spreads and softens; pulled back toward rest by `stiffness` and slowed by
// `damping`; and then, wherever something moving covers it this step, its
// speed is that thing's — each way that thing is moving at all.
//
// Everything is read by whole pixels, with texelFetch: the buffer's grid is
// the world's, and nothing here ever falls between two pixels of it.
//
// The same shader keeps the step for the next one: with `keep` it copies
// `trail` as it is, into the viewport the next step reads.

uniform sampler2D trail : filter_nearest, repeat_disable;  // the buffer as the last step left it
uniform sampler2D emit : filter_nearest, repeat_disable;   // what moves through it now: speed in R and G, A wherever anything is
uniform bool keep = false;
uniform bool fresh = false;       // the buffer has just been made: what `trail` holds is nothing yet
uniform ivec2 shift;              // how far the grid has moved since the last step, in pixels
uniform float stiffness = 70.0;
uniform float damping = 3.0;
uniform float blur = 0.5;         // this step's share of the neighbours' average
uniform float dt = 0.0166;

vec4 was(ivec2 at, ivec2 size) {
	// A buffer just made — the window resized — holds whatever the driver left
	// in it, so its first step starts from still air; and one NaN would spread
	// through the whole of it, so none is ever read.
	if (fresh || at.x < 0 || at.y < 0 || at.x >= size.x || at.y >= size.y) {
		return vec4(0.0);
	}
	vec4 v = texelFetch(trail, at, 0);
	if (any(isnan(v)) || any(isinf(v))) {
		return vec4(0.0);
	}
	return v;
}

void fragment() {
	ivec2 size = textureSize(trail, 0);
	ivec2 here = ivec2(FRAGCOORD.xy);
	if (keep) {
		COLOR = was(here, size);
	} else {
		// Where this pixel of the world was on the grid the last step was taken
		// on, so what was pushed stays where it was pushed when the camera moves.
		ivec2 at = here + shift;
		vec4 now = was(at, size);
		vec4 near = was(at + ivec2(1, 0), size) + was(at - ivec2(1, 0), size)
			+ was(at + ivec2(0, 1), size) + was(at - ivec2(0, 1), size);
		now = mix(now, near * 0.25, blur);
		vec2 moved = now.xy;
		vec2 speed = now.zw;
		// The edge is held at rest, as the package's is: what goes off the
		// picture is let go of rather than echoed back in.
		if (here.x <= 0 || here.y <= 0 || here.x >= size.x - 1 || here.y >= size.y - 1) {
			moved = vec2(0.0);
			speed = vec2(0.0);
		}
		speed += (-moved * stiffness - speed * damping) * dt;
		moved += speed * dt;
		vec4 e = texelFetch(emit, here, 0);
		if (e.a > 0.0) {
			if (e.r != 0.0) {
				speed.x = e.r;
			}
			if (e.g != 0.0) {
				speed.y = e.g;
			}
		}
		COLOR = vec4(moved, speed);
	}
}
