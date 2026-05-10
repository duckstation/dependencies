#!/bin/bash

set -e

merge_binaries() {
  X86DIR=$1
  ARMDIR=$2
  echo "Merging ARM64 binaries from $ARMDIR into fat binaries at $X86DIR..."

  IFS="
"
  pushd "$X86DIR"
  for X86BIN in $(find . -type f \( -name '*.dylib' -o -name '*.a' -o -perm +111 \)); do
    if file "$X86DIR/$X86BIN" | grep "Mach-O " | grep " x86_64" >/dev/null; then
      ARMBIN="${ARMDIR}/${X86BIN}"
      echo "Merge $ARMBIN to $X86BIN..."
      if ! file "$ARMBIN" | grep "Mach-O " | grep " arm64" >/dev/null; then
        echo "Missing ARM64 Mach-O binary for $X86BIN."
        exit 1
      fi
      UNIVERSALBIN="${X86BIN}.universal"
      lipo -create "$X86BIN" "$ARMBIN" -output "$UNIVERSALBIN"
      lipo "$UNIVERSALBIN" -verify_arch x86_64 arm64
      mv "$UNIVERSALBIN" "$X86BIN"
    fi
  done
  popd
}

if [ "$#" -lt 1 ]; then
    echo "Syntax: $0 [-skip-download] [-skip-cleanup] [-only-download] <output directory>"
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

export MACOSX_DEPLOYMENT_TARGET=13.3

NPROCS="$(getconf _NPROCESSORS_ONLN)"
SCRIPTDIR=$(realpath $(dirname "${BASH_SOURCE[0]}"))
INSTALLDIR="$1"
if [ "${INSTALLDIR:0:1}" != "/" ]; then
    INSTALLDIR="$PWD/$INSTALLDIR"
fi

# Pin embedded timestamps to the commit date, unless the caller has already provided a date.
if [ -z "$SOURCE_DATE_EPOCH" ]; then
  SOURCE_DATE_EPOCH=$(git -C "$SCRIPTDIR" log -1 --format=%ct 2>/dev/null || true)
fi
if [ -n "$SOURCE_DATE_EPOCH" ]; then
  export SOURCE_DATE_EPOCH
else
  echo "WARNING: SOURCE_DATE_EPOCH is not set and could not be determined from git, build will not be reproducible."
fi

source "$SCRIPTDIR/versions"

# Download and verify the sources.
"$SCRIPTDIR/download-sources.sh" ${SKIP_DOWNLOAD:+-skip-download} mac
if [ "$ONLY_DOWNLOAD" == true ]; then
  exit 0
fi

mkdir -p deps-build
cd deps-build

# Rewrite paths in macros and debug info to fixed names, so that the output does not depend
# on where the build and install directories are located. Helpful for reproducible builds.
BUILDDIR="$PWD"
CFLAGS_COMMON="-ffile-prefix-map=$BUILDDIR=. -ffile-prefix-map=$INSTALLDIR=deps"

# Stop ar/ranlib/libtool from writing the current time into static libraries.
export ZERO_AR_DATE=1

export PKG_CONFIG_PATH="$INSTALLDIR/lib/pkgconfig:$PKG_CONFIG_PATH"
export LDFLAGS="-L$INSTALLDIR/lib $LDFLAGS"
export CFLAGS="-I$INSTALLDIR/include $CFLAGS_COMMON $CFLAGS"
export CXXFLAGS="-I$INSTALLDIR/include $CFLAGS_COMMON $CXXFLAGS"
LDFLAGS_COMMON="-dead_strip -dead_strip_dylibs"
CMAKE_COMMON=(
  -DCMAKE_BUILD_TYPE="Release"
  -DCMAKE_OSX_DEPLOYMENT_TARGET="$MACOSX_DEPLOYMENT_TARGET"
  -DCMAKE_SHARED_LINKER_FLAGS="$LDFLAGS_COMMON"
  -DCMAKE_PREFIX_PATH="$INSTALLDIR"
  -DCMAKE_INSTALL_PREFIX="$INSTALLDIR"
  -DCMAKE_INSTALL_RPATH="@loader_path"
)
CMAKE_ARCH_X64=-DCMAKE_OSX_ARCHITECTURES="x86_64"
CMAKE_ARCH_ARM64=-DCMAKE_OSX_ARCHITECTURES="arm64"
CMAKE_ARCH_UNIVERSAL=-DCMAKE_OSX_ARCHITECTURES="x86_64;arm64"

