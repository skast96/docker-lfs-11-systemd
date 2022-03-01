#!/bin/bash
#
# PiLFS Build Script for LFS Version r11.0-160
# Builds chapters 5.2 - Binutils to 6.18 - GCC - Pass 2
# https://intestinate.com/pilfs
#
# Optional parameteres below:

RPI_MODEL=4                 # Which Raspberry Pi model are you building for - this selects the right GCC CPU patch.
                            # Put 64 to build for aarch64.
PARALLEL_JOBS=4             # Number of parallel make jobs, 1 for RPi1 and 4 for RPi2 and up recommended.

# End of optional parameters

set -o nounset
set -o errexit

function prebuild_sanity_check {
    if [[ $(whoami) != "lfs" ]] ; then
        echo "Not running as user lfs, you should be!"
        exit 1
    fi

    if ! [[ -v LFS ]] ; then
        echo "You forgot to set your LFS environment variable!"
        exit 1
    fi

    if ! [[ -v LFS_TGT ]] || [[ $LFS_TGT != "armv6l-lfs-linux-gnueabihf" && $LFS_TGT != "armv7l-lfs-linux-gnueabihf" && $LFS_TGT != "aarch64-lfs-linux-gnu" ]] ; then
        echo "Your LFS_TGT variable should be set to armv6l-lfs-linux-gnueabihf for RPi1, armv7l-lfs-linux-gnueabihf for RPi2 - 4 or aarch64-lfs-linux-gnu for aarch64"
        exit 1
    fi

    if ! [[ -d $LFS ]] ; then
        echo "Your LFS directory doesn't exist!"
        exit 1
    fi

    if ! [[ -d $LFS/sources ]] ; then
        echo "Can't find your sources directory!"
        exit 1
    fi

    if [[ $(stat -c %U $LFS/sources) != "lfs" ]] ; then
        echo "The sources directory should be owned by user lfs!"
        exit 1
    fi

    if ! [[ -d $LFS/tools ]] ; then
        echo "Can't find your tools directory!"
        exit 1
    fi

    if [[ $(stat -c %U $LFS/tools) != "lfs" ]] ; then
        echo "The tools directory should be owned by user lfs!"
        exit 1
    fi

    if [[ "$RPI_MODEL" == "64" && $(uname -m) != "aarch64" ]] ; then
        echo "You need to build your aarch64 LFS on an aarch64 host system!"
        exit 1
    fi
}

function check_tarballs {
LIST_OF_TARBALLS="
binutils-2.37.tar.xz
gcc-11.2.0.tar.xz
gcc-9.1.0-rpi1-cpu-default.patch
gcc-9.1.0-rpi2-cpu-default.patch
gcc-9.1.0-rpi3-cpu-default.patch
gcc-9.1.0-rpi4-cpu-default.patch
mpfr-4.1.0.tar.xz
gmp-6.2.1.tar.xz
mpc-1.2.1.tar.gz
rpi-5.15.y.tar.gz
glibc-2.35.tar.xz
glibc-2.35-fhs-1.patch
m4-1.4.19.tar.xz
ncurses-6.3.tar.gz
bash-5.1.16.tar.gz
coreutils-9.0.tar.xz
diffutils-3.8.tar.xz
file-5.41.tar.gz
findutils-4.9.0.tar.xz
gawk-5.1.1.tar.xz
grep-3.7.tar.xz
gzip-1.11.tar.xz
make-4.3.tar.gz
patch-2.7.6.tar.xz
sed-4.8.tar.xz
tar-1.34.tar.xz
xz-5.2.5.tar.xz
"

for tarball in $LIST_OF_TARBALLS ; do
    if ! [[ -f $LFS/sources/$tarball ]] ; then
        echo "Can't find $LFS/sources/$tarball!"
        exit 1
    fi
done
}

function timer {
    if [[ $# -eq 0 ]]; then
        echo $(date '+%s')
    else
        local stime=$1
        etime=$(date '+%s')
        if [[ -z "$stime" ]]; then stime=$etime; fi
        dt=$((etime - stime))
        ds=$((dt % 60))
        dm=$(((dt / 60) % 60))
        dh=$((dt / 3600))
        printf '%02d:%02d:%02d' $dh $dm $ds
    fi
}

prebuild_sanity_check
check_tarballs

if [[ $(free | grep 'Swap:' | tr -d ' ' | cut -d ':' -f2) == "000" ]] ; then
    echo -e "\nYou are almost certainly going to want to add some swap space before building!"
    echo -e "(See https://intestinate.com/pilfs/beyond.html#addswap for instructions)"
    echo -e "Continue without swap?"
    select yn in "Yes" "No"; do
        case $yn in
            Yes) break;;
            No) exit;;
        esac
    done
fi

