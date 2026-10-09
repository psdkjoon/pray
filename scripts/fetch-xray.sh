#!/usr/bin/env bash
set -euo pipefail

TARGET="${1:?usage: fetch-xray.sh android|linux-64|linux-arm64|windows-64|windows-arm64}"
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

# unzip is missing on some Windows (Git Bash) setups, so fall back to tools
# that ship with Windows.
extract_zip() {
    local zip="$1" dest="$2"
    if command -v unzip >/dev/null 2>&1; then
        unzip -q -o "$zip" -d "$dest"
    elif command -v 7z >/dev/null 2>&1; then
        7z x -y -bd "-o$dest" "$zip" >/dev/null
    elif command -v powershell.exe >/dev/null 2>&1; then
        powershell.exe -NoProfile -Command \
            "Expand-Archive -Force -LiteralPath '$(cygpath -w "$zip")' -DestinationPath '$(cygpath -w "$dest")'"
    else
        echo "no tool to extract zip files (install unzip)" >&2
        return 1
    fi
}

# Every platform's asset list is in pubspec.yaml, so the files that belong to
# other platforms must exist too (empty placeholders are fine).
ensure_placeholders() {
    mkdir -p assets/xray/linux assets/xray/windows
    [[ -e assets/xray/linux/xray ]] || : > assets/xray/linux/xray
    [[ -e assets/xray/windows/xray.exe ]] || : > assets/xray/windows/xray.exe
    [[ -e assets/xray/linux/geoip.dat ]] || : > assets/xray/linux/geoip.dat
    [[ -e assets/xray/linux/geosite.dat ]] || : > assets/xray/linux/geosite.dat
}

fetch() {
    local asset="$1"
    local dest="$WORK_DIR/${asset%.zip}"
    echo "Downloading $asset" >&2
    curl -fL --retry 3 "${PROGRESS[@]}" -o "$WORK_DIR/$asset" "$BASE_URL/$asset" >&2
    mkdir -p "$dest"
    extract_zip "$WORK_DIR/$asset" "$dest"
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

install_windows() {
    local asset="$1"
    local dir
    dir="$(fetch "$asset" | tail -n1)"
    ensure_placeholders
    install -m 755 "$dir/xray.exe" assets/xray/windows/xray.exe
    # The geo data is shared with the other platforms.
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
    windows-64)
        install_windows Xray-windows-64.zip
        ;;
    windows-arm64)
        install_windows Xray-windows-arm64-v8a.zip
        ;;
    *)
        echo "unknown target: $TARGET" >&2
        exit 1
        ;;
esac

ensure_placeholders
echo "xray ready for $TARGET"
