# Pray

A Catppuccin-themed Xray client for Android and Linux, written in Flutter with no third-party Dart packages.

## Features

- VLESS, VMess, Trojan and Shadowsocks links, subscriptions and free public config lists
- Proxy mode and TUN mode (Linux asks for administrator permission, Android always uses the VPN service)
- Routing presets, custom rules, per-app VPN on Android, Iran bypass
- Ad blocking with built-in levels and downloadable filter lists
- Cloudflare WARP, standalone, after your server, or for chosen sites
- Share servers as a link, a QR code or an encrypted `.pray` file
- Quick settings tile on Android, tray icon on Linux

## Build

```
./scripts/fetch-xray.sh linux-64      # or linux-arm64, android
flutter pub get
flutter build linux --release
flutter build apk --release --split-per-abi
```

For a signed Android release create `android/key.properties` with `storeFile`, `storePassword`, `keyAlias` and `keyPassword`.

Linux release builds are packaged as AppImages with `./scripts/appimage.sh`.
