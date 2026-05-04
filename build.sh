#!/bin/bash
#
# build.sh — Build af_alg_block.so from source (af_alg_block.c)
#
# The prebuilt af_alg_block.so in the repository is produced by this script.
# Run this to rebuild after any source changes or to verify the binary.
#
# Prerequisites: gcc (or cc), make, libc6-dev (glibc headers)

set -euo pipefail

CC="${CC:-cc}"
CFLAGS="${CFLAGS:--Wall -Wextra -O2 -fPIC}"
SRC="af_alg_block.c"
OUT="af_alg_block.so"

if [ ! -f "$SRC" ]; then
    echo "ERROR: Source file '$SRC' not found in current directory." >&2
    echo "Run this script from the repository root (same dir as $SRC)." >&2
    exit 1
fi

echo "Building $OUT from $SRC ..."
$CC $CFLAGS -shared -o "$OUT" "$SRC" -ldl

echo "OK: $OUT built successfully."
file "$OUT"
