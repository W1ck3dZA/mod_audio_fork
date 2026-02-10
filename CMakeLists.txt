cmake_minimum_required(VERSION 3.10)
project(mod_audio_fork)

# Set C++ standard
set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Set C standard
set(CMAKE_C_STANDARD 99)
set(CMAKE_C_STANDARD_REQUIRED ON)

# Find required packages
find_package(PkgConfig REQUIRED)

# Find FreeSWITCH - Ubuntu 22.04 specific paths with better detection
set(FREESWITCH_SEARCH_PATHS
    /usr/include/freeswitch
    /usr/local/include/freeswitch
    /opt/freeswitch/include/freeswitch
    /usr/include
    /usr/local/include
    /opt/freeswitch/include
)

find_path(FREESWITCH_INCLUDE_DIR switch.h
    PATHS ${FREESWITCH_SEARCH_PATHS}
    NO_DEFAULT_PATH
)

if(NOT FREESWITCH_INCLUDE_DIR)
    find_path(FREESWITCH_INCLUDE_DIR switch.h)
endif()

# Try to find FreeSWITCH library in multiple locations
set(FREESWITCH_LIB_SEARCH_PATHS
    /usr/lib/x86_64-linux-gnu
    /usr/lib
    /usr/local/lib
    /opt/freeswitch/lib
    /usr/lib/freeswitch
)

find_library(FREESWITCH_LIBRARY
    NAMES freeswitch
    PATHS ${FREESWITCH_LIB_SEARCH_PATHS}
    NO_DEFAULT_PATH
)

if(NOT FREESWITCH_LIBRARY)
    find_library(FREESWITCH_LIBRARY NAMES freeswitch)
endif()

# If FreeSWITCH is still not found, try to find it via pkg-config
if(NOT FREESWITCH_INCLUDE_DIR OR NOT FREESWITCH_LIBRARY)
    pkg_check_modules(FREESWITCH_PKG freeswitch)
    if(FREESWITCH_PKG_FOUND)
        set(FREESWITCH_INCLUDE_DIR ${FREESWITCH_PKG_INCLUDE_DIRS})
        set(FREESWITCH_LIBRARY ${FREESWITCH_PKG_LIBRARIES})
        message(STATUS "Found FreeSWITCH via pkg-config")
    endif()
endif()

