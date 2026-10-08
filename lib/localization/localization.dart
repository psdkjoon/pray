import 'dart:ui' as ui;

import 'package:flutter/widgets.dart' as w;
import 'package:pray/localization/strings_fa.dart';
import 'package:pray/localization/strings_id.dart';
import 'package:pray/localization/strings_ja.dart';
import 'package:pray/localization/strings_ru.dart';
import 'package:pray/localization/strings_zh.dart';

class Language {
  const Language(this.code, this.name, this.english);

  final String code;
  final String name;
  final String english;
}

class L10n {
  const L10n._();

  static const languages = <Language>[
    Language('en', 'English', 'English'),
    Language('fa', 'فارسی', 'Persian'),
    Language('ru', 'Русский', 'Russian'),
    Language('id', 'Bahasa Indonesia', 'Indonesian'),
    Language('zh', '中文', 'Chinese'),
    Language('ja', '日本語', 'Japanese'),
  ];

  static const system = 'system';

  static String code = 'en';

  static const _tables = <String, Map<String, String>>{
    'fa': stringsFa,
    'ru': stringsRu,
    'id': stringsId,
    'zh': stringsZh,
    'ja': stringsJa,
  };

  static final _patterns = <String, List<_Pattern>>{};

  static String resolve(String setting) {
    final wanted = setting == system
        ? ui.PlatformDispatcher.instance.locale.languageCode
        : setting;
    for (final language in languages) {
      if (language.code == wanted) return wanted;
    }
    return 'en';
  }

  static w.Locale get locale => w.Locale(code);

  static bool get rtl => code == 'fa';

  static String tr(String text) {
    final table = _tables[code];
    if (table == null || text.isEmpty) return text;
    final exact = table[text];
    if (exact != null) return exact;
    if (text.contains('\n\n')) {
      return text.split('\n\n').map(tr).join('\n\n');
    }
    const lock = ' — disconnect to change';
    if (text.endsWith(lock)) {
      final head = text.substring(0, text.length - lock.length);
      return '${tr(head)}${table[lock] ?? lock}';
    }
    for (final pattern in _patternsFor(table)) {
      final match = pattern.regex.firstMatch(text);
      if (match == null) continue;
      var out = pattern.template;
      for (var i = 1; i <= match.groupCount; i++) {
        out = out.replaceFirst('{}', tr(match.group(i)!));
      }
      return out;
    }
    return text;
  }

  static List<_Pattern> _patternsFor(Map<String, String> table) {
    return _patterns.putIfAbsent(code, () {
      final list = <_Pattern>[];
      for (final entry in table.entries) {
        if (!entry.key.contains('{}')) continue;
        final source = entry.key
            .split('{}')
            .map(RegExp.escape)
            .join('(.+?)');
        list.add(_Pattern(RegExp('^$source\$'), entry.value));
      }
      return list;
    });
  }

  static String wrap(String text, {int width = 42}) {
    final lines = <String>[];
    for (final paragraph in text.split('\n')) {
      var line = StringBuffer();
      var used = 0;
      var lastSpace = -1;
      var lastSpaceUsed = 0;
      for (final rune in paragraph.runes) {
        final char = String.fromCharCode(rune);
        final size = rune >= 0x2E80 ? 2 : 1;
        if (used + size > width) {
          final current = line.toString();
          if (lastSpace > 0) {
            lines.add(current.substring(0, lastSpace));
            final rest = current.substring(lastSpace + 1);
            line = StringBuffer(rest);
            used = used - lastSpaceUsed - 1;
          } else {
            lines.add(current);
            line = StringBuffer();
            used = 0;
          }
          lastSpace = -1;
        }
        if (rune == 0x20) {
          lastSpace = line.length;
          lastSpaceUsed = used;
        }
        line.write(char);
        used += size;
      }
      lines.add(line.toString());
    }
    return lines.join('\n');
  }
}

class _Pattern {
  const _Pattern(this.regex, this.template);

  final RegExp regex;
  final String template;
}

extension TrString on String {
  String get tr => L10n.tr(this);
}

class Text extends w.StatelessWidget {
  const Text(
    this.data, {
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.softWrap,
    super.key,
  });

  final String data;
  final w.TextStyle? style;
  final w.TextAlign? textAlign;
  final int? maxLines;
  final w.TextOverflow? overflow;
  final bool? softWrap;

  @override
  w.Widget build(w.BuildContext context) {
    return w.Text(
      L10n.tr(data),
      style: style,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
      softWrap: softWrap,
    );
  }
}

class Icon extends w.StatelessWidget {
  const Icon(
    this.icon, {
    this.size,
    this.color,
    this.semanticLabel,
    super.key,
  });

  final w.IconData? icon;
  final double? size;
  final w.Color? color;
  final String? semanticLabel;

  @override
  w.Widget build(w.BuildContext context) {
    return w.Icon(
      icon,
      size: size,
      color: color,
      semanticLabel: semanticLabel,
      textDirection: w.TextDirection.ltr,
    );
  }
}
