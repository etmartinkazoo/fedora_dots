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
      "denyRead": ["~/.ssh", "~/.gnupg", "~/.config/gh", "~/.config/google-chrome", "~/.config/Bitwarden", "~/.aws", "~/.kube", "~/.docker", "~/Profiles/personal/.ssh", "~/Profiles/consultancy/.ssh", "~/Profiles/brem/.ssh", "~/Profiles/lumin/.ssh", "~/Profiles/personal/Mail", "~/Profiles/consultancy/Mail", "~/Profiles/brem/Mail", "~/Profiles/lumin/Mail", "~/Profiles/personal/.config/neomutt", "~/Profiles/consultancy/.config/neomutt", "~/Profiles/brem/.config/neomutt", "~/Profiles/lumin/.config/neomutt"]
    }
  },
  "permissions": {
    "deny": [
      "Read(~/.ssh/**)", "Read(~/.gnupg/**)", "Read(~/.config/gh/**)",
      "Read(~/.config/google-chrome/**)", "Read(~/.config/Bitwarden/**)",
      "Read(~/.aws/**)", "Read(~/.kube/**)", "Read(~/.docker/**)",
      "Read(~/Profiles/personal/.ssh/**)", "Read(~/Profiles/consultancy/.ssh/**)",
      "Read(~/Profiles/brem/.ssh/**)", "Read(~/Profiles/lumin/.ssh/**)",
      "Read(~/Profiles/personal/Mail/**)", "Read(~/Profiles/consultancy/Mail/**)",
      "Read(~/Profiles/brem/Mail/**)", "Read(~/Profiles/lumin/Mail/**)",
      "Read(~/Profiles/personal/.config/neomutt/**)", "Read(~/Profiles/consultancy/.config/neomutt/**)",
      "Read(~/Profiles/brem/.config/neomutt/**)", "Read(~/Profiles/lumin/.config/neomutt/**)"
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
