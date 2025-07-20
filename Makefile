# OBINexus DOP Components Makefile
# Alternative build system for environments without CMake

# Compiler Configuration
CC = gcc
CFLAGS = -std=c11 -Wall -Wextra -Wpedantic -pthread
LDFLAGS = -pthread -lxml2

# Debug/Release Configuration
DEBUG_CFLAGS = $(CFLAGS) -g -O0 -DDOP_DEBUG=1
RELEASE_CFLAGS = $(CFLAGS) -O3 -DNDEBUG -DDOP_RELEASE=1

# Directories
SRC_DIR = src
INCLUDE_DIR = include
BUILD_DIR = build
TEST_DIR = tests
DEMO_DIR = src/demo

# Source Files
CORE_SOURCES = $(wildcard $(SRC_DIR)/*.c) $(wildcard $(SRC_DIR)/components/*.c)
TEST_SOURCES = $(wildcard $(TEST_DIR)/*.c)
DEMO_SOURCES = $(wildcard $(DEMO_DIR)/*.c)

# Object Files
CORE_OBJECTS = $(CORE_SOURCES:%.c=$(BUILD_DIR)/%.o)
TEST_OBJECTS = $(TEST_SOURCES:%.c=$(BUILD_DIR)/%.o)
DEMO_OBJECTS = $(DEMO_SOURCES:%.c=$(BUILD_DIR)/%.o)

# Targets
STATIC_LIB = $(BUILD_DIR)/libobinexus_dop_core.a
DEMO_EXECUTABLE = $(BUILD_DIR)/dop_demo
TEST_EXECUTABLE = $(BUILD_DIR)/dop_tests

# Default Target
all: debug

# Debug Build
debug: CFLAGS := $(DEBUG_CFLAGS)
debug: $(STATIC_LIB) $(DEMO_EXECUTABLE) $(TEST_EXECUTABLE)

# Release Build
release: CFLAGS := $(RELEASE_CFLAGS)
release: $(STATIC_LIB) $(DEMO_EXECUTABLE) $(TEST_EXECUTABLE)

# Static Library
$(STATIC_LIB): $(CORE_OBJECTS) | $(BUILD_DIR)
	ar rcs $@ $^

# Demo Executable
$(DEMO_EXECUTABLE): $(DEMO_OBJECTS) $(STATIC_LIB) | $(BUILD_DIR)
	$(CC) $(DEMO_OBJECTS) $(STATIC_LIB) $(LDFLAGS) -o $@

# Test Executable
$(TEST_EXECUTABLE): $(TEST_OBJECTS) $(STATIC_LIB) | $(BUILD_DIR)
	$(CC) $(TEST_OBJECTS) $(STATIC_LIB) $(LDFLAGS) -o $@

# Object File Compilation
$(BUILD_DIR)/%.o: %.c | $(BUILD_DIR)
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) -I$(INCLUDE_DIR) -c $< -o $@

# Create Build Directory
$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

# Test Targets
test: $(TEST_EXECUTABLE)
	$(TEST_EXECUTABLE) component
	$(TEST_EXECUTABLE) topology
	$(TEST_EXECUTABLE) manifest
	$(TEST_EXECUTABLE) adapter

test-p2p: $(DEMO_EXECUTABLE)
	$(DEMO_EXECUTABLE) --test-p2p-fault

test-manifest: $(DEMO_EXECUTABLE)
	$(DEMO_EXECUTABLE) --test-xml-manifest

# Validation Targets
validate-manifest: $(DEMO_EXECUTABLE)
	$(DEMO_EXECUTABLE) --validate-manifest

validate-schema:
	xmllint --schema schemas/dop_manifest.xsd examples/time_components_manifest.xml --noout

# Clean
clean:
	rm -rf $(BUILD_DIR)

# Install
install: release
	install -d /usr/local/lib
	install -d /usr/local/include/obinexus
	install -d /usr/local/share/obinexus/schemas
	install $(STATIC_LIB) /usr/local/lib/
	install $(DEMO_EXECUTABLE) /usr/local/bin/
	install $(INCLUDE_DIR)/*.h /usr/local/include/obinexus/
	install schemas/dop_manifest.xsd /usr/local/share/obinexus/schemas/

# Uninstall
uninstall:
	rm -f /usr/local/lib/libobinexus_dop_core.a
	rm -f /usr/local/bin/dop_demo
	rm -rf /usr/local/include/obinexus
	rm -rf /usr/local/share/obinexus

# Help
help:
	@echo "OBINexus DOP Components Build System"
	@echo "Available targets:"
	@echo "  all              - Build debug version (default)"
	@echo "  debug            - Build debug version"
	@echo "  release          - Build release version"
	@echo "  test             - Run unit tests"
	@echo "  test-p2p         - Run P2P topology tests"
	@echo "  test-manifest    - Run XML manifest tests"
	@echo "  validate-manifest - Validate XML manifest"
	@echo "  validate-schema  - Validate XML schema"
	@echo "  clean            - Clean build files"
	@echo "  install          - Install system-wide"
	@echo "  uninstall        - Uninstall system-wide"
	@echo "  help             - Show this help"

.PHONY: all debug release 
test test-p2p test-manifest 
validate-manifest 
validate-schema clean install 
uninstall help
