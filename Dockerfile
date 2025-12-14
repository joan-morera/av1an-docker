### Av1an Dynamic Build Dockerfile with VapourSynth (Hybrid Debian/Source)

### Stage 1: Builder
### Install build tools, stock encoders, and dependencies
### Update system and install all build dependencies in one go
FROM debian:sid-slim AS builder

RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
    build-essential \
    cmake \
    git \
    pkg-config \
    nasm \
    autoconf \
    automake \
    libtool \
    curl \
    python3 \
    python3-pip \
    python3-dev \
    cython3 \
    ### VapourSynth Dependencies
    libzimg-dev \
    ### Stock Dependencies (Runtime & Build)
    ffmpeg \
    mkvtoolnix \
    libxxhash-dev \
    libvpx-dev \
    aom-tools \
    svt-av1 \
    rav1e \
    libavformat-dev \
    libavcodec-dev \
    libavutil-dev \
    libavfilter-dev \
    libswscale-dev \
    ### Additional build dependencies for VMAF and Av1an
    wget \
    ca-certificates \
    yasm \
    python3-setuptools \
    python3-wheel \
    ninja-build \
    meson \
    zlib1g-dev \
    libssl-dev \
    clang \
    && rm -rf /var/lib/apt/lists/*

### Install Rust
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}"

WORKDIR /build

### Build Arguments
ARG AV1AN_VERSION
ARG VAPOURSYNTH_VERSION=R70
ARG VMAF_VERSION=v3.0.0

### Build VapourSynth (Source - Debian pkg not reliable/found)
RUN echo "[BUILD] Building VapourSynth ${VAPOURSYNTH_VERSION}..." && \
    git clone -b ${VAPOURSYNTH_VERSION} --depth 1 https://github.com/vapoursynth/vapoursynth.git && \
    cd vapoursynth && \
    ./autogen.sh && \
    ./configure --prefix=/usr/local && \
    make -j$(nproc) && \
    make install && \
    cd .. && rm -rf vapoursynth

### Build VMAF (libvmaf)
RUN echo "[BUILD] Building VMAF ${VMAF_VERSION}..." && \
    git clone -b ${VMAF_VERSION} --depth 1 https://github.com/Netflix/vmaf.git && \
    cd vmaf/libvmaf && \
    meson setup build \
        --buildtype release \
        --default-library static \
        -Dbuilt_in_models=true \
        -Denable_tests=false \
        -Denable_docs=false \
        --prefix=/usr/local && \
    ninja -C build && \
    ninja -C build install && \
    cd ../.. && rm -rf vmaf

### Set environment for binding finding
ENV PKG_CONFIG_PATH="/usr/local/lib/pkgconfig"
ENV LD_LIBRARY_PATH="/usr/local/lib"

### Build FFMS2 (Source for VS Plugin)
RUN echo "[BUILD] Building FFMS2..." && \
    git clone https://github.com/FFMS/ffms2.git && \
    cd ffms2 && \
    ./autogen.sh && \
    ./configure --prefix=/usr/local --enable-shared --with-vapoursynth && \
    make -j$(nproc) && \
    make install && \
    cd .. && rm -rf ffms2

### Build L-SMASH (Library)
RUN echo "[BUILD] Building L-SMASH..." && \
    git clone https://github.com/l-smash/l-smash.git && \
    cd l-smash && \
    ./configure --prefix=/usr/local --enable-shared && \
    make -j$(nproc) && \
    make install && \
    cd .. && rm -rf l-smash

### Build L-SMASH-Works (VapourSynth Plugin)
RUN echo "[BUILD] Building L-SMASH-Works..." && \
    git clone https://github.com/HomeOfAviSynthPlusEvolution/L-SMASH-Works.git && \
    cd L-SMASH-Works/VapourSynth && \
    mkdir build && cd build && \
    meson setup .. --prefix=/usr/local --buildtype=release && \
    ninja && \
    ninja install && \
    cd ../../.. && rm -rf L-SMASH-Works

### Build BestSource (VapourSynth Plugin)
RUN echo "[BUILD] Building BestSource..." && \
    git clone --recursive https://github.com/vapoursynth/bestsource.git && \
    cd bestsource && \
    mkdir build && cd build && \
    meson setup .. --prefix=/usr/local --buildtype=release && \
    ninja && \
    ninja install && \
    cd ../.. && rm -rf bestsource

### Build Av1an (Dynamic, with VapourSynth)
### Explicitly set linker search path for /usr/local/lib to find VapourSynth
RUN echo "[BUILD] Building Av1an..." && \
    if [ -z "$AV1AN_VERSION" ] || [ "$AV1AN_VERSION" = "master" ]; then \
        git clone https://github.com/master-of-zen/Av1an.git; \
    else \
        if echo "$AV1AN_VERSION" | grep -q "^v"; then TAG="$AV1AN_VERSION"; else TAG="$AV1AN_VERSION"; fi; \
        git clone -b ${TAG} https://github.com/master-of-zen/Av1an.git || git clone https://github.com/master-of-zen/Av1an.git; \
    fi && \
    cd Av1an && \
    RUSTFLAGS="-L native=/usr/local/lib" cargo build --release --target-dir ./target && \
    cp ./target/release/av1an /usr/local/bin/av1an && \
    cd .. && rm -rf Av1an

### Strip binaries
RUN strip /usr/local/bin/av1an



### Stage 2: Runtime
FROM debian:sid-slim

### Install runtime dependencies
### Update system and install all runtime dependencies in one go
RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
    python3 \
    python3-pip \
    libpython3.13 \
    ffmpeg \
    mkvtoolnix \
    aom-tools \
    svt-av1 \
    rav1e \
    vpx-tools \
    x264 \
    x265 \
    ca-certificates && \
    useradd -u 1000 -s /bin/false -d /home/av1an av1an && \
    mkdir -p /home/av1an/data && \
    chown -R av1an:av1an /home/av1an && \
    rm -rf /var/lib/apt/lists/*

### Copy Artifacts
COPY --from=builder /usr/local /usr/local

### Env
ENV LD_LIBRARY_PATH="/usr/local/lib:/usr/lib:/usr/lib/x86_64-linux-gnu"
ENV PYTHONPATH="/usr/local/lib/python3.13/site-packages"

WORKDIR /home/av1an/data
VOLUME ["/home/av1an/data"]

USER av1an

ENTRYPOINT ["/usr/local/bin/av1an"]
CMD ["--help"]
