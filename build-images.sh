#!/usr/bin/sh

echo "Adding qemu tools"
docker run --privileged --rm tonistiigi/binfmt --install all

PLATFORM=linux/arm/v7

echo "For which architecture do you want to build your LFS?"
select yn in "ARMv7" "AARCH64"; do
  case $yn in
  ARMv7) PLATFORM=linux/arm/v7 ;;
  AARCH64) PLATFORM=linux/arm64 ;;
  esac
done

# Build base image of bullseye which is used for all other stages
cd base
docker buildx build --platform=$PLATFORM -t skast/lfs-base:11.0 . --load
if [ $? -ne 0 ]; then
  echo "ERROR: Building base failed!"
  exit 1
fi
cd ..

# Build cross-toolchain image which is based of the base image
cd cross-compiler
docker buildx build --platform=$PLATFORM -t skast/lfs-cross:11.0 . --load
cd ..
