import 'dart:convert';

import 'package:xray_config/src/base64_utils.dart';
import 'package:xray_config/src/models.dart';

const supportedSchemes = {'vless', 'vmess', 'trojan', 'ss'};

class LinkFormatException implements Exception {
  const LinkFormatException(this.message);

  final String message;

  @override
  String toString() => 'LinkFormatException: $message';
}

ProxyServer parseLink(String link) {
  final trimmed = link.trim();
  final schemeEnd = trimmed.indexOf('://');
  if (schemeEnd <= 0) throw const LinkFormatException('Not a share link');
  final scheme = trimmed.substring(0, schemeEnd).toLowerCase();
  return switch (scheme) {
    'vless' => _parseVless(trimmed),
    'vmess' => _parseVmess(trimmed),
    'trojan' => _parseTrojan(trimmed),
    'ss' => _parseShadowsocks(trimmed),
    _ => throw LinkFormatException('Unsupported link type "$scheme"'),
  };
}

ProxyServer _parseVless(String link) {
  final parsed = _parseUriLink(link);
  final id = _percentDecode(parsed.uri.userInfo);
  if (id.isEmpty) {
    throw const LinkFormatException('VLESS link is missing the user ID');
  }
  return ProxyServer(
    protocol: ProxyProtocol.vless,
    name: parsed.name,
    address: parsed.host,
    port: parsed.port,
    id: id,
    encryption: _nonEmpty(parsed.params['encryption']) ?? 'none',
    flow: _nonEmpty(parsed.params['flow']),
    stream: _streamFromParams(parsed.params),
  );
}

ProxyServer _parseTrojan(String link) {
  final parsed = _parseUriLink(link);
  final password = _percentDecode(parsed.uri.userInfo);
  if (password.isEmpty) {
    throw const LinkFormatException('Trojan link is missing the password');
  }
  return ProxyServer(
    protocol: ProxyProtocol.trojan,
    name: parsed.name,
    address: parsed.host,
    port: parsed.port,
    password: password,
    stream: _streamFromParams(parsed.params, defaultSecurity: Security.tls),
  );
}

ProxyServer _parseVmess(String link) {
  final payload = link.substring(link.indexOf('://') + 3);
  final body = payload.split('#').first.split('?').first;

  if (body.contains('@')) {
    final parsed = _parseUriLink(link);
    final id = _percentDecode(parsed.uri.userInfo);
    if (id.isEmpty) {
      throw const LinkFormatException('VMess link is missing the user ID');
    }
    return ProxyServer(
      protocol: ProxyProtocol.vmess,
      name: parsed.name,
      address: parsed.host,
      port: parsed.port,
      id: id,
      vmessSecurity: _nonEmpty(parsed.params['encryption']) ?? 'auto',
      stream: _streamFromParams(parsed.params),
    );
  }

  final decoded = tryDecodeBase64(body);
  if (decoded == null) {
    throw const LinkFormatException('VMess link is not valid base64');
  }
  final Object? rawJson;
  try {
    rawJson = jsonDecode(decoded);
  } on FormatException {
    throw const LinkFormatException('VMess link does not contain valid JSON');
  }
  if (rawJson is! Map<String, dynamic>) {
    throw const LinkFormatException(
      'VMess link does not contain a JSON object',
    );
  }
  final Map<String, dynamic> json = rawJson;

  String? field(String key) {
    final value = json[key];
    return value == null ? null : _nonEmpty('$value');
  }

  final address = field('add');
  final id = field('id');
  final port = int.tryParse(field('port') ?? '');
  if (address == null) {
    throw const LinkFormatException('VMess link is missing the address');
  }
  if (id == null) {
    throw const LinkFormatException('VMess link is missing the user ID');
  }
  if (port == null || port < 1 || port > 65535) {
    throw const LinkFormatException('Missing or invalid port');
  }

  final transport = _transport(field('net'));
  final security = field('tls') == 'tls' ? Security.tls : Security.none;
  final type = field('type');
  final host = field('host');
  final path = field('path');

  return ProxyServer(
    protocol: ProxyProtocol.vmess,
    name: field('ps') ?? '',
    address: address,
    port: port,
    id: id,
    alterId: int.tryParse(field('aid') ?? '') ?? 0,
    vmessSecurity: field('scy') ?? 'auto',
    stream: StreamOptions(
      transport: transport,
      security: security,
      host: host,
      path: (transport == Transport.grpc || transport == Transport.kcp)
          ? null
          : path,
      serviceName: transport == Transport.grpc ? path : null,
      grpcMultiMode: transport == Transport.grpc && type == 'multi',
      headerType: transport == Transport.grpc ? null : type,
      seed: transport == Transport.kcp ? path : null,
      sni: field('sni') ?? host,
      fingerprint: field('fp'),
      alpn: _csv(field('alpn')),
      allowInsecure: _truthy(field('allowInsecure')),
    ),
  );
}

