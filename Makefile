# --- CONFIG ---

# URL of the repository database, such as `http://repo.msys2.org/mingw/x86_64/mingw64.db`.
REPO_DB_URL := http://repo.msys2.org/mingw/x86_64/mingw64.db

# Suffix of the package archives, such as `-any.pkg.tar.xz`.
REPO_PACKAGE_ARRCHIVE_SUFFIX := -any.pkg.tar.xz

# A common prefix for all packages.
# You don't have to set this variable, as it's only used for convenience,
# to avoid typing long package names. (See notes at the end of `make help` for details.)
REPO_PACKAGE_COMMON_PREFIX := mingw-w64-x86_64-

# Extract packages here.
ROOT_DIR := root

# Download archives here.
CACHE_DIR := cache

# If nonzero, don't delete the original database downloaded from the repo, and the temporary files created when parsing it.
# Useful for debugging the database parser.
KEEP_UNPROCESSED_DATABASE := 0


# --- VERSION ---
override version := 1.0.0


# --- GENERIC UTILITIES ---

# Disable parallel builds.
.NOTPARALLEL:


# Some constants.
override space := $(strip) $(strip)
override comma := ,
override define lf :=
$(strip)
$(strip)
endef

# Same as `$(shell ...)`, but triggers a error on failure.
ifeq ($(filter --trace,$(MAKEFLAGS)),)
override safe_shell = $(shell $1)$(if $(filter-out 0,$(.SHELLSTATUS)),$(error Unable to execute `$1`, status $(.SHELLSTATUS)))
else
override safe_shell = $(info Shell command: $1)$(shell $1)$(if $(filter-out 0,$(.SHELLSTATUS)),$(error Unable to execute `$1`, status $(.SHELLSTATUS)))
endif

# Same as `safe_shell`, but discards the output and expands to a single space.
override safe_shell_exec = $(call space,$(call safe_shell,$1))

# Downloads url $1 to file $2. Deletes the file on failure.
override use_wget = $(call safe_shell_exec,wget '$1' -q -c --show-progress -O '$2' || (rm -f '$2' && false))

