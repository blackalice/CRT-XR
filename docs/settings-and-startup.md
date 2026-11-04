# Settings, saved setups and startup

## Pause menu and settings

L1 + R1 + Start (LB + RB + Start on an Xbox pad) or Escape opens the menu. Without a game, Home shows Continue last game,
Game library (or Set up library), Quick settings, Music, Settings and Exit. Continue appears and is selected only when its cartridge is available; otherwise library setup leads. Idle or paused music stays compact; active playback expands transport and timeline below the game actions.
With a game loaded, the pause menu provides Resume, Choose game, Save state, Load state,
Screenshot, Quick settings, Music, Settings and Exit. R3 recentres. B returns one level; at the root it saves
and restores the previous pause state. Failed saves keep the menu open with an error.

| Category | Subsections |
|---|---|
| Quick settings | TV distance; height; recenter; picture preset; game volume; music volume |
| View | Placement; Display; Tracking; Advanced calibration |
| Picture | Presets; CRT; Screen fit; Colour; Signal |
| Audio | TV sound; Balance; Music; Music space; TV effects |
| Room | Presets; Lighting; Materials; Props; Sound; Placement |
| Controls | Game controls; Controller |
| Emulation | Consoles; This game; Performance; Info |
| Saved setups | Setup slots; Per-game picture |
| Menu | Accessibility; Layout & placement; Audio & vibration |
| About & Help | About, controls, device status, troubleshooting, credits and diagnostics; Settings management |

**Console region** (Menu → Layout & placement) chooses PAL (Europe, the default), NTSC (Americas) or Japan. It changes only how consoles are named and pictured in the menus; games, saves and folder recognition are unaffected. Consoles that differ by region:

| Console | PAL | NTSC | Japan |
|---|---|---|---|
| SNES | SNES | SNES (US icon) | Super Famicom (SFC) |
| NES | NES | NES | Famicom (FC) |
| Mega Drive | Mega Drive | Genesis (GEN) | Mega Drive |
| Master System | Master System | Master System | Mark III |
| PC Engine | PC Engine | TurboGrafx-16 (TG-16) | PC Engine |
| Sega CD | Mega-CD | Sega CD | Mega-CD |
| Dreamcast | blue swirl icon | blue swirl icon | red swirl icon |

Every other console keeps one name and icon in all regions. The setting is saved with the Menu settings and returns to PAL under Reset all settings. Names, short names and icon files are defined in `scripts/emulation/core_registry.gd` (`REGIONAL`); add an entry there to give another console a regional variant.

Core settings offer console-wide defaults under Consoles and per-game overrides under This game. The playing console moves to the top, is marked Playing, and expands when the game changes. Console options sit inside the expanded group; selecting the header hides them. Other consoles remain accessible. This game identifies the loaded game and shows effective inherited values with From console or Game override beneath each setting. Y returns an option to its console setting. Changes apply when the game next loads. Sega consoles have separate preferences even where they share a core.

Up/down selects, left/right adjusts immediately, A toggles switches or opens actions,
and Y resets only the selected option. There is no edit lock. L1/R1 changes category;
L2/R2 changes subsection once per trigger press. Category and subsection selection use
a quiet category fill and section underline; the focused setting gets the strongest amber border.
Quick settings appears first in the sidebar; category shortcuts follow that visual order.
Subsections stay on one line with input-specific navigation hints beside them.
Scroll edges fade only where more content is available, alongside a clearer scrollbar.

For keyboard users, arrows select/adjust, Enter activates, Backspace returns, Q/E or
Tab changes category, and Z/C changes subsection. Hints follow the last-used input
method. Pointer hover does not steal selection. Disabled sound and composite options
show a reason and cannot be changed using their arrows.

Audio includes Preview sound, which plays the existing licensed CRT sample through
the selected sound mode while emulation remains paused. Original bypasses the effects;
TV speakers enables speaker character; TV in room additionally enables room amount
and directional strength.

The selected row has a contrasting background and amber border.
The fixed help area explains it; values show suitable units. Picture pages state
whether changes are global or belong to the loaded game. Everything uses the
same 960×720 menu texture in both eyes, without extra 3D passes. The menu viewport
and UI processing stop while closed.

## Feedback, previews and accessibility

