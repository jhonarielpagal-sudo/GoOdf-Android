import 'dart:convert';
import 'dart:typed_data';

import 'odf_model.dart';

/// Parses and writes GrandOrgue .organ files.
///
///  - a line like `[Name]` opens a section
///  - `Key=Value` lines belong to the current section
///  - lines starting with `;` or `#` are comments and are dropped
///  - whitespace around keys and values is trimmed
///  - values are kept exactly as written (no inline comment stripping)
class OdfParser {
  /// UTF-8 if the bytes are valid UTF-8, otherwise Latin-1 (older files).
  static String decode(Uint8List bytes) {
    try {
      return utf8.decode(bytes);
    } on FormatException {
      return latin1.decode(bytes);
    }
  }

  static OdfDocument parse(String text) {
    if (text.isNotEmpty && text.codeUnitAt(0) == 0xFEFF) {
      text = text.substring(1);
    }
    final lines =
        text.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n');

    final doc = OdfDocument();
    OdfSection? current;

    for (final raw in lines) {
      final line = raw.trim();
      if (line.isEmpty) continue;

      if (line.startsWith('[') && line.endsWith(']') && line.length > 2) {
        current = OdfSection(line.substring(1, line.length - 1).trim());
        doc.sections.add(current);
        continue;
      }

      if (line.startsWith(';') || line.startsWith('#')) continue;
      if (current == null) continue;

      final eq = line.indexOf('=');
      if (eq <= 0) continue;
      current.entries.add(OdfEntry(
        line.substring(0, eq).trim(),
        line.substring(eq + 1).trim(),
      ));
    }
    return doc;
  }
}

class OdfWriter {
  static String write(OdfDocument doc) {
    final b = StringBuffer();
    for (var i = 0; i < doc.sections.length; i++) {
      final s = doc.sections[i];
      b.writeln('[${s.name}]');
      for (final e in s.entries) {
        b.writeln('${e.key}=${e.value}');
      }
      if (i != doc.sections.length - 1) b.writeln();
    }
    return b.toString();
  }
}
