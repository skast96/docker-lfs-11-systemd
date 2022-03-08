#!/bin/bash

# Run quiet because of log limits of buildx todo: Remove if possible
wget --quiet --timestamping --continue --input-file=wget-list
md5sum -c md5sum.chk
