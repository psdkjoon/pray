import 'package:flutter/material.dart' hide Text, Icon;
import 'package:pray/localization/localization.dart';
import 'package:pray/platform/android_vpn.dart';
import 'package:pray/theme/app_spacing.dart';

Future<List<String>?> showAppPicker(
  BuildContext context,
  List<String> selected,
) {
  return showDialog<List<String>>(
    context: context,
    builder: (_) => Dialog.fullscreen(child: _AppPicker(selected: selected)),
  );
}

class _AppPicker extends StatefulWidget {
  const _AppPicker({required this.selected});

  final List<String> selected;

  @override
  State<_AppPicker> createState() => _AppPickerState();
}

class _AppPickerState extends State<_AppPicker> {
  late final Set<String> _chosen = {...widget.selected};
  List<AndroidApp>? _apps;
  String _query = '';

  @override
  void initState() {
    super.initState();
    AndroidVpn.listApps().then((apps) {
      if (mounted) setState(() => _apps = apps);
    });
  }

  @override
  Widget build(BuildContext context) {
    final apps = _apps;
    final visible = apps == null
        ? const <AndroidApp>[]
        : [
            for (final app in apps)
              if (app.label.toLowerCase().contains(_query.toLowerCase()) ||
                  app.package.toLowerCase().contains(_query.toLowerCase()))
                app,
          ];
    return Scaffold(
      appBar: AppBar(
        title: Text('Apps (${_chosen.length})'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(_chosen.toList()),
            child: const Text('Done'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: TextField(
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search_rounded),
                hintText: 'Search'.tr,
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          Expanded(
            child: apps == null
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: visible.length,
                    itemBuilder: (context, index) {
                      final app = visible[index];
                      return CheckboxListTile(
                        title: Text(app.label),
                        subtitle: Text(app.package),
                        value: _chosen.contains(app.package),
                        onChanged: (value) => setState(() {
                          if (value ?? false) {
                            _chosen.add(app.package);
                          } else {
                            _chosen.remove(app.package);
                          }
                        }),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
