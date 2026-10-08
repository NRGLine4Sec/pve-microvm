#!/bin/bash
# Require built-in EROFS and decompression in the normalised configuration.
set -euo pipefail
config=${1:?Usage: check-erofs.sh CONFIG}
for option in CONFIG_EROFS_FS CONFIG_EROFS_FS_ZIP CONFIG_LZ4_DECOMPRESS CONFIG_EROFS_FS_ZIP_DEFLATE CONFIG_EROFS_FS_ZIP_ZSTD; do
    grep -qxF "$option=y" "$config" || { echo "ERROR: required $option=y missing" >&2; exit 1; }
done
echo 'EROFS and LZ4/DEFLATE/ZSTD support built-in'