echo -e "\nThis is your last chance to quit before we start building... continue?"
echo "(Note that if anything goes wrong during the build, the script will abort mission)"
select yn in "Yes" "No"; do
    case $yn in
        Yes) break;;
        No) exit;;
    esac
done

total_time=$(timer)
sbu_time=$(timer)

echo "# 5.2. Binutils-2.37 - Pass 1"
cd $LFS/sources
tar -Jxf binutils-2.37.tar.xz
cd binutils-2.37
mkdir -v build
cd build
../configure --prefix=$LFS/tools        \
             --with-sysroot=$LFS        \
             --target=$LFS_TGT          \
             --disable-nls              \
             --disable-werror
make -j $PARALLEL_JOBS
make -j 1 install
cd $LFS/sources
rm -rf binutils-2.37

echo -e "\n=========================="
printf 'Your SBU time is: %s\n' $(timer $sbu_time)
echo -e "==========================\n"

echo "# 5.3. gcc-11.2.0 - Pass 1"
tar -Jxf gcc-11.2.0.tar.xz
cd gcc-11.2.0
if [[ "$RPI_MODEL" == "64" ]] ; then
    sed -e '/mabi.lp64=/s/lib64/lib/' -i.orig gcc/config/aarch64/t-aarch64-linux
else
    patch -Np1 -i ../gcc-9.1.0-rpi$RPI_MODEL-cpu-default.patch
fi
tar -Jxf ../mpfr-4.1.0.tar.xz
mv -v mpfr-4.1.0 mpfr
tar -Jxf ../gmp-6.2.1.tar.xz
mv -v gmp-6.2.1 gmp
tar -zxf ../mpc-1.2.1.tar.gz
mv -v mpc-1.2.1 mpc
mkdir -v build
cd build
../configure                                       \
    --target=$LFS_TGT                              \
    --prefix=$LFS/tools                            \
    --with-glibc-version=2.35                      \
    --with-sysroot=$LFS                            \
    --with-newlib                                  \
    --without-headers                              \
    --enable-initfini-array                        \
    --disable-nls                                  \
    --disable-shared                               \
    --disable-multilib                             \
    --disable-decimal-float                        \
    --disable-threads                              \
    --disable-libatomic                            \
    --disable-libgomp                              \
    --disable-libquadmath                          \
    --disable-libssp                               \
    --disable-libvtv                               \
    --disable-libstdcxx                            \
    --enable-languages=c,c++
make -j 1
make install
cd ..
cat gcc/limitx.h gcc/glimits.h gcc/limity.h > `dirname $($LFS_TGT-gcc -print-libgcc-file-name)`/install-tools/include/limits.h
cd $LFS/sources
rm -rf gcc-11.2.0

echo "# 5.4. Raspberry Pi Linux API Headers"
tar -zxf rpi-5.15.y.tar.gz
cd linux-rpi-5.15.y
make mrproper
make headers
find usr/include -name '.*' -delete
rm usr/include/Makefile
cp -rv usr/include $LFS/usr
cd $LFS/sources
rm -rf linux-rpi-5.15.y

echo "# 5.5. Glibc-2.35"
tar -Jxf glibc-2.35.tar.xz
cd glibc-2.35
patch -Np1 -i ../glibc-2.35-fhs-1.patch
mkdir -v build
cd build
echo "rootsbindir=/usr/sbin" > configparms
../configure                             \
      --prefix=/usr                      \
      --host=$LFS_TGT                    \
      --build=$(../scripts/config.guess) \
      --enable-kernel=3.2                \
      --with-headers=$LFS/usr/include    \
      libc_cv_slibdir=/usr/lib
make -j $PARALLEL_JOBS
make DESTDIR=$LFS install
sed '/RTLDLIST=/s@/usr@@g' -i $LFS/usr/bin/ldd
$LFS/tools/libexec/gcc/$LFS_TGT/11.2.0/install-tools/mkheaders
# Compatibility symlink for non ld-linux-armhf awareness
ln -sv ld-2.35.so $LFS/tools/lib/ld-linux.so.3
cd $LFS/sources
rm -rf glibc-2.35

echo "# 5.6. Libstdc++ from GCC-11.2.0 - Pass 1"
tar -Jxf gcc-11.2.0.tar.xz
cd gcc-11.2.0
mkdir -v build
cd build
../libstdc++-v3/configure           \
    --host=$LFS_TGT                 \
    --build=$(../config.guess)      \
    --prefix=/usr                   \
    --disable-multilib              \
    --disable-nls                   \
    --disable-libstdcxx-pch         \
    --with-gxx-include-dir=/tools/$LFS_TGT/include/c++/11.2.0
make -j $PARALLEL_JOBS
make DESTDIR=$LFS install
cd $LFS/sources
rm -rf gcc-11.2.0

