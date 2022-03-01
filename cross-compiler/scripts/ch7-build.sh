#!/bin/bash
#
# PiLFS Build Script for LFS Version r11.0-160
# Builds chapters 7.7 Libstdc++ from GCC - Pass 2 to 8.75 - Sysvinit
# https://intestinate.com/pilfs
#
# Optional parameteres below:

RPI_MODEL=4                     # Which Raspberry Pi model are you building for - this selects the right GCC CPU patch.
                                # Put 64 to build for aarch64.
PARALLEL_JOBS=4                 # Number of parallel make jobs, 1 for RPi1 and 4 for RPi2 and up recommended.
LOCAL_TIMEZONE=Europe/London    # Use this timezone from /usr/share/zoneinfo/ to set /etc/localtime. See "8.8.2 Configuring Glibc".
GROFF_PAPER_SIZE=A4             # Use this default paper size for Groff. See "8.57 Groff".
INSTALL_OPTIONAL_DOCS=1         # Install optional documentation when given a choice?
INSTALL_ALL_LOCALES=0           # Install all glibc locales? By default only en_US.ISO-8859-1 and en_US.UTF-8 are installed.

# End of optional parameters

set -o nounset
set -o errexit

function prebuild_sanity_check {
    if [[ $(whoami) != "root" ]] ; then
        echo "You should be running as root for chapter 7!"
        exit 1
    fi

    if ! [[ -d /sources ]] ; then
        echo "Can't find your sources directory! Did you forget to chroot?"
        exit 1
    fi

    if ! [[ -d /tools ]] ; then
        echo "Can't find your tools directory! Did you forget to chroot?"
        exit 1
    fi
}

