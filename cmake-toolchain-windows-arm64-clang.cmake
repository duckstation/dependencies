include("${CMAKE_CURRENT_LIST_DIR}/cmake-toolchain-windows-arm64.cmake")

set(CMAKE_C_COMPILER clang-cl)
set(CMAKE_C_COMPILER_TARGET aarch64-pc-windows-msvc)
set(CMAKE_CXX_COMPILER clang-cl)
set(CMAKE_CXX_COMPILER_TARGET aarch64-pc-windows-msvc)
