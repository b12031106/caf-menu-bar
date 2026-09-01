# caf menu bar

A small macOS menu bar app that prevents sleep with `caffeinate`.

## Features

- Runs as a menu bar app without opening Terminal.
- Starts automatically at login by default, with a menu option to turn it off.
- Launch once to enable `caffeinate -dims`.
- Launch again to toggle it off.
- Shows ON/OFF state in the menu bar.
- Provides a menu item and `Control + Option + Command + C` hotkey for toggling.
- Choose whether to keep the display awake (`-dims`, default) or allow display
  sleep while preventing system sleep (`-ims`). The choice is remembered.
- Sends a macOS notification when the state changes.

## Install via Homebrew (recommended)

```sh
brew install --cask b12031106/tap/caf
```

The cask strips the quarantine attribute on install, so the app launches
without a Gatekeeper prompt. Update with:

```sh
brew upgrade --cask caf
```

## Download manually

Grab the latest `caf-*.dmg` from the
[Releases page](https://github.com/b12031106/caf-menu-bar/releases/latest),
open it, and drag **caf.app** into **Applications**.

Because the app is not signed/notarized by Apple, a manual download needs a
one-time Gatekeeper bypass on first launch:

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
