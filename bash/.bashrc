# ~/.bashrc — Fedora stock default + personal dotfiles layer.
#
# Complement, don't replace: source the distro default first (the exact file
# useradd/adduser copies into a new home), then apply personal overrides and
# additions from ~/.config/bashrc.d/ on top of it.
case $- in *i*) ;; *) return;; esac

# Stock Fedora behavior as the base: /etc/bashrc (prompt, checkwinsize) and
# through it /etc/profile.d/* (ls/ll/grep color aliases, less, bash-completion,
# VTE title), ~/.local/bin on PATH, and any ~/.bashrc.d/* snippets.
# Sourced (not copied) so it tracks bash/setup package updates.
[ -r /etc/skel/.bashrc ] && . /etc/skel/.bashrc

# Personal layer. Load order matters: path/mise before completion.
for f in path options history completion aliases functions prompt; do
  [ -f "$HOME/.config/bashrc.d/${f}.bash" ] && . "$HOME/.config/bashrc.d/${f}.bash"
done
unset f
