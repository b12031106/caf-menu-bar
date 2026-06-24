# caf menu bar

A small macOS menu bar app that toggles `caffeinate -dims`.

## Features

- Runs as a menu bar app without opening Terminal.
- Launch once to enable `caffeinate -dims`.
- Launch again to toggle it off.
- Shows ON/OFF state in the menu bar.
- Provides a menu item and `Control + Option + Command + C` hotkey for toggling.
- Sends a macOS notification when the state changes.

## Download (recommended)

Grab the latest `caf-*.dmg` from the
[Releases page](https://github.com/b12031106/caf-menu-bar/releases/latest),
open it, and drag **caf.app** into **Applications**.

Because the app is not signed/notarized by Apple, the first launch needs a
one-time Gatekeeper bypass:

- **Right-click caf.app → Open**, then click **Open** again in the dialog, or
- run once in Terminal:

  ```sh
  xattr -dr com.apple.quarantine /Applications/caf.app
  ```

Afterwards just double-click to launch as usual.

## Build from source

```sh
./build.sh
```

The built app is written to:

```text
build/caf.app
```

Install the locally built app:

```sh
ditto build/caf.app ~/Applications/caf.app
```

## Releasing

Pushing a `v*` tag triggers the
[Release workflow](.github/workflows/release.yml), which builds the app on a
macOS runner, packages a `.dmg`, and publishes a GitHub Release with download
and install instructions.

```sh
git tag v2.1
git push origin v2.1
```

The version in the tag (`v2.1` → `2.1`) is stamped into `Info.plist`
automatically.
