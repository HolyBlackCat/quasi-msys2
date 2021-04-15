# A space-separated list of programs that must not have fakebin wrappers.
# Most are blacklisted because native equivalents work equally well.
# `pkg-config` is blacklisted because it outputs WINE-style paths.
QUASI_MSYS2_FAKEBIN_BLACKLIST ?= ar ld ld.bfd pkg-config strip


ifeq ($(filter --trace,$(MAKEFLAGS)),)
# Same as `$(shell ...)`, but triggers a error on failure.
override safe_shell = $(shell $1)$(if $(filter-out 0,$(.SHELLSTATUS)),$(error Unable to execute `$1`, exit code $(.SHELLSTATUS)))
# Same as `$(shell ...)`, expands to the shell status code rather than the command output.
override shell_status = $(call,$(shell $1))$(.SHELLSTATUS)
else
# Same functions but with logging.
override safe_shell = $(info Shell command: $1)$(shell $1)$(if $(filter-out 0,$(.SHELLSTATUS)),$(error Unable to execute `$1`, exit code $(.SHELLSTATUS)))
override shell_status = $(info Shell command: $1)$(call,$(shell $1))$(.SHELLSTATUS)$(info Exit code: $(.SHELLSTATUS))
endif

# Same as `safe_shell`, but discards the output and expands to nothing.
override safe_shell_exec = $(call,$(call safe_shell,$1))

# Encloses $1 in single quotes, with proper escaping for the shell.
# If you makefile uses single quotes everywhere, a decent way to transition is to manually search and replace `'(\$(?:.|\(.*?\)))'` with `$(call quote,$1)`.
override quote = '$(subst ','"'"',$1)'


QUIET :=
$(if $(QUIET),,\
	$(info This script creates extension-less wrappers for installed executables, to make running them easier.)\
	$(info Run with `remove` to delete the wrappers.)\
	$(info Add `QUIET=1` to hide this message.)\
	$(info )\
)


override installation_root := $(dir $(word 1,$(MAKEFILE_LIST)))..
$(if $(wildcard $(installation_root)/msys2_pacmake_base_dir),,$(error Looks like this makefile is in a wrong directory. Refuse to continue))


DIR := env/fake_bin
override DIR := $(installation_root)/$(DIR)

# This should give us the value of `MSYSTEM_PREFIX` from the main makefile.
MSYSTEM_PREFIX :=
$(eval $(call safe_shell,make -C $(call quote,$(installation_root)) -pq | grep '^MSYSTEM_PREFIX\b'))
$(if $(MSYSTEM_PREFIX),,$(error Can't obtain the value of `MSYSTEM_PREFIX`.))

PATTERN := root$(MSYSTEM_PREFIX)/bin/*.exe
override PATTERN := $(installation_root)/$(PATTERN)

override wanted_list = $(filter-out $(QUASI_MSYS2_FAKEBIN_BLACKLIST),$(patsubst $(subst *,%,$(PATTERN)),%,$(wildcard $(PATTERN))))
override current_list = $(patsubst $(DIR)/%,%,$(wildcard $(DIR)/*))
override added_list = $(filter-out $(current_list),$(wanted_list))
override removed_list = $(filter-out $(wanted_list),$(current_list))

.PHONY: update
update:
	$(call safe_shell_exec,mkdir -p '$(DIR)')
	$(foreach x,$(added_list),$(file >$(DIR)/$x,wine $x "$$@")$(call safe_shell_exec,chmod +x '$(DIR)/$x'))
	$(foreach x,$(removed_list),$(call safe_shell_exec,rm -f '$(DIR)/$x'))
	$(if $(added_list)$(removed_list),\
		$(info Added $(words $(added_list)) wrappers, removed $(words $(removed_list)) wrappers.)\
	,\
		$(info Nothing to do.)\
	)
	@true

.PHONY: remove
remove:
	$(call safe_shell_exec,rm -rf '$(DIR)')
	$(info Deleted `$(DIR)`.)
	@true
