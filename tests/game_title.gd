extends SceneTree
## Clean game titles from the naming styles real libraries use.
const GameTitle = preload("res://scripts/content/game_title.gd")
var failures := 0
func check(ok: bool, text: String):
	print("PASS: " if ok else "FAIL: ", text)
	if not ok: failures += 1
func _initialize(): call_deferred("run")

func expect(file: String, title: String, variant := "", tags: Array = [], numbered := false) -> void:
	var parsed := GameTitle.parse(file, numbered)
	check(parsed.title == title and parsed.variant == variant and Array(parsed.tags) == tags,
		"%s -> %s | %s | %s (got %s | %s | %s)" % [file, title, variant, tags, parsed.title, parsed.variant, parsed.tags])

func run():
	# No-Intro / Redump
	expect("Addams Family, The (USA, Europe).md", "The Addams Family", "USA, Europe")
	expect("Flintstones, The - The Treasure of Sierra Madrock (USA).sfc", "The Flintstones - The Treasure of Sierra Madrock", "USA")
	expect("1080 Snowboarding (Japan, USA) (En,Ja).z64", "1080 Snowboarding", "Japan, USA")
	expect("Sonic CD (USA).chd", "Sonic CD", "USA")
	expect("Final Fantasy VII (USA) (Disc 2).chd", "Final Fantasy VII", "USA", ["Disc 2"])
	expect("Super Mario World (Europe) (Rev 1).sfc", "Super Mario World", "Europe · Rev 1")
	expect("Star Fox 2 (Japan) (Proto).sfc", "Star Fox 2", "Japan", ["Prototype"])
	expect("Gran Turismo 2 (USA) (Arcade Mode) (v1.1).zip", "Gran Turismo 2", "USA · v1.1", ["Arcade Mode"])
	expect("Gran Turismo 2 (USA) (Simulation Mode) (v1.2).zip", "Gran Turismo 2", "USA · v1.2", ["Simulation Mode"])
	expect("Gran Turismo 2 - Music at the Speed of Sound - The Album (USA) (Bonus PlayStation Disc).zip", "Gran Turismo 2 - Music at the Speed of Sound - The Album", "USA", ["Bonus PlayStation Disc"])
	expect("Sonic the Hedgehog (Side B).gg", "Sonic the Hedgehog", "", ["Side B"])
	expect("Tetris (World) (Beta 2).gb", "Tetris", "World", ["Beta 2"])
	expect("09 Chairs (Japan).chd", "09 Chairs", "Japan")
	# GoodTools
	expect("102 Dalmatians - Puppies to the Rescue (U) (C).zip", "102 Dalmatians - Puppies to the Rescue", "USA")
	expect("4-in-1 Funpak Vol. II (JU).gb", "4-in-1 Funpak Vol. II", "Japan, USA")
	expect("Aladdin (U) [!].smc", "Aladdin", "USA")
	expect("Go Go Ackman (J) (S).gb", "Go Go Ackman", "Japan")
	expect("Pokemon - Edicion Plata (S) (C).zip", "Pokemon - Edicion Plata", "Spain")
	expect("Aladdin (E) [b1].smc", "Aladdin", "Europe", ["Bad dump"])
	expect("Chrono Trigger (J) [T+Eng1.0].smc", "Chrono Trigger", "Japan", ["Translation"])
	expect("Super Metroid (U) [h1C].smc", "Super Metroid", "USA", ["Hack"])
	expect("Gran Turismo 4 [Trial] (Japan)", "Gran Turismo 4", "Japan", [], false)
	# TOSEC
	expect("1943 - The Battle of Midway (1988-10)(Capcom)(US).nes", "1943 - The Battle of Midway", "USA")
	var tosec := GameTitle.parse("1942 (1985-12-11)(Capcom)(JP-US).nes")
	check(tosec.title == "1942" and tosec.year == "1985" and tosec.publisher == "Capcom" and tosec.variant == "Japan, USA", "TOSEC keeps year and publisher out of the title")
	# Numbered sets: a leading zero always strips; others only when the folder is numbered.
	expect("0001 - F-Zero (J)(Independent).zip", "F-Zero", "Japan")
	expect("0004 - Legend of Zelda, The - Ocarina of Time 3D (Europe) (En,Fr,De,Es,It) Decrypted.3ds", "The Legend of Zelda - Ocarina of Time 3D", "Europe")
	expect("0002 - Super Monkey Ball 3D Decrypted.3ds", "Super Monkey Ball 3D")
	expect("2345 - Pokemon Emerald (U)(TrashMan).zip", "2345 - Pokemon Emerald", "USA")
	expect("2345 - Pokemon Emerald (U)(TrashMan).zip", "Pokemon Emerald", "USA", [], true)
	# Plain and odd names
	expect("007 - Agent Under Fire.iso", "007 - Agent Under Fire")
	expect("Super_Mario_World.sfc", "Super Mario World")
	expect("Crazy Taxi (USA).iso.zip", "Crazy Taxi", "USA")
	expect("(USA).sfc", "(USA)", "USA")
	expect("Hey, Arnold! (USA).gba", "Hey, Arnold!", "USA")
	# Ordering, letters and search
	check(GameTitle.parse("Legend of Zelda, The (USA).sfc").sort == "legend of zelda", "Moved article still sorts under the main word")
	check(GameTitle.sort_key("The Lion King") == "lion king" and GameTitle.sort_key("The") == "the", "Leading The is ignored when sorting")
	check(GameTitle.letter("legend") == "L" and GameTitle.letter("1942") == "#", "Jump to letter headings")
	var zelda := "/roms/snes/Legend of Zelda, The - A Link to the Past (USA).sfc"
	check(GameTitle.matches("zelda link", zelda), "Search matches words in any order and ignores punctuation")
	check(GameTitle.matches("USA", zelda) and GameTitle.matches("", zelda), "Search still finds file-name tags; empty query matches")
	check(not GameTitle.matches("metroid", zelda), "Search excludes other games")
	GameTitle.remember("/roms/gba/2345 - Pokemon Emerald (U).zip", true)
	check(GameTitle.of("/roms/gba/2345 - Pokemon Emerald (U).zip") == "Pokemon Emerald", "Remembered numbered sets keep their clean title")
	print("Game title checks complete: ", failures, " failures")
	quit(1 if failures else 0)
