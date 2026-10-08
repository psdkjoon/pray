import 'dart:io';

import 'package:pray/core/app_dirs.dart';
import 'package:pray/core/http_fetch.dart';

class AdList {
  const AdList({required this.name, required this.url, this.enabled = true});

  final String name;
  final String url;
  final bool enabled;

  AdList copyWith({bool? enabled}) =>
      AdList(name: name, url: url, enabled: enabled ?? this.enabled);

  String encode() => '${enabled ? 1 : 0}|$name|$url';

  static AdList? decode(String text) {
    final parts = text.split('|');
    if (parts.length < 3) return null;
    return AdList(
      enabled: parts[0] == '1',
      name: parts[1],
      url: parts.sublist(2).join('|'),
    );
  }
}

const presetAdLists = [
  AdList(
    name: 'StevenBlack hosts',
    url: 'https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts',
    enabled: false,
  ),
  AdList(
    name: 'HaGeZi Pro',
    url: 'https://raw.githubusercontent.com/hagezi/dns-blocklists/main/domains/pro.txt',
    enabled: false,
  ),
  AdList(
    name: 'AdGuard DNS filter',
    url: 'https://adguardteam.github.io/AdGuardSDNSFilter/Filters/filter.txt',
    enabled: false,
  ),
  AdList(
    name: 'PersianBlocker (Iranian ads)',
    url: 'https://raw.githubusercontent.com/MasterKia/PersianBlocker/main/PersianBlockerHosts.txt',
    enabled: false,
  ),
];

const youtubeAdDomains = [
  'googleads.g.doubleclick.net',
  'googleads4.g.doubleclick.net',
  'pubads.g.doubleclick.net',
  'securepubads.g.doubleclick.net',
  'static.doubleclick.net',
  'pagead2.googlesyndication.com',
  'tpc.googlesyndication.com',
  'ade.googlesyndication.com',
  'imasdk.googleapis.com',
  'ad.youtube.com',
  'ads.youtube.com',
  'youtube.cleverads.vn',
  's0.2mdn.net',
  'adservice.google.com',
  'www.googleadservices.com',
];

const strictBuiltinDomains = [
  'ads.facebook.com',
  'an.facebook.com',
  'ads.twitter.com',
  'ads-api.twitter.com',
  'analytics.twitter.com',
  'ads.tiktok.com',
  'analytics.tiktok.com',
  'adsterra.com',
  'popads.net',
  'propellerads.com',
  'exoclick.com',
  'mgid.com',
  'revcontent.com',
  'smaato.net',
  'mopub.com',
  'ironsrc.com',
  'ironsource.com',
  'fyber.com',
  'tapjoy.com',
  'appsflyer.com',
  'kochava.com',
  'segment.io',
  'amplitude.com',
  'doubleclick.net',
  'googlesyndication.com',
  'googleadservices.com',
  'google-analytics.com',
  'googletagmanager.com',
  'googletagservices.com',
  'adservice.google.com',
  'app-measurement.com',
  'scorecardresearch.com',
  'adnxs.com',
  'criteo.com',
  'criteo.net',
  'taboola.com',
  'outbrain.com',
  'pubmatic.com',
  'rubiconproject.com',
  'moatads.com',
  'amazon-adsystem.com',
  'unityads.unity3d.com',
  'applovin.com',
  'adcolony.com',
  'vungle.com',
  'chartboost.com',
  'inmobi.com',
  'supersonicads.com',
  'startappservice.com',
  'flurry.com',
  'hotjar.com',
  'mixpanel.com',
  'mc.yandex.ru',
  'an.yandex.ru',
  'yektanet.com',
  'tapsell.ir',
  'adivery.com',
  'mediaad.org',
];

abstract class AdBlockLists {
  static const maxDomains = 80000;
  static final _domain = RegExp(
    r'^(?=.{4,253}$)([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,63}$',
  );

  static Future<File> _file() async =>
      File('${await AppDirs.data()}/adblock_domains.txt');

  static Future<List<String>> load() async {
    try {
      final file = await _file();
      if (!await file.exists()) return const [];
      return (await file.readAsLines()).where((l) => l.isNotEmpty).toList();
    } on Object {
      return const [];
    }
  }

  static Future<DateTime?> lastUpdated() async {
    try {
      final file = await _file();
      return await file.exists() ? await file.lastModified() : null;
    } on Object {
      return null;
    }
  }

  static Set<String> parse(String body) {
    final result = <String>{};
    for (final raw in body.split('\n')) {
      var line = raw.trim();
      if (line.isEmpty ||
          line.startsWith('#') ||
          line.startsWith('!') ||
          line.startsWith('[')) {
        continue;
      }
      final hash = line.indexOf('#');
      if (hash > 0) line = line.substring(0, hash).trim();
      String? candidate;
      if (line.startsWith('||')) {
        final end = line.indexOf('^');
        if (end > 2 && !line.contains('/')) candidate = line.substring(2, end);
      } else {
        final parts = line.split(RegExp(r'\s+'));
        if (parts.length == 1) {
          candidate = parts[0];
        } else if (parts.length >= 2 &&
            (parts[0] == '0.0.0.0' || parts[0] == '127.0.0.1')) {
          candidate = parts[1];
        }
      }
      if (candidate == null) continue;
      final domain = candidate.toLowerCase().replaceFirst(RegExp(r'^\*\.'), '');
      if (_domain.hasMatch(domain)) result.add(domain);
    }
    return result;
  }

  static Future<({int count, List<String> failed})> update(
    List<AdList> lists, {
    void Function(double?)? onProgress,
  }) async {
    final enabled = lists.where((l) => l.enabled).toList();
    final all = <String>{};
    final failed = <String>[];
    for (var i = 0; i < enabled.length; i++) {
      try {
        final body = await fetchText(
          enabled[i].url,
          onProgress: (f) =>
              onProgress?.call(f == null ? null : (i + f) / enabled.length),
        );
        all.addAll(parse(body));
      } on Object {
        failed.add(enabled[i].name);
      }
      onProgress?.call((i + 1) / enabled.length);
    }
    if (all.isNotEmpty || enabled.isEmpty) {
      final list = all.take(maxDomains).toList();
      await (await _file()).writeAsString(list.join('\n'), flush: true);
      return (count: list.length, failed: failed);
    }
    return (count: (await load()).length, failed: failed);
  }
}