CMAKE_COMMON_QT=(
  -DCMAKE_OSX_ARCHITECTURES="x86_64;arm64"
  -DCMAKE_BUILD_RPATH="$INSTALLDIR/lib"
  -DQT_GENERATE_SBOM=ON
)

echo "Building Qt Base..."
rm -fr "qtbase-everywhere-src-$QT"
tar xf "qtbase-everywhere-src-$QT.tar.xz"
cd "qtbase-everywhere-src-$QT"

# Allow window-modal dialog boxes in Tahoe, it's not a problem for us.
patch -p1 < "$SCRIPTDIR/patches/qtbase-window-modal-tahoe.patch"

cmake -B build "${CMAKE_COMMON[@]}" "${CMAKE_COMMON_QT[@]}" -DFEATURE_dbus=OFF -DFEATURE_framework=OFF -DFEATURE_icu=OFF -DFEATURE_opengl=OFF -DFEATURE_sql=OFF -DFEATURE_gssapi=OFF -DFEATURE_png=ON -DFEATURE_system_png=OFF -DFEATURE_jpeg=ON -DFEATURE_system_jpeg=OFF -DFEATURE_system_zlib=OFF -DFEATURE_freetype=ON -DFEATURE_system_freetype=OFF -DFEATURE_harfbuzz=ON -DFEATURE_system_harfbuzz=OFF -DFEATURE_brotli=OFF
make -C build "-j$NPROCS"
make -C build install
cd ..
rm -fr "qtbase-everywhere-src-$QT"

echo "Building Qt Image Formats..."
rm -fr "qtimageformats-everywhere-src-$QT"
tar xf "qtimageformats-everywhere-src-$QT.tar.xz"
cd "qtimageformats-everywhere-src-$QT"
mkdir build
cd build
"$INSTALLDIR/bin/qt-configure-module" .. -- "${CMAKE_COMMON[@]}" "${CMAKE_COMMON_QT[@]}" -DFEATURE_webp=ON -DFEATURE_system_webp=OFF
make "-j$NPROCS"
make install
cd ../..
rm -fr "qtimageformats-everywhere-src-$QT"

echo "Installing Qt Shader Tools..."
rm -fr "qtshadertools-everywhere-src-$QT"
tar xf "qtshadertools-everywhere-src-$QT.tar.xz"
cd "qtshadertools-everywhere-src-$QT"
mkdir build
cd build
"$INSTALLDIR/bin/qt-configure-module" .. -- "${CMAKE_COMMON[@]}" "${CMAKE_COMMON_QT[@]}"
make "-j$NPROCS"
make install
cd ../..
rm -fr "qtshadertools-everywhere-src-$QT"

echo "Installing Qt Declarative..."
rm -fr "qtdeclarative-everywhere-src-$QT"
tar xf "qtdeclarative-everywhere-src-$QT.tar.xz"
cd "qtdeclarative-everywhere-src-$QT"
mkdir build
cd build
"$INSTALLDIR/bin/qt-configure-module" .. -- "${CMAKE_COMMON[@]}" "${CMAKE_COMMON_QT[@]}"
make "-j$NPROCS"
make install
cd ../..
rm -fr "qtdeclarative-everywhere-src-$QT"

echo "Building Qt Tools..."
rm -fr "qttools-everywhere-src-$QT"
tar xf "qttools-everywhere-src-$QT.tar.xz"
cd "qttools-everywhere-src-$QT"
mkdir build
cd build
"$INSTALLDIR/bin/qt-configure-module" .. -- "${CMAKE_COMMON[@]}" "${CMAKE_COMMON_QT[@]}" -DFEATURE_assistant=OFF -DFEATURE_clang=OFF -DFEATURE_designer=ON -DFEATURE_kmap2qmap=OFF -DFEATURE_linguist=ON -DFEATURE_pixeltool=OFF -DFEATURE_pkg_config=OFF -DFEATURE_qev=OFF -DFEATURE_qtattributionsscanner=OFF -DFEATURE_qtdiag=OFF -DFEATURE_qtplugininfo=OFF
make "-j$NPROCS"
make install
cd ../..
rm -fr "qttools-everywhere-src-$QT"

