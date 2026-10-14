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

Windows builds are plain folders (`build/windows/x64/runner/Release`). CI wraps that folder into an installer, `Pray-windows-x64-setup.exe`, with [Inno Setup](https://jrsoftware.org/isinfo.php) (`windows/installer/installer.iss`; locally: `iscc /DAppName=Pray /DAppExe=pray.exe /DAppVersion=1.4.0 /DAppMutex=Local\ir.psdkjoon.pray.instance windows\installer\installer.iss`). The installer is the only Windows file published on the releases page.

If the app fails while starting, the reason is shown in the window and saved to `startup.log` in the app's data folder (`%APPDATA%\pray` on Windows).

## Fonts

The bundled Noto fonts are subsetted to the characters the app uses. After adding translations, rebuild them with `python3 scripts/subset_fonts.py --src <folder with the original fonts>` (see the script header for the files it needs).

## Release

```
bash scripts/bump_version.sh 1.4.1
git commit -am "Release 1.4.1" && git push
```

CI builds the Android APKs, the Linux AppImages and the Windows installer, then publishes them to GitHub Releases as `v1.4.1`. Installed copies find the new version through the `VERSION` file on `main`.

## Icons

Edit `assets/icons/icon_mocha.svg` and `icon_latte.svg`, then run `python3 scripts/generate_icons.py`.

## Languages

The app ships in Persian (`fa`), English (`en`), Japanese (`ja`) and Russian (`ru`). Write new text in English and add it to `strings_fa.dart`, `strings_ja.dart` and `strings_ru.dart`. `flutter test` fails when a language is missing a string.

## Structure

Pray follows the [flutter-base](flutter-base-README.md) conventions: `core/` for plain Dart (including `core/xray_config`), `connection/` and `servers/` for feature state, `platform/` for OS channels, `ui/` for screens.

## Building this app with Claude

Do not design from memory. Before writing any screen:

1. Use the best UI and UX plugin available in Claude's plugins (design critique, accessibility review, UX copy, design system) to decide how each screen should look and behave.
2. Use the best Flutter plugins (the official Flutter and Dart skills first, then the strongest community ones) to decide what to build and how. Read the matching skill before writing that kind of code.
3. Build the screen, then review it with the same plugins before calling it done. Check it in all four languages, in Mocha and Latte, and in right-to-left Persian.
4. Where a plugin disagrees with the flutter-base README (third-party packages, comments, state management), the flutter-base README wins.

See the flutter-base README for the structure and the conventions this project follows.
