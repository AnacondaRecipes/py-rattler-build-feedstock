#!/bin/bash

set -euxo pipefail

export CARGO_PROFILE_RELEASE_STRIP=symbols
export CARGO_PROFILE_RELEASE_LTO=fat

# aws-lc-sys jitterentropy.c must compile at -O0; conda CFLAGS inject -O2.
# The cmake builder honors that; the default cc-rs path does not.
# s3/sigstore still pull aws-lc-sys even when the HTTP stack is native-tls.
export AWS_LC_SYS_CMAKE_BUILDER=1

# TLS backend matches rattler-build-feedstock#2:
#   osx     rustls — native-tls uses SecureTransport, which never does TLS 1.3
#           (conda/rattler#2749; conda-forge/py-rattler-feedstock#101).
#   linux   native-tls + conda openssl (OPENSSL_DIR).
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

cd rust
cargo-bundle-licenses --format yaml --output "${SRC_DIR}/THIRDPARTY.yml"
