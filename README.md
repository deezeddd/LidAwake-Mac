<div align="center">

# ☕ LidAwake

**Keep your Mac awake with the lid closed. One click from the menu bar.**

[![Platform](https://img.shields.io/badge/platform-macOS%2013%2B-blue)](#requirements)
[![Language](https://img.shields.io/badge/language-Swift-F05138?logo=swift&logoColor=white)](main.swift)
[![License: MIT](https://img.shields.io/badge/license-MIT-green)](LICENSE)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen)](#contributing)

*A native macOS menu bar utility with no Dock icon, no Electron, no background daemons,<br>and an entire codebase you can read in one sitting.*

</div>

---

## Why LidAwake?

macOS only keeps running with the lid closed when an external display is attached (clamshell mode). If you want to close the lid while a build finishes, a server runs, or music plays, your options are third-party apps or remembering `pmset` incantations. LidAwake wraps the official Apple power-management flag in a one-click menu bar toggle, and adds one thing nothing else does: it remembers your display brightness across every lid close and reopen.

## Features

- ☕ **One-click toggle**: a coffee cup in the menu bar. Outline cup means normal sleep, filled cup means the Mac keeps running with the lid closed.
- 🔆 **Brightness memory**: on lid close, your current brightness is saved and the panel is set to zero. On reopen, it is restored to the exact level you had. Works around regular display sleep too.
- 🔁 **Always truthful**: the icon reflects the real system state every time the menu opens, even if you changed the setting from the terminal.
- 🚀 **Start at Login**: one menu item, implemented with Apple's `SMAppService`.
- 🪶 **Native and tiny**: AppKit, SF Symbols, standard dialogs. Adapts to light and dark mode. A few MB of RAM.
- 📜 **Audit trail**: every lid and brightness event is logged to `~/Library/Logs/LidAwake.log`.

## Installation

### Requirements

- macOS 13 Ventura or newer (developed and tested on macOS 26)
- Xcode or the Xcode Command Line Tools (`xcode-select --install`)

### Build from source

```shell
git clone https://github.com/deezeddd/LidAwake-Mac.git
cd LidAwake-Mac
./build.sh              # compiles and installs ~/Applications/LidAwake.app
./setup-permissions.sh  # one-time rule so the toggle needs no password
open ~/Applications/LidAwake.app
```

> [!NOTE]
> `setup-permissions.sh` installs a sudoers rule scoped to exactly two commands, `pmset -a disablesleep 1` and `pmset -a disablesleep 0`, for your user only. It is validated with `visudo` before being installed. If you skip this step, the app shows a dialog with the command whenever you try to toggle.

## Usage

| Menu item | What it does |
| --- | --- |
| **Keep Awake When Lid Is Closed** | Toggles lid-awake mode. Checkmark and filled cup when active. |
| **Start at Login** | Registers or unregisters the app as a login item. |
| **Quit Lid Awake** | Quits the app. The sleep setting stays however you left it. |

> [!WARNING]
> While the toggle is ON, the Mac will not sleep for **any** reason, including on battery inside a bag. Toggle it off before you pack up. The filled cup is your reminder. A lid-closed laptop also dissipates heat worse, so AC power is best.

## How it works

| Piece | Mechanism |
| --- | --- |
| Sleep toggle | Apple's supported `pmset disablesleep` flag, flipped via `sudo -n`. No kernel extensions, no SIP changes, no hacks. |
| Lid detection | Closing the lid does not fire a display-sleep notification; macOS disconnects the built-in display entirely. LidAwake polls the `AppleClamshellState` property of `IOPMrootDomain` every 2 seconds to catch lid transitions reliably. |
| Brightness | The private `DisplayServices` framework (`DisplayServicesGetBrightness` / `SetBrightness`), the same API used by [MonitorControl](https://github.com/MonitorControl/MonitorControl). The saved level lives in `UserDefaults` with a no-overwrite guard, so a crash between close and open never loses your original brightness. |

## FAQ

**Is this dangerous?**
No. `disablesleep` is an official power-management flag and is fully reversed by toggling off (or `sudo pmset -a disablesleep 0`). The app itself runs unprivileged. The only real caution is behavioral: see the warning above about bags and batteries.

**Why does it need a sudoers rule?**
`pmset disablesleep` requires root. The rule lets exactly those two commands run without a password prompt, so the toggle is one click instead of a password dialog every time. Nothing else gains elevated rights.

**Could a macOS update break it?**
The sleep toggle uses only supported interfaces. The brightness feature relies on a private framework, so a future macOS release could break that part; the toggle would be unaffected.

**Why is there no Dock icon?**
By design. LidAwake is a background menu bar utility (`LSUIElement`), the same convention Amphetamine and MonitorControl follow: it has no windows, so the coffee cup in the menu bar is its whole interface and the Dock stays uncluttered.

**Can I still launch it from the Dock?**
Yes. Open `~/Applications` in Finder and drag `LidAwake.app` to the right side of the Dock (near the Trash). Clicking it launches the app if it is not already running. Note that as a background app it never shows the Dock's "running" indicator dot. If you prefer never thinking about launching at all, just enable **Start at Login** from the menu instead.

**Why not Amphetamine or KeepingYouAwake?**
Both are great. KeepingYouAwake (based on `caffeinate`) intentionally does not support closed-lid operation. Amphetamine does, but this project started the day the App Store refused to install it. Two hundred lines of Swift later, this exists, and it also restores your brightness.

## Uninstall

```shell
sudo pmset -a disablesleep 0
sudo rm /etc/sudoers.d/lid-awake
rm -rf ~/Applications/LidAwake.app
rm -f ~/Library/Logs/LidAwake.log
```

No other traces are left on the system.

## Contributing

Issues and pull requests are welcome. The whole app lives in [`main.swift`](main.swift); `build.sh` gives you a compile-install-run loop in a few seconds. Please keep changes native (AppKit, no dependencies) and update the README when behavior changes.

## License

LidAwake is free and open source software, released under the [MIT License](LICENSE).
Copyright (c) 2026 Vedant Maurya.
