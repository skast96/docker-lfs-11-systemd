FROM debian:bullseye

# image info
LABEL description="Base image of the automated LFS build"
LABEL version="11.0"
LABEL maintainer="stephan.kast96@gmail.com"

# LFS mount point
ENV LFS=/lfs

# Other LFS parameters
ENV LC_ALL=POSIX

ENV PATH=/tools/bin:/bin:/usr/bin:/sbin:/usr/sbin

# set 1 to run tests; running tests takes much more time
ENV LFS_TEST=0

# set 1 to install documentation; slightly increases final size
ENV LFS_DOCS=0

# set bash as default shell
WORKDIR /bin
RUN rm sh && ln -s bash sh

# install required packages
RUN apt-get update && apt-get install -y \
    build-essential                      \
    bison                                \
    file                                 \
    gawk                                 \
    texinfo                              \
    wget                                 \
    sudo                                 \
    genisoimage                          \
 && apt-get -q -y autoremove             \
 && rm -rf /var/lib/apt/lists/*

# create sources directory as writable and sticky
RUN mkdir -pv     $LFS/sources   \
 && chmod -v a+wt $LFS/sources   \
 && ln    -sv     $LFS/sources /

# create book directory as writable and sticky
RUN mkdir -pv     $LFS/stages   \
 && chmod -v a+wt $LFS/stages   \
 && ln    -sv     $LFS/stages /

# create image directory as writable and sticky
RUN mkdir -pv     $LFS/image   \
 && chmod -v a+wt $LFS/image   \
 && ln    -sv     $LFS/image /

# create tools directory and symlink
RUN mkdir -pv $LFS/tools   \
 && ln    -sv $LFS/tools /

# check environment
COPY ["scripts/", "/scripts"]
RUN /scripts/version-check.sh && rm -rf /scripts

# create lfs user with 'lfs' password
RUN groupadd lfs                                    \
 && useradd -s /bin/bash -g lfs -m -k /dev/null lfs \
 && echo "lfs:lfs" | chpasswd
RUN adduser lfs sudo

# give lfs user ownership of directories
RUN chown -v lfs $LFS/tools  \
 && chown -v lfs $LFS/sources

# avoid sudo password
RUN echo 'Defaults secure_path="/tools/bin:/bin:/usr/bin:/sbin:/usr/sbin"' >> /etc/sudoers
RUN echo "lfs ALL = NOPASSWD : ALL" >> /etc/sudoers
RUN echo 'Defaults env_keep += "LFS LC_ALL LFS_TGT PATH MAKEFLAGS FETCH_TOOLCHAIN_MODE LFS_TEST LFS_DOCS JOB_COUNT LOOP LOOP_DIR IMAGE_SIZE INITRD_TREE IMAGE_RAM IMAGE_BZ2 IMAGE_ISO IMAGE_HDD"' >> /etc/sudoers

# login as lfs user
USER lfs
COPY [ ".bash_profile", ".bashrc", "/home/lfs/" ]
RUN source ~/.bash_profile

# change path to home folder as default
WORKDIR /home/lfs