function check_tarballs {
LIST_OF_TARBALLS="
gcc-11.2.0.tar.xz
gcc-9.1.0-rpi1-cpu-default.patch
gcc-9.1.0-rpi2-cpu-default.patch
gcc-9.1.0-rpi3-cpu-default.patch
gcc-9.1.0-rpi4-cpu-default.patch
bison-3.8.2.tar.xz
gettext-0.21.tar.xz
perl-5.34.0.tar.xz
perl-5.34.0-upstream_fixes-1.patch
Python-3.10.2.tar.xz
python-3.10.2-docs-html.tar.bz2
texinfo-6.8.tar.xz
util-linux-2.37.3.tar.xz
man-pages-5.13.tar.xz
tcl8.6.12-src.tar.gz
tcl8.6.12-html.tar.gz
expect5.45.4.tar.gz
expect5.45-aarch64-fix.patch
dejagnu-1.6.3.tar.gz
iana-etc-20220128.tar.gz
glibc-2.35.tar.xz
glibc-2.35-fhs-1.patch
tzdata2021e.tar.gz
zlib-1.2.11.tar.xz
bzip2-1.0.8.tar.gz
bzip2-1.0.8-install_docs-1.patch
xz-5.2.5.tar.xz
zstd-1.5.2.tar.gz
file-5.41.tar.gz
readline-8.1.2.tar.gz
m4-1.4.19.tar.xz
bc-5.2.1.tar.xz
flex-2.6.4.tar.gz
binutils-2.37.tar.xz
binutils-2.37-upstream_fix-1.patch
gmp-6.2.1.tar.xz
mpfr-4.1.0.tar.xz
mpc-1.2.1.tar.gz
attr-2.5.1.tar.gz
acl-2.3.1.tar.xz
libcap-2.63.tar.xz
shadow-4.11.1.tar.xz
pkg-config-0.29.2.tar.gz
ncurses-6.3.tar.gz
sed-4.8.tar.xz
psmisc-23.4.tar.xz
grep-3.7.tar.xz
bash-5.1.16.tar.gz
libtool-2.4.6.tar.xz
gdbm-1.23.tar.gz
gperf-3.1.tar.gz
expat-2.4.4.tar.xz
inetutils-2.2.tar.xz
XML-Parser-2.46.tar.gz
intltool-0.51.0.tar.gz
autoconf-2.71.tar.xz
automake-1.16.5.tar.xz
kmod-29.tar.xz
elfutils-0.186.tar.bz2
libffi-3.4.2.tar.gz
openssl-3.0.1.tar.gz
ninja-1.10.2.tar.gz
meson-0.61.1.tar.gz
coreutils-9.0.tar.xz
coreutils-9.0-i18n-1.patch
coreutils-9.0-chmod_fix-1.patch
check-0.15.2.tar.gz
diffutils-3.8.tar.xz
gawk-5.1.1.tar.xz
findutils-4.9.0.tar.xz
groff-1.22.4.tar.gz
less-590.tar.gz
gzip-1.11.tar.xz
iproute2-5.16.0.tar.xz
kbd-2.4.0.tar.xz
kbd-2.4.0-backspace-1.patch
libpipeline-1.5.5.tar.gz
make-4.3.tar.gz
patch-2.7.6.tar.xz
man-db-2.10.0.tar.xz
tar-1.34.tar.xz
vim-8.2.4236.tar.gz
eudev-3.2.11.tar.gz
udev-lfs-20171102.tar.xz
procps-ng-3.3.17.tar.xz
e2fsprogs-1.46.5.tar.gz
sysklogd-1.5.1.tar.gz
sysvinit-3.01.tar.xz
sysvinit-3.01-consolidated-1.patch
master.tar.gz
v2022.01.25-138a1.tar.gz
"

for tarball in $LIST_OF_TARBALLS ; do
    if ! [[ -f /sources/$tarball ]] ; then
        echo "Can't find /sources/$tarball!"
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

if [[ $(cat /proc/swaps | wc -l) == 1 ]] ; then
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

echo "# 7.7. Libstdc++ from GCC-11.2.0, Pass 2"
tar -Jxf gcc-11.2.0.tar.xz
cd gcc-11.2.0
ln -s gthr-posix.h libgcc/gthr-default.h
mkdir -v build
cd build
if [[ "$RPI_MODEL" == "64" ]] ; then
    ../libstdc++-v3/configure            \
        CXXFLAGS="-g -O2 -D_GNU_SOURCE"  \
        --prefix=/usr                    \
        --disable-multilib               \
        --disable-nls                    \
        --host=$(uname -m)-lfs-linux-gnu \
        --disable-libstdcxx-pch
else
    ../libstdc++-v3/configure            \
        CXXFLAGS="-g -O2 -D_GNU_SOURCE"  \
        --prefix=/usr                    \
        --disable-multilib               \
        --disable-nls                    \
        --host=$(uname -m)-lfs-linux-gnueabihf \
        --disable-libstdcxx-pch
fi
make -j $PARALLEL_JOBS
make install
cd /sources
rm -rf gcc-11.2.0

echo "# 7.8. Gettext-0.21"
tar -Jxf gettext-0.21.tar.xz
cd gettext-0.21
./configure --disable-shared
make -j $PARALLEL_JOBS
cp -v gettext-tools/src/{msgfmt,msgmerge,xgettext} /usr/bin
cd /sources
rm -rf gettext-0.21

echo "# 7.9. Bison-3.8.2"
tar -Jxf bison-3.8.2.tar.xz
cd bison-3.8.2
./configure --prefix=/usr \
            --docdir=/usr/share/doc/bison-3.8.2
make -j $PARALLEL_JOBS
make install
cd /sources
rm -rf bison-3.8.2

echo "# 7.10. Perl-5.34.0"
tar -Jxf perl-5.34.0.tar.xz
cd perl-5.34.0
sh Configure -des                                        \
             -Dprefix=/usr                               \
             -Dvendorprefix=/usr                         \
             -Dprivlib=/usr/lib/perl5/5.34/core_perl     \
             -Darchlib=/usr/lib/perl5/5.34/core_perl     \
             -Dsitelib=/usr/lib/perl5/5.34/site_perl     \
             -Dsitearch=/usr/lib/perl5/5.34/site_perl    \
             -Dvendorlib=/usr/lib/perl5/5.34/vendor_perl \
             -Dvendorarch=/usr/lib/perl5/5.34/vendor_perl
make -j $PARALLEL_JOBS
make install
cd /sources
rm -rf perl-5.34.0

echo "# 7.11. Python-3.10.2"
tar -Jxf Python-3.10.2.tar.xz
cd Python-3.10.2
./configure --prefix=/usr   \
            --enable-shared \
            --without-ensurepip
make -j $PARALLEL_JOBS
make install 
cd /sources
rm -rf Python-3.10.2

echo "# 7.12. Texinfo-6.8"
tar -Jxf texinfo-6.8.tar.xz
cd texinfo-6.8
sed -e 's/__attribute_nonnull__/__nonnull/' -i gnulib/lib/malloc/dynarray-skeleton.c
./configure --prefix=/usr
make -j $PARALLEL_JOBS
make install
cd /sources
rm -rf texinfo-6.8

echo "# 7.13. Util-linux-2.37.3"
tar -Jxf util-linux-2.37.3.tar.xz
cd util-linux-2.37.3
mkdir -pv /var/lib/hwclock
./configure ADJTIME_PATH=/var/lib/hwclock/adjtime    \
            --libdir=/usr/lib    \
            --docdir=/usr/share/doc/util-linux-2.37.3 \
            --disable-chfn-chsh  \
            --disable-login      \
            --disable-nologin    \
            --disable-su         \
            --disable-setpriv    \
            --disable-runuser    \
            --disable-pylibmount \
            --disable-static     \
            --without-python     \
            runstatedir=/run
make -j $PARALLEL_JOBS
make install
cd /sources
rm -rf util-linux-2.37.3

echo "# 7.14. Cleaning up and Saving the Temporary System"
rm -rf /usr/share/{info,man,doc}/*
find /usr/{lib,libexec} -name \*.la -delete
rm -rf /tools
# In order to keep our script running we will not exit the chroot environment here

echo "# 8.3. Man-pages-5.13"
tar -Jxf man-pages-5.13.tar.xz
cd man-pages-5.13
make prefix=/usr install
cd /sources
rm -rf man-pages-5.13

echo "# 8.4. Iana-Etc-20220128"
tar -zxf iana-etc-20220128.tar.gz
cd iana-etc-20220128
cp services protocols /etc
cd /sources
rm -rf iana-etc-20220128

echo "# 8.5. Glibc-2.35"
tar -Jxf glibc-2.35.tar.xz
cd glibc-2.35
patch -Np1 -i ../glibc-2.35-fhs-1.patch
mkdir -v build
cd build
echo "rootsbindir=/usr/sbin" > configparms
../configure --prefix=/usr                            \
             --disable-werror                         \
             --enable-kernel=3.2                      \
             --enable-stack-protector=strong          \
             --with-headers=/usr/include              \
             libc_cv_slibdir=/usr/lib
make -j $PARALLEL_JOBS
touch /etc/ld.so.conf
sed '/test-installation/s@$(PERL)@echo not running@' -i ../Makefile
make install
sed '/RTLDLIST=/s@/usr@@g' -i /usr/bin/ldd
cp -v ../nscd/nscd.conf /etc/nscd.conf
mkdir -pv /var/cache/nscd
if [[ $INSTALL_ALL_LOCALES = 1 ]] ; then
    make localedata/install-locales
else
    mkdir -pv /usr/lib/locale
    localedef -i en_US -f ISO-8859-1 en_US
    localedef -i en_US -f UTF-8 en_US.UTF-8
fi
cat > /etc/nsswitch.conf << "EOF"
# Begin /etc/nsswitch.conf

passwd: files
group: files
shadow: files

hosts: files dns
networks: files

protocols: files
services: files
ethers: files
rpc: files

# End /etc/nsswitch.conf
EOF
tar -zxf ../../tzdata2021e.tar.gz
ZONEINFO=/usr/share/zoneinfo
mkdir -pv $ZONEINFO/{posix,right}
for tz in etcetera southamerica northamerica europe africa antarctica  \
          asia australasia backward; do
    zic -L /dev/null   -d $ZONEINFO       ${tz}
    zic -L /dev/null   -d $ZONEINFO/posix ${tz}
    zic -L leapseconds -d $ZONEINFO/right ${tz}
done
cp -v zone.tab zone1970.tab iso3166.tab $ZONEINFO
zic -d $ZONEINFO -p America/New_York
unset ZONEINFO
if ! [[ -f /usr/share/zoneinfo/$LOCAL_TIMEZONE ]] ; then
    echo "Seems like your timezone won't work out. Defaulting to London. Either fix it yourself later or consider moving there :)"
    ln -sfv /usr/share/zoneinfo/Europe/London /etc/localtime
else
    ln -sfv /usr/share/zoneinfo/$LOCAL_TIMEZONE /etc/localtime
fi
cat > /etc/ld.so.conf << "EOF"
# Begin /etc/ld.so.conf
/usr/local/lib

EOF
cat >> /etc/ld.so.conf << "EOF"
# Add an include directory
include /etc/ld.so.conf.d/*.conf

EOF
mkdir -pv /etc/ld.so.conf.d
# Compatibility symlink for non ld-linux-armhf awareness
ln -sv ld-2.35.so /lib/ld-linux.so.3
cd /sources
rm -rf glibc-2.35

echo "# 8.6. Zlib-1.2.11"
tar -Jxf zlib-1.2.11.tar.xz
cd zlib-1.2.11
./configure --prefix=/usr
make -j $PARALLEL_JOBS
make install
rm -fv /usr/lib/libz.a
cd /sources
rm -rf zlib-1.2.11

echo "# 8.7. Bzip2-1.0.8"
tar -zxf bzip2-1.0.8.tar.gz
cd bzip2-1.0.8
patch -Np1 -i ../bzip2-1.0.8-install_docs-1.patch
sed -i 's@\(ln -s -f \)$(PREFIX)/bin/@\1@' Makefile
sed -i "s@(PREFIX)/man@(PREFIX)/share/man@g" Makefile
make -j $PARALLEL_JOBS -f Makefile-libbz2_so
make clean
make -j $PARALLEL_JOBS
make PREFIX=/usr install
cp -av libbz2.so.* /usr/lib
ln -sv libbz2.so.1.0.8 /usr/lib/libbz2.so
cp -v bzip2-shared /usr/bin/bzip2
for i in /usr/bin/{bzcat,bunzip2}; do
  ln -sfv bzip2 $i
done
rm -fv /usr/lib/libbz2.a
cd /sources
rm -rf bzip2-1.0.8

echo "# 8.8. Xz-5.2.5"
tar -Jxf xz-5.2.5.tar.xz
cd xz-5.2.5
./configure --prefix=/usr    \
            --disable-static \
            --docdir=/usr/share/doc/xz-5.2.5
make -j $PARALLEL_JOBS
make install
cd /sources
rm -rf xz-5.2.5

echo "# 8.9. Zstd-1.5.2"
tar -zxf zstd-1.5.2.tar.gz
cd zstd-1.5.2
make -j $PARALLEL_JOBS
make prefix=/usr install
rm -v /usr/lib/libzstd.a
cd /sources
rm -rf zstd-1.5.2

echo "# 8.10. File-5.41"
tar -zxf file-5.41.tar.gz
cd file-5.41
./configure --prefix=/usr
make -j $PARALLEL_JOBS
make install
cd /sources
rm -rf file-5.41

echo "# 8.11. Readline-8.1.2"
tar -zxf readline-8.1.2.tar.gz
cd readline-8.1.2
sed -i '/MV.*old/d' Makefile.in
sed -i '/{OLDSUFF}/c:' support/shlib-install
./configure --prefix=/usr    \
            --disable-static \
            --with-curses    \
            --docdir=/usr/share/doc/readline-8.1.2
make -j $PARALLEL_JOBS SHLIB_LIBS="-lncursesw"
make SHLIB_LIBS="-lncursesw" install
if [[ $INSTALL_OPTIONAL_DOCS = 1 ]] ; then
    install -v -m644 doc/*.{ps,pdf,html,dvi} /usr/share/doc/readline-8.1.2
fi
cd /sources
rm -rf readline-8.1.2

echo "# 8.12. M4-1.4.19"
tar -Jxf m4-1.4.19.tar.xz
cd m4-1.4.19
./configure --prefix=/usr
make -j $PARALLEL_JOBS
make install
cd /sources
rm -rf m4-1.4.19

echo "# 8.13. Bc-5.2.1"
tar -Jxf bc-5.2.1.tar.xz
cd bc-5.2.1
CC=gcc ./configure --prefix=/usr -G -O3
make -j $PARALLEL_JOBS
make install
cd /sources
rm -rf bc-5.2.1

echo "# 8.14. Flex-2.6.4"
tar -zxf flex-2.6.4.tar.gz
cd flex-2.6.4
./configure --prefix=/usr \
            --docdir=/usr/share/doc/flex-2.6.4 \
            --disable-static
make -j $PARALLEL_JOBS
make install
ln -sv flex /usr/bin/lex
cd /sources
rm -rf flex-2.6.4

echo "# 8.15. Tcl-8.6.12"
tar -zxf tcl8.6.12-src.tar.gz
cd tcl8.6.12
tar -xf ../tcl8.6.12-html.tar.gz --strip-components=1
SRCDIR=$(pwd)
cd unix
if [[ "$RPI_MODEL" == "64" ]] ; then
./configure --prefix=/usr           \
            --mandir=/usr/share/man \
            --enable-64bit

else
./configure --prefix=/usr           \
            --mandir=/usr/share/man
fi
make -j $PARALLEL_JOBS
sed -e "s|$SRCDIR/unix|/usr/lib|" \
    -e "s|$SRCDIR|/usr/include|"  \
    -i tclConfig.sh
sed -e "s|$SRCDIR/unix/pkgs/tdbc1.1.3|/usr/lib/tdbc1.1.3|" \
    -e "s|$SRCDIR/pkgs/tdbc1.1.3/generic|/usr/include|"    \
    -e "s|$SRCDIR/pkgs/tdbc1.1.3/library|/usr/lib/tcl8.6|" \
    -e "s|$SRCDIR/pkgs/tdbc1.1.3|/usr/include|"            \
    -i pkgs/tdbc1.1.3/tdbcConfig.sh
sed -e "s|$SRCDIR/unix/pkgs/itcl4.2.2|/usr/lib/itcl4.2.2|" \
    -e "s|$SRCDIR/pkgs/itcl4.2.2/generic|/usr/include|"    \
    -e "s|$SRCDIR/pkgs/itcl4.2.2|/usr/include|"            \
    -i pkgs/itcl4.2.2/itclConfig.sh
unset SRCDIR
make install
chmod -v u+w /usr/lib/libtcl8.6.so
make install-private-headers
ln -sfv tclsh8.6 /usr/bin/tclsh
mv /usr/share/man/man3/{Thread,Tcl_Thread}.3
if [[ $INSTALL_OPTIONAL_DOCS = 1 ]] ; then
    mkdir -v -p /usr/share/doc/tcl-8.6.12
    cp -v -r  ../html/* /usr/share/doc/tcl-8.6.12
fi
cd /sources
rm -rf tcl8.6.12

echo "# 8.16. Expect-5.45.4"
tar -zxf expect5.45.4.tar.gz
cd expect5.45.4
if [[ "$RPI_MODEL" == "64" ]] ; then
    patch -Np1 -i ../expect5.45-aarch64-fix.patch
fi
./configure --prefix=/usr           \
            --with-tcl=/usr/lib     \
            --enable-shared         \
            --mandir=/usr/share/man \
            --with-tclinclude=/usr/include
make -j $PARALLEL_JOBS
make install
ln -svf expect5.45.4/libexpect5.45.4.so /usr/lib
cd /sources
rm -rf expect5.45.4

echo "# 8.17. DejaGNU-1.6.3"
tar -zxf dejagnu-1.6.3.tar.gz
cd dejagnu-1.6.3
mkdir -v build
cd build
../configure --prefix=/usr
make install
if [[ $INSTALL_OPTIONAL_DOCS = 1 ]] ; then
    makeinfo --html --no-split -o doc/dejagnu.html ../doc/dejagnu.texi
    makeinfo --plaintext       -o doc/dejagnu.txt  ../doc/dejagnu.texi
    install -v -dm755 /usr/share/doc/dejagnu-1.6.3
    install -v -m644 doc/dejagnu.{html,txt} /usr/share/doc/dejagnu-1.6.3
fi
cd /sources
rm -rf dejagnu-1.6.3

echo "# 8.18. Binutils-2.37"
tar -Jxf binutils-2.37.tar.xz
cd binutils-2.37
patch -Np1 -i ../binutils-2.37-upstream_fix-1.patch
sed -i '63d' etc/texi2pod.pl
find -name \*.1 -delete
mkdir -v build
cd build
../configure --prefix=/usr       \
             --enable-gold       \
             --enable-ld=default \
             --enable-plugins    \
             --enable-shared     \
             --disable-werror    \
             --enable-64-bit-bfd \
             --with-system-zlib
make -j $PARALLEL_JOBS tooldir=/usr
make -j 1 tooldir=/usr install
rm -fv /usr/lib/lib{bfd,ctf,ctf-nobfd,opcodes}.a
cd /sources
rm -rf binutils-2.37

echo "# 8.19. GMP-6.2.1"
tar -Jxf gmp-6.2.1.tar.xz
cd gmp-6.2.1
./configure --prefix=/usr    \
            --enable-cxx     \
            --disable-static \
            --docdir=/usr/share/doc/gmp-6.2.1
make -j $PARALLEL_JOBS
make install
if [[ $INSTALL_OPTIONAL_DOCS = 1 ]] ; then
    make html
    make install-html
fi
cd /sources
rm -rf gmp-6.2.1

echo "# 8.20. MPFR-4.1.0"
tar -Jxf mpfr-4.1.0.tar.xz
cd mpfr-4.1.0
./configure  --prefix=/usr        \
             --disable-static     \
             --enable-thread-safe \
             --docdir=/usr/share/doc/mpfr-4.1.0
make -j $PARALLEL_JOBS
make install
if [[ $INSTALL_OPTIONAL_DOCS = 1 ]] ; then
    make html
    make install-html
fi
cd /sources
rm -rf mpfr-4.1.0

echo "# 8.21. MPC-1.2.1"
tar -zxf mpc-1.2.1.tar.gz
cd mpc-1.2.1
./configure --prefix=/usr    \
            --disable-static \
            --docdir=/usr/share/doc/mpc-1.2.1
make -j $PARALLEL_JOBS
make install
if [[ $INSTALL_OPTIONAL_DOCS = 1 ]] ; then
    make html
    make install-html
fi
cd /sources
rm -rf mpc-1.2.1

echo "# 8.22. Attr-2.5.1"
tar -zxf attr-2.5.1.tar.gz
cd attr-2.5.1
./configure --prefix=/usr     \
            --disable-static  \
            --sysconfdir=/etc \
            --docdir=/usr/share/doc/attr-2.5.1
make -j $PARALLEL_JOBS
make install
cd /sources
rm -rf attr-2.5.1

echo "# 8.23. Acl-2.3.1"
tar -Jxf acl-2.3.1.tar.xz
cd acl-2.3.1
./configure --prefix=/usr         \
            --disable-static      \
            --docdir=/usr/share/doc/acl-2.3.1
make -j $PARALLEL_JOBS
make install
cd /sources
rm -rf acl-2.3.1

echo "# 8.24. Libcap-2.63"
tar -Jxf libcap-2.63.tar.xz
cd libcap-2.63
sed -i '/install -m.*STA/d' libcap/Makefile
make -j $PARALLEL_JOBS prefix=/usr lib=lib
make prefix=/usr lib=lib install
cd /sources
rm -rf libcap-2.63

echo "# 8.25. Shadow-4.11.1"
tar -Jxf shadow-4.11.1.tar.xz
cd shadow-4.11.1
sed -i 's/groups$(EXEEXT) //' src/Makefile.in
find man -name Makefile.in -exec sed -i 's/groups\.1 / /'   {} \;
find man -name Makefile.in -exec sed -i 's/getspnam\.3 / /' {} \;
find man -name Makefile.in -exec sed -i 's/passwd\.5 / /'   {} \;
sed -e 's:#ENCRYPT_METHOD DES:ENCRYPT_METHOD SHA512:' \
    -e 's:/var/spool/mail:/var/mail:'                 \
    -e '/PATH=/{s@/sbin:@@;s@/bin:@@}'                \
    -i etc/login.defs
touch /usr/bin/passwd
./configure --sysconfdir=/etc \
            --with-group-name-max-length=32
make -j $PARALLEL_JOBS
make exec_prefix=/usr install
make -C man install-man
pwconv
grpconv
mkdir -p /etc/default
useradd -D --gid 999
sed -i 's/yes/no/' /etc/default/useradd
# passwd root
# Root password will be set at the end of the script to prevent a stop here
cd /sources
rm -rf shadow-4.11.1

echo "# 8.26. GCC-11.2.0"
tar -Jxf gcc-11.2.0.tar.xz
cd gcc-11.2.0
if [[ "$RPI_MODEL" == "64" ]] ; then
    sed -e '/mabi.lp64=/s/lib64/lib/' -i.orig gcc/config/aarch64/t-aarch64-linux
else
    patch -Np1 -i ../gcc-9.1.0-rpi$RPI_MODEL-cpu-default.patch
fi
sed -e '/static.*SIGSTKSZ/d' \
    -e 's/return kAltStackSize/return SIGSTKSZ * 4/' \
    -i libsanitizer/sanitizer_common/sanitizer_posix_libcdep.cpp
mkdir -v build
cd build
../configure --prefix=/usr            \
             LD=ld                    \
             --enable-languages=c,c++ \
             --disable-multilib       \
             --disable-bootstrap      \
             --with-system-zlib
make -j 1
make install
rm -rf /usr/lib/gcc/$(gcc -dumpmachine)/11.2.0/include-fixed/bits/
chown -v -R root:root /usr/lib/gcc/*linux-gnu*/11.2.0/include{,-fixed}
ln -svr /usr/bin/cpp /lib
ln -sfv ../../libexec/gcc/$(gcc -dumpmachine)/11.2.0/liblto_plugin.so /usr/lib/bfd-plugins/
mkdir -pv /usr/share/gdb/auto-load/usr/lib
mv -v /usr/lib/*gdb.py /usr/share/gdb/auto-load/usr/lib
cd /sources
rm -rf gcc-11.2.0

echo "# 8.27. Pkg-config-0.29.2"
tar -zxf pkg-config-0.29.2.tar.gz
cd pkg-config-0.29.2
./configure --prefix=/usr              \
            --with-internal-glib       \
            --disable-host-tool        \
            --docdir=/usr/share/doc/pkg-config-0.29.2
make -j $PARALLEL_JOBS
make install
cd /sources
rm -rf pkg-config-0.29.2

echo "# 8.28. Ncurses-6.3"
tar -zxf ncurses-6.3.tar.gz
cd ncurses-6.3
./configure --prefix=/usr           \
            --mandir=/usr/share/man \
            --with-shared           \
            --without-debug         \
            --without-normal        \
            --enable-pc-files       \
            --enable-widec          \
            --with-pkg-config-libdir=/usr/lib/pkgconfig
make -j $PARALLEL_JOBS
make DESTDIR=$PWD/dest install
install -vm755 dest/usr/lib/libncursesw.so.6.3 /usr/lib
rm -v  dest/usr/lib/{libncursesw.so.6.3,libncurses++w.a}
cp -av dest/* /
for lib in ncurses form panel menu ; do
    rm -vf                    /usr/lib/lib${lib}.so
    echo "INPUT(-l${lib}w)" > /usr/lib/lib${lib}.so
    ln -sfv ${lib}w.pc        /usr/lib/pkgconfig/${lib}.pc
done
rm -vf                     /usr/lib/libcursesw.so
echo "INPUT(-lncursesw)" > /usr/lib/libcursesw.so
ln -sfv libncurses.so      /usr/lib/libcurses.so
if [[ $INSTALL_OPTIONAL_DOCS = 1 ]] ; then
    mkdir -pv      /usr/share/doc/ncurses-6.3
    cp -v -R doc/* /usr/share/doc/ncurses-6.3
fi
cd /sources
rm -rf ncurses-6.3

echo "# 8.29. Sed-4.8"
tar -Jxf sed-4.8.tar.xz
cd sed-4.8
./configure --prefix=/usr
make -j $PARALLEL_JOBS
make install
if [[ $INSTALL_OPTIONAL_DOCS = 1 ]] ; then
    make html
    install -d -m755           /usr/share/doc/sed-4.8
    install -m644 doc/sed.html /usr/share/doc/sed-4.8
fi
cd /sources
rm -rf sed-4.8

echo "# 8.30. Psmisc-23.4"
tar -Jxf psmisc-23.4.tar.xz
cd psmisc-23.4
./configure --prefix=/usr
make -j $PARALLEL_JOBS
make install
cd /sources
rm -rf psmisc-23.4

echo "# 8.31. Gettext-0.21"
tar -Jxf gettext-0.21.tar.xz
cd gettext-0.21
./configure --prefix=/usr    \
            --disable-static \
            --docdir=/usr/share/doc/gettext-0.21
make -j $PARALLEL_JOBS
make install
chmod -v 0755 /usr/lib/preloadable_libintl.so
cd /sources
rm -rf gettext-0.21

echo "# 8.32. Bison-3.8.2"
tar -Jxf bison-3.8.2.tar.xz
cd bison-3.8.2
./configure --prefix=/usr --docdir=/usr/share/doc/bison-3.8.2
make -j $PARALLEL_JOBS
make install
cd /sources
rm -rf bison-3.8.2

echo "# 8.33. Grep-3.7"
tar -Jxf grep-3.7.tar.xz
cd grep-3.7
./configure --prefix=/usr
make -j $PARALLEL_JOBS
make install
cd /sources
rm -rf grep-3.7

echo "# 8.34. Bash-5.1.16"
tar -zxf bash-5.1.16.tar.gz
cd bash-5.1.16
./configure --prefix=/usr                      \
            --docdir=/usr/share/doc/bash-5.1.16 \
            --without-bash-malloc              \
            --with-installed-readline
make -j $PARALLEL_JOBS
make install
# exec /bin/bash --login +h
# Don't know of a good way to keep running the script after entering bash here.
cd /sources
rm -rf bash-5.1.16

echo "# 8.35. Libtool-2.4.6"
tar -Jxf libtool-2.4.6.tar.xz
cd libtool-2.4.6
./configure --prefix=/usr
make -j $PARALLEL_JOBS
make install
rm -fv /usr/lib/libltdl.a
cd /sources
rm -rf libtool-2.4.6

echo "# 8.36. GDBM-1.23"
tar -zxf gdbm-1.23.tar.gz
cd gdbm-1.23
./configure --prefix=/usr \
            --disable-static \
            --enable-libgdbm-compat
make -j $PARALLEL_JOBS
make install
cd /sources
rm -rf gdbm-1.23

echo "# 8.37. Gperf-3.1"
tar -zxf gperf-3.1.tar.gz
cd gperf-3.1
./configure --prefix=/usr --docdir=/usr/share/doc/gperf-3.1
make -j $PARALLEL_JOBS
make install
cd /sources
rm -rf gperf-3.1

echo "# 8.38. Expat-2.4.4"
tar -Jxf expat-2.4.4.tar.xz
cd expat-2.4.4
./configure --prefix=/usr    \
            --disable-static \
            --docdir=/usr/share/doc/expat-2.4.4
make -j $PARALLEL_JOBS
make install
if [[ $INSTALL_OPTIONAL_DOCS = 1 ]] ; then
    install -v -m644 doc/*.{html,css} /usr/share/doc/expat-2.4.4
fi
cd /sources
rm -rf expat-2.4.4

echo "# 8.39. Inetutils-2.2"
tar -Jxf inetutils-2.2.tar.xz
cd inetutils-2.2
./configure --prefix=/usr        \
            --bindir=/usr/bin    \
            --localstatedir=/var \
            --disable-logger     \
            --disable-whois      \
            --disable-rcp        \
            --disable-rexec      \
            --disable-rlogin     \
            --disable-rsh        \
            --disable-servers
make -j $PARALLEL_JOBS
make install
mv -v /usr/{,s}bin/ifconfig
cd /sources
rm -rf inetutils-2.2

echo "# 8.40. Less-590"
tar -zxf less-590.tar.gz
cd less-590
./configure --prefix=/usr --sysconfdir=/etc
make -j $PARALLEL_JOBS
make install
cd /sources
rm -rf less-590

echo "# 8.41. Perl-5.34.0"
tar -Jxf perl-5.34.0.tar.xz
cd perl-5.34.0
patch -Np1 -i ../perl-5.34.0-upstream_fixes-1.patch
export BUILD_ZLIB=False
export BUILD_BZIP2=0
sh Configure -des                                         \
             -Dprefix=/usr                                \
             -Dvendorprefix=/usr                          \
             -Dprivlib=/usr/lib/perl5/5.34/core_perl      \
             -Darchlib=/usr/lib/perl5/5.34/core_perl      \
             -Dsitelib=/usr/lib/perl5/5.34/site_perl      \
             -Dsitearch=/usr/lib/perl5/5.34/site_perl     \
             -Dvendorlib=/usr/lib/perl5/5.34/vendor_perl  \
             -Dvendorarch=/usr/lib/perl5/5.34/vendor_perl \
             -Dman1dir=/usr/share/man/man1                \
             -Dman3dir=/usr/share/man/man3                \
             -Dpager="/usr/bin/less -isR"                 \
             -Duseshrplib                                 \
             -Dusethreads
make -j $PARALLEL_JOBS
make install
unset BUILD_ZLIB BUILD_BZIP2
cd /sources
rm -rf perl-5.34.0

echo "# 8.42. XML::Parser-2.46"
tar -zxf XML-Parser-2.46.tar.gz
cd XML-Parser-2.46
perl Makefile.PL
make -j $PARALLEL_JOBS
make install
cd /sources
rm -rf XML-Parser-2.46

echo "# 8.43. Intltool-0.51.0"
tar -zxf intltool-0.51.0.tar.gz
cd intltool-0.51.0
sed -i 's:\\\${:\\\$\\{:' intltool-update.in
./configure --prefix=/usr
make -j $PARALLEL_JOBS
make install
if [[ $INSTALL_OPTIONAL_DOCS = 1 ]] ; then
    install -v -Dm644 doc/I18N-HOWTO /usr/share/doc/intltool-0.51.0/I18N-HOWTO
fi
cd /sources
rm -rf intltool-0.51.0

echo "# 8.44. Autoconf-2.71"
tar -Jxf autoconf-2.71.tar.xz
cd autoconf-2.71
./configure --prefix=/usr
make -j $PARALLEL_JOBS
make install
cd /sources
rm -rf autoconf-2.71

echo "# 8.45. Automake-1.16.5"
tar -Jxf automake-1.16.5.tar.xz
cd automake-1.16.5
./configure --prefix=/usr --docdir=/usr/share/doc/automake-1.16.5
make -j $PARALLEL_JOBS
make install
cd /sources
rm -rf automake-1.16.5

echo "# 8.46. OpenSSL-3.0.1"
tar -zxf openssl-3.0.1.tar.gz
cd openssl-3.0.1
./config --prefix=/usr         \
         --openssldir=/etc/ssl \
         --libdir=lib          \
         shared                \
         zlib-dynamic
make -j $PARALLEL_JOBS
sed -i '/INSTALL_LIBS/s/libcrypto.a libssl.a//' Makefile
make MANSUFFIX=ssl install
mv -v /usr/share/doc/openssl /usr/share/doc/openssl-3.0.1
if [[ $INSTALL_OPTIONAL_DOCS = 1 ]] ; then
    cp -vfr doc/* /usr/share/doc/openssl-3.0.1
fi
cd /sources
rm -rf openssl-3.0.1

echo "# 8.47. kmod-29"
tar -Jxf kmod-29.tar.xz
cd kmod-29
./configure --prefix=/usr          \
            --sysconfdir=/etc      \
            --with-openssl         \
            --with-xz              \
            --with-zstd            \
            --with-zlib
make -j $PARALLEL_JOBS
make install
for target in depmod insmod modinfo modprobe rmmod; do
  ln -sfv ../bin/kmod /usr/sbin/$target
done
ln -sfv kmod /usr/bin/lsmod
cd /sources
rm -rf kmod-29

echo "8.48. Libelf from Elfutils-0.186"
tar -jxf elfutils-0.186.tar.bz2
cd elfutils-0.186
./configure --prefix=/usr                \
            --disable-debuginfod         \
            --enable-libdebuginfod=dummy
make -j $PARALLEL_JOBS
make -C libelf install
install -vm644 config/libelf.pc /usr/lib/pkgconfig
rm /usr/lib/libelf.a
cd /sources
rm -rf elfutils-0.186

echo "# 8.49. libffi-3.4.2"
tar -zxf libffi-3.4.2.tar.gz
cd libffi-3.4.2
./configure --prefix=/usr          \
            --disable-static       \
            --with-gcc-arch=native \
            --disable-exec-static-tramp
make -j $PARALLEL_JOBS
make install 
cd /sources
rm -rf libffi-3.4.2

echo "# 8.50. Python-3.10.2"
tar -Jxf Python-3.10.2.tar.xz
cd Python-3.10.2
./configure --prefix=/usr        \
            --enable-shared      \
            --with-system-expat  \
            --with-system-ffi    \
            --with-ensurepip=yes \
            --enable-optimizations
make -j $PARALLEL_JOBS
make install 
if [[ $INSTALL_OPTIONAL_DOCS = 1 ]] ; then
    install -v -dm755 /usr/share/doc/python-3.10.2/html
    tar --strip-components=1 --no-same-owner --no-same-permissions -C /usr/share/doc/python-3.10.2/html -jxf ../python-3.10.2-docs-html.tar.bz2
fi
cd /sources
rm -rf Python-3.10.2

echo "# 8.51. Ninja-1.10.2"
tar -zxf ninja-1.10.2.tar.gz
cd ninja-1.10.2
sed -i '/int Guess/a \
  int   j = 0;\
  char* jobs = getenv( "NINJAJOBS" );\
  if ( jobs != NULL ) j = atoi( jobs );\
  if ( j > 0 ) return j;\
' src/ninja.cc
python3 configure.py --bootstrap
install -vm755 ninja /usr/bin/
install -vDm644 misc/bash-completion /usr/share/bash-completion/completions/ninja
install -vDm644 misc/zsh-completion /usr/share/zsh/site-functions/_ninja
cd /sources
rm -rf ninja-1.10.2

echo "# 8.52. Meson-0.61.1"
tar -zxf meson-0.61.1.tar.gz
cd meson-0.61.1
python3 setup.py build
python3 setup.py install --root=dest
cp -rv dest/* /
install -vDm644 data/shell-completions/bash/meson /usr/share/bash-completion/completions/meson
install -vDm644 data/shell-completions/zsh/_meson /usr/share/zsh/site-functions/_meson
cd /sources
rm -rf meson-0.61.1

echo "# 8.53. Coreutils-9.0"
tar -Jxf coreutils-9.0.tar.xz
cd coreutils-9.0
patch -Np1 -i ../coreutils-9.0-i18n-1.patch
patch -Np1 -i ../coreutils-9.0-chmod_fix-1.patch
autoreconf -fiv
FORCE_UNSAFE_CONFIGURE=1 ./configure \
            --prefix=/usr            \
            --enable-no-install-program=kill,uptime
make -j $PARALLEL_JOBS
make install
mv -v /usr/bin/chroot /usr/sbin
mv -v /usr/share/man/man1/chroot.1 /usr/share/man/man8/chroot.8
sed -i 's/"1"/"8"/' /usr/share/man/man8/chroot.8
cd /sources
rm -rf coreutils-9.0

echo "# 8.54. Check-0.15.2"
tar -zxf check-0.15.2.tar.gz
cd check-0.15.2
./configure --prefix=/usr --disable-static
make -j $PARALLEL_JOBS
make docdir=/usr/share/doc/check-0.15.2 install
cd /sources
rm -rf check-0.15.2

echo "# 8.55. Diffutils-3.8"
tar -Jxf diffutils-3.8.tar.xz
cd diffutils-3.8
./configure --prefix=/usr
make -j $PARALLEL_JOBS
make install
cd /sources
rm -rf diffutils-3.8

echo "# 8.56. Gawk-5.1.1"
tar -Jxf gawk-5.1.1.tar.xz
cd gawk-5.1.1
sed -i 's/extras//' Makefile.in
./configure --prefix=/usr
make -j $PARALLEL_JOBS
make install
if [[ $INSTALL_OPTIONAL_DOCS = 1 ]] ; then
    mkdir -pv /usr/share/doc/gawk-5.1.1
    cp    -v doc/{awkforai.txt,*.{eps,pdf,jpg}} /usr/share/doc/gawk-5.1.1
fi
cd /sources
rm -rf gawk-5.1.1

echo "# 8.57. Findutils-4.9.0"
tar -Jxf findutils-4.9.0.tar.xz
cd findutils-4.9.0
if [[ "$RPI_MODEL" == "64" ]] ; then
    ./configure --prefix=/usr --localstatedir=/var/lib/locate
else
    TIME_T_32_BIT_OK=yes ./configure --prefix=/usr --localstatedir=/var/lib/locate
fi
make -j $PARALLEL_JOBS
make install
cd /sources
rm -rf findutils-4.9.0

echo "# 8.58. Groff-1.22.4"
tar -zxf groff-1.22.4.tar.gz
cd groff-1.22.4
PAGE=$GROFF_PAPER_SIZE ./configure --prefix=/usr
make -j 1
make install
cd /sources
rm -rf groff-1.22.4

# 8.59. GRUB-2.04
# We don't use GRUB on ARM

echo "# 8.60. Gzip-1.11"
tar -Jxf gzip-1.11.tar.xz
cd gzip-1.11
./configure --prefix=/usr
make -j $PARALLEL_JOBS
make install
cd /sources
rm -rf gzip-1.11

echo "# 8.61. IPRoute2-5.16.0"
tar -Jxf iproute2-5.16.0.tar.xz
cd iproute2-5.16.0
sed -i /ARPD/d Makefile
rm -fv man/man8/arpd.8
make -j $PARALLEL_JOBS
make SBINDIR=/usr/sbin install
if [[ $INSTALL_OPTIONAL_DOCS = 1 ]] ; then
    mkdir -pv             /usr/share/doc/iproute2-5.16.0
    cp -v COPYING README* /usr/share/doc/iproute2-5.16.0
fi
cd /sources
rm -rf iproute2-5.16.0

echo "# 8.62. Kbd-2.4.0"
tar -Jxf kbd-2.4.0.tar.xz
cd kbd-2.4.0
patch -Np1 -i ../kbd-2.4.0-backspace-1.patch
sed -i 's/\(RESIZECONS_PROGS=\)yes/\1no/g' configure
sed -i 's/resizecons.8 //' docs/man/man8/Makefile.in
./configure --prefix=/usr --disable-vlock
make -j $PARALLEL_JOBS
make install
if [[ $INSTALL_OPTIONAL_DOCS = 1 ]] ; then
    mkdir -pv           /usr/share/doc/kbd-2.4.0
    cp -R -v docs/doc/* /usr/share/doc/kbd-2.4.0
fi
cd /sources
rm -rf kbd-2.4.0

echo "# 8.63. Libpipeline-1.5.5"
tar -zxf libpipeline-1.5.5.tar.gz
cd libpipeline-1.5.5
./configure --prefix=/usr
make -j $PARALLEL_JOBS
make install
cd /sources
rm -rf libpipeline-1.5.5

echo "# 8.64. Make-4.3"
tar -zxf make-4.3.tar.gz
cd make-4.3
./configure --prefix=/usr
make -j $PARALLEL_JOBS
make install
cd /sources
rm -rf make-4.3

echo "# 8.65. Patch-2.7.6"
tar -Jxf patch-2.7.6.tar.xz
cd patch-2.7.6
./configure --prefix=/usr
make -j $PARALLEL_JOBS
make install
cd /sources
rm -rf patch-2.7.6

echo "# 8.66. Tar-1.34"
tar -Jxf tar-1.34.tar.xz
cd tar-1.34
FORCE_UNSAFE_CONFIGURE=1  \
./configure --prefix=/usr
make -j $PARALLEL_JOBS
make install
if [[ $INSTALL_OPTIONAL_DOCS = 1 ]] ; then
    make -C doc install-html docdir=/usr/share/doc/tar-1.34
fi
cd /sources
rm -rf tar-1.34

echo "# 8.67. Texinfo-6.8"
tar -Jxf texinfo-6.8.tar.xz
cd texinfo-6.8
./configure --prefix=/usr
sed -e 's/__attribute_nonnull__/__nonnull/' -i gnulib/lib/malloc/dynarray-skeleton.c
make -j $PARALLEL_JOBS
make install
cd /sources
rm -rf texinfo-6.8

echo "# 8.68. Vim-8.2.4236"
tar -zxf vim-8.2.4236.tar.gz
cd vim-8.2.4236
echo '#define SYS_VIMRC_FILE "/etc/vimrc"' >> src/feature.h
./configure --prefix=/usr
make -j $PARALLEL_JOBS
make install
ln -sv vim /usr/bin/vi
for L in /usr/share/man/{,*/}man1/vim.1; do
    ln -sv vim.1 $(dirname $L)/vi.1
