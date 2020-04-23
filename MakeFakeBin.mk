# Same as `$(shell ...)`, but triggers a error on failure.
ifeq ($(filter --trace,$(MAKEFLAGS)),)
override safe_shell = $(shell $1)$(if $(filter-out 0,$(.SHELLSTATUS)),$(error Unable to execute `$1`, status $(.SHELLSTATUS)))
else
override safe_shell = $(info Shell command: $1)$(shell $1)$(if $(filter-out 0,$(.SHELLSTATUS)),$(error Unable to execute `$1`, status $(.SHELLSTATUS)))
endif

# Same as `safe_shell`, but discards the output and expands to nothing.
override safe_shell_exec = $(call,$(call safe_shell,$1))


DIR := fake_bin
PATTERN := root/mingw64/bin/*.exe

NAMES := $(patsubst $(subst *,%,$(PATTERN)),%,$(wildcard $(PATTERN)))


.PHONY: all
all:
	$(call safe_shell_exec,rm -rf '$(DIR)')
	$(call safe_shell_exec,mkdir -p '$(DIR)')
	$(foreach x,$(NAMES),$(call safe_shell_exec,echo >'$(DIR)/$x' 'wine $x $$@')$(call safe_shell_exec,chmod +x '$(DIR)/$x'))
	@true

