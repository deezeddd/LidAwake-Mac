# LidAwake ☕

A tiny native macOS menu bar app that keeps your Mac running when you close the lid. One click to toggle, no Dock icon, a few MB of RAM.

Built because Amphetamine wouldn't install and the Shortcuts menu bar pin never showed up. Sometimes the best app is the 200-line one you compile yourself.

## Features

- **Menu bar toggle**: a coffee cup icon in the menu bar. Outline cup = normal sleep, filled cup = the Mac keeps running with the lid closed. The icon always reflects the real system state, even if you change it from the terminal.
- **Brightness memory**: when the lid closes, LidAwake saves your current brightness and drops it to zero. When you reopen the lid, it restores the exact level you had. Also works around regular display sleep.
- **Start at Login**: toggle it from the menu, implemented with Apple's `SMAppService`.
- **Native all the way**: AppKit, SF Symbols, standard menus and dialogs. Adapts to light and dark mode. No Electron, no background daemons, no network access.
- **Audit trail**: every lid and brightness event is logged to `~/Library/Logs/LidAwake.log`.

## Requirements

- macOS 13 Ventura or newer (built and tested on macOS 26)
- Xcode or the Xcode Command Line Tools (for `swiftc`)

## Install

```bash
git clone https://github.com/deezeddd/LidAwake-Mac.git
cd LidAwake-Mac
./build.sh              # compiles and installs ~/Applications/LidAwake.app
./setup-permissions.sh  # one-time sudo rule so the toggle needs no password
open ~/Applications/LidAwake.app
```

The setup script installs a sudoers rule scoped to exactly two commands, `pmset -a disablesleep 1` and `pmset -a disablesleep 0`, for your user only. It is validated with `visudo` before being installed. If you skip this step, the app will show a dialog with the command whenever you try to toggle.

## How it works

- **Sleep toggle**: flips Apple's supported `pmset disablesleep` power-management flag via `sudo -n`. No kernel extensions, no hacks.
- **Lid detection**: closing the lid does not fire a display-sleep notification; macOS disconnects the built-in display entirely. So LidAwake polls the `AppleClamshellState` property of `IOPMrootDomain` every 2 seconds to catch lid transitions reliably.
- **Brightness**: uses the private `DisplayServices` framework (`DisplayServicesGetBrightness` / `DisplayServicesSetBrightness`), the same API used by tools like MonitorControl. The saved level lives in `UserDefaults` with a no-overwrite guard, so a crash or restart between close and open never loses your original brightness.

## Caveats

- While the toggle is ON, the Mac will not sleep for **any** reason, including on battery inside a bag. Toggle it off before you pack up. The filled cup is your reminder.
- A lid-closed laptop dissipates heat worse. Best used on AC power.
- `DisplayServices` is a private framework, so a future macOS release could break the brightness feature (the sleep toggle would be unaffected).

## Uninstall

```bash
sudo pmset -a disablesleep 0
sudo rm /etc/sudoers.d/lid-awake
rm -rf ~/Applications/LidAwake.app
rm -f ~/Library/Logs/LidAwake.log
```

## License

[MIT](LICENSE)