echo "# 6.2. M4-1.4.19"
tar -Jxf m4-1.4.19.tar.xz
cd m4-1.4.19
./configure --prefix=/usr   \
            --host=$LFS_TGT \
            --build=$(build-aux/config.guess)
make -j $PARALLEL_JOBS
make DESTDIR=$LFS install
cd $LFS/sources
rm -rf m4-1.4.19

echo "# 6.3. Ncurses-6.3"
tar -zxf ncurses-6.3.tar.gz
cd ncurses-6.3
sed -i s/mawk// configure
mkdir build
pushd build
../configure
make -j $PARALLEL_JOBS -C include
make -j $PARALLEL_JOBS -C progs tic
popd
./configure --prefix=/usr                \
            --host=$LFS_TGT              \
            --build=$(./config.guess)    \
            --mandir=/usr/share/man      \
            --with-manpage-format=normal \
            --with-shared                \
            --without-debug              \
            --without-ada                \
            --without-normal             \
            --enable-widec
make -j $PARALLEL_JOBS
make DESTDIR=$LFS TIC_PATH=$(pwd)/build/progs/tic install
echo "INPUT(-lncursesw)" > $LFS/usr/lib/libncurses.so
cd $LFS/sources
rm -rf ncurses-6.3

echo "# 6.4. Bash-5.1.16"
tar -zxf bash-5.1.16.tar.gz
cd bash-5.1.16
./configure --prefix=/usr                   \
            --build=$(support/config.guess) \
            --host=$LFS_TGT                 \
            --without-bash-malloc
make -j $PARALLEL_JOBS
make DESTDIR=$LFS install
ln -sv bash $LFS/bin/sh
cd $LFS/sources
rm -rf bash-5.1.16

echo "# 6.5. Coreutils-9.0"
tar -Jxf coreutils-9.0.tar.xz
cd coreutils-9.0
./configure --prefix=/usr                     \
            --host=$LFS_TGT                   \
            --build=$(build-aux/config.guess) \
            --enable-install-program=hostname \
            --enable-no-install-program=kill,uptime
make -j $PARALLEL_JOBS
make DESTDIR=$LFS install
mv -v $LFS/usr/bin/chroot              $LFS/usr/sbin
mkdir -pv $LFS/usr/share/man/man8
mv -v $LFS/usr/share/man/man1/chroot.1 $LFS/usr/share/man/man8/chroot.8
sed -i 's/"1"/"8"/'                    $LFS/usr/share/man/man8/chroot.8
cd $LFS/sources
rm -rf coreutils-9.0

echo "# 6.6. Diffutils-3.8"
tar -Jxf diffutils-3.8.tar.xz
cd diffutils-3.8
./configure --prefix=/usr --host=$LFS_TGT
make -j $PARALLEL_JOBS
make DESTDIR=$LFS install
cd $LFS/sources
rm -rf diffutils-3.8

echo "# 6.7. File-5.41"
tar -zxf file-5.41.tar.gz
cd file-5.41
mkdir build
pushd build
../configure --disable-bzlib      \
             --disable-libseccomp \
             --disable-xzlib      \
             --disable-zlib
make -j $PARALLEL_JOBS
popd
./configure --prefix=/usr --host=$LFS_TGT --build=$(./config.guess)
make -j $PARALLEL_JOBS FILE_COMPILE=$(pwd)/build/src/file
make DESTDIR=$LFS install
cd $LFS/sources
rm -rf file-5.41

echo "# 6.8. Findutils-4.9.0"
tar -Jxf findutils-4.9.0.tar.xz
cd findutils-4.9.0
./configure --prefix=/usr   \
            --localstatedir=/var/lib/locate \
            --host=$LFS_TGT \
            --build=$(build-aux/config.guess)
make -j $PARALLEL_JOBS
make DESTDIR=$LFS install
cd $LFS/sources
rm -rf findutils-4.9.0

echo "# 6.9. Gawk-5.1.1"
tar -Jxf gawk-5.1.1.tar.xz
cd gawk-5.1.1
sed -i 's/extras//' Makefile.in
./configure --prefix=/usr   \
            --host=$LFS_TGT \
            --build=$(build-aux/config.guess)
make -j $PARALLEL_JOBS
make DESTDIR=$LFS install
cd $LFS/sources
rm -rf gawk-5.1.1

echo "# 6.10. Grep-3.7"
tar -Jxf grep-3.7.tar.xz
cd grep-3.7
./configure --prefix=/usr   \
            --host=$LFS_TGT
make -j $PARALLEL_JOBS
make DESTDIR=$LFS install
cd $LFS/sources
rm -rf grep-3.7

