# New in development builds

Development builds add five consoles beyond the 15 systems in beta.15. GameCube, Wii, PlayStation 2 and PSP are experimental Steam Deck integrations. Each requires the matching Linux core and a development opt-in. Dreamcast uses Flycast and is also available in Windows development builds.

| Console | Core | Game folder | Setup and compatibility |
|---|---|---|---|
| Dreamcast | Flycast | `dreamcast/` | CHD, GDI and CDI, with M3U playlists for multi-disc games. The first player's VMU can appear as a floating LCD below the TV. [Dreamcast guide](docs/emulation.md#dreamcast-development) |
| GameCube | Dolphin | `gamecube/` | ISO, GCM, RVZ and WIA. Includes C-stick and analogue trigger mappings. [GameCube guide](docs/gamecube-integration.md) |
| Wii | Dolphin | `wii/` | ISO, RVZ, WIA and WBFS. Uses a Wii Remote with Classic Controller layout. [Wii setup](docs/wii-ps2-psp.md) |
| PlayStation 2 | LRPS2 | `ps2/` | ISO, supported cue sheets and CHD. Requires a PS2 BIOS. Internal resolution and EE cycle rate can be set per console or game. [PS2 setup](docs/wii-ps2-psp.md) |
| PlayStation Portable (PSP) | PPSSPP | `psp/` | ISO, CSO and PSP PBP eboots. Plays at the PSP's native widescreen resolution by default. [PSP setup](docs/wii-ps2-psp.md) |

- **Choose your TV.** Use the standard 4:3 CRT or a wider 16:9 cabinet in silver or black. First-run setup lets you choose one TV for all consoles or start with choices by console. Videos have their own starting TV. Each cabinet remembers its placement for desktop and XR use.
- **Fit the game to either TV.** A 4:3 game can play on the wide CRT with side borders, and a widescreen game can play on the standard CRT with borders above and below. **Fit** preserves the whole image and its shape, **Fill** crops the edges, and **Stretch** fills the screen by changing the shape. **Quick settings → TV & fit** adjusts both for the current game or video. [Picture controls](docs/picture-controls.md)
- **Know what you’re editing.** The settings sidebar has eight categories. **TV & picture** shows whether changes apply to this game or video, the console, or the TV defaults. **Games & controls** groups mappings and emulator options. Video Library and the music browser open their own settings, and Back returns to the same selection.
- **Read and adjust in place.** The settings frame stays put as you move between pages. Long choices use the space beside their labels before wrapping. **Clearer menus**, larger text, higher contrast and reduced animation are in **Menu & access → Accessibility**. The idle menu can show a drifting logo screensaver. [Settings and startup](docs/settings-and-startup.md)

The menu paths below describe the development build. The public beta.15 packages listed next contain the features described in their release notes.
