#!/usr/bin/env bash
set -euo pipefail

: "${APK_OUTPUT_DIR:?set APK_OUTPUT_DIR}"
: "${BUILD_TOOLS_DIR:?set BUILD_TOOLS_DIR}"
: "${STRIP_TOOL:?set STRIP_TOOL}"
: "${KEYSTORE_PATH:?set KEYSTORE_PATH}"
: "${KEY_ALIAS:?set KEY_ALIAS}"
: "${KEYSTORE_PASSWORD:?set KEYSTORE_PASSWORD}"
: "${KEY_PASSWORD:?set KEY_PASSWORD}"

PAGE_KB="${PAGE_KB:-16}"
APP_NAME="${APP_NAME:-Pray}"

for tool in unzip zip; do
    command -v "$tool" >/dev/null || { echo "missing tool: $tool" >&2; exit 1; }
done

run() {
    echo "\$ $*"
    "$@"
}

mb() { awk "BEGIN{printf \"%.1f\", $1/1e6}"; }

TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/apk_fix_XXXXXX")"
trap 'rm -rf "$TMP_ROOT"' EXIT
echo "Working in: $TMP_ROOT"

found_any=0

for src_apk in "$APK_OUTPUT_DIR"/app-*-release.apk; do
    [[ -f "$src_apk" ]] || continue
    apk_name="$(basename "$src_apk")"
    abi="${apk_name#app-}"
    abi="${abi%-release.apk}"
    found_any=1

    echo
    echo "=== Processing $abi ($apk_name) ==="
    work_dir="$TMP_ROOT/$abi"
    root_dir="$work_dir/root"
    mkdir -p "$root_dir"

    patched_apk="$work_dir/patched.apk"
    cp "$src_apk" "$patched_apk"

    if [[ "$abi" == "universal" ]]; then
        lib_entries=(lib/arm64-v8a/libflutter.so lib/armeabi-v7a/libflutter.so lib/x86_64/libflutter.so)
    else
        lib_entries=("lib/$abi/libflutter.so")
    fi

    for lib_entry in "${lib_entries[@]}"; do
        if unzip -Z1 "$src_apk" | grep -xF "$lib_entry" >/dev/null; then
            run unzip -q -o "$src_apk" "$lib_entry" -d "$root_dir"
            so_path="$root_dir/$lib_entry"

            before_size=$(stat -c%s "$so_path")
            run "$STRIP_TOOL" --strip-all "$so_path"
            after_size=$(stat -c%s "$so_path")
            echo "Stripped $lib_entry: $(mb "$before_size")MB -> $(mb "$after_size")MB"

            (cd "$root_dir" && run zip -0 -X -q "$patched_apk" "$lib_entry")
        else
            echo "No $lib_entry in $apk_name, skipping strip."
        fi
    done

    rc=0
    zip -q -d "$patched_apk" \
        'META-INF/*.SF' 'META-INF/*.RSA' 'META-INF/*.DSA' 'META-INF/*.EC' \
        'META-INF/MANIFEST.MF' >/dev/null || rc=$?
    [[ $rc -eq 0 || $rc -eq 12 ]] || exit "$rc"

    aligned_apk="$work_dir/aligned.apk"
    run "$BUILD_TOOLS_DIR/zipalign" -f -P "$PAGE_KB" 4 "$patched_apk" "$aligned_apk"

    signed_apk="$APK_OUTPUT_DIR/${APP_NAME}-${abi}.apk"
    run "$BUILD_TOOLS_DIR/apksigner" sign \
        --ks "$KEYSTORE_PATH" \
        --ks-key-alias "$KEY_ALIAS" \
        --ks-pass env:KEYSTORE_PASSWORD \
        --key-pass env:KEY_PASSWORD \
        --v1-signing-enabled true \
        --v2-signing-enabled true \
        --v3-signing-enabled true \
        --out "$signed_apk" \
        "$aligned_apk"

    run "$BUILD_TOOLS_DIR/apksigner" verify "$signed_apk"
    run "$BUILD_TOOLS_DIR/zipalign" -c -P "$PAGE_KB" 4 "$signed_apk"

    echo
    echo "✓ Done: $signed_apk ($(mb "$(stat -c%s "$signed_apk")")MB)"
done

if [[ "$found_any" -eq 0 ]]; then
    echo "No app-*-release.apk files found in $APK_OUTPUT_DIR — did the build step run first?" >&2
    exit 1
fi

echo
echo "All done. Signed APKs are in $APK_OUTPUT_DIR named ${APP_NAME}-<abi>.apk."
