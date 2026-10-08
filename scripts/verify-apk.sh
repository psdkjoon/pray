#!/usr/bin/env bash
# Sanity-check every signed APK: required native libs exist for the ABI(s) it
# claims, and each one is really built for that ABI. Fails the build otherwise.
set -euo pipefail

: "${APK_OUTPUT_DIR:?set APK_OUTPUT_DIR}"
APP_NAME="${APP_NAME:-Pray}"
REQUIRED_LIBS=(libflutter.so libapp.so libxray.so)

for tool in unzip readelf; do
    command -v "$tool" >/dev/null || { echo "missing tool: $tool" >&2; exit 1; }
done

machine_for() {
    case "$1" in
        arm64-v8a)   echo "AArch64" ;;
        armeabi-v7a) echo "ARM" ;;
        x86_64)      echo "Advanced Micro Devices X86-64" ;;
    esac
}

TMP="$(mktemp -d "${TMPDIR:-/tmp}/apk_verify_XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

fail=0
found=0
for apk in "$APK_OUTPUT_DIR/$APP_NAME"-*.apk; do
    [[ -f "$apk" ]] || continue
    found=1
    name="$(basename "$apk" .apk)"
    variant="${name#"$APP_NAME"-}"
    if [[ "$variant" == "universal" ]]; then
        abis=(arm64-v8a armeabi-v7a x86_64)
    else
        abis=("$variant")
    fi

    echo "=== $name ==="
    listing="$(unzip -Z1 "$apk")"
    grep -E '^lib/.+[^/]$' <<<"$listing" | sort || true

    # An ABI-split APK must not carry other ABIs.
    for present in $(grep -oP '^lib/\K[^/]+(?=/.)' <<<"$listing" | sort -u); do
        if [[ ! " ${abis[*]} " =~ " $present " ]]; then
            echo "ERROR: $name contains unexpected ABI dir lib/$present" >&2
            fail=1
        fi
    done

    for abi in "${abis[@]}"; do
        want="$(machine_for "$abi")"
        [[ -n "$want" ]] || { echo "ERROR: unknown ABI '$abi' in $name" >&2; fail=1; continue; }
        for lib in "${REQUIRED_LIBS[@]}"; do
            entry="lib/$abi/$lib"
            if ! grep -qxF "$entry" <<<"$listing"; then
                echo "ERROR: $name is missing $entry" >&2
                fail=1
                continue
            fi
            out="$TMP/$name/$abi"
            mkdir -p "$out"
            unzip -q -o "$apk" "$entry" -d "$out"
            got="$(readelf -h "$out/$entry" | awk -F: '/Machine:/{gsub(/^[ \t]+/,"",$2); print $2}')"
            if [[ "$got" != "$want" ]]; then
                echo "ERROR: $entry is '$got', expected '$want'" >&2
                fail=1
            else
                echo "ok  $entry ($got)"
            fi
        done
    done
done

[[ "$found" -eq 1 ]] || { echo "No $APP_NAME-*.apk in $APK_OUTPUT_DIR" >&2; exit 1; }
exit "$fail"
