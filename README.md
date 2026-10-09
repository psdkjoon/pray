# Pray

A Catppuccin-themed Xray client for Android, Linux and Windows, written in Flutter with no third-party Dart packages.

## Features

- VLESS, VMess, Trojan and Shadowsocks links, subscriptions and free public config lists
- Proxy mode and TUN mode (Linux asks for administrator permission, Android always uses the VPN service)
- Routing presets, custom rules, per-app VPN on Android, Iran bypass
- Ad blocking with built-in levels and downloadable filter lists
- Cloudflare WARP, standalone, after your server, or for chosen sites
- Share servers as a link, a QR code or an encrypted `.pray` file
- Quick settings tile on Android, tray icon on Linux and Windows
- Windows runs in proxy mode (TUN is Linux and Android only for now)

## Build

```
./scripts/fetch-xray.sh linux-64      # or linux-arm64, android, windows-64
flutter pub get
flutter build linux --release
flutter build apk --release --split-per-abi
flutter build windows --release        # on Windows
```

For a signed Android release create `android/key.properties` with `storeFile`, `storePassword`, `keyAlias` and `keyPassword`.

Linux release builds are packaged as AppImages with `./scripts/appimage.sh`.

Windows builds are plain folders (`build/windows/x64/runner/Release`); CI zips them as `Pray-windows-x64.zip`.

## Fonts

The bundled Noto fonts are subsetted to the characters the app uses. After adding translations, rebuild them with `python3 scripts/subset_fonts.py --src <folder with the original fonts>` (see the script header for the files it needs).
