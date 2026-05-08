#!/nix/store/4bwbk4an4bx7cb8xwffghvjjyfyl7m2i-bash-interactive-5.3p9/bin/bash
locked_state=$(busctl --user get-property org.freedesktop.secrets \
    /org/freedesktop/secrets/collection/login \
    org.freedesktop.Secret.Collection Locked)
if [[ "${locked_state}" == "b false" ]]; then
    echo 'Keyring is unlocked' >&2
    exit 0
else
    echo 'Keyring is locked' >&2
    exit 1
fi
