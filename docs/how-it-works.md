# How Peek works

Back to the [README](../README.md).

## Using it

1. Open Peek. An eye icon appears in the menu bar.
2. Click the icon and choose **Turn Peek On** or **Turn Peek Off**.
3. The same menu opens Settings, About Peek and the privacy policy, and quits the app.
4. Move the mouse to read through the clear circle; everything else stays covered.

## Keyboard shortcuts

| Shortcut | Action |
| --- | --- |
| `⌥⌘P` (default) | Turn the overlay on or off |
| `⌘,` | Open Settings |
| `⌘Q` | Quit Peek |

To change the toggle shortcut, open Settings, click the shortcut field and press the new key combination.

## Overlay

Three styles: Light Blur, Dark Blur and Blackout. The Intensity slider in Settings sets how strong the style is, from 5% (barely there) to 100% (full blur, or solid black for Blackout). The clear circle is 100 to 1200 px wide and follows the cursor. Settings shows a live preview of the overlay; hover it to move the circle. Edge Softness sets how gradually the circle fades into the overlay, from a sharp edge to a 200 px fade. **Save as Default** keeps the current style, intensity, softness and size; **Restore Default** brings them back after you experiment. Clicks pass through the overlay to the app underneath.

## Built with

Swift and AppKit with no external dependencies (system frameworks only: Cocoa, Carbon for the global shortcut, QuartzCore and ServiceManagement for launch at login). The Xcode project is generated from `project.yml` with XcodeGen; `./build-app.sh` compiles a release build, creates `Peek.app` and packages `Peek.dmg`.
