extends SceneTree

## The one build step of the map way, for a character being made by hand:
##
##   godot --headless --path . --script graphics/skin/pixel_map_tool.gd -- map <skin.png> [--force]
##       writes `<name>.map.png` beside `<name>.skin.png`: a colour of its own
##       for every opaque skin pixel, to paint the frames in. Refuses to replace
##       a map that exists — frames already painted in it would all go wrong —
##       unless told to with --force.
##
##   godot --headless --path . --script graphics/skin/pixel_map_tool.gd -- check <folder>
##       reads every `<name>.<anim>.png` strip in a character's folder against
##       its map and says which pixels are painted in no map colour, and which
##       strips are not a row of frames the map's size. Exits 1 if any are.
##
## Paths are project paths (`res://...`) or plain file paths. Nothing here needs
## the assets imported first: it reads the PNGs straight off the disk, so a
## skin drawn a minute ago works. See `graphics/skin/pixel_map.gd`.

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var code := 2
	if args.size() >= 2 and args[0] == "map":
		code = _map(args[1], args.has("--force"))
	elif args.size() >= 2 and args[0] == "check":
		code = _check(args[1])
	else:
		printerr("usage: -- map <skin.png> [--force] | check <folder>")
	quit(code)

static func _global(path: String) -> String:
	return ProjectSettings.globalize_path(path)

static func _read(path: String) -> Image:
	var img := Image.load_from_file(_global(path))
	if img == null:
		printerr("cannot read ", path)
		return null
	img.convert(Image.FORMAT_RGBA8)
	return img

func _map(skin_path: String, force: bool) -> int:
	if not skin_path.ends_with(".skin.png"):
		printerr("a skin is named <name>.skin.png, not ", skin_path.get_file())
		return 2
	var map_path := skin_path.trim_suffix(".skin.png") + ".map.png"
	if FileAccess.file_exists(_global(map_path)) and not force:
		printerr(map_path, " exists; frames painted in it would break. --force to replace it anyway.")
		return 1
	var skin := _read(skin_path)
	if skin == null:
		return 1
	var map := PixelMap.generate(skin)
	var err := map.save_png(_global(map_path))
	if err != OK:
		printerr("cannot write ", map_path, " (", err, ")")
		return 1
	var count := PixelMap.from_image(map).lookup.size()
	print("wrote %s: %d colours for %d opaque pixels" % [map_path, count, _opaque(skin)])
	return 0 if count == _opaque(skin) else 1

static func _opaque(img: Image) -> int:
	var n := 0
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a8 == 255:
				n += 1
	return n

func _check(folder: String) -> int:
	var base := folder.trim_suffix("/").get_file()
	var dir := folder.trim_suffix("/") + "/"
	var map_img := _read(dir + "%s.map.png" % base)
	if map_img == null:
		return 1
	var map := PixelMap.from_image(map_img)
	var bad := 0
	var seen := 0
	for file in DirAccess.get_files_at(_global(dir)):
		if not file.begins_with(base + ".") or not file.ends_with(".png"):
			continue
		var anim := file.trim_prefix(base + ".").trim_suffix(".png")
		if anim in ["skin", "map"]:
			continue
		seen += 1
		var strip := _read(dir + file)
		if strip == null:
			bad += 1
			continue
		if strip.get_height() != map.size.y or strip.get_width() % map.size.x != 0:
			printerr("%s: %s is not a row of %s frames" % [file, strip.get_size(), map.size])
			bad += 1
			continue
		@warning_ignore("integer_division")
		var count := strip.get_width() / map.size.x
		var strays := 0
		for i in count:
			map.encode(strip.get_region(Rect2i(i * map.size.x, 0, map.size.x, map.size.y)))
			strays += map.strays
		if strays > 0:
			printerr("%s: %d pixels painted in no map colour" % [file, strays])
			bad += 1
		else:
			print("%s: %d frames, every pixel on the map" % [file, count])
	if seen == 0:
		printerr("no strips in ", dir)
		return 1
	return 0 if bad == 0 else 1