echo "Building Qt Translations..."
rm -fr "qttranslations-everywhere-src-$QT"
tar xf "qttranslations-everywhere-src-$QT.tar.xz"
cd "qttranslations-everywhere-src-$QT"
mkdir build
cd build
"$INSTALLDIR/bin/qt-configure-module" .. -- "${CMAKE_COMMON[@]}" "${CMAKE_COMMON_QT[@]}"
make "-j$NPROCS"
make install
cd ../..
rm -fr "qttranslations-everywhere-src-$QT"

echo "Building libpng..."
rm -fr "libpng-$LIBPNG"
tar xf "libpng-$LIBPNG.tar.gz"
cd "libpng-$LIBPNG"
patch -p1 < "$SCRIPTDIR/patches/libpng-1.6.56-apng.patch"
LIBPNG_OPTIONS=(-DBUILD_SHARED_LIBS=ON -DPNG_TESTS=OFF -DPNG_FRAMEWORK=OFF)
cmake "${CMAKE_COMMON[@]}" "$CMAKE_ARCH_X64" "${LIBPNG_OPTIONS[@]}" -B build
make -C build "-j$NPROCS"
cmake "${CMAKE_COMMON[@]}" "$CMAKE_ARCH_ARM64" "${LIBPNG_OPTIONS[@]}" -DPNG_ARM_NEON=on -B build-arm64
make -C build-arm64 "-j$NPROCS"
merge_binaries $(realpath build) $(realpath build-arm64)
make -C build install
cd ..
rm -fr "libpng-$LIBPNG"

echo "Building libjpeg..."
rm -fr "libjpeg-turbo-$LIBJPEGTURBO"
tar xf "libjpeg-turbo-$LIBJPEGTURBO.tar.gz"
cd "libjpeg-turbo-$LIBJPEGTURBO"
LIBJPEG_OPTIONS=(-DENABLE_STATIC=OFF -DENABLE_SHARED=ON -DWITH_TESTS=OFF -DWITH_TOOLS=OFF)
cmake "${CMAKE_COMMON[@]}" "$CMAKE_ARCH_X64" "${LIBJPEG_OPTIONS[@]}" -B build
make -C build "-j$NPROCS"
cmake "${CMAKE_COMMON[@]}" "$CMAKE_ARCH_ARM64" "${LIBJPEG_OPTIONS[@]}" -B build-arm64
make -C build-arm64 "-j$NPROCS"
merge_binaries $(realpath build) $(realpath build-arm64)
make -C build install
cd ..
rm -fr "libjpeg-turbo-$LIBJPEGTURBO"

echo "Building Zstandard..."
rm -fr "zstd-$ZSTD"
tar xf "zstd-$ZSTD.tar.gz"
cd "zstd-$ZSTD"
ZSTD_OPTIONS=(-DBUILD_SHARED_LIBS=ON -DZSTD_BUILD_PROGRAMS=OFF)
cmake "${CMAKE_COMMON[@]}" "$CMAKE_ARCH_X64" "${ZSTD_OPTIONS[@]}" -B build-dir build/cmake
make -C build-dir "-j$NPROCS"
cmake "${CMAKE_COMMON[@]}" "$CMAKE_ARCH_ARM64" "${ZSTD_OPTIONS[@]}" -B build-dir-arm64 build/cmake
make -C build-dir-arm64 "-j$NPROCS"
merge_binaries $(realpath build-dir) $(realpath build-dir-arm64)
make -C build-dir install
cd ..
rm -fr "zstd-$ZSTD"

echo "Building Brotli..."
rm -fr "brotli-$BROTLI"
tar xf "brotli-$BROTLI.tar.gz"
cd "brotli-$BROTLI"
cmake "${CMAKE_COMMON[@]}" "$CMAKE_ARCH_UNIVERSAL" -DBUILD_SHARED_LIBS=OFF -DBROTLI_BUILD_TOOLS=OFF -DBROTLI_DISABLE_TESTS=ON -B build
cmake --build build --parallel
cmake --install build
cd ..
rm -fr "brotli-$BROTLI"

