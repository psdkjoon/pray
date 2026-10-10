#!/usr/bin/env bash
set -euo pipefail

: "${APK_OUTPUT_DIR:?set APK_OUTPUT_DIR}"
APP_NAME="${APP_NAME:-Pray}"
BUILD_TOOLS_DIR="${BUILD_TOOLS_DIR:-}"
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

    if [[ -n "$BUILD_TOOLS_DIR" ]]; then
        sig="$("$BUILD_TOOLS_DIR/apksigner" verify --verbose --print-certs "$apk")"
        grep -E 'Verifies|Verified using|certificate SHA-256' <<<"$sig"
        for scheme in v2 v3; do
            if ! grep -qE "Verified using $scheme scheme .*: true" <<<"$sig"; then
                echo "ERROR: $name is not signed with the $scheme scheme" >&2
                fail=1
            fi
        done
        if ! unzip -Z1 "$apk" | grep -qE '^META-INF/.+\.(RSA|EC|DSA)$'; then
            echo "warning: $name has no v1 (JAR) signature"
        fi
        cert="$(grep -m1 'certificate SHA-256' <<<"$sig" | awk '{print $NF}')"
        if [[ -z "${first_cert:-}" ]]; then
            first_cert="$cert"
        elif [[ "$cert" != "$first_cert" ]]; then
            echo "ERROR: $name is signed with a different key than the other APKs" >&2
            fail=1
        fi
        badging="$("$BUILD_TOOLS_DIR/aapt2" dump badging "$apk" 2>/dev/null || true)"
        grep -E "^(package:|sdkVersion|minSdkVersion|targetSdkVersion|native-code)" <<<"$badging" || true
        code="$(grep -oP "versionCode='\K[0-9]+" <<<"$badging" | head -1)"
        echo "versionCode $code"
        if [[ -z "${first_code:-}" ]]; then
            first_code="$code"
        elif [[ "$code" != "$first_code" ]]; then
            echo "ERROR: $name has versionCode $code, others have $first_code" >&2
            fail=1
        fi
        if grep -qE "application-debuggable|testOnly" <<<"$badging"; then
            echo "ERROR: $name is a debuggable/test-only build" >&2
            fail=1
        fi
        if ! "$BUILD_TOOLS_DIR/zipalign" -c -P 16 4 "$apk"; then
            echo "ERROR: $name is not zip-aligned" >&2
            fail=1
        fi
    fi
    listing="$(unzip -Z1 "$apk")"
    grep -E '^lib/.+[^/]$' <<<"$listing" | sort || true

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
