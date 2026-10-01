# i3 on NVIDIA DGX Spark (DGX OS, X11)

A small, self-contained bundle that turns a fresh **DGX Spark running DGX OS**
(Ubuntu 24.04 "Noble" base, `arm64`) into a working **i3 tiling desktop** — with
the keyboard remapped exactly the way you asked for.

> **Target:** DGX OS 7 · Ubuntu 24.04 · `aarch64` · **X11** (not Wayland).
> i3 is an X11 window manager; it will not run *inside* a Wayland session.

---

## 1. Your keyboard preferences (what this does)

You asked for three things. They are all implemented with **XKB**, so they apply
to every application in the session, not just i3:

| You press (physical key) | The system delivers | XKB option applied |
|---|---|---|
| **Caps Lock** | **Escape** | `caps:swapescape` |
| **Escape** | **Caps Lock** | `caps:swapescape` |
| **Alt** | **Super** (Mod4) → becomes i3's `$mod` | `altwin:swap_alt_win` |
| **Win** | **Alt** (Mod1) | `altwin:swap_alt_win` |

Net effect:

* **Esc and Caps Lock are swapped.**
* **Alt acts as the Super key** — and because i3's modifier is set to `Mod4`,
  **Alt is your i3 `$mod` key** (so `Alt+Return` opens a terminal, `Alt+d` the
  launcher, `Alt+1..0` switches workspaces, etc.).
* **Win acts as Alt** (Mod1), i.e. the classic Alt behaviour.

The mapping is applied two ways for robustness:

1. `exec setxkbmap -option "caps:swapescape,altwin:swap_alt_win"` at the top of
   `~/.config/i3/config` (always active inside the i3 session), **and**
2. `~/.xinitrc` does the same for `startx` sessions.

