import 'dart:convert';

import 'package:xray_config/src/models.dart';

enum RoutingProfile { global, bypassLan, bypassIran }

enum RuleAction { proxy, direct, block }

class CustomRule {
  const CustomRule({required this.value, required this.action});

  final String value;
  final RuleAction action;

  bool get isIp {
    if (value.startsWith('geoip:')) return true;
    final host = value.split('/').first;
    return _isIPv4(host) || _isIPv6(host);
  }

  bool get needsGeoData =>
      value.startsWith('geoip:') || value.startsWith('geosite:');

  Map<String, Object?> toRule({String proxyTag = 'proxy'}) {
    final tag = switch (action) {
      RuleAction.proxy => proxyTag,
      RuleAction.direct => 'direct',
      RuleAction.block => 'block',
    };
    return {
      'type': 'field',
      if (isIp)
        'ip': [value]
      else
        'domain': [value.contains(':') ? value : 'domain:$value'],
      'outboundTag': tag,
    };
  }

  String encode() => '${action.name}|$value';

  static CustomRule? decode(String text) {
    final index = text.indexOf('|');
    if (index < 0) return null;
    final name = text.substring(0, index);
    final value = text.substring(index + 1);
    for (final action in RuleAction.values) {
      if (action.name == name && value.isNotEmpty) {
        return CustomRule(value: value, action: action);
      }
    }
    return null;
  }
}

enum WarpMode { off, standalone, afterProxy, selective }

class WarpConfig {
  const WarpConfig({
    required this.secretKey,
    required this.publicKey,
    required this.address4,
    required this.address6,
    required this.reserved,
    this.endpoint = '162.159.192.1:2408',
    this.mtu = 1280,
  });

  final String secretKey;
  final String publicKey;
  final String address4;
  final String address6;
  final List<int> reserved;
  final String endpoint;
  final int mtu;

  Map<String, Object?> toOutbound({int? mark, bool viaProxy = false}) {
    return {
      'tag': 'warp',
      'protocol': 'wireguard',
      'settings': {
        'secretKey': secretKey,
        'address': ['$address4/32', if (address6.isNotEmpty) '$address6/128'],
        'peers': [
          {
            'publicKey': publicKey,
            'allowedIPs': ['0.0.0.0/0', '::/0'],
            'endpoint': endpoint,
          },
        ],
        'mtu': mtu,
        if (reserved.length == 3) 'reserved': reserved,
      },
      if (mark != null || viaProxy)
        'streamSettings': {
          'sockopt': {
            if (mark != null) 'mark': mark,
            if (viaProxy) 'dialerProxy': 'proxy',
          },
        },
    };
  }
}

class XrayConfigOptions {
  const XrayConfigOptions({
    required this.mixedPort,
    this.routing = RoutingProfile.bypassLan,
    this.blockAds = false,
    this.geoDataAvailable = false,
    this.allowLan = false,
    this.tunMode = false,
    this.tunSystemRoutes = false,
    this.socketMark,
    this.statsApiPort,
    this.logLevel = 'warning',
    this.remoteDns = const ['1.1.1.1', '8.8.8.8'],
    this.fakeDns = false,
    this.customRules = const [],
    this.blockDomains = const [],
    this.warp,
    this.warpMode = WarpMode.off,
    this.warpDomains = const [],
  });

  final int mixedPort;
  final RoutingProfile routing;
  final bool blockAds;

  final bool geoDataAvailable;

  final bool allowLan;

  final bool tunMode;

  final bool tunSystemRoutes;

  final int? socketMark;

  final int? statsApiPort;
  final String logLevel;
  final List<String> remoteDns;
  final bool fakeDns;
  final List<CustomRule> customRules;
  final List<String> blockDomains;
  final WarpConfig? warp;
  final WarpMode warpMode;
  final List<String> warpDomains;

  bool get _warpActive => warp != null && warpMode != WarpMode.off;

  bool get warpIsDefault =>
      _warpActive &&
      (warpMode == WarpMode.standalone || warpMode == WarpMode.afterProxy);

  String get proxyTag => warpIsDefault ? 'warp' : 'proxy';
}

