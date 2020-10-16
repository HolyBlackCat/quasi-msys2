# Make a dummy function to be able to have local variables.
__dummy_func() {
    test -z "$QUIET" && echo -e 'Make sure you run this script using `source ...`.\nAdd `QUIET=1` to hide this message.\n'

    # Helper variable pointing to the msys2_pacmake installation directory.
    local installation_path="$(realpath "$(dirname "$BASH_SOURCE")"/..)"
    # Make sure the resulting variable is not empty due to some error. If it is, abort.
    test -z "$installation_path" && return

    # This points to the MinGW installation path, i.e. `root/mingw64`.
    export "MINGW_ROOT=$installation_path/root/mingw64"
    echo 'Set MINGW_ROOT to `'"$MINGW_ROOT"'`.'

    # Those are flags for our Clang wrapper in `env/wrappers`.
    export "WIN_CLANG_FLAGS=--target=x86_64-w64-windows-gnu --sysroot=$MINGW_ROOT"
    echo 'Set WIN_CLANG_FLAGS to `'"$WIN_CLANG_FLAGS"'`.'
    echo 'If your native Clang is suffixed with a version, manually set WIN_CLANG_SUFFIX to the version, e.g. `-11`.'

    # Wine will look for executables in this directory.
    export "WINEPATH=$MINGW_ROOT/bin"
    echo 'Set WINEPATH to `'"$WINEPATH"'`.'

    # Update the PATH.
    local new_path="$(make -f "$(dirname "$BASH_SOURCE")/internal/AddToPath.mk" "dirs=$installation_path/env/wrappers:$installation_path/env/fake_bin:$WINEPATH")"
    test -z "$new_path" && return
    export "PATH=$new_path"
    echo 'Your PATH is now equal to `'"$PATH"'`.'
}
# Call our dummy funcion.
__dummy_func
# Delete the function.
unset -f __dummy_func
