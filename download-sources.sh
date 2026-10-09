#!/usr/bin/env bash

set -e

if [ "$#" -gt 2 ]; then
  echo "Syntax: $0 [-skip-download] [all|linux|linux-cross|android|mac]"
  exit 1
fi

PLATFORM=all
for arg in "$@"; do
  if [ "$arg" == "-skip-download" ]; then
    echo "Not downloading sources."
    SKIP_DOWNLOAD=true
  else
    PLATFORM="$arg"
  fi
done

case "$PLATFORM" in
  all|linux|linux-cross|android|mac)
    ;;
  *)
    echo "Unknown platform $PLATFORM"
    exit 1
    ;;
esac

SCRIPTDIR=$(realpath $(dirname "${BASH_SOURCE[0]}"))
source "$SCRIPTDIR/versions"

mkdir -p deps-build
cd deps-build

FILES=()
URLS=()
HASHES=()

# Syntax: add_source <platforms> <file name> <hash> <url>
# Sources for platforms without a build script here (i.e. Windows) are only included in "all".
add_source() {
  if [[ "$PLATFORM" != "all" && ",$1," != *",$PLATFORM,"* ]]; then
    return
  fi

  FILES+=("$2")
  HASHES+=("$3")
  URLS+=("$4")
}

EVERYWHERE="linux,linux-cross,android,mac,windows"
DESKTOP="linux,linux-cross,mac,windows"
QTURL="https://download.qt.io/official_releases/qt/${QT%.*}/$QT/submodules"

add_source "$EVERYWHERE" "brotli-$BROTLI.tar.gz" "$BROTLI_GZ_HASH" "https://github.com/google/brotli/archive/refs/tags/v$BROTLI.tar.gz"
add_source "$EVERYWHERE" "freetype-$FREETYPE.tar.gz" "$FREETYPE_GZ_HASH" "https://sourceforge.net/projects/freetype/files/freetype2/$FREETYPE/freetype-$FREETYPE.tar.gz/download"
add_source "$EVERYWHERE" "harfbuzz-$HARFBUZZ.tar.gz" "$HARFBUZZ_GZ_HASH" "https://github.com/harfbuzz/harfbuzz/archive/refs/tags/$HARFBUZZ.tar.gz"
add_source "$EVERYWHERE" "libjpeg-turbo-$LIBJPEGTURBO.tar.gz" "$LIBJPEGTURBO_GZ_HASH" "https://github.com/libjpeg-turbo/libjpeg-turbo/releases/download/$LIBJPEGTURBO/libjpeg-turbo-$LIBJPEGTURBO.tar.gz"
add_source "$EVERYWHERE" "libpng-$LIBPNG.tar.gz" "$LIBPNG_GZ_HASH" "https://downloads.sourceforge.net/project/libpng/libpng16/$LIBPNG/libpng-$LIBPNG.tar.gz"
add_source "$EVERYWHERE" "libwebp-$LIBWEBP.tar.gz" "$LIBWEBP_GZ_HASH" "https://storage.googleapis.com/downloads.webmproject.org/releases/webp/libwebp-$LIBWEBP.tar.gz"
add_source "$EVERYWHERE" "libzip-$LIBZIP.tar.gz" "$LIBZIP_GZ_HASH" "https://github.com/nih-at/libzip/releases/download/v$LIBZIP/libzip-$LIBZIP.tar.gz"
add_source "$EVERYWHERE" "sqlite-amalgamation-$SQLITE.zip" "$SQLITE_ZIP_HASH" "https://sqlite.org/2026/sqlite-amalgamation-$SQLITE.zip"
add_source "linux,linux-cross,android,windows" "zlib-ng-$ZLIBNG.tar.gz" "$ZLIBNG_GZ_HASH" "https://github.com/zlib-ng/zlib-ng/archive/refs/tags/$ZLIBNG.tar.gz"
add_source "$EVERYWHERE" "zstd-$ZSTD.tar.gz" "$ZSTD_GZ_HASH" "https://github.com/facebook/zstd/releases/download/v$ZSTD/zstd-$ZSTD.tar.gz"
add_source "mac" "ffmpeg-$FFMPEG_VERSION.tar.xz" "$FFMPEG_XZ_HASH" "https://ffmpeg.org/releases/ffmpeg-$FFMPEG_VERSION.tar.xz"
add_source "mac" "v$MOLTENVK_VERSION.tar.gz" "$MOLTENVK_GZ_HASH" "https://github.com/KhronosGroup/MoltenVK/archive/refs/tags/v$MOLTENVK_VERSION.tar.gz"
add_source "linux,linux-cross,mac" "qtbase-everywhere-src-$QT.tar.xz" "$QTBASE_XZ_HASH" "$QTURL/qtbase-everywhere-src-$QT.tar.xz"
add_source "windows" "qtbase-everywhere-src-$QT.zip" "$QTBASE_ZIP_HASH" "$QTURL/qtbase-everywhere-src-$QT.zip"
add_source "linux,linux-cross,mac" "qtimageformats-everywhere-src-$QT.tar.xz" "$QTIMAGEFORMATS_XZ_HASH" "$QTURL/qtimageformats-everywhere-src-$QT.tar.xz"
add_source "windows" "qtimageformats-everywhere-src-$QT.zip" "$QTIMAGEFORMATS_ZIP_HASH" "$QTURL/qtimageformats-everywhere-src-$QT.zip"
add_source "linux,linux-cross,mac" "qttools-everywhere-src-$QT.tar.xz" "$QTTOOLS_XZ_HASH" "$QTURL/qttools-everywhere-src-$QT.tar.xz"
add_source "windows" "qttools-everywhere-src-$QT.zip" "$QTTOOLS_ZIP_HASH" "$QTURL/qttools-everywhere-src-$QT.zip"
add_source "linux,linux-cross,mac" "qttranslations-everywhere-src-$QT.tar.xz" "$QTTRANSLATIONS_XZ_HASH" "$QTURL/qttranslations-everywhere-src-$QT.tar.xz"
add_source "windows" "qttranslations-everywhere-src-$QT.zip" "$QTTRANSLATIONS_ZIP_HASH" "$QTURL/qttranslations-everywhere-src-$QT.zip"
add_source "linux,linux-cross" "qtwayland-everywhere-src-$QT.tar.xz" "$QTWAYLAND_XZ_HASH" "$QTURL/qtwayland-everywhere-src-$QT.tar.xz"
add_source "windows" "qt-online-installer-windows-x64-$QTINSTALLER.exe" "$QTINSTALLER_EXE_HASH" "https://download.qt.io/archive/online_installers/$QTINSTALLERMINOR/qt-online-installer-windows-x64-$QTINSTALLER.exe"
add_source "linux,linux-cross" "libbacktrace-$LIBBACKTRACE_COMMIT.tar.gz" "$LIBBACKTRACE_GZ_HASH" "https://github.com/ianlancetaylor/libbacktrace/archive/$LIBBACKTRACE_COMMIT.tar.gz"
add_source "$DESKTOP" "SDL-release-$SDL3.tar.gz" "$SDL3_GZ_HASH" "https://github.com/libsdl-org/SDL/archive/refs/tags/release-$SDL3.tar.gz"
add_source "$EVERYWHERE" "cpuinfo-$CPUINFO_COMMIT.tar.gz" "$CPUINFO_GZ_HASH" "https://github.com/stenzek/cpuinfo/archive/$CPUINFO_COMMIT.tar.gz"
add_source "$DESKTOP" "discord-rpc-$DISCORD_RPC_COMMIT.tar.gz" "$DISCORD_RPC_GZ_HASH" "https://github.com/stenzek/discord-rpc/archive/$DISCORD_RPC_COMMIT.tar.gz"
add_source "$EVERYWHERE" "plutosvg-$PLUTOSVG_COMMIT.tar.gz" "$PLUTOSVG_GZ_HASH" "https://github.com/stenzek/plutosvg/archive/$PLUTOSVG_COMMIT.tar.gz"
add_source "$EVERYWHERE" "shaderc-$SHADERC_COMMIT.tar.gz" "$SHADERC_GZ_HASH" "https://github.com/stenzek/shaderc/archive/$SHADERC_COMMIT.tar.gz"
add_source "$EVERYWHERE" "soundtouch-$SOUNDTOUCH_COMMIT.tar.gz" "$SOUNDTOUCH_GZ_HASH" "https://github.com/stenzek/soundtouch/archive/$SOUNDTOUCH_COMMIT.tar.gz"
add_source "linux-cross" "Vulkan-Headers-$VULKAN_HEADERS.tar.gz" "$VULKAN_HEADERS_GZ_HASH" "https://github.com/KhronosGroup/Vulkan-Headers/archive/refs/tags/v$VULKAN_HEADERS.tar.gz"
add_source "windows" "dxcompiler-$DXCOMPILER_VERSION.zip" "$DXCOMPILER_ZIP_HASH" "https://www.nuget.org/api/v2/package/Microsoft.Direct3D.DXC/$DXCOMPILER_VERSION"

