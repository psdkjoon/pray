enum DnsProvider { system, cloudflare, google, quad9, custom }

List<String> dnsServers({
  required DnsProvider provider,
  required bool encrypted,
  required String custom,
}) {
  if (provider == DnsProvider.system) return ['localhost'];
  final plain = switch (provider) {
    DnsProvider.system => <String>[],
    DnsProvider.cloudflare => ['1.1.1.1', '1.0.0.1'],
    DnsProvider.google => ['8.8.8.8', '8.8.4.4'],
    DnsProvider.quad9 => ['9.9.9.9', '149.112.112.112'],
    DnsProvider.custom => [
        for (final part in custom.split(RegExp(r'[\s,]+')))
          if (part.isNotEmpty) part,
      ],
  };
  if (plain.isEmpty) return ['1.1.1.1', '8.8.8.8'];
  if (!encrypted) return plain;
  return [
    for (final entry in plain)
      entry.contains('://') ? entry : 'https://$entry/dns-query',
  ];
}
