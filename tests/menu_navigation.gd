extends SceneTree
var app
var failures:=0
func _initialize():call_deferred("run")
func check(ok:bool,label:String):
    print("PASS: " if ok else "FAIL: ",label)
    if not ok: failures+=1
func settle():
    for i in range(4): await process_frame
func button(code:int):
    for down in [true,false]:
        var e:=InputEventJoypadButton.new();e.device=7;e.button_index=code;e.pressed=down
        Input.parse_input_event(e);Input.flush_buffered_events();await settle()
func key(code:int,unicode:=0,ctrl:=false):
    for down in [true,false]:
        var e:=InputEventKey.new();e.physical_keycode=code;e.unicode=unicode;e.pressed=down;e.ctrl_pressed=ctrl
        Input.parse_input_event(e);Input.flush_buffered_events();await settle()
func page(cat:int,section:int):
    app.menu.preview=false;app.menu.category=cat;app.menu.subsection=section;app.menu.mode="settings";app.menu.render()
func row(id:String):
    for item in app.menu.rows:
        if item.item.id==id:return item
    return null
func run():
    for action in ["ui_up","ui_down","ui_left","ui_right","ui_accept"]:
        for e in InputMap.action_get_events(action):
            if e is InputEventJoypadButton or e is InputEventJoypadMotion:InputMap.action_erase_event(action,e)
    app=load("res://scenes/main.tscn").instantiate();root.add_child(app);app.use_tracking(false);await settle()
    var m=app.menu
    check(m.items.map(func(i):return i.id)==["home.continue","home.library","home.settings","home.exit"],"Startup has its own home menu")
    check(m.selected_id=="home.library" and row("home.continue").disabled,"No-game startup selects Library and disables unavailable Continue")
    m.open_settings();page(0,0);m.select("view.distance",false);app.distance=3.0
    await button(JOY_BUTTON_DPAD_RIGHT)
    check(is_equal_approx(app.distance,3.1) and m.category==0,"Right adjusts immediately")
    var held_right:=InputEventJoypadButton.new();held_right.device=7;held_right.button_index=JOY_BUTTON_DPAD_RIGHT;held_right.pressed=true
    m.handle(held_right);m._process(.4);m._process(.11);held_right.pressed=false;m.handle(held_right)
    check(app.distance>3.2 and m.direction==Vector2i.ZERO,"Held adjustment repeats and releases cleanly")
    await button(JOY_BUTTON_DPAD_DOWN)
    check(m.selected_id=="view.height_offset" and not m.preview,"Down moves to another option without an edit lock")
    await button(JOY_BUTTON_A)
    check(m.preview and not m.body.visible,"A opens preview for placement, without hiding the menu during navigation")
    var cat=m.category;await button(JOY_BUTTON_RIGHT_SHOULDER)
    check(m.category==cat,"Preview ignores category switches")
    await button(JOY_BUTTON_DPAD_RIGHT);await button(JOY_BUTTON_Y)
    check(is_zero_approx(app.height_offset-app.Showcase.VIEW.height_offset),"Preview reset affects the selected option")
    await button(JOY_BUTTON_B)
    check(not m.preview and m.selected_id=="view.height_offset","Back restores the preview selection")
    await button(JOY_BUTTON_RIGHT_SHOULDER)
    check(m.category==1,"RB changes category")
    await button(JOY_BUTTON_LEFT_SHOULDER)
    check(m.category==0 and m.selected_id=="view.height_offset","Category focus is restored")
    for value in [.9,.95]:
        var e:=InputEventJoypadMotion.new();e.device=7;e.axis=JOY_AXIS_TRIGGER_RIGHT;e.axis_value=value;Input.parse_input_event(e);Input.flush_buffered_events();await settle()
    check(m.subsection==1,"Holding a trigger advances only one subsection")
    var release:=InputEventJoypadMotion.new();release.device=7;release.axis=JOY_AXIS_TRIGGER_RIGHT;release.axis_value=0;Input.parse_input_event(release);Input.flush_buffered_events()
    page(3,0);m.select("controls.distance",false);var before:bool=app.right_stick_distance;await button(JOY_BUTTON_A)
    check(app.right_stick_distance!=before,"A toggles immediately")
    page(1,4);app.world.picture.mode=0;m.render();await settle();m.select("picture.connection",false)
    var disabled=row("picture.composite_strength")
    check(disabled.disabled and disabled.adjust_buttons.all(func(b):return b.disabled),"Composite controls and their arrows are disabled in RGB")
    check(disabled.unavailable_label.visible and not disabled.unavailable_label.text.is_empty(),"Disabled reason is visible")
    disabled.adjust_buttons[1].pressed.emit()
    check(app.world.picture.mode==0,"Disabled arrows cannot change another selected control")
    await button(JOY_BUTTON_DPAD_RIGHT)
    check(app.world.picture.mode==1 and not row("picture.composite_strength").disabled,"Changing connection immediately enables composite controls")
    page(2,0);app.emulator.tv_audio.mode=0;app.emulator.tv_audio.apply();m.render();await settle()
    check(row("audio.room_amount").disabled and row("audio.speaker_character").disabled and row("audio.directional_strength").disabled,"Original audio mode disables bypassed controls")
    check(row("audio.preview")!=null and app.emulator.tv_audio.preview_player.bus=="Master","Sound preview uses the selected audio route")
    if DisplayServer.get_name()!="headless":
        app.emulator.tv_audio.preview_sample()
        check(app.emulator.tv_audio.preview_player.playing,"Preview starts while the game menu remains open")
        app.emulator.tv_audio.preview_player.stop()
    page(2,1);m.select("room.ambient",false);await button(JOY_BUTTON_X)
    check(m.preview,"Room lighting has working compact preview")
    await button(JOY_BUTTON_B)
    m.open_library();m.rom_index.cancel()
    var games:Array=[{"path":"/test/1942.sfc","label":"1942"}]
    for i in range(115):games.append({"path":"/test/Alpha%03d.sfc"%i,"label":"Alpha%03d"%i})
    games.append({"path":"/test/Zelda.sfc","label":"Zelda"});m.rom_index.games={"snes":games};m.open_system("snes");await settle()
    m.select("game:/test/Alpha000.sfc",false);await key(KEY_X,120)
    check("/test/Alpha000.sfc" in app.play_history.favourites and m.search_query.is_empty(),"X still favourites instead of entering search")
    await key(KEY_F,102,true);await key(KEY_Z,122)
    check(m.search_query=="z" and m.game_entries().size()==1 and m.search_field.has_focus(),"First typed search character filters immediately and retains focus")
    await key(KEY_DOWN)
    check(not m.search_field.has_focus(),"Down returns from search to controller-style list navigation")
    m.update_search("");m.search_field.text="";m.select("games.jump",false);await key(KEY_J,106)
    check(m.mode=="alphabet" and row("letter.#")!=null,"J opens the controller-friendly alphabet, including numbers")
    m.select("letter.#",false);await button(JOY_BUTTON_DPAD_RIGHT)
    check(m.selected_id=="letter.A","Alphabet controller navigation skips unavailable letters")
    await button(JOY_BUTTON_DPAD_DOWN)
    check(m.selected_id=="letter.Z","Alphabet navigation reaches a populated row past empty rows")
    if DisplayServer.get_name()!="headless":
        await RenderingServer.frame_post_draw
        DirAccess.make_dir_recursive_absolute("res://build/ui-notes-review")
        app.menu_view.get_texture().get_image().save_png("res://build/ui-notes-review/alphabet.png")
    m.select("letter.Z",false);await button(JOY_BUTTON_A)
    check(m.mode=="games" and m.game_page==2 and m.selected_id=="game:/test/Zelda.sfc","Letter jump reaches games beyond the first page")
    await button(JOY_BUTTON_B);m.open_settings()
    var unique:Dictionary={};var count:=0
    for cat_index in range(m.CATEGORIES.size()):
        var pages:Array=m.catalog.pages(cat_index)
        for section in range(pages.size()):
            page(cat_index,section);await settle()
            for item in m.items:
                check(not unique.has(item.id),"Unique setting ID: "+item.id);unique[item.id]=true;count+=1
            for kind in ["keyboard","controller"]:
                m.set_input_kind(kind);await settle()
                check(m.get_rect().end.x<=960 and m.get_rect().end.y<=720,"Page fits the shared canvas: %d/%d %s"%[cat_index,section,kind])
            if DisplayServer.get_name()!="headless":
                await RenderingServer.frame_post_draw
                DirAccess.make_dir_recursive_absolute("res://build/ui-notes-review")
                app.menu_view.get_texture().get_image().save_png("res://build/ui-notes-review/%d-%d.png"%[cat_index,section])
    check(count>80 and unique.has("system.reset"),"All settings remain reachable, including General reset")
    page(0,0);m.select("view.distance",false)
    var motion:=InputEventJoypadMotion.new();motion.device=7;motion.axis=JOY_AXIS_LEFT_Y;motion.axis_value=1;m.handle(motion)
    Input.joy_connection_changed.emit(7,false)
    check(m.direction==Vector2i.ZERO,"Disconnect stops held movement")
    app._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
    check(m.direction==Vector2i.ZERO,"Focus loss clears held navigation")
    m.open_pause();m.select("home.exit",false);await button(JOY_BUTTON_A);await button(JOY_BUTTON_B)
    check(m.mode=="pause" and m.selected_id=="home.exit","Exit cancellation restores selection")
    m.open_settings();page(5,0);m.select("system.reset",false);await button(JOY_BUTTON_A)
    check(m.mode=="confirm" and m.selected_id=="cancel","Reset-all confirmation defaults to Cancel")
    await button(JOY_BUTTON_B)
    check(m.mode=="settings" and m.selected_id=="system.reset","Cancelling reset restores selection")
    DirAccess.make_dir_absolute(ProjectSettings.globalize_path("user://settings.cfg.tmp"));app.close_settings()
    check(m.visible and m.error_label.visible,"Failed save keeps the menu open and error visible")
    DirAccess.remove_absolute(ProjectSettings.globalize_path("user://settings.cfg.tmp"));app.close_settings()
    check(not m.visible,"Closing retries after storage recovers")
    app.load_game(ProjectSettings.globalize_path("res://build/retrocrt-probe.sfc"));await settle()
    app.close_settings();app.toggle_settings();await settle()
    check(app.emulator.paused and m.selected_id=="resume","Menu pauses a running game and selects Resume")
    var load_row=m.rows.filter(func(row):return row.item.id=="load_state")[0]
    check(load_row.disabled,"Load state is unavailable until a state exists")
    m.select("save_state");await button(JOY_BUTTON_A)
    load_row=m.rows.filter(func(row):return row.item.id=="load_state")[0]
    check(not load_row.disabled,"Successful state save immediately enables Load state")
    m.select("load_state");await button(JOY_BUTTON_A)
    check(m.mode=="confirm","Loading state requests confirmation")
    m.select("confirm");await button(JOY_BUTTON_A)
    check(app.emulator.paused and m.visible,"Loading state from the menu keeps the game paused")
    m.select("resume");await button(JOY_BUTTON_A)
    check(not m.visible and not app.emulator.paused,"Resume restores gameplay")
    await settle()
    check(app.menu_view.render_target_update_mode==SubViewport.UPDATE_DISABLED,"Closed menu stops rendering")
    app.emulator.set_paused(true);app.toggle_settings();app.close_settings()
    check(app.emulator.paused,"A previously paused game stays paused")
    app.toggle_settings()
    app.distance+=.1
    DirAccess.make_dir_absolute(ProjectSettings.globalize_path("user://settings.cfg.tmp"))
    app.close_settings()
    check(m.visible and m.error_label.visible and app.emulator.paused,"Save failure retains the open menu, error and paused game")
    DirAccess.remove_absolute(ProjectSettings.globalize_path("user://settings.cfg.tmp"))
    app.close_settings()
    check(not m.visible,"Retrying after storage recovery saves and closes normally")
    app.distance_save_delay=-1;app.free();await settle()
    print("MENU USABILITY COMPLETE: ",failures," failures")
    quit.call_deferred(1 if failures else 0)