echo "Building WebP..."
rm -fr "libwebp-$LIBWEBP"
tar xf "libwebp-$LIBWEBP.tar.gz"
cd "libwebp-$LIBWEBP"
LIBWEBP_OPTIONS=(
  -DWEBP_BUILD_ANIM_UTILS=OFF -DWEBP_BUILD_CWEBP=OFF -DWEBP_BUILD_DWEBP=OFF -DWEBP_BUILD_GIF2WEBP=OFF -DWEBP_BUILD_IMG2WEBP=OFF
  -DWEBP_BUILD_VWEBP=OFF -DWEBP_BUILD_WEBPINFO=OFF -DWEBP_BUILD_WEBPMUX=OFF -DWEBP_BUILD_EXTRAS=OFF -DBUILD_SHARED_LIBS=ON
)
cmake "${CMAKE_COMMON[@]}" "$CMAKE_ARCH_X64" "${LIBWEBP_OPTIONS[@]}" -B build
make -C build "-j$NPROCS"
cmake "${CMAKE_COMMON[@]}" "$CMAKE_ARCH_ARM64" "${LIBWEBP_OPTIONS[@]}" -B build-arm64
make -C build-arm64 "-j$NPROCS"
# Run CMake's install and install_name_tool steps on each thin build before merging. A fat dylib assembled in the build
# tree has a different build RPATH in each slice, which CMake cannot remove correctly during installation.
DESTDIR="$PWD/install-x64" cmake --install build
DESTDIR="$PWD/install-arm64" cmake --install build-arm64
merge_binaries "$PWD/install-x64$INSTALLDIR" "$PWD/install-arm64$INSTALLDIR"
cp -R "$PWD/install-x64$INSTALLDIR/." "$INSTALLDIR/"
cd ..
rm -fr "libwebp-$LIBWEBP"

echo "Building libzip..."
rm -fr "libzip-$LIBZIP"
tar xf "libzip-$LIBZIP.tar.gz"
cd "libzip-$LIBZIP"
cmake "${CMAKE_COMMON[@]}" "$CMAKE_ARCH_UNIVERSAL" -B build \
  -DENABLE_COMMONCRYPTO=OFF -DENABLE_GNUTLS=OFF -DENABLE_MBEDTLS=OFF -DENABLE_OPENSSL=OFF -DENABLE_WINDOWS_CRYPTO=OFF \
  -DENABLE_BZIP2=OFF -DENABLE_LZMA=OFF -DENABLE_ZSTD=ON -DBUILD_SHARED_LIBS=ON -DLIBZIP_DO_INSTALL=ON \
  -DBUILD_TOOLS=OFF -DBUILD_REGRESS=OFF -DBUILD_OSSFUZZ=OFF -DBUILD_EXAMPLES=OFF -DBUILD_DOC=OFF
cmake --build build --parallel
cmake --install build
cd ..
rm -fr "libzip-$LIBZIP"

echo "Building FreeType..."
rm -fr "freetype-$FREETYPE"
tar xf "freetype-$FREETYPE.tar.gz"
cd "freetype-$FREETYPE"
patch -p1 < "$SCRIPTDIR/patches/freetype-harfbuzz-soname.patch"
patch -p1 < "$SCRIPTDIR/patches/freetype-static-brotli.patch"
cmake "${CMAKE_COMMON[@]}" "$CMAKE_ARCH_UNIVERSAL" -DBUILD_SHARED_LIBS=ON -DFT_REQUIRE_ZLIB=ON -DFT_REQUIRE_PNG=ON -DFT_DISABLE_BZIP2=TRUE -DFT_REQUIRE_BROTLI=TRUE -DFT_DYNAMIC_HARFBUZZ=TRUE -B build
cmake --build build --parallel
cmake --install build
cd ..
rm -fr "freetype-$FREETYPE"

echo "Building HarfBuzz..."
rm -fr "harfbuzz-$HARFBUZZ"
tar xf "harfbuzz-$HARFBUZZ.tar.gz"
cd "harfbuzz-$HARFBUZZ"
cmake "${CMAKE_COMMON[@]}" "$CMAKE_ARCH_UNIVERSAL" -DBUILD_SHARED_LIBS=ON -DHB_BUILD_UTILS=OFF -B build
cmake --build build --parallel
cmake --install build
cd ..
rm -fr "harfbuzz-$HARFBUZZ"

