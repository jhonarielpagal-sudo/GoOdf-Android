// In-memory model of a GrandOrgue organ definition file (.organ).
//
// The format is INI-like: [Section] headers followed by Key=Value lines.
// The model keeps the order of sections and keys, and keeps every key it does
// not understand, so a file can be edited and written back without losing data.

class OdfEntry {
  String key;
  String value;
  OdfEntry(this.key, this.value);
}

class OdfSection {
  String name;
  final List<OdfEntry> entries;

  OdfSection(this.name, {List<OdfEntry>? entries}) : entries = entries ?? [];

  String? get(String key) {
    for (final e in entries) {
      if (e.key == key) return e.value;
    }
    return null;
  }

  bool has(String key) => get(key) != null;

  int getInt(String key, [int fallback = 0]) {
    final v = get(key);
    if (v == null) return fallback;
    return int.tryParse(v.trim()) ?? fallback;
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

  OdfSection clone() => OdfSection(
        name,
        entries: entries.map((e) => OdfEntry(e.key, e.value)).toList(),
      );
}

class OdfDocument {
  final List<OdfSection> sections;

  OdfDocument({List<OdfSection>? sections}) : sections = sections ?? [];

  OdfSection? find(String name) {
    for (final s in sections) {
      if (s.name == name) return s;
    }
    return null;
  }
}
