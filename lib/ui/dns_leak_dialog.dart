import 'package:flutter/material.dart' hide Text, Icon;
import 'package:pray/core/dns_leak_test.dart';
import 'package:pray/localization/localization.dart';
import 'package:pray/theme/app_spacing.dart';

class DnsLeakDialog extends StatefulWidget {
  const DnsLeakDialog({super.key});

  @override
  State<DnsLeakDialog> createState() => _DnsLeakDialogState();
}

class _DnsLeakDialogState extends State<DnsLeakDialog> {
  late Future<DnsLeakResult> _future = DnsLeakTest.run();

  void _retry() => setState(() => _future = DnsLeakTest.run());

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('DNS leak test'),
      content: SizedBox(
        width: 360,
        child: FutureBuilder<DnsLeakResult>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                child: Row(
                  spacing: AppSpacing.md,
                  children: [
                    SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                    Expanded(child: Text('Testing…')),
                  ],
                ),
              );
            }
            if (snapshot.hasError) {
              return const Text('The test failed. Check your connection.');
            }
            final result = snapshot.requireData;
            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: AppSpacing.md,
                children: [
                  if (result.ip != null)
                    _Line(
                      label: 'Your IP',
                      value: result.ip!,
                      note: result.ipCountry,
                    ),
                  Text(
                    result.servers.isEmpty
                        ? 'No DNS servers were reported.'
                        : 'DNS servers that answered',
                    style: theme.textTheme.titleMedium,
                  ),
                  for (final server in result.servers)
                    _Line(
                      value: server.ip,
                      note: [
                        if (server.country != null) server.country!,
                        if (server.provider != null) server.provider!,
                      ].join(' · '),
                    ),
                  if (result.conclusion != null && result.conclusion!.isNotEmpty)
                    Text(
                      result.conclusion!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(onPressed: _retry, child: const Text('Run again')),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.value, this.label, this.note});

  final String? label;
  final String value;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null)
          Text(
            label!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        SelectableText(value, style: theme.textTheme.bodyMedium),
        if (note != null && note!.isNotEmpty)
          Text(
            note!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}
