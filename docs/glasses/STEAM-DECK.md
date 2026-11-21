# Glasses on Steam Deck

Head tracking on the Deck comes from **Decky Loader** and its **XR Gaming** plugin. CRT XR reads the tracking from XR Gaming's driver and draws its own side-by-side picture, so you don't need XR Gaming's virtual display.

## 1. Install Decky Loader

In **Desktop Mode**, download Decky Loader from [decky.xyz](https://decky.xyz) and run its installer. Back in **Gaming Mode**, the **⋯** (Quick Access) button now has a plug icon for Decky.

## 2. Install XR Gaming

Open Decky (the plug icon) → the store icon → search **XR Gaming** → Install. Open XR Gaming from Decky, connect your glasses and follow its setup until it shows them connected. Use a current XR Gaming release; it supports VITURE (Pro 2 included), XREAL, Rokid and RayNeo glasses.

## 3. Install CRT XR

1. In Desktop Mode, download `CRT-XR-<version>-SteamDeck.tar.gz` from [Releases](https://github.com/blackalice/CRT-XR/releases) and extract it (right-click → Extract).
2. Double-click **Install CRT XR** (choose **Trust and Launch** if asked).
3. Choose **XR glasses (and the Deck screen)**. Setup checks for Decky and XR Gaming and tells you if anything is still missing.
4. Let it close Steam, then choose **Return to Gaming Mode** when it offers. CRT XR is under **Library → Non-Steam**.

## 4. Play

1. In XR Gaming, keep the **virtual display off** for CRT XR. CRT XR switches XR Gaming into tracking-only mode while it runs and puts your settings back when you quit.
2. Connect the glasses in **2D (mono)** and launch CRT XR.
3. Put them on and switch them to **SBS** with their button when asked (glasses XR Gaming can switch are switched for you). The view goes dark for a moment, then the room appears.
4. When you quit, switch the glasses back to 2D when asked.

Without glasses, CRT XR starts in Flat view on the Deck's screen; choose **XR view** on Home to see the room.

## Troubleshooting

- **The installer says Decky Loader or XR Gaming is missing**: finish steps 1 and 2, then run the installer again. CRT XR still works without them, with a fixed view.
- **"XR Gaming is installed but its driver is not set up yet"**: open XR Gaming in Decky and complete its setup with the glasses connected.
- **Black screen in the glasses**: CRT XR's Steam game resolution must be 3840 × 1080 (Properties → General → Game resolution). The installer sets it; Native alone doesn't work.
- **No tracking**: **View & glasses → Tracking → Reconnect glasses**. Check XR Gaming shows the glasses as connected.

More: [Gaming Mode details](../gaming-mode.md) · [Display setup](../display-setup.md)
