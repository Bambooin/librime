RIME_ROOT ?= $(CURDIR)

RIME_SOURCE_PATH = plugins sample src test tools
RIME_THIRD_PARTY_PATH = plugins/*/

CLANG_TIDY_ROOT_RE = $(shell python3 -c \
	'import re, sys; print(re.escape(sys.argv[1]))' \
	"$(abspath $(RIME_ROOT))")

THIRD_PARTY_RE = $(subst *,[^/]+,$(RIME_THIRD_PARTY_PATH))

CLANG_TIDY_SOURCE_FILTER = ^$(CLANG_TIDY_ROOT_RE)/(?!$(THIRD_PARTY_RE)|deps/)

CLANG_FORMAT_FIND = find -L $(RIME_SOURCE_PATH) \
	\! -path '$(RIME_THIRD_PARTY_PATH)*' \
	-a \( -name '*.cc' -o -name '*.cpp' -o -name '*.cxx' \
	-o -name '*.h' -o -name '*.hpp' -o -false \)

LINT_TIP = Please lint your code by 'make $(1)-apply'.

LLVM_MAJOR_VERSION ?= 23

OS_NAME = $(shell uname)
ifdef BOOST_ROOT
CMAKE_BOOST_OPTIONS = -DBoost_NO_BOOST_CMAKE=TRUE \
	-DBOOST_ROOT="$(BOOST_ROOT)"
endif

TIDY_BOOST_OPTIONS = -DBoost_NO_BOOST_CMAKE=TRUE
ifdef BOOST_ROOT
TIDY_BOOST_OPTIONS += -DBOOST_ROOT="$(BOOST_ROOT)"
else
ifneq ($(wildcard $(RIME_ROOT)/deps/boost),)
TIDY_BOOST_OPTIONS += -DBOOST_ROOT="$(RIME_ROOT)/deps/boost"
endif
endif

ifeq ($(OS_NAME),Darwin) # for macOS
prefix ?= $(RIME_ROOT)/dist

# https://cmake.org/cmake/help/latest/variable/CMAKE_OSX_SYSROOT.html
export SDKROOT ?= $(shell xcrun --sdk macosx --show-sdk-path)

# https://cmake.org/cmake/help/latest/envvar/MACOSX_DEPLOYMENT_TARGET.html
export MACOSX_DEPLOYMENT_TARGET ?= 10.15

ifdef BUILD_UNIVERSAL
# https://cmake.org/cmake/help/latest/envvar/CMAKE_OSX_ARCHITECTURES.html
export CMAKE_OSX_ARCHITECTURES = arm64;x86_64
endif
else ifeq ($(shell test -n "$$PREFIX" && echo "$$PREFIX" | grep -q "/data/data/com.termux" && echo "termux"),termux)
prefix ?= $(PREFIX)
else ifeq ($(OS_NAME),FreeBSD)
prefix ?= $(DESTDIR)/usr/local
else ifeq ($(OS_NAME),OpenBSD)
prefix ?= $(DESTDIR)/usr/local
else # for Linux
prefix ?= $(DESTDIR)/usr
endif

ifndef NOPARALLEL
  MAKEFLAGS += -j$(shell expr $$(nproc 2>/dev/null || getconf _NPROCESSORS_ONLN 2>/dev/null || getconf NPROCESSORS_ONLN 2>/dev/null || echo 8) + 1)
endif

debug install-debug uninstall-debug test-debug: build ?= debug
build ?= build
tidy-build ?= build-tidy

.PHONY: all lint apply llvm-major-version deps clean \
librime librime-static merged-plugins no-logging \
release debug test install uninstall \
install-debug uninstall-debug \
clang-format-lint clang-format-apply \
clang-tidy-check clang-tidy-lint clang-tidy-apply

all: release

lint: clang-format-lint clang-tidy-lint

.NOTPARALLEL: apply
apply: clang-format-apply clang-tidy-apply

llvm-major-version:
	@echo $(LLVM_MAJOR_VERSION)

clang-format-lint:
	clang-format --version
	$(CLANG_FORMAT_FIND) -exec clang-format --verbose -Werror --dry-run {} + || \
	{ echo "$(call LINT_TIP,clang-format)"; false; }

clang-format-apply:
	$(CLANG_FORMAT_FIND) -exec clang-format --verbose -i {} +

clang-tidy-check:
	cmake . -B$(tidy-build) -DCMAKE_BUILD_TYPE=Debug \
	-DBUILD_MERGED_PLUGINS=OFF -DENABLE_EXTERNAL_PLUGINS=ON -DBUILD_SAMPLE=ON \
	$(TIDY_BOOST_OPTIONS)
	clang-tidy --verify-config
	clang-tidy --version

clang-tidy-lint: clang-tidy-check
	run-clang-tidy -p $(tidy-build) -quiet -warnings-as-errors='*' \
	-source-filter='$(CLANG_TIDY_SOURCE_FILTER)' || \
	{ echo "$(call LINT_TIP,clang-tidy)"; false; }

clang-tidy-apply: clang-tidy-check
	run-clang-tidy -p $(tidy-build) -fix -format \
	-source-filter='$(CLANG_TIDY_SOURCE_FILTER)'

deps:
	$(MAKE) -f deps.mk

deps/%:
	$(MAKE) -f deps.mk $(@:deps/%=%)

clean:
	rm -r $(build) $(tidy-build) || true

librime: release

librime-static:
	cmake . -B$(build) \
	-DCMAKE_INSTALL_PREFIX=$(prefix) \
	-DCMAKE_BUILD_TYPE=Release \
	-DBUILD_STATIC=ON \
	-DBUILD_SHARED_LIBS=OFF \
	$(CMAKE_BOOST_OPTIONS)
	cmake --build $(build)

release:
	cmake . -B$(build) \
	-DCMAKE_INSTALL_PREFIX=$(prefix) \
	-DCMAKE_BUILD_TYPE=Release \
	-DBUILD_MERGED_PLUGINS=OFF \
	-DENABLE_EXTERNAL_PLUGINS=ON \
	$(CMAKE_BOOST_OPTIONS)
	cmake --build $(build)

merged-plugins:
	cmake . -B$(build) \
	-DCMAKE_INSTALL_PREFIX=$(prefix) \
	-DCMAKE_BUILD_TYPE=Release \
	-DBUILD_MERGED_PLUGINS=ON \
	-DENABLE_EXTERNAL_PLUGINS=OFF \
	$(CMAKE_BOOST_OPTIONS)
	cmake --build $(build)

no-logging:
	cmake . -B$(build) \
	-DCMAKE_INSTALL_PREFIX=$(prefix) \
	-DCMAKE_BUILD_TYPE=Release \
	-DENABLE_LOGGING=OFF \
	-DBUILD_MERGED_PLUGINS=OFF \
	-DENABLE_EXTERNAL_PLUGINS=ON \
	$(CMAKE_BOOST_OPTIONS)
	cmake --build $(build)

debug:
	cmake . -B$(build) \
	-DCMAKE_INSTALL_PREFIX=$(prefix) \
	-DCMAKE_BUILD_TYPE=Debug \
	-DBUILD_MERGED_PLUGINS=OFF \
	-DALSO_LOG_TO_STDERR=ON \
	-DENABLE_EXTERNAL_PLUGINS=ON \
	$(CMAKE_BOOST_OPTIONS)
	cmake --build $(build)

install:
	cmake --build $(build) --target install

install-debug:
	cmake --build $(build) --target install

uninstall:
	cmake --build $(build) --target remove

uninstall-debug:
	cmake --build $(build) --target remove

test: release
	(cd $(build); ctest --output-on-failure)

test-debug: debug
	(cd $(build); ctest --output-on-failure)
