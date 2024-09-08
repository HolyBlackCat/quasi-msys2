# Generates the cross-file for meson (like cmake's toolchain file).
# Meson, in their infinite wisdom, decided that you shouldn't be able
# to read environment variables from your build scripts, so apparently
# we have GENERATE this on the fly. Duh.

ifeq ($(origin MSYSTEM),undefined)
$(error Environment variables are missing. Run this from the quasi-msys2 shell, or source `vars.src` first)
endif

override define lf :=
$(strip)
$(strip)
endef

override is32bit := $(if $(filter %32,$(MSYSTEM)),y)

override define contents :=
[binaries]
exe_wrapper = 'wine'
# Meson refuses to use those unless we explicitly tell it to. Something else might be missing.
pkg-config = 'pkg-config'
strip = 'strip'
# Unsure about those, copied them from https://github.com/mesonbuild/meson/blob/master/cross/linux-mingw-w64-64bit.txt
ar = 'ar'
windres = 'windres'
cmake = 'cmake'

[host_machine]
system = 'windows'
# I guess?
cpu_family = '$(if $(is32bit),x86,x86_64)'
cpu = '$(if $(is32bit),i686,x86_64)'
endian = 'little'

[properties]
# What's the difference? `root` seems to be undocumented...
sys_root = '$(MSYSTEM_PREFIX)'
root = '$(MSYSTEM_PREFIX)'
endef

target_file := $(dir $(word 1,$(MAKEFILE_LIST)))config/meson_cross_file.ini

override old_contents := $(file <$(target_file))

should_overwrite = $(if $(and $(findstring $(contents),$(old_contents)),$(findstring $(old_contents),$(contents))),,y)

ifneq ($(should_overwrite),)
.PHONY: $(target_file)
endif

$(target_file):
	$(file >$(target_file),$(contents))
	$(info Updated `$(target_file)`.)
	@true

# $(error $(contents))