Compact adjustment arrows reserve their space beside the value so tracks stay aligned.
Only the focused slider uses amber; other tracks are muted. Contextual help explains
the effect without repeating the row title. Rows grow around wrapped text; game titles
use up to three lines, with system captions
inside the same row. Y opens a scrollable full-title view (or clears an active search);
pointer users can also hover for the full title. Long descriptive values appear below their labels. Numeric rows
show the minimum and maximum beside the track; a full Scanlines track explicitly means the 70% maximum. A dot
marks values changed from their defaults. Presets include a look description and active
checkmark; manual edits show Custom. Picture → Presets offers Undo picture preset.
Changes persist when closing the menu, with Saved feedback only after a successful write.

New manual and automatic saves include a small game-frame thumbnail with the existing
game title and UTC timestamp. Loading or overwriting a manual save shows its preview and
selects Cancel first. Older saves remain readable and can lack thumbnails. Continue also
shows the automatic resume preview. Preview capture reuses the presented CPU frame.

About & Help includes scrollable controls, troubleshooting, device status, full credits
and diagnostics. Device status stays separate from the selected action’s help. Menu → Accessibility provides larger text, stronger contrast, reduced animation and Clean menu feed. The menu on the CRT uses the current picture settings by default, including colour, CRT effects, fitting and composite decoding. Clean menu feed restores the separate RGB reading picture without changing game settings. Auto composite keeps the current programme’s PAL/NTSC rate while the menu is shown. Menu layout and placement, sounds and vibration have their own sections.
Focus transitions only change colour; the UI remains a sharp shared 2D texture.
Controller shortcuts use drawn button icons and follow the last input method. With Menu sounds enabled, valid L1/R1 category or game-page changes and L2/R2 subsection changes play the supplied click. Held controls, ignored shortcuts and page boundaries stay silent.

## Compact adjustment preview

Home and the paused-game menu carry six Quick settings in a three-column,
two-row grid: Room, Picture, Game volume, TV distance, Screen height offset and
Music volume (the album/radio player, independent of the menu background loop).
TV distance and height open the floating bottom preview strip with A / Enter or
a pointer click. Left/right adjusts, up/down switches between those two controls,
Y resets, and B returns to the same quick tile while gameplay stays paused.
The default Home (including Continue) and game-pause layouts fit without a
scrollbar: compact library/music actions, closer row spacing and concise quick
help make room for the second row. Full settings keep their longer explanations;
larger text and expanded music panels can still scroll when needed.
Screen height defaults to 0 m. A changed-value dot sits in the row's corner,
outside the title layout, so changing height cannot rewrap or enlarge its tile.
Existing saved placements are retained; Y resets height to the new default.

Steam Deck starts with controller glyphs in both Gaming and Desktop Mode.
Its trackpad leaves those prompts in place. Pressing a keyboard key switches to
keyboard prompts; controller input switches them back.

The Preview button, X, or A on a visual value opens a bottom strip.
Moving between settings does not automatically hide the full panel. Left/right adjusts,
up/down selects adjacent visual settings in that subsection, Y resets and X/B
returns. Category/subsection inputs are ignored. The game remains paused, while
picture, lighting and real head tracking continue updating immediately.

## ROM library

The empty library shows one setup action and explanation. Once games are found,
the library shows supported system cards, Recent, Favourites and Library locations.
Folder, drive and SD-card management remain inside Library locations. Select the main
ROM folder containing `snes`, `megadrive`, etc. with R1, rather than a single
system folder. System lists include subfolders, use natural title sorting, and
remember page/selection/scroll. Counts use singular/plural labels, and page numbers
appear only when there is more than one page. Left/right or L1/R1 changes pages of 50 games;
B returns to the system selector. Jump to letter opens a controller-friendly A–Z/# grid
and jumps across pages; missing letters are disabled. Ctrl+F focuses keyboard search;
Down or Enter returns to the list. X remains Favourite and J opens the alphabet when
search is not focused. Search includes Recent and Favourites.
Refresh library rescans additions/removals.
In a folder: A opens, B returns to the library, L1 goes up, X opens SD cards,
Y opens the default folder and R1 saves the current folder as default. Returning
from a child folder restores selection and scroll position. Missing folders,
cards or files retain the saved path and offer recovery instructions. Windows also provides Computer drives for browsing another drive. Supported
ROM extensions remain .sfc, .smc, .swc and .fig. No files are moved or deleted.

## Saved setups

Saved setups lists three named slots with Empty/Saved status. Open a slot for
Save, Load, Rename slot and Undo last setup load. The initial labels are
Everyday, Evening and Bright room. Names, folder paths and radio URLs support an on-screen controller keyboard with case, space, delete and cursor controls, as well as a physical keyboard. Saving an
existing setup asks for confirmation, with Cancel selected first. Cancelling a
rename leaves its prior name alone. Renaming takes effect when that setup is saved.

