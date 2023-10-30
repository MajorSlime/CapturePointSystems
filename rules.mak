# Ripped from QEMU:
# https://android.googlesource.com/platform/external/qemu/+/aca144a9e9264b11c2d729096af90d695d01455d/rules.mak

# Usage: $(call quiet-command,command and args,"NAME","args to print")
# This will run "command and args", and either:
#  if V=1 just print the whole command and args
#  otherwise print the 'quiet' output in the format "  NAME     args to print"
# NAME should be a short name of the command, 7 letters or fewer.
# If called with only a single argument, will print nothing in quiet mode.
quiet-command = $(if $(V),$1,$(if $(2),@printf "  %-7s %s\n" $2 $3 && $1 >/dev/null 2>&1, @$1))

# save-vars
# Usage: $(call save-vars, vars)
# Save each variable $v in $vars as save-vars-$v, save their object's
# variables, then clear $v.  saved-vars-$v contains the variables that
# where saved for the objects, in order to speedup load-vars.
define save-vars
    $(foreach v,$1,
        $(eval save-vars-$v := $(value $v))
        $(eval saved-vars-$v := $(foreach o,$($v), \
            $(if $($o-cflags), $o-cflags $(eval save-vars-$o-cflags := $($o-cflags))$(eval $o-cflags := )) \
            $(if $($o-libs), $o-libs $(eval save-vars-$o-libs := $($o-libs))$(eval $o-libs := )) \
            $(if $($o-objs), $o-objs $(eval save-vars-$o-objs := $($o-objs))$(eval $o-objs := ))))
        $(eval $v := ))
endef
# load-vars
# Usage: $(call load-vars, vars, add_var)
# Load the saved value for each variable in @vars, and the per object
# variables.
# Append @add_var's current value to the loaded value.
define load-vars
    $(eval $2-new-value := $(value $2))
    $(foreach v,$1,
        $(eval $v := $(value save-vars-$v))
        $(foreach o,$(saved-vars-$v),
            $(eval $o := $(save-vars-$o)) $(eval save-vars-$o := ))
        $(eval save-vars-$v := )
        $(eval saved-vars-$v := ))
    $(eval $2 := $(value $2) $($2-new-value))
endef
# fix-paths
# Usage: $(call fix-paths, obj_path, src_path, vars)
# Add prefix @obj_path to all objects in @vars, and add prefix @src_path to all
# directories in @vars.
define fix-paths
    $(foreach v,$3,
        $(foreach o,$($v),
            $(if $($o-libs),
                $(eval $1$o-libs := $($o-libs)))
            $(if $($o-cflags),
                $(eval $1$o-cflags := $($o-cflags)))
            $(if $($o-objs),
                $(eval $1$o-objs := $(addprefix $1,$($o-objs)))))
        $(eval $v := $(addprefix $1,$(filter-out %/,$($v))) \
                     $(addprefix $2,$(filter %/,$($v)))))
endef
# unnest-var-recursive
# Usage: $(call unnest-var-recursive, obj_prefix, vars, var)
#
# Unnest @var by including subdir Makefile.objs, while protect others in @vars
# unchanged.
#
# @obj_prefix is the starting point of object path prefix.
#
define unnest-var-recursive
    $(eval dirs := $(sort $(filter %/,$($3))))
    $(eval $3 := $(filter-out %/,$($3)))
    $(foreach d,$(dirs:%/=%),
            $(call save-vars,$2)
            $(eval obj := $(if $1,$1/)$d)
            $(eval -include $(SRC_PATH)/$d/Makefile.objs)
            $(call fix-paths,$(if $1,$1/)$d/,$d/,$2)
            $(call load-vars,$2,$3)
            $(call unnest-var-recursive,$1,$2,$3))
