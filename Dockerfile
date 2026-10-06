#Download base image ubuntu 24.04
FROM ubuntu:24.04 AS base_os

# add vriviere's pre-built Ubuntu packages for cross-mint-essentials for x86_64 and aarch64
WORKDIR /tmp
FROM base_os AS add_prebuild_packages
RUN \
  apt -y update && \
  DEBIAN_FRONTEND=noninteractive apt -y install git clang \
  rsync curl build-essential python3 python-is-python3 upx-ucl \
  zip unzip autoconf automake libtool pkg-config

# ---- Direct installation vasm ----
WORKDIR /tmp
FROM add_prebuild_packages AS vasm
RUN \
  curl http://sun.hasenbraten.de/vasm/release/vasm.tar.gz --output vasm.tar.gz && \
  gunzip vasm.tar.gz && \
  tar -xf vasm.tar && \
  cd vasm && \
  make CPU=m68k SYNTAX=mot && \
  cp vasmm68k_mot /usr/local/bin && \
  ln -s /usr/local/bin/vasmm68k_mot /usr/local/bin/vasm && \
  cp vobjdump /usr/local/bin && \
  cd .. && \
  rm -fR vasm*

# ---- Direct installation vlink ----
WORKDIR /tmp
FROM vasm AS vlink
RUN \
  curl http://sun.hasenbraten.de/vlink/release/vlink.tar.gz --output vlink.tar.gz && \
  gunzip vlink.tar.gz && \
  tar -xf vlink.tar && \
  cd vlink && \
  make && \
  cp vlink /usr/local/bin && \
  cd .. && \
  rm -fR vlink*

# ---- mintelf tools ----
WORKDIR /tmp
FROM vlink AS mintelf
RUN \
  curl https://tho-otto.m68k.eu/download/mint/binutils-2.45-mintelf-20250812-bin-linux64.tar.xz --output binutils.tar.xz && \
  tar -xf binutils.tar.xz && \
  cp -r usr/* /usr/local/ && \
  rm -fR usr *.tar.xz
RUN \
  curl https://tho-otto.m68k.eu/download/mint/gcc-15.2.0-mintelf-20250810-bin-linux64.tar.xz --output gcc.tar.xz && \
  tar -xf gcc.tar.xz && \
  cp -r usr/* /usr/local/ && \
  rm -fR usr *.tar.xz
RUN \
  curl https://tho-otto.m68k.eu/download/mint/gdb-17.0-mintelf-20250812-bin-linux64.tar.xz --output gdb.tar.xz && \
  tar -xf gdb.tar.xz && \
  cp -r usr/* /usr/local/ && \
  rm -fR usr *.tar.xz

# ---- Libraries ----
WORKDIR /tmp
FROM mintelf AS libraries
RUN \
  curl https://tho-otto.m68k.eu/download/mint/mintlib-0.60.1-mintelf-20240718-dev.tar.xz --output mintlib.tar.xz && \
  tar -xf mintlib.tar.xz && \
  cp -r usr/* /usr/local/ && \
  rm -fR usr *.tar.xz
RUN \
  curl https://tho-otto.m68k.eu/download/mint/fdlibm-20240425-mintelf-dev.tar.xz --output fdlibm.tar.xz && \
  tar -xf fdlibm.tar.xz && \
  cp -r usr/* /usr/local/ && \
  rm -fR usr *.tar.xz
RUN \
  curl https://tho-otto.m68k.eu/download/mint/gemlib-0.44.0-mintelf-20240425-dev.tar.xz --output gemlib.tar.xz && \
  tar -xf gemlib.tar.xz && \
  cp -r usr/* /usr/local/ && \
  rm -fR usr *.tar.xz

# ---- Download helper lib libcmini ----
WORKDIR /tmp
FROM libraries AS libcmini
RUN \
  git clone https://github.com/freemint/libcmini.git && \
  cd libcmini && \
  make -e BUILD_CF=N -e COMPILE_ELF=Y -e PREFIX=/usr/local/m68k-atari-libcmini install && \
  cd .. && rm -fR libcmini

# ---- Build AGT tools ----
# d_m_l's upstream repo ships prebuilt Linux binaries. Just use them
FROM libcmini AS agt
WORKDIR /
RUN \
  git clone --depth 1 https://bitbucket.org/d_m_l/agtools.git && \
  chmod -R +x /agtools/bin/Linux

COPY ./agt/config.sh /agtools/config.sh

# Delete folders not needed at runtime and with dubious license files
RUN rm -fR /agtools/examples
RUN rm -fR /agtools/demos
RUN rm -fR /agtools/tutorials
RUN rm -fR /agtools/bin/Darwin
RUN rm -fR /agtools/bin/win
RUN rm -fR /agtools/tools

# ---- Configure entrypoint ----
WORKDIR /root
FROM agt AS entrypoint

COPY ./entrypoint.sh /

# Set environment variables.
ENV HOME=/root
ENV AGTROOT=/agtools

# stcmd mounts the project at /tmp with the host user's id, which git does not
# see as the owner of the files: trust repositories there (at /tmp, or below
# it when the working folder is a parent of the project), or each git command a
# build runs (version strings, submodules...) fails with "detected dubious
# ownership"
RUN git config --system --add safe.directory /tmp && \
  git config --system --add safe.directory '/tmp/*'

# HOME is /root, which the host user stcmd runs as cannot enter: let any user
# through, so the per-user settings git looks for there are skipped as missing
# instead of "Permission denied" warnings. Its contents stay unreadable.
RUN chmod 711 /root

# Define working directory.

RUN ["chmod", "+x", "/entrypoint.sh"]

ENTRYPOINT ["/entrypoint.sh"]
