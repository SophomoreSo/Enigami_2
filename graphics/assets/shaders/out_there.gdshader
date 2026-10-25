shader_type canvas_item;
render_mode unshaded;

#include "res://graphics/assets/shaders/lighting.gdshaderinc"

// What is seen out past a room — the sky through its arches, the city through
// its glass (graphics/views/hideout_scenery.gd, `room`) — marked in the
// picture of the world's normals as giving its own light. So no lamp in the
// room lights it, and no darkness in the room dims it: it is lit as it is
// painted, and by whatever gives light out there with it (`Shine.out_there`).
// The air in front of it still catches a lamp's light, as the air does
// anywhere.
//
// Drawn over the whole room with the room itself as its texture: the room's
// walls drawn once, alone, on nothing. Out there is wherever they left open —
// where they drew nothing, or nothing more than half there.

void fragment() {
	if (texture(TEXTURE, UV).a > 0.5) {
		discard;
	}
	COLOR = out_there_pixel();
}
