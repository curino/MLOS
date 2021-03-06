# -----------------------------------------------------------------------------
# CMake project wrapper Makefile
# This allows us to simply run "make" in various source dirs.
# We support targetting Debug vs. Release configurations using the
# CONFIGURATION environment variable.
# See Also: https://stackoverflow.com/a/29678916/10772564
# -----------------------------------------------------------------------------

RelativePathToProjectRoot := .
include ./build/Common.mk

handledtargets += cmake-build cmake-test cmake-clean \
		  cmake-buildfiles clean-cmake-buildfiles \
		  cmake-distclean $(CMAKE) \
		  python-checks python-test \
		  grpc-clean mlos-codegen-clean

# Build using dotnet and the Makefile produced by cmake.
.PHONY: all
all: dotnet-build cmake-build python-checks
	@ echo "make all target finished."

.PHONY: test
test: dotnet-test cmake-test python-test
	@ echo "make test target finished."

.PHONY: check
check: all test

.PHONY: clean
clean: cmake-clean dotnet-clean grpc-clean mlos-codegen-clean

.PHONY: distclean
distclean: clean cmake-distclean

.PHONY: rebuild
rebuild: clean all

# Somewhat overkill clean rules - they just nuke the top-level output directories.

.PHONY: mlos-codegen-clean
mlos-codegen-clean: dotnet-clean
	@ $(RM) $(MLOS_ROOT)/Mlos.CodeGen.out

.PHONY: grpc-clean
grpc-clean:
	@ $(RM) $(MLOS_ROOT)/Grpc.out


# Build the dirs.proj file in this directory with "dotnet build"
include $(MLOS_ROOT)/build/DotnetWrapperRules.mk

# For the rest, the top-level CMakeLists.txt is special,
# so we don't use the CMakeWrapperRules.mk file.

ConfigurationCmakeDir := $(CmakeBuildDir)/$(CONFIGURATION)
ConfigurationMakefile := $(ConfigurationCmakeDir)/Makefile
CmakeGenerator := "Unix Makefiles"

handledtargets += $(ConfigurationMakefile)

.PHONY: cmake-build
cmake-build: $(ConfigurationMakefile)
	@  $(MAKE) -C $(ConfigurationCmakeDir)
	@ echo "make cmake-build target finished."

.PHONY: cmake-test
cmake-test: $(ConfigurationMakefile)
	@  $(MAKE) -C $(ConfigurationCmakeDir) test

.PHONY: cmake-check
cmake-check:
	@  $(MAKE) -C $(ConfigurationCmakeDir) check

.NOTPARALLEL: cmake-clean
.PHONY: cmake-clean
cmake-clean:
	@- $(MAKE) -C $(MLOS_ROOT) $(ConfigurationMakefile) || true
	@- $(MAKE) -C $(ConfigurationCmakeDir) clean || true

.PHONY: cmake-buildfiles
cmake-buildfiles: $(ConfigurationMakefile)

# Create the build Makefile using cmake.
.NOTPARALLEL: $(ConfigurationMakefile)
.PHONY: $(ConfigurationMakefile)
$(ConfigurationMakefile): $(CMAKE) CMakeLists.txt
	@  $(MKDIR) $(ConfigurationCmakeDir) > /dev/null
	@  $(CMAKE) -D CMAKE_BUILD_TYPE=$(CONFIGURATION) -S $(MLOS_ROOT) -B $(ConfigurationCmakeDir) -G $(CmakeGenerator)

.PHONY: clean-cmake-buildfiles
clean-cmake-buildfiles:
	@ $(RM) $(ConfigurationCmakeDir)/CMakeCache.txt
	@ $(RM) $(ConfigurationCmakeDir)/_deps
	@ $(RM) $(ConfigurationMakefile)

# Fetch a specific version of cmake.
.NOTPARALLEL: $(CMAKE)
$(CMAKE): ./scripts/fetch-cmake.sh
	@  ./scripts/fetch-cmake.sh

.PHONY: python-checks
python-checks:
	@ ./scripts/run-python-checks.sh
	@ echo "make python-checks target finished."

.PHONY: python-test
python-test:
	@ ./scripts/run-python-tests.sh
	@ echo "make python-test target finished."

# Don't force cmake regen every time we run ctags - only if it doesn't exist
.PHONY: ctags
ctags:
	@  test -e $(ConfigurationMakefile) || $(MAKE) -C . $(ConfigurationMakefile)
	@  $(MAKE) -C $(ConfigurationCmakeDir) ctags

# Cleanup the outputs produced by cmake.
.PHONY: cmake-distclean
cmake-distclean: cmake-clean
	@- $(RM) $(ConfigurationCmakeDir)/Makefile
	@- $(RM) $(ConfigurationCmakeDir)/*.ninja
	@- $(RM) $(ConfigurationCmakeDir)/_deps
	@- $(RM) $(ConfigurationCmakeDir)/source
	@- $(RM) $(ConfigurationCmakeDir)/test
	@- $(RM) $(ConfigurationCmakeDir)/CMake*
	@- $(RM) $(ConfigurationCmakeDir)/cmake.*
	@- $(RM) $(ConfigurationCmakeDir)/*.cmake
	@- $(RM) $(ConfigurationCmakeDir)/*.json
	@- $(RM) $(ConfigurationCmakeDir)/*.txt

# Send all other targets to the Makefile produced by cmake.
unhandledtargets := $(filter-out $(handledtargets),$(MAKECMDGOALS))
ifneq ($(unhandledtargets),)
$(unhandledtargets): $(ConfigurationMakefile)
	@ $(MAKE) -C $(ConfigurationCmakeDir) $(unhandledtargets)
endif