done
ln -sv ../vim/vim82/doc /usr/share/doc/vim-8.2.4236
cat > /etc/vimrc << "EOF"
" Begin /etc/vimrc

" Ensure defaults are set before customizing settings, not after
source $VIMRUNTIME/defaults.vim
let skip_defaults_vim=1 

set nocompatible
set backspace=2
set mouse=
syntax on
if (&term == "xterm") || (&term == "putty")
  set background=dark
endif

" End /etc/vimrc
EOF
cd /sources
rm -rf vim-8.2.4236

echo "# 8.69. Eudev-3.2.11"
tar -zxf eudev-3.2.11.tar.gz
cd eudev-3.2.11
./configure --prefix=/usr           \
            --bindir=/usr/sbin      \
            --sysconfdir=/etc       \
            --enable-manpages       \
            --disable-static
make -j $PARALLEL_JOBS
mkdir -pv /usr/lib/udev/rules.d
mkdir -pv /etc/udev/rules.d
make install
tar -Jxf ../udev-lfs-20171102.tar.xz
make -f udev-lfs-20171102/Makefile.lfs install
udevadm hwdb --update
cd /sources
rm -rf eudev-3.2.11

echo "# 8.70. Man-DB-2.10.0"
tar -Jxf man-db-2.10.0.tar.xz
cd man-db-2.10.0
./configure --prefix=/usr                        \
            --docdir=/usr/share/doc/man-db-2.10.0 \
            --sysconfdir=/etc                    \
            --disable-setuid                     \
            --enable-cache-owner=bin             \
            --with-browser=/usr/bin/lynx         \
            --with-vgrind=/usr/bin/vgrind        \
            --with-grap=/usr/bin/grap            \
            --with-systemdtmpfilesdir=           \
            --with-systemdsystemunitdir=
