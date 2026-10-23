<p align="center">
  <img src="Resources/AppIcon.png" width="128" alt="Projector Hold icon">
</p>

<h1 align="center">Projector Hold</h1>

<p align="center">
  Freeze or blank the picture on your TV or projector while you keep working on your Mac.<br>
  Works with AirPlay, including plain screen mirroring.
</p>

<p align="center">
  <a href="../../releases/latest"><b>Download for macOS</b></a> ·
  <a href="https://melvinardra.com">melvinardra.com</a>
</p>

---

Classroom and meeting-room projectors have a **Freeze** button and a **Blank** button. AirPlay doesn't. Projector Hold adds them to your Mac.

| Shortcut | What it does |
|---|---|
| **⌃⌥⌘F** | Freeze the TV on the current picture. Press again to go live. |
| **⌃⌥⌘B** | Blank the TV (black screen). Press again to show it. |

While the TV is frozen or blank, your Mac's own screen stays live, so you can find the next slide, answer a message or set up a demo without the room seeing it.

## How it works

- **Separate display:** If the TV is a separate display, Projector Hold covers it with the frozen picture or a black screen.
- **Mirroring:** If you're mirroring, Projector Hold captures what's on the TV, briefly turns mirroring off so your Mac is free, and turns mirroring back on when you release. Both screens may flicker for about a second when it switches.

It runs in the menu bar and has no Dock icon.

## Install

1. Download the latest `ProjectorHold.dmg` from [Releases](../../releases/latest).
2. Open it and drag **Projector Hold** to **Applications**.
3. Open Projector Hold. A screen icon appears in the menu bar.
4. The first time you freeze, macOS asks for **Screen & System Audio Recording** permission. Turn on Projector Hold in System Settings, then choose **Restart Projector Hold** from its menu.

Blank works without any permission. Freeze needs Screen Recording to take its snapshot. Projector Hold doesn't record audio.

Requires macOS 14 Sonoma or later.

## Privacy

Projector Hold has no network access, analytics or accounts. The frozen picture is kept in memory only while the TV is frozen and is never saved or sent anywhere.

## Support the project

Projector Hold is free and open source. If it saves your presentations, you can pay what you want for it at [melvinardra.com](https://melvinardra.com). It helps keep the app updated.

## Build from source

You need macOS 14+ and the Xcode Command Line Tools (`xcode-select --install`).

```bash
git clone <this repo's URL>
cd ProjectorHold
./build_app.sh
open ProjectorHold.app
```

- `scripts/make_icon.sh` regenerates the app icon.
- `release.sh` builds a signed, notarized `.dmg` for distribution and needs an Apple Developer ID. See the comments at the top of the script.

## Contributing

Bug reports, ideas and pull requests are welcome. Please open an issue first for larger changes.

## License

[MIT](LICENSE)
