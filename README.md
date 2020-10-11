## msys2-pacmake

**What is this?**

`msys2-pacmake` a tiny package manager (a single makefile), designed to work with MSYS2 repositories.

It's designed to run on Linux, since MSYS2 shell and package manager don't work on Linux even under Wine.

**What is MSYS2 and why would I want MSYS2 packages on Linux?**

MSYS2 normally runs on Windows, and provides a linux-like build environment that includes ports of common command-line utilities, major compilers (GCC and Clang, targeting Windows x86 and x64) and many prebuilt libraries.

MSYS2 shell and command-line utilties don't work on Linux even under Wine.

But ***compilers and libraries provided by MSYS2 **do** work under Wine. Using this script, you can download them.***

## Prerequisites

* `make` (obviously)
* `wget`
* `tar`
* `zstd` (which `tar` uses to unpack `.tar.zst` archives).

## Usage

`make help` displays the full list of commands.

Here are the most common commands:

* `make list-all` - List all packages available in the repository.<br>
  This command will only download the repository database on the first run.<br>
  Use `make upgrade` to update the database.

  Use `make list-all | grep <package>` to search for packages.

* `make install <packages>` - Install packages.<br>
  The packages are installed into the `./root/`.

  <sup>Most package names share a common prefix: `mingw-w64-x86_64-gcc mingw-w64-x86_64-clang ...`. You can use `_` instead of this long prefix, e.g. `make install _gcc` instead of `make install mingw-w64-x86_64-gcc`.</sup>

* `make remove <packages>` - Remove packages.

* `make upgrade` - Download the latest package database and install package updates.<br>
  Do this routinely to keep your installation up to date.

* `make list-ins` - List all installed packages.

* `make list-req` - List only those installed packages that were explicitly requested, rather than being automatically installed as a dependency.

**Fixing problems**

Sometimes the installation can become inconsistent. This usually happens if you interrupt `make`, or if something goes wrong.

This means that one or more packages are queued for installation, update, or removal.

Normally this is fixed automatically, but you can also do it manually:

* `make delta` - Check the installation, and list the queued actions. If you get no output, your installation is consistent.

  The output is a list of packages, with prefixes: `+` for packages to be installed, `-` for packages to be removed, `>` for packages to be updated.

* `make apply-delta` - Fix the installation by applying necessary changes as displayed by `make delta`.

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

**Switching repositores**

By default the script targets the `x86_64` repository, which contains 64-bit compilers and libraries.

You can switch to the `i686` (32-bit) repository by editing the constants at the beginning of `Makefile`.

## I installed a compiler, how do I use it?

Installed compilers should be located in `./root/mingw64/bin/`.

You can run them using Wine:

    cd ./root/mingw64/bin && wine gcc --version

If you want to run them from an arbitrary directory, you need to set the `WINEPATH` environment variable:

    export WINEPATH=/<full-path>/root/mingw64/bin
    wine gcc --version

Have fun.

## Known issues

* Package signatures are not verified, beware!

* Pre/post-install actions are not executed; we simply unpack the package archives. In most cases this is good enough.

* If a package depends on a specific version of some other package, the exact version of that package is not checked. This shouldn't affect you, as long as you don't manually install outdated packages.

* Package conflicts are handled in a crude manner. Information about package conflits provided by the package database is ignored, but if you try to install a package providing a file that already exists, the installation will fail. In most cases this is good enough.