make -j $PARALLEL_JOBS
make install
cd /sources
rm -rf man-db-2.10.0

echo "# 8.71. Procps-ng-3.3.17"
tar -Jxf procps-ng-3.3.17.tar.xz
cd procps-3.3.17
./configure --prefix=/usr                            \
            --docdir=/usr/share/doc/procps-ng-3.3.17 \
            --disable-static                         \
            --disable-kill
make -j $PARALLEL_JOBS
make install
cd /sources
rm -rf procps-3.3.17

echo "# 8.72. Util-linux-2.37.3"
tar -Jxf util-linux-2.37.3.tar.xz
cd util-linux-2.37.3
./configure ADJTIME_PATH=/var/lib/hwclock/adjtime   \
            --bindir=/usr/bin    \
            --libdir=/usr/lib    \
            --sbindir=/usr/sbin  \
            --docdir=/usr/share/doc/util-linux-2.37.3 \
            --disable-chfn-chsh  \
            --disable-login      \
            --disable-nologin    \
            --disable-su         \
            --disable-setpriv    \
            --disable-runuser    \
            --disable-pylibmount \
            --disable-static     \
            --without-python     \
            --without-systemd    \
            --without-systemdsystemunitdir \
            runstatedir=/run
make -j $PARALLEL_JOBS
make install
cd /sources
rm -rf util-linux-2.37.3

