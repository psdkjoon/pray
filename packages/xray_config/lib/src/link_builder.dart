import 'dart:convert';

import 'package:xray_config/src/models.dart';

String buildLink(ProxyServer s) {
  return switch (s.protocol) {
    ProxyProtocol.vless => _uriLink('vless', s, s.id ?? '', {
        'encryption': s.encryption,
        if (s.flow != null) 'flow': s.flow,
        ..._streamParams(s.stream),
      }),
    ProxyProtocol.trojan => _uriLink('trojan', s, s.password ?? '', {
        ..._streamParams(s.stream),
      }),
    ProxyProtocol.vmess => s.stream.security == Security.reality
        ? _uriLink('vmess', s, s.id ?? '', {
            'encryption': s.vmessSecurity,
            ..._streamParams(s.stream),
          })
        : _vmessJson(s),
    ProxyProtocol.shadowsocks => _shadowsocks(s),
  };
}

String _host(String address) => address.contains(':') ? '[$address]' : address;

String _uriLink(
  String scheme,
  ProxyServer s,
  String userInfo,
  Map<String, String?> params,
) {
  final query = [
    for (final entry in params.entries)
      if (entry.value != null)
        '${entry.key}=${Uri.encodeQueryComponent(entry.value!)}',
  ].join('&');
  final name = s.name.isEmpty ? '' : '#${Uri.encodeComponent(s.name)}';
  return '$scheme://${Uri.encodeComponent(userInfo)}@${_host(s.address)}:${s.port}'
      '${query.isEmpty ? '' : '?$query'}$name';
}

String _transportName(Transport t) => switch (t) {
      Transport.tcp => 'tcp',
      Transport.ws => 'ws',
      Transport.grpc => 'grpc',
      Transport.kcp => 'kcp',
      Transport.httpUpgrade => 'httpupgrade',
      Transport.xhttp => 'xhttp',
      Transport.h2 => 'h2',
    };

Map<String, String?> _streamParams(StreamOptions o) {
  return {
    'type': _transportName(o.transport),
    'security': o.security.name,
    'host': o.host,
    'path': o.path,
    'serviceName': o.serviceName,
    'authority': o.authority,
    'headerType': o.headerType,
    'seed': o.seed,
    'mode': o.transport == Transport.grpc
        ? (o.grpcMultiMode ? 'multi' : null)
        : o.xhttpMode,
    'sni': o.sni,
    'fp': o.fingerprint,
    'alpn': o.alpn.isEmpty ? null : o.alpn.join(','),
    'allowInsecure': o.allowInsecure ? '1' : null,
    'pbk': o.publicKey,
    'sid': o.shortId,
    'spx': o.spiderX,
  };
}

String _vmessJson(ProxyServer s) {
  final o = s.stream;
  final grpc = o.transport == Transport.grpc;
  final kcp = o.transport == Transport.kcp;
  final json = <String, Object?>{
    'v': '2',
    'ps': s.name,
    'add': s.address,
    'port': '${s.port}',
    'id': s.id,
    'aid': '${s.alterId}',
    'scy': s.vmessSecurity,
    'net': _transportName(o.transport),
    'type': grpc ? (o.grpcMultiMode ? 'multi' : 'gun') : (o.headerType ?? 'none'),
    'host': o.host ?? '',
    'path': grpc ? (o.serviceName ?? '') : kcp ? (o.seed ?? '') : (o.path ?? ''),
    'tls': o.security == Security.tls ? 'tls' : '',
    'sni': o.sni ?? '',
    'fp': o.fingerprint ?? '',
    'alpn': o.alpn.join(','),
    if (o.allowInsecure) 'allowInsecure': '1',
  };
  return 'vmess://${base64.encode(utf8.encode(jsonEncode(json)))}';
}

String _shadowsocks(ProxyServer s) {
  final credentials = base64Url
      .encode(utf8.encode('${s.method}:${s.password}'))
      .replaceAll('=', '');
  final name = s.name.isEmpty ? '' : '#${Uri.encodeComponent(s.name)}';
  return 'ss://$credentials@${_host(s.address)}:${s.port}$name';
}
