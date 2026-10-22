# bash-completion itself is loaded via /etc/bashrc -> /etc/profile.d/bash_completion.sh.
if command -v herdr >/dev/null 2>&1; then
  eval "$(herdr completion bash 2>/dev/null)"
fi

if [ -x "$HOME/.local/bin/mise" ]; then
  eval "$("$HOME/.local/bin/mise" completion bash 2>/dev/null)"
fi

if [ -x "$HOME/.opencode/bin/opencode" ]; then
  eval "$("$HOME/.opencode/bin/opencode" --completions bash 2>/dev/null)"
elif command -v opencode >/dev/null 2>&1; then
  eval "$(opencode --completions bash 2>/dev/null)"
fi
