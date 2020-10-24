# Make a dummy function to be able to have local variables.
__dummy_func() {
    test -z "$QUIET" && echo -e 'Make sure you run this script using `source ...`.\nAdd `QUIET=1` to hide this message.\n'

    # Helper variable pointing to the msys2_pacmake installation directory.
    local installation_path="$(realpath "$(dirname "$BASH_SOURCE")"/..)"
    # Make sure the resulting variable is not empty due to some error. If it is, abort.
    test -z "$installation_path" && return


    # This MSYS2-style variable points to the MinGW installation path, i.e. `root/mingw64`.
    if test -z "$MSYSTEM_PREFIX"; then
        # `MSYSTEM_PREFIX` not set, determine automatically.
        if test "$(readlink /mingw64)" = "$installation_path/root/mingw64"; then
            echo 'Found symlink `/mingw64` -> `'"$installation_path/root/mingw64"'`, will use it.'
            export "MSYSTEM_PREFIX=/mingw64"
        else
            echo 'WARNING: Didn'"'"'t find symlink `/mingw64` -> `'"$installation_path/root/mingw64"'`.'
            echo 'Pkg-config (and possibly something else) will not work properly.'
            echo 'Consider creating the symlink with:'
            echo '    sudo ln -s "'"$installation_path/root/mingw64"'" /mingw64'
            export "MSYSTEM_PREFIX=$installation_path/root/mingw64"
        fi
    fi
    echo "MSYSTEM_PREFIX = $MSYSTEM_PREFIX"

    # This MSYS2-style variable specifies the target triplet.
    test -z "$MINGW_CHOST" && export "MINGW_CHOST=x86_64-w64-mingw32"
    echo "MINGW_CHOST = $MINGW_CHOST"


    # Select a compiler.
    if test "$MINGW_CC" || test "$MINGW_CXX"; then
        # A custom compiler is specified, use it.
        export "CC=$MINGW_CC"
        export "CXX=$MINGW_CXX"
    else
        # No custom compiler is specified, try to guess.
        echo -e '\nGuessing a compiler... To override, set `MINGW_CC` and `MINGW_CXX` and restart.'

        # First, try the native Clang.
        echo "Trying native Clang..."
        if test -z "$WIN_CLANG_VER"; then
            export "WIN_CLANG_VER=11"
            echo '    Assuming your native Clang is suffixed with `'"-$WIN_CLANG_VER"'`.'
            echo '    If it'"'"'s not the case, set `WIN_CLANG_VER` to the correct version,'
            echo '    or to `NONE` if your Clang is not suffixed with a version.'
        fi
        if test "$WIN_CLANG_VER" = "NONE"; then
            # Those variables are used by our Clang wrapper in `env/wrappers`.
            export "WIN_NATIVE_CLANG_CC=clang"
            export "WIN_NATIVE_CLANG_CXX=clang++"
        else
            # Those variables are used by our Clang wrapper in `env/wrappers`.
            export "WIN_NATIVE_CLANG_CC=clang-$WIN_CLANG_VER"
            export "WIN_NATIVE_CLANG_CXX=clang++-$WIN_CLANG_VER"
        fi

        if which "$WIN_NATIVE_CLANG_CC" "$WIN_NATIVE_CLANG_CXX" >/dev/null; then
            # Successfully found a native Clang.
            echo "Success! Will use wrappers around the native Clang."
            export "CC=win-clang"
            export "CXX=win-clang++"

            # Warn if MSYS2 GCC is not installed.
            if test ! -f "$MSYSTEM_PREFIX/bin/gcc.exe" || test ! -f "$MSYSTEM_PREFIX/bin/g++.exe"; then
                echo "WARNING: Couldn't find the MSYS2 GCC. It has to be installed for the native Clang to be able to cross-compile."
            fi

            # If MSYS2 Clang is installed, switch to absolute paths and warn.
            if test -f "$MSYSTEM_PREFIX/bin/clang.exe" || test -f "$MSYSTEM_PREFIX/bin/clang++.exe"; then
                echo "To avoid conflicts with the MSYS2 Clang, absolute paths will be used."
                export "WIN_NATIVE_CLANG_CC=$(which $WIN_NATIVE_CLANG_CC)"
                export "WIN_NATIVE_CLANG_CXX=$(which $WIN_NATIVE_CLANG_CXX)"
            fi

            echo "WIN_NATIVE_CLANG_CC = $WIN_NATIVE_CLANG_CC"
            echo "WIN_NATIVE_CLANG_CXX = $WIN_NATIVE_CLANG_CXX"

            # This custom variable specifies the flags for our Clang wrapper in `env/wrappers`.
            # Note that the target is different from the value of `MINGW_CHOST`. That's slightly weird but that's what MSYS2 does, so...
            # `--sysroot` tells Clang where to look for a GCC installation.
            # `-pthread` tells is to link winpthread, since it doesn't happen automatically and some CMake scripts expect it.
            # `-femulated-tls` is necessary when using libstdc++ atomics with Clang.
            test -z "$WIN_CLANG_FLAGS" && export "WIN_CLANG_FLAGS=--target=x86_64-w64-windows-gnu --sysroot=$MSYSTEM_PREFIX -pthread -femulated-tls"
            echo "WIN_CLANG_FLAGS = $WIN_CLANG_FLAGS"
        else
            # Couldn't find a native Clang.
            unset WIN_NATIVE_CLANG_CC
            unset WIN_NATIVE_CLANG_CXX
            echo "Fail."

            # Now try the MSYS2 Clang.
            echo "Trying MSYS2 Clang... (not recommended)"
            if test -f "$MSYSTEM_PREFIX/bin/clang.exe" && test -f "$MSYSTEM_PREFIX/bin/clang++.exe"; then
                # Successfully found the MSYS2 Clang.
                echo "Success."
                echo "But consider using the native Clang instead, it should be faster."
                export "CC=clang"
                export "CXX=clang++"
            else
                # Couldn't find the MSYS2 Clang.
                echo "Fail."

                # Now try the MSYS2 GCC.
                echo "Trying MSYS2 GCC..."
                if test -f "$MSYSTEM_PREFIX/bin/gcc.exe" && test -f "$MSYSTEM_PREFIX/bin/g++.exe"; then
                    echo "Success."
                    export "CC=gcc"
                    export "CXX=g++"
                else
                    echo "Fail."
                    echo "Couldn't find any suitable compiler."
                fi
            fi
        fi
    fi

    # Print the compiler we ended up with.
    echo "CC = $CC"
    echo "CXX = $CXX"
    echo ''


    # Wine will look for executables in this directory.
    export "WINEPATH=$MSYSTEM_PREFIX/bin"
    echo "WINEPATH = $WINEPATH"
    which wine >/dev/null || echo "WARNING: Can't find Wine. If you want to run native executables, it has to be installed."

    # Autotools will read config from that file.
    export "CONFIG_SITE=$installation_path/env/config/config.site"
    echo "CONFIG_SITE = $CONFIG_SITE"

    # Pkg-config will look for packages in this directory. The value is taken from MSYS2.
    # Note that we use the hardcoded path instead of `$MSYSTEM_PREFIX`, because the thing wouldn't work without the `/mingw64` anyway,
    # because the `.pc` files have hardcoded paths in them.
    export "PKG_CONFIG_PATH=/mingw64/lib/pkgconfig:/mingw64/share/pkgconfig"
    echo "PKG_CONFIG_PATH = $PKG_CONFIG_PATH"

    # Check if MSYS2 CMake is installed. Warn if it is, because it doesn't work properly under Wine.
    test -f "$MSYSTEM_PREFIX/bin/cmake.exe" && echo -e 'WARNING: MSYS2 CMake is installed. It won'"'"'t function properly,\nget rid of it and use the `win-cmake` wrapper that calls the native CMake.'
    # This variable is used by our wrapper in `env/wrappers`. We use an absolute path
    # to avoid collisions with MSYS2 CMake if it's installed for some reason.
    export "WIN_NATIVE_CMAKE=$(which cmake)"
    echo "WIN_NATIVE_CMAKE = $WIN_NATIVE_CMAKE"
    # This variable is also used by our wrapper in `env/wrappers`, and contains the extra CMake flags.
    export "WIN_CMAKE_FLAGS=-DCMAKE_TOOLCHAIN_FILE=$installation_path/env/config/toolchain.cmake -DCMAKE_INSTALL_PREFIX=$MSYSTEM_PREFIX"
    echo "WIN_CMAKE_FLAGS = $WIN_CMAKE_FLAGS"

    echo ''

    # Update the PATH.
    local new_path="$(make -f "$(dirname "$BASH_SOURCE")/internal/AddToPath.mk" "dirs=$installation_path/env/wrappers:$installation_path/env/fake_bin:$WINEPATH")"
    test -z "$new_path" && return
    export "PATH=$new_path"
    echo "PATH = $PATH"

    # We don't use the following variables, but sill define them for some extra compatibility with MSYS2.
    # The list of variables was obtained by running `printenv` on MSYS2 and manually sorting through the list.
    # Note that some useful MSYS2-style variables (that are actually useful) are defined above and not there, comments near them indicate that.
    echo ''
    echo 'Extra MSYS2 mimicry:'
    export "OS=Windows_NT"; echo -n "OS = $OS; "
    export "MSYSTEM_CARCH=x86_64"; echo -n "MSYSTEM_CARCH = $MSYSTEM_CARCH; "
    export "MSYSTEM_CHOST=$MINGW_CHOST"; echo -n "MSYSTEM_CHOST = $MSYSTEM_CHOST; "
    export "MSYSTEM=MINGW64"; echo -n "MSYSTEM = $MSYSTEM; "
    # Finally, copy the MSYS2 prompt.
    export 'PS1=\[\e]0;\w\a\]\n\[\e[32m\]\u@\h \[\e[35m\]$MSYSTEM\[\e[0m\] \[\e[33m\]\w\[\e[0m\]\n\[\e[1m\]#\[\e[0m\] '; echo "PS1 = ..."
}
# Call our dummy funcion.
__dummy_func
# Delete the function.
unset -f __dummy_func
