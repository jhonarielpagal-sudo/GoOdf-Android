// Reference-aware operations on an [OdfDocument]: listing, adding, deleting
// (with renumbering), counting, validating and importing from another file.
//
// GrandOrgue numbers sections globally (Stop001, Stop002, ...) and refers to
// them by number (Manual001 has Stop001=010, which means section [Stop010]).
// Deleting a section therefore has to renumber the later sections and fix every
// reference to them. That is what this file does.

import 'odf_model.dart';

String pad3(int n) => n.toString().padLeft(3, '0');

const List<String> kTopTypes = [
  'Manual',
  'Stop',
  'Rank',
  'Coupler',
  'Switch',
  'Tremulant',
  'WindchestGroup',
  'Enclosure',
  'ReversiblePiston',
  'DivisionalCoupler',
  'General',
  'Panel',
];

final RegExp _topRe = RegExp(r'^([A-Za-z]+?)(\d+)$');

String? topTypeOf(String name) {
  final m = _topRe.firstMatch(name);
  if (m == null) return null;
  final t = m.group(1)!;
  return kTopTypes.contains(t) ? t : null;
}

int? topNumberOf(String name) {
  if (topTypeOf(name) == null) return null;
  final m = _topRe.firstMatch(name);
  return m == null ? null : int.tryParse(m.group(2)!);
}

extension OdfSectionX on OdfSection {
  String? get topType => topTypeOf(name);
  int? get topNumber => topNumberOf(name);

  /// A readable label for lists and trees.
  String get label {
    final n = get('Name') ?? get('ChurchName');
    if (n != null && n.trim().isNotEmpty) return n.trim();
    return name;
  }
}

/// A list of references from one kind of section to another, stored as
/// `<count key>=N` followed by `<item key>001=..`, `<item key>002=..` and so on.
class RefSpec {
  final String ownerType;
  final String countKey;
  final String itemKey;
  final String targetType;

  /// Per-item suffix keys, e.g. Rank001FirstPipeNumber.
  final List<String> extras;

  const RefSpec(this.ownerType, this.countKey, this.itemKey, this.targetType,
      [this.extras = const []]);
}

/// A single reference stored in one key, e.g. Rank.WindchestGroup=005.
class SingleRef {
  final String ownerType;
  final String key;
  final String targetType;
  const SingleRef(this.ownerType, this.key, this.targetType);
}

const List<String> kRankExtras = [
  'FirstPipeNumber',
  'FirstAccessibleKeyNumber',
  'PipeCount',
];

final List<RefSpec> kRefs = _buildRefs();

List<RefSpec> _buildRefs() {
  final r = <RefSpec>[
    const RefSpec('Manual', 'NumberOfStops', 'Stop', 'Stop'),
    const RefSpec('Manual', 'NumberOfCouplers', 'Coupler', 'Coupler'),
    const RefSpec('Manual', 'NumberOfSwitches', 'Switch', 'Switch'),
    const RefSpec('Manual', 'NumberOfTremulants', 'Tremulant', 'Tremulant'),
    const RefSpec('Stop', 'NumberOfRanks', 'Rank', 'Rank', kRankExtras),
    const RefSpec('Stop', 'SwitchCount', 'Switch', 'Switch'),
    const RefSpec('Coupler', 'SwitchCount', 'Switch', 'Switch'),
    const RefSpec('Tremulant', 'SwitchCount', 'Switch', 'Switch'),
    const RefSpec(
        'WindchestGroup', 'NumberOfEnclosures', 'Enclosure', 'Enclosure'),
    const RefSpec(
        'WindchestGroup', 'NumberOfTremulants', 'Tremulant', 'Tremulant'),
  ];
  const panelLists = <List<String>>[
    ['NumberOfManuals', 'Manual'],
    ['NumberOfEnclosures', 'Enclosure'],
    ['NumberOfTremulants', 'Tremulant'],
    ['NumberOfSwitches', 'Switch'],
    ['NumberOfReversiblePistons', 'ReversiblePiston'],
    ['NumberOfDivisionalCouplers', 'DivisionalCoupler'],
    ['NumberOfGenerals', 'General'],
    ['NumberOfStops', 'Stop'],
    ['NumberOfCouplers', 'Coupler'],
  ];
  for (final p in panelLists) {
    r.add(RefSpec('Panel', p[0], p[1], p[1]));
  }
  return r;
}