# Check if FreeSWITCH was found
if(NOT FREESWITCH_INCLUDE_DIR)
    message(FATAL_ERROR "FreeSWITCH headers not found. Please install FreeSWITCH development package:
    sudo apt-get install freeswitch-dev
    Or set FREESWITCH_INCLUDE_DIR manually.")
endif()

if(NOT FREESWITCH_LIBRARY)
    message(FATAL_ERROR "FreeSWITCH library not found. Please install FreeSWITCH:
    sudo apt-get install freeswitch
    Or set FREESWITCH_LIBRARY manually.")
endif()

# Find libwebsockets
pkg_check_modules(LIBWEBSOCKETS REQUIRED libwebsockets)

# Find speex
pkg_check_modules(SPEEX REQUIRED speex)

# Also try to find speexdsp which contains the resampler functions
find_library(SPEEXDSP_LIBRARY
    NAMES speexdsp
    PATHS
    /usr/lib/x86_64-linux-gnu
    /usr/lib
    /usr/local/lib
    NO_DEFAULT_PATH
)

if(NOT SPEEXDSP_LIBRARY)
    find_library(SPEEXDSP_LIBRARY NAMES speexdsp)
endif()

# If speexdsp is not found, try to find it via pkg-config
if(NOT SPEEXDSP_LIBRARY)
    pkg_check_modules(SPEEXDSP speexdsp)
    if(SPEEXDSP_FOUND)
        set(SPEEXDSP_LIBRARY ${SPEEXDSP_LIBRARIES})
    endif()
endif()

# Find boost - Ubuntu 22.04 specific
find_package(Boost REQUIRED COMPONENTS system thread)

# Find boost circular_buffer (header-only) - Ubuntu 22.04 paths
find_path(BOOST_INCLUDE_DIR boost/circular_buffer.hpp
    PATHS
    /usr/include
    /usr/local/include
    /opt/homebrew/include
    NO_DEFAULT_PATH
)

if(NOT BOOST_INCLUDE_DIR)
    find_path(BOOST_INCLUDE_DIR boost/circular_buffer.hpp)
endif()

# Set source files
set(MOD_AUDIO_FORK_SOURCES
    mod_audio_fork.c
    lws_glue.cpp
    parser.cpp
    audio_pipe.cpp
    vector_math.cpp
)

# Create shared library
add_library(mod_audio_fork SHARED ${MOD_AUDIO_FORK_SOURCES})

# Set include directories
target_include_directories(mod_audio_fork PRIVATE
    ${FREESWITCH_INCLUDE_DIR}
    ${LIBWEBSOCKETS_INCLUDE_DIRS}
    ${SPEEX_INCLUDE_DIRS}
    ${BOOST_INCLUDE_DIRS}
    ${BOOST_INCLUDE_DIR}
    ${CMAKE_CURRENT_SOURCE_DIR}
)

# Set compile definitions
target_compile_definitions(mod_audio_fork PRIVATE
    MOD_AUDIO_FORK_BUILD
    SWITCH_PACKAGE_VERSION="1.0.0"
    _GNU_SOURCE
)

# Set compile flags - Ubuntu 22.04 optimized
target_compile_options(mod_audio_fork PRIVATE
    $<$<CXX_COMPILER_ID:GNU>:-Wall -Wextra -fPIC -O2>
    $<$<CXX_COMPILER_ID:Clang>:-Wall -Wextra -fPIC -O2>
    $<$<C_COMPILER_ID:GNU>:-Wall -Wextra -fPIC -O2>
    $<$<C_COMPILER_ID:Clang>:-Wall -Wextra -fPIC -O2>
)

# Check for AVX2 support - Ubuntu 22.04 typically supports this
include(CheckCXXCompilerFlag)
check_cxx_compiler_flag("-mavx2" COMPILER_SUPPORTS_AVX2)
if(COMPILER_SUPPORTS_AVX2)
    target_compile_options(mod_audio_fork PRIVATE -mavx2)
    target_compile_definitions(mod_audio_fork PRIVATE USE_AVX2)
    message(STATUS "Using AVX2 optimizations")
else()
    # Check for SSE2 support
    check_cxx_compiler_flag("-msse2" COMPILER_SUPPORTS_SSE2)
    if(COMPILER_SUPPORTS_SSE2)
        target_compile_options(mod_audio_fork PRIVATE -msse2)
        target_compile_definitions(mod_audio_fork PRIVATE USE_SSE2)
        message(STATUS "Using SSE2 optimizations")
    endif()
endif()

# Link libraries
target_link_libraries(mod_audio_fork
    ${FREESWITCH_LIBRARY}
    ${LIBWEBSOCKETS_LIBRARIES}
    ${SPEEX_LIBRARIES}
    ${SPEEXDSP_LIBRARY}
    ${Boost_LIBRARIES}
    stdc++
    pthread
    dl
)

# Set link flags - Ubuntu 22.04 specific
set_target_properties(mod_audio_fork PROPERTIES
    PREFIX ""
    SUFFIX ".so"
    BUILD_WITH_INSTALL_RPATH TRUE
    INSTALL_RPATH "/usr/lib/freeswitch/mod"
)

# Set linker flags correctly for FreeSWITCH module
target_link_options(mod_audio_fork PRIVATE
    -Wl,-no-undefined
    -Wl,-shared
)

# Install target - Ubuntu 22.04 paths
install(TARGETS mod_audio_fork
    LIBRARY DESTINATION lib/freeswitch/mod
    PERMISSIONS OWNER_READ OWNER_WRITE GROUP_READ WORLD_READ
)

# Print configuration info
message(STATUS "=== mod_audio_fork Configuration ===")
message(STATUS "FreeSWITCH include dir: ${FREESWITCH_INCLUDE_DIR}")
message(STATUS "FreeSWITCH library: ${FREESWITCH_LIBRARY}")
message(STATUS "libwebsockets: ${LIBWEBSOCKETS_LIBRARIES}")
message(STATUS "speex: ${SPEEX_LIBRARIES}")
message(STATUS "speexdsp: ${SPEEXDSP_LIBRARY}")
message(STATUS "boost: ${Boost_LIBRARIES}")
message(STATUS "boost include dir: ${BOOST_INCLUDE_DIR}")
message(STATUS "Build type: ${CMAKE_BUILD_TYPE}")
message(STATUS "C++ standard: ${CMAKE_CXX_STANDARD}")
message(STATUS "C standard: ${CMAKE_C_STANDARD}")

