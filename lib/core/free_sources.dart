import 'dart:async';

import 'package:pray/core/http_fetch.dart';
import 'package:pray/core/real_ping.dart';
import 'package:pray/core/xray_config/xray_config.dart';

class ConfigSource {
  const ConfigSource({required this.name, required this.url});

  final String name;
  final String url;

  String encode() => '$name|$url';

  static ConfigSource? decode(String text) {
    final index = text.indexOf('|');
    if (index <= 0) return null;
    return ConfigSource(
      name: text.substring(0, index),
      url: text.substring(index + 1),
    );
  }
}

const _raw = 'https://raw.githubusercontent.com';

const defaultSourcesVersion = 2;

const defaultConfigSources = [
  ConfigSource(
    name: 'MahsaNet (MCI)',
    url: '$_raw/mahsanet/MahsaFreeConfig/main/mci/sub_1.txt',
  ),
  ConfigSource(
    name: 'MahsaNet (MTN)',
    url: '$_raw/mahsanet/MahsaFreeConfig/main/mtn/sub_1.txt',
  ),
  ConfigSource(
    name: 'barry-far',
    url: '$_raw/barry-far/V2ray-Configs/main/All_Configs_Sub.txt',
  ),
  ConfigSource(
    name: 'barry-far (VLESS)',
    url: '$_raw/barry-far/V2ray-Configs/main/Splitted-By-Protocol/vless.txt',
  ),
  ConfigSource(
    name: 'barry-far (VMess)',
    url: '$_raw/barry-far/V2ray-Configs/main/Splitted-By-Protocol/vmess.txt',
  ),
  ConfigSource(
    name: 'barry-far (Trojan)',
    url: '$_raw/barry-far/V2ray-Configs/main/Splitted-By-Protocol/trojan.txt',
  ),
  ConfigSource(
    name: 'barry-far (SS)',
    url: '$_raw/barry-far/V2ray-Configs/main/Splitted-By-Protocol/ss.txt',
  ),
  ConfigSource(
    name: 'Epodonios',
    url: '$_raw/Epodonios/v2ray-configs/main/All_Configs_Sub.txt',
  ),
  ConfigSource(
    name: 'Epodonios (VLESS)',
    url: '$_raw/Epodonios/v2ray-configs/main/Splitted-By-Protocol/vless.txt',
  ),
  ConfigSource(
    name: 'MatinGhanbari',
    url: '$_raw/MatinGhanbari/v2ray-configs/main/subscriptions/v2ray/super-sub.txt',
  ),
  ConfigSource(
    name: 'ALIILAPRO',
    url: '$_raw/ALIILAPRO/v2rayNG-Config/main/sub.txt',
  ),
  ConfigSource(
    name: 'V2RayAggregator',
    url: '$_raw/mahdibland/V2RayAggregator/master/sub/sub_merge.txt',
  ),
  ConfigSource(
    name: 'Pawdroid',
    url: '$_raw/Pawdroid/Free-servers/main/sub',
  ),
  ConfigSource(
    name: 'EbraSha',
    url: '$_raw/ebrasha/free-v2ray-public-list/main/V2Ray-Config-By-EbraSha.txt',
  ),
  ConfigSource(
    name: 'SoliSpirit',
    url: '$_raw/SoliSpirit/v2ray-configs/main/all_configs.txt',
  ),
  ConfigSource(
    name: 'Danialsamadi',
    url: '$_raw/Danialsamadi/v2go/main/AllConfigsSub.txt',
  ),
  ConfigSource(
    name: 'mheidari98',
    url: '$_raw/mheidari98/.proxy/main/all',
  ),
  ConfigSource(
    name: 'soroushmirzaei',
    url: '$_raw/soroushmirzaei/telegram-configs-collector/main/splitted/mixed',
  ),
  ConfigSource(
    name: 'yebekhe',
    url: '$_raw/yebekhe/TelegramV2rayCollector/main/sub/normal/mix',
  ),
  ConfigSource(
    name: 'MrMohebi',
    url: '$_raw/MrMohebi/xray-proxy-grabber-telegram/master/collected-proxies/row-url/all.txt',
  ),
  ConfigSource(
    name: 'Surfboardv2ray',
    url: '$_raw/Surfboardv2ray/TGParse/main/splitted/mixed',
  ),
  ConfigSource(
    name: 'NiREvil',
    url: '$_raw/NiREvil/vless/main/sub/SSTime',
  ),
  ConfigSource(
    name: 'Rayan-Config',
    url: '$_raw/Rayan-Config/C-Sub/main/configs/proxy.txt',
  ),
  ConfigSource(
    name: 'V2RayRoot',
    url: '$_raw/V2RayRoot/V2RayConfig/main/Config/vless.txt',
  ),
  ConfigSource(
    name: 'sevcator',
    url: '$_raw/sevcator/5ubscrpt10n/main/protocols/vl.txt',
  ),
  ConfigSource(
    name: 'roosterkid',
    url: '$_raw/roosterkid/openproxylist/main/V2RAY_RAW.txt',
  ),
  ConfigSource(
    name: 'Everyday-VPN',
    url: '$_raw/Everyday-VPN/Everyday-VPN/main/subscription/main.txt',
  ),
  ConfigSource(
    name: 'ermaozi',
    url: '$_raw/ermaozi/get_subscribe/main/subscribe/v2ray.txt',
  ),
  ConfigSource(
    name: 'aiboboxx',
    url: '$_raw/aiboboxx/v2rayfree/main/v2',
  ),
  ConfigSource(
    name: 'freefq',
    url: '$_raw/freefq/free/master/v2',
  ),
  ConfigSource(
    name: 'w1770946466',
    url: '$_raw/w1770946466/Auto_proxy/main/Long_term_subscription_num',
  ),
  ConfigSource(
    name: 'mfuu',
    url: '$_raw/mfuu/v2ray/master/v2ray',
  ),
  ConfigSource(
    name: 'chengaopan',
    url: '$_raw/chengaopan/AutoMergePublicNodes/master/list_raw.txt',
  ),
  ConfigSource(
    name: 'peasoft',
    url: '$_raw/peasoft/NoMoreWalls/master/list_raw.txt',
  ),
  ConfigSource(
    name: 'ts-sf',
    url: '$_raw/ts-sf/fly/main/v2',
  ),
];