const List<SingleRef> kSingleRefs = [
  SingleRef('Rank', 'WindchestGroup', 'WindchestGroup'),
  SingleRef('Stop', 'WindchestGroup', 'WindchestGroup'),
  SingleRef('Coupler', 'DestinationManual', 'Manual'),
];

RefSpec refSpecFor(String ownerType, String countKey) {
  for (final r in kRefs) {
    if (r.ownerType == ownerType && r.countKey == countKey) return r;
  }
  throw ArgumentError('No RefSpec for $ownerType/$countKey');
}

// ---------------------------------------------------------------------------
// Listing
// ---------------------------------------------------------------------------

/// All top-level sections of [type], sorted by number.
List<OdfSection> sectionsOf(OdfDocument d, String type) {
  final r = <OdfSection>[];
  for (final s in d.sections) {
    if (s.topType == type) r.add(s);
  }
  r.sort((a, b) => a.topNumber!.compareTo(b.topNumber!));
  return r;
}

OdfSection? sectionByNumber(OdfDocument d, String type, int n) =>
    d.find('$type${pad3(n)}');

bool hasPedal(OdfDocument d) => d.find('Manual000') != null;

class RefItem {
  int number;
  Map<String, String> extra;
  RefItem(this.number, [Map<String, String>? extra]) : extra = extra ?? {};
}

List<RefItem> readList(OdfSection sec, RefSpec spec) {
  final n = sec.getInt(spec.countKey, 0);
  final items = <RefItem>[];
  for (var i = 1; i <= n; i++) {
    final v = sec.get('${spec.itemKey}${pad3(i)}');
    if (v == null) continue;
    final num = int.tryParse(v.trim());
    if (num == null) continue;
    final ex = <String, String>{};
    for (final e in spec.extras) {
      final ev = sec.get('${spec.itemKey}${pad3(i)}$e');
      if (ev != null) ex[e] = ev;
    }
    items.add(RefItem(num, ex));
  }
  return items;
}

void writeList(OdfSection sec, RefSpec spec, List<RefItem> items) {
  var pattern = '^${RegExp.escape(spec.itemKey)}' r'\d{3}';
  if (spec.extras.isNotEmpty) {
    pattern += '(${spec.extras.map(RegExp.escape).join('|')})?';
  }
  pattern += r'$';
  final re = RegExp(pattern);
  sec.entries.removeWhere((e) => e.key == spec.countKey || re.hasMatch(e.key));
  sec.entries.add(OdfEntry(spec.countKey, items.length.toString()));
  for (var i = 0; i < items.length; i++) {
    final idx = pad3(i + 1);
    sec.entries.add(OdfEntry('${spec.itemKey}$idx', pad3(items[i].number)));
    items[i].extra.forEach((k, v) {
      sec.entries.add(OdfEntry('${spec.itemKey}$idx$k', v));
    });
  }
}

/// Appends a reference to [target] if it is not already in the list.
void addRef(OdfSection owner, RefSpec spec, int target,
    [Map<String, String>? extra]) {
  final items = readList(owner, spec);
  if (items.any((i) => i.number == target)) return;
  items.add(RefItem(target, extra));
  writeList(owner, spec, items);
}

void removeRef(OdfSection owner, RefSpec spec, int target) {
  final items = readList(owner, spec);
  items.removeWhere((i) => i.number == target);
  writeList(owner, spec, items);
}

// ---------------------------------------------------------------------------
// Counts
// ---------------------------------------------------------------------------

const List<List<String>> kOrganCounts = [
  ['NumberOfManuals', 'Manual'],
  ['NumberOfEnclosures', 'Enclosure'],
  ['NumberOfTremulants', 'Tremulant'],
  ['NumberOfWindchestGroups', 'WindchestGroup'],
  ['NumberOfReversiblePistons', 'ReversiblePiston'],
  ['NumberOfGenerals', 'General'],
  ['NumberOfDivisionalCouplers', 'DivisionalCoupler'],
  ['NumberOfPanels', 'Panel'],
  ['NumberOfRanks', 'Rank'],
  ['NumberOfSwitches', 'Switch'],
];

int _countOf(OdfDocument d, String type) {
  var c = 0;
  for (final s in sectionsOf(d, type)) {
    if (type == 'Manual' && s.topNumber == 0) continue;
    c++;
  }
  return c;
}