ProxyServer _parseShadowsocks(String link) {
  final (withoutFragment, name) = _splitFragment(link);
  var rest = withoutFragment.substring(withoutFragment.indexOf('://') + 3);

  final query = rest.indexOf('?');
  if (query >= 0) {
    if (rest.substring(query + 1).contains('plugin=')) {
      throw const LinkFormatException(
        'Shadowsocks plugins are not supported by Xray-core',
      );
    }
    rest = rest.substring(0, query);
  }

  final String credentials;
  final String hostPort;
  final at = rest.lastIndexOf('@');
  if (at >= 0) {
    final userInfo = _percentDecode(rest.substring(0, at));
    final decoded =
        userInfo.contains(':') ? userInfo : tryDecodeBase64(userInfo);
    if (decoded == null) {
      throw const LinkFormatException('Shadowsocks credentials are not valid');
    }
    credentials = decoded;
    final tail = rest.substring(at + 1);
    hostPort = tail.endsWith('/') ? tail.substring(0, tail.length - 1) : tail;
  } else {
    final decoded = tryDecodeBase64(rest);
    if (decoded == null) {
      throw const LinkFormatException('Shadowsocks link is not valid base64');
    }
    final innerAt = decoded.lastIndexOf('@');
    if (innerAt < 0) {
      throw const LinkFormatException(
        'Shadowsocks link is missing the server address',
      );
    }
    credentials = decoded.substring(0, innerAt);
    hostPort = decoded.substring(innerAt + 1);
  }

  final colon = credentials.indexOf(':');
  if (colon <= 0 || colon == credentials.length - 1) {
    throw const LinkFormatException(
      'Shadowsocks credentials need a method and a password',
    );
  }

  final Uri server;
  try {
    server = Uri.parse('ss://$hostPort');
  } on FormatException {
    throw const LinkFormatException('Shadowsocks server address is not valid');
  }
  if (server.host.isEmpty || !server.hasPort || server.port < 1) {
    throw const LinkFormatException('Missing server address or port');
  }

  return ProxyServer(
    protocol: ProxyProtocol.shadowsocks,
    name: name,
    address: server.host,
    port: server.port,
    method: credentials.substring(0, colon),
    password: credentials.substring(colon + 1),
  );
}

class _UriLink {
  const _UriLink({
    required this.uri,
    required this.name,
    required this.host,
    required this.port,
    required this.params,
  });

  final Uri uri;
  final String name;
  final String host;
  final int port;
  final Map<String, String> params;
}

_UriLink _parseUriLink(String link) {
  final (body, name) = _splitFragment(link);
  final uri = _uriOf(body);
  if (uri.host.isEmpty) {
    throw const LinkFormatException('Missing server address');
  }
  final port = uri.hasPort ? uri.port : 0;
  if (port < 1 || port > 65535) {
    throw const LinkFormatException('Missing or invalid port');
  }
  return _UriLink(
    uri: uri,
    name: name,
    host: uri.host,
    port: port,
    params: _queryOf(uri),
  );
}

Uri _uriOf(String body) {
  try {
    return Uri.parse(body);
  } on FormatException catch (e) {
    throw LinkFormatException('Malformed link: ${e.message}');
  }
}

Map<String, String> _queryOf(Uri uri) {
  try {
    return uri.queryParameters;
  } on FormatException {
    throw const LinkFormatException('Malformed query string');
  } on ArgumentError {
    throw const LinkFormatException('Malformed query string');
  }
}

(String, String) _splitFragment(String link) {
  final hash = link.indexOf('#');
  if (hash < 0) return (link, '');
  return (
    link.substring(0, hash),
    _percentDecode(link.substring(hash + 1)).trim(),
  );
}

StreamOptions _streamFromParams(
  Map<String, String> p, {
  Security defaultSecurity = Security.none,
}) {
  final transport = _transport(p['type']);
  final security = _security(p['security'], defaultSecurity);
  final publicKey = _nonEmpty(p['pbk']);
  if (security == Security.reality && publicKey == null) {
    throw const LinkFormatException(
      'Reality link is missing the public key (pbk)',
    );
  }
  return StreamOptions(
    transport: transport,
    security: security,
    host: _nonEmpty(p['host']),
    path: _nonEmpty(p['path']),
    serviceName: _nonEmpty(p['serviceName']),
    grpcMultiMode: transport == Transport.grpc && p['mode'] == 'multi',
    authority: _nonEmpty(p['authority']),
    headerType: _nonEmpty(p['headerType']),
    seed: _nonEmpty(p['seed']),
    xhttpMode: transport == Transport.xhttp ? _nonEmpty(p['mode']) : null,
    sni: _nonEmpty(p['sni']) ?? _nonEmpty(p['peer']),
    fingerprint: _nonEmpty(p['fp']),
    alpn: _csv(p['alpn']),
    allowInsecure: _truthy(p['allowInsecure']) || _truthy(p['insecure']),
    publicKey: publicKey,
    shortId: p['sid'],
    spiderX: _nonEmpty(p['spx']),
  );
}

Transport _transport(String? type) {
  return switch (type?.toLowerCase()) {
    null || '' || 'tcp' || 'raw' => Transport.tcp,
    'ws' || 'websocket' => Transport.ws,
    'grpc' || 'gun' => Transport.grpc,
    'kcp' || 'mkcp' => Transport.kcp,
    'httpupgrade' => Transport.httpUpgrade,
    'xhttp' || 'splithttp' => Transport.xhttp,
    'h2' || 'http' => Transport.h2,
    final other => throw LinkFormatException('Unsupported transport "$other"'),
  };
}

Security _security(String? value, Security fallback) {
  return switch (value?.toLowerCase()) {
    null || '' => fallback,
    'none' => Security.none,
    'tls' => Security.tls,
    'reality' => Security.reality,
    final other => throw LinkFormatException('Unsupported security "$other"'),
  };
}

String? _nonEmpty(String? value) {
  final trimmed = value?.trim();
  return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
}

String _percentDecode(String value) {
  try {
    return Uri.decodeComponent(value);
  } on FormatException {
    return value;
  } on ArgumentError {
    return value;
  }
}

List<String> _csv(String? value) {
  return [
    for (final part in (value ?? '').split(','))
      if (part.trim().isNotEmpty) part.trim(),
  ];
}

bool _truthy(String? value) => value == '1' || value?.toLowerCase() == 'true';
