##### ----- ----- ----- ----- ----- ----- ----- ----- ----- ----- ----- #####
##### Thank you for using this Dockerfile template!                     #####
##### This is an outline for the flow of building a docker image.       #####
##### The docker image is built to the 'app' stage on dockerhub/quay.   #####
##### ----- ----- ----- ----- ----- ----- ----- ----- ----- ----- ----- #####

##### ----- ----- ----- ----- ----- ----- ----- ----- ----- ----- ----- #####
##### Sometimes tools required to build a tool are not needed to run    #####
##### it. This means that images are larger than they need to be. A way #####
##### to reduce the size of an image, is to have a stage prior to 'app' #####
##### where these temporarily-required tools are installed. Then, only  #####
##### relevant executables and files are copied in to the 'app' stage.  #####
##### ----- ----- ----- ----- ----- ----- ----- ----- ----- ----- ----- #####

##### ----- ----- ----- ----- ----- ----- ----- ----- ----- ----- ----- #####
##### Step 1. Set up the builder stage as the first stage.              #####
##### ----- ----- ----- ----- ----- ----- ----- ----- ----- ----- ----- #####

# Define parent image
FROM ubuntu:jammy as builder

#Version variable only accessible in build
ARG DORADO_VER="0.5.1"
ARG CMAKE_VER="3.28.1"

# USER root
# 'RUN' executes code during the build
# Install dependencies via apt-get or yum if using a centos or fedora base
# Compile libraries and script -> cmake
# RAther than running all together, write 

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    git \
    ca-certificates \
    build-essential \
    libhdf5-dev \
    libssl-dev \
    libzstd-dev \
    libaec-dev \
    autoconf \
    automake \
    wget \
    cmake protobuf-compiler \
    cmake \
    nano \
    gzip && \
    apt-get autoclean && rm -rf /var/lib/apt/lists/* 

# RUN wget https://developer.download.nvidia.com/compute/cuda/repos/debian12/x86_64/cuda-keyring_1.1-1_all.deb && dpkg -i cuda-keyring_1.1-1_all.deb && rm cuda-keyring_1.1-1_all.deb

# RUN apt-get update && apt-get install -y \
#     cuda-toolkit-12-3 && \
#     apt-get autoclean && rm -rf /var/lib/apt/lists/*

RUN wget https://cdn.oxfordnanoportal.com/software/analysis/dorado-0.5.1-linux-x64.tar.gz && \
    tar -xvf dorado-0.5.1-linux-x64.tar.gz && mv dorado-0.5.1-linux-x64 dorado-0.5.1

# RUN git clone https://github.com/nanoporetech/dorado.git dorado && \
#     cd dorado && \
#     git submodule update --init --recursive 
    
# RUN cd dorado && \
#     cmake -S . -B cmake-build && \
#     cmake --build cmake-build --config Release -j && \
#     ctest --test-dir cmake-build

# Install and/or setup more things. Make /data for use as a working dir
# For readability, limit one install per 'RUN' statement.


##### ----- ----- ----- ----- ----- ----- ----- ----- ----- ----- ----- #####
##### Step 2. Set up the base image in the 'app' stage.                 #####
##### ----- ----- ----- ----- ----- ----- ----- ----- ----- ----- ----- #####

# 'FROM' defines where the Dockerfile is starting to build from. This command has to come first in the file
# The 'as' keyword lets you name the folowing stage. The production image uses everything to the 'app' stage.

FROM ubuntu:jammy as app

# List all software versions are ARGs near the top of the dockerfile
# 'ARG' sets environment variables during the build stage
# ARG variables are ONLY available during image build, they do not persist in the final image
ARG DORADO_VER="0.5.1"

# Metadata
LABEL base.image="Ubuntu Focal 20.04"
LABEL dockerfile.version="1"
LABEL software="Dorado"
LABEL software.version="${DORADO_VER}"
LABEL description="High-performance basecaller for Oxford Nanopore reads"
LABEL website="https://github.com/nanoporetech/dorado"
LABEL license="Public License Version 1.0"
LABEL license.url="https://github.com/nanoporetech/dorado/blob/master/LICENCE"
LABEL maintainer="Eva Gunawan"
LABEL maintainer.email="eva.gunawan@slh.wisc.edu"

# copy in files and executables into app stage
COPY --from=builder dorado-${DORADO_VER} .

# example copy in blast executable
COPY --from=builder dorado-${DORADO_VER}/ /usr/local/bin

# 'RUN' executes code during the build
# Install dependencies via apt-get or yum if using a centos or fedora base
# Please ensure ALL dependencies for running the tool make it into this stage
RUN git clone https://github.com/nanoporetech/dorado.git dorado \
    cd dorado \
    cmake -S . -B cmake-build \
    cmake --build cmake-build --config Release -j && \
    ctest --test-dir cmake-build

# Install and/or setup more things. Make /data for use as a working dir
# For readability, limit one install per 'RUN' statement.

# 'ENV' instructions set environment variables that persist from the build into the resulting image
# Use for e.g. $PATH and locale settings for compatibility with Singularity
ENV PATH="/software-${SOFTWARENAME_VER}/bin:$PATH" \
 LC_ALL=C

# 'CMD' instructions set a default command when the container is run. This is typically 'tool --help.'
CMD [ "dorado", "--help" ]

# 'WORKDIR' sets working directory
WORKDIR /data

##### ----- ----- ----- ----- ----- ----- ----- ----- ----- ----- ----- #####
##### Step 3. Set up the testing stage.                                 #####
##### The docker image is built to the 'test' stage before merging, but #####
##### the test stage (or any stage after 'app') will be lost.           #####
##### ----- ----- ----- ----- ----- ----- ----- ----- ----- ----- ----- #####

# A second FROM insruction creates a new stage
# The test stage must be downstream from 'app'
FROM app as test

# set working directory so that all test inputs & outputs are kept in /test
WORKDIR /test

# print help and version info; check dependencies (not all software has these options available)
# Mostly this ensures the tool of choice is in path and is executable
RUN softwarename --help && \
 softwarename --check && \
 softwarename --version

# Demonstrate that the program is successfully installed - which is highly dependant on what the tool is.

# Run the program's internal tests if available, for example with SPAdes:
RUN spades.py --test

# Option 1: write your own tests in a bash script in the same directory as your Dockerfile and copy them:
COPY my_tests.sh .
RUN bash my_tests.sh

# Option 2: write below common usage cases, for example with tb-profiler:
RUN wget ftp://ftp.sra.ebi.ac.uk/vol1/fastq/ERR166/009/ERR1664619/ERR1664619_1.fastq.gz && \
    wget ftp://ftp.sra.ebi.ac.uk/vol1/fastq/ERR166/009/ERR1664619/ERR1664619_2.fastq.gz && \
    tb-profiler profile -1 ERR1664619_1.fastq.gz -2 ERR1664619_2.fastq.gz -t 4 -p ERR1664619 --txt