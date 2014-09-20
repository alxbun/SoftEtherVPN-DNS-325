#!/bin/bash

set -e
set -x

ROOT=`pwd`

mkdir SoftEtherVPN && cd SoftEtherVPN

BASE=`pwd`
SRC=$BASE/src
WGET="wget --prefer-family=IPv4"
DEST=$BASE/target 
CC=arm-linux-musleabi-gcc
CXX=arm-linux-musleabi-g++
LDFLAGS="-L$DEST/lib"
CPPFLAGS="-I$DEST/include"
MAKE="make -j`nproc`"
CONFIGURE="./configure --prefix=/target --host=arm-linux"
mkdir -p $SRC

# ZLIB #

mkdir $SRC/zlib && cd $SRC/zlib
$WGET http://zlib.net/zlib-1.2.8.tar.gz
tar zxvf zlib-1.2.8.tar.gz
cd zlib-1.2.8

LDFLAGS=$LDFLAGS \
CPPFLAGS=$CPPFLAGS \
CROSS_PREFIX=arm-linux-musleabi- \
./configure \
--prefix=/target

$MAKE
make install DESTDIR=$BASE

# LZO # 

mkdir $SRC/lzo && cd $SRC/lzo
$WGET http://www.oberhumer.com/opensource/lzo/download/lzo-2.08.tar.gz
tar zxvf lzo-2.08.tar.gz
cd lzo-2.08

CC=$CC \
CXX=$CXX \
LDFLAGS=$LDFLAGS \
CPPFLAGS=$CPPFLAGS \
$CONFIGURE

$MAKE
make install DESTDIR=$BASE

# OPENSSL #

mkdir -p $SRC/openssl && cd $SRC/openssl
$WGET http://www.openssl.org/source/openssl-1.0.1i.tar.gz
tar zxvf openssl-1.0.1i.tar.gz
cd openssl-1.0.1i

cp $ROOT/openssl-musl.patch  .
patch -p1 < openssl-musl.patch

./Configure linux-armv4 \
--prefix=/target shared zlib zlib-dynamic \
-D_GNU_SOURCE -D_BSD_SOURCE \
--with-zlib-lib=$DEST/lib \
--with-zlib-include=$DEST/include

make CC=$CC
make CC=$CC install INSTALLTOP=$DEST OPENSSLDIR=$DEST/ssl

# NCURSES # 

mkdir $SRC/ncurses && cd $SRC/ncurses
$WGET http://ftp.gnu.org/pub/gnu/ncurses/ncurses-5.9.tar.gz
tar zxvf ncurses-5.9.tar.gz
cd ncurses-5.9

CC=$CC \
CXX=$CXX \
LDFLAGS=$LDFLAGS \
CPPFLAGS="-D_GNU_SOURCE $CPPFLAGS" \
$CONFIGURE \
--with-shared \
--enable-overwrite \
--enable-widec \
--disable-database \
--with-fallbacks=xterm

$MAKE
make install DESTDIR=$BASE
ln -s libncursesw.a $DEST/lib/libcurses.a
ln -s libncursesw.so $DEST/lib/libcurses.so

# LIBREADLINE # 

mkdir $SRC/libreadline && cd $SRC/libreadline
$WGET ftp://ftp.cwru.edu/pub/bash/readline-6.3.tar.gz
tar zxvf readline-6.3.tar.gz
cd readline-6.3

CC=$CC \
CXX=$CXX \
LDFLAGS=$LDFLAGS \
CPPFLAGS=$CPPFLAGS \
$CONFIGURE

$MAKE
make install DESTDIR=$BASE

# LIBICONV # 


mkdir $SRC/libiconv && cd $SRC/libiconv
$WGET http://ftp.gnu.org/pub/gnu/libiconv/libiconv-1.14.tar.gz
tar zxvf libiconv-1.14.tar.gz
cd libiconv-1.14

CC=$CC \
CXX=$CXX \
LDFLAGS=$LDFLAGS \
CPPFLAGS=$CPPFLAGS \
$CONFIGURE \
--enable-static \
--disable-shared

$MAKE
make install DESTDIR=$BASE

# SOFTETHER # 

mkdir $SRC/softether && cd $SRC/softether
git clone https://github.com/SoftEtherVPN/SoftEtherVPN.git
cp -r SoftEtherVPN SoftEtherVPN_host
cd SoftEtherVPN_host

if [ "`uname -m`" == "x86_64" ];then
        cp ./src/makefiles/linux_64bit.mak ./Makefile
else
        cp ./src/makefiles/linux_32bit.mak ./Makefile
fi

$MAKE

cd ../SoftEtherVPN

cp $ROOT/100-fix-ccldflags-common.patch .
cp $ROOT/120-fix-iconv-headers-common.patch .
cp $ROOT/130-softether-tmp.patch .
patch -p1 < 100-fix-ccldflags-common.patch
patch -p1 < 120-fix-iconv-headers-common.patch
patch -p1 < 130-softether-tmp.patch

cp ./src/makefiles/linux_32bit.mak ./Makefile
sed -i 's,#CC=gcc,CC=arm-linux-musleabi-gcc,g' Makefile
sed -i 's,-lncurses -lz,-lncursesw -lz -liconv,g' Makefile
sed -i 's,ranlib,arm-linux-musleabi-ranlib,g' Makefile

CCFLAGS="$CPPFLAGS $CFLAGS" \
LDFLAGS="-static $LDFLAGS" \
$MAKE \
|| true

cp ../SoftEtherVPN_host/tmp/hamcorebuilder ./tmp/

CCFLAGS="$CPPFLAGS $CFLAGS" \
LDFLAGS="-static $LDFLAGS" \
$MAKE
