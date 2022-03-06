#!/usr/bin/sh

echo "Adding qemu tools"
docker run --privileged --rm tonistiigi/binfmt --install all

if [ -f .env ]; then
  export $(grep -v '^#' .env | xargs -d '\n')
else
  echo "No env file available"
  exit 1
fi

# Build base image of bullseye which is used for all other stages
cd base || exit 1
docker buildx build --platform="$PLATFORM" -t skast/lfs-base:11.0 . # --load
if [ $? -ne 0 ]; then
  echo "ERROR: Building base failed!"
  exit 1
fi
cd ..

echo "Starting build of cross in a few seconds.!"
sleep 10

# Build cross-toolchain image which is based of the base image
cd cross-compiler || exit 1
docker buildx build --platform="$PLATFORM" -t skast/lfs-cross:11.0 . --load
cd ..
