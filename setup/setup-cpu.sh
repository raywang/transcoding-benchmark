#!/bin/bash
#
# Script for compiling and installing FFmpeg from source on Amazon Linux 2023 on x86_64 and arm64 instances
#

# Backup logs
#ARCH_FLAG_ARM64="-march=armv8.4-a+sve -mcpu=neoverse-512tvb"
#NASM_SOURCE="https://github.com/netwide-assembler/nasm/archive/refs/tags/nasm-2.16.01.tar.gz"
#OPUS_SOURCE="https://archive.mozilla.org/pub/opus/opus-1.3.1.tar.gz"

ARCH=$(uname -m)
ARCH_FLAG_X86="-march=x86-64-v2"
ARCH_FLAG_ARM64="-mcpu=neoverse-512tvb"
NASM_SOURCE="https://www.nasm.us/pub/nasm/releasebuilds/2.15.05/nasm-2.15.05.tar.bz2"
YASM_SOURCE="https://www.tortall.net/projects/yasm/releases/yasm-1.3.0.tar.gz"
MP3_SOURCE="https://downloads.sourceforge.net/project/lame/lame/3.100/lame-3.100.tar.gz"
OPUS_SOURCE="https://downloads.xiph.org/releases/opus/opus-1.4.tar.gz"
FFMPEG_SOURCE="https://ffmpeg.org/releases/ffmpeg-6.0.tar.bz2"

# 1 - Update host OS, and reboot the instance if needed

sudo dnf update --releasever=latest -y

# 2 - Install build dependencies & other packages

sudo dnf install -y autoconf automake bzip2 bzip2-devel cmake freetype-devel gcc gcc-c++ git libtool make pkgconfig zlib-devel tmux zstd

# 3 - Create build directory

mkdir ~/ffmpeg_sources

# 4 - Compile the NASM assembler
echo "================================="
echo "Building NASM..."
echo "================================="

cd ~/ffmpeg_sources
curl -O -L -k $NASM_SOURCE
tar xf nasm-2.15.05.tar.bz2
cd nasm-2.15.05
./autogen.sh
./configure --prefix="$HOME/ffmpeg_build" --bindir="$HOME/bin"
make
make install

echo "================================="
echo "Building NASM... Done"
echo "================================="



# 5 - Compile the YASM assembler
echo "================================="
echo "Building YASM..."
echo "================================="

cd ~/ffmpeg_sources
curl -O -L $YASM_SOURCE
tar xf yasm-1.3.0.tar.gz
cd yasm-1.3.0
./configure --prefix="$HOME/ffmpeg_build" --bindir="$HOME/bin" $ARCH_FLAG_ARM64
make
make install

echo "================================="
echo "Building YASM... Done"
echo "================================="



# 6 - Compile x264
echo "================================="
echo "Building x264..."
echo "================================="

cd ~/ffmpeg_sources
git clone --depth 1 https://code.videolan.org/videolan/x264.git
cd x264
if [ $ARCH == "aarch64" ]; then
    PKG_CONFIG_PATH="$HOME/ffmpeg_build/lib/pkgconfig" ./configure --prefix="$HOME/ffmpeg_build" --bindir="$HOME/bin" $ARCH_FLAG_ARM64 --enable-static
else
    PKG_CONFIG_PATH="$HOME/ffmpeg_build/lib/pkgconfig" ./configure --prefix="$HOME/ffmpeg_build" --bindir="$HOME/bin" $ARCH_FLAG_X86 --enable-static
fi
make
make install

echo "================================="
echo "Building x264... Done"
echo "================================="



# 7 - Compile x265
echo "================================="
echo "Building x265..."
echo "================================="

cd ~/ffmpeg_sources
git clone https://bitbucket.org/multicoreware/x265_git
cd ~/ffmpeg_sources/x265_git/build/linux
if [ $ARCH == "aarch64" ]; then
    cmake -G "Unix Makefiles" -DCMAKE_INSTALL_PREFIX="$HOME/ffmpeg_build" \
        -DCMAKE_C_FLAGS="-O3 $ARCH_FLAG_ARM64" \
        -DCMAKE_CXX_FLAGS="-O3 $ARCH_FLAG_ARM64" \
        -DENABLE_SHARED:bool=off ../../source
else
    cmake -G "Unix Makefiles" -DCMAKE_INSTALL_PREFIX="$HOME/ffmpeg_build" \
        -DCMAKE_C_FLAGS="-O3 $ARCH_FLAG_X86" \
        -DCMAKE_CXX_FLAGS="-O3 $ARCH_FLAG_X86" \
        -DENABLE_SHARED:bool=off ../../source
