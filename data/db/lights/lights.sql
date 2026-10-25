-- The light each kind of shining thing gives. See "A light" in README.md.
-- The numbers are `Shine`'s (graphics/shine.gd): change one here and rebuild,
-- and every shining thing of that kind lights the picture that way. A new kind
-- is a row here, and the thing that gives it naming it (`Shine.give`).

-- ---- what the map creator puts about a map ----------------------------------
-- (graphics/views/made_room_view.gd)

-- A lantern: paper round a flame, hung on a cord, lighting the room round it
-- as it swings. Its light is a little under the pixel it hangs by.
INSERT INTO lights (id, type, color, power, reach, volume, shadows, y) VALUES
	('lantern', 'point', '#ffc257', 2.0, 140, 0.16, 1, 10);

-- A fire on the ground, wavering.
INSERT INTO lights (id, type, color, power, reach, volume, shadows, flicker) VALUES
	('fire', 'point', '#ff9e42', 2.45, 180, 0.08, 1, 0.08);

-- Glowing caps, and the fireflies over a cell: a little light of their own,
-- and no shadow of anything.
INSERT INTO lights (id, type, color, power, reach, volume, shadows) VALUES
	('mushrooms', 'point', '#5cf5e6', 1.0, 64, 0.04, 0),
	('fireflies', 'point', '#d1ff73', 0.6, 48, 0.02, 0);

-- A lightbulb under its shade, hung on a cord: a cone down out of the shade,
-- soft at its edge.
INSERT INTO lights (id, type, color, power, radius, reach, direction, spot_size, spot_blend, volume, shadows, y) VALUES
	('lightbulb', 'spot', '#ffe9bd', 2.2, 2, 220, 90, 110, 0.35, 0.1, 1, 12);

-- A fireplace: the mouth of the fire, a shape of light all round, wavering.
INSERT INTO lights (id, type, color, power, reach, size_x, size_y, direction, spread, volume, shadows, flicker, y) VALUES
	('fireplace', 'area', '#ff8a3d', 2.2, 190, 18, 10, 270, 360, 0.06, 1, 0.15, -12);

-- ---- the hideout's looks, and the dragon test's tower -----------------------
-- (graphics/views/hideout_*.gd, graphics/views/tower_view.gd). What is painted
-- glowing gives light too: a look puts each where it is painted, tints it its
-- own colour where it has one, and brightens and dims it as the picture does
-- — a tube on its way out, a station lit for somebody standing at it.

-- A torch on a pier, and the braziers at a gate: fire, wavering.
INSERT INTO lights (id, type, color, power, reach, volume, shadows, flicker) VALUES
	('torch', 'point', '#ff8f2e', 1.4, 150, 0.08, 1, 0.15),
	('brazier', 'point', '#ff8f2e', 1.6, 160, 0.08, 1, 0.15);

-- A ring of candles on its chain, and one candle on its own.
INSERT INTO lights (id, type, color, power, reach, volume, shadows, flicker) VALUES
	('candles', 'point', '#ffb35c', 1.2, 140, 0.06, 1, 0.10),
	('candle', 'point', '#ffbf6b', 0.8, 60, 0.03, 0, 0.12);

-- A lamp on a chain under the brass terrace's arches: its glass a little under
-- the pixel it hangs by.
INSERT INTO lights (id, type, color, power, reach, volume, shadows, y) VALUES
	('lamp', 'point', '#ffe085', 1.4, 150, 0.06, 1, 13);

-- A window lit from inside, small and warm; a crystal glowing; what a gate
-- gives while it is lit, in the colour of whether it would let you through.
INSERT INTO lights (id, type, color, power, reach, volume, shadows, flicker) VALUES
	('lit_window', 'point', '#ffc257', 0.6, 60, 0.04, 0, 0.10),
	('crystal', 'point', '#5c9eff', 0.8, 70, 0.06, 0, 0),
	('gate_light', 'point', '#59ff9e', 0.9, 130, 0.08, 0, 0);

-- Moonlight through a window: the window's sill, shining down the slant the
-- shafts painted under it lean at.
INSERT INTO lights (id, type, color, power, reach, size_x, size_y, direction, spread, volume, shadows) VALUES
	('moonlight', 'area', '#8fb3ff', 0.55, 240, 104, 4, 70.7, 40, 0.05, 0);

-- A fluorescent tube under a ceiling, and a panel of light set in one: down.
INSERT INTO lights (id, type, color, power, reach, size_x, size_y, direction, spread, volume, shadows) VALUES
	('ceiling_tube', 'area', '#cdf2ff', 0.9, 170, 36, 2, 90, 150, 0.04, 1),
	('light_panel', 'area', '#e0f7ff', 0.9, 200, 88, 8, 90, 140, 0.04, 1);

-- Neon: a sign, its board all round; a strip of it along a wall or under an
-- awning; and a screen. Each is given its own colour and size where it is put.
INSERT INTO lights (id, type, color, power, reach, size_x, size_y, spread, volume, shadows) VALUES
	('neon_sign', 'area', '#ff3d9e', 0.8, 110, 20, 40, 360, 0.10, 0),
	('neon_strip', 'area', '#a361ff', 0.7, 80, 64, 2, 360, 0.05, 0),
	('screen', 'area', '#40f2ff', 0.5, 60, 28, 16, 360, 0.04, 0),
	('exit_sign', 'area', '#59ff8c', 0.7, 80, 36, 14, 360, 0.06, 0);

-- A lamp under the tower's ceiling: a cone down out of its shade, soft at its
-- edge.
INSERT INTO lights (id, type, color, power, radius, reach, direction, spot_size, spot_blend, volume, shadows) VALUES
	('ceiling_lamp', 'spot', '#ffcc85', 1.4, 8, 230, 90, 55, 0.45, 0.08, 1);
