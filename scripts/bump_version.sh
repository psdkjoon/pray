#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 || ! "$1" =~ ^[0-9]+(\.[0-9]+){1,3}$ ]]; then
    echo "usage: scripts/bump_version.sh <major.minor.patch>" >&2
    exit 1
fi

version="$1"
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

printf '%s\n' "$version" > "$root/VERSION"
sed -i -E "s/^version: .*/version: $version/" "$root/pubspec.yaml"
sed -i -E "s/(static const String version = ')[^']*(')/\1$version\2/" "$root/lib/app_info.dart"

echo "VERSION      $(tr -d '[:space:]' < "$root/VERSION")"
echo "pubspec.yaml $(grep -oP '^version: \K\S+' "$root/pubspec.yaml")"
echo "app_info     $(grep -oP "static const String version = '\K[^']+" "$root/lib/app_info.dart")"
