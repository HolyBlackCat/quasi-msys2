# Make a dummy function to be able to have local variables.
__dummy_func() {
    echo 'Make sure you run this script using `source ...`.'

    local installation_path="$(realpath "$(dirname "$BASH_SOURCE")"/..)"
    # Make sure the resulting variable is not empty due to some error. If it is, abort.
    test -z "$installation_path" && return
    export "MINGW_ROOT=$installation_path/root/mingw64"
    echo 'Set MINGW_ROOT to `'"$MINGW_ROOT"'`.'

    export "WINEPATH=$MINGW_ROOT/bin"
    echo 'Set WINEPATH to `'"$WINEPATH"'`.'

    local new_path="$(make -f "$(dirname "$BASH_SOURCE")/helpers/AddToPath.mk" "dirs=$installation_path/fake_bin:$WINEPATH")"
    test -z "$new_path" && return
    export "PATH=$new_path"
    echo 'Your PATH is now equal to `'"$PATH"'`.'
}
# Call our dummy funcion.
__dummy_func
# Delete the function.
unset -f __dummy_func
