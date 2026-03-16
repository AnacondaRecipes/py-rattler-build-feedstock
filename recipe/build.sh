#!/bin/bash

set -euxo pipefail

export CARGO_PROFILE_RELEASE_STRIP=symbols
export CARGO_PROFILE_RELEASE_LTO=fat

export OPENSSL_DIR=$PREFIX

# Use native-tls on conda-forge
export MATURIN_PEP517_ARGS="--no-default-features --features=native-tls"


# Run the maturin build via pip which works for direct and
# cross-compiled builds.
$PYTHON -m pip install . -vv --no-deps --no-build-isolation

# Run from the rust crate dir so we don't hit the workspace that references
# rust-tests (not included in the PyPI sdist).
cd py-rattler-build/rust && cargo-bundle-licenses --format yaml --output ../../THIRDPARTY.yml
