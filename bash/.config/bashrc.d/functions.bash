# Stage everything, commit, push. gpk also deploys, but only after a
# successful push.
function gp() {
  if [ $# -ne 2 ]; then
    echo "usage: gp <message> <branch>" >&2
    return 2
  fi
  git add . && git commit -m "$1" && git push origin "$2"
}

function gpk() {
  gp "$@" && bin/kamal deploy
}

# Yolo runs are always sandboxed: Bash runs under bubblewrap with no
# unsandboxed fallback (refuses to start if the sandbox is unavailable), and
# deny rules keep both Bash and the file tools out of credential stores. Deny
# rules hold even under --dangerously-skip-permissions.
_CLAUDE_YOLO_SETTINGS='{
  "sandbox": {
    "enabled": true,
    "allowUnsandboxedCommands": false,
    "failIfUnavailable": true,
    "filesystem": {
      "denyRead": ["~/.ssh", "~/.gnupg", "~/.config/gh", "~/.config/google-chrome", "~/.config/Bitwarden", "~/.aws", "~/.kube", "~/.docker"]
    }
  },
  "permissions": {
    "deny": [
      "Read(~/.ssh/**)", "Read(~/.gnupg/**)", "Read(~/.config/gh/**)",
      "Read(~/.config/google-chrome/**)", "Read(~/.config/Bitwarden/**)",
      "Read(~/.aws/**)", "Read(~/.kube/**)", "Read(~/.docker/**)"
    ]
  }
}'

_claude() {
  local dir="$HOME/.claude-$1"; shift
  if [[ ${1:-} == --yolo ]]; then
    shift
    read -r -p "Run claude with --dangerously-skip-permissions (sandboxed)? [y/N] " ans
    [[ $ans == [yY] ]] || return 1
    CLAUDE_CONFIG_DIR="$dir" claude --settings "$_CLAUDE_YOLO_SETTINGS" --dangerously-skip-permissions "$@"
  else
    CLAUDE_CONFIG_DIR="$dir" claude "$@"
  fi
}

claude-brem()       { _claude brem "$@"; }
claude-lumin()      { _claude lumin "$@"; }
claude-brem-yolo()  { _claude brem --yolo "$@"; }
claude-lumin-yolo() { _claude lumin --yolo "$@"; }
