# Roughstock TV

Roku channel for displaying photos and videos from a USB thumb drive (e.g. gym info, ads, pricing on a TV). Supports **Photos only**, **Videos only**, or **Both** modes.

## USB layout

At the **root** of the USB drive create two folders with exactly these names (capital P and V):

```
USB root/
├── Photos/   ← .jpg, .png, .gif
└── Videos/   ← .mp4, .mkv, .mov
```

Use FAT32 or NTFS. Plug the USB into the Roku TV’s USB port.  
If you copy files from a Mac, it may create hidden `._` files (e.g. `._image.png`); the app skips these and only shows real images.

## Viewing logs (debugging)

When the channel shows a blank screen or misbehaves, use the **BrightScript debug console** to see `print` output and errors:

1. **Enable developer mode on the Roku**
   - Settings → System → Developer options (or enter your Roku’s IP in a browser and use “Developer Application Installer”).
   - Turn on “Developer Application Installer” and note your Roku’s IP (e.g. Settings → Network → About).

2. **Connect to the debug console**
   - **Mac (no telnet):** use netcat (built in):  
     `nc <ROKU_IP> 8085`  
     Example: `nc 192.168.1.100 8085`  
     Logs appear in the terminal. Press **Ctrl+C** to disconnect.
   - **Mac or Linux (with telnet):** `telnet <ROKU_IP> 8085`
   - **Windows:** enable “Telnet Client” in Settings, or use PuTTY (Telnet, port 8085).

3. **Reproduce the issue**
   - Launch Roughstock TV again. You should see lines like:
     - `[Roughstock] Main() start`
     - `[Roughstock] Creating MainScene`
     - `[Roughstock] MainScene init() start`
     - `[Roughstock] listDirectory ...` or `listDirectory failed: ext1:/photos/`
     - `[Roughstock] USB discovery done. photos=0 videos=0`
     - etc.
   - Any runtime error or crash will appear here too.

If you don’t see any output, the channel may not be loading (check that you installed the latest zip and launched “Roughstock TV”). If connection to 8085 is refused, ensure developer mode is on and try rebooting the Roku.

## Run the channel

1. Install [Roku Developer SDK](https://developer.roku.com/docs/developer-program/getting-started/roku-dev-prog.md) and enable Developer Application Installer on your Roku device.
2. Zip the channel (manifest, source/, components/, images/ at the root of the zip).
3. Sideload via the Roku developer dashboard or `curl` to your device’s plugin_install endpoint.

Example zip from project root:

```bash
zip -r roughstock-tv.zip manifest source components images
```

Then install the zip as a developer channel on your Roku TV.

## Project layout

- `manifest` – Channel metadata and version
- `images/roughstock-orig.jpg` – Main screen background logo (watermark). Roku doesn’t support SVG; to use `roughstock.svg` instead, export it to PNG (e.g. 1280×720), save as `images/roughstock-bg.png`, and in `MainScene.xml` set `mainBgLogo`’s `uri` to `pkg:/images/roughstock-bg.png`.
- `source/main.brs` – Entry point, creates SceneGraph screen and MainScene
- `components/MainScene.xml` – UI: mode list, message label, poster, video, timer
- `components/MainScene.brs` – USB discovery (`ext1:/`, `ext2:/`), mode handling, slideshow, video playlist, “both” mode

## Notes

- **USB path**: Roku exposes the first USB drive as `ext1:/`. The channel looks for `Photos/` and `Videos/` (capital P and V) at the root and builds playlists from supported file extensions.
- If no USB or no content is found, the channel shows instructions to insert a USB with `Photos` and `Videos` folders.
- Slide duration is 10 seconds; “Both” mode shows 5 photos then one video, then repeats.
