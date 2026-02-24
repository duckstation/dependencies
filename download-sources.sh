#!/usr/bin/env bash

set -e

SCRIPTDIR=$(realpath $(dirname "${BASH_SOURCE[0]}"))
source "$SCRIPTDIR/versions"

mkdir -p deps-build
cd deps-build

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
  -O "https://ffmpeg.org/releases/ffmpeg-$FFMPEG_VERSION.tar.xz" \
  -O "https://github.com/KhronosGroup/MoltenVK/archive/refs/tags/v$MOLTENVK_VERSION.tar.gz" \
  -O "https://download.qt.io/official_releases/qt/${QT%.*}/$QT/submodules/qtbase-everywhere-src-$QT.tar.xz" \
  -O "https://download.qt.io/official_releases/qt/${QT%.*}/$QT/submodules/qtbase-everywhere-src-$QT.zip" \
  -O "https://download.qt.io/official_releases/qt/${QT%.*}/$QT/submodules/qtimageformats-everywhere-src-$QT.tar.xz" \
  -O "https://download.qt.io/official_releases/qt/${QT%.*}/$QT/submodules/qtimageformats-everywhere-src-$QT.zip" \
  -O "https://download.qt.io/official_releases/qt/${QT%.*}/$QT/submodules/qtsvg-everywhere-src-$QT.tar.xz" \
  -O "https://download.qt.io/official_releases/qt/${QT%.*}/$QT/submodules/qtsvg-everywhere-src-$QT.zip" \
  -O "https://download.qt.io/official_releases/qt/${QT%.*}/$QT/submodules/qttools-everywhere-src-$QT.tar.xz" \
  -O "https://download.qt.io/official_releases/qt/${QT%.*}/$QT/submodules/qttools-everywhere-src-$QT.zip" \
  -O "https://download.qt.io/official_releases/qt/${QT%.*}/$QT/submodules/qttranslations-everywhere-src-$QT.tar.xz" \
  -O "https://download.qt.io/official_releases/qt/${QT%.*}/$QT/submodules/qttranslations-everywhere-src-$QT.zip" \
  -O "https://download.qt.io/official_releases/qt/${QT%.*}/$QT/submodules/qtwayland-everywhere-src-$QT.tar.xz" \
  -o "libbacktrace-$LIBBACKTRACE_COMMIT.tar.gz" "https://github.com/ianlancetaylor/libbacktrace/archive/$LIBBACKTRACE_COMMIT.tar.gz" \
  -O "https://github.com/libsdl-org/SDL/releases/download/release-$SDL3/SDL3-$SDL3.tar.gz" \
  -O "https://github.com/libsdl-org/SDL/releases/download/release-$SDL3/SDL3-$SDL3.zip" \
  -o "cpuinfo-$CPUINFO_COMMIT.tar.gz" "https://github.com/stenzek/cpuinfo/archive/$CPUINFO_COMMIT.tar.gz" \
  -o "discord-rpc-$DISCORD_RPC_COMMIT.tar.gz" "https://github.com/stenzek/discord-rpc/archive/$DISCORD_RPC_COMMIT.tar.gz" \
  -o "plutosvg-$PLUTOSVG_COMMIT.tar.gz" "https://github.com/stenzek/plutosvg/archive/$PLUTOSVG_COMMIT.tar.gz" \
  -o "shaderc-$SHADERC_COMMIT.tar.gz" "https://github.com/stenzek/shaderc/archive/$SHADERC_COMMIT.tar.gz" \
  -o "soundtouch-$SOUNDTOUCH_COMMIT.tar.gz" "https://github.com/stenzek/soundtouch/archive/$SOUNDTOUCH_COMMIT.tar.gz"

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
$FFMPEG_XZ_HASH  ffmpeg-$FFMPEG_VERSION.tar.xz
$MOLTENVK_GZ_HASH  v$MOLTENVK_VERSION.tar.gz
$QTBASE_XZ_HASH  qtbase-everywhere-src-$QT.tar.xz
$QTBASE_ZIP_HASH  qtbase-everywhere-src-$QT.zip
$QTIMAGEFORMATS_XZ_HASH  qtimageformats-everywhere-src-$QT.tar.xz
$QTIMAGEFORMATS_ZIP_HASH  qtimageformats-everywhere-src-$QT.zip
$QTSVG_XZ_HASH  qtsvg-everywhere-src-$QT.tar.xz
$QTSVG_ZIP_HASH  qtsvg-everywhere-src-$QT.zip
$QTTOOLS_XZ_HASH  qttools-everywhere-src-$QT.tar.xz
$QTTOOLS_ZIP_HASH  qttools-everywhere-src-$QT.zip
$QTTRANSLATIONS_XZ_HASH  qttranslations-everywhere-src-$QT.tar.xz
$QTTRANSLATIONS_ZIP_HASH  qttranslations-everywhere-src-$QT.zip
$QTWAYLAND_XZ_HASH  qtwayland-everywhere-src-$QT.tar.xz
$LIBBACKTRACE_GZ_HASH  libbacktrace-$LIBBACKTRACE_COMMIT.tar.gz
$SDL3_GZ_HASH  SDL3-$SDL3.tar.gz
$SDL3_ZIP_HASH  SDL3-$SDL3.zip
$CPUINFO_GZ_HASH  cpuinfo-$CPUINFO_COMMIT.tar.gz
$DISCORD_RPC_GZ_HASH  discord-rpc-$DISCORD_RPC_COMMIT.tar.gz
$PLUTOSVG_GZ_HASH  plutosvg-$PLUTOSVG_COMMIT.tar.gz
$SHADERC_GZ_HASH  shaderc-$SHADERC_COMMIT.tar.gz
$SOUNDTOUCH_GZ_HASH  soundtouch-$SOUNDTOUCH_COMMIT.tar.gz
EOF

shasum -a 256 --check SHASUMS

# Have to clone with git, because it does version detection.
git clone https://github.com/KhronosGroup/SPIRV-Cross/ -b $SPIRV_CROSS_TAG --depth 1
if [ "$(git --git-dir=SPIRV-Cross/.git rev-parse HEAD)" != "$SPIRV_CROSS_SHA" ]; then
  echo "SPIRV-Cross version mismatch, expected $SPIRV_CROSS_SHA, got $(git rev-parse HEAD)"
  exit 1
fi
