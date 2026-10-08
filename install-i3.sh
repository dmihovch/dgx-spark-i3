#!/usr/bin/env bash
# =============================================================================
#  install-i3.sh
#
#  Sets up i3 on NVIDIA DGX Spark (DGX OS 7 — Ubuntu 24.04 "Noble", arm64) on
#  X11.
#
#  Philosophy: the ~/.config/i3/config written here is a NEAR-VERBATIM copy of
#  the upstream i3 default config (i3 4.23). It is intentionally boring/vanilla
#  and has exactly these modifications layered on top:
#
#    * Esc <-> Caps Lock          (XKB: caps:swapescape)
#    * Alt <-> Win                (XKB: altwin:swap_alt_win)
#         physical Alt -> Super (Mod4) ==> i3's $mod key
#         physical Win -> Alt   (Mod1)
#    * $mod = Mod4 (so all the stock Mod1+<key> bindings now use Alt)
#    * vim-style navigation: h=left, j=down, k=up, l=right
#         (the old "split h" binding moved to $mod+semicolon)
#    * Meta+Return = simple terminal (xterm, Iosevka Term)   [neovim friendly]
#    * Meta+b      = firefox
#    * status bar on the BOTTOM and never auto-hides
#    * no compositor / no window fading
#
#  It also installs the Iosevka font and writes ~/.Xresources, which gives xterm
#  its font and working clipboard copy/paste (Ctrl+Shift+C / Ctrl+Shift+V).
#
#  Usage:
#    ./install-i3.sh                     # install packages + font + write configs
#    ./install-i3.sh --persistent-keys   # (default) system-wide keymap file
#    ./install-i3.sh --emit-config DIR   # just (re)generate config files into DIR
#    ./install-i3.sh --no-install        # skip apt, only write config files
#    ./install-i3.sh --no-font           # skip downloading the Iosevka font
#
#  Safe to re-run; existing configs are backed up with a timestamp.
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
#  Tweaks
# ---------------------------------------------------------------------------
XKB_OPTIONS="caps:swapescape,altwin:swap_alt_win"
XKB_LAYOUT="${XKB_LAYOUT:-us}"   # used only for the optional system-wide file

# Iosevka font (downloaded from the upstream GitHub release).
# The release asset name is e.g. "PkgTTC-SGr-IosevkaTerm" (terminal cut) or
# "PkgTTC-SGr-Iosevka" (code-editor cut); see the release's "Quick picker".
IOSEVKA_VERSION="${IOSEVKA_VERSION:-34.9.0}"
IOSEVKA_ASSET="${IOSEVKA_ASSET:-PkgTTC-SGr-IosevkaTerm}"
TERM_FONT_FAMILY="${TERM_FONT_FAMILY:-Iosevka Term}"  # family xterm uses

# ---------------------------------------------------------------------------
#  Argument parsing
# ---------------------------------------------------------------------------
EMIT_ONLY=0
DO_INSTALL=1
DO_FONT=1
PERSISTENT_KEYS=1
EMIT_DIR=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --emit-config)     EMIT_ONLY=1; EMIT_DIR="${2:-$PWD}"; shift 2 ;;
        --no-install)      DO_INSTALL=0; shift ;;
        --no-font)         DO_FONT=0; shift ;;
        --persistent-keys) PERSISTENT_KEYS=1; shift ;;
        -h|--help)         sed -n '2,40p' "$0"; exit 0 ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