Setups include room, view, emulation preview and picture. Loading one preserves
physical display mode and tracking provider. Undo restores previous in-memory
preferences. Each slot retains its existing previous-version backup. Reset-all
and exiting also ask for confirmation; ordinary adjustments and closing do not.

## Per-game picture

Off by default to keep the Showcase picture global; switch it on in Saved setups. Each ROM's content SHA-256 is
its identity, so moving or renaming a game retains its preferences. Picture
fitting, CRT/glass/curvature and signal/colour settings are remembered. Room,
view, input preview and hardware calibration remain global.

Switching or stopping games saves the outgoing picture and restores the global
baseline before loading the next game's override. A game with no override uses
global picture preferences. **Use global picture settings for this game** clears
its override; future global changes apply until you customise it again.
To change the global picture baseline, return to the test signal and adjust it.

Preferences live in Godot's user-data folder: `settings.cfg`, `recent.cfg`,
`presets/slot-N.cfg` and `games/ROM-SHA256.cfg`. Files are written to a temporary
file and renamed, with a `.bak` previous version. Invalid numeric types and
non-finite values fall back safely; malformed files try the backup. Existing
settings are read without requiring a migration. No ROMs or saves are deleted.

## Startup and recovery

On a normal launch into Home, the shared menu display plays a native
boot sequence after display setup has handed over and the CRT power-on reveal
has fully finished. During tube warm-up, the planet and stars keep moving while
the logo and diamonds hold their first frame. The logo timeline and boot cue
start together once the tube reaches full power. The updated vector logo has
three diamonds and no drop shadow; its sequential diamond pulses, X-axis flip
and edge-on disappearance use samples from After Effects Comp 7. The planet moves
down and right with moon/star parallax. The menu then builds in fast, 55 ms visual-row
steps (tiles on a row appear together), followed by help and the footer. The
sequence finishes in 3.8 seconds; the menu reveal takes under a second. The
resume-game page includes its saved-frame preview and preserves Continue selection.
The existing planet rotation and pixel-snapped star drift continue into the menu.
Both eyes and the TV use the same menu texture. The supplied startup sound begins
after display setup hands over and plays its full fading tail after the UI appears.
**Menu / Audio & vibration / Boot sound** turns it off independently of menu ticks and reduced
animation; the choice is saved between launches. Revealing the menu with directions,
A, another key or a click keeps the sound playing. B (Backspace/Escape), leaving
the menu, or starting a game, video, album or radio stops the boot sound.
The menu background loop (`assets/audio/menu-bgm.wav`, from `assets/audio/source/bgm2.wav`) starts fading in four
seconds into the boot cue, as its tail begins, and reaches the chosen volume over
1.5 seconds. **Menu / Audio & vibration / Menu music** enables it; **Menu music volume**
sets its independent level (10% by default). Both preferences persist. With boot
sound disabled or cancelled, the music fades in immediately. It stops outside menus
and yields to an audible album or radio stream, returning when that is paused or
stopped. Stereo uses one shared player. The original 16.615-second stereo WAV
loops at its sample boundary. Press a key, controller button or click to skip; that press does
not activate a menu action. Reopening Home does not replay the sequence.
Reduce animation and stronger contrast bypass the visual sequence. Direct game/video
launches and capture tooling keep their existing startup. Scripted checks bypass
boot unless `--boot-preview` is supplied after `--`. `tests/menu_boot.gd` checks
completion, skip, interruption and accessibility, and captures the 2D sequence when
rendered. `tests/menu_boot_sound.gd` checks sound preference persistence, handover,
skipping, the complete audio tail and independence from visual accessibility.

### First-run setup

A new user (no saved settings) gets first-run setup straight after the boot
sequence: instead of flipping away, the boot logo stays face-on and glides down
onto the Welcome page's logo while the planet settles, and the page builds in
around it. **Let's get set up** runs six steps; **Skip setup** (or X on any step)
goes to the last page, which still shows the menu shortcut.

1. **Controls**: the menu shortcut (L1 + R1 + Start, or Escape) drawn as the
   menu's own glyphs. Pressing it lights them and turns "Can't press it right
   now? Continue" into Continue; it does not close setup or move on by itself. On other steps the shortcut and Escape say how to leave instead.
   Recentre, Back and moving the TV are shown below.
