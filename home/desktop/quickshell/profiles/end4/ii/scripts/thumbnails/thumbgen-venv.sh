#!/nix/store/4bwbk4an4bx7cb8xwffghvjjyfyl7m2i-bash-interactive-5.3p9/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source $(eval echo $ILLOGICAL_IMPULSE_VIRTUAL_ENV)/bin/activate
GIO_USE_VFS=local "$SCRIPT_DIR/thumbgen.py" "$@"
THUMBGEN_EXIT_CODE=$?
deactivate

exit $THUMBGEN_EXIT_CODE