fi
make
make install
echo "================================="
echo "Building x265... Done"
echo "================================="



# 8 - Compile the AAC audio codec
echo "================================="
echo "Building AAC..."
echo "================================="

cd ~/ffmpeg_sources
git clone --depth 1 https://github.com/mstorsjo/fdk-aac
cd fdk-aac
autoreconf -fiv
if [ $ARCH == "aarch64" ]; then
    ./configure --prefix="$HOME/ffmpeg_build" $ARCH_FLAG_ARM64 --disable-shared
else
    ./configure --prefix="$HOME/ffmpeg_build" $ARCH_FLAG_X86 --disable-shared
fi
make
make install

echo "================================="
echo "Building AAC... Done"
echo "================================="



# 9 - Compile MP3 codec
echo "================================="
echo "Building MP3..."
echo "================================="

cd ~/ffmpeg_sources
curl -O -L $MP3_SOURCE
tar xf lame-3.100.tar.gz
cd lame-3.100
if [ $ARChttps://github.com/mstorsjo/fdk-aacH == "aarch64" ]; then
    ./configure --prefix="$HOME/ffmpeg_build" $ARCH_FLAG_ARM64 --disable-shared
else
    ./configure --prefix="$HOME/ffmpeg_build" $ARCH_FLAG_X86 --disable-shared
fi
make
make install

echo "================================="
echo "Building MP3... Done"
echo "================================="



# 10 - Compile the Opus codec
echo "================================="
echo "Building Opus..."
echo "================================="

cd ~/ffmpeg_sources
curl -O -L $OPUS_SOURCE
tar xf opus-1.4.tar.gz
cd opus-1.4
if [ $ARCH == "aarch64" ]; then
    ./configure --prefix="$HOME/ffmpeg_build" $ARCH_FLAG_ARM64 --disable-shared
else
    ./configure --prefix="$HOME/ffmpeg_build" $ARCH_FLAG_X86 --disable-shared
fi
make
make install

echo "================================="
echo "Building Opus... Done"
echo "================================="



#export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/lib64/
#cp /usr/local/lib64/pkgconfig/libvmaf.pc $HOME/ffmpeg_build/lib/pkgconfig/

# 11 - Compile FFmpeg
echo "================================="
echo "Building FFmpeg..."
echo "================================="

cd ~/ffmpeg_sources
curl -O -L $FFMPEG_SOURCE
tar xf ffmpeg-6.0.tar.bz2
cd ffmpeg-6.0
if [ $ARCH == "aarch64" ]; then
    PATH="$HOME/bin:$PATH" PKG_CONFIG_PATH="$HOME/ffmpeg_build/lib/pkgconfig" ./configure \
      --prefix="$HOME/ffmpeg_build" \
      --pkg-config-flags="--static" \
      --extra-cflags="-I$HOME/ffmpeg_build/include $ARCH_FLAG_ARM64" \
      --extra-ldflags="-L$HOME/ffmpeg_build/lib" \
      --extra-libs=-lpthread \
      --extra-libs=-lm \
      --bindir="$HOME/bin" \
      --enable-gpl \
      --enable-libfdk_aac \
      --enable-libfreetype \
      --enable-libmp3lame \
      --enable-libx264 \
      --enable-libx265 \
      --enable-nonfree
else
    PATH="$HOME/bin:$PATH" PKG_CONFIG_PATH="$HOME/ffmpeg_build/lib/pkgconfig" ./configure \
      --prefix="$HOME/ffmpeg_build" \
      --pkg-config-flags="--static" \
      --extra-cflags="-I$HOME/ffmpeg_build/include $ARCH_FLAG_X86" \
      --extra-ldflags="-L$HOME/ffmpeg_build/lib" \
      --extra-libs=-lpthread \
      --extra-libs=-lm \
      --bindir="$HOME/bin" \
      --enable-gpl \
      --enable-libfdk_aac \
      --enable-libfreetype \
      --enable-libmp3lame \
      --enable-libx264 \
      --enable-libx265 \
      --enable-nonfree
fi
make
make install

echo "================================="
echo "Building FFmpeg... Done"
echo "================================="



cd ~/bin
hash -d ./ffmpeg
./ffmpeg -codecs | grep libx26

# 12 - Remove build and source directories to free up disk space

# rm -rf ffmpeg_build/ ffmpeg_sources/

# done
printf "\nDone.\n"
