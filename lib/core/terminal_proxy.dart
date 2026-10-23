import 'dart:io';

abstract class TerminalProxy {
  static const host = '127.0.0.1';
  static const _noProxy = 'localhost,127.0.0.0/8,::1';

  static String proxychainsConfig(int port) => '''
strict_chain
quiet_mode
proxy_dns
remote_dns_subnet 224
tcp_read_time_out 15000
tcp_connect_time_out 8000
localnet 127.0.0.0/255.0.0.0

[ProxyList]
socks5 $host $port
''';

  static String shellEnv(int port) => '''
export ALL_PROXY=socks5h://$host:$port
export all_proxy=socks5h://$host:$port
export HTTP_PROXY=http://$host:$port
export http_proxy=http://$host:$port
export HTTPS_PROXY=http://$host:$port
export https_proxy=http://$host:$port
export NO_PROXY=$_noProxy
export no_proxy=$_noProxy
''';

  static String fishEnv(int port) => '''
set -gx ALL_PROXY socks5h://$host:$port
set -gx all_proxy socks5h://$host:$port
set -gx HTTP_PROXY http://$host:$port
set -gx http_proxy http://$host:$port
set -gx HTTPS_PROXY http://$host:$port
set -gx https_proxy http://$host:$port
set -gx NO_PROXY $_noProxy
set -gx no_proxy $_noProxy
''';

  static String? get directory {
    final env = Platform.environment;
    final config = env['XDG_CONFIG_HOME'];
    if (config != null && config.trim().isNotEmpty) return '$config/pray';
    final home = env['HOME'];
    if (home == null || home.trim().isEmpty) return null;
    return '$home/.config/pray';
  }

  static String? get proxychainsPath =>
      directory == null ? null : '$directory/proxychains.conf';
  static String? get shellEnvPath =>
      directory == null ? null : '$directory/proxy.env';
  static String? get fishEnvPath =>
      directory == null ? null : '$directory/proxy.fish';

  static String proxychainsCommand() =>
      'proxychains4 -f ${proxychainsPath ?? '~/.config/pray/proxychains.conf'} ';

  static String shellCommand() =>
      'source ${shellEnvPath ?? '~/.config/pray/proxy.env'}';

  static String fishCommand() =>
      'source ${fishEnvPath ?? '~/.config/pray/proxy.fish'}';

  static Future<bool> write(int port) async {
    if (!Platform.isLinux) return false;
    final dir = directory;
    if (dir == null) return false;
    try {
      await Directory(dir).create(recursive: true);
      await File('$dir/proxychains.conf')
          .writeAsString(proxychainsConfig(port), flush: true);
      await File('$dir/proxy.env')
          .writeAsString(shellEnv(port), flush: true);
      await File('$dir/proxy.fish')
          .writeAsString(fishEnv(port), flush: true);
      return true;
    } on Object {
      return false;
    }
  }
}
