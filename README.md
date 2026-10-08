# i3 on NVIDIA DGX Spark (DGX OS, X11)

Turns a DGX Spark running **DGX OS** (Ubuntu 24.04 "Noble" base, `arm64`) into a
working **i3 tiling desktop**.

The i3 config is a **near-verbatim copy of the upstream i3 default config**
(`i3 4.23`), with only the modifications you asked for layered on top — nothing
clever, nothing to fight.

> **Target:** DGX OS 7 · Ubuntu 24.04 · `aarch64` · **X11** (not Wayland).
> i3 is an X11 window manager; it will not run *inside* a Wayland session.

---

## 1. Your keyboard preferences (what this does)

Implemented with **XKB**, so they apply to every application in the session, not
just i3:

| You press (physical key) | The system delivers | XKB option applied |
|---|---|---|
| **Caps Lock** | **Escape** | `caps:swapescape` |
| **Escape** | **Caps Lock** | `caps:swapescape` |
| **Alt** | **Super** (Mod4) → i3's `$mod` | `altwin:swap_alt_win` |
| **Win** | **Alt** (Mod1) | `altwin:swap_alt_win` |

Net effect:

* **Esc and Caps Lock are swapped.**
* **Alt acts as the Super key** — and since the config sets `set $mod Mod4`,
  **Alt is your i3 modifier** (every stock `Mod1+<key>` binding is now `$mod+<key>`,
  i.e. Alt-based).
* **Win acts as Alt** (Mod1).

Applied three ways for robustness:

1. `exec setxkbmap -option "caps:swapescape,altwin:swap_alt_win"` near the top of
   `~/.config/i3/config` (always active in the i3 session),
2. `~/.xinitrc` does the same for `startx` sessions, and
3. `/etc/X11/xorg.conf.d/00-keyboard.conf` (written by the installer by default)
   applies the same options to every keyboard the X server sees — including a
   USB keyboard re-detected after suspend/resume, which is what otherwise
   resets the swap.

---

## 2. Exactly what was changed vs. the vanilla config

Everything below is the *complete* delta from upstream's default config. Nothing
else was touched:

* **Added** (top of file):
  * `exec --no-startup-id setxkbmap -option "caps:swapescape,altwin:swap_alt_win"`
  * `set $mod Mod4`
* **Changed** every `Mod1+…` keybinding to `$mod+…` (focus, move, layout,
  workspaces, reload/restart/exit, resize mode). `floating_modifier Mod1` is
  deliberately left as `Mod1` so **physical Win** still drags floating windows.
* **Terminal:** `$mod+Return` runs xterm; its font (Iosevka Term) and clipboard
  bindings come from `~/.Xresources` (loaded with `xrdb`):
  ```i3config
  set $term xterm
  bindsym $mod+Return exec $term
  ```
* **Navigation:** vim-style — `h`=left, `j`=down, `k`=up, `l`=right:
  ```i3config
  set $up k
  set $down j
  set $left h
  set $right l
  ```
  The old `split h` binding moved to `$mod+semicolon`:
  ```i3config
  bindsym $mod+semicolon split h
  ```
* **X resources:** the config loads `~/.Xresources` at startup (xterm font +
  clipboard):
  ```i3config
  exec --no-startup-id xrdb -merge ~/.Xresources
  ```
* **Browser:** `$mod+b` runs Firefox:
  ```i3config
  set $browser firefox
  bindsym $mod+b exec --no-startup-id $browser
  ```
* **Status bar:** left `dock` (always visible — no auto-hide) and anchored to the
  **bottom**:
  ```i3config
  bar {
          status_command i3status
          position bottom
  }
  ```
* **Removed** the trailing `exec i3-config-wizard` line (per its own comment,
  since we ship a config).
* **No compositor at all** — so there is no window fading. (The upstream default
  has no compositor either.)

You can see this for yourself:

```bash
diff <(curl -sL https://raw.githubusercontent.com/i3/i3/4.23/etc/config | grep -v '^#') \
     <(grep -v '^#' config)
```

---

## 3. Quick start

```bash
chmod +x install-i3.sh
./install-i3.sh
```

Then **log out and pick the `i3` session** at the login screen.

| Flag | Effect |
|---|---|
| `--persistent-keys` | Write `/etc/X11/xorg.conf.d/00-keyboard.conf` (now the default) so the remap applies at the greeter and survives suspend/resume. |
| `--no-install` | Skip `apt`; only (re)write the config files. |
| `--emit-config DIR` | Dump the canonical config files into `DIR` (handy for inspection). |

---

## 4. What's in this bundle

