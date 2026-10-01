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
