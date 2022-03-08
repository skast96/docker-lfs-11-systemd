#!/usr/bin/bash

bash build-image.sh || exit 1

docker run -it --rm -v "$(pwd)/stages:/lfs/stages" skast/lfs:11.0 bash
