# hyprwm — Horizon

Hyprland + Quickshell session built from the dusk horizon wallpaper.
Runs next to the Sway setup in `~/swaywm`: same palette (`~/swaywm/colors.md`,
plus `sky #06587a` for gradients), same keybindings, separate daemons.
Pick **Hyprland** or **Sway** on the login screen.

![Empty workspace: the dusk wallpaper, a notification top right, and the launcher rising out of the bar island](docs/screenshot.png)

Colour appears only where your attention is: the focused window's border
fades from accent to the photo's deep blue, a thin "horizon line" marks the
active workspace, the selected row in a menu and a notification's remaining
time, and amber means a mode is on (REC, AWAKE, DND, PERF). Everything else
stays grey, including app icons until you select them.

![Two tiled windows: nvim with the look config, kitty with the repo tree](docs/screenshot-work.png)

## What's in it

**Bar (glow island).** One island per screen, centred at the bottom.
- Left: that screen's workspaces, with a dot per window and the horizon line
  under the active one. A soft glow on the island's top edge drifts after it.
  Next to them, whatever is playing, or else the focused window as
  `App  title`, capped so it never reaches the clock.
- Centre: date and time. Click for a month calendar.
- Right: modes only while they're on (REC, AWAKE, DND, PERF in amber, SAVER
  in grey), volume and battery meters, and a `···` tray drawer. Scroll the
  volume to change it, click it to mute. The battery reads BAT, CHR or AC.
- Click the battery for the **power panel**: power profile (saver, balanced,
  performance, via tuned-ppd), a keep-awake switch, and time left and power draw.

**Launcher** (`Super+D`). Apps, a calculator (`=` or `Super+C`, qalc), emoji
(`:` or `Super+.`, types into the focused window), and clipboard history
(`Super+V`, cliphist; `Shift+Delete` removes an entry). Pressing the same key
again closes it. Also a menu mode for scripts: `scripts/qs-dmenu`, a
`rofi -dmenu` stand-in, used by the appearance menu.

**Notifications.** Quickshell is the notification server in this session.
Popups top right, newest first, with a shrinking horizon line for time left
(hover pauses it); critical ones stay and turn red. Same-tag notifications
(brightness, recording, night light) replace each other. History, clear all
and do-not-disturb are on keys.

**Also:** volume and brightness OSD above the bar, power menu that asks before
logging out, rebooting or shutting down, tray menus for nm-applet and
blueman drawn in the same style (not Qt's default), a lock screen with the
clock in the sky above the mountain (hyprlock), and Papirus-Dark icons for
Quickshell only.

## Motion

Everything that moves runs on near-critically damped springs (ζ ≈ 0.9):
light glides and settles, it doesn't bounce. Hyprland's curves
(`modules/look.lua`) and Quickshell's (`Theme.springs`, integrated per frame
by `Spring.qml`) use the same stiffness, damping and mass, so windows and
panels move alike.

The values were tuned from frame-by-frame screen recordings (wf-recorder at
60 Hz, every frame measured):
- Workspaces drift 20% and cross-fade instead of sliding the full width;
  a 1920 px slide in ~0.3 s jumps 200–400 px per frame and reads as a jerk.
- New windows fade in fast, so the bright horizon band doesn't flash through.
- Panels stay mapped (invisible and click-through while closed), are drawn
  once at startup, and fade in ahead of their rise, so they open on the next
  frame without a hitch.
- Keys reach Quickshell through Hyprland's global shortcuts
  (`Shortcuts.qml`), not by starting `qs ipc` per key press.

## Keys

