extends SceneTree
## Help pages as structured articles: the markup's blocks, Markdown credits
## read cleanly, and each help page opening at its own top.
const HelpArticle = preload("res://scripts/ui/help_article.gd")
var failures := 0

func check(ok: bool, label: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok: failures += 1

func _initialize() -> void: call_deferred("run")

func settle() -> void:
	for i in range(8): await process_frame

func kinds(blocks: Array) -> Array:
	return blocks.map(func(block): return block[0])

func run() -> void:
	var blocks := HelpArticle.parse("## Starting\n1. First step\n2. Second\n- A bullet\nA | Enter :: Select\n> A tip\n!! Card title\nIts body\nruns on.\n\nA paragraph.")
	check(kinds(blocks) == ["heading", "step", "step", "bullet", "control", "tip", "card", "text"], "Each markup line becomes its block")
	check(blocks[1][2] == "1" and blocks[2][1] == "Second", "Steps keep their numbers")
	check(blocks[4][2] == ["A", "Enter"] and blocks[4][1] == "Select", "A control has its pad and keyboard chips")
	check(blocks[6][2] == "Its body runs on.", "A card's body joins its lines")
	var markdown := HelpArticle.parse("# Title\n\nSome `code` and a [link](https://example.com).\n\n* A bullet that\n  continues here.")
	check(kinds(markdown) == ["text", "bullet"], "Markdown's page title is dropped (the page has one)")
	check(markdown[0][1] == "Some code and a link.", "Code ticks and link targets are removed")
	check(markdown[1][1] == "A bullet that continues here.", "Indented lines continue the bullet")
	var credits := HelpArticle.parse(FileAccess.get_file_as_string("res://THIRD_PARTY.md"))
	check(credits.any(func(b): return b[0] == "heading") and not credits.any(func(b): return "`" in b[1] or "](" in b[1]), "The credits read as sections, without Markdown marks")

	var app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	app.use_tracking(false)
	await settle()
	var menu = app.menu
	for page in [["Using glasses", menu.play.glasses_guide()], ["Controls", menu.catalog.CONTROLS_GUIDE], ["Troubleshooting", menu.catalog.TROUBLESHOOTING_GUIDE]]:
		var parsed := HelpArticle.parse(page[1])
		check(parsed.size() >= 5 and not parsed.any(func(b): return b[0] == "text" and b[1].length() > 240), page[0] + " is structured, not one long block")
	check(HelpArticle.parse(menu.catalog.CONTROLS_GUIDE).filter(func(b): return b[0] == "control").size() >= 8, "Controls lists each button")
	check(HelpArticle.parse(menu.play.glasses_guide()).any(func(b): return b[0] == "step"), "Using glasses walks through numbered steps")
	menu.open_settings()
	menu.open_help("Credits & licences", FileAccess.get_file_as_string("res://THIRD_PARTY.md"))
	await settle()
	menu.scroll.scroll_vertical = 900
	await settle()
	menu.remember()
	menu.open_help("Controls", menu.catalog.CONTROLS_GUIDE)
	await settle()
	check(menu.scroll.scroll_vertical == 0, "A new help page opens at its top, not where the last one was")
	check(not menu.help_label.visible, "Help pages give the help strip's room to the article")
	# About: the version row opens it, with the 3D logo floating in front.
	var about := HelpArticle.parse(menu.catalog.about_page())
	check(about[0][0] == "logo" and about.any(func(b): return b[0] == "fact" and b[2] == "Website" and b[1] == "stua.rtfoy.co.uk"), "About has the logo, then facts including the website")
	menu.open_settings(); menu.category = 6; menu.render(); await settle()
	menu.select("system.version"); menu.activate(); await settle()
	var logo = menu.column.find_child("Logo3D", true, false)
	check(menu.mode == "help" and menu.help_title == "About CRT XR" and logo != null, "The version row opens About CRT XR")
	check(logo != null and menu.depth_layout().lift == logo.get_global_rect().intersection(menu.scroll.get_global_rect()), "In stereo the logo is the page's lifted layer")
	var Logo3D = preload("res://scripts/ui/logo_3d.gd")
	var keys := [[0.0, 0.0, 16.7, 42.0], [0.5, 105.0, 30.0, 42.0], [1.0, 0.0, 30.0, 16.7]]
	check(is_equal_approx(Logo3D.keyed(keys, 0.5), 105.0) and is_equal_approx(Logo3D.keyed(keys, 1.0), 0.0) and is_equal_approx(Logo3D.keyed(keys, 9.0), 0.0), "Keyframes land exactly on their values")
	var smooth := true
	var last := -1.0
	for i in range(51):
		var value: float = Logo3D.keyed(keys, i / 100.0)
		smooth = smooth and value >= last - 0.001
		last = value
	check(smooth and Logo3D.keyed(keys, 0.05) < 105.0 * 0.1, "After Effects' ease: a slow start, rising steadily to the key")
	check(logo != null and logo.letters.size() == 5 and logo.view.own_world_3d, "Five letters, built in their own little 3D world")
	app.free()
	await settle()
	print("HELP ARTICLE CHECKS COMPLETE: ", failures, " failures")
	quit(1 if failures else 0)