rm -f SHASUMS
for i in "${!FILES[@]}"; do
  if [ ! -f "${FILES[$i]}" ]; then
    if [ "$SKIP_DOWNLOAD" == true ]; then
      echo "Required source file ${FILES[$i]} not found."
      exit 1
    fi

    # Download to a temporary name, so that an interrupted download is not mistaken for the file.
    echo "Downloading ${FILES[$i]} from ${URLS[$i]}..."
    curl -f -L -o "${FILES[$i]}.part" "${URLS[$i]}"
    mv "${FILES[$i]}.part" "${FILES[$i]}"
  fi

  echo "${HASHES[$i]}  ${FILES[$i]}" >> SHASUMS
done

shasum -a 256 --check SHASUMS

# Have to clone with git, because it does version detection.
if [ ! -d "SPIRV-Cross" ]; then
  if [ "$SKIP_DOWNLOAD" == true ]; then
    echo "Required source directory SPIRV-Cross not found."
    exit 1
  fi

  git clone https://github.com/KhronosGroup/SPIRV-Cross/ -b $SPIRV_CROSS_TAG --depth 1
fi
SPIRV_CROSS_HEAD="$(git --git-dir=SPIRV-Cross/.git rev-parse HEAD)"
if [ "$SPIRV_CROSS_HEAD" != "$SPIRV_CROSS_SHA" ]; then
  echo "SPIRV-Cross version mismatch, expected $SPIRV_CROSS_SHA, got $SPIRV_CROSS_HEAD"
  exit 1
fi
