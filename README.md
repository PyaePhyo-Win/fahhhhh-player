# FahhPlayer

FahhPlayer is a small macOS SwiftUI menu bar app that plays sounds when your Mac switches from AC power to battery power and when zsh cannot find a typed terminal command.

## What It Does

- Monitors macOS power source changes.
- Runs from the macOS menu bar instead of opening a main window.
- Plays a bundled default sound when power changes from AC to battery.
- Plays a sound when zsh cannot find a typed terminal command.
- Lets you choose separate custom sound files for power events and terminal command errors.
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
3. Use `Choose` in either `Power Supply Sound` or `Terminal Command Error Sound`.
4. Pick an MP3, WAV, or another supported audio file.
5. Click `Test` in that same section to verify it works.

When you choose a custom file, FahhPlayer copies it into the app's Application Support directory and uses that local copy for playback. Power and terminal sounds are stored separately, so resetting one does not reset the other.

## Terminal Command Errors

FahhPlayer plays the terminal error sound for zsh `command not found` events. A sandboxed macOS app cannot globally inspect everything typed in Terminal, so terminal support uses a small shell hook that opens FahhPlayer through its custom URL scheme.

Add this to your `~/.zshrc`:

```zsh
command_not_found_handler() {
  open -g "fahhplayer://command-not-found"
  print -u2 "zsh: command not found: $1"
  return 127
}
```

Then reload your shell:

```zsh
source ~/.zshrc
```

Test it with a command that does not exist:

```zsh
definitely_missing_fahh_command
```

If you already have a `command_not_found_handler`, merge the `open -g "fahhplayer://command-not-found"` line into your existing handler instead of replacing it.

You can also test the app trigger directly:

```zsh
open -g "fahhplayer://command-not-found"
```

## Default Bundled Sound

The app includes a bundled fallback sound in the app target resources. If you want to replace it, update the bundled audio file in the project and keep the resource name aligned with the lookup in `PowerObserver.swift`.

## Project Structure

```text
FahhPlayer/
  FahhPlayer-Info.plist
  FahhPlayer/
    ContentView.swift
    FahhPlayerApp.swift
    PowerObserver.swift
    Assets.xcassets/
    fahhhhh.mp3
  FahhPlayer.xcodeproj/
  export_app.sh
  README.md
```

## Notes

- Power-triggered playback is currently tied to AC to battery transitions.
- Terminal-triggered playback is currently tied to zsh `command not found` events after installing the shell hook.
- The app includes sandbox permissions for user-selected read-only files.
- Each custom sound can be cleared with `Reset` in its own section.
- `Launch at Login` is controlled from the menu bar popover and may require approval in System Settings > General > Login Items.
