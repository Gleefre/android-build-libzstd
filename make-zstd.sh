#!/bin/sh
set -e

# Download source
version=1.5.7
if [ -f zstd/lib/Makefile ]; then
    (cd zstd/lib && make clean)
else
    if [ ! -f v$version.zip ]; then
        wget https://github.com/facebook/zstd/archive/refs/tags/v$version.zip
    fi
    # Clean old folders if they exist
    rm -rf zstd
    rm -rf zstd-$version
    # Unpack
    unzip v$version.zip > /dev/null
    mv zstd-$version zstd
    # Fix soname with patch
    patch -p1 < soname-fix.patch
fi

# Configure NDK.

if [ -z $NDK ]; then
    echo "Please set NDK path variable." && exit 1
fi

if [ -z $ABI ]; then
    echo "Running adb to determine target ABI..."
    ABI=`adb shell uname -m`
    echo $ABI
fi
case $ABI in
    arm64 | aarch64) ABI=arm64-v8a ;;
    arm) ABI=armeabi-v7a ;;
    x86-64) ABI=x86_64 ;;
esac
case $ABI in
    arm64-v8a) TARGET=aarch64-linux-android ;;
    armeabi-v7a) TARGET=armv7a-linux-androideabi ;;
    x86) TARGET=i686-linux-android ;;
    x86_64) TARGET=x86_64-linux-android ;;
    all)
        ABI=arm64-v8a ./make-zstd.sh
        ABI=armeabi-v7a ./make-zstd.sh
        ABI=x86 ./make-zstd.sh
        ABI=x86_64 ./make-zstd.sh
        echo "Done."
        exit 0 ;;
    *) echo "Unsupported CPU ABI" && exit 1 ;;
esac

case `uname` in
    Linux) os=linux ;;
    Darwin) os=darwin ;;
    *) echo "Unsupported OS" && exit 1 ;;
esac
TOOLCHAIN=$NDK/toolchains/llvm/prebuilt/$os-x86_64

if [ -z $API ]; then
    echo "Android API not set. Using 21 by default."
    API=21
fi

(
cd zstd/lib ;
make \
    CC=$TOOLCHAIN/bin/$TARGET$API-clang \
    AR=$TOOLCHAIN/bin/llvm-ar
)

# Copy shared library
mkdir -p lib/$ABI
cp zstd/lib/libzstd.so.1 lib/$ABI/libzstd.so
# ...and headers
mkdir -p headers
cp zstd/lib/zstd.h headers
cp zstd/lib/zstd_errors.h headers
cp zstd/lib/zdict.h headers
