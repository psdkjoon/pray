#!/usr/bin/env bash
set -euo pipefail

: "${BUNDLE_DIR:?set BUNDLE_DIR}"
: "${OUTPUT_DIR:?set OUTPUT_DIR}"

APPIMAGETOOL_VERSION="${APPIMAGETOOL_VERSION:-1.9.1}"
ARCH="${ARCH:-x86_64}"
if [[ "$ARCH" == "x86_64" ]]; then
    APPIMAGETOOL_SHA256="${APPIMAGETOOL_SHA256:-ed4ce84f0d9caff66f50bcca6ff6f35aae54ce8135408b3fa33abfc3cb384eb0}"
else
    APPIMAGETOOL_SHA256="${APPIMAGETOOL_SHA256:-}"
fi

APP_ID="ir.psdkjoon.pray"
APP_NAME="pray"
DESKTOP_FILE="linux/packaging/${APP_ID}.desktop"
ICON_FILE="linux/icon.png"

cd "$(dirname "${BASH_SOURCE[0]}")/.."

run() {
    echo "\$ $*"
    "$@"
}

[[ -d "$BUNDLE_DIR" ]]    || { echo "BUNDLE_DIR not found: $BUNDLE_DIR" >&2; exit 1; }
[[ -f "$DESKTOP_FILE" ]]  || { echo "Desktop file not found: $DESKTOP_FILE" >&2; exit 1; }
[[ -f "$ICON_FILE" ]]     || { echo "Icon not found: $ICON_FILE" >&2; exit 1; }

WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/appimage_build_XXXXXX")"
trap 'rm -rf "$WORK_DIR"' EXIT
APP_DIR="$WORK_DIR/AppDir"
echo "Working in: $WORK_DIR"

mkdir -p "$APP_DIR/usr/bin" "$OUTPUT_DIR"
run cp -r "$BUNDLE_DIR"/. "$APP_DIR/usr/bin/"

if [[ ! -x "$APP_DIR/usr/bin/$APP_NAME" ]]; then
    echo "Expected executable '$APP_NAME' not found in $BUNDLE_DIR" >&2
    exit 1
fi

run cp "$DESKTOP_FILE" "$APP_DIR/${APP_ID}.desktop"
run cp "$ICON_FILE" "$APP_DIR/${APP_ID}.png"
run ln -sf "${APP_ID}.png" "$APP_DIR/.DirIcon"

cat > "$APP_DIR/AppRun" <<'EOF_APPRUN'
#!/usr/bin/env bash
set -euo pipefail
HERE="$(dirname "$(readlink -f "${0}")")"
APP_ID="@APP_ID@"
APP_NAME="@APP_NAME@"

DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
APPS_DIR="$DATA_HOME/applications"
ICONS_DIR="$DATA_HOME/icons/hicolor/256x256/apps"
DESKTOP_PATH="$APPS_DIR/$APP_ID.desktop"
BIN_DIR="$HOME/.local/bin"
CLI_PATH="$BIN_DIR/$APP_NAME"   # `pray --tray` etc.
# Created by `uninstall`, so the menu entry is not silently recreated.
OPT_OUT="$CONFIG_HOME/$APP_NAME-appimage-no-integrate"

refresh_caches() {
    if command -v update-desktop-database >/dev/null 2>&1; then
        update-desktop-database "$APPS_DIR" >/dev/null 2>&1 || true
    fi
    if command -v gtk-update-icon-cache >/dev/null 2>&1; then
        gtk-update-icon-cache -f -t "$DATA_HOME/icons/hicolor" >/dev/null 2>&1 || true
    fi
}

# Exec= value for an AppImage path (quoted if it contains whitespace).
exec_line_for() {
    local target="$1"
    if [[ "$target" =~ [[:space:]] ]]; then
        target="${target//\\/\\\\}"
        target="${target//\"/\\\"}"
        printf 'Exec="%s" %%U' "$target"
    else
        printf 'Exec=%s %%U' "$target"
    fi
}

# Writes the .desktop entry + icon so launchers (rofi, dmenu-desktop, GNOME,
# KDE, ...) can find the app. $1 = AppImage that the entry should launch.
write_desktop_entry() {
    local target="$1" exec_line tmp line
    exec_line="$(exec_line_for "$target")"

    mkdir -p "$APPS_DIR" "$ICONS_DIR"
    cp -f "$HERE/$APP_ID.png" "$ICONS_DIR/$APP_ID.png"

    tmp="$(mktemp "$APPS_DIR/.$APP_ID.XXXXXX")"
    while IFS= read -r line || [[ -n "$line" ]]; do
        case "$line" in
            Exec=*)    printf '%s\n' "$exec_line" ;;
            Icon=*)    printf 'Icon=%s\n' "$APP_ID" ;;
            TryExec=*) ;;
            *)         printf '%s\n' "$line" ;;
        esac
    done < "$HERE/$APP_ID.desktop" > "$tmp"
    chmod 644 "$tmp"
    mv -f "$tmp" "$DESKTOP_PATH"
    refresh_caches
}

