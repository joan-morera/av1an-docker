# Av1an Docker (Debian)


This is a personal Docker image for [Av1an](https://github.com/master-of-zen/Av1an), built on **Debian Sid** to stay as upstream as possible.

I started building it because the package was broken on the Arch repos due to VapourSynth being too recent, and found the official image, which is huge in size and has no ARM64 support.

## Features & Improvements

*   **Size**: The image size is approximately **700MB** (vs 1.79GB official). *(--squash)ed to reduce image size.
*   **Arch**: **AMD64 & ARM64**.
*   **Feature Parity**: Should provide 1:1 core functionality with the official image, including all standard encoders and VapourSynth support. If not, feel free to open an issue.
*   **Plugins**: Included **L-SMASH-Works**, **FFMS2**, and **BestSource** VapourSynth plugins built from source, enabling high-accuracy chunking and input handling.

## Build Policy & Versions

The GitHub Actions will check for new versions each day on a schedule. If it detects any runtime or build dependency updates, it will be recreated.

*   Only VapourSynth is pinned to a specific version at this moment to R70, until Av1an integrates the VapourSynth API changes.
    
    *   <sub>**Rationale**: Av1an 0.5 relies on the legacy VapourSynth API (v3), which was removed in version R71. Although the official docker image builds over R69, R70 is the latest stable release fully compatible I've detected.</sub>

*   VMAF is built from source as there's no package available on the official repos (Only in multimedia), and to make the container compatible with ARM64.

## Usage

Same as the [official image](https://github.com/rust-av/Av1an/blob/master/site/src/docker.md). Entrypoint is av1an, just add your parameters and make sure you make the files accessible to the container.

```bash
# Basic encoding
docker run --rm -v "$(pwd):/videos" av1an-docker av1an -i input.mkv -e svt-av1 --vmaf -o output.mkv
```


**Note**: Mostly written with Gemini 3.5 Pro, but designed and revised by me.