Map<String, Object?> buildXrayConfig(
  ProxyServer? server,
  XrayConfigOptions options,
) {
  final listen = options.allowLan ? '0.0.0.0' : '127.0.0.1';
  final apiPort = options.statsApiPort;
  final mark = options.socketMark;
  final sniffing = <String, Object?>{
    'enabled': true,
    'destOverride': ['http', 'tls', 'quic', if (options.fakeDns) 'fakedns'],
    'routeOnly': !options.fakeDns,
  };

  return {
    'log': {'loglevel': options.logLevel},
    if (apiPort != null) ...{
      'stats': <String, Object?>{},
      'api': {
        'tag': 'api',
        'services': ['StatsService'],
      },
      'policy': {
        'system': {
          'statsOutboundUplink': true,
          'statsOutboundDownlink': true,
        },
      },
    },
    'dns': _dns(server, options),
    if (options.fakeDns)
      'fakedns': [
        {'ipPool': '198.18.0.0/15', 'poolSize': 65535},
      ],
    'inbounds': [
      {
        'tag': 'mixed-in',
        'listen': listen,
        'port': options.mixedPort,
        'protocol': 'socks',
        'settings': {'auth': 'noauth', 'udp': true},
        'sniffing': sniffing,
      },
      if (options.tunMode)
        {
          'tag': 'tun-in',
          'protocol': 'tun',
          'settings': {
            'name': 'xray0',
            'mtu': 1500,
            if (options.tunSystemRoutes) ...{
              'gateway': ['10.0.0.1/16'],
            },
          },
          'sniffing': sniffing,
        },
      if (apiPort != null)
        {
          'tag': 'api-in',
          'listen': '127.0.0.1',
          'port': apiPort,
          'protocol': 'dokodemo-door',
          'settings': {'address': '127.0.0.1'},
        },
    ],
    'outbounds': [
      if (options.warpIsDefault)
        options.warp!.toOutbound(
          mark: mark,
          viaProxy: options.warpMode == WarpMode.afterProxy,
        ),
      if (server != null) _proxyOutbound(server, mark),
      if (options._warpActive && !options.warpIsDefault)
        options.warp!.toOutbound(mark: mark, viaProxy: server != null),
      {
        'tag': 'direct',
        'protocol': 'freedom',
        if (mark != null)
          'streamSettings': {
            'sockopt': {'mark': mark},
          },
      },
      {'tag': 'block', 'protocol': 'blackhole'},
    ],
    'routing': {
      'domainStrategy':
          options.routing == RoutingProfile.global ? 'AsIs' : 'IPIfNonMatch',
      'rules': _rules(options),
    },
  };
}

String buildXrayConfigJson(
  ProxyServer? server,
  XrayConfigOptions options, {
  bool pretty = false,
}) {
  final config = buildXrayConfig(server, options);
  return pretty
      ? const JsonEncoder.withIndent('  ').convert(config)
      : jsonEncode(config);
}

Map<String, Object?> _dns(ProxyServer? server, XrayConfigOptions options) {
  return {
    'servers': [
      if (server != null && !_isIpAddress(server.address))
        {
          'address': 'localhost',
          'domains': ['full:${server.address}'],
        },
      if (options.routing == RoutingProfile.bypassIran)
        {
          'address': 'localhost',
          'domains': [
            r'regexp:\.ir$',
            if (options.geoDataAvailable) 'geosite:category-ir',
          ],
        },
      if (options.fakeDns) 'fakedns',
      ...options.remoteDns,
    ],
    'queryStrategy': 'UseIP',
  };
}

bool _isIpAddress(String host) => _isIPv4(host) || _isIPv6(host);

bool _isIPv4(String host) {
  try {
    Uri.parseIPv4Address(host);
    return true;
  } on FormatException {
    return false;
  }
}

bool _isIPv6(String host) {
  try {
    Uri.parseIPv6Address(host);
    return true;
  } on FormatException {
    return false;
  }
}

const _privateRanges = [
  '0.0.0.0/8',
  '10.0.0.0/8',
  '100.64.0.0/10',
  '127.0.0.0/8',
  '169.254.0.0/16',
  '172.16.0.0/12',
  '192.168.0.0/16',
  '224.0.0.0/4',
  '::1/128',
  'fc00::/7',
  'fe80::/10',
];

List<Map<String, Object?>> _rules(XrayConfigOptions options) {
  final geo = options.geoDataAvailable;
  final Map<String, Object?> lanIp = {
    'type': 'field',
    'ip': geo ? ['geoip:private'] : _privateRanges,
    'outboundTag': 'direct',
  };
  const Map<String, Object?> lanDomain = {
    'type': 'field',
    'domain': ['full:localhost'],
    'outboundTag': 'direct',
  };
  final apiPort = options.statsApiPort;
  final warpDomains = options._warpActive &&
          options.warpMode == WarpMode.selective
      ? [
          for (final d in options.warpDomains)
            if (geo || !d.startsWith('geosite:'))
              d.contains(':') ? d : 'domain:$d',
        ]
      : const <String>[];

  return [
    if (apiPort != null)
      {
        'type': 'field',
        'inboundTag': ['api-in'],
        'outboundTag': 'api',
      },
    if (options.blockAds && geo)
      {
        'type': 'field',
        'domain': ['geosite:category-ads-all'],
        'outboundTag': 'block',
      },
    if (options.blockDomains.isNotEmpty)
      {
        'type': 'field',
        'domain': [for (final d in options.blockDomains) 'domain:$d'],
        'outboundTag': 'block',
      },
    for (final rule in options.customRules)
      if (geo || !rule.needsGeoData) rule.toRule(proxyTag: options.proxyTag),
    if (warpDomains.isNotEmpty)
      {
        'type': 'field',
        'domain': warpDomains,
        'outboundTag': 'warp',
      },
    ...switch (options.routing) {
      RoutingProfile.global => const <Map<String, Object?>>[],
      RoutingProfile.bypassLan => <Map<String, Object?>>[lanIp, lanDomain],
      RoutingProfile.bypassIran => <Map<String, Object?>>[
          lanIp,
          lanDomain,
          {
            'type': 'field',
            'domain': [
              r'regexp:\.ir$',
              if (geo) 'geosite:category-ir',
            ],
            'outboundTag': 'direct',
          },
          if (geo)
            {
              'type': 'field',
              'ip': ['geoip:ir'],
              'outboundTag': 'direct',
            },
        ],
    },
  ];
}

