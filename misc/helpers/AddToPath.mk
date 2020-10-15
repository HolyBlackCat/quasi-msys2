# This makefile prints the contents of PATH, with the value of `dir` appended to the front of it.
# If that directory is already mentioned, any duplicates of it are removed.
# We have no way to set the resulting PATH, so we print it to `stdout`.


# Some constants.
override space := $(strip) $(strip)

dir = $(error Set `dir` to the dir you want to append to the PATH.)
override dir := $(subst $(space),<,$(dir))

$(info $(subst <, ,$(subst $(space),:,$(strip $(dir) $(filter-out $(dir),$(subst :, ,$(subst $(space),<,$(PATH))))))))

.PHONY: empty
empty:
	@true
