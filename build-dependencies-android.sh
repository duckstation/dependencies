#!/usr/bin/env bash

set -e

if [ "$#" -lt 2 ]; then
    echo "Syntax: $0 <cross architecture> <output directory> [-skip-download] [-skip-cleanup] [-only-download] <output directory>"
    exit 1
fi

# Check for NDK_HOME environment variable.
if [ -z "$NDK_HOME" ] || [ ! -d "$NDK_HOME" ]; then
  echo "NDK_HOME environment variable not set or not a directory."
  exit 1
fi

for arg in "$@"; do
  if [ "$arg" == "-skip-download" ]; then
    echo "Not downloading sources."
    SKIP_DOWNLOAD=true
    shift
  elif [ "$arg" == "-skip-cleanup" ]; then
    echo "Not removing build directory."
    SKIP_CLEANUP=true
    shift
  elif [ "$arg" == "-only-download" ]; then
    echo "Only downloading sources."
    ONLY_DOWNLOAD=true
    shift
  fi
done

SCRIPTDIR=$(realpath $(dirname "${BASH_SOURCE[0]}"))
NPROCS="$(getconf _NPROCESSORS_ONLN)"
CROSSARCH="$1"
INSTALLDIR="$2"
if [ "${INSTALLDIR:0:1}" != "/" ]; then
  INSTALLDIR="$PWD/$INSTALLDIR"
fi
TOOLCHAINFILE="$NDK_HOME/build\cmake/android.toolchain.cmake"
CMAKE_COMMON=(
  -DCMAKE_BUILD_TYPE=Release
  -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAINFILE"
  -DCMAKE_PREFIX_PATH="$INSTALLDIR"
  -DCMAKE_INSTALL_PREFIX="$INSTALLDIR"
  -DCMAKE_FIND_ROOT_PATH="$INSTALLDIR"
  -DANDROID_ABI="$CROSSARCH"
  -DANDROID_PLATFORM="android-23"
)

source "$SCRIPTDIR/versions"

mkdir -p deps-build
cd deps-build

if [[ "$SKIP_DOWNLOAD" != true && ! -f "brotli-$BROTLI.tar.gz" ]]; then
  curl -C - -L \
    -o "brotli-$BROTLI.tar.gz" "https://github.com/google/brotli/archive/refs/tags/v$BROTLI.tar.gz" \
    -o "freetype-$FREETYPE.tar.gz" "https://sourceforge.net/projects/freetype/files/freetype2/$FREETYPE/freetype-$FREETYPE.tar.gz/download" \
    -o "harfbuzz-$HARFBUZZ.tar.gz" "https://github.com/harfbuzz/harfbuzz/archive/refs/tags/$HARFBUZZ.tar.gz" \
    -O "https://github.com/libjpeg-turbo/libjpeg-turbo/releases/download/$LIBJPEGTURBO/libjpeg-turbo-$LIBJPEGTURBO.tar.gz" \
    -O "https://downloads.sourceforge.net/project/libpng/libpng16/$LIBPNG/libpng-$LIBPNG.tar.gz" \
    -O "https://storage.googleapis.com/downloads.webmproject.org/releases/webp/libwebp-$LIBWEBP.tar.gz" \
    -O "https://github.com/nih-at/libzip/releases/download/v$LIBZIP/libzip-$LIBZIP.tar.gz" \
    -o "zlib-ng-$ZLIBNG.tar.gz" "https://github.com/zlib-ng/zlib-ng/archive/refs/tags/$ZLIBNG.tar.gz" \
    -O "https://github.com/facebook/zstd/releases/download/v$ZSTD/zstd-$ZSTD.tar.gz" \
    -o "cpuinfo-$CPUINFO_COMMIT.tar.gz" "https://github.com/stenzek/cpuinfo/archive/$CPUINFO_COMMIT.tar.gz" \
    -o "plutosvg-$PLUTOSVG_COMMIT.tar.gz" "https://github.com/stenzek/plutosvg/archive/$PLUTOSVG_COMMIT.tar.gz" \
    -o "shaderc-$SHADERC_COMMIT.tar.gz" "https://github.com/stenzek/shaderc/archive/$SHADERC_COMMIT.tar.gz" \
    -o "soundtouch-$SOUNDTOUCH_COMMIT.tar.gz" "https://github.com/stenzek/soundtouch/archive/$SOUNDTOUCH_COMMIT.tar.gz"
