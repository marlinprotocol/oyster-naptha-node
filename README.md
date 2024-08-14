# Naptha Node on Oyster

This repository packages a [Naptha Node](https://github.com/NapthaAI/node) along with related services in an enclave image.

## Prerequisites

- Nix

The enclave is built using nix for reproducibility. It does NOT use the standard `nitro-cli` based pipeline, and instead uses [monzo/aws-nitro-util](https://github.com/monzo/aws-nitro-util) in order to produce bit-for-bit reproducible enclaves.

The following nix `experimental-features` must be enabled:
- nix-command
- flakes

## Build

TODO: arm64 support, cross-platform build support

```bash
# On amd64, For amd64
# The request folder will contain the enclave image and pcrs
nix build -vL
```
