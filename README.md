
<p><img src="assets/app-icon.png" width="128" height="128" alt="Peek app icon"></p>

<h1>Peek</h1>

<p>A digital privacy screen for macOS that blurs everything except a clear circle around your cursor.<br>
For working in public without turning your screen into a billboard.</p>

<p><strong>Version 1.2</strong> · macOS 13 (Ventura) or later · Apple Silicon & Intel</p>

<p>
  <img src="https://img.shields.io/badge/Swift-f05138" alt="Swift">
  <img src="https://img.shields.io/badge/AppKit-0066cc" alt="AppKit">
  <img src="https://img.shields.io/badge/macOS-000000" alt="macOS">
</p>

<p><a href="https://apps.apple.com/us/app/peek-screen-privacy/id6800797352?mt=12">Download Peek on the Mac App Store</a></p>

![Peek demo](assets/peek-preview.gif)

Peek is a menu bar app that blurs your whole screen except for a clear circle around your cursor. For coffee shops, trains, anywhere with someone next to you.

## How it works

Three overlay styles: Light Blur, Dark Blur, and Blackout. The clear circle is 100–1200px and follows your cursor with no lag. Clicks pass through to whatever's underneath.

## Usage

1. Open Peek. An eye icon appears in the menu bar.
2. Click the menu bar icon and choose **Turn Peek On** or **Turn Peek Off**
3. Use the same menu to open Settings, view About, or quit Peek
4. Move your mouse to reveal content through the peek circle

### Keyboard shortcuts

| Shortcut | Action |
|----------|--------|
| `⌥⌘P` (default) | Toggle privacy overlay |
| `Cmd + ,` | Open Settings |
| `Cmd + Q` | Quit Peek |

Change the toggle shortcut in **Settings**: click the shortcut field and press your preferred key combination.

## Installation

[**Download Peek from the Mac App Store**](https://apps.apple.com/us/app/peek-screen-privacy/id6800797352?mt=12).

Peek does not need Accessibility, Input Monitoring, or Screen Recording permission.

## Building from source

Requires Swift 5.9+ and macOS 13+.

```sh
# Build, sign, notarize, and package the direct-download app
./build-app.sh
```

The Xcode project is generated from `project.yml` with XcodeGen. The direct-download script compiles a release binary, creates `Peek.app`, and packages it into `Peek.dmg`.

## Known limitations

- **Designed for nearby privacy.** Peek reduces casual over-the-shoulder viewing. Screenshot, recording, screen-sharing, AirPlay, and Sidecar behavior can vary by macOS version and capture method, so do not rely on Peek as the only control for sensitive information.

## Built with

Swift + AppKit, zero external dependencies.

## Feedback

Need help, found a bug, or have a feature idea? See [Peek Support](SUPPORT.md).

## License

[MIT](LICENSE)

## Privacy

Peek does not collect or transmit data. See the [Privacy Policy](PRIVACY.md).

---

Made by [santiagoalonso.com](https://santiagoalonso.com)