fi

cat > SHASUMS <<EOF
$BROTLI_GZ_HASH  brotli-$BROTLI.tar.gz
$FREETYPE_GZ_HASH  freetype-$FREETYPE.tar.gz
$HARFBUZZ_GZ_HASH  harfbuzz-$HARFBUZZ.tar.gz
$LIBJPEGTURBO_GZ_HASH  libjpeg-turbo-$LIBJPEGTURBO.tar.gz
$LIBPNG_GZ_HASH  libpng-$LIBPNG.tar.gz
$LIBWEBP_GZ_HASH  libwebp-$LIBWEBP.tar.gz
$LIBZIP_GZ_HASH  libzip-$LIBZIP.tar.gz
$ZLIBNG_GZ_HASH  zlib-ng-$ZLIBNG.tar.gz
$ZSTD_GZ_HASH  zstd-$ZSTD.tar.gz
$CPUINFO_GZ_HASH  cpuinfo-$CPUINFO_COMMIT.tar.gz
$PLUTOSVG_GZ_HASH  plutosvg-$PLUTOSVG_COMMIT.tar.gz
$SHADERC_GZ_HASH  shaderc-$SHADERC_COMMIT.tar.gz
$SOUNDTOUCH_GZ_HASH  soundtouch-$SOUNDTOUCH_COMMIT.tar.gz
EOF

shasum -a 256 --check SHASUMS

# Have to clone with git, because it does version detection.
if [[ "$SKIP_DOWNLOAD" != true && ! -d "SPIRV-Cross" ]]; then
  git clone https://github.com/KhronosGroup/SPIRV-Cross/ -b $SPIRV_CROSS_TAG --depth 1
  if [ "$(git --git-dir=SPIRV-Cross/.git rev-parse HEAD)" != "$SPIRV_CROSS_SHA" ]; then
    echo "SPIRV-Cross version mismatch, expected $SPIRV_CROSS_SHA, got $(git rev-parse HEAD)"
    exit 1
  fi
fi

# Only downloading sources?
if [ "$ONLY_DOWNLOAD" == true ]; then
  exit 0
fi

# Build zlib first because of the things that depend on it.
# Disabled because it currently causes crashes on armhf.
echo "Building zlib-ng..."
rm -fr "zlib-ng-$ZLIBNG"
tar xf "zlib-ng-$ZLIBNG.tar.gz"
cd "zlib-ng-$ZLIBNG"
cmake "${CMAKE_COMMON[@]}" -DBUILD_SHARED_LIBS=ON -DZLIB_COMPAT=ON -DBUILD_TESTING=OFF -DWITH_BENCHMARK_APPS=OFF -DWITH_GTEST=OFF -B build -G Ninja
cmake --build build --parallel
ninja -C build install
cd ..

echo "Building libpng..."
rm -fr "libpng-$LIBPNG"
tar xf "libpng-$LIBPNG.tar.gz"
cd "libpng-$LIBPNG"
patch -p1 < "$SCRIPTDIR/patches/libpng-1.6.56-apng.patch"
cmake "${CMAKE_COMMON[@]}" -DBUILD_SHARED_LIBS=ON -DPNG_TESTS=OFF -DPNG_STATIC=OFF -DPNG_SHARED=ON -DPNG_TOOLS=OFF -B build -G Ninja
cmake --build build --parallel
ninja -C build install
cd ..
rm -fr "libpng-$LIBPNG"

echo "Building libjpeg..."
rm -fr "libjpeg-turbo-$LIBJPEGTURBO"
tar xf "libjpeg-turbo-$LIBJPEGTURBO.tar.gz"
cd "libjpeg-turbo-$LIBJPEGTURBO"
patch -p1 < "$SCRIPTDIR/patches/libjpeg-turbo-disable-rpath.patch"
cmake "${CMAKE_COMMON[@]}" -DENABLE_STATIC=OFF -DENABLE_SHARED=ON -DWITH_TESTS=OFF -DWITH_TOOLS=OFF -B build -G Ninja
cmake --build build --parallel
ninja -C build install
cd ..
rm -fr "libjpeg-turbo-$LIBJPEGTURBO"

