# Without starship, the stock Fedora /etc/bashrc prompt stays in place.
if command -v starship >/dev/null 2>&1; then
  # Starship prompt (git branch/dirty, exit status, runtimes). Installed by
  # setup/dev/tools.sh; config comes from ~/.config/starship.toml defaults.
  eval "$(starship init bash)"
  # starship's init resets PROMPT_COMMAND; keep the per-command history append
  # from history.bash alive (it is silently dropped otherwise).
  [[ ${PROMPT_COMMAND:-} == *"history -a"* ]] || PROMPT_COMMAND="history -a${PROMPT_COMMAND:+; $PROMPT_COMMAND}"
fi
