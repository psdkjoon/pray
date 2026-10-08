import 'package:flutter/material.dart' hide Text;
import 'package:pray/localization/localization.dart';
import 'package:pray/core/qr/qr_code.dart';

class QrView extends StatelessWidget {
  const QrView({required this.data, this.size = 260, super.key});

  final String data;
  final double size;

  @override
  Widget build(BuildContext context) {
    final QrCode code;
    try {
      code = QrCode.encode(data);
    } on FormatException {
      return SizedBox.square(
        dimension: size,
        child: const Center(child: Text('Too long for a QR code')),
      );
    }
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _QrPainter(code)),
    );
  }
}

class _QrPainter extends CustomPainter {
  _QrPainter(this.code);

  final QrCode code;

  static const _quiet = 4;

  @override
  void paint(Canvas canvas, Size size) {
    final modules = code.size + _quiet * 2;
    final cell = size.width / modules;
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
    final paint = Paint()
      ..color = Colors.black
      ..isAntiAlias = false;
    for (var y = 0; y < code.size; y++) {
      for (var x = 0; x < code.size; x++) {
        if (!code.isDark(x, y)) continue;
        canvas.drawRect(
          Rect.fromLTWH(
            (x + _quiet) * cell,
            (y + _quiet) * cell,
            cell + 0.5,
            cell + 0.5,
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_QrPainter oldDelegate) => oldDelegate.code != code;
}