echo "Building SDL..."
rm -fr "SDL-release-$SDL3"
tar xf "SDL-release-$SDL3.tar.gz"
cd "SDL-release-$SDL3"
cmake -B build "${CMAKE_COMMON[@]}" "$CMAKE_ARCH_UNIVERSAL" -DSDL_SHARED=ON -DSDL_STATIC=OFF -DSDL_TESTS=OFF -DSDL_X11=OFF -DBUILD_SHARED_LIBS=ON
make -C build "-j$NPROCS"
make -C build install
cd ..
rm -fr "SDL-release-$SDL3"

echo "Building FFmpeg..."
rm -fr "ffmpeg-$FFMPEG_VERSION"
tar xf "ffmpeg-$FFMPEG_VERSION.tar.xz"
cd "ffmpeg-$FFMPEG_VERSION"
FFMPEG_OPTIONS=(
  --disable-x86asm --disable-all --disable-autodetect --disable-static --enable-shared
  --enable-avcodec --enable-avformat --enable-avutil --enable-swresample --enable-swscale --enable-audiotoolbox --enable-videotoolbox
  --enable-encoder='ffv1,qtrle,pcm_s16be,pcm_s16le,*_at,*_videotoolbox'
  --enable-muxer='avi,matroska,mov,mp3,mp4,wav'
  --enable-protocol='file'
)
mkdir build
cd build
LDFLAGS="$LDFLAGS_COMMON $LDFLAGS" \
  ../configure --prefix="$INSTALLDIR" \
  --enable-cross-compile --arch=x86_64 --cc='clang -arch x86_64' --cxx='clang++ -arch x86_64' \
  "${FFMPEG_OPTIONS[@]}"
make "-j$NPROCS"
cd ..
mkdir build-arm64
cd build-arm64
LDFLAGS="$LDFLAGS_COMMON $LDFLAGS" \
  ../configure --prefix="$INSTALLDIR" \
  --enable-cross-compile --arch=arm64 --cc='clang -arch arm64' --cxx='clang++ -arch arm64' \
  "${FFMPEG_OPTIONS[@]}"
make "-j$NPROCS"
cd ..
merge_binaries $(realpath build) $(realpath build-arm64)
cd build
make install
cd ../..
rm -fr "ffmpeg-$FFMPEG_VERSION"

# MoltenVK already builds universal binaries, nothing special to do here.
echo "Building MoltenVK..."
rm -fr "MoltenVK-${MOLTENVK_VERSION}"
tar xf "v$MOLTENVK_VERSION.tar.gz"
cd "MoltenVK-${MOLTENVK_VERSION}"
./fetchDependencies --macos
make macos
cp Package/Latest/MoltenVK/dynamic/dylib/macOS/libMoltenVK.dylib "$INSTALLDIR/lib/"
cd ..
rm -fr "MoltenVK-${MOLTENVK_VERSION}"

echo "Building sqlite..."
rm -fr "sqlite-amalgamation-$SQLITE"
unzip "sqlite-amalgamation-$SQLITE.zip"
cd "sqlite-amalgamation-$SQLITE"
patch -p1 < "$SCRIPTDIR/patches/sqlite-cmake.patch"
sed -i -e "s/@@SQLITE_LONG_VERSION@@/$SQLITE_LONG_VERSION/" CMakeLists.txt
cmake -B build "${CMAKE_COMMON[@]}" "$CMAKE_ARCH_UNIVERSAL" -DENABLE_SHARED=ON -DENABLE_STATIC=OFF -DENABLE_RTREE=OFF -DENABLE_ZLIB=OFF
make -C build "-j$NPROCS"
make -C build install
cd ..
rm -fr "sqlite-amalgamation-$SQLITE"

echo "Building shaderc..."
rm -fr "shaderc-$SHADERC_COMMIT"
tar xf "shaderc-$SHADERC_COMMIT.tar.gz"
cd "shaderc-$SHADERC_COMMIT"
cmake "${CMAKE_COMMON[@]}" "$CMAKE_ARCH_UNIVERSAL" -DSHADERC_SKIP_TESTS=ON -DSHADERC_SKIP_EXAMPLES=ON -DSHADERC_SKIP_COPYRIGHT_CHECK=ON -DSHADERC_SKIP_EXECUTABLES=ON -DSHADERC_ENABLE_HLSL=OFF -B build
make -C build "-j$NPROCS"
make -C build install
cd ..
rm -fr "shaderc-$SHADERC_COMMIT"

