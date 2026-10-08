import 'dart:async';
import 'dart:convert';
import 'dart:io';

class DnsLeakServer {
  const DnsLeakServer({required this.ip, this.country, this.provider});

  final String ip;
  final String? country;
  final String? provider;
}

class DnsLeakResult {
  const DnsLeakResult({this.ip, this.ipCountry, this.servers = const [], this.conclusion});

  final String? ip;
  final String? ipCountry;
  final List<DnsLeakServer> servers;
  final String? conclusion;
}

abstract class DnsLeakTest {
  static Future<DnsLeakResult> run() async {
    final id = (await _get('https://bash.ws/id')).trim();
    if (id.isEmpty) throw const HttpException('empty id');
    await Future.wait([
      for (var i = 0; i < 10; i++)
        InternetAddress.lookup('$i.$id.bash.ws')
            .timeout(const Duration(seconds: 6))
            .then<void>((_) {}, onError: (Object _) {}),
    ]);
    final body = await _get('https://bash.ws/dnsleak/test/$id?json');
    final data = jsonDecode(body) as List;
    String? ip;
    String? ipCountry;
    String? conclusion;
    final servers = <DnsLeakServer>[];
    for (final item in data) {
      final map = item as Map;
      final type = '${map['type']}';
      final address = '${map['ip'] ?? ''}';
      final country = map['country_name'] == null || '${map['country_name']}'.isEmpty
          ? null
          : '${map['country_name']}';
      final asn = map['asn'] == null || '${map['asn']}'.isEmpty ? null : '${map['asn']}';
      switch (type) {
        case 'ip':
          ip = address;
          ipCountry = country;
        case 'dns':
          servers.add(DnsLeakServer(ip: address, country: country, provider: asn));
        case 'conclusion':
          conclusion = address;
      }
    }
    return DnsLeakResult(
      ip: ip,
      ipCountry: ipCountry,
      servers: servers,
      conclusion: conclusion,
    );
  }

  static Future<String> _get(String url) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 8)
      ..userAgent = 'pray-dns-test';
    try {
      final request = await client
          .getUrl(Uri.parse(url))
          .timeout(const Duration(seconds: 8));
      final response = await request.close().timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        await response.drain<void>();
        throw HttpException('status ${response.statusCode}');
      }
      return await response
          .transform(utf8.decoder)
          .join()
          .timeout(const Duration(seconds: 15));
    } finally {
      client.close(force: true);
    }
  }
}
