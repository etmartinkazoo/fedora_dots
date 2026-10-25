# Prepend only once, so nested shells don't grow duplicate PATH entries
# (Fedora's stock /etc/skel/.bashrc already adds ~/.local/bin).
# ~/bin holds the profile launchers written by setup/profiles.sh.
for d in "$HOME/.opencode/bin" "$HOME/.local/bin" "$HOME/bin"; do
  case ":$PATH:" in *":$d:"*) ;; *) PATH="$d:$PATH" ;; esac
done
unset d
export PATH

if [ -x "$HOME/.local/bin/mise" ]; then
  eval "$("$HOME/.local/bin/mise" activate bash)"
fi