echo "# 8.73. E2fsprogs-1.46.5"
tar -zxf e2fsprogs-1.46.5.tar.gz
cd e2fsprogs-1.46.5
mkdir -v build
cd build
../configure --prefix=/usr           \
             --sysconfdir=/etc       \
             --enable-elf-shlibs     \
             --disable-libblkid      \
             --disable-libuuid       \
             --disable-uuidd         \
             --disable-fsck
make -j $PARALLEL_JOBS
make install
rm -fv /usr/lib/{libcom_err,libe2p,libext2fs,libss}.a
if [[ $INSTALL_OPTIONAL_DOCS = 1 ]] ; then
    gunzip -v /usr/share/info/libext2fs.info.gz
    install-info --dir-file=/usr/share/info/dir /usr/share/info/libext2fs.info
    makeinfo -o      doc/com_err.info ../lib/et/com_err.texinfo
    install -v -m644 doc/com_err.info /usr/share/info
    install-info --dir-file=/usr/share/info/dir /usr/share/info/com_err.info
fi
cd /sources
rm -rf e2fsprogs-1.46.5

echo "# 8.74. Sysklogd-1.5.1"
tar -zxf sysklogd-1.5.1.tar.gz
cd sysklogd-1.5.1
sed -i '/Error loading kernel symbols/{n;n;d}' ksym_mod.c
sed -i 's/union wait/int/' syslogd.c
make -j $PARALLEL_JOBS
make BINDIR=/sbin install
cat > /etc/syslog.conf << "EOF"
# Begin /etc/syslog.conf

