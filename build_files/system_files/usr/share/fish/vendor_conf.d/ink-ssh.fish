# the user's ssh-agent (socket activated); a session that already has an agent keeps it
if not set -q SSH_AUTH_SOCK; and set -q XDG_RUNTIME_DIR
    set -gx SSH_AUTH_SOCK $XDG_RUNTIME_DIR/ssh-agent.socket
end
