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

Up/down or left-stick selects rows and stops at list ends. Left/right adjusts
numbers and choices immediately. A activates actions or toggles switches. Y
resets only the selected editable option. L1/R1 changes category; L2/R2 changes
subsection once per trigger press. Category, subsection, selected row and scroll
position are remembered for the session. Child pages restore their originating
selection. Pointer hover is visually distinct and does not move controller focus.

Keyboard: arrows adjust/select; Enter or Space activates; Backspace returns;
Y resets; X previews; Q/E or Tab changes category; Z/C changes subsection.
The sidebar, subsection arrows, setting arrows and rows also support the pointer.

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

Choose game provides recent game, default folder, SD cards and folder browsing.
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

Enabled by default; switch it in Saved setups. Each ROM's content SHA-256 is
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