auth,authpriv.* -/var/log/auth.log
*.*;auth,authpriv.none -/var/log/sys.log
daemon.* -/var/log/daemon.log
kern.* -/var/log/kern.log
mail.* -/var/log/mail.log
user.* -/var/log/user.log
*.emerg *

# End /etc/syslog.conf
EOF
cd /sources
rm -rf sysklogd-1.5.1

echo "# 8.75. Sysvinit-3.01"
tar -Jxf sysvinit-3.01.tar.xz
cd sysvinit-3.01
patch -Np1 -i ../sysvinit-3.01-consolidated-1.patch
make -j $PARALLEL_JOBS
make install
cd /sources
rm -rf sysvinit-3.01

echo -e "--------------------------------------------------------------------"
echo -e "\nYou made it! Now there are just a few things left to take care of..."
printf 'Total script time: %s\n' $(timer $total_time)
echo -e "\nYou have not set a root password yet. Go ahead, I'll wait here.\n"
passwd root

echo -e "\nNow about the firmware..."
echo "You probably want to copy the supplied Broadcom libraries to /opt/vc?"
select yn in "Yes" "No"; do
    case $yn in
        Yes) tar -zxf master.tar.gz
             cp -rv /sources/firmware-master/hardfp/opt/vc /opt
             echo "/opt/vc/lib" >> /etc/ld.so.conf.d/broadcom.conf
             ldconfig
             if [[ "$RPI_MODEL" == "4" || "$RPI_MODEL" == "64" ]] ; then
                 tar -zxf v2022.01.25-138a1.tar.gz
                 cd rpi-eeprom-2022.01.25-138a1
                 cp -v rpi-eeprom-update-default /etc/default/rpi-eeprom-update
                 cp -v rpi-eeprom-config rpi-eeprom-update rpi-eeprom-digest /opt/vc/bin
                 mkdir -pv /lib/firmware/raspberrypi
                 cp -rv firmware /lib/firmware/raspberrypi/bootloader
                 cd /sources
                 rm -rf rpi-eeprom-2022.01.25-138a1
             fi
             break
             ;;
        No) break;;
    esac
done

echo -e "\nIf you're not going to compile your own kernel you probably want to copy the kernel modules from the firmware package to /lib/modules?"
select yn in "Yes" "No"; do
    case $yn in
        Yes) cp -rv /sources/firmware-master/modules /lib; break;;
        No) break;;
    esac
done

echo -e "\nLast question, if you want I can mount the boot partition and overwrite the kernel and bootloader with the one you downloaded?"
select yn in "Yes" "No"; do
    case $yn in
        Yes) mount /dev/mmcblk0p1 /boot && cp -rv /sources/firmware-master/boot / && umount /boot; break;;
        No) break;;
    esac
done

echo -e "\nThere, all done! Now continue reading from \"8.76. About Debugging Symbols\" to make your system bootable."
echo "And don't forget to check out https://intestinate.com/pilfs/beyond.html when you're done with your build!"