# Prints $1 to stderr.
override print_log = $(call safe_shell_exec,echo >&2 '$(subst ','"'"',$1)')

# Removes the last occurence of $1 in $2, and everything that follows.
# $2 has to contain no spaces (same for $1).
# If $1 is not found in $2, returns $2 without changing it.
#override remove_suffix = $(subst $(lastword $(subst $1, ,$2)<<<),,$2<<<)
override remove_suffix = $(subst <<<,,$(subst $1$(lastword $(subst $1, ,$2)<<<),<<<,$2<<<))


# --- PROCESS PARMETERS ---

# A default target.
.DEFAULT_GOAL := help
ifeq ($(words $(MAKECMDGOALS)),0)
# Note that this assignment doesn't make `make` execute the target, so we also need to set `.DEFAULT_GOAL`.
MAKECMDGOALS := help
endif

override display_help :=
ifneq ($(filter help,$(word 1,$(MAKECMDGOALS))),)
override display_help := y
endif

override p_is_set :=
override p = $(error No parameters specified)

override stop_if_have_parameters = $(if $(p_is_set),$(error This action requires no parameters))

# If more than one parameter is specified...
ifneq ($(filter-out 0 1,$(words $(MAKECMDGOALS))),)
# If it's a database query, do nothing.
# Otherwise, convert all targets after the first one to paramters. Also replace `_` with a proper prefix.
# Also create a list of fake empty recipes for those targets.
$(if $(filter __database_%,$(MAKECMDGOALS)),,\
	$(eval override p_is_set := y)\
	$(eval override p := $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS)))\
	$(foreach x,$p,$(eval .PHONY: $x)$(eval $x: ; @true))\
	$(eval override p := $(patsubst _%,$(REPO_PACKAGE_COMMON_PREFIX)%,$p))\
	)
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
override database_tmp_dir := database
# A pattern for desciption files.
override desc_pattern := $(database_tmp_dir)/*/desc

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
#   override code_pkg_deps_versions_var = $(call safe_shell_exec,echo >>'$1' 'override DEP_VERS_OF_$(call strip_ver,$2) := $(sort $(foreach x,$3,$(if $(findstring =,$x),$x)))')

# Prints to a file $1 a make target for a list of packages $2, that depend on packages $3.
# $1 is a destination file.
# Both $1 and $2 shouldn't contain versions, but $2 can contain version conditions, such as `=1.2` or `>=1.2`.
# The first name in $2 is considered to be the actual name of the package.
override code_pkg_target = \
	$(call safe_shell_exec,echo >>'$1' '.PHONY: $(addprefix PKG@@,$(sort $2))')\
	$(call safe_shell_exec,echo >>'$1' '$(addprefix PKG@@,$(sort $2)): $(addprefix PKG@@,$(sort $(call strip_ver_cond,$3))) ; @echo '"'"'PKG@@$(word 1,$2)'"'"'')


# We don't use `.INTERMEDIATE` for consistency, see below.
.SECONDARY:
$(database_tmp_file):
	$(call print_log,Downloading package database...)
	$(call use_wget,$(REPO_DB_URL),$@)

# `.INTERMEDIATE` doesn't seem to work with directories, so we use `.SECONDARY` and delete it manually in the recipe for `database.mk`.
.SECONDARY:
$(database_tmp_dir)/: $(database_tmp_file)
	$(call print_log,Extracting package database...)
	@rm -rf '$@'
	@mkdir -p '$@'
	@tar -C '$@' -xzf '$<'
ifeq ($(KEEP_UNPROCESSED_DATABASE),0)
	@rm -f '$<'
endif

database.mk: $(database_tmp_dir)/
	$(call print_log,Processing package database...)
	$(call safe_shell_exec,rm -f '$@')
	$(eval override _local_db_files := $(sort $(wildcard $(desc_pattern))))
#	$(eval   override _local_db_files := $(wordlist 400,800,$(_local_db_files)))
	$(eval override _local_pkg_list :=)
	$(eval override _local_dupe_check_list :=)
	$(foreach x,$(_local_db_files),\
		$(eval override _local_name_ver := $(call desc_file_to_name_ver,$x))\
		$(eval override _local_name := $(call strip_ver,$(_local_name_ver)))\
		$(call code_pkg_version_var,$@,$(_local_name_ver))\
		$(eval override _local_file := $(call safe_shell,cat $x))\
		$(eval override _local_deps := $(call extract_section,%DEPENDS%,$(_local_file)))\
		$(eval override _local_aliases := $(call strip_ver_cond,$(call extract_section,%PROVIDES%,$(_local_file))))\
		$(eval override _local_lhs := $(_local_name) $(_local_aliases))\
		$(eval override _local_pkg_list += $(_local_name))\
		$(foreach y,$(_local_lhs),\
			$(eval override _local_conflict := $(strip $(word 1,$(filter %|$y,$(_local_dupe_check_list)))))\
			$(if $(_local_conflict),\
				$(call print_log,Warning: '$y' is provided by both)\
				$(call print_log,  '$(word 1,$(subst |, ,$(_local_conflict)))' and)\
				$(call print_log,  '$(_local_name_ver)')\
				$(call print_log,  The second option will be ignored by default.)\
				$(eval override _local_lhs := $(filter-out $y,$(_local_lhs)))\
			)\
		)\
		$(eval override _local_dupe_check_list += $(addprefix $(_local_name_ver)|,$(_local_lhs)))\
		$(call code_pkg_target,$@,$(_local_lhs),$(_local_deps))\
		$(call safe_shell_exec,echo >>$@)\
	)
	$(call safe_shell_exec,echo >>$@ 'override FULL_PACKAGE_LIST := $(sort $(_local_pkg_list))')
ifeq ($(KEEP_UNPROCESSED_DATABASE),0)
	@rm -rf '$<'
endif
	@true


# Load the database if we got a query.
ifneq ($(filter __database_%,$(MAKECMDGOALS)),)
include database.mk
# Also validate all package names specified in the command line
$(foreach x,$(patsubst PKG@@%,%,$(filter PKG@@%,$(MAKECMDGOALS))),$(if $(VERSION_OF_$x),,$(error Unknown package: '$x')))
endif

# Internal database interface:

# Invokes make with $1 parameters, and returns the result.
override invoke_database_process = $(call safe_shell,$(MAKE) $(MAKEOVERRIDES) $1)


# Serves as the query parameter.
__packages = $(error The parameter `__packages` is not set)

# A dummy target, simply loads the database. Good for querying package dependencies.
.PHONY: __database_load
__database_load:
	@true

# Given a list of package names without versions, returns the version of each package.
# Uses `__packages`.
.PHONY: __database_get_versions
__database_get_versions:
	$(info $(strip $(foreach x,$(__packages),$(if $(VERSION_OF_$x),$(VERSION_OF_$x),??))))
	@true

# Returns a list of all available packages.
.PHONY: __database_list_all
__database_list_all:
	$(info $(FULL_PACKAGE_LIST))
	@true

# Verifies a list of packages.
# Uses `__packages`.
.PHONY: __database_verify
__database_verify:
	$(eval override _local_missing := $(sort $(filter-out $(FULL_PACKAGE_LIST), $(__packages))))
	$(if $(_local_missing),$(error Following packages are not known: $(_local_missing)))
	@true


# --- DATABASE INTERFACE ---

# Does nothing. But if the database is missing, downloads it.
override database_query_empty = $(call space,$(call invoke_database_process,__database_load))

# Returns a list of all available packages.
override database_query_available = $(call invoke_database_process,__database_list_all)

# Verifies a list of packages.
# Causes an error on failure, expands to nothing.
override database_query_verify = $(call invoke_database_process,__database_verify __packages='$1')

# $1 is a list of package names, without versions.
# Returns $1, with all dependencies added.
override database_query_deps = $(sort $(patsubst PKG@@%,%,$(filter PKG@@%,$(call invoke_database_process,__database_load $(addprefix PKG@@,$1)))))

# $1 is a list of package names, without versions.
# Returns the version of each package.
override database_query_version = $(call invoke_database_process,__database_get_versions __packages='$1')

# $1 is a list of package names, without versions.
# Returns the same list, but with versions added.
override database_query_full_name = $(join $1,$(addprefix -,$(call database_query_version,$1)))


# --- CACHE INTERNALS ---

ifeq ($(wildcard $(CACHE_DIR)),)
$(call safe_shell_exec,mkdir -p '$(CACHE_DIR)')
endif

ifeq ($(wildcard $(ROOT_DIR)),)
$(call safe_shell_exec,mkdir -p '$(ROOT_DIR)')
endif

# A prefix for unfinished downloads.
override cache_unfinished_prefix = ---

# $1 is the url, relative to the repo url.
# If the is missing in the cache, downloads it.
override cache_download_file_if_missing = \
	$(if $(wildcard $(CACHE_DIR)/$(notdir $1)),\
		$(call print_log,Using cached '$(notdir $1)'),\
		$(call print_log,Downloading '$(notdir $1)'...)$(call safe_shell_exec,$(call use_wget,$(dir $(REPO_DB_URL))$1,$(CACHE_DIR)/$(cache_unfinished_prefix)$(notdir $1)))\
	$(call safe_shell_exec,mv -f '$(CACHE_DIR)/$(cache_unfinished_prefix)$(notdir $1)' '$(CACHE_DIR)/$(notdir $1)'))

# Deletes unfinished downloads.
override cache_purge_unfinished = $(foreach x,$(wildcard $(CACHE_DIR)/$(cache_unfinished_prefix)*),$(call safe_shell_exec,rm -f '$x'))

# --- CACHE INTERFACE ---

# $1 is a list of packages, with versions.
# If they are not cached, downloads them.
override cache_want_packages = \
	$(cache_purge_unfinished)\
	$(foreach x,$1,$(if $(findstring ??,$x),\
		$(error Can't add package to cache: unknown package: '$x'),\
		$(call cache_download_file_if_missing,$x$(REPO_PACKAGE_ARRCHIVE_SUFFIX))\
	))

# $1 is a list of packages, with versions.
# Outputs the list of contained files, without folders, with spaces replaced with `<`.
override cache_list_pkg_files = $(foreach x,$1,$(call safe_shell,tar -tf '$(CACHE_DIR)/$x$(REPO_PACKAGE_ARRCHIVE_SUFFIX)' --exclude='.*' | grep '[^/]$$' | sed 's| |<|g'))

# Lists current packages sitting in the cache.
override cache_list_current = $(patsubst $(CACHE_DIR)/%$(REPO_PACKAGE_ARRCHIVE_SUFFIX),%,$(wildcard $(CACHE_DIR)/*))

# Lists all archives (including missing ones) used by installed packages.
override cache_list_missing = $(filter-out $(cache_list_current),$(index_list_all_installed))

# Lists all archives not used by installed packages.
override cache_list_unused = $(filter-out $(index_list_all_installed),$(cache_list_current))


# --- INDEX INTERNALS ---

override index_dir := index
override index_pattern := $(index_dir)/*

ifeq ($(wildcard $(index_dir)),)
$(call safe_shell_exec,mkdir -p '$(index_dir)')
endif

# A prefix for broken packages.
override index_broken_prefix := --broken--

# Causes an error if the package $1 is already installed, or is broken.
# $1 has to include the version.
override index_stop_if_single_pkg_installed = \
	$(if $(wildcard $(index_dir)/$1),$(error Package '$1' is already installed))\
	$(if $(wildcard $(index_dir)/$(index_broken_prefix)$1),$(error Installed package '$1' is broken, run 'make purge-broken' and try again))

# Causes an error if the package $1 is not installed (broken counts as installed).
# $1 has to include the version.
override index_stop_if_single_pkg_not_installed = \
	$(if $(strip $(wildcard $(index_dir)/$1)$(wildcard $(index_dir)/$(index_broken_prefix)$1)),,$(error Package '$1' is not installed))\

# Removes a single broken package.
# $1 is a package name, with version. $(index_broken_prefix) is assumed and shouldn't be specified.
override index_uninstall_single_broken_pkg = \
	$(foreach x,$(call index_list_pkg_files,$(index_broken_prefix)$1),$(call safe_shell_exec,rm -f '$(ROOT_DIR)/$(subst <, ,$x)' || true))\
    	$(call safe_shell_exec,rm -f '$(index_dir)/$(index_broken_prefix)$1')\
		$(call print_log,Removed '$1')

# Removes all empty directories in the $(ROOT_DIR).
override index_clean_empty_dirs = $(call safe_shell_exec,find $(ROOT_DIR) -mindepth 1 -type d -empty -delete)

# Removes all packages that have the $(index_broken_prefix) prefix.
override index_purge_broken = \
	$(foreach x,$(wildcard $(index_dir)/$(index_broken_prefix)*),$(call index_uninstall_single_broken_pkg,$(patsubst $(index_dir)/$(index_broken_prefix)%,%,$x)))\
	$(index_clean_empty_dirs)


# $1 is a single package, with version.
# It's installed, without checking dependencies.
# Make sure it's not already installed!
# It's downloaded, unless it's already cached.
override index_force_install_single_pkg = \
	$(call index_stop_if_single_pkg_installed,$1)\
	$(call cache_want_packages,$1)\
	$(foreach x,$(call cache_list_pkg_files,$1),$(call safe_shell_exec,echo >>'$(index_dir)/$(index_broken_prefix)$1' '$x'))\
	$(call print_log,Extracting '$1'...)\
	$(call safe_shell_exec,tar -C '$(ROOT_DIR)' -xf '$(CACHE_DIR)/$1$(REPO_PACKAGE_ARRCHIVE_SUFFIX)' --exclude='.*')\
	$(call safe_shell_exec,mv -f '$(index_dir)/$(index_broken_prefix)$1' '$(index_dir)/$1')\
	$(call print_log,Installed '$1')

# Installs a list of packages $1 (which has to include versions), without considering dependencies.
override index_force_install = $(foreach x,$1,$(call index_force_install_single_pkg,$x))

# Removes a list of packages $1 (which has to include versions), without considering dependencies.
override index_force_uninstall = \
	$(foreach x,$(sort $(patsubst $(index_broken_prefix)%,%,$1)),\
		$(call index_stop_if_single_pkg_not_installed,$x)\
		$(if $(wildcard $(index_dir)/$x),$(call safe_shell_exec,mv -f '$(index_dir)/$x' '$(index_dir)/$(index_broken_prefix)$x'))\
		$(call index_uninstall_single_broken_pkg,$x)\
	)\
	$(index_clean_empty_dirs)


# --- INDEX INTERFACE ---

# Expands to a list of all installed packages, with versions.
override index_list_all_installed = $(patsubst $(subst *,%,$(index_pattern)),%,$(wildcard $(index_pattern)))

# Returns a list of files that belong to installed packages listed in $1.
# $1 has to include package versions.
# Spaces in the resulting list are separated with `<`.
override index_list_pkg_files = $(sort $(foreach x,$1,$(call safe_shell,cat '$(index_dir)/$x')))


# --- PACKAGE MANAGEMENT INTERNALS ---

# Requested packages will be saved to this file.
override request_list_file := requested_packages.txt

ifeq ($(wildcard $(request_list_file)),)
$(call safe_shell_exec,touch '$(request_list_file)')
endif

# Writes a new list of requested packages (with versions) from $1.
override pkg_set_request_list = $(call safe_shell_exec,echo >'$(request_list_file)' '$(sort $1)')

# $1 is a list of packages, without versions. Emits an error if any packages in $1 are in the requested list.
override pkg_stop_if_in_request_list = \
	$(eval override _local_delta := $(sort $(filter $1,$(pkg_request_list))))\
	$(if $(_local_delta),$(error Following packages are already requested: $(_local_delta)))

# $1 is a list of packages, without versions. Emits an error if any packages in $1 are not in the requested list.
override pkg_stop_if_not_in_request_list = \
	$(eval override _local_delta := $(sort $(filter-out $(pkg_request_list),$1)))\
	$(if $(_local_delta),$(error Following packages are already not requested: $(_local_delta)))

# --- PACKAGE MANAGEMENT INTERFACE ---

# Returns the list of requested packages.
override pkg_request_list = $(call safe_shell,cat '$(request_list_file)')

# Clears the request list.
override pkg_request_list_reset = $(call pkg_set_request_list,)

# Adds packages to the list of requested packages.
# $1 is a list of packages without versions.
override pkg_request_list_add = $(call database_query_verify,$1)$(call pkg_stop_if_in_request_list,$1)$(call pkg_set_request_list,$(pkg_request_list) $1)

# Adds packages to the list of requested packages.
# $1 is a list of packages without versions.
override pkg_request_list_remove = $(call pkg_stop_if_not_in_request_list,$1)$(call pkg_set_request_list,$(filter-out $1,$(pkg_request_list)))

# Computes the delta between the current state and the desired state.
# Returns a list of packages with prefixes: `>` means a package should be installed, and `<` means it should be removed.
#   Note that we do `$(foreach x,$(pkg_request_list) ...` rather than passing the entire list
#   to `database_query_deps` to reduce the length of command-line parameters that are passed around.
override pkg_compute_delta = \
	$(eval override _state_cur := $(index_list_all_installed))\
	$(eval override _state_target := $(sort $(foreach x,$(pkg_request_list),$(call database_query_full_name,$(call database_query_deps,$x)))))\
	$(addprefix <,$(filter-out $(_state_target),$(_state_cur)))\
	$(addprefix >,$(filter-out $(_state_cur),$(_state_target)))

# Prints a delta.
# $1 is the delta data.
# Packages that should be removed are prefixed with `- `, and packages that shoudl be installed are prefixed with `+ `.
override pkg_pretty_print_delta = \
	$(foreach x,$(patsubst <%,%,$(filter <%,$1)),$(info - $x))\
	$(foreach x,$(patsubst >%,%,$(filter >%,$1)),$(info + $x))

# Prints a delta.
# $1 is the delta data.
# Same as pkg_pretty_print_delta`, but package updates are printed separately and prefixed with `> `.
override pkg_pretty_print_delta_fancy = \
	$(eval override _local_delta := $1)\
	$(eval override _local_upd :=)\
	$(foreach x,$(_local_delta),$(if $(filter <%,$x),\
		$(eval override _local_name_ver := $(patsubst <%,%,$x))\
		$(eval override _local_name := $(call strip_ver,$(_local_name_ver)))\
		$(foreach y,$(_local_delta),$(if $(filter 1,$(words $(sort $(_local_name) $(call strip_ver,$(patsubst >%,%,$y))))),\
			$(eval override _local_upd += $(_local_name_ver)>$(subst >$(_local_name)-,,$y))\
			$(eval override _local_delta := $(filter-out $x $y,$(_local_delta)))\
		))\
	))\
	$(foreach x,$(patsubst <%,%,$(filter <%,$(_local_delta))),$(info - $x))\
	$(foreach x,$(patsubst >%,%,$(filter >%,$(_local_delta))),$(info + $x))\
	$(foreach x,$(_local_upd),$(info > $(subst >, >> ,$x)))

# Applies a delta.
# $1 is the delta data.
override pkg_apply_delta = \
	$(call index_force_uninstall,$(patsubst <%,%,$(filter <%,$1)))\
	$(call index_force_install,$(patsubst >%,%,$(filter >%,$1)))


# --- TARGETS ---

# Creates a new public target.
# $1 is name.
# $2 is a user-facing parameter name, or empty if it accepts no parameters.
# #3 is human-readable descrption
override act = \
	$(eval override _locat_target := $(if $(filter $1,$(word 1,$(MAKECMDGOALS))),,>>)$(strip $1))\
	$(eval .PHONY: $(_locat_target))\
	$(if $(display_help),\
		$(info make $(strip $1)$(if $2, <$2>))\
		$(info $(space)$(space)$(subst $(lf),$(lf)$(space)$(space),$3))\
		$(info )\
	)\
	$(_locat_target): ; $(if $2,,$$(stop_if_have_parameters))

$(if $(display_help),\
	$(if $(p_is_set),$(error This action requires no parameters.))\
	$(info >> msys2-pacmake v$(version) <<)\
	$(info A simple makefile-based package manager that can be used instead of)\
	$(info MSYS2's pacman if it's not available (e.g. if you're not on Windows))\
	$(info )\
	$(info Usage:)\
	$(info )\
	)

# Defines a new public target section.
# $1 is name, in caps.
override act_section = $(if $(display_help),$(info -- $(strip $1) --$(lf)))


# MISC

$(call act, help \
,,Display this information and exit.)
	@true


# PACKAGE DATABASE
$(call act_section, PACKAGE DATABASE )

# Lists all available packages in the repo, without versions.
$(call act, list-all \
,,List all packages available in the repository.$(lf)Doesn't output package versions.))
	$(foreach x,$(database_query_available),$(info $x))
	@true

# Downloads a new database. Backups the old one as `database.mk.bak`
$(call act, update-database \
,,Download a new database. The existing database will be backed up.)
	$(if $(wildcard database.mk),$(call safe_shell_exec,mv -f 'database.mk' 'database.mk.bak' || true))
	$(call safe_shell_exec,rm -rf '$(database_tmp_dir)')
	$(call safe_shell_exec,rm -f '$(database_tmp_file)')
	$(database_query_empty)
	@true

# Accepts a list of packages. Returns the same list, but with package versions specified.
$(call act, get-ver \
,packages,Print the specified packages with version numbers added.)
	$(foreach x,$(call database_query_full_name,$p),$(info $x))
	@true

# Accepts a is a list of packages. Returns the same list, with all dependencies added.
$(call act, get-deps \
,packages,Print the specified packages and all their dependencies.)
	$(foreach x,$(call database_query_deps,$p),$(info $x))
	@true

# Cleans the database.
$(call act, clean-database \
,,Delete the package database$(comma) which contains the information about the repository.\
$(lf)A new database will be downloaded next time it is needed.)
	@rm -f database.mk database.mk.bak $(database_tmp_file)
	@rm -rf '$(database_tmp_dir)'


# PACKAGE MANAGEMENT
$(call act_section, PACKAGE MANAGEMENT )

# Lists all installed packages, with versions.
$(call act, list-ins \
,,List all installed packages$(comma) with versions.$(lf)The list includes automatically installed dependencies.)
	$(foreach x,$(index_list_all_installed),$(info $x))
	@true

# Lists all requested packages, without versions.
$(call act, list-req \
,,List all explicitly requested packages.)
	$(foreach x,$(pkg_request_list),$(info $x))
	@true

# Installs packages (without versions specified).
$(call act, install \
,packages,Installs packages.$(lf)Equivalent to 'make request' followed by 'make apply-delta'.)
	$(call pkg_request_list_add,$p)
	$(info Will apply following changes:)
	$(eval override _local_delta := $(pkg_compute_delta))
	$(call pkg_pretty_print_delta_fancy,$(_local_delta))
	$(call pkg_apply_delta,$(_local_delta))
	@true

# Removes packages (without versions specified).
$(call act, remove \
,packages,Removes packages.$(lf)Equivalent to 'make undo-request' followed by 'make apply-delta'.)
	$(call pkg_request_list_remove,$p)
	$(info Will apply following changes:)
	$(eval override _local_delta := $(pkg_compute_delta))
	$(call pkg_pretty_print_delta_fancy,$(_local_delta))
	$(call pkg_apply_delta,$(_local_delta))
	@true

# Removes all packages (without versions specified).
$(call act, remove-all-packages \
,,Removes all packages.)
	$(call pkg_request_list_reset)
	$(info Will apply following changes:)
	$(eval override _local_delta := $(pkg_compute_delta))
	$(call pkg_pretty_print_delta_fancy,$(_local_delta))
	$(call pkg_apply_delta,$(_local_delta))
	@true

# Updates the database, upgrades packages, and fixes stuff.
$(call act, upgrade \
,,Updates package database and upgrades packages.)
	$(call safe_shell_exec, $(MAKE) 1>&2 upgrade-keep-cache)
	$(call safe_shell_exec, $(MAKE) 1>&2 cache-remove-unused)
	@true

# Updates the database, upgrades packages, and fixes stuff. Doesn't remove old archives from the cache.
$(call act, upgrade-keep-cache \
,,Updates package database and upgrades packages.\
$(lf)Doesn't remove unused entries from the cache.)
	$(call safe_shell_exec, $(MAKE) 1>&2 update-database)
	$(info Will apply following changes:)
	$(call safe_shell_exec, $(MAKE) 1>&2 delta)
	$(call safe_shell_exec, $(MAKE) 1>&2 apply-delta)
	$(info Cleaning up...)
	$(call safe_shell_exec, $(MAKE) 1>&2 purge-broken)
	$(call safe_shell_exec, $(MAKE) 1>&2 cache-purge-unfinished)
	@true

# Updates the database, upgrades packages, and fixes stuff. Doesn't remove old archives from the cache.
$(call act, upgrade-clean-cache \
,,Updates package database and upgrades packages.\
$(lf)Cleans the cache.)
	$(call safe_shell_exec, $(MAKE) 1>&2 upgrade-keep-cache)
	$(call safe_shell_exec, $(MAKE) 1>&2 clean-cache)
	@true

# Adds packages (without versions) to the request list.
$(call act, request \
,packages,Request packages to be installed.$(lf)The packages and their dependencies will be\
$(lf)installed next time 'make apply-delta' is called.)
	$(call pkg_request_list_add,$p)
	@true

# Removes packages (without versions) from the request list.
$(call act, undo-request \
,packages,Request packages to not be installed.$(lf)The packages and any dependencies that are no longer needed\
$(lf)will be removed next time 'make apply-delta' is called.)
	$(call pkg_request_list_remove,$p)
	@true

# Cleans the request list.
$(call act, clean-requests \
,,Clean the list of requested packages.)
	$(call pkg_request_list_reset)
	@true

# Prints the current delta.
$(call act, delta \
,,Prints the list of changes that should be applied to the installed packages to make sure\
$(lf)that the latest versions of the requested packages and their dependencies are installed.\
$(lf)`+` prefix means the package should be installed$(comma)\
$(lf)`-` prefix means the package should be removed$(comma) and\
$(lf)`>` prefix means the package should be updated.)
	$(call pkg_pretty_print_delta_fancy,$(pkg_compute_delta))
	@true

# Prints the current delta, in a simple form.
$(call act, simple-delta \
,,Similar to `make delta`$(comma) but only displays 'install' and 'remove' actions.\
$(lf)Other actions are represented in terms of those two.)
	$(call pkg_pretty_print_delta,$(pkg_compute_delta))
	@true

# Applies the current delta.
$(call act, apply-delta \
,,Installs all requested packages and their dependencies$(comma)\
$(lf)or updates them to latest known versions.\
$(lf)Use `make delta` to preview the changes before applying them.)
	$(call pkg_apply_delta,$(pkg_compute_delta))
	@true

# Accepts a list of installed packages, with versions. Returns the list of files that belong to those packages.
$(call act, list-pkg-contents \
,package-versions,List all files owned by the specified installed packages.)
	$(foreach x,$(call index_list_pkg_files,$p),$(info $(subst <, ,$x)))
	@true

# Accepts a list of packages, without versions.
# Installs those packages, without considering their dependencies.
$(call act, unmanaged-install \
,packages,Install specified packages$(comma) without dependencies.\
$(lf)Normally you don't need to use this command$(comma) since its effects\
$(lf)will be undone automatically next time you invoke a non-unmanaged command.)
	$(call index_force_install,$(call database_query_full_name,$p))
	@true

# Same as `unmanaged-install`, but you need to specify package versions manually.
$(call act, unmanaged-install-ver \
,package-versions,Install specified package versions$(comma) without dependencies.\
$(lf)Normally you don't need to use this command$(comma) since its effects\
$(lf)will be undone automatically next time you invoke a non-unmanaged command.)
	$(call index_force_install,$p)
	@true

# Accepts a list of packages, with versions.
# Removes those packages, without considering their dependencies.
$(call act, unmanaged-remove-ver \
,package-versions,Remove specified packages$(comma) without dependencies.\
$(lf)Normally you don't need to use this command$(comma) since its effects\
$(lf)will be undone automatically next time you invoke a non-unmanaged command.)
	$(call index_force_uninstall,$p)
	@true


# BROKEN PACKAGES
$(call act_section, BROKEN PACKAGES )

# Lists broken packages.
# A package can become broken if you interrupt its installation or removal.
# Run `purge-broken` to destroy those.
$(call act, list-broken \
,,List all broken packages.$(lf)A package might become broken if you interrupt its installation or removal.)
	$(foreach x,$(patsubst $(index_dir)/$(index_broken_prefix)%,%,$(wildcard $(index_dir)/$(index_broken_prefix)*)),$(info $x))
	@true

# Destroys broken packages.
$(call act, purge-broken \
,,Destroys all broken packages.)
	$(index_purge_broken)
	@true


# PACKAGE CACHE
$(call act_section, PACKAGE CACHE )

# Returns a list of cached packages, with versions.
$(call act, list-cached \
,,List all cached packages archives.$(lf)Incomplete archives will be prefixed with `$(cache_unfinished_prefix)`.)
	$(foreach x,$(cache_list_current),$(info $x))
	@true

# Removes incomplete downloads from the cache.
$(call act, cache-purge-unfinished \
,,Delete incomplete cached archives$(comma) which might appear if you interrupt a download.)
	$(cache_purge_unfinished)
	@true

# Cleans the cache.
$(call act, clean-cache \
,,Clean the entire archive cache.)
	$(foreach x,$(wildcard $(CACHE_DIR)/*),$(call safe_shell_exec,rm -f '$x'))
	@true

# Accepts a list of packages, without versions. Downloads them, if they are not already in the cache.
$(call act, cache-download \
,packages,Download specified packages to the cache.)
	$(call cache_want_packages,$(call database_query_full_name,$p))
	@true

# Same as `cache-download`, but you need to specify package versions manually.
$(call act, cache-download-ver \
,package-versions,Download specified package versions to the cache.)
	$(call cache_want_packages,$p)
	@true

# Lists packages that are installed but not cached.
$(call act, cache-list-missing \
,,Lists all installed packages that are not cached.)
	$(foreach x,$(cache_list_missing),$(info $x))
	@true

# Lists packages that are cached but not installed.
$(call act, cache-list-unused \
,,Lists all cached packages that are not installed.)
	$(foreach x,$(cache_list_unused),$(info $x))
	@true

# Caches packages that are currently installed.
$(call act, cache-add-missing \
,,Caches all installed packages.)
	$(call cache_want_packages,$(cache_list_missing))
	@true

# Removes packages that are not currently installed from cache.
$(call act, cache-remove-unused \
,,Removes packages that are not currently installed from the cache.)
	$(foreach x,$(cache_list_unused),\
		$(call safe_shell_exec,rm -f '$(CACHE_DIR)/$x$(REPO_PACKAGE_ARRCHIVE_SUFFIX)')\
		$(info Removed '$x' from cache)\
		)
	@true

# Updates the database, upgrades packages, and fixes stuff. Doesn't remove old archives from the cache.
$(call act, cache-installed-only \
,,Make sure the cache contains all installed packages, and nothign else.)
	$(call safe_shell_exec, $(MAKE) 1>&2 cache-add-missing)
	$(call safe_shell_exec, $(MAKE) 1>&2 cache-remove-unused)
	@true

# Accepts a list of packages, without versions. Outputs the list of files contained in them.
$(call act, cache-list-pkg-contents \
,package-versions,Output a list of files contained in the specified cached packages.)
	$(foreach x,$(call cache_list_pkg_files,$p),$(info $(subst <, ,$x)))
	@true

# NOTES
$(call act_section, NOTES )

$(if $(display_help),\
	$(info When passing a package name to a command,)\
	$(info you can use `_` instead of the `$(REPO_PACKAGE_COMMON_PREFIX)` prefix.)\
	$(info )\
	)
