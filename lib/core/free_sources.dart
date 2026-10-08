
import 'package:pray/core/http_fetch.dart';
import 'package:pray/core/real_ping.dart';
import 'package:xray_config/xray_config.dart';

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

const defaultConfigSources = [
  ConfigSource(
    name: 'MahsaNet (MCI)',
    url: 'https://raw.githubusercontent.com/mahsanet/MahsaFreeConfig/main/mci/sub_1.txt',
  ),
  ConfigSource(
    name: 'MahsaNet (MTN)',
    url: 'https://raw.githubusercontent.com/mahsanet/MahsaFreeConfig/main/mtn/sub_1.txt',
  ),
  ConfigSource(
    name: 'barry-far',
    url: 'https://raw.githubusercontent.com/barry-far/V2ray-Configs/main/All_Configs_Sub.txt',
  ),
  ConfigSource(
    name: 'Epodonios',
    url: 'https://raw.githubusercontent.com/Epodonios/v2ray-configs/main/All_Configs_Sub.txt',
  ),
  ConfigSource(
    name: 'MatinGhanbari',
    url: 'https://raw.githubusercontent.com/MatinGhanbari/v2ray-configs/main/subscriptions/v2ray/super-sub.txt',
  ),
  ConfigSource(
    name: 'ALIILAPRO',
    url: 'https://raw.githubusercontent.com/ALIILAPRO/v2rayNG-Config/main/sub.txt',
  ),
  ConfigSource(
    name: 'V2RayAggregator',
    url: 'https://raw.githubusercontent.com/mahdibland/V2RayAggregator/master/sub/sub_merge.txt',
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
  static const perSourceLimit = 400;

  static Future<List<FoundServer>> fetch(
    List<ConfigSource> sources, {
    void Function(int done, int total)? onProgress,
  }) async {
    final seen = <String>{};
    final found = <FoundServer>[];
    var done = 0;
    await Future.wait([
      for (final source in sources)
        () async {
          try {
            final body = await fetchText(source.url);
            final result = parseSubscription(body);
            for (final proxy in result.servers.take(perSourceLimit)) {
              final server = FoundServer(proxy, source.name);
              if (seen.add(server.key)) found.add(server);
            }
          } on Object {
            return;
          } finally {
            done++;
            onProgress?.call(done, sources.length);
          }
        }(),
    ]);
    return found;
  }

  static Future<void> testAll(
    List<FoundServer> servers, {
    void Function(int done)? onProgress,
    bool Function()? cancelled,
  }) async {
    var done = 0;
    await RealPing.measureMany<FoundServer>(
      servers,
      (s) => s.proxy,
      (s, ms) {
        s.pingMs = ms;
        s.tested = true;
        done++;
        onProgress?.call(done);
      },
      cancelled: cancelled,
    );
  }
}
