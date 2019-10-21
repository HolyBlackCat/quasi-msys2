# --- CONFIG ---

REPO_DB := http://repo.msys2.org/mingw/x86_64/mingw64.db

override flags_dir := flags/

# --- GENERIC UTILITIES ---

# Some constants.
override space := $(strip) $(strip)

# Same as `$(shell ...)`, but triggers a error on failure.
ifeq ($(filter --trace,$(MAKEFLAGS)),)
override safe_shell = $(shell $1)$(if $(filter-out 0,$(.SHELLSTATUS)),$(error Unable to execute `$1`, status $(.SHELLSTATUS)))
else
override safe_shell = $(info Shell command: $1)$(shell $1)$(if $(filter-out 0,$(.SHELLSTATUS)),$(error Unable to execute `$1`, status $(.SHELLSTATUS)))
endif

# Same as `safe_shell`, but discards the output and expands to a single space.
override safe_shell_exec = $(call space,$(call safe_shell,$1))

# Prints $1 to stderr.
override print_log = $(call safe_shell_exec,echo >&2 '$(subst ','"'"',$1)')

# Removes the last occurence of $1 in $2, and everything that follows.
# $2 has to contain no spaces (same for $1).
# If $1 is not found in $2, returns $2 without changing it.
#override remove_suffix = $(subst $(lastword $(subst $1, ,$2)<<<),,$2<<<)
override remove_suffix = $(subst <<<,,$(subst $1$(lastword $(subst $1, ,$2)<<<),<<<,$2<<<))


# --- CHECK USAGE ---
ifeq ($(words $(MAKECMDGOALS)),0)
$(error No action specified)
else ifneq ($(words $(MAKECMDGOALS)),1)
$(if $(filter __database_query,$(MAKECMDGOALS)),,\
	$(error More than one action specified))
endif


# --- DETECT A RESTART ---

$(if $(MAKE_RESTARTS),$(eval override make_was_restarted := yes))
ifneq ($(make_was_restarted),)
$(call print_log,Restaring 'make'...)
endif


# --- DATABASE INTERNALS ---

# Temporary database file.
override database_tmp_file := database.db
# Temporary database directory.
override database_tmp_dir := database/
# A pattern for desciption files.
override desc_pattern := $(database_tmp_dir)*/desc

# Converts description file names to package names (with versions).
override desc_file_to_name_ver = $(patsubst $(subst *,%,$(desc_pattern)),%,$1)

# Strips versions from package names.
override strip_ver = $(foreach x,$1,$(call remove_suffix,-,$(call remove_suffix,-,$x)))
# Strips version conditions from package names, e.g. `=1.2` or `>=1.2`.
override strip_ver_cond = $(foreach x,$1,$(call remove_suffix,=,$(call remove_suffix,>=,$x)))

# Extracts section contents from a package description file.
# $1 is the section name, such as `%DEPENDS%`.
# $2 is the file contents, as a string.
override extract_section = $(subst <, ,$(sort $(word 1,$(subst %, ,$(word 2,$(subst $1, ,$(subst $(space),<,$(strip $2))))))))

# Prints to a file $1 a variable that contains the version of the package $2.
# $1 is a destination file.
# $2 is a package name, with version.
override code_pkg_version_var = $(call safe_shell_exec,echo >>'$1' 'override VERSION_OF_$(call strip_ver,$2) := $(subst $(call strip_ver,$2)-,,$2)')

# Prints to a file $1 a variable that contains the dependencies of the package $1 that have a version specified.
# $1 is a destination file.
# $2 is a package name, with version.
# $3 is a list of dependencies, from a package descritpion file (extracted with `extract_section`).
override code_pkg_deps_versions_var = $(call safe_shell_exec,echo >>'$1' 'override DEP_VERS_OF_$(call strip_ver,$2) := $(sort $(foreach x,$3,$(if $(findstring =,$x),$x)))')

# Prints to a file $1 a make target for a list of packages $2, that depend on packages $3.
# $1 is a destination file.
# Both $1 and $2 shouldn't contain versions, but $2 can contain version conditions, such as `=1.2` or `>=1.2`.
override code_pkg_target = \
	$(call safe_shell_exec,echo >>'$1' '.PHONY: $(addprefix PKG@@,$(sort $2))')\
	$(call safe_shell_exec,echo >>'$1' '$(addprefix PKG@@,$(sort $2)): $(addprefix PKG@@,$(sort $(call strip_ver_cond,$3))) ; @echo '"'"'$$(@:PKG@@=)'"'"'')


# Converts package names (without versions) to flag file names.
override name_to_flag = $(addprefix $(flags_dir),$1)

# We don't use `.INTERMEDIATE` for consistency, see below.
.SECONDARY:
$(database_tmp_file):
	$(call print_log,Downloading package database...)
	@wget '$(REPO_DB)' -O $@

# `.INTERMEDIATE` doesn't seem to work with directories, so we use `.SECONDARY` and delete it manually in the recipe for `database.mk`.
.SECONDARY:
$(database_tmp_dir): $(database_tmp_file)
	$(call print_log,Extracting package database...)
	@rm -rf '$@'
	@mkdir -p '$@'
	@tar -C '$@' -xzf '$<'
	@rm -f '$<'

database.mk: $(database_tmp_dir)
	$(call print_log,Processing package database...)
	$(call safe_shell_exec,rm -f '$@')
	$(eval override _local_db_files := $(sort $(wildcard $(desc_pattern))))
#	$(eval   override _local_db_files := $(wordlist 400,800,$(_local_db_files)))
	$(eval override _local_pkg_list :=)
	$(foreach x,$(_local_db_files),\
		$(eval override _local_name_ver := $(call desc_file_to_name_ver,$x))\
		$(call code_pkg_version_var,$@,$(_local_name_ver))\
		$(eval override _local_file := $(call safe_shell,cat $x))\
		$(eval override _local_deps := $(call extract_section,%DEPENDS%,$(_local_file)))\
		$(call code_pkg_deps_versions_var,$@,$(_local_name_ver),$(_local_deps))\
		$(eval override _local_aliases := $(call strip_ver_cond,$(call extract_section,%PROVIDES%,$(_local_file))))\
		$(eval override _local_lhs := $(call strip_ver,$(_local_name_ver)) $(_local_aliases))\
		$(foreach y,$(_local_lhs),\
			$(eval override _local_conflict := $(strip $(word 1,$(filter %|$y,$(_local_pkg_list)))))\
			$(if $(_local_conflict),\
				$(call print_log,Warning: '$y' is provided by both)\
				$(call print_log,  '$(word 1,$(subst |, ,$(_local_conflict)))' and)\
				$(call print_log,  '$(_local_name_ver)')\
				$(call print_log,  The second option will be ignored by default.)\
				$(eval override _local_lhs := $(filter-out $y,$(_local_lhs)))\
			)\
		)\
		$(eval override _local_pkg_list += $(addprefix $(_local_name_ver)|,$(_local_lhs)))\
		$(call code_pkg_target,$@,$(_local_lhs),$(_local_deps))\
		$(call safe_shell_exec,echo >>$@)\
	)
	@rm -rf '$<'

# A fake target. If it's specified in the command line, the database will be loaded.
# Use it to make a database query:
.PHONY: __database_query
__database_query:
	@true

ifneq ($(filter __database_query,$(MAKECMDGOALS)),)
include database.mk
endif


# --- DATABASE INTERFACE ---

# $1 is a list of package names, without versions.
# Returns $1, with all necessary dependencies added.
override database_query_deps = $(patsubst PKG@@%,%,$(filter PKG@@%,$(call safe_shell,$(MAKE) __database_query $(addprefix PKG@@,$1))))


# --- OTHER TARGETS ---

.DEFAULT_GOAL := print_all
.PHONY: print_all
print_all:
	$(info ...)
	@echo '$(addprefix ->,$(call database_query_deps,mingw-w64-x86_64-libc++))'


# .PHONY: print_all
# print_all: $(flags_dir)mingw-w64-x86_64-SDL2_image



# pkg_list: pkg_list_raw
# 	grep pkg_list_raw -Poe '(?<=<a href=")[^"]*\.pkg\.[^"]*' >$@

# .INTERMEDIATE: pkg_list_raw
# pkg_list_raw:
# 	wget http://repo.msys2.org/mingw/x86_64/ -O $@