echo "Building Zstandard..."
rm -fr "zstd-$ZSTD"
tar -xf "zstd-$ZSTD.tar.gz" --exclude "zstd-$ZSTD/tests/cli-tests/*"
cd "zstd-$ZSTD"
cmake "${CMAKE_COMMON[@]}" -DBUILD_SHARED_LIBS=ON -DZSTD_BUILD_SHARED=ON -DZSTD_BUILD_STATIC=OFF -DZSTD_BUILD_PROGRAMS=OFF -B build -G Ninja build/cmake
cmake --build build --parallel
ninja -C build install
cd ..
rm -fr "zstd-$ZSTD"

echo "Building Brotli..."
rm -fr "brotli-$BROTLI"
tar xf "brotli-$BROTLI.tar.gz"
cd "brotli-$BROTLI"
cmake "${CMAKE_COMMON[@]}" -DBUILD_SHARED_LIBS=OFF -DBROTLI_BUILD_TOOLS=OFF -DBROTLI_DISABLE_TESTS=ON -B build -G Ninja
ninja -C build install
cd ..
rm -fr "brotli-$BROTLI"

echo "Building WebP..."
rm -fr "libwebp-$LIBWEBP"
tar xf "libwebp-$LIBWEBP.tar.gz"
cd "libwebp-$LIBWEBP"
cmake "${CMAKE_COMMON[@]}" -B build -G Ninja \
  -DWEBP_BUILD_ANIM_UTILS=OFF -DWEBP_BUILD_CWEBP=OFF -DWEBP_BUILD_DWEBP=OFF -DWEBP_BUILD_GIF2WEBP=OFF -DWEBP_BUILD_IMG2WEBP=OFF \
  -DWEBP_BUILD_VWEBP=OFF -DWEBP_BUILD_WEBPINFO=OFF -DWEBP_BUILD_WEBPMUX=OFF -DWEBP_BUILD_EXTRAS=OFF -DBUILD_SHARED_LIBS=ON \
  -DCMAKE_INSTALL_RPATH="\$ORIGIN"
cmake --build build --parallel
ninja -C build install
cd ..
rm -fr "libwebp-$LIBWEBP"

echo "Building libzip..."
rm -fr "libzip-$LIBZIP"
tar xf "libzip-$LIBZIP.tar.gz"
cd "libzip-$LIBZIP"
cmake "${CMAKE_COMMON[@]}" -B build -G Ninja \
  -DENABLE_COMMONCRYPTO=OFF -DENABLE_GNUTLS=OFF -DENABLE_MBEDTLS=OFF -DENABLE_OPENSSL=OFF -DENABLE_WINDOWS_CRYPTO=OFF \
  -DENABLE_BZIP2=OFF -DENABLE_LZMA=OFF -DENABLE_ZSTD=ON -DBUILD_SHARED_LIBS=ON -DLIBZIP_DO_INSTALL=ON \
  -DBUILD_TOOLS=OFF -DBUILD_REGRESS=OFF -DBUILD_OSSFUZZ=OFF -DBUILD_EXAMPLES=OFF -DBUILD_DOC=OFF \
  -DCMAKE_INSTALL_RPATH="\$ORIGIN"
cmake --build build --parallel
ninja -C build install
cd ..
rm -fr "libzip-$LIBZIP"

echo "Building FreeType..."
rm -fr "freetype-$FREETYPE"
tar xf "freetype-$FREETYPE.tar.gz"
cd "freetype-$FREETYPE"
patch -p1 < "$SCRIPTDIR/patches/freetype-harfbuzz-soname.patch"
patch -p1 < "$SCRIPTDIR/patches/freetype-static-brotli.patch"
cmake "${CMAKE_COMMON[@]}" -DBUILD_SHARED_LIBS=ON -DFT_REQUIRE_ZLIB=ON -DFT_REQUIRE_PNG=ON -DFT_DISABLE_BZIP2=TRUE -DFT_REQUIRE_BROTLI=TRUE -DFT_DYNAMIC_HARFBUZZ=TRUE -B build -G Ninja
cmake --build build --parallel
ninja -C build install
cd ..
rm -fr "freetype-$FREETYPE"

