-- The heroes: who the player can play as. See "A hero" in README.md.
--
-- A row a hero, in the order they stand on the bench's screen, in a colour of
-- their own. Their names are `hud.heroes.name.<id>` in localization/. Each is
-- drawn from their own sprites once those are made — `prompt` is who they are,
-- for the tool their sprites are made with (graphics/assets/sprites/HEROES.md)
-- — and until then `sprite`, a character of the atlas, stands in for their
-- face. What each can do is to come.

-- `hands` is where each hero's hang pose puts its fist over the middle of the
-- body, in world units (twice the art's pixels): the player's own art holds a
-- rope at 30, and Legna Dennis, drawn taller, at 67.
INSERT INTO heroes (id, place, sprite, color, hands, prompt) VALUES
	('dren_repus', 1, 'doc', '#5ce0ff', 30,
		'a lanky young man in an oversized grey hoodie with the hood down, thick round glasses, messy dark hair, a satchel strap across the chest, worn sneakers, a nervous hunched stance'),
	('legna_dennis', 2, 'angel', '#ffd36b', 67,
		'a small girl with long pink hair tied with a dark ribbon, a dark dress with a white apron, pale skin, a fallen angel with a cold calm stance'),
	('reniart_lamina', 3, 'elf_m', '#7bf28a', 30,
		'a wiry animal trainer in a khaki safari jacket, a whistle on a cord round the neck, a coiled leash on the belt, tall boots, a wide-brim hat, an alert forward lean'),
	('sett_eragic', 4, 'wizzard_m', '#d98cff', 30,
		'a tired man in a long dark trench coat and a loosened tie, a cigarette glowing orange at his lips, slicked-back hair, hands in his pockets, a loose slouching stance');