Map<String, Object?> _proxyOutbound(ProxyServer server, int? mark) {
  final protocol = switch (server.protocol) {
    ProxyProtocol.vless => 'vless',
    ProxyProtocol.vmess => 'vmess',
    ProxyProtocol.trojan => 'trojan',
    ProxyProtocol.shadowsocks => 'shadowsocks',
  };
  return {
    'tag': 'proxy',
    'protocol': protocol,
    'settings': _outboundSettings(server),
    'streamSettings': _streamSettings(server.stream, mark),
  };
}

Map<String, Object?> _outboundSettings(ProxyServer s) {
  return switch (s.protocol) {
    ProxyProtocol.vless => {
        'vnext': [
          {
            'address': s.address,
            'port': s.port,
            'users': [
              {
                'id': s.id,
                'encryption': s.encryption,
                if (s.flow != null) 'flow': s.flow,
              },
            ],
          },
        ],
      },
    ProxyProtocol.vmess => {
        'vnext': [
          {
            'address': s.address,
            'port': s.port,
            'users': [
              {'id': s.id, 'alterId': s.alterId, 'security': s.vmessSecurity},
            ],
          },
        ],
      },
    ProxyProtocol.trojan => {
        'servers': [
          {'address': s.address, 'port': s.port, 'password': s.password},
        ],
      },
    ProxyProtocol.shadowsocks => {
        'servers': [
          {
            'address': s.address,
            'port': s.port,
            'method': s.method,
            'password': s.password,
          },
        ],
      },
  };
}

Map<String, Object?> _streamSettings(StreamOptions s, int? mark) {
  final network = switch (s.transport) {
    Transport.tcp => 'tcp',
    Transport.ws => 'ws',
    Transport.grpc => 'grpc',
    Transport.kcp => 'kcp',
    Transport.httpUpgrade => 'httpupgrade',
    Transport.xhttp => 'xhttp',
    Transport.h2 => 'h2',
  };
  final security = switch (s.security) {
    Security.none => 'none',
    Security.tls => 'tls',
    Security.reality => 'reality',
  };
  return {
    'network': network,
    'security': security,
    if (s.security == Security.tls)
      'tlsSettings': {
        if (s.sni != null) 'serverName': s.sni,
        if (s.fingerprint != null) 'fingerprint': s.fingerprint,
        if (s.alpn.isNotEmpty) 'alpn': s.alpn,
        if (s.allowInsecure) 'allowInsecure': true,
      },
    if (s.security == Security.reality)
      'realitySettings': {
        if (s.sni != null) 'serverName': s.sni,
        'fingerprint': s.fingerprint ?? 'chrome',
        'publicKey': s.publicKey,
        'shortId': s.shortId ?? '',
        if (s.spiderX != null) 'spiderX': s.spiderX,
      },
    ..._transportSettings(s),
    if (mark != null) 'sockopt': {'mark': mark},
  };
}

Map<String, Object?> _transportSettings(StreamOptions s) {
  final host = s.host;
  final authority = s.authority;
  final seed = s.seed;
  final mode = s.xhttpMode;
  final path = s.path ?? '/';

  return switch (s.transport) {
    Transport.tcp => s.headerType == 'http'
        ? {
            'tcpSettings': {
              'header': {
                'type': 'http',
                'request': {
                  'path': [path],
                  'headers': {
                    'Host': [if (host != null) ...host.split(',')],
                  },
                },
              },
            },
          }
        : const <String, Object?>{},
    Transport.ws => {
        'wsSettings': {
          'path': path,
          if (host != null) 'headers': {'Host': host},
        },
      },
    Transport.grpc => {
        'grpcSettings': {
          'serviceName': s.serviceName ?? '',
          'multiMode': s.grpcMultiMode,
          if (authority != null) 'authority': authority,
        },
      },
    Transport.kcp => {
        'kcpSettings': {
          'header': {'type': s.headerType ?? 'none'},
          if (seed != null) 'seed': seed,
        },
      },
    Transport.httpUpgrade => {
        'httpupgradeSettings': {
          'path': path,
          if (host != null) 'host': host,
        },
      },
    Transport.xhttp => {
        'xhttpSettings': {
          'path': path,
          if (host != null) 'host': host,
          if (mode != null) 'mode': mode,
        },
      },
    Transport.h2 => {
        'httpSettings': {
          'path': path,
          if (host != null) 'host': host.split(','),
        },
      },
  };
}