/// Updates the NumberOf... keys of [Organ] to match the sections that exist.
void recount(OdfDocument d) {
  final org = d.find('Organ');
  if (org == null) return;
  for (final p in kOrganCounts) {
    org.set(p[0], _countOf(d, p[1]).toString());
  }
  org.set('HasPedals', hasPedal(d) ? 'Y' : 'N');
}

// ---------------------------------------------------------------------------
// Adding
// ---------------------------------------------------------------------------

int nextNumber(OdfDocument d, String type) {
  var max = 0;
  for (final s in sectionsOf(d, type)) {
    final n = s.topNumber!;
    if (n > max) max = n;
  }
  return max + 1;
}

/// Adds [sec] as the next free section of [type] and returns its number.
/// The section is placed after the last section of the same type.
int addSection(OdfDocument d, String type, OdfSection sec) {
  final n = nextNumber(d, type);
  sec.name = '$type${pad3(n)}';
  var idx = -1;
  for (var i = 0; i < d.sections.length; i++) {
    if (d.sections[i].topType == type) idx = i;
  }
  if (idx >= 0) {
    d.sections.insert(idx + 1, sec);
  } else {
    d.sections.add(sec);
  }
  return n;
}

OdfSection _s(List<List<String>> kv) {
  final s = OdfSection('x');
  for (final p in kv) {
    s.set(p[0], p[1]);
  }
  return s;
}

/// Defaults for new elements. Every new drawstop/button is displayed so that
/// GrandOrgue lays it out on its built-in default panel.
int addWindchestGroup(OdfDocument d, [String? name]) {
  final n = nextNumber(d, 'WindchestGroup');
  final r = addSection(
      d,
      'WindchestGroup',
      _s([
        ['Name', name ?? 'Windchest $n'],
        ['NumberOfEnclosures', '0'],
        ['NumberOfTremulants', '0'],
      ]));
  recount(d);
  return r;
}

int addEnclosure(OdfDocument d, [String? name]) {
  final n = nextNumber(d, 'Enclosure');
  final r = addSection(
      d,
      'Enclosure',
      _s([
        ['Name', name ?? 'Enclosure $n'],
        ['AmpMinimumLevel', '1'],
        ['Displayed', 'Y'],
      ]));
  recount(d);
  return r;
}

int addTremulant(OdfDocument d, [String? name]) {
  final n = nextNumber(d, 'Tremulant');
  final r = addSection(
      d,
      'Tremulant',
      _s([
        ['Name', name ?? 'Tremulant $n'],
        ['Function', 'Input'],
        ['DefaultToEngaged', 'N'],
        ['GCState', '0'],
        ['StoreInDivisional', 'Y'],
        ['StoreInGeneral', 'Y'],
        ['Displayed', 'Y'],
        ['TremulantType', 'Synth'],
        ['Period', '160'],
        ['StartRate', '8'],
        ['StopRate', '8'],
        ['AmpModDepth', '18'],
      ]));
  recount(d);
  return r;
}

int addSwitch(OdfDocument d, [String? name]) {
  final n = nextNumber(d, 'Switch');
  final r = addSection(
      d,
      'Switch',
      _s([
        ['Name', name ?? 'Switch $n'],
        ['DefaultToEngaged', 'N'],
        ['GCState', '0'],
        ['StoreInDivisional', 'Y'],
        ['StoreInGeneral', 'Y'],
        ['Displayed', 'Y'],
      ]));
  recount(d);
  return r;
}

int addRank(OdfDocument d, {String? name, int windchest = 0}) {
  final n = nextNumber(d, 'Rank');
  final s = _s([
    ['Name', name ?? 'Rank $n'],
    ['NumberOfLogicalPipes', '61'],
    ['FirstMidiNoteNumber', '36'],
    ['Percussive', 'N'],
    ['AcceptsRetuning', 'Y'],
  ]);
  if (windchest > 0) s.set('WindchestGroup', pad3(windchest));
  final r = addSection(d, 'Rank', s);
  recount(d);
  return r;
}

