# Roughstock TV

Roku channel for displaying photos and videos from a USB thumb drive (e.g. gym info, ads, pricing on a TV), and a **round timer** for jiu jitsu/wrestling. From the home screen choose **Scrolling photos & videos** (Photos only, Videos only, or Both) or **Round timer**.

## USB layout

At the **root** of the USB drive create folders with exactly these names (capital P and V for media):

```
USB root/
├── Photos/     ← .jpg, .png, .gif
├── Videos/     ← .mp4, .mkv, .mov
└── Roughstock/
    └── announcements.txt   ← optional; text shown on the timer screen (class announcements)
```

Use FAT32 or NTFS. Plug the USB into the Roku TV’s USB port. The channel checks both `ext1:/` and `ext2:/` for these folders.  
If you copy files from a Mac, it may create hidden `._` files (e.g. `._image.png`); the app skips these and only shows real images.

## Viewing logs (debugging)

When the channel shows a blank screen or misbehaves, use the **BrightScript debug console** to see runtime errors and any `print` output:

1. **Enable developer mode on the Roku**
   - Settings → System → Developer options (or enter your Roku’s IP in a browser and use “Developer Application Installer”).
   - Turn on “Developer Application Installer” and note your Roku’s IP (e.g. Settings → Network → About).

2. **Connect to the debug console**
   - **Mac (no telnet):** use netcat (built in):  
     `nc <ROKU_IP> 8085`  
     Example: `nc 192.168.1.100 8085`  
     Output appears in the terminal. Press **Ctrl+C** to disconnect.
   - **Mac or Linux (with telnet):** `telnet <ROKU_IP> 8085`
   - **Windows:** enable “Telnet Client” in Settings, or use PuTTY (Telnet, port 8085).

3. **Reproduce the issue**
   - Launch Roughstock TV again. The channel does not emit debug logs by default; you will see runtime errors and crashes if they occur. Add `print` statements in the BrightScript code if you need trace output.
   - If you don’t see any output, the channel may not be loading (check that you installed the latest zip and launched “Roughstock TV”). If connection to 8085 is refused, ensure developer mode is on and try rebooting the Roku.

## Run the channel

1. Install [Roku Developer SDK](https://developer.roku.com/docs/developer-program/getting-started/roku-dev-prog.md) and enable Developer Application Installer on your Roku device.
2. Zip the channel (manifest, source/, components/, images/ at the root of the zip).
3. Sideload via the Roku developer dashboard or `curl` to your device’s plugin_install endpoint.

Example zip from project root:

```bash
zip -r roughstock-tv.zip manifest source components images
```

Then install the zip as a developer channel on your Roku TV.

## Round timer

- **Timer screen**: Roughstock Jiu Jitsu logo (background), round/rest countdown, round number, "Next round in" during rest, optional current time, optional sponsor logos, class announcements (from USB `Roughstock/announcements.txt` if present).
- **Timer settings** (open with **Options** or **\*** on the timer screen): show sponsor logos, font size (small/medium/large), show current time, font color (white/yellow/red/green), round duration (1/3/5 min), rest between rounds (30/60/90 sec). **Back** from timer returns to the home screen.

## Sponsor logos

Place PNG images in `images/sponsors/` (e.g. `sponsor1.png`, `sponsor2.png`) to show on the timer screen. Enable "Sponsors: Yes" in Timer settings.

## Media (slideshow) settings

From the media mode list (after choosing “Scrolling photos & videos”), select **Settings** to adjust:

- **Display** – Slideshow (auto-advance) or one-at-a-time (use remote left/right to change image).
- **Seconds per slide** – 5, 10, 15, 20, 30, 45, or 60.
- **Order** – Loop (sequence) or Shuffle.
- **Transition** – None, Fade, Zoom in, Slide, or Random.

Choose “Save and Back” to return to the mode list.

## Navigation

- **Back**: From the timer screen → home. From timer settings → timer screen. From the media mode list → home. From playback (photos/videos) → media mode list. From the no-USB or no-content message → home.
- **Options** or **\*** on the timer screen opens Timer settings.

## Project layout

- `manifest` – Channel metadata and version
- `images/roughstock-orig.jpg` – Main screen background logo (watermark). Roku doesn’t support SVG; to use `roughstock.svg` instead, export it to PNG (e.g. 1280×720), save as `images/roughstock-bg.png`, and in `MainScene.xml` set `mainBgLogo`’s `uri` to `pkg:/images/roughstock-bg.png`.
- `source/main.brs` – Entry point, creates SceneGraph screen and MainScene
- `images/rjj-logo.png` – Timer screen background (Roughstock Jiu Jitsu).
- `images/sponsors/` – Optional sponsor logos for the timer (e.g. `sponsor1.png`, `sponsor2.png`).
- `components/MainScene.xml` – UI: home list, mode list, timer group, poster, video, timer
- `components/MainScene.brs` – USB discovery (ext1/ext2), home and mode list, media playback (photos/videos/both), media settings, round timer and timer settings, key handling

## Notes

- **USB path**: Roku exposes USB drives as `ext1:/` and `ext2:/`. The channel checks both and looks for `Photos/` and `Videos/` (capital P and V) at the root, plus `Roughstock/announcements.txt` for the timer. Playlists use supported file extensions only.
- **Home screen**: On launch you choose "Scrolling photos & videos" or "Round timer". If you choose media and no USB or no content is found, the channel shows instructions to insert a USB with `Photos` and `Videos` folders. The round timer works without USB.
- If you choose “Photos only” or “Videos only” and that folder is empty (or missing), the channel shows a short message (e.g. “No photos found…”) and returns to the mode list so you can pick another mode or go Back to home.
- Default slide duration is 10 seconds (configurable in Settings from 5–60 sec). “Both” mode shows 5 photos then one video, then repeats.