echo "Building SPIRV-Cross..."
cd SPIRV-Cross
rm -fr build
cmake "${CMAKE_COMMON[@]}" "$CMAKE_ARCH_UNIVERSAL" -DSPIRV_CROSS_SHARED=ON -DSPIRV_CROSS_STATIC=OFF -DSPIRV_CROSS_CLI=OFF -DSPIRV_CROSS_ENABLE_TESTS=OFF -DSPIRV_CROSS_ENABLE_GLSL=ON -DSPIRV_CROSS_ENABLE_HLSL=OFF -DSPIRV_CROSS_ENABLE_MSL=ON -DSPIRV_CROSS_ENABLE_CPP=OFF -DSPIRV_CROSS_ENABLE_REFLECT=OFF -DSPIRV_CROSS_ENABLE_C_API=ON -DSPIRV_CROSS_ENABLE_UTIL=ON -B build
cmake --build build --parallel
cmake --install build
rm -fr build
cd ..

echo "Building cpuinfo..."
rm -fr "cpuinfo-$CPUINFO_COMMIT"
tar xf "cpuinfo-$CPUINFO_COMMIT.tar.gz"
cd "cpuinfo-$CPUINFO_COMMIT"
CPUINFO_OPTIONS=(-DCPUINFO_LIBRARY_TYPE=shared -DCPUINFO_RUNTIME_TYPE=shared -DCPUINFO_LOG_LEVEL=error -DCPUINFO_LOG_TO_STDIO=ON -DCPUINFO_BUILD_TOOLS=OFF -DCPUINFO_BUILD_UNIT_TESTS=OFF -DCPUINFO_BUILD_MOCK_TESTS=OFF -DCPUINFO_BUILD_BENCHMARKS=OFF -DUSE_SYSTEM_LIBS=ON)
cmake "${CMAKE_COMMON[@]}" "$CMAKE_ARCH_X64" "${CPUINFO_OPTIONS[@]}" -B build
make -C build "-j$NPROCS"
cmake "${CMAKE_COMMON[@]}" "$CMAKE_ARCH_ARM64" "${CPUINFO_OPTIONS[@]}" -B build-arm64
make -C build-arm64 "-j$NPROCS"
merge_binaries $(realpath build) $(realpath build-arm64)
make -C build install
cd ..
rm -fr "cpuinfo-$CPUINFO_COMMIT"

echo "Building discord-rpc..."
rm -fr "discord-rpc-$DISCORD_RPC_COMMIT"
tar xf "discord-rpc-$DISCORD_RPC_COMMIT.tar.gz"
cd "discord-rpc-$DISCORD_RPC_COMMIT"
cmake "${CMAKE_COMMON[@]}" "$CMAKE_ARCH_UNIVERSAL" -DBUILD_SHARED_LIBS=ON -B build
cmake --build build --parallel
cmake --install build
cd ..
rm -fr "discord-rpc-$DISCORD_RPC_COMMIT"

echo "Building plutosvg..."
rm -fr "plutosvg-$PLUTOSVG_COMMIT"
tar xf "plutosvg-$PLUTOSVG_COMMIT.tar.gz"
cd "plutosvg-$PLUTOSVG_COMMIT"
cmake "${CMAKE_COMMON[@]}" "$CMAKE_ARCH_UNIVERSAL" -DBUILD_SHARED_LIBS=ON -DPLUTOSVG_ENABLE_FREETYPE=ON -DPLUTOSVG_BUILD_EXAMPLES=OFF -B build
cmake --build build --parallel
cmake --install build
cd ..
rm -fr "plutosvg-$PLUTOSVG_COMMIT"

echo "Building soundtouch..."
rm -fr "soundtouch-$SOUNDTOUCH_COMMIT"
tar xf "soundtouch-$SOUNDTOUCH_COMMIT.tar.gz"
cd "soundtouch-$SOUNDTOUCH_COMMIT"
cmake "${CMAKE_COMMON[@]}" "$CMAKE_ARCH_UNIVERSAL" -DCMAKE_INTERPROCEDURAL_OPTIMIZATION=ON -B build
cmake --build build --parallel
cmake --install build
cd ..
rm -fr "soundtouch-$SOUNDTOUCH_COMMIT"

if [ "$SKIP_CLEANUP" != true ]; then
  echo "Cleaning up..."
  cd ..
  rm -fr deps-build
fi
