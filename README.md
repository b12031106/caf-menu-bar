# caf menu bar

A small macOS menu bar app that toggles `caffeinate -dims`.

## Features

- Runs as a menu bar app without opening Terminal.
- Launch once to enable `caffeinate -dims`.
- Launch again to toggle it off.
- Shows ON/OFF state in the menu bar.
- Provides a menu item and `Control + Option + Command + C` hotkey for toggling.
- Sends a macOS notification when the state changes.

## Build

```sh
./build.sh
```

The built app is written to:

```text
build/caf.app
```

## Install

```sh
ditto build/caf.app ~/Applications/caf.app
```
