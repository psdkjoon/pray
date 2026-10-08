abstract class ProxyEndpoint {
  static const String host = '127.0.0.1';
  static const int defaultPort = 8585;

  static String address(int port) => '$host:$port';
}
