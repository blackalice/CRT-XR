# XREAL, Rokid, RayNeo and other glasses on Windows

For glasses other than VITURE, CRT XR follows head tracking from any app that sends **OpenTrack UDP** to this computer. Side-by-side 3D works with any glasses that have a full SBS mode.

## 1. Run a tracking app

Pick the one for your glasses, and set it to send **OpenTrack UDP to 127.0.0.1, port 4242**:

- **XREAL**: [PhoenixHeadTracker](https://github.com/iVideoGameBoss/PhoenixHeadTracker)
- **Rokid, RayNeo**: VertoXR
- **Anything else with tracking**: [opentrack](https://github.com/opentrack/opentrack), output **UDP over network**

## 2. Start CRT XR

1. Extract `CRT-XR-<version>-Windows.zip` and double-click **CRT-XR.exe** (if Windows warns, **More info → Run anyway**).
2. Choose the glasses' display, select **Open glasses view**, and switch the glasses to SBS when asked.
3. Open the menu (**LB + RB + Start**) → **Settings → View & glasses → Tracking → Tracking source → OpenTrack**.

The status reads *OpenTrack UDP / LIVE 3DoF* once poses arrive. CRT XR only listens on 127.0.0.1, so only this computer can send.

## Tips

- **Turning or tilting goes the wrong way**: OpenTrack has no fixed sign convention. Use **Invert yaw / pitch / roll** on the same page.
- **The TV slides as you turn**: adjust **View & glasses → Calibration → Vertical field of view** (shown with **Show advanced settings** on).

This route has been tested with simulated tracking but not yet with real XREAL, Rokid or RayNeo glasses. Please [report how it goes](https://github.com/blackalice/CRT-XR/issues).
