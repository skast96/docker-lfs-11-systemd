#!/usr/bin/sh

# Build base image of bullseye which is used for all other stages
cd base
docker buildx build -t skast/lfs-base:11.0 . --load
if [ $? -ne 0 ]; then
  echo "ERROR: Building base failed!"
  exit 1
fi
cd ..

# Build cross-toolchain image which is based of the base image
cd cross-compiler
docker buildx build -t skast/lfs-cross:11.0 . --load
cd ..
