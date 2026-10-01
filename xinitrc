#!/bin/sh
# ~/.xinitrc  — used when starting a session with `startx`.

# Apply the keyboard preferences (Caps<->Esc, Alt<->Win).
setxkbmap -option "caps:swapescape,altwin:swap_alt_win"

# Merge X resources if present.
[ -f "$HOME/.Xresources" ] && xrdb -merge "$HOME/.Xresources"

exec i3
