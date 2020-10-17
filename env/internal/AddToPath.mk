# This makefile prints the contents of PATH, with the value of `dirs` appended to the front of it.
# If those directories are already mentioned, any duplicates of them are removed.
# We have no way to set the resulting PATH, so we print it to `stdout`.


# Some constants.
override space := $(strip) $(strip)

dirs = $(error Set `dirs` to the dirs you want to append to the PATH.)
override dirs := $(subst :, ,$(subst $(space),<,$(dirs)))

$(info $(subst <, ,$(subst $(space),:,$(strip $(dirs) $(filter-out $(dirs),$(subst :, ,$(subst $(space),<,$(PATH))))))))

.PHONY: empty
empty:
	@true
