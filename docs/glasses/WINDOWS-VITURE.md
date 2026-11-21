# VITURE glasses on Windows

CRT XR reads VITURE head tracking through VITURE's own Windows SDK. The SDK is free but can't be bundled with CRT XR, so you download it once and point CRT XR at it.

## 1. Get the SDK

Download the **Windows SDK** from [VITURE's developer page](https://www.viture.com/developer) and keep the ZIP (you don't need to extract it). Follow its terms.

## 2. Start CRT XR and set up tracking

1. Extract `CRT-XR-<version>-Windows.zip` to a folder and double-click **CRT-XR.exe**. It's unsigned: if Windows warns, choose **More info → Run anyway**.
2. On the start-up screen, choose **Set up VITURE head tracking…** and pick the SDK's ZIP (or `glasses.dll` inside it). CRT XR copies what it needs into its own settings folder, so this survives updates.
3. **Close SpaceWalker**: it holds the glasses' tracking. CRT XR warns if it's running.

You can also do step 2 later from **View & glasses → Tracking → Set up VITURE SDK**.

## 3. Play

1. Connect the glasses directly to the PC.
2. On your normal monitor, choose the glasses' display (CRT XR usually picks it for you) and select **Open glasses view**.
3. Switch the glasses to **SBS** when the view asks. It's fine if they're already in SBS.

**LB + RB + Start** opens the menu (or turn on **Menu & access → Layout → Menu shortcut → Also hold Select**); **R3** recentres.

## Troubleshooting

- **Black view**: switch the glasses back to 2D and press B / Escape to return to the start-up screen. Check the right display is selected.
- **"VITURE SDK not set up yet"**: do step 2 again with the ZIP from VITURE's site.
- **Turning goes the wrong way**: **View & glasses → Tracking → Invert** that axis.