endef
# unnest-vars
# Usage: $(call unnest-vars, obj_prefix, vars)
#
# @obj_prefix: object path prefix, can be empty, or '..', etc. Don't include
# ending '/'.
#
# @vars: the list of variable names to unnest.
#
# This macro will scan subdirectories's Makefile.objs, include them, to build
# up each variable listed in @vars.
#
# Per object and per module cflags and libs are saved with relative path fixed
# as well, those variables include -libs, -cflags and -objs. Items in -objs are
# also fixed to relative path against SRC_PATH plus the prefix @obj_prefix.
#
# All nested variables postfixed by -m in names are treated as DSO variables,
# and will be built as modules, if enabled.
#
# A simple example of the unnest:
#
#     obj_prefix = ..
#     vars = hot cold
#     hot  = fire.o sun.o season/
#     cold = snow.o water/ season/
#
# Unnest through a faked source directory structure:
#
#     SRC_PATH
#        ├── water
#        │   └── Makefile.objs──────────────────┐
#        │       │ hot += steam.o               │
#        │       │ cold += ice.mo               │
#        │       │ ice.mo-libs := -licemaker    │
#        │       │ ice.mo-objs := ice1.o ice2.o │
#        │       └──────────────────────────────┘
#        │
#        └── season
#            └── Makefile.objs──────┐
#                │ hot += summer.o  │
#                │ cold += winter.o │
#                └──────────────────┘
#
# In the end, the result will be:
#
#     hot  = ../fire.o ../sun.o ../season/summer.o
#     cold = ../snow.o ../water/ice.mo ../season/winter.o
#     ../water/ice.mo-libs = -licemaker
#     ../water/ice.mo-objs = ../water/ice1.o ../water/ice2.o
#
# Note that 'hot' didn't include 'season/' in the input, so 'summer.o' is not
# included.
#
define unnest-vars
    # In the case of target build (i.e. $1 == ..), fix path for top level
    # Makefile.objs objects
    $(if $1,$(call fix-paths,$1/,,$2))
    # Descend and include every subdir Makefile.objs
    $(foreach v, $2,
        $(call unnest-var-recursive,$1,$2,$v)
        # Pass the .mo-cflags and .mo-libs along to its member objects
        $(foreach o, $(filter %.mo,$($v)),
            $(foreach p,$($o-objs),
                $(if $($o-cflags), $(eval $p-cflags += $($o-cflags)))
                $(if $($o-libs), $(eval $p-libs += $($o-libs))))))
    # For all %.mo objects that are directly added into -y, just expand them
    $(foreach v,$(filter %-y,$2),
        $(eval $v := $(foreach o,$($v),$(if $($o-objs),$($o-objs),$o))))
    $(foreach v,$(filter %-m,$2),
        # All .o found in *-m variables are single object modules, create .mo
        # for them
        $(foreach o,$(filter %.o,$($v)),
            $(eval $(o:%.o=%.mo)-objs := $o))
        # Now unify .o in -m variable to .mo
        $(eval $v := $($v:%.o=%.mo))
        $(eval modules-m += $($v))
        # For module build, build shared libraries during "make modules"
        # For non-module build, add -m to -y
        $(if $(CONFIG_MODULES),
             $(foreach o,$($v),
                   $(eval $($o-objs): CFLAGS += $(DSO_OBJ_CFLAGS))
                   $(eval $o: $($o-objs)))
             $(eval $(patsubst %-m,%-y,$v) += $($v))
             $(eval modules: $($v:%.mo=%$(DSOSUF))),
             $(eval $(patsubst %-m,%-y,$v) += $(call expand-objs, $($v)))))
    # Post-process all the unnested vars
    $(foreach v,$2,
        $(foreach o, $(filter %.mo,$($v)),
            # Find all the .mo objects in variables and add dependency rules
            # according to .mo-objs. Report error if not set
            $(if $($o-objs),
                $(eval $(o:%.mo=%$(DSOSUF)): module-common.o $($o-objs)),
                $(error $o added in $v but $o-objs is not set)))
        $(shell mkdir -p ./ $(sort $(dir $($v))))
        $(eval $v := $(filter-out %/,$($v))))
endef