echo "# 6.11. Gzip-1.11"
tar -Jxf gzip-1.11.tar.xz
cd gzip-1.11
./configure --prefix=/usr --host=$LFS_TGT
make -j $PARALLEL_JOBS
make DESTDIR=$LFS install
cd $LFS/sources
rm -rf gzip-1.11

echo "# 6.12. Make-4.3"
tar -zxf make-4.3.tar.gz
cd make-4.3
./configure --prefix=/usr   \
            --without-guile \
            --host=$LFS_TGT \
            --build=$(build-aux/config.guess)
make -j $PARALLEL_JOBS
make DESTDIR=$LFS install
cd $LFS/sources
rm -rf make-4.3

echo "# 6.13. Patch-2.7.6"
tar -Jxf patch-2.7.6.tar.xz
cd patch-2.7.6
./configure --prefix=/usr   \
            --host=$LFS_TGT \
            --build=$(build-aux/config.guess)
make -j $PARALLEL_JOBS
make DESTDIR=$LFS install
cd $LFS/sources
rm -rf patch-2.7.6

echo "# 6.14. Sed-4.8"
tar -Jxf sed-4.8.tar.xz
cd sed-4.8
./configure --prefix=/usr   \
            --host=$LFS_TGT
make -j $PARALLEL_JOBS
make DESTDIR=$LFS install
cd $LFS/sources
rm -rf sed-4.8

echo "# 6.15. Tar-1.34"
tar -Jxf tar-1.34.tar.xz
cd tar-1.34
./configure --prefix=/usr                     \
            --host=$LFS_TGT                   \
            --build=$(build-aux/config.guess)
make -j $PARALLEL_JOBS
make DESTDIR=$LFS install
cd $LFS/sources
rm -rf tar-1.34

echo "# 6.16. Xz-5.2.5"
tar -Jxf xz-5.2.5.tar.xz
cd xz-5.2.5
./configure --prefix=/usr                     \
            --host=$LFS_TGT                   \
            --build=$(build-aux/config.guess) \
            --disable-static                  \
            --docdir=/usr/share/doc/xz-5.2.5
make -j $PARALLEL_JOBS
make DESTDIR=$LFS install
cd $LFS/sources
rm -rf xz-5.2.5

echo "# 6.17. Binutils-2.37 - Pass 2"
tar -Jxf binutils-2.37.tar.xz
cd binutils-2.37
mkdir -v build
cd build
../configure                   \
    --prefix=/usr              \
    --build=$(../config.guess) \
    --host=$LFS_TGT            \
    --disable-nls              \
    --enable-shared            \
    --disable-werror           \
    --enable-64-bit-bfd
make -j $PARALLEL_JOBS
make -j 1 DESTDIR=$LFS install
install -vm755 libctf/.libs/libctf.so.0.0.0 $LFS/usr/lib
cd $LFS/sources
rm -rf binutils-2.37

echo "# 6.18. gcc-11.2.0 - Pass 2"
tar -Jxf gcc-11.2.0.tar.xz
cd gcc-11.2.0
if [[ "$RPI_MODEL" == "64" ]] ; then
    sed -e '/mabi.lp64=/s/lib64/lib/' -i.orig gcc/config/aarch64/t-aarch64-linux
else
    patch -Np1 -i ../gcc-9.1.0-rpi$RPI_MODEL-cpu-default.patch
fi
tar -Jxf ../mpfr-4.1.0.tar.xz
mv -v mpfr-4.1.0 mpfr
tar -Jxf ../gmp-6.2.1.tar.xz
mv -v gmp-6.2.1 gmp
tar -zxf ../mpc-1.2.1.tar.gz
mv -v mpc-1.2.1 mpc
mkdir -v build
cd build
mkdir -pv $LFS_TGT/libgcc
ln -s ../../../libgcc/gthr-posix.h $LFS_TGT/libgcc/gthr-default.h
../configure                                       \
    --build=$(../config.guess)                     \
    --host=$LFS_TGT                                \
    --prefix=/usr                                  \
    CC_FOR_TARGET=$LFS_TGT-gcc                     \
    --with-build-sysroot=$LFS                      \
    --enable-initfini-array                        \
    --disable-nls                                  \
    --disable-multilib                             \
    --disable-decimal-float                        \
    --disable-libatomic                            \
    --disable-libgomp                              \
    --disable-libquadmath                          \
    --disable-libssp                               \
    --disable-libvtv                               \
    --disable-libstdcxx                            \
    --enable-languages=c,c++
make -j 1
make DESTDIR=$LFS install
ln -sv gcc $LFS/usr/bin/cc
cd $LFS/sources
rm -rf gcc-11.2.0

echo -e "----------------------------------------------------"
echo -e "\nYou made it! This is the end of chapter 6!"
printf 'Total script time: %s\n' $(timer $total_time)
echo -e "Now continue reading from \"7. Entering Chroot and Building Additional Temporary Tools\""