/// Adds a manual. Use [pedal] = true for Manual000 (only one allowed).
/// Returns the manual number, or -1 if a pedal already exists.
int addManual(OdfDocument d, {bool pedal = false, String? name}) {
  if (pedal) {
    if (hasPedal(d)) return -1;
    final s = _s([
      ['Name', name ?? 'PEDAL'],
      ['NumberOfLogicalKeys', '32'],
      ['FirstAccessibleKeyLogicalKeyNumber', '1'],
      ['FirstAccessibleKeyMIDINoteNumber', '36'],
      ['NumberOfAccessibleKeys', '32'],
      ['MIDIInputNumber', '1'],
      ['Displayed', 'Y'],
      ['NumberOfStops', '0'],
      ['NumberOfCouplers', '0'],
      ['NumberOfDivisionals', '0'],
    ]);
    s.name = 'Manual000';
    d.sections.add(s);
    final org = d.find('Organ');
    if (org != null) org.set('HasPedals', 'Y');
    recount(d);
    return 0;
  }
  final n = nextNumber(d, 'Manual');
  final num = n < 1 ? 1 : n;
  final s = _s([
    ['Name', name ?? 'Manual $num'],
    ['NumberOfLogicalKeys', '61'],
    ['FirstAccessibleKeyLogicalKeyNumber', '1'],
    ['FirstAccessibleKeyMIDINoteNumber', '36'],
    ['NumberOfAccessibleKeys', '61'],
    ['MIDIInputNumber', (num + (hasPedal(d) ? 1 : 0)).toString()],
    ['Displayed', 'Y'],
    ['NumberOfStops', '0'],
    ['NumberOfCouplers', '0'],
    ['NumberOfDivisionals', '0'],
  ]);
  final r = addSection(d, 'Manual', s);
  recount(d);
  return r;
}

/// Adds a new stop to [manual]. Returns the new stop number.
int addStop(OdfDocument d, OdfSection manual, {String? name}) {
  final n = nextNumber(d, 'Stop');
  final s = _s([
    ['Name', name ?? 'Stop $n'],
    ['Function', 'Input'],
    ['DefaultToEngaged', 'N'],
    ['GCState', '0'],
    ['StoreInDivisional', 'Y'],
    ['StoreInGeneral', 'Y'],
    ['Displayed', 'Y'],
    ['FirstAccessiblePipeLogicalKeyNumber', '1'],
    ['NumberOfAccessiblePipes', manual.getInt('NumberOfAccessibleKeys', 61).toString()],
    ['NumberOfRanks', '0'],
  ]);
  final no = addSection(d, 'Stop', s);
  addRef(manual, refSpecFor('Manual', 'NumberOfStops'), no);
  return no;
}

/// Adds a new coupler to [manual]. Returns the new coupler number.
int addCoupler(OdfDocument d, OdfSection manual, {String? name}) {
  final n = nextNumber(d, 'Coupler');
  final dest = manual.topNumber ?? 1;
  final s = _s([
    ['Name', name ?? 'Coupler $n'],
    ['UnisonOff', 'N'],
    ['DestinationManual', pad3(dest)],
    ['DestinationKeyshift', '0'],
    ['CoupleToSubsequentUnisonIntermanualCouplers', 'N'],
    ['CoupleToSubsequentUpwardIntermanualCouplers', 'N'],
    ['CoupleToSubsequentDownwardIntermanualCouplers', 'N'],
    ['CoupleToSubsequentUpwardIntramanualCouplers', 'N'],
    ['CoupleToSubsequentDownwardIntramanualCouplers', 'N'],
    ['Function', 'Input'],
    ['DefaultToEngaged', 'N'],
    ['GCState', '0'],
    ['StoreInDivisional', 'Y'],
    ['StoreInGeneral', 'Y'],
    ['Displayed', 'Y'],
  ]);
  final no = addSection(d, 'Coupler', s);
  addRef(manual, refSpecFor('Manual', 'NumberOfCouplers'), no);
  return no;
}

/// Creates a blank organ with sensible defaults.
OdfDocument newOrgan() {
  final d = OdfDocument();
  d.sections.add(_s([
    ['ChurchName', 'New organ'],
    ['ChurchAddress', ''],
    ['OrganBuilder', ''],
    ['OrganBuildDate', ''],
    ['OrganComments', ''],
    ['RecordingDetails', ''],
    ['InfoFilename', ''],
    ['HasPedals', 'N'],
    ['DivisionalsStoreIntermanualCouplers', 'Y'],
    ['DivisionalsStoreIntramanualCouplers', 'Y'],
    ['DivisionalsStoreTremulants', 'Y'],
    ['GeneralsStoreDivisionalCouplers', 'Y'],
    ['CombinationsStoreNonDisplayedDrawstops', 'Y'],
  ])..name = 'Organ');
  recount(d);
  return d;
}

