-- The map `moonlit_grove`, as the map creator saved it (feature/world/maps.gd).
-- What is in one is data/db/README.md's **A map**.

INSERT INTO maps (id, tileset, region, width, height) VALUES
	('moonlit_grove', 'grove', 0, 40, 22);

INSERT INTO map_layers (map_id, layer, level, reference) VALUES
	('moonlit_grove', 'back', 0, NULL),
	('moonlit_grove', 'plan', 1, NULL),
	('moonlit_grove', 'dressing', 2, NULL);

-- back
INSERT INTO map_rows (map_id, layer, y, cells) VALUES
	('moonlit_grove', 'back', 0, '........................................'),
	('moonlit_grove', 'back', 1, '........................................'),
	('moonlit_grove', 'back', 2, '................................!!!!!!!.'),
	('moonlit_grove', 'back', 3, '................................!!!!!!!.'),
	('moonlit_grove', 'back', 4, '.................-----------....!!!!!!!.'),
	('moonlit_grove', 'back', 5, '..................|.......|.....!!!!!!!.'),
	('moonlit_grove', 'back', 6, '..........|.......|.......|.....!!!!!!!.'),
	('moonlit_grove', 'back', 7, '..........|.......|.......|.....!!!!!!!.'),
	('moonlit_grove', 'back', 8, '..........|.......|.......|.....!!!!!!!.'),
	('moonlit_grove', 'back', 9, '..........|.......|.......|.....!!!!!!!.'),
	('moonlit_grove', 'back', 10, '..........|.......|.......|.....!!!!!!!.'),
	('moonlit_grove', 'back', 11, '..........|.......|.......|.....!!!!!!!.'),
	('moonlit_grove', 'back', 12, '..........|.......|.......|.....!!!!!!!.'),
	('moonlit_grove', 'back', 13, '..........|.......|.......|.....!!!!!!!.'),
	('moonlit_grove', 'back', 14, '..========|=======|=======|=====!!!!!!!.'),
	('moonlit_grove', 'back', 15, '..........|.......|.......|.....!!!!!!!.'),
	('moonlit_grove', 'back', 16, '..........|.......|.......|.....!!!!!!!.'),
	('moonlit_grove', 'back', 17, '..........|.......|.......|.....!!!!!!!.'),
	('moonlit_grove', 'back', 18, '...~~..~..|..~~~..|...~~..|..~..!!!!!!!.'),
	('moonlit_grove', 'back', 19, '..~~~~~~~~|~~~~~~~|~~~~~~~|~~~~~!!!!!!!.'),
	('moonlit_grove', 'back', 20, '........................................'),
	('moonlit_grove', 'back', 21, '........................................');

-- plan
INSERT INTO map_rows (map_id, layer, y, cells) VALUES
	('moonlit_grove', 'plan', 0, '****************************************'),
	('moonlit_grove', 'plan', 1, '||*****.....****.....****.....*********|'),
	('moonlit_grove', 'plan', 2, '||.....................................|'),
	('moonlit_grove', 'plan', 3, '||.....................................|'),
	('moonlit_grove', 'plan', 4, '||.....................................|'),
	('moonlit_grove', 'plan', 5, '||.....................................|'),
	('moonlit_grove', 'plan', 6, '||.....................................|'),
	('moonlit_grove', 'plan', 7, '||.....................................|'),
	('moonlit_grove', 'plan', 8, '||.....................................|'),
	('moonlit_grove', 'plan', 9, '||.....................................|'),
	('moonlit_grove', 'plan', 10, '||.....................................|'),
	('moonlit_grove', 'plan', 11, '||.....................................|'),
	('moonlit_grove', 'plan', 12, '||.....................................|'),
	('moonlit_grove', 'plan', 13, '||.....................................|'),
	('moonlit_grove', 'plan', 14, '||.....................................|'),
	('moonlit_grove', 'plan', 15, '||.....................................|'),
	('moonlit_grove', 'plan', 16, '||.....................................|'),
	('moonlit_grove', 'plan', 17, '||.....................................|'),
	('moonlit_grove', 'plan', 18, '||.....................................|'),
	('moonlit_grove', 'plan', 19, '||...P.................................|'),
	('moonlit_grove', 'plan', 20, '%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%'),
	('moonlit_grove', 'plan', 21, '%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%');

-- dressing
INSERT INTO map_rows (map_id, layer, y, cells) VALUES
	('moonlit_grove', 'dressing', 0, '........................................'),
	('moonlit_grove', 'dressing', 1, '........................................'),
	('moonlit_grove', 'dressing', 2, '.....v.................v..........v.....'),
	('moonlit_grove', 'dressing', 3, '.....v.................v..........v.....'),
	('moonlit_grove', 'dressing', 4, '.....v.................v..........v.....'),
	('moonlit_grove', 'dressing', 5, '.....v................L...........v.....'),
	('moonlit_grove', 'dressing', 6, '............L.....................v.....'),
	('moonlit_grove', 'dressing', 7, '........................................'),
	('moonlit_grove', 'dressing', 8, '........................*....L..........'),
	('moonlit_grove', 'dressing', 9, '...............*...................*....'),
	('moonlit_grove', 'dressing', 10, '......*.................................'),
	('moonlit_grove', 'dressing', 11, '..............................*.........'),
	('moonlit_grove', 'dressing', 12, '....................*...................'),
	('moonlit_grove', 'dressing', 13, '........................................'),
	('moonlit_grove', 'dressing', 14, '....L.........L.............L...........'),
	('moonlit_grove', 'dressing', 15, '.........*..............................'),
	('moonlit_grove', 'dressing', 16, '.................*......................'),
	('moonlit_grove', 'dressing', 17, '........................................'),
	('moonlit_grove', 'dressing', 18, '........................................'),
	('moonlit_grove', 'dressing', 19, '..gggggffn.gggg.f..nggggFf..gggn.bb.m...'),
	('moonlit_grove', 'dressing', 20, '........................................'),
	('moonlit_grove', 'dressing', 21, '........................................');