class FoundServer {
  FoundServer(this.proxy, this.source);

  final ProxyServer proxy;
  final String source;
  int? pingMs;
  bool tested = false;

  String get key =>
      '${proxy.protocol.name}|${proxy.address}|${proxy.port}|${proxy.id ?? proxy.password ?? ''}';
}

abstract class FreeSources {
  static const perSourceLimit = 2000;
  static const maxTotal = 8000;
  static const enoughAlive = 80;
  static const refineCount = 30;
  static const refineRounds = 2;
  static const scanTimeout = Duration(milliseconds: 3500);
  static const refineTimeout = Duration(seconds: 4);
  static const _sourceTimeout = Duration(seconds: 20);
  static const _stagger = Duration(seconds: 3);

  static final _githubRaw = RegExp(
    r'^https://raw\.githubusercontent\.com/([^/]+)/([^/]+)/([^/]+)/(.+)$',
  );

  static List<String> _candidates(String url) {
    final match = _githubRaw.firstMatch(url);
    if (match == null) return [url];
    final user = match.group(1)!;
    final repo = match.group(2)!;
    final branch = match.group(3)!;
    final path = match.group(4)!;
    return [
      url,
      'https://cdn.jsdelivr.net/gh/$user/$repo@$branch/$path',
      'https://fastly.jsdelivr.net/gh/$user/$repo@$branch/$path',
      'https://gcore.jsdelivr.net/gh/$user/$repo@$branch/$path',
    ];
  }