// ---------------------------------------------------------------------------
// Deleting
// ---------------------------------------------------------------------------

void _renamePrefixed(OdfDocument d, String oldName, String newName) {
  final re = RegExp('^${RegExp.escape(oldName)}(?=[A-Za-z])');
  for (final x in d.sections) {
    if (x.name == oldName) {
      x.name = newName;
    } else if (re.hasMatch(x.name)) {
      x.name = newName + x.name.substring(oldName.length);
    }
  }
}

/// Deletes [sec] and everything that belongs to it, removes every reference to
/// it, renumbers the later sections and fixes the references to those.
void deleteSection(OdfDocument d, OdfSection sec) {
  final t = sec.topType;
  final n = sec.topNumber;
  if (t == null || n == null) {
    d.sections.remove(sec);
    return;
  }
  // Deleting the pedal (Manual000) does not shift the other manuals.
  final pedalCase = t == 'Manual' && n == 0;

  // 1. Reference lists that point at this type.
  for (final spec in kRefs) {
    if (spec.targetType != t) continue;
    for (final o in sectionsOf(d, spec.ownerType)) {
      if (o.get(spec.countKey) == null) continue;
      final items = readList(o, spec);
      final out = <RefItem>[];
      var changed = false;
      for (final it in items) {
        var num = it.number;
        if (num == n) {
          changed = true;
          continue;
        }
        if (num > n && !pedalCase) {
          num -= 1;
          changed = true;
        }
        out.add(RefItem(num, it.extra));
      }
      if (changed) writeList(o, spec, out);
    }
  }

  // 1b. Single-key references.
  for (final sr in kSingleRefs) {
    if (sr.targetType != t) continue;
    for (final o in sectionsOf(d, sr.ownerType)) {
      final v = o.get(sr.key);
      if (v == null) continue;
      final num = int.tryParse(v.trim());
      if (num == null) continue;
      if (num == n) {
        o.remove(sr.key);
      } else if (num > n && !pedalCase) {
        o.set(sr.key, v.trim().length >= 3 ? pad3(num - 1) : (num - 1).toString());
      }
    }
  }

  // 2. Remove the section and its sub-sections (e.g. Panel001Switch005).
  final subRe = RegExp('^${RegExp.escape(sec.name)}(?=[A-Za-z])');
  d.sections.removeWhere((x) => x.name == sec.name || subRe.hasMatch(x.name));

  // 2b. Panel display sub-sections are keyed by the global number of the
  // object they show (Panel001Switch005 shows Switch005).
  for (final pan in sectionsOf(d, 'Panel')) {
    final pre = '${pan.name}$t${pad3(n)}';
    d.sections.removeWhere((x) => x.name == pre);
  }

  // 3. Renumber later sections.
  if (!pedalCase) {
    for (final pan in sectionsOf(d, 'Panel')) {
      final pre = pan.name + t;
      final re = RegExp('^${RegExp.escape(pre)}(\\d+)\$');
      final subs = <int, OdfSection>{};
      for (final x in d.sections) {
        final m = re.firstMatch(x.name);
        if (m != null) subs[int.parse(m.group(1)!)] = x;
      }
      final keys = subs.keys.toList()..sort();
      for (final num in keys) {
        if (num > n) subs[num]!.name = '$pre${pad3(num - 1)}';
      }
    }
    for (final x in sectionsOf(d, t)) {
      final num = x.topNumber!;
      if (num > n) _renamePrefixed(d, x.name, '$t${pad3(num - 1)}');
    }
  }

  recount(d);
}

// ---------------------------------------------------------------------------
// Validation
// ---------------------------------------------------------------------------

