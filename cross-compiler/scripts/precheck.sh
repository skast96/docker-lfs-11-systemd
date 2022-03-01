#!/bin/bash

RPI_MODEL=4 # Which Raspberry Pi model are you building for - this selects the right GCC CPU patch.
# Put 64 to build for aarch64.
PARALLEL_JOBS=4 # Number of parallel make jobs, 1 for RPi1 and 4 for RPi2 and up recommended.

set -o nounset
set -o errexit

function prebuild_sanity_check {
  if [[ $(whoami) != "lfs" ]]; then
    echo "Not running as user lfs, you should be!"
    exit 1
  fi

  if ! [[ -v LFS ]]; then
    echo "You forgot to set your LFS environment variable!"
    exit 1
  fi

  if ! [[ -v LFS_TGT ]] || [[ $LFS_TGT != "armv6l-lfs-linux-gnueabihf" && $LFS_TGT != "armv7l-lfs-linux-gnueabihf" && $LFS_TGT != "aarch64-lfs-linux-gnu" ]]; then
    echo "Your LFS_TGT variable should be set to armv6l-lfs-linux-gnueabihf for RPi1, armv7l-lfs-linux-gnueabihf for RPi2 - 4 or aarch64-lfs-linux-gnu for aarch64"
    exit 1
  fi

  if ! [[ -d $LFS ]]; then
    echo "Your LFS directory doesn't exist!"
    exit 1
  fi

  if ! [[ -d $LFS/sources ]]; then
    echo "Can't find your sources directory!"
    exit 1
  fi

  if [[ $(stat -c %U $LFS/sources) != "lfs" ]]; then
    echo "The sources directory should be owned by user lfs!"
    exit 1
  fi

  if ! [[ -d $LFS/tools ]]; then
    echo "Can't find your tools directory!"
    exit 1
  fi

  if [[ $(stat -c %U $LFS/tools) != "lfs" ]]; then
    echo "The tools directory should be owned by user lfs!"
    exit 1
  fi

  if [[ "$RPI_MODEL" == "64" && $(uname -m) != "aarch64" ]]; then
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

  for tarball in $LIST_OF_TARBALLS; do
    if ! [[ -f $LFS/sources/$tarball ]]; then
      echo "Can't find $LFS/sources/$tarball!"
      exit 1
    fi
  done
}

prebuild_sanity_check
check_tarballs

if [[ $(free | grep 'Swap:' | tr -d ' ' | cut -d ':' -f2) == "000" ]]; then
  echo -e "\nYou are almost certainly going to want to add some swap space before building!"
  echo -e "(See https://intestinate.com/pilfs/beyond.html#addswap for instructions)"
  echo -e "Continue without swap?"
  select yn in "Yes" "No"; do
    case $yn in
    Yes) break ;;
    No) exit ;;
    esac
  done
fi

echo -e "\nThis is your last chance to quit before we start building... continue?"
echo "(Note that if anything goes wrong during the build, the script will abort mission)"
select yn in "Yes" "No"; do
  case $yn in
  Yes) break ;;
  No) exit ;;
  esac
done
