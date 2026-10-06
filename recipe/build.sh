#!/bin/bash

set -euxo pipefail

export CARGO_PROFILE_RELEASE_STRIP=symbols
export CARGO_PROFILE_RELEASE_LTO=fat

# py-rattler-build 0.61+ transitively pulls in aws-lc-sys, which vendors
# jitterentropy. jitterentropy-base.c has a hard `#error` when compiled with
# optimizations, and the cc crate's per-file -O0 override is defeated by
# conda's trailing -O2 in CFLAGS. See aws/aws-lc-rs builder/cc_builder.rs
# (disable_jitter_entropy). On Unix the cmake builder honors -O0, so we use
# that instead of skipping (linux/osx CI green on 0.76.1). Windows still skips
# (C1083 under NMake) — see bld.bat.
# s3/sigstore still pull aws-lc-sys even when the HTTP stack is native-tls.
export AWS_LC_SYS_CMAKE_BUILDER=1

# TLS backend (rattler-build-feedstock#2):
#   osx     rustls — native-tls uses SecureTransport, which never does TLS 1.3
#           (conda/rattler#2749; conda-forge/py-rattler-feedstock#101).
#   linux   native-tls + conda openssl (OPENSSL_DIR), as before.
if [[ "${target_platform}" == osx-* ]]; then
  export MATURIN_PEP517_ARGS="--no-default-features --features=rustls"
else
  export OPENSSL_DIR="$PREFIX"
  export MATURIN_PEP517_ARGS="--no-default-features --features=native-tls"
fi

# GitHub source is the monorepo; the Python crate is in py-rattler-build/.
cd py-rattler-build

# Run the maturin build via pip which works for direct and
# cross-compiled builds.
$PYTHON -m pip install . -vv --no-deps --no-build-isolation

# Run from the rust crate dir so we don't hit the workspace that references
# rust-tests (not included in the PyPI sdist).
cd rust
cargo-bundle-licenses --format yaml --output THIRDPARTY.yml
cp THIRDPARTY.yml "${SRC_DIR}/THIRDPARTY.yml"
