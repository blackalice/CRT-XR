extends SceneTree
var failures := 0
func _initialize():call_deferred("run")
func check(ok:bool,label:String):
 print("PASS: " if ok else "FAIL: ",label)
 if not ok:failures+=1
func application():
 var app=load("res://scenes/main.tscn").instantiate();root.add_child(app);app.use_tracking(false);return app
func run():
 var app=application()
 var path:=ProjectSettings.globalize_path("res://build/album-fixture/a.mp3")
 app.music.play_file(path);app.music.toggle_playback();app.music.seek(2.25)
 check(app.music.save_resume()==OK,"Track and paused seek position save atomically")
 app.free();await create_timer(.15).timeout
 app=application()
 check(app.music.player.stream!=null and not app.music.player.playing and app.music.http==null,"Startup prepares the track without starting audio or network")
 check(app.music.metadata.title=="Second song" and app.music.track_index==1,"Metadata and album queue restore to the selected track")
 check(is_equal_approx(app.music.position_seconds(),2.25) and app.music.playback_caption()=="Play","Ready player shows the saved timestamp and Play action")
 app.music._process(1)
 check(is_equal_approx(app.music.duck_gain,1),"Prepared music never ducks game audio")
 app.load_game(ProjectSettings.globalize_path("res://build/crt-xr-probe.sfc"))
 if not app.settings_panel.visible: app.toggle_settings()
 app.music.toggle_playback();await create_timer(.12).timeout
 check(app.music.player.playing and app.music.position_seconds()>2.2,"Play continues from the stored position without reloading the track")
 app.music.toggle_playback()
 await create_timer(.25).timeout
 var pause_time: float=app.music.position_seconds()
 app.close_settings();await create_timer(.25).timeout
 app.toggle_settings();app.music.toggle_playback();await create_timer(.15).timeout
 check(app.music.position_seconds()>=pause_time-.05 and app.music.position_seconds()>2.0,"Pause, close menu, reopen and Play continues instead of restarting")
 app.music.toggle_playback();app.music.seek(1.5);app.music.save_resume()
 var bookmark:=ConfigFile.new();bookmark.load("user://music-resume.cfg")
 check(is_equal_approx(float(bookmark.get_value("resume","position")),1.5),"Seek changes update the bookmark while paused")
 app.free();await create_timer(.15).timeout
 bookmark.set_value("resume","path",path+".missing");bookmark.save("user://music-resume.cfg")
 app=application()
 check(not app.music.player.playing and "unavailable" in app.music.status,"A missing SD-card track stays silent and reports recovery guidance")
 app.free();await create_timer(.15).timeout
 var preserved:=ConfigFile.new();preserved.load("user://music-resume.cfg")
 check(str(preserved.get_value("resume","path")).ends_with(".missing"),"Missing media does not erase the saved bookmark")
 bookmark.set_value("resume","path",path);bookmark.set_value("resume","position","invalid");bookmark.save("user://music-resume.cfg")
 app=application()
 check(app.music.player.stream!=null and app.music.position_seconds()==0,"Malformed saved position safely resets to zero")
 app.music.reset_defaults();app.free();await create_timer(.15).timeout
 app=application();check(app.music.kind.is_empty() and app.music.player.stream==null,"Reset all clears the resume bookmark")
 app.free();await create_timer(.15).timeout
 bookmark.clear();bookmark.set_value("resume","kind","radio");bookmark.set_value("resume","url","https://example.org/live.mp3");bookmark.save("user://music-resume.cfg")
 app=application()
 check(app.music.kind=="radio" and app.music.http==null and not app.music.player.playing,"Radio is also restored ready without reconnecting automatically")
 app.free();await create_timer(.15).timeout
 print("MUSIC RESUME CHECKS COMPLETE: ",failures," failures");quit.call_deferred(1 if failures else 0)
