@echo on
set "PYO3_PYTHON=%PYTHON%"

set "PYTHONUTF8=1"
set "PYTHONIOENCODING=utf-8"

REM path too long for pixi_config subpackage, https://github.com/prefix-dev/pixi/issues/3691
set CARGO_HOME=C:\.cargo
md %CARGO_HOME%
set CARGO_TARGET_DIR=C:\.ct

set CARGO_PROFILE_RELEASE_STRIP=symbols

:: Use CMake to build aws-lc-sys on win-64; on win-arm64 the cc builder avoids
:: CMake ASM/ClangCL issues in BuildTools-only environments.
if /I not "%VSCMD_ARG_TGT_ARCH%"=="arm64" (
  set AWS_LC_SYS_CMAKE_BUILDER=1
  set "CMAKE_GENERATOR=Ninja"
)
:: Jitter entropy module requires intrinsics headers not available in the
:: conda build env; safe to disable on Windows where BCryptGenRandom provides
:: OS-level entropy. 0.76.1 also hits MSVC C1083 ("Cannot open compiler
:: generated file: '': Invalid argument") under NMake on the 8.3 cargo path.
set AWS_LC_SYS_NO_JITTER_ENTROPY=1

:: ring on win-arm64 needs clang on PATH for assembly.
if exist "%BUILD_PREFIX%\Library\bin\clang.exe" (
  set "PATH=%BUILD_PREFIX%\Library\bin;%PATH%"
)

if /I "%VSCMD_ARG_TGT_ARCH%"=="arm64" (
  :: aws-lc-sys cc builder must compile ARM .S files with clang, not cl.exe.
  set "CC=%BUILD_PREFIX%\Library\bin\clang.exe"
  set "CXX=%BUILD_PREFIX%\Library\bin\clang.exe"
  set "CFLAGS=--target=aarch64-pc-windows-msvc"
  set "CXXFLAGS=--target=aarch64-pc-windows-msvc"
)

:: native-tls = Schannel (TLS 1.3). rustls is only needed on macOS (SecureTransport).
set "MATURIN_PEP517_ARGS=--no-default-features --features=native-tls"

:: GitHub source is the monorepo; the Python crate is in py-rattler-build/.
cd py-rattler-build
%PYTHON% -m pip install . -vv  --no-deps --no-build-isolation || exit 1

cd rust
cargo-bundle-licenses --format yaml --output THIRDPARTY.yml || exit 1
copy THIRDPARTY.yml %SRC_DIR%\THIRDPARTY.yml || exit 1
