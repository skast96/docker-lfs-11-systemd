#!/usr/bin/sh

echo "Adding qemu tools"
docker run --privileged --rm tonistiigi/binfmt --install all

echo "Starting build of image"
docker buildx build --platform=linux/arm64 -t skast/lfs:11.0 . --load
