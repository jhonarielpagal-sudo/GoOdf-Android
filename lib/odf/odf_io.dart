import 'odf_model.dart';

/// Parses and writes GrandOrgue .organ files.
///
/// Parsing rules follow GrandOrgue's own reader:
///  - lines starting with `[` and ending with `]` open a new section
///  - `Key=Value` lines belong to the current section
///  - `;` and `#` start comment lines
///  - whitespace around keys and values is trimmed
///  - an inline `;` comment after a value is stripped (same as GoOdf does)
class OdfParser {
  static OdfDocument parse(String text) {
    // Remove BOM, normalise line endings.
    if (text.isNotEmpty && text.codeUnitAt(0) == 0xFEFF) {
      text = text.substring(1);
    }
    final lines = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n');

    final doc = OdfDocument();
    OdfSection? current;
    var pending = <String>[];

    for (final raw in lines) {
      final line = raw.trim();

      if (line.startsWith('[') && line.endsWith(']') && line.length > 2) {
        current = OdfSection(
          line.substring(1, line.length - 1).trim(),
          leadingLines: pending,
        );
        pending = <String>[];
        doc.sections.add(current);
        continue;
      }

      if (line.isEmpty || line.startsWith(';') || line.startsWith('#')) {
        // Keep comments, but drop plain blank lines; the writer adds its own.
        if (line.isNotEmpty) pending.add(line);
        continue;
      }

      final eq = line.indexOf('=');
      if (eq <= 0) continue; // not a key/value line, ignore

      final key = line.substring(0, eq).trim();
      var value = line.substring(eq + 1);
      final semi = value.indexOf(';');
      if (semi >= 0) value = value.substring(0, semi);
      value = value.trim();

      if (current == null) {
        // Key/value before any section: ignore, GrandOrgue does the same.
        continue;
      }
      current.entries.add(OdfEntry(key, value));
    }

    if (current == null) {
      doc.preamble.addAll(pending);
    } else if (pending.isNotEmpty) {
      // Trailing comments at the end of the file go to the last section's
      // lines via the preamble list of a synthetic holder: keep it simple and
      // append them to the document preamble so they are not lost.
      doc.preamble.addAll(pending);
    }
    return doc;
  }
}

class OdfWriter {
  static String write(OdfDocument doc) {
    final b = StringBuffer();

    for (final l in doc.preamble) {
      b.writeln(l);
    }
    if (doc.preamble.isNotEmpty) b.writeln();

    for (var i = 0; i < doc.sections.length; i++) {
      final s = doc.sections[i];
      for (final l in s.leadingLines) {
        b.writeln(l);
      }
      b.writeln('[${s.name}]');
      for (final e in s.entries) {
        b.writeln('${e.key}=${e.value}');
      }
      if (i != doc.sections.length - 1) b.writeln();
    }
    return b.toString();
  }
}
