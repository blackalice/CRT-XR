# CRT XR Menu Implementation Brief

Implement the approved Home, Pause, and Settings layouts for CRT XR. Use the Figma frames for the new presentation and the deployed Steam Deck build `ux-overhaul-20261116d` as the baseline for menu content, platform-specific controls, and existing game and media flows. The approved Home frames cover both menu aspect ratios. The compact Pause and Settings mockups establish the **4:3** layout at **960 × 720**. [Current designs](https://www.figma.com/design/8A6e3EZ7UYJHF65lwHV893?node-id=0-1)

## Home and game Pause

### Shared layout

- Centre an **852 px** reading area on the **960 × 720** standard and **1280 × 720** widescreen menu canvases. That places its edges at **x = 54 and 906** in 4:3, and **x = 214 and 1066** in 16:9. Use the backdrop appropriate to each canvas.
- Align Media and Quick Settings on three **278 px** columns with **9 px** gaps. Quick Settings uses **44 px** rows with **6 px** between them. Put labels and values on the same line. Use **Screen fit** for the setting label and **Fit**, **Fill**, or **Stretch** for its value. Tint its icon to match the other setting icons.
- Keep Actions, selection help, and controller shortcuts anchored near the bottom. At 720 px tall, the Actions tiles start at **y = 525**, the help window at **y = 588**, and the shortcut row at **y = 638**. Use four equal Action slots with **9 px** gaps and populate them for the current state.

### Home without a recent game

- Lead with three equal **112 px** Media tiles labelled **Games**, **Videos**, and **Music Player**, with larger icons above their labels. Give Games initial focus. Keep the existing library and onboarding paths for setting up games.
- Keep Quick Settings below Media. The approved first-run example shows **Settings** and **Using glasses** in Actions. Retain the context-sensitive view action where the current library and view state call for it. [4:3 and 16:9 Home frames](https://www.figma.com/design/8A6e3EZ7UYJHF65lwHV893?node-id=27-4315)

### Home with Continue

- Lead with a full-width **84 px** Continue card for the last available game. Show its saved gameplay thumbnail, title, console, and available play history. Put **Continue ›** at the right edge, vertically centred. Preserve the existing game launch and resume selection flow.
- Match the Media tiles to the Continue card’s **84 px** height. Keep the card’s focus treatment and preview as the primary visual cue.
- Use **Settings**, **Recentre view**, **Using glasses**, and **Favourite** in Actions. Favourite targets the game shown in Continue. [4:3 and 16:9 Continue frames](https://www.figma.com/design/8A6e3EZ7UYJHF65lwHV893?node-id=27-4571)

### Game Pause

- Use an **84 px** top row with a **549 px** current-game card and three **92 px** tiles for **Save**, **Load**, and **Reset**, separated by **9 px**. Put each action icon above its label. The current-game card shows the frame where play paused, the game title, console and session duration, and a centred chevron on the right.
- Reserve **72 px** of preview height. Fit a 4:3 source at **96 × 72** and a 16:9 source at **128 × 72**. Both Figma Pause examples use the same 4:3 menu canvas and demonstrate the two gameplay image shapes.
- Keep the compact **44 px** Media row and Quick Settings beneath the game card. Use **Settings**, **Screenshot**, **Recentre view**, and **Favourite** in Actions. Favourite targets the loaded game. Keep Save, Load, and Reset connected to the existing save-slot actions and reset confirmation. [Compact Pause frames](https://www.figma.com/design/8A6e3EZ7UYJHF65lwHV893?node-id=22-3415)

### Home and Pause implementation

1. Build the shared Media, Quick Settings, and pinned Actions groups around `menu_play.gd` and `menu_controller.gd`. Route Games, Videos, and Music Player through their existing destinations and playback state. Keep the controller focus order aligned with the visible rows and retain contextual help.
2. Use the emulator’s last clean game frame for the Pause preview and the existing resume or save thumbnail for Continue. Fit each image at its source aspect ratio. If a thumbnail is missing, use the existing cover or console icon fallback.
3. Use the existing play history and favourite store. Show **Favourite** with an outline heart and **Favourited** with a filled amber heart. Refresh the action state immediately after a successful toggle and preserve it across reloads.

### Home and Pause acceptance checks

- Compare both Home states at 4:3 and 16:9. Check focus, the 112 px and 84 px Media heights, the shared column edges, and the bottom anchors. Try a long game title, no compatible recent game, and a missing preview.
- Pause with a 4:3 and a 16:9 game source. Verify the preview shows the paused moment and preserves its shape. Check that the chevron resumes play, Save and Load reach the correct slots, and Reset asks before restarting.
- Toggle Favourite in Continue and Pause, then verify the matching game and the displayed state in the library. Exercise the existing media destinations and Quick Settings with a controller. Use the existing `wide_menu_canvas.gd`, `menu_layout.gd`, `menu_navigation.gd`, and `state_previews.gd` checks as regression coverage.

## Settings

Start with **Picture → Tube** on the 4:3 Steam Deck menu, then exercise the same layout with Tracking and Volumes using their existing platform-specific controls. [Collapsed rail](https://www.figma.com/design/8A6e3EZ7UYJHF65lwHV893?node-id=53-1506) · [Open drawer](https://www.figma.com/design/8A6e3EZ7UYJHF65lwHV893?node-id=53-2449)

### Approved Settings design

- Keep the **54 px** outer margins and **9 px** column gaps. The compact rail is **68 px** wide. The open drawer is **330 px** wide. Both start at **y = 104**, are **509 px** tall, and use **48 px** category rows with **8 px** gaps. Keep the icons at the same vertical positions during expansion.

- Use the Steam Deck’s individual L1/R1 and L2/R2 badges. Keep the approved **4 px** gap between the two badges, with the shoulders in the category header and the triggers in the tab bar. The controller hints sit along the bottom.

- Picture → Tube uses a **532 px** settings column with **56 px** rows, compact segmented meters, and a **234 px** pale blue help panel with dark text. Align the top of the help panel with the first row and anchor the inheritance details at its bottom. Populate the panel from the focused setting’s actual help text and source, letting long descriptions wrap or scroll.

- The drawer overlays the controls and dims the background. The category highlight shows where controller input is directed. Keep the footer visible with **A Done** and **B Back**.

### Settings controller behaviour

- **L1/R1** reveal the labelled drawer. For the first pass, keep the existing shoulder-button cycling behaviour. The first press also steps one category in the pressed direction. Each subsequent shoulder press steps again and restarts the **1.2 second** timer used in the prototype.

- **A** dismisses the open drawer and returns focus to the selected category’s settings. Consume that press so it cannot also activate the focused setting. The timeout returns focus to the same place.

- **B** backs out to the previous screen from either drawer state. Use the existing origin stack for Home, Pause, and direct links into Settings. A visible drawer should never turn B into a Categories shortcut.

- With the drawer collapsed, **L2/R2** switch tabs and **View** changes scope where available. Display the focused control’s existing context-specific hints for adjustment, inheritance, and preview.

### Settings implementation

1. In `scripts/ui/menu_controller.gd`, add the collapsed and expanded presentation around the existing category navigation, using its category order, saved tab, focus, and scroll state. Route the Settings shoulder, A, and B inputs through the drawer state before setting-row activation. Use one restartable timer and clear it when the drawer or Settings closes.

2. Reuse `scripts/ui/menu_catalog.gd` and the existing row and scope data for labels, values, visibility, help, disabled reasons, and inheritance. Keep Basic and Advanced filtering, per-game/console scope, and setting persistence active in the new layout.

3. Build the compact Settings row presentation on the existing row styles and segmented meters. Reuse `scripts/ui/input_glyph.gd` and the menu theme for the badge shapes, colours, dot font, and focus treatment. Keep one active focus indicator while the drawer is open.

### Settings acceptance checks

- Compare both 4:3 states with the Figma frames at native menu size. Check equal outer margins, legible badges clear of the rail border, stable category positions, long labels, and Larger menu text.

- On Steam Deck, test single and rapid L1/R1 presses, wraparound, timer restart and dismissal, A dismissal without changing a setting, and B from both states and direct Settings links. Confirm the chosen tab, focused row, and scroll position restore appropriately.

- In Picture, verify This game, All SNES games, and Game defaults, along with inheritance and X Preview. In Tracking, verify XR Gaming and Linux-specific labels. In Volumes, check group scrolling and the unavailable Room sound explanation.

- Run the existing `menu_layout.gd`, `menu_navigation.gd`, `menu_reorganisation.gd`, `controller_menu.gd`, and `picture_controls.gd` checks. Add a focused regression check for the drawer’s timeout and A/B routing.
