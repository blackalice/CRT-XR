extends SceneTree
## Box art download: names and addresses as libretro-thumbnails uses them, and
## downloaded art found by the box art lookup.
const Fetch = preload("res://scripts/content/box_art_fetch.gd")
const BoxArt = preload("res://scripts/content/box_art.gd")
var failures := 0
func check(ok: bool, text: String):
	print("PASS: " if ok else "FAIL: ", text)
	if not ok: failures += 1
func _initialize(): call_deferred("run")
func run():
	check(Fetch.thumbnail_name("Sonic & Knuckles (World)") == "Sonic _ Knuckles (World)", "& becomes _ as the collection names files")
	check(Fetch.thumbnail_name("Q*bert: Qubes (USA)") == "Q_bert_ Qubes (USA)", "* and : become _")
	var url: String = Fetch.url_for("snes", "/r/snes/Super Mario World (USA).sfc", "Super Mario World (USA)")
	check(url.begins_with("https://thumbnails.libretro.com/Nintendo%20-%20Super%20Nintendo%20Entertainment%20System/Named_Boxarts/Super%20Mario%20World%20") and url.ends_with(".png"), "SNES art comes from its Named_Boxarts folder: " + url)
	check(Fetch.playlist("gameboy", "x/Tetris DX (World).gbc") == "Nintendo - Game Boy Color", "Game Boy Color games use their own collection")
	check(Fetch.playlist("gameboy", "x/Tetris (World).gb") == "Nintendo - Game Boy", "Game Boy games use the Game Boy collection")
	check(Fetch.url_for("unknown", "x.bin", "X").is_empty(), "Unknown consoles are skipped")
	# A downloaded cover is found by the ordinary lookup.
	var art = BoxArt.new()
	var roms := ProjectSettings.globalize_path("user://fetch-roms")
	art.set_root(roms)
	var rom := roms.path_join("snes/Super Mario World (USA).sfc")
	check(art.console_folder(rom) == "snes", "The console folder is the folder under the ROM root")
	check(art.find(rom).is_empty(), "No art before downloading")
	var target := Fetch.save_path("snes", rom)
	DirAccess.make_dir_recursive_absolute(target.get_base_dir())
	var image := Image.create(4, 4, false, Image.FORMAT_RGB8); image.save_png(target)
	art.refresh()
	check(art.find(rom) == target, "Downloaded art is found for its game")
	check(art.find(rom, BoxArt.COVER_TYPES, BoxArt.COVER_BESIDE) == target, "and printed on the box on the table")
	var fetch = Fetch.new()
	check(fetch.start([["snes", rom, ["Super Mario World (USA)"], "snes"]]) == 0, "Games that already have downloaded art are not fetched again")
	# The download is a .part file: its format comes from its bytes, not its name.
	var part := target + ".part"
	DirAccess.copy_absolute(target, part)
	check(Fetch.valid_image(part), "A PNG saved as .part is recognised as a picture")
	var junk := FileAccess.open(part, FileAccess.WRITE); junk.store_string("<html>Not found</html>"); junk.close()
	check(not Fetch.valid_image(part), "An error page is not a picture")
	# Spellings: file name, identified name, GoodTools written out, then without extra tags.
	check(Fetch.from_goodtools("Kirby's Dream Land (UE) [!]") == "Kirby's Dream Land (USA, Europe)", "GoodTools (UE) becomes (USA, Europe)")
	check(Fetch.from_goodtools("Super Mario Land (W) (V1.1)") == "Super Mario Land (World)", "GoodTools (W) becomes (World)")
	var names: Array = Fetch.names_for("Donkey Kong Country (Europe) (En,Fr,De) (Rev 1).sfc", "")
	check(names == ["Donkey Kong Country (Europe) (En,Fr,De) (Rev 1)", "Donkey Kong Country (Europe)"], "No-Intro names are tried whole, then without their tags: %s" % [names])
	# Misses are remembered and skipped next time.
	var other := roms.path_join("snes/Not A Real Game (USA).sfc")
	fetch.misses_loaded = true
	fetch.misses.set_value("missing", other.md5_text(), true)
	check(fetch.known_missing(other) and fetch.start([["snes", other, ["Not A Real Game (USA)"], "snes"]]) == 0, "A game the collection didn't have is not asked for again")
	fetch.free(); art.free()
	print("BOX ART FETCH: %d failures" % failures)
	quit(1 if failures else 0)