# Makes `$APP_NAME` available as a command (symlink to the AppImage).
# Never overwrites a regular file the user put there.
link_cli() {
    local target="$1"
    mkdir -p "$BIN_DIR"
    if [[ -e "$CLI_PATH" && ! -L "$CLI_PATH" ]]; then
        echo "Not creating $CLI_PATH: a non-symlink file already exists." >&2
        return 0
    fi
    ln -sfn "$target" "$CLI_PATH"
}

cli_is_current() {
    [[ -L "$CLI_PATH" && "$(readlink -f "$CLI_PATH" 2>/dev/null || true)" == "$1" ]]
}

# First launch (or after the AppImage was moved): register the app.
auto_integrate() {
    [[ -n "${APPIMAGE:-}" ]] || return 0
    [[ -z "${PRAY_NO_INTEGRATE:-}" ]] || return 0
    [[ ! -e "$OPT_OUT" ]] || return 0

    local target exec_line
    target="$(readlink -f "$APPIMAGE")"
    exec_line="$(exec_line_for "$target")"
    if [[ -f "$DESKTOP_PATH" && -f "$ICONS_DIR/$APP_ID.png" ]] \
        && grep -qxF -- "$exec_line" "$DESKTOP_PATH" \
        && { [[ -e "$CLI_PATH" && ! -L "$CLI_PATH" ]] || cli_is_current "$target"; }; then
        return 0
    fi
    write_desktop_entry "$target" || true
    link_cli "$target" || true
}

install_app() {
    local appimage_path installed
    appimage_path="$(readlink -f "${APPIMAGE:-$0}")"
    installed="$BIN_DIR/$APP_NAME.AppImage"

    mkdir -p "$BIN_DIR"
    if [[ "$appimage_path" != "$(readlink -f "$installed" 2>/dev/null || true)" ]]; then
        cp -f "$appimage_path" "$installed"
    fi
    chmod +x "$installed"

    rm -f "$OPT_OUT"
    write_desktop_entry "$installed"
    link_cli "$installed"

    echo "Installed $APP_NAME:"
    echo "  binary:  $installed"
    echo "  command: $CLI_PATH"
    echo "  desktop: $DESKTOP_PATH"
    echo "  icon:    $ICONS_DIR/$APP_ID.png"
    case ":$PATH:" in
        *":$BIN_DIR:"*) ;;
        *) echo "Add $BIN_DIR to your PATH to use the '$APP_NAME' command." ;;
    esac
}

uninstall_app() {
    rm -f "$BIN_DIR/$APP_NAME.AppImage" "$DESKTOP_PATH" "$ICONS_DIR/$APP_ID.png"
    [[ -L "$CLI_PATH" ]] && rm -f "$CLI_PATH"
    mkdir -p "$(dirname "$OPT_OUT")"
    : > "$OPT_OUT"
    refresh_caches
    echo "Uninstalled $APP_NAME (menu entry will not be recreated; run '... install' to undo)."
}

case "${1:-}" in
    --appimage-install|install)
        install_app
        exit 0
        ;;
    --appimage-uninstall|uninstall)
        uninstall_app
        exit 0
        ;;
esac

auto_integrate

exec "$HERE/usr/bin/$APP_NAME" "$@"
EOF_APPRUN
sed -i -e "s|@APP_ID@|${APP_ID}|" -e "s|@APP_NAME@|${APP_NAME}|" "$APP_DIR/AppRun"
chmod +x "$APP_DIR/AppRun"

APPIMAGETOOL="$WORK_DIR/appimagetool.AppImage"
run curl -fsSL --retry 3 -o "$APPIMAGETOOL" \
    "https://github.com/AppImage/appimagetool/releases/download/${APPIMAGETOOL_VERSION}/appimagetool-${ARCH}.AppImage"
if [[ -n "$APPIMAGETOOL_SHA256" ]]; then
    echo "${APPIMAGETOOL_SHA256}  ${APPIMAGETOOL}" | sha256sum -c -
fi
chmod +x "$APPIMAGETOOL"

OUTPUT_FILE="$OUTPUT_DIR/Pray-${ARCH}.AppImage"

export ARCH
run "$APPIMAGETOOL" --appimage-extract-and-run "$APP_DIR" "$OUTPUT_FILE"

echo
echo "✓ Done: $OUTPUT_FILE"
