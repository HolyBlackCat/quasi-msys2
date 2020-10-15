# Make a dummy function to be able to have local variables.
__dummy_func() {
    echo 'Make sure you run this script using `source ...`.'

    local new_winepath="$(realpath "$(dirname "$BASH_SOURCE")"/../root/mingw64/bin)"
    # Make sure the resulting variable is not empty due to some error. If it is, abort.
    test -z "$new_winepath" && return
    export "WINEPATH=$new_winepath"
    echo 'Your WINEPATH is now equal to `'"$WINEPATH"'`.'

    local new_path="$(make -f "$(dirname "$BASH_SOURCE")/helpers/AddToPath.mk" "dir=$WINEPATH")"
    # Make sure the resulting variable is not empty due to some error. If it is, abort.
    test -z "$new_path" && return
    export "PATH=$new_path"
    echo 'Your PATH is now equal to `'"$PATH"'`.'
}
# Call our dummy funcion.
__dummy_func
# Delete the function.
unset -f __dummy_func
