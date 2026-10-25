// What the glass's two shaders share (graphics/glazing.gd): how a pane of
// glass is written into the glazing's marks, and how it is read back.
//
// The marks are the world drawn again, as the normals are, into a float
// buffer that starts out empty. A pixel of it where a pane was drawn:
//
//   blue    that glass is there, GLASS_RELIEF times over — and which way it
//           faces by its sign: above nothing for glass that faces the eye,
//           clear glass or a back mirror; below it for a mirror whose face
//           meets the air across the picture.
//   red     the way from the pixel to what it shows, in pixels of the
//   green   picture, across and down, GLASS_STEP times over. For a mirror
//           across the picture always an odd number of pixels straight across
//           its nearest face; for a back mirror the same way for every pixel
//           of it, to whatever stands in front of it there; nothing for clear
//           glass.
//
// Everything else drawn into the marks draws its colours, as it would
// anywhere, and a colour is never more than 1: against GLASS_RELIEF, nothing.
// So what is drawn over a pane afterwards — whatever stands in front of the
// glass — wipes its mark out by as much as it covers it, and a mark half
// covered reads as half the glass it was (glass_cover). The way to what a
// mirror shows is written larger than a colour is for the same reason: half
// covered, it still reads true.

const float GLASS_RELIEF = 256.0;
const float GLASS_STEP = 16.0;

// A pixel of the marks: glass, a mirror or not, and the way from it to what it
// shows — nothing for clear glass, or a mirror with no face to show across.
vec4 glass_mark(bool mirror, vec2 to) {
	return vec4(to * GLASS_STEP, mirror ? -GLASS_RELIEF : GLASS_RELIEF, 1.0);
}

// How much of a pixel of the marks is glass, 0 to 1: none for a colour that
// was only drawn there.
float glass_cover(vec4 mark) {
	return clamp((abs(mark.b) - 1.0) / (GLASS_RELIEF - 1.0), 0.0, 1.0);
}

// Whether the glass there is a mirror whose face meets the air across the
// picture. Glass that faces the eye is clear unless it has a way to what it
// shows (glass_to): then it is a back mirror.
bool glass_mirror(vec4 mark) {
	return mark.b < 0.0;
}

// The way from a pixel of the marks to what the mirror there shows, in whole
// pixels of the picture: nothing for clear glass.
vec2 glass_to(vec4 mark) {
	float share = abs(mark.b) / GLASS_RELIEF;
	if (share <= 0.0) {
		return vec2(0.0);
	}
	return floor(mark.rg / (GLASS_STEP * share) + 0.5);
}
