enum ProxyProtocol { vless, vmess, trojan, shadowsocks }

enum Transport { tcp, ws, grpc, kcp, httpUpgrade, xhttp, h2 }

enum Security { none, tls, reality }

class StreamOptions {
  const StreamOptions({
    this.transport = Transport.tcp,
    this.security = Security.none,
    this.host,
    this.path,
    this.serviceName,
    this.grpcMultiMode = false,
    this.authority,
    this.headerType,
    this.seed,
    this.xhttpMode,
    this.sni,
    this.fingerprint,
    this.alpn = const [],
    this.allowInsecure = false,
    this.publicKey,
    this.shortId,
    this.spiderX,
  });

  final Transport transport;
  final Security security;

  final String? host;
  final String? path;

  final String? serviceName;
  final bool grpcMultiMode;
  final String? authority;

  final String? headerType;

  final String? seed;
  final String? xhttpMode;

  final String? sni;
  final String? fingerprint;
  final List<String> alpn;
  final bool allowInsecure;

  final String? publicKey;
  final String? shortId;
  final String? spiderX;

  Map<String, Object?> toJson() => {
        'transport': transport.name,
        'security': security.name,
        'host': host,
        'path': path,
        'serviceName': serviceName,
        'grpcMultiMode': grpcMultiMode,
        'authority': authority,
        'headerType': headerType,
        'seed': seed,
        'xhttpMode': xhttpMode,
        'sni': sni,
        'fingerprint': fingerprint,
        'alpn': alpn,
        'allowInsecure': allowInsecure,
        'publicKey': publicKey,
        'shortId': shortId,
        'spiderX': spiderX,
      };

  factory StreamOptions.fromJson(Map<String, Object?> json) {
    return StreamOptions(
      transport: Transport.values.byName(json['transport'] as String? ?? 'tcp'),
      security: Security.values.byName(json['security'] as String? ?? 'none'),
      host: json['host'] as String?,
      path: json['path'] as String?,
      serviceName: json['serviceName'] as String?,
      grpcMultiMode: json['grpcMultiMode'] as bool? ?? false,
      authority: json['authority'] as String?,
      headerType: json['headerType'] as String?,
      seed: json['seed'] as String?,
      xhttpMode: json['xhttpMode'] as String?,
      sni: json['sni'] as String?,
      fingerprint: json['fingerprint'] as String?,
      alpn: [...?(json['alpn'] as List?)?.cast<String>()],
      allowInsecure: json['allowInsecure'] as bool? ?? false,
      publicKey: json['publicKey'] as String?,
      shortId: json['shortId'] as String?,
      spiderX: json['spiderX'] as String?,
    );
  }
}

class ProxyServer {
  const ProxyServer({
    required this.protocol,
    required this.address,
    required this.port,
    this.name = '',
    this.id,
    this.password,
    this.method,
    this.flow,
    this.encryption = 'none',
    this.alterId = 0,
    this.vmessSecurity = 'auto',
    this.stream = const StreamOptions(),
  });

  final ProxyProtocol protocol;
  final String address;
  final int port;

  final String name;

  final String? id;

  final String? password;

  final String? method;

  final String? flow;

  final String encryption;
  final int alterId;

  final String vmessSecurity;
  final StreamOptions stream;

  ProxyServer copyWith({
    String? name,
    String? address,
    int? port,
    String? id,
    String? password,
  }) {
    return ProxyServer(
      protocol: protocol,
      address: address ?? this.address,
      port: port ?? this.port,
      name: name ?? this.name,
      id: id ?? this.id,
      password: password ?? this.password,
      method: method,
      flow: flow,
      encryption: encryption,
      alterId: alterId,
      vmessSecurity: vmessSecurity,
      stream: stream,
    );
  }

  Map<String, Object?> toJson() => {
        'protocol': protocol.name,
        'address': address,
        'port': port,
        'name': name,
        'id': id,
        'password': password,
        'method': method,
        'flow': flow,
        'encryption': encryption,
        'alterId': alterId,
        'vmessSecurity': vmessSecurity,
        'stream': stream.toJson(),
      };

  factory ProxyServer.fromJson(Map<String, Object?> json) {
    return ProxyServer(
      protocol: ProxyProtocol.values.byName(json['protocol'] as String),
      address: json['address'] as String,
      port: json['port'] as int,
      name: json['name'] as String? ?? '',
      id: json['id'] as String?,
      password: json['password'] as String?,
      method: json['method'] as String?,
      flow: json['flow'] as String?,
      encryption: json['encryption'] as String? ?? 'none',
      alterId: json['alterId'] as int? ?? 0,
      vmessSecurity: json['vmessSecurity'] as String? ?? 'auto',
      stream: StreamOptions.fromJson(
        Map<String, Object?>.from(json['stream'] as Map? ?? const {}),
      ),
    );
  }

  String get displayName => name.isEmpty ? '$address:$port' : name;

  String get summary {
    final protocolName = switch (protocol) {
      ProxyProtocol.vless => 'VLESS',
      ProxyProtocol.vmess => 'VMess',
      ProxyProtocol.trojan => 'Trojan',
      ProxyProtocol.shadowsocks => 'Shadowsocks',
    };
    final securityName = switch (stream.security) {
      Security.none => null,
      Security.tls => 'TLS',
      Security.reality => 'Reality',
    };
    final transportName = switch (stream.transport) {
      Transport.tcp => 'TCP',
      Transport.ws => 'WebSocket',
      Transport.grpc => 'gRPC',
      Transport.kcp => 'mKCP',
      Transport.httpUpgrade => 'HTTPUpgrade',
      Transport.xhttp => 'XHTTP',
      Transport.h2 => 'HTTP/2',
    };
    final parts = [
      protocolName,
      if (securityName != null) securityName,
      transportName,
    ];
    return parts.join(' ');
  }
}
