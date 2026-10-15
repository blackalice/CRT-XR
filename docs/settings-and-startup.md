# Settings, saved setups and startup

This update is local only. The installed Steam Deck build has not changed.

## Pause menu and settings

L1 + R1 + Start or Escape opens the pause menu: Resume, Choose game, Save state,
Load state, Screenshot, Settings and Exit. Unavailable actions are disabled and
skipped. Opening with a game selects Resume; without a game it selects Choose game.
R3 remains the recenter shortcut. B returns one level; B at the pause menu saves
preferences and resumes the previous game state. The menu chord / Escape closes
from any page. If saving fails, the menu stays open with its selection and an error.

Settings have five categories, with separate subsection pages:

| Category | Subsections |
|---|---|
| View | Placement; Display |
| Picture | CRT; Screen fit; Colour; Signal; Presets |
| Room | Lighting; Materials; Placement & fade |
| Controls & XR | Controller; Tracking; Calibration |
| Saved setups | Setup slots; Per-game picture |

Up/down or left-stick selects rows and stops at list ends. While browsing,
Left/right changes the category in the sidebar. **A selects an option for editing**;
its marker becomes a diamond, its border strengthens and adjustment arrows appear.
Left/right then changes that value, with live updates. **A or B finishes editing**
and keeps the value; B returns to the previous page only when not editing.
Numbers, choices and switches share this interaction. Actions still run with A.
Y resets only the selected editable option, in either browsing or editing mode.
L1/R1 also changes category; L2/R2 changes subsection once per trigger press.
Shoulders/triggers and row navigation are ignored while editing. All subsection
names appear as clickable tabs, with a marker for the active one and an explicit
position/count such as “Screen fit · 2 of 5”. Category, subsection, selected row and scroll
position are remembered for the session. Child pages restore their originating
selection. Pointer hover is visually distinct and does not move controller focus.

Keyboard: Up/down selects; Left/right changes category until Enter or Space
starts editing, then adjusts the value. Enter/Space finishes editing; Backspace
finishes editing or returns one level;
Y resets; X previews; Q/E or Tab changes category; Z/C changes subsection.
The sidebar, subsection arrows, setting arrows and rows also support the pointer.
Clicking another row/category finishes the current edit without undoing its changes.

The selected row has a contrasting background, amber border and arrow marker.
The fixed help area explains it; values show suitable units. Picture pages state
whether changes are global or belong to the loaded game. Everything uses the
same 960×720 menu texture in both eyes, without extra 3D passes. The menu viewport
and UI processing stop while closed.

## Compact adjustment preview

X on a visual setting replaces the page with a bottom strip. Left/right adjusts,
up/down selects adjacent visual settings in that subsection, Y resets and X/B
returns. Category/subsection inputs are ignored. The game remains paused, while
picture, lighting and real head tracking continue updating immediately.

## ROM library

Choose game scans the saved root and shows supported systems with game counts,
plus recent game, default folder, SD cards and manual browsing. Select the main
ROM folder containing `snes`, `megadrive`, etc. with R1, rather than a single
system folder. System lists include subfolders, use natural title sorting, and
remember page/selection/scroll. Left/right or L1/R1 changes pages of 50 games;
B returns to the system selector. Refresh library rescans additions/removals.
In a folder: A opens, B returns to the library, L1 goes up, X opens SD cards,
Y opens the default folder and R1 saves the current folder as default. Returning
from a child folder restores selection and scroll position. Missing folders,
cards or files retain the saved path and offer recovery instructions. Windows also provides Computer drives for browsing another drive. Supported
ROM extensions remain .sfc, .smc, .swc and .fig. No files are moved or deleted.

## Saved setups

Saved setups lists three named slots with Empty/Saved status. Open a slot for
Save, Load, Name for next save and Undo last setup load. The initial labels are
Everyday, Evening and Showcase; optional names use keyboard entry. Saving an
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

Without a game to autostart, launch opens the shared pause menu with Choose game selected. A missing
last-game path or SD folder keeps its saved location and explains how to reconnect
or choose another folder. A ROM load failure returns to the chooser with details.

Startup guidance reports unavailable tracking. **Controls & XR → Tracking** offers
**Use glasses / retry** or **Use fixed view**. During a tracking drop, the existing tracking implementation
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

Choosing a game with an automatic save offers **Continue**, **Start fresh**, and **Back**. Continue checks the ROM and core identity before restoring. Unreadable or incompatible saves stay on disk and offer Start fresh as recovery. Starting fresh keeps manual states and cartridge battery saves; the automatic point updates after gameplay on the next clean exit or game change. The `--last-game` launcher uses the same chooser; explicit `--rom` remains a fresh launch for tooling.

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
- Dark room: ambient 0.05, warm lamp 0.30, front fill 0.10, screen spill 40%, no rug; room fade 3.5–7 m.
- Distance approximately 3.284 m, height −0.15 m, convergence 3.5 m and soft view edges 3%.
- TV-in-room audio: room amount 18%, speaker character 15%, directional strength 80%.
- Metrics overlay off. Per-game picture off by default, matching the captured configuration.

**Picture → Presets → Deck Showcase (PAL)** restores the picture, glass and curvature while retaining screen fitting, room and view. **Saved setups → Setup slots → Deck Showcase** restores the full built-in view/room/picture/audio setup and hides metrics, with Undo available. It occupies none of the three writable setup slots and retains the current display mode, platform field of view, tracking axes and per-game preference. Other CRT/composite presets now use stronger scanline/mask/glow settings and composite movement; Clean source remains the comparison reference.

Existing saved settings and per-game overrides are retained. New installs and explicit defaults resets use Showcase. Metrics is a persistent toggle under **Controls & XR → Tracking → Metrics overlay**; F1 also toggles it. Closing the menu saves the choice. Native FOV remains platform-specific (24° for glasses tracking, 50° for the desktop simulation), rather than forcing the captured glasses calibration into desktop previews.

`tests/showcase_defaults.gd` compares fresh settings against the captured reference, checks metrics persistence, full-setup undo, per-option/reset-all consistency, stronger presets and preservation of fitting/room when applying a picture-only preset.