/// Checks the file for broken references and wrong counts.
/// Returns a list of human-readable problems (empty if everything is fine).
List<String> validate(OdfDocument d) {
  final issues = <String>[];
  final names = <String>{for (final s in d.sections) s.name};

  for (final t in kTopTypes) {
    final nums = [for (final s in sectionsOf(d, t)) s.topNumber!];
    if (t == 'Stop' || nums.isEmpty) continue;
    final start = (t == 'Manual' && nums.contains(0)) ? 0 : 1;
    var ok = true;
    for (var i = 0; i < nums.length; i++) {
      if (nums[i] != start + i) {
        ok = false;
        break;
      }
    }
    if (!ok) issues.add('$t numbering has gaps.');
  }

  final org = d.find('Organ');
  if (org == null) {
    issues.add('There is no [Organ] section.');
  } else {
    for (final p in kOrganCounts) {
      final v = org.get(p[0]);
      if (v == null) continue;
      final c = _countOf(d, p[1]);
      if (int.tryParse(v) != c) {
        issues.add('Organ ${p[0]}=$v but there are $c sections.');
      }
    }
  }

  for (final spec in kRefs) {
    for (final o in sectionsOf(d, spec.ownerType)) {
      if (o.get(spec.countKey) == null) continue;
      final items = readList(o, spec);
      final declared = o.getInt(spec.countKey, 0);
      if (items.length != declared) {
        issues.add(
            '${o.name}: ${spec.countKey}=$declared but ${items.length} entries found.');
      }
      for (var i = 0; i < items.length; i++) {
        final target = '${spec.targetType}${pad3(items[i].number)}';
        if (!names.contains(target)) {
          issues.add(
              '${o.name}: ${spec.itemKey}${pad3(i + 1)} points to missing $target.');
        }
        if (spec.ownerType == 'Panel' &&
            spec.itemKey == 'Switch' &&
            !names.contains('${o.name}Switch${pad3(items[i].number)}')) {
          issues.add(
              '${o.name}: missing display section ${o.name}Switch${pad3(items[i].number)}.');
        }
      }
    }
  }

  for (final sr in kSingleRefs) {
    for (final o in sectionsOf(d, sr.ownerType)) {
      final v = o.get(sr.key);
      if (v == null) continue;
      final num = int.tryParse(v.trim());
      if (num == null || !names.contains('${sr.targetType}${pad3(num)}')) {
        issues.add('${o.name}: ${sr.key}=$v points to a missing section.');
      }
    }
  }

  for (final r in sectionsOf(d, 'Rank')) {
    if (r.get('WindchestGroup') == null) {
      issues.add('${r.name} (${r.label}) has no windchest group.');
    }
  }
  return issues;
}

// ---------------------------------------------------------------------------
// Import stops / ranks from another file
// ---------------------------------------------------------------------------

class SourceStop {
  final int number;
  final String name;
  final String manualName;
  SourceStop(this.number, this.name, this.manualName);
}

/// Stops of [src] in the order of its manuals.
List<SourceStop> stopsOfManuals(OdfDocument src) {
  final out = <SourceStop>[];
  final seen = <int>{};
  final spec = refSpecFor('Manual', 'NumberOfStops');
  for (final m in sectionsOf(src, 'Manual')) {
    for (final it in readList(m, spec)) {
      final s = sectionByNumber(src, 'Stop', it.number);
      if (s == null) continue;
      seen.add(it.number);
      out.add(SourceStop(it.number, s.label, m.label));
    }
  }
  for (final s in sectionsOf(src, 'Stop')) {
    if (!seen.contains(s.topNumber)) {
      out.add(SourceStop(s.topNumber!, s.label, '(not in a manual)'));
    }
  }
  return out;
}

final RegExp _pipePathKey = RegExp(r'^Pipe\d+(Attack\d+|Release\d+)?$');
final RegExp _absolutePath = RegExp(r'^([A-Za-z]:|[\\/])');

/// Adds [prefix] in front of every sample path in [sec].
void applyPathPrefix(OdfSection sec, String prefix) {
  if (prefix.isEmpty) return;
  for (final e in sec.entries) {
    if (!_pipePathKey.hasMatch(e.key)) continue;
    final v = e.value;
    if (v.isEmpty || v.startsWith('REF:') || _absolutePath.hasMatch(v)) continue;
    e.value = '$prefix$v';
  }
}

final RegExp _panelLookKey = RegExp(
    r'^(DispDrawstop|DispImageNum|DispButton|DispLabel|DispSpecialImage|PositionX|PositionY|ImageOn|ImageOff|MouseRadius|MouseRect|TextRect|TextBreakWidth)');

