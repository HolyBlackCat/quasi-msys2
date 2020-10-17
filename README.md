## msys2-pacmake

**What is this?**

A small Linux-to-Windows cross-compilation environment.

Features:

* A tiny package manager, working with MSYS2 repositories.<br>
  From there you can install an up-to-date GCC and some common libraries.
* A script that temporarily configures your kernel to transparently run `.exe` files with Wine, as if they were native executables. All kernel configuration will be undone on a reboot, or can be undone manually with the provided script.
* CMake and Autotools will be tricked into thinking that they're doing a native Windows build!

## Prerequisites

Mandatory:

* `make`, `wget`, `tar`, `zstd` (which `tar` uses to unpack `.tar.zst` archives)

Recommended:

* **Clang**, to cross-compile for Windows. You can use MSYS2 GCC and Clang as well, but a native Clang is much faster.

* **Wine** to transparently run Windows programs.

## Basic usage

* `make install _gcc _gdb` to install MSYS2 GCC and GDB.<br>
  Then you can run `make upgrade` from time to time to update the installed packages.

* `source env/all_quiet.sh` to set up the build environment and configure the kernel.<br>
  You need to run this in each shell you want to build from.

  This script goes over all files in `env/*`, executing shell scripts with `source <file>` and makefiles with `make -f <file>`.

  If you want to know more about what each file does, run them manually. They will print some information about what they're doing, and what parameters they have.

  The kernel configuration is done by `env/binfmk.mk`, for that it will ask you for a `sudo` password. When run manually, this makefile will behave a bit more nicely, asking you for confirmation before executing each `sudo` command. If you don't trust the makefile, you can inspect it and run the commands manually, that shouldn't be hard.

In a configured build environment, you can do following:

  * Invoke `.exe` files transparently as if they were native executables, Wine will be used for that.

  * Cross-compile to Windows using your native Clang. Use `win-clang` and `win-clang++` wrappers.

  * Cross-compile to Windows using MSYS2 GCC or Clang running under Wine. Normally you want to avoid this, since a native Clang is much faster.

    While using MSYS2 GCC makes some sense if you prefer GCC over Clang, using MSYS2 Clang is completely pointless, since a native Clang will do the same thing but faster.

  * Cross-compile libraries using Autotools and CMake.

    Autotools (aka `./configure && make`) should work out of the box.

    For CMake you should be using the `win-cmake` wrapper.

## Package manager usage

You can install various libraries from the package manager.

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

To restore such backup to a working state, run `make apply-delta` in it.

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

* `msys2_pacmake_base_dir` — An empty file marking the installation directory. The package manager refuses to operate if it's not in the working directory, to make sure you don't accidentally create a new installation.

* (temporary) `database.db` — The database downloaded from the repository, in the process of being converted to our custom format.

* (temporary) `database/` — Temporary files created when processing a downloaded database.

* `env/` — Contains the scripts for configuring the build environment. The contents have no connection with the package manager.

  * `binfmt.mk` — Configures the kernel to transparently run Wine programs. It uses `sudo`, so you'll be asked for a `sudo` password.

    Has flags to un-configure the kernel, run it to get more information.

  * `fakebin.mk` — Generates extension-less wrappers for all installed executables, to make running them easier.

    Has a flag to delete all wrappers, run it to get more information.

  * `fake_bin/` — Contains the wrappers generated by `fakebin.mk`

  * `vars.sh` — Sets up environment variables, including `PATH`. Must be run as `source path/to/vars.sh`.

  * `all_quiet.sh` — Runs all the files above, in quiet mode. Must be run as `source path/to/all_quiet.sh`.

  * `wrappers/` — Wrappers for the native Clang and CMake that add the correct parameters for them.

  * `config/` — Contains configuration files for the build systems.

    * `config.site` — This configures the Autotools. `vars.sh` stores a path to it in `CONFIG_SITE`, which Autotools read.

    * `toolchain.cmake` — This configures CMake. The `win-cmake` wrapper passes this file to CMake.

  * `internal/` — Internal helper scripts.
