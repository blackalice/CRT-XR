# TV and picture preferences

The display policy lives in `scripts/ui/display_preferences.gd`. The settings
catalog, playback transitions and controller shortcuts all use that policy.

TV selection and game rendering are separate choices. A wide cabinet does not
patch a game, stretch its source or enable an emulator hack.

Startup restores `last_screen` and that TV's viewing profile before the boot menu
or Continue chooser. This is separate from platform/game/video defaults: launching
a different programme still follows its own TV preference. Scope previews do not
replace the last-used programme TV. Older settings fall back to the saved cabinet.
Quick settings → Display combines TV and fitting: each TV offers Fit, Crop and
Stretch. It saves the current game/video's choice without changing platform
defaults. Crop maps to the existing Fill mode; Stretch changes proportions.
Music volume lives in the audio player's transport row: a speaker icon and a
fixed-width percentage slot reserved for 100%. A starts/finishes adjustment,
left/right changes the level, and B finishes without closing the menu. The
visualiser key is icon-only, retaining its focus help and accessible label.
The info box reserves one line on Home and two in settings. Its text cannot
resize the page; help copy is checked in both keyboard and controller forms.

| Preference | Resolution order |
| --- | --- |
| Game TV | Game override → platform preference → games default |
| Video TV | Video override → videos default |
| Game picture on each TV | Game fields → platform fields → game TV defaults → migrated baseline |
| Video picture on each TV | Video fields → video TV defaults → migrated baseline |
| Placement | Fixed/XR viewing profile for the selected TV |

PS2, GameCube and PSP default to Wide TV (Stretch). All other platforms, including
Wii and Dreamcast, default to 4:3 TV (Fit). This versioned defaults update also
applies to existing settings, preserving per-game overrides, viewing profiles and
other picture fields. Videos retain their separate defaults. Games with anamorphic output can
select 16:9 under Picture aspect ratio; plain 4:3 stretching is a separate fitting
choice. Verified emulator widescreen options are available under Emulation and
retain the existing platform/per-game core-option inheritance and reload rules.

Picture → TV & defaults selects whether edits apply to this game/video, platform
defaults or TV defaults. Defaults are previewed without the programme's higher
overrides. Closing settings restores the programme's effective picture and TV.
Resetting a picture option removes its override at the selected level; clearing
picture changes removes that level's whole patch for this TV. Room and saved
lighting presets retain the active cabinet. Saved setups deliberately apply their
picture to the currently edited context and their placement to the active TV.

The stored picture patches contain only changed fields, so later default changes
flow through untouched fields. Games use ROM content identity; videos use the
existing file path identity. Both standard and wide settings remain available when
a programme changes its selected TV. Distance, height and physical scale are stored
per TV and fixed/XR view; eye calibration and tracking preferences remain device
settings. Menu lean-in is temporary and does not replace seating distance.

The versioned `display_profiles/data` dictionary in settings.cfg stores this data.
The existing atomic settings writer and backup apply. Existing cabinet baselines,
enabled legacy game files and shared video profiles are migrated lazily for each
TV. The originals remain intact. Invalid profile fields fall back or clamp to their
allowed ranges. `restore_settings` restores a complete persisted configuration;
`apply_settings` applies preset fields without replacing the active edit context.

Core AV information and runtime geometry callbacks carry display aspect through
both synchronous and threaded playback. Unspecified core aspect falls back to the
platform's established ratio. Image-only stream/preview packets retain the last
reported ratio rather than treating missing metadata as a fallback request. This
prevents alternating widths between core metadata polls and fresh image uploads.
Video's original-aspect mode emits an unletterboxed
frame at the existing line budget plus its display aspect; the TV performs fitting
once. The legacy 4:3 broadcast styles remain available. Subtitle and VCR text use
the same display aspect. The TV menu uses a 960×720 canvas on standard and
1280×720 on wide. Main sections remain centred at their original 888×664 reading
size; only the backdrop expands to the canvas edges. Menu fitting fills the tube
independently of the programme's overscan, crop and picture offsets. Floating
adjustment previews retain the original canvas. The programme's raster, aspect
and picture settings are restored on close.

The CRT shader blends only the picture/border transition using final-screen
derivatives. It does not filter the interior image. Optional 2×/4× geometry MSAA
affects both eye viewports and defaults off; target-hardware cost remains to be
measured. No FXAA, TAA, supersampling or change to core resolution is introduced.

Coverage includes display inheritance and restart/migration tests, menu actions,
rendered edge/interior comparisons, picture fitting, all menu layouts, video
playback, and native geometry/aspect and video-layout tests. Steam Deck visual and
performance validation remains a hardware check.
