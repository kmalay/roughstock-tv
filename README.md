# Roughstock TV

Roku channel for displaying photos and videos from a USB thumb drive (e.g. gym info, ads, pricing on a TV), and a **round timer** for jiu jitsu/wrestling. From the home screen choose **Scrolling photos & videos** (Photos only, Videos only, or Both) or **Round timer**.

## USB layout

At the **root** of the USB drive create folders with exactly these names (capital P and V for media):

```
USB root/
├── Photos/           ← .jpg, .png, .gif
├── Videos/            ← .mp4, .mkv, .mov
└── announcements.txt ← optional; text shown on the timer screen (class announcements)
```

Use FAT32 or NTFS. Plug the USB into the Roku TV's USB port. The channel checks both `ext1:/` and `ext2:/` for these folders.  
If you copy files from a Mac, it may create hidden `._` files (e.g. `._image.png`); the app skips these and only shows real images.

## Viewing logs (debugging)

When the channel shows a blank screen or misbehaves, use the **BrightScript debug console** to see runtime errors and any `print` output:

1. **Enable developer mode on the Roku**
   - Settings → System → Developer options (or enter your Roku's IP in a browser and use "Developer Application Installer").
   - Turn on "Developer Application Installer" and note your Roku's IP (e.g. Settings → Network → About).

2. **Connect to the debug console**
   ```bash
   ./scripts/logs.sh
   ```
   This connects to port 8085 on your Roku (using `ROKU_IP` from `.env`). Press **Ctrl+C** to disconnect.

3. **Reproduce the issue**
   - Launch Roughstock TV again. The channel does not emit debug logs by default; you will see runtime errors and crashes if they occur. Add `print` statements in the BrightScript code if you need trace output.
   - If you don't see any output, the channel may not be loading (check that you installed the latest zip and launched "Roughstock TV"). If connection to 8085 is refused, ensure developer mode is on and try rebooting the Roku.

## Run the channel

1. Install [Roku Developer SDK](https://developer.roku.com/docs/developer-program/getting-started/roku-dev-prog.md) and enable Developer Application Installer on your Roku device.
2. Zip the channel (manifest, source/, components/, images/, sounds/ at the root of the zip).
3. Create a `.env` file in the project root (not checked in) with your device IP and developer password:
   ```
   ROKU_IP=192.168.86.34
   ROKU_PASSWORD=your_password
   ```
4. Zip and sideload in one step:
   ```bash
   ./scripts/sideload.sh
   ```
   This zips the channel into `roughstock-tv.zip` at the project root and installs it on the Roku.

## Round timer

- **Timer screen**: Roughstock logo (background, same as main screen), round/rest countdown, round number, "Next round in" during rest, optional current time, optional sponsor logos, class announcements (from USB root `announcements.txt` if present). A short **beep** plays when a round or rest period ends.
- **Timer settings** (open with **Options** or **\*** on the timer screen): **Preset** (Custom, 1 min/10 s rest, 2 min/10 s rest, 3 min/10 s rest), show sponsor logos, font size (small/medium/large), show current time, font color (white/yellow/red/green), round duration (1/2/3/5 min), rest between rounds (10/30/60/90 sec). **Back** from timer returns to the home screen.
- **Remote on timer**: **Play** = pause or resume the round/rest. **Right** = jump to next (round → rest, or rest → next round). **Left** = jump to previous (rest → current round, or round → previous rest).

## Sponsor logos

Place PNG images in `images/sponsors/` (e.g. `sponsor1.png`, `sponsor2.png`) to show on the timer screen. Enable "Sponsors: Yes" in Timer settings.

## Media (slideshow) settings

From the media mode list (after choosing "Scrolling photos & videos"), select **Settings** to adjust:

- **Display** – Slideshow (auto-advance) or one-at-a-time (use remote left/right to change image).
- **Seconds per slide** – 5, 10, 15, 20, 30, 45, or 60.
- **Order** – Loop (sequence) or Shuffle.
- **Transition** – None, Fade, Zoom in, Slide, or Random.

Choose "Save and Back" to return to the mode list.

## Navigation

- **Back**: From the timer screen → home. From timer settings → timer screen. From the media mode list → home. From playback (photos/videos) → media mode list. From the no-USB or no-content message → home.
- **Options** or **\*** on the timer screen opens Timer settings.

## Project layout

- `manifest` – Channel metadata and version
- `images/roughstock-orig.jpg` – Main screen background logo (watermark). Roku doesn't support SVG; to use `roughstock.svg` instead, export it to PNG (e.g. 1280×720), save as `images/roughstock-bg.png`, and in `MainScene.xml` set `mainBgLogo`'s `uri` to `pkg:/images/roughstock-bg.png`.
- `source/main.brs` – Entry point, creates SceneGraph screen and MainScene
- `images/roughstock-bg-16x9.jpg` – Main and timer screen background logo (watermark).
- `images/sponsors/` – Optional sponsor logos for the timer (e.g. `sponsor1.png`, `sponsor2.png`).
- `sounds/beep.m4a` – 3-second continuous beep (AAC) played when a round or rest ends. **Generate with ffmpeg:** (1) Install ffmpeg: `brew install ffmpeg` (if Homebrew says directories are not writable, run the `sudo chown` command it suggests, then retry). (2) From the project root run: `./scripts/generate_beep_m4a.sh`. (3) Include the `sounds/` folder (with `beep.m4a`) in your channel zip.
- `scripts/sideload.sh` – Zips the channel and sideloads it to the Roku device. Reads `ROKU_IP` and `ROKU_PASSWORD` from `.env`.
- `scripts/logs.sh` – Connects to the Roku BrightScript debug console (port 8085). Reads `ROKU_IP` from `.env`.
- `components/MainScene.xml` – UI: home list, mode list, timer group, poster, video, timer
- `components/MainScene.brs` – USB discovery (ext1/ext2), home and mode list, media playback (photos/videos/both), media settings, round timer and timer settings, key handling

## Notes

- **USB path**: Roku exposes USB drives as `ext1:/` and `ext2:/`. The channel checks both and looks for `Photos/` and `Videos/` (capital P and V) at the root, plus `announcements.txt` at the root for the timer. Playlists use supported file extensions only.
- **Home screen**: On launch you choose "Scrolling photos & videos" or "Round timer". If you choose media and no USB or no content is found, the channel shows instructions to insert a USB with `Photos` and `Videos` folders. The round timer works without USB.
- If you choose "Photos only" or "Videos only" and that folder is empty (or missing), the channel shows a short message (e.g. "No photos found…") and returns to the mode list so you can pick another mode or go Back to home.
- Default slide duration is 10 seconds (configurable in Settings from 5–60 sec). "Both" mode shows 5 photos then one video, then repeats.
