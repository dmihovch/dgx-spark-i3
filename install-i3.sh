#!/usr/bin/env bash
# =============================================================================
#  install-i3.sh
#
#  Sets up a complete i3 tiling-desktop environment on NVIDIA DGX Spark
#  (DGX OS 7 — Ubuntu 24.04 "Noble" base, arm64) running X11.
#
#  What it does:
#    1. Installs the i3 window manager and the "plumbing" that makes a bare
#       WM usable as a daily driver: terminal, launcher, status bar, lock,
#       compositor, notifications, network/bluetooth/audio tray applets,
#       screenshot + clipboard tools, fonts, etc.
#    2. Writes an opinionated i3 config to ~/.config/i3/config
#    3. Writes i3status, picom, screenshot helper and ~/.xinitrc
#    4. Applies YOUR keyboard preferences (see below)
#
#  Keyboard preferences (the whole point):
#    * Esc  <->  Caps Lock          XKB option: caps:swapescape
#    * Alt  <->  Win                XKB option: altwin:swap_alt_win
#        - Physical "Alt" now emits Super (Mod4) -> used as i3's $mod key
#        - Physical "Win" now emits Alt   (Mod1)
#
#  Usage:
#    ./install-i3.sh                     # install packages + write configs
#    ./install-i3.sh --persistent-keys   # also persist keymap for the greeter
#    ./install-i3.sh --emit-config DIR   # just (re)generate config files into DIR
#    ./install-i3.sh --no-install        # skip apt, only write config files
#
#  Tested target: DGX OS 7 / Ubuntu 24.04, X11 (not Wayland).
#  Safe to re-run; existing configs are backed up with a timestamp.
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
#  Configuration knobs (edit before running if you like)
# ---------------------------------------------------------------------------
# XKB options applied to the X session.
XKB_OPTIONS="caps:swapescape,altwin:swap_alt_win"
# XKB layout/variant used only for the OPTIONAL system-wide file.
XKB_LAYOUT="${XKB_LAYOUT:-us}"

# NOTE: the terminal ($term = xterm), launcher ($menu = dmenu_run) and browser
# ($browser = firefox) that the keybindings use are set inside the embedded
# ~/.config/i3/config below.

# ---------------------------------------------------------------------------
#  Argument parsing
# ---------------------------------------------------------------------------
EMIT_ONLY=0
DO_INSTALL=1
PERSISTENT_KEYS=0
EMIT_DIR=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --emit-config)  EMIT_ONLY=1; EMIT_DIR="${2:-$PWD}"; shift 2 ;;
        --no-install)   DO_INSTALL=0; shift ;;
        --persistent-keys) PERSISTENT_KEYS=1; shift ;;
        -h|--help)
            sed -n '2,40p' "$0"; exit 0 ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

