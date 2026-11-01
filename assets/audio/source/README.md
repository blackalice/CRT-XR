# Audio authoring sources

Original user-supplied recordings, renders and FL Studio project, preserved with their original filenames and import metadata. Godot ignores this directory via `.gdignore`; export presets also explicitly exclude it.

Runtime assets stay in the parent directory:

| Original source | Runtime asset |
| --- | --- |
| `NewBoot.wav` | `../boot.wav` (identical copy) |
| `bgm2.wav` | `../menu-bgm.wav` (identical copy) |
| `click.mp3` | `../menu-click.mp3` (identical copy) |
| `untitled.wav` | No current runtime reference |
| `untitled.flp` | Authoring project; not loaded by the app |

Use the runtime asset paths in application scripts. Source import metadata is retained for completeness; it is not used by Godot here.
