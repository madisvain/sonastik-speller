cmake_minimum_required(VERSION 3.20)
project(sonastik-speller LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS ON)

if(NOT APPLE)
  message(FATAL_ERROR "This milestone builds libvabamorf.dylib on macOS.")
endif()

if(NOT CMAKE_OSX_ARCHITECTURES)
  set(CMAKE_OSX_ARCHITECTURES "arm64;x86_64" CACHE STRING "Universal binary architectures" FORCE)
endif()
if(NOT CMAKE_OSX_DEPLOYMENT_TARGET)
  set(CMAKE_OSX_DEPLOYMENT_TARGET "13.0" CACHE STRING "Minimum macOS version" FORCE)
endif()

set(VM_VABAMORF_COMMIT "unknown" CACHE STRING "Vabamorf commit reported by vm_version()")

set(VABAMORF_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/../third_party/vabamorf")
if(NOT EXISTS "${VABAMORF_ROOT}/lib/proof/linguistic.h")
  message(FATAL_ERROR "Vabamorf submodule is missing at ${VABAMORF_ROOT}")
endif()

# Same file set as apps/cmdline/project/unix/Makefile. fsjni is a subdirectory
# and stays out. etsyn is not on the speller link line.
file(GLOB FSC_SOURCES CONFIGURE_DEPENDS "${VABAMORF_ROOT}/lib/fsc/*.cpp")
file(GLOB ETANA_SOURCES CONFIGURE_DEPENDS "${VABAMORF_ROOT}/lib/etana/*.cpp")
file(GLOB ETYHH_SOURCES CONFIGURE_DEPENDS "${VABAMORF_ROOT}/lib/etyhh/*.cpp")
file(GLOB PROOF_SOURCES CONFIGURE_DEPENDS "${VABAMORF_ROOT}/lib/proof/*.cpp")

add_library(vabamorf SHARED
  ${FSC_SOURCES}
  ${ETANA_SOURCES}
  ${ETYHH_SOURCES}
  ${PROOF_SOURCES}
  shim/vabamorf_c.cpp
)

# Apple clang does not define `unix`, so stdfsc.h would reject the build.
# UNIX selects the POSIX path. Do not define FSUTF16: wchar_t is 32-bit here,
# matching the Linux regression. `register` was removed in C++17; Vabamorf
# still uses it, and -Wno-register keeps gnu++17 without editing the submodule.
target_compile_definitions(vabamorf PRIVATE UNIX "VM_VABAMORF_COMMIT=${VM_VABAMORF_COMMIT}")
target_compile_options(vabamorf PRIVATE
  -fno-delete-null-pointer-checks
  -ffunction-sections
  -fdata-sections
  -fvisibility=hidden
  -Wno-register
)
target_include_directories(vabamorf PRIVATE "${VABAMORF_ROOT}/lib")
target_link_libraries(vabamorf PRIVATE pthread)
target_link_options(vabamorf PRIVATE "LINKER:-dead_strip")

set_target_properties(vabamorf PROPERTIES
  OUTPUT_NAME vabamorf
  MACOSX_RPATH ON
  CXX_VISIBILITY_PRESET hidden
  VISIBILITY_INLINES_HIDDEN ON
)