  static Future<List<ProxyServer>> _load(String target) async {
    final body = await fetchText(target, timeout: _sourceTimeout);
    final servers = parseSubscription(body).servers;
    if (servers.isEmpty) throw const FormatException('No servers in the file');
    return servers;
  }

  static Future<List<ProxyServer>> _download(String url) {
    final targets = _candidates(url);
    final done = Completer<List<ProxyServer>>();
    var launched = 0;
    var failed = 0;
    Timer? timer;

    void launch() {
      if (done.isCompleted || launched >= targets.length) return;
      final target = targets[launched++];
      timer?.cancel();
      if (launched < targets.length) timer = Timer(_stagger, launch);
      _load(target).then((servers) {
        if (done.isCompleted) return;
        timer?.cancel();
        done.complete(servers);
      }, onError: (Object error) {
        failed++;
        if (done.isCompleted) return;
        if (failed >= targets.length) {
          timer?.cancel();
          done.completeError(error);
        } else {
          launch();
        }
      });
    }

    launch();
    return done.future;
  }

  static Future<List<FoundServer>> fetch(
    List<ConfigSource> sources, {
    void Function(int done, int total)? onProgress,
    void Function(ConfigSource source, int? count)? onSource,
  }) async {
    final seen = <String>{};
    final found = <FoundServer>[];
    var done = 0;
    await Future.wait([
      for (final source in sources)
        () async {
          int? count;
          try {
            final proxies = await _download(source.url);
            count = proxies.length;
            final sample = [...proxies]..shuffle();
            for (final proxy in sample.take(perSourceLimit)) {
              final server = FoundServer(proxy, source.name);
              if (seen.add(server.key)) found.add(server);
            }
          } on Object {
            count = null;
          } finally {
            done++;
            onSource?.call(source, count);
            onProgress?.call(done, sources.length);
          }
        }(),
    ]);
    found.shuffle();
    if (found.length <= maxTotal) return found;
    return found.sublist(0, maxTotal);
  }

  static Future<void> testAll(
    List<FoundServer> servers, {
    void Function(int done, int alive)? onProgress,
    bool Function()? cancelled,
    bool Function()? finishEarly,
  }) async {
    var done = 0;
    var alive = 0;
    bool aborted() => cancelled?.call() ?? false;
    bool skipRest() => aborted() || (finishEarly?.call() ?? false);

    await RealPing.measureMany<FoundServer>(
      servers,
      (s) => s.proxy,
      (s, ms) {
        s.pingMs = ms;
        s.tested = true;
        done++;
        if (ms != null) alive++;
        onProgress?.call(done, alive);
      },
      cancelled: () => skipRest() || alive >= enoughAlive,
      probeTimeout: scanTimeout,
    );
    if (skipRest()) return;
    await _refine(servers, skipRest);
  }

  static Future<void> _refine(
    List<FoundServer> servers,
    bool Function() halt,
  ) async {
    final best = servers.where((s) => s.pingMs != null).toList()
      ..sort((a, b) => a.pingMs!.compareTo(b.pingMs!));
    final subset = best.take(refineCount).toList();
    if (subset.isEmpty) return;
    final samples = {
      for (final server in subset) server: <int>[server.pingMs!],
    };
    for (var round = 0; round < refineRounds; round++) {
      if (halt()) return;
      await RealPing.measureMany<FoundServer>(
        subset,
        (s) => s.proxy,
        (s, ms) {
          if (ms != null) samples[s]!.add(ms);
        },
        cancelled: halt,
        probeTimeout: refineTimeout,
        skipTcp: true,
      );
    }
    if (halt()) return;
    const needed = (refineRounds + 2) ~/ 2;
    for (final entry in samples.entries) {
      final values = [...entry.value]..sort();
      entry.key.pingMs =
          values.length < needed ? null : values[values.length ~/ 2];
    }
  }
}