2. **Your view**: tracking status (with Connect glasses / Use fixed view when
   tracking is not running), recentring, TV distance and screen height (which
   open the same compact preview as the pause menu's, floating over the room
   whichever menu position is chosen), and
   **Menu position** (On the TV or Floating, the same `menu_on_tv` setting).
3. **Console region**: PAL, NTSC or Japan, first suggested from the system
   locale; five consoles, Dreamcast included, show their names and pictures live.
4. **Game library**: folders found automatically (EmuDeck, RetroDECK and plain
   `roms` layouts at home and on SD cards), or Browse folders, SD card / Computer
   drives and Type a path, which borrow the menu's own pickers and return here.
   The results page lists every console found, in a grid that widens from two
   to four columns as the library grows, with BIOS needs and skipped folders.
5. **Videos & music** (optional): the video folder picker (or FFmpeg setup where
   needed) and a music folder. The music folder is saved in `recent.cfg`
   (`[music] folder`) and is where the music browser opens.
6. **Comfort**: picture style and the larger text, reduced animation, menu
   music and vibration switches.

Every step's Next (or Finish) is pinned below the page, outside its scrolling
area, so it stays on screen with larger text or a long list. Pages with little
to select scroll with up and down. Finishing saves `[welcome] done=true` in
`settings.cfg`; leaving part-way keeps it false and shows setup again next time,
and reopening the menu during setup returns to it. Settings saved before setup
existed have no `[welcome]` entry and count as done, so existing users are not
shown it. Reset all settings leaves it alone; **About & Help → Run setup again**
opens it any time. It comes before the last-game chooser that the Steam
launcher's `--last-game` asks for. Launches with `--rom`, `--capture` or a test
`--script` skip it; `--welcome-preview` (after `--`) forces it.
`tests/welcome_flow.gd` covers who sees it, the logo's landing, every page,
the pickers, the pinned rows and saving, and captures each page to
`build/welcome-review/` when rendered.

Without a game to autostart, launch selects Continue when the last cartridge is available, otherwise library setup. A missing
last-game path or SD folder keeps its saved location and explains how to reconnect
or choose another folder. A ROM load failure returns to the chooser with details.

Startup guidance reports unavailable tracking. **View → Tracking** offers
**Connect glasses** or **Use fixed view**. During a tracking drop, the existing tracking implementation
holds the last view; a notice directs you to recovery. Reconnection retains its
existing continuity behaviour. The application does not infer USB detection just
from selecting SBS.

The Steam glasses launcher still shows **SWITCH TO SBS NOW**. In Desktop mode
it continues detecting Full-SBS until success or cancellation. After a slow
reconnect, the prompt stays visible with cable/button guidance. Gaming Mode
retains explicit A confirmation and explains the Native / 3840×1080 Steam
resolution workaround. B / Escape cancels. Display restoration remains owned
by the existing launcher.

Local validation includes controller section selection, named setup load/undo,
global/per-game isolation across two original diagnostic cartridges, a renamed
ROM, automatic saving, invalid-value and truncated-file recovery, missing paths,
and simulated tracking/resolution status. Actual USB reconnect and Gamescope
behaviour still require a Steam Deck check.

## Validation

Controller integration tests remove platform UI joypad bindings and exercise held
input, trigger latches, disconnect/focus loss, disabled actions, focus/scroll
restoration, compact preview, per-option resets, setup overwrite cancellation,
renaming, failed-save recovery and menu-chord release. Separate tests cover
per-game preferences, missing paths, folder defaults, mono/SBS, clean screenshots,
picture fitting and emulator input/latency. Visual checks capture only the 2D
menu viewport; licensed TV assets and scene renders are excluded from inspection.
Windows is reviewed first. Steam Deck transfer and through-glasses testing are
separate follow-up checks.

## Continue, recent games and favourites

Clean exits and game changes save a separate automatic resume point (`<ROM hash>.auto.rst`) alongside each game's states. Manual slot 0 and cartridge SRAM retain their existing locations and formats. Automatic resume requires a core that supports save states. A failed automatic save keeps the app open (or cancels the game change) so storage can be fixed and the action retried. Force-closing or losing power does not create a resume point.

Choosing a game with an automatic save offers **Continue**, **Start from a fresh boot**, and a named return destination (**Go to Home** at startup). The screen names the game and console and groups the saved screenshot and timestamp into an inset panel. Saves without screenshots show a placeholder. Continue is initially selected and checks the ROM and core identity before restoring. Unreadable or incompatible saves stay on disk and offer Start from a fresh boot as recovery. Starting fresh keeps manual states and cartridge battery saves; the automatic point updates after gameplay on the next clean exit or game change. The `--last-game` launcher uses the same chooser; explicit `--rom` remains a fresh launch for tooling.

