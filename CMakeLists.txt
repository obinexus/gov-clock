cmake_minimum_required(VERSION 3.16)
project(OBINexus_DOP_Components 
    VERSION 1.0.0 
    DESCRIPTION "OBINexus Data-Oriented Programming Component System"
    LANGUAGES C)

# OBINexus Build Configuration
set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)
set(CMAKE_C_EXTENSIONS OFF)

# Build Type Configuration
if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE "Debug" CACHE STRING "Build type" FORCE)
endif()

# OBINexus Compiler Flags
set(CMAKE_C_FLAGS_DEBUG "-g -O0 -Wall -Wextra -Wpedantic -DDOP_DEBUG=1")
set(CMAKE_C_FLAGS_RELEASE "-O3 -DNDEBUG -DDOP_RELEASE=1")

# Threading Support (Required for P2P Topology)
find_package(Threads REQUIRED)

# XML Processing Library for Manifest Support
find_package(PkgConfig REQUIRED)
pkg_check_modules(LIBXML2 REQUIRED libxml-2.0)

# Include Directories
include_directories(${CMAKE_CURRENT_SOURCE_DIR}/include)
include_directories(${LIBXML2_INCLUDE_DIRS})

# Source Files
set(DOP_CORE_SOURCES
    src/obinexus_dop_core.c
    src/dop_adapter.c
    src/dop_topology.c
    src/dop_manifest.c
    src/components/alarm.c
    src/components/clock.c
    src/components/stopwatch.c
    src/components/timer.c
)

# Header Files
set(DOP_CORE_HEADERS
    include/obinexus_dop_core.h
    include/dop_adapter.h
    include/dop_topology.h
    include/dop_manifest.h
)

# Main DOP Library Target
add_library(obinexus_dop_core STATIC ${DOP_CORE_SOURCES})
target_link_libraries(obinexus_dop_core 
    ${CMAKE_THREAD_LIBS_INIT}
    ${LIBXML2_LIBRARIES}
)
target_compile_options(obinexus_dop_core PRIVATE ${LIBXML2_CFLAGS_OTHER})

# Demo Application
add_executable(dop_demo 
    src/demo/dop_demo.c
    src/demo/p2p_topology_test.c
    src/demo/func_oop_conversion_test.c
)
target_link_libraries(dop_demo obinexus_dop_core)

# Unit Tests
enable_testing()
add_executable(dop_tests
    tests/test_components.c
    tests/test_topology.c
    tests/test_manifest.c
    tests/test_adapter.c
)
target_link_libraries(dop_tests obinexus_dop_core)

# Test Registration
add_test(NAME component_tests COMMAND dop_tests component)
add_test(NAME topology_tests COMMAND dop_tests topology)
add_test(NAME manifest_tests COMMAND dop_tests manifest)
add_test(NAME adapter_tests COMMAND dop_tests adapter)

# P2P Fault Tolerance Test
add_test(NAME p2p_fault_test COMMAND dop_demo --test-p2p-fault)

# XML Manifest Validation Test
add_test(NAME xml_manifest_test COMMAND dop_demo --test-xml-manifest)

# Custom Build Targets
add_custom_target(validate_manifest
    COMMAND ${CMAKE_CURRENT_BINARY_DIR}/dop_demo --validate-manifest 
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
    COMMENT "Validating XML manifest schema"
)

add_custom_target(test_p2p_topology
    COMMAND ${CMAKE_CURRENT_BINARY_DIR}/dop_demo --test-p2p-topology
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
    COMMENT "Testing P2P fault-tolerant topology"
)

# Install Configuration
install(TARGETS obinexus_dop_core dop_demo
    LIBRARY DESTINATION lib
    ARCHIVE DESTINATION lib
    RUNTIME DESTINATION bin
)

install(FILES ${DOP_CORE_HEADERS}
    DESTINATION include/obinexus
)

install(FILES schemas/dop_manifest.xsd
    DESTINATION share/obinexus/schemas
)

# CPack Configuration for Distribution
set(CPACK_PACKAGE_NAME "OBINexus-DOP-Components")
set(CPACK_PACKAGE_VERSION_MAJOR 1)
set(CPACK_PACKAGE_VERSION_MINOR 0)
set(CPACK_PACKAGE_VERSION_PATCH 0)
set(CPACK_PACKAGE_DESCRIPTION_SUMMARY "OBINexus Data-Oriented Programming Component System")
include(CPack)
