extends SceneTree
## Version comparison, release picking and the once-per-version What's new.
const Updates = preload("res://scripts/content/update_check.gd")
var failures := 0
func check(ok: bool, text: String):
	print("PASS: " if ok else "FAIL: ", text)
	if not ok: failures += 1
func _initialize(): call_deferred("run")

func run():
	check(Updates.compare("v0.1.0-beta.16", "0.1.0-beta.15") == 1, "beta.16 is newer than beta.15")
	check(Updates.compare("0.1.0-beta.15", "v0.1.0-beta.15") == 0, "A leading v doesn't matter")
	check(Updates.compare("0.1.0-beta.9", "0.1.0-beta.10") == -1, "Beta numbers compare as numbers, not text")
	check(Updates.compare("0.1.0", "0.1.0-beta.15") == 1, "A release is newer than its betas")
	check(Updates.compare("0.1.0-beta.14.1", "0.1.0-beta.14") == 1, "beta.14.1 is newer than beta.14")
	check(Updates.compare("0.2.0-beta.1", "0.1.9") == 1, "Minor versions outrank betas")
	var releases := [{"tag_name": "v0.1.0-beta.15", "draft": false}, {"tag_name": "v0.1.0-beta.17", "draft": true}, {"tag_name": "v0.1.0-beta.16", "draft": false, "html_url": "u"}]
	check(Updates.newest(releases).tag_name == "v0.1.0-beta.16", "The newest published release is chosen; drafts are skipped")
	check(Updates.newest([]).is_empty(), "No releases, nothing chosen")
	var u = Updates.new()
	u.latest_tag = "v99.0.0"
	check(u.update_available() and u.summary().begins_with("99.0.0"), "A newer tag is reported as available")
	u.latest_tag = "v0.0.1"
	check(not u.update_available(), "An older tag is not an update")
	u.seen_version = ""
	check(u.should_show_whats_new(true) and not u.should_show_whats_new(false), "What's new is for people already set up")
	u.mark_whats_new_seen()
	check(not u.should_show_whats_new(true), "What's new shows once per version")
	var reloaded = Updates.new(); reloaded.load_state()
	check(reloaded.seen_version == Updates.current_version(), "Seen is saved in updates.cfg")
	check(not u.auto, "Automatic checks are off by default")
	check(Updates.whats_new_text().contains("## "), "What's new has notes for this version")
	u.free(); reloaded.free()
	print("UPDATE CHECK: %d failures" % failures)
	quit(1 if failures else 0)
