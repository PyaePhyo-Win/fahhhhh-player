# FahhPlayer

FahhPlayer is a small macOS SwiftUI menu bar app that plays a sound when your Mac switches from AC power to battery power.

## What It Does

- Monitors macOS power source changes.
- Runs from the macOS menu bar instead of opening a main window.
- Plays a bundled default sound when power changes from AC to battery.
- Lets you choose your own custom sound file.
- Imports the selected custom file into the app's local storage so playback does not depend on the original file location.
- Lets you test playback and reset back to the bundled fallback.
- Can be configured to launch automatically at login.

## Requirements

- macOS
- Xcode

## Run The Project

### In Xcode

1. Open `FahhPlayer.xcodeproj`.
2. Select the `FahhPlayer` scheme.
3. Press Run.

After launch, the app appears as a menu bar item and stays hidden from the Dock.

### From Terminal

```bash
cd '/Users/pyaephyowin/Documents/Portfolio Projects/FahhPlayer'
open FahhPlayer.xcodeproj
```

You can also build from Terminal:

```bash
cd '/Users/pyaephyowin/Documents/Portfolio Projects/FahhPlayer'
xcodebuild -project FahhPlayer.xcodeproj -scheme FahhPlayer -configuration Debug build
```

## Export A .app

Use the reusable export script from the project root:

```bash
cd '/Users/pyaephyowin/Documents/Portfolio Projects/FahhPlayer'
./export_app.sh
```

By default, it builds a Release version and exports:

- `FahhPlayer.app`
- `FahhPlayer-<version>.zip`

If the project has no app version set, the zip falls back to a date-based name such as `FahhPlayer-20260429.zip`.

You can also choose another output folder:

```bash
./export_app.sh --output-dir "$HOME/Desktop"
```

## Using Custom Sounds

1. Launch the app.
2. Click the FahhPlayer menu bar icon.
3. Click `Choose Sound`.
4. Pick an MP3, WAV, or another supported audio file.
5. Click `Test Playback` to verify it works.

When you choose a custom file, FahhPlayer copies it into the app's Application Support directory and uses that local copy for playback.

## Default Bundled Sound

The app includes a bundled fallback sound in the app target resources. If you want to replace it, update the bundled audio file in the project and keep the resource name aligned with the lookup in `PowerObserver.swift`.

## Project Structure

```text
FahhPlayer/
  FahhPlayer/
    ContentView.swift
    FahhPlayerApp.swift
    PowerObserver.swift
    Assets.xcassets/
    fahhhhh.mp3
  FahhPlayer.xcodeproj/
  README.md
```

## Notes

- Power-triggered playback is currently tied to AC to battery transitions.
- The app includes sandbox permissions for user-selected read-only files.
- A custom sound can be cleared with `Reset to Default`.
- `Launch at Login` is controlled from the menu bar popover and may require approval in System Settings > General > Login Items.