/// Copies stops and ranks from [src] into [dst]. Every imported stop is a real,
/// fully linked copy: its ranks (with all pipes and sample paths) are copied
/// too, references are renumbered, and the stop is added to manual
/// [destManual] and shown on the default panel.
///
/// [destWindchest] = 0 leaves the windchest group unset.
/// [prefix] is put in front of every sample path so that GrandOrgue can still
/// find the samples from the destination file's folder.
List<String> importItems(
  OdfDocument dst,
  OdfDocument src, {
  required List<int> stopNos,
  required List<int> rankNos,
  required int destManual,
  required int destWindchest,
  String prefix = '',
}) {
  final log = <String>[];
  final rankMap = <int, int>{};

  int importRank(int rn) {
    final cached = rankMap[rn];
    if (cached != null) return cached;
    final s = sectionByNumber(src, 'Rank', rn);
    if (s == null) return -1;
    final c = s.clone();
    applyPathPrefix(c, prefix);
    c.remove('WindchestGroup');
    if (destWindchest > 0) c.set('WindchestGroup', pad3(destWindchest));
    final no = addSection(dst, 'Rank', c);
    rankMap[rn] = no;
    log.add('Rank "${s.label}" -> Rank${pad3(no)}');
    return no;
  }

  for (final rn in rankNos) {
    importRank(rn);
  }

  final man = stopNos.isEmpty ? null : sectionByNumber(dst, 'Manual', destManual);
  final rankSpec = refSpecFor('Stop', 'NumberOfRanks');
  final manStops = refSpecFor('Manual', 'NumberOfStops');
  final switchRe = RegExp(r'^Switch\d{3}$');

  for (final sn in stopNos) {
    final s = sectionByNumber(src, 'Stop', sn);
    if (s == null || man == null) continue;
    final c = s.clone();
    applyPathPrefix(c, prefix);

    // Re-link the ranks to the copies in the destination.
    final ranks = readList(c, rankSpec);
    if (ranks.isNotEmpty) {
      final out = <RefItem>[];
      for (final it in ranks) {
        final nn = importRank(it.number);
        if (nn > 0) out.add(RefItem(nn, it.extra));
      }
      writeList(c, rankSpec, out);
    }

    // Make it a standalone drawstop shown on the default panel.
    c.entries.removeWhere((e) =>
        e.key == 'SwitchCount' ||
        switchRe.hasMatch(e.key) ||
        _panelLookKey.hasMatch(e.key));
    c.set('Function', 'Input');
    c.set('Displayed', 'Y');
    c.remove('WindchestGroup');
    if (destWindchest > 0) c.set('WindchestGroup', pad3(destWindchest));

    final no = addSection(dst, 'Stop', c);
    addRef(man, manStops, no);
    log.add('Stop "${s.label}" -> Stop${pad3(no)} in ${man.label}');
  }

  recount(dst);
  return log;
}

// ---------------------------------------------------------------------------
// Manual sub-sections (Manual001Divisional001 and so on)
// ---------------------------------------------------------------------------

/// Deletes a sub-section such as [Manual001Divisional002] and renumbers the
/// ones after it. The manual's NumberOfDivisionals is updated.
void deleteSubSection(OdfDocument d, OdfSection sec) {
  d.sections.remove(sec);
  final m = RegExp(r'^(Manual\d+)Divisional(\d+)$').firstMatch(sec.name);
  if (m == null) return;
  final pre = '${m.group(1)}Divisional';
  final re = RegExp('^${RegExp.escape(pre)}(\\d+)\$');
  final subs = <OdfSection>[];
  for (final x in d.sections) {
    if (re.hasMatch(x.name)) subs.add(x);
  }
  subs.sort((a, b) => int.parse(re.firstMatch(a.name)!.group(1)!)
      .compareTo(int.parse(re.firstMatch(b.name)!.group(1)!)));
  for (var i = 0; i < subs.length; i++) {
    subs[i].name = '$pre${pad3(i + 1)}';
  }
  d.find(m.group(1)!)?.set('NumberOfDivisionals', subs.length.toString());
}

/// Divisional sub-sections of [manual].
List<OdfSection> divisionalsOf(OdfDocument d, OdfSection manual) {
  final re = RegExp('^${RegExp.escape(manual.name)}Divisional\\d+\$');
  return [
    for (final x in d.sections)
      if (re.hasMatch(x.name)) x
  ];
}
