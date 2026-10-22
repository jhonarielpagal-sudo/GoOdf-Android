/// In-memory model of a GrandOrgue organ definition file (.organ).
///
/// The format is INI-like: [Section] headers followed by Key=Value lines.
/// The model keeps the order of sections and keys so that a file can be
/// edited and written back without being reshuffled.

class OdfEntry {
  String key;
  String value;
  OdfEntry(this.key, this.value);
}

class OdfSection {
  String name;
  final List<OdfEntry> entries;

  /// Comment or blank lines that appeared before the section header.
  /// Kept so that notes in the original file are not lost.
  final List<String> leadingLines;

  OdfSection(this.name, {List<OdfEntry>? entries, List<String>? leadingLines})
      : entries = entries ?? [],
        leadingLines = leadingLines ?? [];

  String? get(String key) {
    for (final e in entries) {
      if (e.key == key) return e.value;
    }
    return null;
  }

  void set(String key, String value) {
    for (final e in entries) {
      if (e.key == key) {
        e.value = value;
        return;
      }
    }
    entries.add(OdfEntry(key, value));
  }

  void remove(String key) => entries.removeWhere((e) => e.key == key);

  /// Section type without its number: "Stop012" -> "Stop".
  String get type => OdfDocument.typeOf(name);

  /// Section number: "Stop012" -> 12, or null if there is none.
  int? get number => OdfDocument.numberOf(name);

  /// A readable label for lists, using Name/ChurchName when present.
  String get label {
    final n = get('Name') ?? get('ChurchName');
    if (n != null && n.trim().isNotEmpty) return '$name  -  ${n.trim()}';
    return name;
  }
}

class OdfDocument {
  final List<OdfSection> sections;

  /// Lines found before the first section header.
  final List<String> preamble;

  OdfDocument({List<OdfSection>? sections, List<String>? preamble})
      : sections = sections ?? [],
        preamble = preamble ?? [];

  static final RegExp _numberedName = RegExp(r'^(.*?)(\d+)$');

  static String typeOf(String sectionName) {
    final m = _numberedName.firstMatch(sectionName);
    return m == null ? sectionName : m.group(1)!;
  }

  static int? numberOf(String sectionName) {
    final m = _numberedName.firstMatch(sectionName);
    return m == null ? null : int.tryParse(m.group(2)!);
  }

  OdfSection? find(String name) {
    for (final s in sections) {
      if (s.name == name) return s;
    }
    return null;
  }

  /// Distinct section types in the order they first appear.
  List<String> get types {
    final seen = <String>[];
    for (final s in sections) {
      if (!seen.contains(s.type)) seen.add(s.type);
    }
    return seen;
  }

  List<OdfSection> ofType(String type) =>
      sections.where((s) => s.type == type).toList();

  /// Adds a new section of [type] with the next free number
  /// (padded to 3 digits, e.g. Stop013). Returns the new section.
  OdfSection addNumbered(String type, {int pad = 3}) {
    var max = 0;
    var lastIndex = -1;
    for (var i = 0; i < sections.length; i++) {
      final s = sections[i];
      if (s.type == type && s.number != null) {
        if (s.number! > max) max = s.number!;
        lastIndex = i;
      }
    }
    final next = max + 1;
    final section = OdfSection('$type${next.toString().padLeft(pad, '0')}');
    if (lastIndex >= 0) {
      sections.insert(lastIndex + 1, section);
    } else {
      sections.add(section);
    }
    return section;
  }

  void removeSection(OdfSection s) => sections.remove(s);
}