```
install-i3.sh        The installer (self-contained; embeds the configs)
README.md            This document
config               i3 config            -> ~/.config/i3/config
i3status.conf        status-bar config    -> ~/.config/i3status/config
xinitrc              startx session       -> ~/.xinitrc
Xresources           xterm font/clipboard -> ~/.Xresources
```

`config`, `i3status.conf`, `xinitrc` and `Xresources` are the exact files the
installer writes (regenerate with `./install-i3.sh --emit-config .`), so copies
never drift.

---

## 5. What gets installed

* **Window manager:** `i3-wm`, `i3status`, `i3lock`
* **Session / XDG:** `dex` (used by the stock config's autostart line), `xinit`,
  `x11-xserver-utils`, `x11-xkb-utils`, `xdg-utils`, `dbus-x11`
* **Launcher / terminals:** `suckless-tools` (`dmenu`), `rofi`, `xterm`,
  `rxvt-unicode`
* **Status-bar / tray plumbing:** `network-manager-gnome` (`nm-applet`),
  `blueman`, `pasystray`, `pulseaudio-utils` (`pactl`), `pavucontrol`, `playerctl`
* **Niceties:** `dunst`, `libnotify-bin`, `brightnessctl`, `xss-lock`, `lxpolkit`,
  `gnome-keyring`, `maim`, `xclip`
* **Fonts / theming:** `fonts-dejavu`, `fonts-font-awesome`, `lxappearance`
* **Iosevka font:** downloaded from the upstream GitHub release into
  `~/.local/share/fonts/iosevka` (skip with `--no-font`; override the version
  with `IOSEVKA_VERSION=…` or the cut with `IOSEVKA_ASSET=PkgTTC-SGr-Iosevka`).
* **Browser:** `firefox` (best effort — see [§7](#7-firefox-and-dgx-os-snap-caveat))

> All available for `arm64` from the stock Ubuntu 24.04 archives; no third-party
> repos required. There is **no compositor package** (no picom) by design.

---

## 6. Day-to-day usage

| Keys | Action |
|---|---|
| **Alt + Return** | Terminal (`xterm`) |
| **Alt + b** | Browser (`firefox`) |
| **Alt + d** | Launcher (`dmenu`) |
| **Alt + ; / v** | Split horizontal / vertical |
| **Alt + s / w / e** | Stacking / tabbed / toggle-split layout |
| **Alt + f** | Fullscreen |
| **Alt + Shift + space** | Toggle floating |
| **Alt + a** | Focus parent container |
| **Alt + arrows** (or `h j k l`) | Focus window |
| **Alt + Shift + arrows** (or `h j k l`) | Move window |
| **Alt + 1…0** | Switch workspace |
| **Alt + Shift + 1…0** | Move container to workspace |
| **Alt + r** | Resize mode (arrows, then `Return`/`Esc`) |
| **Alt + Shift + c / r / e** | Reload / restart / exit i3 |
| **Alt + Shift + q** | Close window |

This is the standard i3 keymap; the only difference is that **Alt is your `$mod`**.

### 6.1 Why xterm (and not Alacritty/kitty)

You asked for a terminal that "plays nice with Neovim" and avoids **kitty
keyboard protocol** issues (CSI-u / progressive keyboard enhancement). That
protocol is implemented by kitty, foot, WezTerm, Ghostty and **Alacritty 0.13+**,
and it is a common cause of broken key handling in Neovim/tmux.

The default is therefore **`xterm`**, which doesn't implement the protocol at
all; **`rxvt-unicode` (`urxvt`)** is installed as an equally-safe alternative.
Swap the one line if you prefer:

```i3config
set $term urxvt -fn "xft:Iosevka Term:pixelsize=14"
```

(Other protocol-free choices: `st`, `xfce4-terminal`, `gnome-terminal`.)

---

## 7. Firefox and DGX OS (snap caveat)

The **Alt + b** binding runs `firefox`. The installer tries
`apt-get install firefox`, but on Ubuntu 24.04 that package is a **transitional
package that installs the Firefox snap**, and DGX OS images may not ship `snapd`.
This step is deliberately **best-effort** and never aborts the rest of the
install.

If it didn't install, use whatever fits the box (`snap install firefox`, the
Mozilla `apt` repo, or a Flatpak), or point the binding elsewhere by editing
`set $browser …`. Verify with `command -v firefox`.

---

## 8. Remap at the greeter and across suspend/resume

The i3-session remap doesn't cover the **greeter** (login screen), which is a
separate X session — and a plain `setxkbmap` is lost when a USB keyboard is
re-detected after suspend/resume. The installer therefore writes
`/etc/X11/xorg.conf.d/00-keyboard.conf` **by default**; the X server applies
it to every keyboard device, including on wake:

```ini
Section "InputClass"
    Identifier   "system-keyboard"
    MatchIsKeyboard "on"
    Option "XkbLayout"  "us"                                      # change if needed
    Option "XkbOptions" "caps:swapescape,altwin:swap_alt_win"
EndSection
```

Reboot (or restart the display manager) to apply. Override the layout with
`XKB_LAYOUT=de ./install-i3.sh --persistent-keys`.

The file is written **mode 0644**: Xorg runs *rootless* (as your user) on modern
GDM, and a `0600` root-owned file is silently ignored by the X server — which is
exactly why the swap used to reset after suspend/resume. The installer also
mirrors the options into GNOME's `dconf` (`org.gnome.desktop.input-sources
xkb-options`) so any GNOME component that re-applies the layout keeps the swaps.

---

## 9. Verifying the keyboard mapping

Inside the i3 session:

```bash
setxkbmap -print | tr ',' '\n' | grep -E 'swapescape|swap_alt_win'
xev     # press Caps Lock, Esc, Alt, Win
```

In `xev`: **Caps Lock** → `Escape`; **Escape** → `Caps_Lock`; **Alt** → `Super_L`
(Mod4); **Win** → `Alt_L` (Mod1).

---

## 10. Customizing

* **Terminal / launcher / browser:** edit `set $term`, `set $menu`, `set $browser`
  in `~/.config/i3/config`.
* **Terminal font / clipboard:** `~/.Xresources` (then `xrdb -merge ~/.Xresources`,
  or just reload i3). The font family is `XTerm*faceName`; copy/paste is
  `XTerm*selectToClipboard` + the `XTerm*VT100.Translations` block.
* **Bar:** `bar { … }` — it's `position bottom` and uses the default `dock` mode
  (always visible). Change `position` to `top`, or set `mode hide` if you ever
  want it to auto-hide.
* **Status fields:** `~/.config/i3status/config`.
* **Wallpaper / compositor:** intentionally not included (vanilla). Add your own
  `exec` line if you want `feh`/`picom` later.

Reload after editing with **Alt + Shift + c**.

---

## 11. Choosing the i3 session at login

`i3-wm` ships `/usr/share/xsessions/i3.desktop`, so GDM will offer it:

1. Log out.
2. On the GDM login screen, click the **gear/cog** icon.
3. Select **i3**, then log in.

For a headless/TTY start: `startx` (uses `~/.xinitrc`). The script does **not**
change your default session.

---

## 12. Troubleshooting

**Still GNOME after login.** You didn't pick the i3 session — see §11.

**Keys aren't swapped inside i3.** Check `echo $XDG_SESSION_TYPE` is `x11`, then
run `setxkbmap -option "caps:swapescape,altwin:swap_alt_win"` manually.

**Greeter keys aren't swapped, or the remap resets after sleep.** The system-wide keymap file is missing — re-run `./install-i3.sh --no-install` (§8).

**Alt (= `$mod`) does nothing.** Confirm `~/.config/i3/config` starts with the
`setxkbmap` exec line and `set $mod Mod4`; reload with **Alt + Shift + c**.

**Alt + b does nothing.** `command -v firefox` — if missing see §7.

**Neovim key handling looks wrong.** Use `xterm`/`rxvt-unicode`, not
Alacritty/kitty/WezTerm/foot (§6.1).

**Can't copy/paste in the terminal.** `~/.Xresources` must be loaded — reload i3
(**Alt + Shift + c**) or run `xrdb -merge ~/.Xresources`. Then: select with the
mouse (goes to CLIPBOARD), `Ctrl+Shift+C` to copy, `Ctrl+Shift+V` to paste
(middle-click and `Shift+Insert` also paste).

**Terminal font is not Iosevka.** Confirm it is installed with `fc-list | grep -i
Iosevka`; if not, re-run `./install-i3.sh` (or `--no-install` to only fetch the
font). Check the family name in `~/.Xresources` matches (`Iosevka Term`).

**Tray applet (network/audio) missing.** The stock config launches `nm-applet`
and `dex --autostart` (which starts XDG autostart entries, e.g. blueman). Verify
the packages are present (§5).

---

## 13. Rolling back

The installer never removes packages and backs up every file it overwrites
(`<file>.bak.<timestamp>`). Restore a backup to revert a config. To remove the
packages:

```bash
sudo apt-get remove --autoremove i3-wm i3status i3lock dex \
    xterm rxvt-unicode rofi suckless-tools xss-lock maim xclip brightnessctl \
    blueman pasystray lxpolkit dunst
# and, to remove the system-wide keymap file:
sudo rm -f /etc/X11/xorg.conf.d/00-keyboard.conf
# and the downloaded font:
rm -rf ~/.local/share/fonts/iosevka && fc-cache -f
```
