FROM skast/lfs-base:11.0

# image info
LABEL description="Cross compiler toolchain of the automated LFS build"
LABEL version="11.0"
LABEL maintainer="stephan.kast96@gmail.com"

####################################
####################################
#########Download Sources###########
####################################
####################################

WORKDIR $LFS/sources

# Download wget list / Download all packages in wget / download all checksums / check all packages
#RUN wget --timestamping https://raw.githubusercontent.com/skast96/docker-lfs-11-systemd/main/cross-compiler/scripts/wget-list
## Run quiet because of log limits of buildx
#RUN wget --quiet --timestamping --continue --input-file=wget-list
#RUN wget --timestamping https://raw.githubusercontent.com/skast96/docker-lfs-11-systemd/main/cross-compiler/scripts/md5sum.chk
#RUN md5sum -c md5sums.chk

# Copy needed scripts
COPY scripts $LFS/scripts
# Start building
RUN tail -f /dev/null