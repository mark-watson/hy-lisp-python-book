#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

BUILD_DIR="build/typecheck"
PKG_OUT="${BUILD_DIR}/hy_kg_utils"

rm -rf "${BUILD_DIR}"
mkdir -p "${PKG_OUT}"

cp src/hy_kg_utils/__init__.py "${PKG_OUT}/__init__.py"
uv run hy2py src/hy_kg_utils/macros.hy > "${PKG_OUT}/macros.py"
uv run hy2py src/hy_kg_utils/core.hy > "${PKG_OUT}/core.py"

echo "=== Translated Python modules in ${PKG_OUT} ==="
ls -1 "${PKG_OUT}"

echo "=== Running mypy on translated core.py and __init__.py ==="
MYPYPATH="${BUILD_DIR}" uv run mypy --config-file pyproject.toml "${PKG_OUT}/core.py" "${PKG_OUT}/__init__.py"

rm -rf build .mypy_cache
