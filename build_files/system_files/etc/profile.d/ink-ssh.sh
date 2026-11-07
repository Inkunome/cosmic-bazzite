# the user's ssh-agent (socket activated); a session that already has an agent keeps it
[ -n "$SSH_AUTH_SOCK" ] || { [ -n "$XDG_RUNTIME_DIR" ] && export SSH_AUTH_SOCK="$XDG_RUNTIME_DIR/ssh-agent.socket"; }
