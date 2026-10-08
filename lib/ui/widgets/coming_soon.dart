import 'package:flutter/material.dart' hide Text;
import 'package:pray/localization/localization.dart';

void showComingSoon(BuildContext context, String what) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('$what arrives with the Xray core.')),
  );
}