# ---------------------------------------------------------------------------
#  Helpers
# ---------------------------------------------------------------------------
log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[warn]\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[error]\033[0m %s\n' "$*" >&2; exit 1; }

if [[ ${EUID} -eq 0 ]]; then
    TARGET_USER="${SUDO_USER:-root}"
else
    TARGET_USER="${USER}"
fi
TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
[[ -n "$TARGET_HOME" ]] || die "Could not determine home directory for user '$TARGET_USER'."

run_priv() { if [[ ${EUID} -eq 0 ]]; then "$@"; else sudo "$@"; fi; }

# ---------------------------------------------------------------------------
#  Config file generators
# ---------------------------------------------------------------------------
write_i3_config() {
    local dest="$1"
    # --- Upstream i3 4.23 default config, with the documented modifications. ---
    cat > "$dest" <<'I3CONFIG'
# i3 config file (v4)
#
# Please see https://i3wm.org/docs/userguide.html for a complete reference!
#
# This config file uses keycodes (bindsym) and was written for the QWERTY
# layout.
#
# ---------------------------------------------------------------------------
#  LOCAL MODIFICATIONS (NVIDIA DGX Spark)
#    * Session-wide keyboard remap (see exec below):
#         Caps Lock <-> Escape            (caps:swapescape)
#         physical Alt <-> physical Win   (altwin:swap_alt_win)
#             physical Alt -> Super (Mod4)  => this is the i3 modifier, $mod
#             physical Win -> Alt   (Mod1)
#    * $mod is Mod4, so every stock "Mod1+<key>" binding below is now "$mod+<key>".
#    * Navigation uses vim keys: h=left, j=down, k=up, l=right
#      (so the old "split h" binding moved to $mod+semicolon).
#    * $mod+Return starts xterm (Iosevka Term); its font and clipboard
#      copy/paste bindings live in ~/.Xresources, loaded with xrdb below.
#    * $mod+b starts firefox.
#    * i3bar sits on the BOTTOM of the screen and never auto-hides.
#    * No compositor, so no window fading.
# ---------------------------------------------------------------------------

# Apply the keyboard preferences to the whole X session.
exec --no-startup-id setxkbmap -option "caps:swapescape,altwin:swap_alt_win"

# Load X resources: xterm font (Iosevka Term) and clipboard copy/paste bindings.
exec --no-startup-id xrdb -merge ~/.Xresources

# i3 modifier = physical Alt (which now emits Super / Mod4).
set $mod Mod4

# Font for window titles. Will also be used by the bar unless a different font
# is used in the bar {} block below.
font pango:monospace 8

# This font is widely installed, provides lots of unicode glyphs, right-to-left
# text rendering and scalability on retina/hidpi displays (thanks to pango).
#font pango:DejaVu Sans Mono 8

# Start XDG autostart .desktop files using dex. See also
# https://wiki.archlinux.org/index.php/XDG_Autostart
exec --no-startup-id dex --autostart --environment i3

# The combination of xss-lock, nm-applet and pactl is a popular choice, so
# they are included here as an example. Modify as you see fit.

# xss-lock grabs a logind suspend inhibit lock and will use i3lock to lock the
# screen before suspend. Use loginctl lock-session to lock your screen.
exec --no-startup-id xss-lock --transfer-sleep-lock -- i3lock --nofork

# NetworkManager is the most popular way to manage wireless networks on Linux,
# and nm-applet is a desktop environment-independent system tray GUI for it.
exec --no-startup-id nm-applet

# Use pactl to adjust volume in PulseAudio.
set $refresh_i3status killall -SIGUSR1 i3status
bindsym XF86AudioRaiseVolume exec --no-startup-id pactl set-sink-volume @DEFAULT_SINK@ +10% && $refresh_i3status
bindsym XF86AudioLowerVolume exec --no-startup-id pactl set-sink-volume @DEFAULT_SINK@ -10% && $refresh_i3status
bindsym XF86AudioMute exec --no-startup-id pactl set-sink-mute @DEFAULT_SINK@ toggle && $refresh_i3status
bindsym XF86AudioMicMute exec --no-startup-id pactl set-source-mute @DEFAULT_SOURCE@ toggle && $refresh_i3status

# use these keys for focus, movement, and resize directions when reaching for
# the arrows is not convenient (vim-style: h=left, j=down, k=up, l=right)
set $up k
set $down j
set $left h
set $right l

# use Mouse+Mod1 to drag floating windows to their wanted position
# (Mod1 is the physical Win key, which now acts as Alt)
floating_modifier Mod1

# move tiling windows via drag & drop by left-clicking into the title bar,
# or left-clicking anywhere into the window while holding the floating modifier.
tiling_drag modifier titlebar

# start a terminal
# (simple terminal that does not use the kitty keyboard protocol -> neovim/tmux safe)
# Font (Iosevka Term) and clipboard settings come from ~/.Xresources.
set $term xterm
bindsym $mod+Return exec $term

# start the web browser
set $browser firefox
bindsym $mod+b exec --no-startup-id $browser

# kill focused window
bindsym $mod+Shift+q kill

# start dmenu (a program launcher)
bindsym $mod+d exec --no-startup-id dmenu_run
# A more modern dmenu replacement is rofi:
# bindsym $mod+d exec "rofi -modi drun,run -show drun"
# There also is i3-dmenu-desktop which only displays applications shipping a
# .desktop file. It is a wrapper around dmenu, so you need that installed.
# bindsym $mod+d exec --no-startup-id i3-dmenu-desktop

# change focus
bindsym $mod+$left focus left
bindsym $mod+$down focus down
bindsym $mod+$up focus up
bindsym $mod+$right focus right

# alternatively, you can use the cursor keys:
bindsym $mod+Left focus left
bindsym $mod+Down focus down
bindsym $mod+Up focus up
bindsym $mod+Right focus right

# move focused window
bindsym $mod+Shift+$left move left
bindsym $mod+Shift+$down move down
bindsym $mod+Shift+$up move up
bindsym $mod+Shift+$right move right

# alternatively, you can use the cursor keys:
bindsym $mod+Shift+Left move left
bindsym $mod+Shift+Down move down
bindsym $mod+Shift+Up move up
bindsym $mod+Shift+Right move right

# split in horizontal orientation
# (moved off "h" so h/j/k/l can be used for vim-style navigation)
bindsym $mod+semicolon split h

# split in vertical orientation
bindsym $mod+v split v

# enter fullscreen mode for the focused container
bindsym $mod+f fullscreen toggle

# change container layout (stacked, tabbed, toggle split)
bindsym $mod+s layout stacking
bindsym $mod+w layout tabbed
bindsym $mod+e layout toggle split

# toggle tiling / floating
bindsym $mod+Shift+space floating toggle

# change focus between tiling / floating windows
bindsym $mod+space focus mode_toggle

# focus the parent container
bindsym $mod+a focus parent

# focus the child container
#bindsym $mod+d focus child

# move the currently focused window to the scratchpad
bindsym $mod+Shift+minus move scratchpad

# Show the next scratchpad window or hide the focused scratchpad window.
# If there are multiple scratchpad windows, this command cycles through them.
bindsym $mod+minus scratchpad show

# Define names for default workspaces for which we configure key bindings later on.
# We use variables to avoid repeating the names in multiple places.
set $ws1 "1"
set $ws2 "2"
set $ws3 "3"
set $ws4 "4"
set $ws5 "5"
set $ws6 "6"
set $ws7 "7"
set $ws8 "8"
set $ws9 "9"
set $ws10 "10"

# switch to workspace
bindsym $mod+1 workspace number $ws1
bindsym $mod+2 workspace number $ws2
bindsym $mod+3 workspace number $ws3
bindsym $mod+4 workspace number $ws4
bindsym $mod+5 workspace number $ws5
bindsym $mod+6 workspace number $ws6
bindsym $mod+7 workspace number $ws7
bindsym $mod+8 workspace number $ws8
bindsym $mod+9 workspace number $ws9
bindsym $mod+0 workspace number $ws10

# move focused container to workspace
bindsym $mod+Shift+1 move container to workspace number $ws1
bindsym $mod+Shift+2 move container to workspace number $ws2
bindsym $mod+Shift+3 move container to workspace number $ws3
bindsym $mod+Shift+4 move container to workspace number $ws4
bindsym $mod+Shift+5 move container to workspace number $ws5
bindsym $mod+Shift+6 move container to workspace number $ws6
bindsym $mod+Shift+7 move container to workspace number $ws7
bindsym $mod+Shift+8 move container to workspace number $ws8
bindsym $mod+Shift+9 move container to workspace number $ws9
bindsym $mod+Shift+0 move container to workspace number $ws10

# reload the configuration file
bindsym $mod+Shift+c reload
# restart i3 inplace (preserves your layout/session, can be used to upgrade i3)
bindsym $mod+Shift+r restart
# exit i3 (logs you out of your X session)
bindsym $mod+Shift+e exec "i3-nagbar -t warning -m 'You pressed the exit shortcut. Do you really want to exit i3? This will end your X session.' -B 'Yes, exit i3' 'i3-msg exit'"

# resize window (you can also use the mouse for that)
mode "resize" {
        # These bindings trigger as soon as you enter the resize mode

        # Pressing left will shrink the window’s width.
        # Pressing right will grow the window’s width.
        # Pressing up will shrink the window’s height.
        # Pressing down will grow the window’s height.
        bindsym $left       resize shrink width 10 px or 10 ppt
        bindsym $down       resize grow height 10 px or 10 ppt
        bindsym $up         resize shrink height 10 px or 10 ppt
        bindsym $right      resize grow width 10 px or 10 ppt

        # same bindings, but for the arrow keys
        bindsym Left        resize shrink width 10 px or 10 ppt
        bindsym Down        resize grow height 10 px or 10 ppt
        bindsym Up          resize shrink height 10 px or 10 ppt
        bindsym Right       resize grow width 10 px or 10 ppt

        # back to normal: Enter or Escape or $mod+r
        bindsym Return mode "default"
        bindsym Escape mode "default"
        bindsym $mod+r mode "default"
}

bindsym $mod+r mode "resize"

# Start i3bar to display a workspace bar (plus the system information i3status
# finds out, if available).
# Kept vanilla except: it is anchored to the bottom and stays visible
# (default mode is "dock", i.e. it does not auto-hide).
bar {
        status_command i3status
        position bottom
}
I3CONFIG
}

write_i3status_config() {
    local dest="$1"
    cat > "$dest" <<'I3STATUS'
# i3status configuration  ·  ~/.config/i3status/config
general {
    colors      = true
    interval    = 5
    markup      = pango
    color_good     = "#b5bd68"
    color_degraded = "#f0c674"
    color_bad      = "#cc6666"
}

order += "wireless _first_"
order += "ethernet _first_"
order += "disk /"
order += "load"
order += "memory"
order += "cpu_temperature 0"
order += "tztime local"

wireless _first_ {
    format_up   = "  %essid %quality"
    format_down = "  wifi down"
}

ethernet _first_ {
    format_up   = "  %ip"
    format_down = "  eth down"
}

disk "/" {
    format = "  %avail free"
}

load {
    format = "  load %1min"
}

memory {
    format = "  mem %used/%total"
}

cpu_temperature 0 {
    format = "  %degrees°C"
    max_threshold = 95
}

tztime local {
    format = "%a %Y-%m-%d  %H:%M:%S"
}
I3STATUS
}

write_xinitrc() {
    local dest="$1"
    cat > "$dest" <<'XINITRC'
#!/bin/sh
# ~/.xinitrc  — used when starting a session with `startx`.

# Apply the keyboard preferences (Caps<->Esc, Alt<->Win).
setxkbmap -option "caps:swapescape,altwin:swap_alt_win"

# Merge X resources if present.
[ -f "$HOME/.Xresources" ] && xrdb -merge "$HOME/.Xresources"

exec i3
XINITRC
    chmod +x "$dest"
}

write_xresources() {
    local dest="$1"
    cat > "$dest" <<XRESOURCES
! ~/.Xresources  —  managed by install-i3.sh
!
! Loaded by the i3 config (exec xrdb -merge ~/.Xresources) and by ~/.xinitrc.
! Re-apply after editing with:  xrdb -merge ~/.Xresources

! ---------------------------------------------------------------------------
!  xterm: font
! ---------------------------------------------------------------------------
! "Iosevka Term" is the terminal-optimised cut of Iosevka (installed by
! install-i3.sh into ~/.local/share/fonts). Use "Iosevka" for the narrower
! default cut, or "Iosevka Fixed" for a strictly monospaced cut.
XTerm*faceName: ${TERM_FONT_FAMILY}
XTerm*faceSize: 18

! ---------------------------------------------------------------------------
!  xterm: clipboard (copy / paste)
! ---------------------------------------------------------------------------
! Put mouse selections on the CLIPBOARD as well as PRIMARY, so a selection can
! be pasted with Ctrl+V in other applications.
XTerm*selectToClipboard: true

! Ctrl+Shift+C = copy, Ctrl+Shift+V = paste.
! (The xterm defaults still work too: middle-click pastes PRIMARY, and
!  Shift+Insert pastes PRIMARY/CLIPBOARD.)
XTerm*VT100.Translations: #override \n\\
    Ctrl Shift <Key>C: copy-selection(CLIPBOARD) \n\\
    Ctrl Shift <Key>V: insert-selection(CLIPBOARD)
XRESOURCES
}

# ---------------------------------------------------------------------------
#  Iosevka font (for the terminal)
# ---------------------------------------------------------------------------
install_iosevka_font() {
    local font_dir="$TARGET_HOME/.local/share/fonts/iosevka"
    local url="https://github.com/be5invis/Iosevka/releases/download/v${IOSEVKA_VERSION}/${IOSEVKA_ASSET}-${IOSEVKA_VERSION}.zip"

    if command -v fc-list >/dev/null 2>&1 && fc-list 2>/dev/null | grep -qi 'Iosevka'; then
        log "An Iosevka font is already installed."
        return 0
    fi

    log "Downloading Iosevka ${IOSEVKA_VERSION} (${IOSEVKA_ASSET})…"
    local tmp
    tmp="$(mktemp -d)"
    if ! curl -fL --retry 3 -o "$tmp/iosevka.zip" "$url"; then
        warn "Could not download Iosevka from: $url"
        warn "Install it manually and set the family in ~/.Xresources."
        rm -rf "$tmp"
        return 1
    fi

    log "Installing fonts into $font_dir…"
    mkdir -p "$font_dir"
    unzip -o -q "$tmp/iosevka.zip" -d "$tmp/extract"
    find "$tmp/extract" -type f \( -iname '*.ttf' -o -iname '*.ttc' -o -iname '*.otf' \) \
        -exec cp -f {} "$font_dir/" \;
    rm -rf "$tmp"

    if command -v fc-cache >/dev/null 2>&1; then
        fc-cache -f "$font_dir" >/dev/null 2>&1 || true
    fi
    log "Iosevka installed. Terminal family: '$TERM_FONT_FAMILY'."
}

# ---------------------------------------------------------------------------
#  EMIT-ONLY mode
# ---------------------------------------------------------------------------
if [[ ${EMIT_ONLY} -eq 1 ]]; then
    mkdir -p "$EMIT_DIR"
    write_i3_config       "$EMIT_DIR/config"
    write_i3status_config "$EMIT_DIR/i3status.conf"
    write_xinitrc         "$EMIT_DIR/xinitrc"
    write_xresources      "$EMIT_DIR/Xresources"
    log "Config files written to: $EMIT_DIR"
    ls -l "$EMIT_DIR"
    exit 0
fi

# ---------------------------------------------------------------------------
#  Sanity checks
# ---------------------------------------------------------------------------
log "Target user: $TARGET_USER   home: $TARGET_HOME"
ARCH="$(uname -m)"
if [[ "$ARCH" != "aarch64" && "$ARCH" != "arm64" ]]; then
    warn "Architecture is '$ARCH' — this bundle targets DGX Spark (aarch64). Continuing anyway."
fi
if [[ -r /etc/os-release ]]; then
    . /etc/os-release
    log "Detected OS: ${PRETTY_NAME:-unknown}"
fi
if [[ "${XDG_SESSION_TYPE:-}" == "wayland" ]]; then
    warn "Current session is Wayland. i3 is X11-only — log out and pick the 'i3' (X11) session."
fi

# ---------------------------------------------------------------------------
#  Packages
# ---------------------------------------------------------------------------
PKGS=(
    # window manager core
    i3-wm i3status i3lock dex
    # session / X utilities
    xinit x11-xserver-utils x11-xkb-utils xdg-utils dbus-x11
    # launcher / terminals (xterm + rxvt-unicode: no kitty keyboard protocol)
    suckless-tools rofi xterm rxvt-unicode
    # status-bar / tray plumbing
    network-manager-gnome blueman pasystray
    pulseaudio-utils pavucontrol playerctl
    # notifications / misc
    dunst libnotify-bin
    brightnessctl xss-lock lxpolkit gnome-keyring
    # screenshots / clipboard
    maim xclip
    # fonts / theming
    fonts-dejavu fonts-font-awesome lxappearance
)

if [[ ${DO_INSTALL} -eq 1 ]]; then
    log "Updating package lists…"
    run_priv apt-get update

    log "Installing i3 and plumbing packages…"
    run_priv env DEBIAN_FRONTEND=noninteractive apt-get install -y "${PKGS[@]}"
    log "Package installation complete."

    # --- Browser: Meta+b launches Firefox (best effort) --------------------
    # On Ubuntu 24.04 the 'firefox' apt package is a transitional package that
    # pulls in the Firefox snap. Some DGX OS images lack snapd, so do not let a
    # failure here abort the whole install.
    if command -v firefox >/dev/null 2>&1; then
        log "Firefox already present."
    else
        log "Installing Firefox (best effort)…"
        if run_priv env DEBIAN_FRONTEND=noninteractive apt-get install -y firefox \
              && command -v firefox >/dev/null 2>&1; then
            log "Firefox installed."
        else
            warn "Could not install Firefox automatically (DGX OS may not have snapd)."
            warn "Install it your way (snap, Mozilla repo, flatpak) — the \$mod+b"
            warn "binding just runs 'firefox', or edit 'set \$browser' in the i3 config."
        fi
    fi
else
    log "Skipping package installation (--no-install)."
fi

# ---------------------------------------------------------------------------
#  Iosevka font
# ---------------------------------------------------------------------------
if [[ ${DO_FONT} -eq 1 ]]; then
    install_iosevka_font || true
else
    log "Skipping Iosevka font install (--no-font)."
fi

# ---------------------------------------------------------------------------
#  Write configs (with backups)
# ---------------------------------------------------------------------------
backup_if_exists() {
    local f="$1"
    if [[ -e "$f" && ! -e "${f}.bak.$(date +%s)" ]]; then
        local b
        b="${f}.bak.$(date +%Y%m%d-%H%M%S)"
        cp -a "$f" "$b"
        warn "Backed up existing '$f' -> '$b'"
    fi
}

log "Writing configuration files…"
mkdir -p "$TARGET_HOME/.config/i3" "$TARGET_HOME/.config/i3status"

backup_if_exists "$TARGET_HOME/.config/i3/config"
backup_if_exists "$TARGET_HOME/.config/i3status/config"
backup_if_exists "$TARGET_HOME/.xinitrc"
backup_if_exists "$TARGET_HOME/.Xresources"

write_i3_config       "$TARGET_HOME/.config/i3/config"
write_i3status_config "$TARGET_HOME/.config/i3status/config"
write_xinitrc         "$TARGET_HOME/.xinitrc"
write_xresources      "$TARGET_HOME/.Xresources"

if [[ ${EUID} -eq 0 && "$TARGET_USER" != "root" ]]; then
    chown -R "$TARGET_USER":"$TARGET_USER" "$TARGET_HOME/.config" "$TARGET_HOME/.xinitrc" 2>/dev/null || true
fi

# ---------------------------------------------------------------------------
#  Persist the keymap system-wide (greeter, and survives suspend/resume)
# ---------------------------------------------------------------------------
if [[ ${PERSISTENT_KEYS} -eq 1 ]]; then
    log "Writing /etc/X11/xorg.conf.d/00-keyboard.conf…"
    run_priv mkdir -p /etc/X11/xorg.conf.d
    TMP_KB="$(mktemp)"
    cat > "$TMP_KB" <<EOF
# Managed by install-i3.sh — persistent X11 keyboard options.
# Applies at the display manager / greeter and in every X session.
Section "InputClass"
    Identifier   "system-keyboard"
    MatchIsKeyboard "on"
    Option "XkbLayout"  "${XKB_LAYOUT}"
    Option "XkbOptions" "${XKB_OPTIONS}"
EndSection
EOF
    run_priv cp "$TMP_KB" /etc/X11/xorg.conf.d/00-keyboard.conf
    rm -f "$TMP_KB"
    # Xorg runs rootless (as the logged-in user) on modern GDM, so the file must
    # be world-readable or the X server silently ignores it.
    run_priv chmod 0644 /etc/X11/xorg.conf.d/00-keyboard.conf
    warn "Persistent keymap written (mode 0644). A full log out / reboot is needed for it to apply everywhere."

    # Keep GNOME's own input-source settings in sync, so any GNOME component
    # (gsd-keyboard, ibus, …) that re-applies the layout keeps the swaps too.
    if command -v gsettings >/dev/null 2>&1; then
        if gsettings set org.gnome.desktop.input-sources xkb-options \
                "['caps:swapescape', 'altwin:swap_alt_win']" 2>/dev/null; then
            log "Updated GNOME xkb-options (dconf)."
        else
            warn "Could not update GNOME xkb-options (no dconf session?)."
        fi
    fi
fi

# ---------------------------------------------------------------------------
#  Done
# ---------------------------------------------------------------------------
cat <<EOF

=============================================================================
  i3 setup complete for user '$TARGET_USER'.
=============================================================================

  Files written:
    ~/.config/i3/config          (vanilla i3 config + your modifications)
    ~/.config/i3status/config    (status bar)
    ~/.xinitrc                   (for 'startx' from a TTY)
    ~/.Xresources                (xterm font + clipboard copy/paste)

  Keyboard, as requested:
    Caps Lock  <->  Escape
    Physical Alt  -> Super (Mod4)  == your i3 \$mod key
    Physical Win  -> Alt   (Mod1)

  i3:  \$mod+Return = xterm (Iosevka Term, neovim-friendly),  \$mod+b = firefox
       navigation is vim-style: h=left  j=down  k=up  l=right
       (split-horizontal is now \$mod+semicolon)
       bar is on the bottom, no compositor / no window fading.

  Terminal:
    Font:      $TERM_FONT_FAMILY
    Copy:      select with the mouse, or Ctrl+Shift+C
    Paste:     Ctrl+Shift+V (also middle-click / Shift+Insert)

  Next steps:
    1. Log out, then pick the "i3" session at the login screen
       (gear/cog icon on GDM -> "i3").
       - or, from a TTY with no display manager:  startx
    2. Verify the remap inside the session:
           setxkbmap -print | grep -o 'caps:swapescape,altwin:swap_alt_win'
           xev   # press Caps/Esc/Alt/Win and inspect keysyms

  System-wide keymap written (mode 0644): it survives suspend/resume and covers
  the greeter.
=============================================================================
EOF
