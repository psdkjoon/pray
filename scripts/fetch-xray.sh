#!/usr/bin/env bash
set -euo pipefail

TARGET="${1:?usage: fetch-xray.sh android|linux-64|linux-arm64}"
XRAY_VERSION="${XRAY_VERSION:-latest}"

cd "$(dirname "${BASH_SOURCE[0]}")/.."

if [[ "$XRAY_VERSION" == "latest" ]]; then
    BASE_URL="https://github.com/XTLS/Xray-core/releases/latest/download"
else
    BASE_URL="https://github.com/XTLS/Xray-core/releases/download/${XRAY_VERSION}"
fi

WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/xray_fetch_XXXXXX")"
trap 'rm -rf "$WORK_DIR"' EXIT

if [[ -t 2 ]]; then
    PROGRESS=(--progress-bar)
else
    PROGRESS=(-sS)
fi

fetch() {
    local asset="$1"
    local dest="$WORK_DIR/${asset%.zip}"
    echo "Downloading $asset" >&2
    curl -fL --retry 3 "${PROGRESS[@]}" -o "$WORK_DIR/$asset" "$BASE_URL/$asset" >&2
    mkdir -p "$dest"
    unzip -q -o "$WORK_DIR/$asset" -d "$dest"
    echo "$dest"
}

install_android() {
    local abi="$1"
    local asset="$2"
    local dir
    dir="$(fetch "$asset" | tail -n1)"
    mkdir -p "android/app/src/main/jniLibs/$abi"
    install -m 755 "$dir/xray" "android/app/src/main/jniLibs/$abi/libxray.so"
}

install_android_assets() {
    local asset="$1"
    local dir
    dir="$(fetch "$asset" | tail -n1)"
    mkdir -p assets/xray/linux
    install -m 644 "$dir/geoip.dat" assets/xray/linux/geoip.dat
    install -m 644 "$dir/geosite.dat" assets/xray/linux/geosite.dat
    [[ -s assets/xray/linux/xray ]] || : > assets/xray/linux/xray
}

install_linux() {
    local asset="$1"
    local dir
    dir="$(fetch "$asset" | tail -n1)"
    mkdir -p assets/xray/linux
    install -m 755 "$dir/xray" assets/xray/linux/xray
    install -m 644 "$dir/geoip.dat" assets/xray/linux/geoip.dat
    install -m 644 "$dir/geosite.dat" assets/xray/linux/geosite.dat
}

case "$TARGET" in
    android)
        install_android arm64-v8a Xray-android-arm64-v8a.zip
        install_android armeabi-v7a Xray-linux-arm32-v7a.zip
        install_android x86_64 Xray-linux-64.zip
        install_android_assets Xray-linux-64.zip
        ;;
    linux-64)
        install_linux Xray-linux-64.zip
        ;;
    linux-arm64)
        install_linux Xray-linux-arm64-v8a.zip
        ;;
    *)
        echo "unknown target: $TARGET" >&2
        exit 1
        ;;
esac

echo "xray ready for $TARGET"
