# Make a dummy function to be able to have local variables.
__dummy_func() {
    echo -e 'Make sure you run this script using `source ...`.'

    # Helper variable pointing to the env scripts directory.
    local env_path="$(realpath "$(dirname "$BASH_SOURCE")")"
    # Make sure the resulting variable is not empty due to some error. If it is, abort.
    test -z "$env_path" && return

    echo -e '\n--- binfmt.mk'
    make -f "$env_path/binfmt.mk" QUIET=1 || return

    echo -e '\n--- fakebin.mk'
    make -f "$env_path/fakebin.mk" QUIET=1 || return

    echo -e '\n--- vars.sh'
    QUIET=1 source "$env_path/vars.sh" || return
}
# Call our dummy funcion.
__dummy_func
# Delete the function.
unset -f __dummy_func
