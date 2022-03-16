## quasi-msys2

A small and easy to use Linux-to-Windows cross-compilation environment, utilizing prebuilt packages from [MSYS2 repos](https://packages.msys2.org/package/).


The goal is to mimic MSYS2, but on Linux.

* MinGW-based packages (compilers, libraries, etc) are downloaded from MSYS2 repos.
* Cygwin-based packages are not available (since Cygwin doesn't work well under Wine, if at all), but their native equivalents should be enough.
* `pacman` is replaced with a tiny custom package manager (since `pacman` itself is Cygwin-based).
* [`binfmt_misc`](https://en.wikipedia.org/wiki/Binfmt_misc) allows Windows executables to be transparently invoked via Wine.
* The environment is set up to trick CMake and Autotools into thinking that they're doing native Windows builds.
* The installation is entirely self-contained. We don't modify any files outside of the installation directory.

## Environments

Quasi-MSYS2 supports different [MSYS2 environments](https://www.msys2.org/docs/environments/). `MINGW64` is the default. [See below](#not-so-frequently-asked-questions) for more details.

## Prerequisites

Mandatory:

* `make`, `wget`, `tar`, `zstd`

Heavily recommended:

* **Clang** and **LLD**, to cross-compile for Windows. You can use MSYS2 GCC and Clang as well (under Wine), but a native Clang is much faster.

* **Wine** to transparently run Windows programs.

## Basic usage

* `make install _gcc _gdb` to install MSYS2 GCC and GDB.<br>
  You're encouraged to routinely run `make upgrade` to update the installed packages.

* `env/shell.sh` to start a sub-shell configured for cross-compiling. Type `exit` to return to the original shell.

  Within such a shell, use `pacmake ...` instead of `make ...` to invoke the package manager.

  First time you start such shell after a reboot, you might be asked for a sudo password to configure the kernel to transparently run `.exe` files. If you don't trust random scripts with your password, you can do it manually, see below.

In such a sub-shell, you can do following:

  * **Invoke any `.exe` files transparently** as if they were native executables. Wine will be used for that.<br>
  <sub>(Actually this will work everywhere, until you reboot or manually tell the kernel to stop doing this, see below.)</sub>

    Even if you opted out of kernel configuration, you can always transparently invoke any programs installed from the packages, without specifying the extension. E.g. `g++` is equivalent to `wine g++.exe`, assuming GCC is installed.

    The installation directory is prepended to `PATH`, so programs from MSYS2 repos take precedence.

  * **Cross-compile to Windows using your native Clang**, using `win-clang` and `win-clang++` wrappers. This is the recommended approach.

    `_gcc` package must be installed, since it provides the standard library for cross-compilation, and more.

  * **Cross-compile to Windows using MSYS2 GCC or Clang** running under Wine. They're much slower than a native Clang, and should normally be used as a fallback.

    You can invoke them using `gcc`, `g++`, `clang`, `clang++` as usual, assuming the corresponding packages are installed.

  * **Cross-compile using Autotools and CMake.**

    Both should work out of the box. `pkg-config` also works.

  * **Debug executables running under Wine.**

    Use the `win-gdb` wrapper. You need to have `_gdb` package installed.

    MSYS2 GDB doesn't interact well with a regular terminal, but runs nicely inside of `wineconsole`. This wrapper starts `wineconsole` automatically. It will open a new terminal window, CMD style.

    Or, to reuse your existing terminal window, start `wine cmd` and run `gdb` inside of it. I've yet to figure out how to combine this into a single convenient command.

  * **Inspect `.dll` dependencies of executables.**

    Use the `win-ldd` wrapper. You need to have `_ntldd-git` package installed.

    It processes the output of `ntldd.exe`, converting resulting paths to Linux style.

## What exactly are we doing with the kernel

We use [`binfmt_misc`](https://www.kernel.org/doc/Documentation/admin-guide/binfmt-misc.rst) to temporarily configure the kernel to transparently run Windows `.exe`s using Wine.

This requires root permissions, and persists until a reboot or until stopped manually.

This is not restricted to Quasi-MSYS2 shells, and will work everywhere.

See `env/binfmk.mk` for the exact commands we're using.

## Package manager usage

Run `make help` to get the full list of commands it supports.

Here are some common ones:

* `make list-all` - List all packages available in the repository.<br>
  This command will only download the repository database on the first run. Updating the database is explained below.

  Use `make list-all | grep <package>` to search for packages.

* `make install <packages>` - Install packages.<br>
  The packages are installed to the `./root/`.

  <sup>Most package names share a common prefix: `mingw-w64-x86_64-gcc mingw-w64-x86_64-clang ...`. You can use `_` instead of this long prefix, e.g. `make install _gcc` instead of `make install mingw-w64-x86_64-gcc`.</sup>

* `make remove <packages>` - Remove packages.

* `make upgrade` - Download the latest package database and install package updates.<br>
  Do this routinely to keep your installation up to date.

  <sup>To update only the database and not the packages, run `make update`.</sup>

* `make list-ins` - List all installed packages.

* `make list-req` - List only those installed packages that were explicitly requested, rather than being automatically installed as a dependency.

**Fixing problems**

Sometimes the installation can become inconsistent. This usually happens if you interrupt `make`, or if something goes wrong.

This means that one or more packages are queued for installation, update, or removal.

Normally this is fixed automatically, but you can also do it manually:

* `make delta` - Check the installation, and list the queued actions. If you get no output, your installation is consistent.

  The output is a list of packages, with prefixes: `+` for packages to be installed, `-` for packages to be removed, `>` for packages to be updated.

* `make apply-delta` - Fix the installation by applying the necessary the changes as displayed by `make delta`.

  This is done automatically by most high-level commands, such as `upgrade`, `install`, and `remove`.

If you messed up your installation beyond repair, use `make reinstall-all` to purge everything and reinstall all packages.

**Advanced usage**

Basic commands listed above are too crude in some cases.

E.g. `make upgrade` doesn't let you review the updates before installing them, and `make install` doesn't tell you what dependencies it's going to install.

This can be solved using several more advanced commands listed below. Most of them make the installation inconsistent, and require running `make apply-delta` to apply the changes.

* `make update` - Download a new repository database, but don't do anything else.

  If followed by `apply-delta`, this is roughly equivalent to `upgrade` (which additionally cleans up a few things).

* `make request <packages>` - Signal that you want a package to be installed, but don't actually install it.

  If followed by `apply-delta`, this is equivalent to `install`.

* `make undo-request <packages>` - Signal that you no longer want a package to be installed, but don't actually remove it even if it's installed.

  If followed by `apply-delta`, this is equivalent to `remove`.

The list above contains only the most common commands. See `make help` for more.

**Known issues**

* Package signatures are not verified! But at least we're downloading the files using HTTPS by default.

* Pre/post-install actions are not executed; we simply unpack the package archives. In most cases this is good enough.

* If a package depends on a specific version of some other package, the exact version of that package is not checked. This shouldn't affect you, as long as you don't manually install outdated packages.

* Package conflicts are handled in a crude manner. Information about package conflits provided in the package database is ignored, but if you try to install a package providing a file that already exists, the installation will fail. In most cases this is good enough.

## Backing up the installation

The whole installation directory can be moved around, it doesn't contain any absolute paths.

But you don't need to copy everything if you're making a backup, assuming all files came from the package manager. You only need a clean copy of the repository, and following files:

* `database.mk` — The package database.
* `requested_packages.txt` — The list of packages you've explicitly installed.
* Contents of the `cache/` directory, which contains archived versions of all installed packages. Before backing up the cache, make sure it's up-to-date and minimal by running `make cache-installed-only`.
* User config files: `msystem.txt`, `alternatives.txt` (if present).

To restore such backup to a working state, run `make apply-delta` in it.

## Not-so-frequently asked questions

  * How do I use different [MSYS2 environments](https://www.msys2.org/docs/environments/)?

    * The environment can be changed using `echo DesiredEnvName >msystem.txt`, preferably in a clean repository. If you want multiple environments, you need multiple copies of Quasi-MSYS2.

      All environments should work, more or less. (Except for `MSYS`, which I'm not particulary interested in.)

      `MINGW64`, `MINGW32`, and `UCRT64` are relatively well-tested.

      On `CLANG64` and `CLANG32`, cross-compiling with the native Clang is experimental. It's strongly recommended to install the same native Clang version as the one used by MSYS2 (at least the same major version, different minor versions seem to be compatible?).

  * How do I add a desktop entry for the quasi-msys2 shell?
    * Use `make -f env/integration.mk`. To undo, invoke it again with the `uninstall` flag.

  * Using LD instead of LLD when compiling with the native Clang.
    * I started having problems with the native LD after some MSYS2 update (it produces broken executables), so we default to LLD.

      Last tested on LD 2.34, a more recent version might work.

      LD shipped by MSYS2 (was LD 2.37 last time I checked) works under Wine. If `binfmt_misc` is enabled, you can switch to it using `-fuse-ld=$MSYSTEM_PREFIX/bin/ld.exe`.

      You can try the native LD using `-fuse-ld=ld`. (Or remove `-fuse-ld=lld` from `WIN_CLANG_FLAGS` variable.)

  * My build system is confused because the compiled C/C++ binaries are suffixed with `.exe`.
    * Use `source env/duplicate_exe_outputs.src`. Then `$CC` and `$CXX` will output two identical binaries, `foo.exe` and `foo`. The lack of the extension doesn't stop them from being transparently invoked with Wine.


## Installation structure

* `Makefile` — The package manager.

* `root/` — Packages are installed here.

* `index/` — For each installed package it contains a file with a list of files owned by it.

  `root/` and `index/` must always stay in sync, otherwise things will break.
* `cache/` — Stores cached archives of the packages downloaded from the repo.

* `database.mk` — The package database, converted to our own format.

* `database.mk.bak` — A backup of `database.mk` performed the last time a new database was downloaded.

* `database.current_original` — The original database file downloaded from the repository. This is used to speed up database updated (if the downloaded database matches this file, we don't need to reparse it).

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

  * `all_quiet.src` — Runs all the files above, in quiet mode. Must be run as `source path/to/all_quiet.src`.

  * `shell.sh` — Creates a new Bash shell and runs `source all_quiet.src` in it. Do `exit` to return to the original shell.

  * `integration.mk` — Generates a desktop file for the Quasi-MSYS2 shell.

  * `duplicate_exe_outputs.src` — Modifies `CC` and `CXX` variables to point to wrappers that duplicate the produced executables without extensions. This can have with some build systems.

  * `wrappers/` — Wrappers for the native Clang and CMake that add the correct parameters for them.

  * `config/` — Contains configuration files for the build systems.

    * `config.site` — This configures the Autotools. `vars.src` stores a path to it in `CONFIG_SITE`, which Autotools read.

    * `toolchain.cmake` — This configures CMake. Our CMake wrapper passes this file to CMake.

  * `internal/` — Internal helper scripts.
