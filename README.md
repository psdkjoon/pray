# Pray

A Catppuccin-themed Xray client for Android, Linux and Windows, written in Flutter. `flutter_svg` is the only dependency besides Flutter itself.

## Features

- VLESS, VMess, Trojan and Shadowsocks links and free public config lists
- Subscription groups: every subscription is its own group with its own name (taken from the provider's `profile-title` when it sends one). Each group updates from its link on its own, or all at once. Updating keeps your pins, pings and the selected server, and a broken link never empties a group
- Fast latency test: servers that do not answer a plain connect are dropped at once, the rest are timed in batches through a single xray process
- Live download and upload speed on Home, read from xray's own byte counters (a local stats page on a random port)
- Changing the selected server while connected reconnects to the new one
- Terminal helper on Linux (Home, Terminal button): a ready `proxychains4` config plus `ALL_PROXY` snippets for bash, zsh and fish, written to `~/.config/pray/` each time you connect
- Only one window: starting Pray again brings the open (or hidden) window to the front
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

The script downloads xray v26.6.27 by default, the last release before xray refused VLESS without TLS or encryption on public addresses. Use `XRAY_VERSION=<tag> ./scripts/fetch-xray.sh ...` for another tag, or `XRAY_VERSION=latest` for the newest.

For a signed Android release create `android/key.properties` with `storeFile`, `storePassword`, `keyAlias` and `keyPassword`.

Linux release builds are packaged as AppImages with `./scripts/appimage.sh`.

Windows builds are plain folders (`build/windows/x64/runner/Release`). CI wraps that folder into an installer, `Pray-windows-x64-setup.exe`, with [Inno Setup](https://jrsoftware.org/isinfo.php) (`windows/installer/installer.iss`; locally: `iscc /DAppName=Pray /DAppExe=pray.exe /DAppVersion=2.0.1 /DAppMutex=Local\ir.psdkjoon.pray.instance windows\installer\installer.iss`). The installer is the only Windows file published on the releases page.

If the app fails while starting, the reason is shown in the window and saved to `startup.log` in the app's data folder (`%APPDATA%\pray` on Windows).

## Release

```
bash scripts/bump_version.sh 2.0.1
git commit -am "Release 2.0.1" && git push
```

CI builds the Android APKs, the Linux AppImages and the Windows installer, then publishes them to GitHub Releases as `v2.0.1`. Installed copies find the new version through the `VERSION` file on `main`.

## Languages

The app ships in Persian (`fa`), English (`en`), Japanese (`ja`) and Russian (`ru`). Write new text in English and add it to `strings_fa.dart`, `strings_ja.dart` and `strings_ru.dart`.

## Structure

Pray follows the flutter-base conventions: Persian digits and pure Persian words, the Settings order (Appearance, Language, app sections, Updates, then the About block with links, donations and diagnostics), the compact bottom bar, `AppInfo.usesBackground`, and one launcher icon with the accent-follow aliases. In short: `core/` for plain Dart (including `core/xray_config`), `connection/` and `servers/` for feature state, `platform/` for OS channels, `ui/` for screens.

## Building this app with Claude

Do not design from memory. Before writing any screen:

1. Use the best UI and UX plugin available in Claude's plugins (design critique, accessibility review, UX copy, design system) to decide how each screen should look and behave.
2. Use the best Flutter plugins (the official Flutter and Dart skills first, then the strongest community ones) to decide what to build and how. Read the matching skill before writing that kind of code.
3. Build the screen, then review it with the same plugins before calling it done. Check it in all four languages, in Mocha and Latte, and in right-to-left Persian.
4. Where a plugin disagrees with the flutter-base README (third-party packages, comments, state management), the flutter-base README wins.

