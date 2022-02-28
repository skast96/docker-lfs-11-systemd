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
RUN  wget --timestamping https://www.linuxfromscratch.org/lfs/downloads/11.0-systemd/wget-list &&  \
     wget --timestamping --continue --input-file=wget-list && \
     wget --timestamping https://www.linuxfromscratch.org/lfs/downloads/11.0-systemd/md5sums && \
     md5sum -c md5sums