There is also an **optional** system-wide file (see
[§6](#6-optional-remap-at-the-login-greeter-too)) that additionally remaps keys
at the display-manager greeter.

> Want to double-check the option names? `grep -i altwin /usr/share/X11/xkb/rules/evdev.lst`
> and `grep -i 'caps:' /usr/share/X11/xkb/rules/evdev.lst`.

---

## 2. Quick start

```bash
# From this directory (keep install-i3.sh and the .conf files together, or just
# use the script on its own — it embeds all the configs):
chmod +x install-i3.sh
./install-i3.sh
```

The script will:

1. `apt-get update` and install i3 + everything needed to make a bare WM a
   daily driver (see [§4](#4-what-gets-installed)).
2. Write the config files into the right places (backing up anything already
   there).
3. Print next steps.

Then **log out and pick the `i3` session** at the login screen and you're done.

Useful flags:

| Flag | Effect |
|---|---|
| `--persistent-keys` | Also write `/etc/X11/xorg.conf.d/00-keyboard.conf` so the remap applies at the greeter too. |
| `--no-install` | Skip `apt`; only (re)write the config files. |
| `--emit-config DIR` | Just dump the canonical config files into `DIR` (handy for inspecting/editing before installing). |

---

## 3. What's in this bundle

```
install-i3.sh        The installer (self-contained; embeds all configs)
README.md            This document
config               i3 config            -> ~/.config/i3/config
i3status.conf        status-bar config    -> ~/.config/i3status/config
picom.conf           compositor config    -> ~/.config/picom/picom.conf
screenshot.sh        Print / Alt+Print    -> ~/.config/i3/screenshot.sh
xinitrc              startx session       -> ~/.xinitrc
```

`config`, `i3status.conf`, `picom.conf`, `screenshot.sh` and `xinitrc` are the
exact files the installer writes. They were generated *from* the installer
(`./install-i3.sh --emit-config .`), so the copies here and the installed files
never drift.

---

## 4. What gets installed

Grouped by purpose so you can trim the list to taste (edit the `PKGS` array in
`install-i3.sh`):

* **Window manager:** `i3-wm`, `i3status`, `i3lock`
* **X / session:** `xinit`, `x11-xserver-utils`, `x11-xkb-utils`, `xdg-utils`, `dbus-x11`
* **Launcher / terminal:** `suckless-tools` (provides `dmenu`), `rofi`, `xterm`,
  `rxvt-unicode` (both simple terminals — see
  [§5.1](#51-why-xterm-and-not-alacrittykitty))
* **Browser:** `firefox` (installed on a **best-effort** basis — see
  [§5.2](#52-firefox-and-dgx-os-snap-caveat))
* **Status-bar plumbing:** `network-manager-gnome` (`nm-applet`), `blueman`,
  `pasystray`, `pulseaudio-utils` (`pactl`), `pavucontrol`, `playerctl`
* **Desktop niceties:** `dunst`, `libnotify-bin`, `feh`, `picom`, `brightnessctl`,
  `xss-lock`, `lxpolkit`, `gnome-keyring`
* **Screenshots / clipboard:** `maim`, `xclip`
* **Fonts / theming:** `fonts-dejavu`, `fonts-font-awesome`, `lxappearance`

> All of these are available for `arm64` from the Ubuntu 24.04 archives, so no
> third-party repositories are required.

---

## 5. Day-to-day usage

After logging into the i3 session:

| Keys | Action |
|---|---|
| **Alt + Return** | Terminal (`xterm`) |
| **Alt + d** | Launcher (`dmenu`) |
| **Alt + b** | Browser (`firefox`) |
| **Alt + h / v** | Split horizontal / vertical |
| **Alt + s / w / e** | Stacking / tabbed / toggle-split layout |
| **Alt + f** | Fullscreen |
| **Alt + Shift + space** | Toggle floating |
| **Alt + a** | Focus parent container |
| **Alt + arrows** (or `j k l ;`) | Focus window |
| **Alt + Shift + arrows** (or `j k l ;`) | Move window |
| **Alt + 1…0** | Switch workspace |
| **Alt + Shift + 1…0** | Move container to workspace |
| **Alt + r** | Enter resize mode (arrows, then `Return`/`Esc`) |
| **Alt + Shift + x** | Lock screen |
| **Print** / **Alt + Print** | Screenshot (full / region) → `~/Pictures/Screenshots` |
| **Alt + Shift + c / r / e** | Reload / restart / exit i3 |

This is essentially the standard i3 keymap, so your muscle memory should mostly
just work — the only deliberate change is that **Alt is now `$mod`**.

### 5.1 Why xterm (and not Alacritty/kitty)

You asked for a terminal that "plays nice with Neovim" and avoids
**kitty keyboard protocol** issues. That protocol (CSI-u / progressive keyboard
enhancement) is implemented by **kitty, foot, WezTerm, Ghostty and Alacritty
(0.13+)**, and it's a common source of broken key handling in Neovim and tmux.

The default here is therefore **`xterm`**, which does not implement the protocol
at all, with **`rxvt-unicode` (`urxvt`)** installed as an equally-safe
alternative. The default binding is set in the i3 config as:

```i3config
set $term xterm -fa "DejaVu Sans Mono" -fs 12
```

To switch to urxvt instead, change that one line to e.g.:

```i3config
set $term urxvt -fn "xft:DejaVu Sans Mono:pixelsize=14"
```

(Other safe, protocol-free choices: `st`, `xfce4-terminal`, `gnome-terminal`.)
The original Alacritty package was intentionally dropped from the install list
for this reason.

### 5.2 Firefox and DGX OS (snap caveat)

The **Alt + b** binding simply runs `firefox`. The installer tries
`apt-get install firefox`, but note that on Ubuntu 24.04 that package is a
**transitional package that installs the Firefox snap**. DGX OS images may not
ship `snapd`, so this step is deliberately **best-effort** and never aborts the
rest of the install.

If Firefox didn't install automatically, install it however suits the box
(`snap install firefox`, the Mozilla `apt` repo, or a Flatpak), or point the
binding at a different browser by editing `set $browser …` in
`~/.config/i3/config`. Verify with `command -v firefox`.

---

## 6. Optional: remap at the login greeter too

The i3-session remap does not cover the **GDM/greeter** (login screen), because
the greeter is a separate X session. If you want Caps/Esc and Alt/Win swapped
there too:

```bash
./install-i3.sh --no-install --persistent-keys
```

This writes:

```ini
# /etc/X11/xorg.conf.d/00-keyboard.conf
Section "InputClass"
    Identifier   "system-keyboard"
    MatchIsKeyboard "on"
    Option "XkbLayout"  "us"                                      # change if needed
    Option "XkbOptions" "caps:swapescape,altwin:swap_alt_win"
EndSection
```

Reboot (or fully restart the display manager) to apply it system-wide. Override
the layout with `XKB_LAYOUT=de ./install-i3.sh --persistent-keys`, etc.

---

## 7. Verifying the keyboard mapping

Inside the i3 session:

```bash
# Confirm the options are active:
setxkbmap -print | tr ',' '\n' | grep -E 'swapescape|swap_alt_win'

# Interactive check — press Caps Lock, Esc, Alt and Win:
xev
```

In `xev`:

* Pressing **Caps Lock** should report keysym `Escape`.
* Pressing **Escape** should report `Caps_Lock`.
* Pressing **Alt** should report `Super_L` (modifiers include `Mod4`).
* Pressing **Win** should report `Alt_L` (modifiers include `Mod1`).

If you don't see this, your session is probably not the i3 session, or you're on
Wayland (see below).

---

## 8. Customizing

Everything lives under `~/.config/`:

* **Terminal / launcher / browser:** edit `set $term`, `set $menu` and
  `set $browser` in `~/.config/i3/config` (defaults: `xterm`, `dmenu_run`,
  `firefox`). See [§5.1](#51-why-xterm-and-not-alacrittykitty) for the terminal
  rationale.
* **Gaps/borders:** `gaps inner/outer`, `default_border pixel 2`.
* **Wallpaper:** drop a PNG at `~/.config/i3/wallpaper.png`; i3 will apply it on
  startup (`feh --bg-fill`).
* **Status bar:** `~/.config/i3status/config` — wireless/ethernet, disk, load,
  memory, CPU temperature, clock.
* **Compositor:** `~/.config/picom/picom.conf` — shadows, fading, vsync.
* **Screenshots:** `~/.config/i3/screenshot.sh`.

After editing `~/.config/i3/config`, reload with **Alt + Shift + c**.

---

## 9. Choosing the i3 session at login

`i3-wm` ships `/usr/share/xsessions/i3.desktop`, so a display manager (GDM, which
DGX OS uses) will offer it:

1. Log out.
2. On the GDM login screen, click the **gear/cog** icon (bottom-right on most
   themes).
3. Select **i3**.
4. Log in.

If instead you run headless/from a TTY with no display manager, use:

```bash
startx     # uses ~/.xinitrc, which applies the keymap and execs i3
```

To make i3 the **default** session, you can either leave GNOME installed and just
pick i3 at login, or (more invasive) tell GDM to use i3 — not recommended unless
you want to remove GNOME. The script does not change your default session.

---

## 10. Troubleshooting

**"I logged in but it's still GNOME."**
You didn't select the i3 session — see [§9](#9-choosing-the-i3-session-at-login).

**Keys aren't swapped inside i3.**
Check the session is X11, not Wayland: `echo $XDG_SESSION_TYPE` should print
`x11`. i3 can't run under Wayland. Also re-run the setxkbmap line manually:

```bash
setxkbmap -option "caps:swapescape,altwin:swap_alt_win"
```

**The greeter keys aren't swapped.**
Expected — the greeter is a separate session; use `--persistent-keys` (§6).

**`$mod` (Alt) doesn't do anything.**
Confirm i3 read the config: `i3-msg -t get_version` and check
`~/.config/i3/config` starts with `set $mod Mod4` and the `setxkbmap` exec line.
Reload with **Alt + Shift + c**.

**A tray applet (network/bluetooth/audio) isn't showing.**
Those need a running tray. The i3 `bar { tray_output primary }` provides one; the
applets are launched from the i3 config. Verify they exist:
`command -v nm-applet blueman-applet pasystray`. If one is missing, install its
package (see §4).

**Tearing / no shadows.**
Tune or disable `picom` in the i3 config, or edit
`~/.config/picom/picom.conf`. With the NVIDIA driver, `backend = "glx"` is
usually right; try `"xrender"` if you hit issues.

**Wrong terminal / launcher / browser.**
Edit `set $term` / `set $menu` / `set $browser` (§8). `xterm`, `rxvt-unicode`
and `rofi` are installed as alternatives.

**Alt + b does nothing.**
Firefox isn't on `PATH`. Check `command -v firefox`; if missing, see
[§5.2](#52-firefox-and-dgx-os-snap-caveat).

**Neovim key handling looks wrong.**
Make sure you're using `xterm`/`rxvt-unicode` (not Alacritty/kitty/WezTerm/foot),
which don't emit the kitty keyboard protocol. See
[§5.1](#51-why-xterm-and-not-alacrittykitty).

**Suspend doesn't lock.**
`xss-lock` is wired to `i3lock`. Test with `xss-lock --transfer-sleep-lock -- i3lock -n -c 1a1a1a &`.

---

## 11. Rolling back

The installer never removes packages and backs up any file it overwrites
(`<file>.bak.<timestamp>`). To revert a config, restore the backup. To remove the
added packages:

```bash
sudo apt-get remove --autoremove i3-wm i3status i3lock picom dunst \
    xterm rxvt-unicode rofi suckless-tools xss-lock maim xclip brightnessctl \
    blueman pasystray lxpolkit
# and, if you used --persistent-keys:
sudo rm -f /etc/X11/xorg.conf.d/00-keyboard.conf
```