echo "Building HarfBuzz..."
rm -fr "harfbuzz-$HARFBUZZ"
tar xf "harfbuzz-$HARFBUZZ.tar.gz"
cd "harfbuzz-$HARFBUZZ"
cmake "${CMAKE_COMMON[@]}" -DBUILD_SHARED_LIBS=ON -DHB_BUILD_UTILS=OFF -B build -G Ninja
cmake --build build --parallel
ninja -C build install
cd ..
rm -fr "harfbuzz-$HARFBUZZ"

echo "Building shaderc..."
rm -fr "shaderc-$SHADERC_COMMIT"
tar xf "shaderc-$SHADERC_COMMIT.tar.gz"
cd "shaderc-$SHADERC_COMMIT"
cmake "${CMAKE_COMMON[@]}" -DSHADERC_SKIP_TESTS=ON -DSHADERC_SKIP_EXAMPLES=ON -DSHADERC_SKIP_EXECUTABLES=ON -DSHADERC_SKIP_COPYRIGHT_CHECK=ON -B build -G Ninja
cmake --build build --parallel
ninja -C build install
cd ..
rm -fr "shaderc-$SHADERC_COMMIT"

echo "Building SPIRV-Cross..."
cd SPIRV-Cross
rm -fr build
cmake "${CMAKE_COMMON[@]}" -DSPIRV_CROSS_SHARED=ON -DSPIRV_CROSS_STATIC=OFF -DSPIRV_CROSS_CLI=OFF -DSPIRV_CROSS_ENABLE_TESTS=OFF -DSPIRV_CROSS_ENABLE_GLSL=ON -DSPIRV_CROSS_ENABLE_HLSL=OFF -DSPIRV_CROSS_ENABLE_MSL=OFF -DSPIRV_CROSS_ENABLE_CPP=OFF -DSPIRV_CROSS_ENABLE_REFLECT=OFF -DSPIRV_CROSS_ENABLE_C_API=ON -DSPIRV_CROSS_ENABLE_UTIL=ON -B build -G Ninja
cmake --build build --parallel
ninja -C build install
rm -fr build
cd ..

echo "Building cpuinfo..."
rm -fr "cpuinfo-$CPUINFO_COMMIT"
tar xf "cpuinfo-$CPUINFO_COMMIT.tar.gz"
cd "cpuinfo-$CPUINFO_COMMIT"
cmake "${CMAKE_COMMON[@]}" -DCPUINFO_LIBRARY_TYPE=shared -DCPUINFO_RUNTIME_TYPE=shared -DCPUINFO_LOG_LEVEL=error -DCPUINFO_LOG_TO_STDIO=ON -DCPUINFO_BUILD_TOOLS=OFF -DCPUINFO_BUILD_UNIT_TESTS=OFF -DCPUINFO_BUILD_MOCK_TESTS=OFF -DCPUINFO_BUILD_BENCHMARKS=OFF -DUSE_SYSTEM_LIBS=ON -B build -G Ninja
cmake --build build --parallel
ninja -C build install
cd ..
rm -fr "cpuinfo-$CPUINFO_COMMIT"

echo "Building plutosvg..."
rm -fr "plutosvg-$PLUTOSVG_COMMIT"
tar xf "plutosvg-$PLUTOSVG_COMMIT.tar.gz"
cd "plutosvg-$PLUTOSVG_COMMIT"
cmake "${CMAKE_COMMON[@]}" -DBUILD_SHARED_LIBS=ON -DPLUTOSVG_ENABLE_FREETYPE=ON -DPLUTOSVG_BUILD_EXAMPLES=OFF -DCMAKE_INSTALL_RPATH="\$ORIGIN" -B build -G Ninja
cmake --build build --parallel
ninja -C build install
cd ..
rm -fr "plutosvg-$PLUTOSVG_COMMIT"

echo "Building soundtouch..."
rm -fr "soundtouch-$SOUNDTOUCH_COMMIT"
tar xf "soundtouch-$SOUNDTOUCH_COMMIT.tar.gz"
cd "soundtouch-$SOUNDTOUCH_COMMIT"
cmake "${CMAKE_COMMON[@]}" -DCMAKE_INTERPROCEDURAL_OPTIMIZATION=ON -B build -G Ninja
cmake --build build --parallel
ninja -C build install
cd ..
rm -fr "soundtouch-$SOUNDTOUCH_COMMIT"

if [ "$SKIP_CLEANUP" != true ]; then
  echo "Cleaning up..."
  cd ..
  rm -fr deps-build
fi