Choose game begins with **Recently played** (up to 20 games) and **Favourites**. In either list or a system game list, press **X** to add/remove a favourite; a star marks favourites. Entries remain when removable storage is disconnected. Reconnect the card and choose the entry again. History and favourites live in `user://play-history.cfg`; the previous last-game entry migrates automatically.

Manual Save state and F5 show the game, slot and UTC save time. Load state and F8 require confirmation, defaulting to Cancel, before replacing progress. Old manual states without a timestamp still load and use their file modification time in the UI. Failed loads or saves keep errors visible. All menu screens use the same mono/SBS viewport.

## Console library

Choose game is a two-column console shelf in the shared 960×720 menu. Recently played and Favourites sit above colour-accented cartridge cards for SNES, NES, Mega Drive, Master System and Game Gear. Only consoles with supported cartridges appear; cards show game counts. All five supported consoles and the locations card fit on the same page. D-pad or arrow keys select cards, A opens one, B returns, and R1 refreshes the library. Returning restores the originating card and the game page/scroll position.

Library locations contains folder browsing, SD cards, computer drives, refresh, and default-folder management. The manual browser keeps its existing shortcuts and exposes all folders for unusual layouts. Game lists keep their 50-game pages and X favourite shortcut, with a second line showing system/collection or unavailable storage. They do not download cover art, contact metadata services or alter ROM filenames.

The incremental scanner recognises common console folder aliases (including Genesis, Super Nintendo, SMS and Game Gear). It prioritises supported system folders and skips known unsupported console trees such as PlayStation, Game Boy, arcade, Dreamcast, N64 and Sega CD. Metadata folders remain excluded. Custom collection folders still scan, and a folder such as `snes/Ports` remains valid inside a supported console tree. File detection still decides which core to use; directory names never turn an unsupported file into a supported game.

Console results appear during discovery, so the menu stays usable before the whole scan finishes. Missing-card errors offer reconnection or another library location; recent and favourite entries remain available. No persistence format, SRAM/state namespace or ROM contents changed. Original vector cartridge illustrations are drawn in code and require no additional asset licence.

Checks: `tests/library_cards.gd`, `tests/rom_index.gd`, and `tests/rom_locations.gd` cover filtering, aliases, custom folders, grid navigation, disabled cards, focus, paging, refresh and browser shortcuts. `tests/library_cards_visual.gd` captures only the 2D menu, including every console and missing storage.

## Deck Showcase defaults

The default setup was captured from the user's saved Steam Deck preferences on 15 October 2026. The central values are in `scripts/presets/showcase.gd`; a path-free reference configuration is retained in `tests/fixtures/deck_showcase.cfg` for comparison.

- PAL connection; scanlines 70%, phosphor mask 50%, glow 40%, glass reflections 40%, tube curvature 70%.
- Chroma phase noise 38% and moving signal artifacts 95%.
- Dark room: ambient 0.05, warm lamp 0.30, front fill 0.10, screen spill 40%, 90s confetti floor; room fade 3.5–7 m.
- Distance approximately 3.284 m, height 0 m, convergence 3.5 m and soft view edges 3%.
- TV-in-room audio: room amount 18%, speaker character 15%, directional strength 80%.
- Metrics overlay off. Per-game picture off by default, matching the captured configuration.

**Picture → Presets → Deck Showcase (PAL)** restores the picture, glass and curvature while retaining screen fitting, room and view. **Saved setups → Setup slots → Deck Showcase** restores the full built-in view/room/picture/audio setup and hides metrics, with Undo available. It occupies none of the three writable setup slots and retains the current display mode, platform field of view, tracking axes and per-game preference. Other CRT/composite presets now use stronger scanline/mask/glow settings and composite movement; Clean source remains the comparison reference.

Existing saved settings and per-game overrides are retained. New installs and explicit defaults resets use Showcase. Metrics is a persistent toggle under **View → Tracking → Metrics overlay**; F1 also toggles it. Closing the menu saves the choice. Native FOV remains platform-specific (24° for glasses tracking, 50° for the desktop simulation), rather than forcing the captured glasses calibration into desktop previews.

`tests/showcase_defaults.gd` compares fresh settings against the captured reference, checks metrics persistence, full-setup undo, per-option/reset-all consistency, stronger presets and preservation of fitting/room when applying a picture-only preset.
