#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CORE_DIR="$ROOT_DIR/core"
BUILD_DIR="$ROOT_DIR/.dart_tool/ohos_core_build"
GO_BIN="${GO_BIN:-go}"
OHOS_SDK_HOME="${OHOS_SDK_HOME:-/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony}"
CC="${CC:-$OHOS_SDK_HOME/native/llvm/bin/aarch64-unknown-linux-ohos-clang}"
OUTPUT="${OUTPUT:-$ROOT_DIR/ohos/entry/libs/arm64-v8a/libclash.so}"

GVISOR_DIR="$(cd "$CORE_DIR" && "$GO_BIN" list -m -f '{{.Dir}}' github.com/metacubex/gvisor)"
PATCHED_GVISOR_DIR="$BUILD_DIR/gvisor"
TEMP_MOD_FILE="$CORE_DIR/.ohos_core.mod"
TEMP_SUM_FILE="$CORE_DIR/.ohos_core.sum"

rm -rf "$PATCHED_GVISOR_DIR"
mkdir -p "$BUILD_DIR" "$(dirname "$OUTPUT")"
cp -R "$GVISOR_DIR" "$PATCHED_GVISOR_DIR"
chmod -R u+w "$PATCHED_GVISOR_DIR"
patch -d "$PATCHED_GVISOR_DIR" -p1 < "$CORE_DIR/patches/gvisor-ohos-fstat.patch"

cp "$CORE_DIR/go.mod" "$TEMP_MOD_FILE"
cp "$CORE_DIR/go.sum" "$TEMP_SUM_FILE"
trap 'rm -f "$TEMP_MOD_FILE" "$TEMP_SUM_FILE"' EXIT

cd "$CORE_DIR"
"$GO_BIN" mod edit \
  -modfile="$TEMP_MOD_FILE" \
  -replace="github.com/metacubex/gvisor=$PATCHED_GVISOR_DIR"

GOOS=linux \
GOARCH=arm64 \
CGO_ENABLED=1 \
CC="$CC" \
"$GO_BIN" build \
  -modfile="$TEMP_MOD_FILE" \
  -trimpath \
  -ldflags='-w -s -extldflags "-Wl,-z,max-page-size=16384"' \
  -tags=with_gvisor,ohos \
  -buildmode=c-shared \
  -o "$OUTPUT"