# ---------------------------------------------------------------------------
#  Helpers
# ---------------------------------------------------------------------------
log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[warn]\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[error]\033[0m %s\n' "$*" >&2; exit 1; }

# Resolve the user we are installing FOR (works under sudo too).
if [[ ${EUID} -eq 0 ]]; then
    TARGET_USER="${SUDO_USER:-root}"
else
    TARGET_USER="${USER}"
fi
TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
[[ -n "$TARGET_HOME" ]] || die "Could not determine home directory for user '$TARGET_USER'."

run_priv() {
    if [[ ${EUID} -eq 0 ]]; then "$@"; else sudo "$@"; fi
}

# ---------------------------------------------------------------------------
#  Config file generators  (each takes a destination file path)
# ---------------------------------------------------------------------------
write_i3_config() {
    local dest="$1"
    cat > "$dest" <<'I3CONFIG'
# ===========================================================================
#  i3 configuration
#  Target: NVIDIA DGX Spark  ·  DGX OS 7 (Ubuntu 24.04, arm64)  ·  X11
#  File:   ~/.config/i3/config
# ===========================================================================
#
#  Keyboard customization (applies to the whole X session):
#    * Caps Lock  <->  Escape            (XKB: caps:swapescape)
#    * Physical Alt <-> Physical Win     (XKB: altwin:swap_alt_win)
#         physical Alt  ->  Super  (Mod4)  ==> this is our $mod key
#         physical Win  ->  Alt    (Mod1)
#
# ---------------------------------------------------------------------------

exec --no-startup-id setxkbmap -option "caps:swapescape,altwin:swap_alt_win"

# Physical Alt (now Super/Mod4) is the i3 modifier.
set $mod Mod4
# Physical Win (now Alt/Mod1), available as a secondary modifier if wanted.
set $alt Mod1

# --- Fonts -----------------------------------------------------------------
font pango:DejaVu Sans Mono 10

# --- Gaps / borders (native in i3 >= 4.22) ---------------------------------
gaps inner 8
gaps outer 4
smart_gaps on
smart_borders on
default_border pixel 2
default_floating_border pixel 2
hide_edge_borders smart

# --- Behaviour -------------------------------------------------------------
focus_follows_mouse no
mouse_warping output
workspace_layout default

# --- Startup applications --------------------------------------------------
# Notifications
exec --no-startup-id dunst
# Network / Bluetooth / Audio tray applets
exec --no-startup-id nm-applet --indicator
exec --no-startup-id blueman-applet
exec --no-startup-id pasystray
# Compositor (shadows, no tearing)
exec --no-startup-id picom --config "$HOME/.config/picom/picom.conf"
# Lock the screen on suspend
exec --no-startup-id xss-lock --transfer-sleep-lock -- i3lock -n -c 1a1a1a
# Wallpaper (only if a wallpaper.png exists)
exec --no-startup-id bash -c '[ -f "$HOME/.config/i3/wallpaper.png" ] && feh --bg-fill "$HOME/.config/i3/wallpaper.png"'

# --- Programs --------------------------------------------------------------
# Simple terminal that does NOT implement the "kitty keyboard protocol", so it
# plays nicely with Neovim/tmux (no CSI-u key weirdness). xterm is the most
# conservative choice; rxvt-unicode is equally fine (both are installed).
set $term xterm -fa "DejaVu Sans Mono" -fs 12
set $menu dmenu_run -i -p "run:"
set $browser firefox

# --- Launching -------------------------------------------------------------
bindsym $mod+Return       exec --no-startup-id $term
bindsym $mod+Shift+Return exec --no-startup-id $term -e tmux
bindsym $mod+d            exec --no-startup-id $menu
bindsym $mod+b            exec --no-startup-id $browser
bindsym $mod+n            exec --no-startup-id xdg-open "$HOME"

# --- Window management -----------------------------------------------------
bindsym $mod+Shift+q kill
bindsym $mod+f       fullscreen toggle
bindsym $mod+Shift+space floating toggle
bindsym $mod+space   focus mode_toggle
bindsym $mod+a       focus parent

# --- Layout / splitting ----------------------------------------------------
bindsym $mod+h split h
bindsym $mod+v split v
bindsym $mod+s layout stacking
bindsym $mod+w layout tabbed
bindsym $mod+e layout toggle split

# --- Focus -----------------------------------------------------------------
bindsym $mod+Left  focus left
bindsym $mod+Down  focus down
bindsym $mod+Up    focus up
bindsym $mod+Right focus right
# home-row (vim-ish) aliases
bindsym $mod+j focus left
bindsym $mod+k focus down
bindsym $mod+l focus up
bindsym $mod+semicolon focus right

# --- Move windows ----------------------------------------------------------
bindsym $mod+Shift+Left  move left
bindsym $mod+Shift+Down  move down
bindsym $mod+Shift+Up    move up
bindsym $mod+Shift+Right move right
bindsym $mod+Shift+j move left
bindsym $mod+Shift+k move down
bindsym $mod+Shift+l move up
bindsym $mod+Shift+semicolon move right

# --- Workspaces ------------------------------------------------------------
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

# --- Resize mode -----------------------------------------------------------
mode "resize" {
    bindsym Left  resize shrink width  5 px or 5 ppt
    bindsym Down  resize grow   height 5 px or 5 ppt
    bindsym Up    resize shrink height 5 px or 5 ppt
    bindsym Right resize grow   width  5 px or 5 ppt
    bindsym j resize shrink width  5 px or 5 ppt
    bindsym k resize grow   height 5 px or 5 ppt
    bindsym l resize shrink height 5 px or 5 ppt
    bindsym semicolon resize grow width 5 px or 5 ppt

    bindsym Return mode "default"
    bindsym Escape mode "default"
}
bindsym $mod+r mode "resize"

# --- i3 control ------------------------------------------------------------
bindsym $mod+Shift+c reload
bindsym $mod+Shift+r restart
bindsym $mod+Shift+e exec --no-startup-id i3-nagbar -t warning -m 'Exit i3?' -B 'Yes, exit i3' 'i3-msg exit'
bindsym $mod+Shift+x exec --no-startup-id i3lock -n -c 1a1a1a

# --- Screenshots (see ~/.config/i3/screenshot.sh) --------------------------
bindsym Print       exec --no-startup-id ~/.config/i3/screenshot.sh
bindsym $mod+Print  exec --no-startup-id ~/.config/i3/screenshot.sh select

# --- Media / hardware keys -------------------------------------------------
bindsym XF86AudioRaiseVolume exec --no-startup-id pactl set-sink-volume @DEFAULT_SINK@ +5%
bindsym XF86AudioLowerVolume exec --no-startup-id pactl set-sink-volume @DEFAULT_SINK@ -5%
bindsym XF86AudioMute        exec --no-startup-id pactl set-sink-mute   @DEFAULT_SINK@ toggle
bindsym XF86AudioMicMute     exec --no-startup-id pactl set-source-mute @DEFAULT_SOURCE@ toggle
bindsym XF86AudioPlay        exec --no-startup-id playerctl play-pause
bindsym XF86AudioNext        exec --no-startup-id playerctl next
bindsym XF86AudioPrev        exec --no-startup-id playerctl previous
bindsym XF86MonBrightnessUp  exec --no-startup-id brightnessctl set +5%
bindsym XF86MonBrightnessDown exec --no-startup-id brightnessctl set 5%-

# --- Status bar ------------------------------------------------------------
bar {
    status_command i3status --config "$HOME/.config/i3status/config"
    position top
    mode hide
    modifier $mod
    workspace_buttons yes
    strip_workspace_numbers no
    tray_output primary
    fonts {
        font pango:DejaVu Sans Mono, FontAwesome 10
    }
    colors {
        background #1d1f21
        statusline #c5c8c6
        separator  #373b41
        focused_workspace  #1d1f21 #285577 #ffffff
        active_workspace   #1d1f21 #333333 #ffffff
        inactive_workspace #1d1f21 #1d1f21 #888888
        urgent_workspace   #1d1f21 #900000 #ffffff
        binding_mode       #1d1f21 #900000 #ffffff
    }
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

write_picom_config() {
    local dest="$1"
    cat > "$dest" <<'PICOM'
# Minimal picom compositor config  ·  ~/.config/picom/picom.conf
backend = "glx";
vsync = true;

shadow = true;
shadow-radius = 12;
shadow-opacity = 0.40;
shadow-offset-x = -12;
shadow-offset-y = -12;

fading = true;
fade-in-step = 0.03;
fade-out-step = 0.06;

inactive-opacity = 0.95;
frame-opacity = 1.0;

# Ignore shadows on these (adjust as you like)
shadow-exclude = [
    "class_g = 'i3-frame'",
    "class_g = 'slop'",
    "_NET_WM_STATE@:32a *= '_NET_WM_STATE_HIDDEN'"
];
PICOM
}

write_screenshot_script() {
    local dest="$1"
    cat > "$dest" <<'SCREENSHOT'
#!/usr/bin/env bash
# Screenshot helper  ·  ~/.config/i3/screenshot.sh
# Usage: screenshot.sh          -> full screen
#        screenshot.sh select   -> interactive region
set -euo pipefail

dir="$HOME/Pictures/Screenshots"
mkdir -p "$dir"
file="$dir/$(date +%F-%H%M%S).png"

if [[ "${1:-}" == "select" ]]; then
    maim -s "$file"
else
    maim "$file"
fi

if command -v notify-send >/dev/null 2>&1; then
    notify-send -i camera "Screenshot saved" "$file"
fi
SCREENSHOT
    chmod +x "$dest"
}

write_xinitrc() {
    local dest="$1"
    cat > "$dest" <<'XINITRC'
#!/bin/sh
# ~/.xinitrc  — used when starting a session with `startx`.
# Applies your keyboard preferences, then launches i3.

setxkbmap -option "caps:swapescape,altwin:swap_alt_win"

# Load X resources / merge any existing ones
[ -f "$HOME/.Xresources" ] && xrdb -merge "$HOME/.Xresources"

# --- Session quality-of-life (tray bits are also launched from the i3 config)
if command -v xset >/dev/null 2>&1; then
    xset -dpms s off   # keep the DPMS/blanking policy out of the way
fi

exec i3
XINITRC
    chmod +x "$dest"
}

# ---------------------------------------------------------------------------
#  EMIT-ONLY mode: just write the canonical config files into a directory
# ---------------------------------------------------------------------------
if [[ ${EMIT_ONLY} -eq 1 ]]; then
    mkdir -p "$EMIT_DIR"
    write_i3_config        "$EMIT_DIR/config"
    write_i3status_config  "$EMIT_DIR/i3status.conf"
    write_picom_config     "$EMIT_DIR/picom.conf"
    write_screenshot_script "$EMIT_DIR/screenshot.sh"
    write_xinitrc          "$EMIT_DIR/xinitrc"
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
    warn "Current session is Wayland. i3 is X11-only — log out and pick an 'i3' (X11) session."
fi

# ---------------------------------------------------------------------------
#  Package installation
# ---------------------------------------------------------------------------
PKGS=(
    # --- window manager core ---
    i3-wm i3status i3lock
    # --- session / X utilities ---
    xinit x11-xserver-utils x11-xkb-utils xdg-utils dbus-x11
    # --- launcher / terminal ---
    # (xterm + rxvt-unicode: simple terminals without kitty keyboard protocol)
    suckless-tools rofi xterm rxvt-unicode
    # --- status-bar plumbing ---
    network-manager-gnome blueman pasystray
    pulseaudio-utils pavucontrol playerctl
    # --- desktop niceties ---
    dunst libnotify-bin feh picom
    brightnessctl xss-lock lxpolkit gnome-keyring
    # --- screenshots / clipboard ---
    maim xclip
    # --- fonts / theming ---
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
            warn "Install it your way (snap, Mozilla repo, flatpak) — the Meta+b"
            warn "binding just runs 'firefox', or edit 'set \$browser' in the i3 config."
        fi
    fi
else
    log "Skipping package installation (--no-install)."
fi

# ---------------------------------------------------------------------------
#  Write user config files (with backups)
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
mkdir -p "$TARGET_HOME/.config/i3" \
         "$TARGET_HOME/.config/i3status" \
         "$TARGET_HOME/.config/picom"

backup_if_exists "$TARGET_HOME/.config/i3/config"
backup_if_exists "$TARGET_HOME/.config/i3status/config"
backup_if_exists "$TARGET_HOME/.config/picom/picom.conf"
backup_if_exists "$TARGET_HOME/.xinitrc"

write_i3_config         "$TARGET_HOME/.config/i3/config"
write_i3status_config   "$TARGET_HOME/.config/i3status/config"
write_picom_config      "$TARGET_HOME/.config/picom/picom.conf"
write_screenshot_script "$TARGET_HOME/.config/i3/screenshot.sh"
write_xinitrc           "$TARGET_HOME/.xinitrc"

# Fix ownership if we were invoked with sudo
if [[ ${EUID} -eq 0 && "$TARGET_USER" != "root" ]]; then
    chown -R "$TARGET_USER":"$TARGET_USER" "$TARGET_HOME/.config" "$TARGET_HOME/.xinitrc" 2>/dev/null || true
fi

# ---------------------------------------------------------------------------
#  Optional: persist the keymap system-wide (so the login greeter matches too)
# ---------------------------------------------------------------------------
if [[ ${PERSISTENT_KEYS} -eq 1 ]]; then
    log "Writing system-wide keyboard config (/etc/X11/xorg.conf.d/00-keyboard.conf)…"
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
    warn "Persistent keymap written. A full log out / reboot is needed to take effect everywhere."
fi

# ---------------------------------------------------------------------------
#  Done
# ---------------------------------------------------------------------------
cat <<EOF

=============================================================================
  i3 setup complete for user '$TARGET_USER'.
=============================================================================

  Files written:
    ~/.config/i3/config              (main i3 config)
    ~/.config/i3status/config        (status bar)
    ~/.config/i3/screenshot.sh       (Print / \$mod+Print)
    ~/.config/picom/picom.conf       (compositor)
    ~/.xinitrc                       (for 'startx' from a TTY)

  Keyboard, as requested:
    Caps Lock  <->  Escape
    Physical Alt  -> Super (Mod4)  == your i3 \$mod key
    Physical Win  -> Alt   (Mod1)

  Next steps:
    1. Log out, then pick the "i3" session at the login screen
       (gear/cog icon on GDM -> "i3").
       - or, from a TTY with no display manager running:  startx
    2. Verify the remap inside the session:
           setxkbmap -print | grep -o 'caps:swapescape,altwin:swap_alt_win'
           xev   # press Caps/Esc/Alt/Win and inspect keysyms
    3. Start working:  \$mod+Return = terminal,  \$mod+d = launcher.

  Hint: run with --persistent-keys to also remap keys at the greeter.
=============================================================================
EOF
