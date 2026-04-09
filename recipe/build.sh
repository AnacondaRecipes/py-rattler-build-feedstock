#!/bin/bash

set -euxo pipefail

export CARGO_PROFILE_RELEASE_STRIP=symbols
export CARGO_PROFILE_RELEASE_LTO=fat

export OPENSSL_DIR=$PREFIX

# Use native-tls on conda-forge
export MATURIN_PEP517_ARGS="--no-default-features --features=native-tls"

# py-rattler-build 0.61+ transitively pulls in aws-lc-sys, which vendors
# jitterentropy. jitterentropy-base.c has a hard `#error` when compiled with
# optimizations, and the cc crate's per-file -O0 override is defeated by
# conda's trailing -O2 in CFLAGS. Skip jitterentropy compilation entirely.
# See aws/aws-lc-rs builder/cc_builder.rs (disable_jitter_entropy).
export AWS_LC_SYS_NO_JITTER_ENTROPY=1


# Run the maturin build via pip which works for direct and
# cross-compiled builds.
$PYTHON -m pip install . -vv --no-deps --no-build-isolation

# Run from the rust crate dir so we don't hit the workspace that references
# rust-tests (not included in the PyPI sdist).
cd py-rattler-build/rust && cargo-bundle-licenses --format yaml --output ../../THIRDPARTY.yml
