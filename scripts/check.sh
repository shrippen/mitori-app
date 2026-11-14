#!/usr/bin/env bash
# The local checks before a commit, the same as .github/workflows/checks.yml:
# structure limits, data (from the mitori-daten submodul), release notes, the app with its C++ tests,
# qmllint (reports only). Build directory: MITORI_BUILD, default ~/.cache/claude/mitori-build.
set -euo pipefail
cd "$(dirname "$0")/.."
BUILD="${MITORI_BUILD:-$HOME/.cache/claude/mitori-build}"
DATEN="${MITORI_DATA_DIR:-$PWD/third_party/mitori-daten}"

pipx run tools/structure-check.py
python3 "$DATEN/tools/daten.py"
scripts/release-notes.sh --check
python3 -m pytest -q tests
(cd "$DATEN" && python3 -m pytest -q tests && python3 tools/kommentare.py > /dev/null \
    && python3 tools/lexikon.py > /dev/null && git diff --exit-code -- daten/)
cmake -S app -B "$BUILD" -G Ninja -DCMAKE_BUILD_TYPE=Debug -DMITORI_BUILD_TESTS=ON > /dev/null
cmake --build "$BUILD"
QT_QPA_PLATFORM=offscreen ctest --test-dir "$BUILD" --output-on-failure
scripts/qmllint.sh || echo "qmllint: findings (reported, not blocking)"