| Keys | |
| :--- | :--- |
| `Super+Return` · `Super+Shift+Return` | kitty · drop-down kitty |
| `Super+D` · `Super+C` · `Super+.` · `Super+V` | launcher: apps · calculator · emoji · clipboard |
| `Super+X` · `Super+Shift+E` | power menu · log out |
| `Super+Shift+Escape` | lock |
| `Super+Q` | close window |
| `Super+H/J/K/L` (or arrows) | focus; `+Shift` move, `+Ctrl` resize |
| `Super+1…0` · `Super+Shift+1…0` | go to workspace · send window there (stay) |
| `Super+Tab` · `Super+Shift+Tab` | other monitor · send workspace there |
| `Super+F` · `Super+Shift+Space` · `Super+Space` | fullscreen · float · focus tiled/floating |
| `Super+W` · `Super+S` | window group (tabs) · next tab |
| `Super+B` · `Super+Shift+V` · `Super+E` | next window opens right · below · toggle split |
| `Super+-` · `Super+Shift+-` | scratchpad show · send |
| `Super+\`` · `Super+Shift+\`` · `Super+Shift+N` | last notification · clear all · do not disturb |
| `Super+N` · `Super+Shift+A` | night light · appearance (GTK theme, icons, cursor, font) |
| `Super+[` · `Super+]` | brightness (laptop panel or DDC monitor, whichever is focused) |
| `Print` · `Alt+Print` · `Ctrl+Print` · `Shift+Print` | screenshot screen · window · area · record area |
| click the clock · click the battery | calendar · power panel |

Monitors: workspaces 1–5 live on the external Samsung, 6–10 on the laptop,
and move back when a screen returns. Closing the lid turns the laptop panel
off only while another screen is connected.

## Packages (stow, target `~`)

| Package      | Installs to             | What |
| :----------- | :---------------------- | :--- |
| `hypr`       | `~/.config/hypr`        | `hyprland.lua` (Lua config, Hyprland 0.57+) split into `modules/`, hypridle, hyprlock, scripts, wallpaper |
| `quickshell` | `~/.config/quickshell`  | wallpaper, bar, notifications, OSD, launcher, power menu, power panel, calendar, tray menus |
| `systemd`    | `~/.config/systemd/user` | `hyprland-session.target` (needed for xdg-desktop-portal) and a drop-in keeping kanshi out of Hyprland |
| `kitty`      | `~/.config/kitty`       | terminal, same font and colours as foot |

```sh
cd ~/hyprwm && stow hypr kitty quickshell systemd
```

## System packages

Hyprland is no longer in Fedora's repos; it comes from the `sdegler/hyprland`
COPR, limited to the Hyprland stack so it can't replace Fedora's waybar or kitty:

```sh
sudo dnf copr enable sdegler/hyprland
sudo dnf config-manager setopt "copr:copr.fedorainfracloud.org:sdegler:hyprland.includepkgs=hypr*,aquamarine*,xdg-desktop-portal-hyprland*,glaze*"
sudo dnf install hyprland hyprlock hypridle hyprpicker hyprpolkitagent hyprsunset \
  xdg-desktop-portal-hyprland quickshell kitty qt6-qt5compat qt6-qtmultimedia \
  papirus-icon-theme-dark
```

Shared with the Sway setup (already installed there): grim, slurp, wl-clipboard,
cliphist, brightnessctl, ddcutil, playerctl, wf-recorder, jq, libnotify,
network-manager-applet, blueman, qalculate (qalc), wtype, tuned-ppd.

`quickshell/.config/quickshell/data/emoji.tsv` was generated once from
rofimoji's emoji CSVs (Unicode CLDR names), so the launcher doesn't need rofimoji.

## Checking changes

```sh
Hyprland --verify-config                 # Lua config errors, without reloading
hyprctl configerrors                     # inside a running session
qs ipc call shell reload                 # reload Quickshell (edits to stowed files aren't always noticed)
qs ipc show                              # IPC targets for scripts (launcher, power, notifications, osd, shell)
hyprctl globalshortcuts                  # the quickshell:* shortcuts the keys use
```

If the launcher, power menu or notification keys stop responding, Quickshell
isn't running: `hyprctl dispatch 'hl.dsp.exec_cmd("qs")'`.

## Not shared with Sway

kanshi (Hyprland handles monitors itself: `modules/monitors.lua`), waybar,
dunst, rofi, swayidle/swaylock, foot. Keep-awake state is separate too
(`$XDG_RUNTIME_DIR/hypr-keep-awake`). Shared: gsettings (appearance), the
power profile (tuned-ppd), and the clipboard history.
