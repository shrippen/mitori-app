#!/usr/bin/env bash
# Build the Mitori APK: Qt via aqtinstall, KF6 (Kirigami) from source, Android NDK, Gradle.
# Usage: ./scripts/build-android.sh [debug|release]   → dist/android/mitori-<mode>.apk
# Release signing: MITORI_KEYSTORE_PATH, MITORI_KEYSTORE_PASSWORD, MITORI_KEY_ALIAS, MITORI_KEY_PASSWORD.
# MITORI_SHINKI=OFF leaves the Shinki style out.
# Needs python3 with PyYAML (third_party/mitori-daten/tools/daten.py runs in the build).
set -euo pipefail
MODE="${1:-debug}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_DIR="$REPO_DIR/app"
BUILD_DIR="$APP_DIR/build-android"
SDK_ROOT="${ANDROID_SDK_ROOT:-$HOME/android-sdk}"
NDK_DIR="$SDK_ROOT/ndk"
QT_VER="6.11.3"
QT_ANDROID="$HOME/Qt/$QT_VER/android_arm64_v8a"
QT_HOST="$HOME/Qt/$QT_VER/gcc_64"
# Not in the base install: Kirigami needs ShaderTools, the player Multimedia, the glossary's
# pronunciation Speech (TextToSpeech).
QT_MODULES="qtshadertools qtmultimedia qtspeech"
SHINKI="${MITORI_SHINKI:-ON}"
RED='\033[0;31m'; GREEN='\033[0;32m'; NC='\033[0m'
info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }
# Build output is trimmed to its last lines; MITORI_VERBOSE=1 (CI) shows all of it.
show() { if [ -n "${MITORI_VERBOSE:-}" ]; then cat; else tail -"$1"; fi; }

python3 -c 'import yaml' 2>/dev/null || error "python3 without PyYAML (tools/daten.py needs it)"

# ── 1. NDK ──
NDK_PATH=$(ls -d "$NDK_DIR"/27.2.* 2>/dev/null | head -1)
if [ ! -d "$NDK_PATH" ]; then
    info "Installing Android NDK r27c (the one Qt $QT_VER is built with)..."
    mkdir -p "$SDK_ROOT/cmdline-tools"
    if [ ! -f "$SDK_ROOT/cmdline-tools/latest/bin/sdkmanager" ]; then
        TMP=$(mktemp)
        curl -sL "https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip" -o "$TMP"
        unzip -qo "$TMP" -d "$SDK_ROOT/cmdline-tools/"
        mv "$SDK_ROOT/cmdline-tools/cmdline-tools" "$SDK_ROOT/cmdline-tools/latest" 2>/dev/null || true
        rm -f "$TMP"
    fi
    yes | "$SDK_ROOT/cmdline-tools/latest/bin/sdkmanager" --sdk_root="$SDK_ROOT" "ndk;27.2.12479018" "platforms;android-36" "build-tools;36.0.0" 2>&1 | tail -3
fi
NDK_PATH=$(ls -d "$NDK_DIR"/27.2.* 2>/dev/null | head -1)
[ -d "$NDK_PATH" ] || error "NDK not found"
info "NDK: $NDK_PATH"

# ── 2. Qt host + Android ──
[ -d "$QT_ANDROID/lib/cmake/Qt6TextToSpeech" ] && [ -d "$QT_HOST/lib/cmake/Qt6Multimedia" ] || {
    info "Installing aqtinstall..."
    pip install --user --break-system-packages aqtinstall 2>/dev/null || true
    export PATH="$HOME/.local/bin:$PATH"
    info "Downloading Qt $QT_VER for Android..."
    aqt install-qt all_os android "$QT_VER" android_arm64_v8a -m $QT_MODULES -O "$HOME/Qt" 2>&1 | tail -3
    info "Downloading Qt $QT_VER host tools..."
    aqt install-qt linux desktop "$QT_VER" linux_gcc_64 -m $QT_MODULES -O "$HOME/Qt" 2>&1 | tail -3
}
[ -d "$QT_ANDROID" ] && [ -d "$QT_HOST" ] || error "Qt not found"
info "Qt: host=$QT_HOST android=$QT_ANDROID"

# ── 3. KF6 (Kirigami) for Android; skips itself when already built ──
KF6_ANDROID="$HOME/kf6-android"
ANDROID_SDK_ROOT="$SDK_ROOT" "$SCRIPT_DIR/build-kf6-android.sh" "$KF6_ANDROID"
info "KF6: $KF6_ANDROID"

# ── 4. Build ──
info "Building Mitori ($MODE)..."
rm -rf "$BUILD_DIR"
ANDROID_SDK_ROOT="$SDK_ROOT" \
cmake -S "$APP_DIR" -B "$BUILD_DIR" \
    -DCMAKE_TOOLCHAIN_FILE="$NDK_PATH/build/cmake/android.toolchain.cmake" \
    -DCMAKE_BUILD_TYPE="$MODE" \
    -DMITORI_SHINKI="$SHINKI" \
    -DANDROID_ABI=arm64-v8a \
    -DANDROID_PLATFORM=android-28 \
    -DCMAKE_PREFIX_PATH="$QT_ANDROID;$KF6_ANDROID" \
    -DCMAKE_FIND_ROOT_PATH_MODE_PACKAGE=BOTH \
    -DQT_HOST_PATH="$QT_HOST" \
    -DANDROID_SDK_ROOT="$SDK_ROOT" \
    -DECM_DIR="$KF6_ANDROID/share/ECM/cmake" \
    -DQT_QML_IMPORT_PATH="$KF6_ANDROID/lib/qml" \
    -DMITORI_ANDROID_OPENSSL="$KF6_ANDROID/openssl" \
    2>&1 | show 5
cmake --build "$BUILD_DIR" -j"$(nproc)" 2>&1 | show 10

# ── 5. Signing, Gradle ──
GRADLE_TASK="assembleDebug"
[ "$MODE" = "release" ] && GRADLE_TASK="assembleRelease"
if [ "$MODE" = "release" ] && [ -n "${MITORI_KEYSTORE_PATH:-}" ]; then
    info "Release signing from MITORI_KEYSTORE_* ..."
    {
        echo "RELEASE_STORE_FILE=$MITORI_KEYSTORE_PATH"
        echo "RELEASE_STORE_PASSWORD=${MITORI_KEYSTORE_PASSWORD:?MITORI_KEYSTORE_PASSWORD not set}"
        echo "RELEASE_KEY_ALIAS=${MITORI_KEY_ALIAS:?MITORI_KEY_ALIAS not set}"
        echo "RELEASE_KEY_PASSWORD=${MITORI_KEY_PASSWORD:?MITORI_KEY_PASSWORD not set}"
    } >> "$BUILD_DIR/android-build/gradle.properties"
elif [ "$MODE" = "release" ]; then
    info "No MITORI_KEYSTORE_PATH: the release APK is unsigned."
fi
(cd "$BUILD_DIR/android-build" && ./gradlew "$GRADLE_TASK" 2>&1 | show 10)

# ── 6. Copy APK ──
APK=$(find "$BUILD_DIR/android-build/build/outputs/apk/$MODE" -name "*.apk" 2>/dev/null | head -1)
[ -n "$APK" ] || error "APK not found in build output"
python3 "$REPO_DIR/tests/check_apk_tls.py" "$APK" || error "the APK cannot speak HTTPS"
mkdir -p "$REPO_DIR/dist/android"
OUT="$REPO_DIR/dist/android/mitori-$MODE.apk"
cp "$APK" "$OUT"
info "APK ready: $OUT (adb install -r $OUT)"
