## quasi-msys2

A Linux-to-Windows cross-compilation environment. Imitates [MSYS2](https://www.msys2.org/) (which is Windows-only) on Linux.

Features:

* [Huge amount of prebuilt libraries](https://packages.msys2.org/package/), and [several MinGW flavors](https://www.msys2.org/docs/environments/) (all of this comes from the MSYS2 project).
* Provides environment very similar to MSYS2 you'd have on Windows. If your code builds on MSYS2, it should build on Quasi-MSYS2 as is, and vice versa.
* Linux-distribution-agnostic.
* The installation is self-contained.

Here's how it works:

* MinGW-based packages (compilers, libraries, etc) are downloaded from the MSYS2 repos.
* Cygwin-based packages are not available (since Cygwin doesn't work well under Wine, if at all), but their native equivalents should be enough.
* `pacman` is replaced with a small custom package manager (since `pacman` itself is Cygwin-based).
* Optionally, [`binfmt_misc`](https://en.wikipedia.org/wiki/Binfmt_misc) allows Windows executables to be transparently invoked via Wine, and we convince CMake and Autotools that we're doing a native Windows build.

## Usage

* Install dependencies:

  On Ubuntu: `sudo apt install make wget tar zstd gpg wine`. Wine is optional but recommended. `make --version` must be 4.3 or newer.

  Must also install `clang` and `lld`. Ubuntu users should use `bash -c "$(wget -O - https://apt.llvm.org/llvm.sh)"` to get the latest version. On other distributions just install from the package manager as usual.

  <sup>(While it's technically possible to operate without Clang, by running MSYS2 compilers in Wine, the build systems often choke on this.)</sup>

* Install quasi-msys2:
  ```bash
  git clone https://github.com/holyblackcat/quasi-msys2
  cd quasi-msys2
  make install _gcc _gdb # same as `make install mingw-w64-ucrt-x86_64-gcc mingw-w64-ucrt-x86_64-gdb`
  ```
  For selecting MSYS2 compiler flavor, [see FAQ](#how-do-i-use-different-msys2-environments).
* Open quasi-msys2 shell:
  ```bash
  env/shell.sh
  ```
  This adds MSYS2 packages to `PATH`, and sets some environment variables. For non-interactive use, see [this](#how-do-i-run-commands-non-interactively).

* Build:
  * Manually:
    ```bash
    win-clang++ 1.cpp # Calls your Clang with the right flags for cross-compilation.
    ./a.exe # Works if you installed Wine.
    ```
    You can also use `g++` and `clang++` to run the respective MSYS2 compilers in Wine, assuming you installed `_gcc` and `_clang` respectively.
  * With Autotools: just `./configure && make`, no extra configuration is needed.
  * With CMake: just run `cmake` as usual, no extra configuration is needed.

  Both CMake and Autotools will think they perform a native Windows build, thanks to [`binfmt_misc`](https://en.wikipedia.org/wiki/Binfmt_misc), which transparently calls Wine to run Windows executables.

* Other tools that work in `env/shell.sh`:
  * `pkgconf` (and `pkg-config`)
  * `win-gdb` (replaces `gdb`; which has problems with interactive input when used with Wine directly)
  * `win-ldd` (replaces `ntldd -R`; lists the `.dll`s an executable depends on).

### Rust

We also support Rust for completeness.

You don't need any extra MSYS2 packages (other than `make install _gcc` for the libraries). Install `rustup` on the host and run `rustup target add $CARGO_BUILD_TARGET` inside `env/shell.sh` to install the standard library for the target platform.

Then you can use:

* `win-rustc` to compile a single file (this wrapper calls `/usr/bin/rustc` with flags for cross-compilation).
* `cargo` (we set environment variables to make it cross-compile by default).

## Package manager usage

Run `make help` to get the full list of commands it supports.

Here are some common ones:

* `make list-all` - List all packages available in the repository.<br>
  This command will only download the repository database on the first run. Updating the database is explained below.

  Use `make list-all | grep <package>` to search for packages.

* `make install <packages>` - Install packages.<br>
  The packages are installed to the `./root/`.

  <sup>Most package names share a common prefix: `mingw-w64-ucrt-x86_64-gcc mingw-w64-ucrt-x86_64-clang ...`. You can use `_` instead of this long prefix, e.g. `make install _gcc` instead of `make install mingw-w64-ucrt-x86_64-gcc`.</sup>

* `make remove <packages>` - Remove packages.

* `make upgrade` - Download the latest package database and install package updates.<br>
  Do this routinely to keep your installation up to date.

  The last update can be rolled back using `make rollback`.

* `make list-ins` - List all installed packages.

* `make list-req` - List only those installed packages that were explicitly requested, rather than being automatically installed as a dependency.

* `make apply-delta` - Resume interrupted package installation/removal.

* `make reinstall-all` - Reinstall all packages, if you screwed up your installation.

* Previewing changes before applying them:

  Normally the packages are installed immediately without asking. If you want to check what will be installed first, you can do following:

  * Instead of `make upgrade`, do `make update` and `make delta` to list the changes. Then `make apply-delta` to apply.

  * Instead of `make install ...`, do `make request ...` and `make delta` to list the changes. Then `make apply-delta` to apply or `make undo-request ...` to back out.

  * Instead of `make remove ...`, do `make undo-request ...` and `make delta` to list the changes. Then `make apply-delta` to apply or `make request ...` to back out.

**Known issues**

* Pre/post-install actions are not executed; we simply unpack the package archives. In most cases this is good enough.

* If a package depends on a specific version of some other package, the exact version of that package is not checked. This shouldn't affect you, as long as you don't manually install outdated packages.

* Package conflicts are handled in a crude manner. Information about package conflits provided in the package database is ignored, but if you try to install a package providing a file that already exists, the installation will fail. In most cases this is good enough.

* You can't run several instances of the package manager in the same installation in parallel. There's no locking mechanism, so this can cause weird errors.

## Backing up the installation

The whole installation directory can be moved around, it doesn't contain any absolute paths.

But you don't need to copy everything if you're making a backup, assuming all files came from the package manager. You only need a clean copy of the repository, and following files:

* `database.mk` — The package database.
* `requested_packages.txt` — The list of packages you've explicitly installed.
* Contents of the `cache/` directory, which contains archived versions of all installed packages. Before backing up the cache, make sure it's up-to-date and minimal by running `make cache-installed-only`.
* User config files: `msystem.txt`, `alternatives.txt` (if present).

To restore such backup to a working state, run `make apply-delta` in it.

## Not-so-frequently asked questions

### How do I run commands non-interactively?

`env/shell.sh` works best for interactive use.

If you want to run commands non-interactively (as in from shell scripts), do this:

```sh
bash -c 'source env/all.src && my_command'
```

If you don't want certain components of the environment, you can study `all.src` and run desired components manually. (E.g. if you don't want `binfmt_misc`.)

### How do I use different [MSYS2 environments](https://www.msys2.org/docs/environments/)?

The environment can be changed using `echo DesiredEnvName >msystem.txt`, preferably in a clean repository. If you want multiple environments, you need multiple copies of Quasi-MSYS2.

All environments should work, more or less. (Except for `MSYS`, which I'm not particulary interested in, since Cygwin doesn't seem to work with Wine. Also `CLANGARM64` wasn't tested at all.)

On `CLANG64` and `CLANG32`, when using the native Clang, it's strongly recommended to install the same native Clang version as the one used by MSYS2 (at least the same major version, different minor versions seem to be compatible?). On those, installing or updating MSYS2 Clang requires a shell restart for the native Clang to work correctly.

### How do I add a desktop entry for the quasi-msys2 shell?

Use `make -f env/integration.mk`. To undo, invoke it again with the `uninstall` flag.

### Using LD instead of LLD when compiling with the native Clang.

I started having problems with the native LD after some MSYS2 update (it produces broken executables), so we default to LLD.

Last tested on LD 2.34, a more recent version might work.

LD shipped by MSYS2 (was LD 2.37 last time I checked) works under Wine. If `binfmt_misc` is enabled, you can switch to it using `-fuse-ld=$MSYSTEM_PREFIX/bin/ld.exe`.

You can try the native LD using `-fuse-ld=ld`. (Or remove `-fuse-ld=lld` from `WIN_CLANG_FLAGS` variable.)

### My build system is confused because the compiled C/C++ binaries are suffixed with `.exe`.

Use `source env/duplicate_exe_outputs.src`. Then `$CC` and `$CXX` will output two identical binaries, `foo.exe` and `foo`. The lack of the extension doesn't stop them from being transparently invoked with Wine.


## Installation structure

* `Makefile` — The package manager.

* `root/` — Packages are installed here.

* `index/` — For each installed package it contains a file with a list of files owned by it.

  `root/` and `index/` must always stay in sync, otherwise things will break.

* `cache/` — Stores cached archives of the packages downloaded from the repo.

  Also stores archive signatures. They're checked at download time, and are preserved for informational purposes only.

* `database.mk` — The package database, converted to our own format.

* `database.mk.bak` — A backup of `database.mk` performed the last time a new database was downloaded.

* `database.current_original[.sig]` — The original database file downloaded from the repository. This is used to speed up database updated (if the downloaded database matches this file, we don't need to reparse it).

   The signature is checked at download time, and is preserved for informational purposes only.

* `requested_packages.txt` — A list of installed packages, not including the automatically installed dependencies.

* `alternatives.txt` — Exists only if you created it manually. A configuration file for package alternatives, see `make help` for details.

* `msystem.txt` — Exists only if you created it manually. Configures MSYS2 flavor, see `make help` for details.

* `msys2_pacmake_base_dir` — An empty file marking the installation directory. The package manager refuses to operate if it's not in the working directory, to make sure you don't accidentally create a new installation.

* (temporary) `database.db` — The database downloaded from the repository, in the process of being converted to our custom format.

* (temporary) `database/` — Temporary files created when processing a downloaded database.

* `env/` — Contains the scripts for configuring the build environment. The contents have no connection with the package manager.

  * `binfmt.mk` — Configures the kernel to transparently run Wine programs. It uses `sudo`, so you'll be asked for a `sudo` password.

    Has flags to un-configure the kernel, run it to get more information.

  * `fakebin.mk` — Generates extension-less wrappers for all installed executables, to make running them easier.

    Has a flag to delete all wrappers, run it to get more information.

  * `fake_bin/` — Contains the wrappers generated by `fakebin.mk`

  * `vars.src` — Sets up environment variables, including `PATH`. Must be run as `source path/to/vars.src`.

  * `all.src` — Runs all the files above, in quiet mode. Must be run as `source path/to/all.src`.

  * `shell.sh` — Creates a new Bash shell and runs `source all.src` in it. Do `exit` to return to the original shell.

  * `integration.mk` — Generates a desktop file for the Quasi-MSYS2 shell.

  * `duplicate_exe_outputs.src` — Modifies `CC` and `CXX` variables to point to wrappers that duplicate the produced executables without extensions. This can have with some build systems.

  * `wrappers/` — Wrappers for the native Clang and CMake that add the correct parameters for them.

  * `config/` — Contains configuration files for the build systems.

    * `config.site` — This configures the Autotools. `vars.src` stores a path to it in `CONFIG_SITE`, which Autotools read.

    * `toolchain.cmake` — This configures CMake. Our CMake wrapper passes this file to CMake.

  * `internal/` — Internal helper scripts.
