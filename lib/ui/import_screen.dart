import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../odf/odf_io.dart';
import '../odf/odf_model.dart';
import '../odf/odf_ops.dart';
import 'organ_controller.dart';
import 'widgets.dart';

/// Tools > Import Stops/Ranks.
/// Picks another .organ file and copies chosen stops and ranks into the open
/// organ. The copies are real: ranks keep all their pipes and sample paths,
/// stops are linked to the copied ranks, and numbering is fixed up.
class ImportScreen extends StatefulWidget {
  final OrganController c;
  const ImportScreen({super.key, required this.c});

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  OdfDocument? _src;
  String _srcName = '';
  List<SourceStop> _stops = [];
  final Set<int> _selStops = {};
  final Set<int> _selRanks = {};
  String _filter = '';
  int _destManual = 0;
  int _destWindchest = -1; // -1 = create a new windchest group
  final TextEditingController _prefix = TextEditingController();
  final List<String> _log = [];
  bool _changed = false;

  OdfDocument get _dst => widget.c.doc!;

  @override
  void dispose() {
    _prefix.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    try {
      final r = await FilePicker.platform.pickFiles(
        type: FileType.any,
        withData: true,
      );
      if (r == null || r.files.isEmpty) return;
      final f = r.files.single;
      final bytes = f.bytes;
      if (bytes == null) {
        if (mounted) showSnack(context, 'Could not read the file.');
        return;
      }
      final doc = OdfParser.parse(OdfParser.decode(bytes));
      if (doc.sections.isEmpty) {
        if (mounted) showSnack(context, 'No sections found in that file.');
        return;
      }
      setState(() {
        _src = doc;
        _srcName = f.name;
        _stops = stopsOfManuals(doc);
        _selStops.clear();
        _selRanks.clear();
        _filter = '';
        _log.clear();
        final ms = sectionsOf(_dst, 'Manual');
        _destManual = ms.isEmpty ? 0 : ms.first.topNumber!;
        final ws = sectionsOf(_dst, 'WindchestGroup');
        _destWindchest = ws.isEmpty ? -1 : ws.first.topNumber!;
      });
    } catch (e) {
      if (mounted) showSnack(context, 'Could not open: $e');
    }
  }

  Future<void> _doImport() async {
    final src = _src;
    if (src == null) return;
    if (_selStops.isEmpty && _selRanks.isEmpty) {
      showSnack(context, 'Select at least one stop or rank.');
      return;
    }
    final dst = _dst;
    if (_selStops.isNotEmpty && sectionByNumber(dst, 'Manual', _destManual) == null) {
      showSnack(context, 'Choose a destination manual first (add one in the tree).');
      return;
    }
    var wc = _destWindchest;
    if (wc == -1) {
      wc = addWindchestGroup(dst, 'Imported');
    }
    final log = importItems(
      dst,
      src,
      stopNos: _selStops.toList()..sort(),
      rankNos: _selRanks.toList()..sort(),
      destManual: _destManual,
      destWindchest: wc,
      prefix: _prefix.text.trim(),
    );
    widget.c.structureChanged();
    setState(() {
      _changed = true;
      _log
        ..clear()
        ..addAll(log);
      _selStops.clear();
      _selRanks.clear();
      if (_destWindchest == -1) _destWindchest = wc;
    });
    if (mounted) showSnack(context, 'Imported ${log.length} item(s).');
  }

  @override
  Widget build(BuildContext context) {
    final src = _src;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _changed);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Import Stops/Ranks'),
          leading: BackButton(onPressed: () => Navigator.pop(context, _changed)),
        ),
        body: src == null ? _start() : _chooser(src),
      ),
    );
  }

  Widget _start() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Pick another .organ file. You can then copy any of its stops '
              'and ranks into this organ.\n\nThe copies are real: ranks keep '
              'all their pipes and sample paths, and stops are linked to the '
              'copied ranks.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _pick,
              icon: const Icon(Icons.folder_open),
              label: const Text('Choose .organ file'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chooser(OdfDocument src) {
    final f = _filter.trim().toLowerCase();
    final stops = [
      for (final s in _stops)
        if (f.isEmpty || '${s.name} ${s.manualName}'.toLowerCase().contains(f)) s
    ];
    final ranks = [
      for (final r in sectionsOf(src, 'Rank'))
        if (f.isEmpty || r.label.toLowerCase().contains(f)) r
    ];
    final manuals = sectionsOf(_dst, 'Manual');
    final windchests = sectionsOf(_dst, 'WindchestGroup');

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(children: [
          Expanded(
            child: Text('Source: $_srcName\n'
                '${_stops.length} stops, ${sectionsOf(src, 'Rank').length} ranks'),
          ),
          TextButton(onPressed: _pick, child: const Text('Change')),
        ]),
        const SizedBox(height: 8),
        TextField(
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'Search stops and ranks',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: (v) => setState(() => _filter = v),
        ),
        const SectionTitle('Destination'),
        InputDecorator(
          decoration: const InputDecoration(
              labelText: 'Import stops to manual',
              border: OutlineInputBorder(),
              isDense: true),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              isExpanded: true,
              value: manuals.any((m) => m.topNumber == _destManual)
                  ? _destManual
                  : null,
              hint: const Text('No manual yet'),
              items: [
                for (final m in manuals)
                  DropdownMenuItem<int>(
                      value: m.topNumber!,
                      child: Text('${pad3(m.topNumber!)}  ${m.label}')),
              ],
              onChanged: (v) => setState(() => _destManual = v ?? 0),
            ),
          ),
        ),
        const SizedBox(height: 12),
        InputDecorator(
          decoration: const InputDecoration(
              labelText: 'Windchest group',
              border: OutlineInputBorder(),
              isDense: true),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              isExpanded: true,
              value: _destWindchest == -1 ||
                      windchests.any((w) => w.topNumber == _destWindchest)
                  ? _destWindchest
                  : -1,
              items: [
                const DropdownMenuItem<int>(
                    value: -1, child: Text('(create a new windchest group)')),
                for (final w in windchests)
                  DropdownMenuItem<int>(
                      value: w.topNumber!,
                      child: Text('${pad3(w.topNumber!)}  ${w.label}')),
              ],
              onChanged: (v) => setState(() => _destWindchest = v ?? -1),
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _prefix,
          decoration: const InputDecoration(
            labelText: 'Sample path prefix (optional)',
            helperText:
                'Put in front of every sample path so GrandOrgue can find the '
                'samples from this organ\'s folder, e.g. ..\\OtherOrgan\\',
            helperMaxLines: 3,
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        SectionTitle('Stops  (${_selStops.length} selected)'),
        Wrap(spacing: 8, children: [
          TextButton(
              onPressed: () => setState(
                  () => _selStops.addAll([for (final s in stops) s.number])),
              child: const Text('Select shown')),
          TextButton(
              onPressed: () => setState(_selStops.clear),
              child: const Text('Clear')),
        ]),
        _box(
          stops.isEmpty
              ? [const Padding(padding: EdgeInsets.all(12), child: Text('No stops.'))]
              : [
                  for (final s in stops)
                    CheckboxListTile(
                      dense: true,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: _selStops.contains(s.number),
                      title: Text(s.name),
                      subtitle: Text(s.manualName),
                      onChanged: (v) => setState(() {
                        if (v == true) {
                          _selStops.add(s.number);
                        } else {
                          _selStops.remove(s.number);
                        }
                      }),
                    ),
                ],
        ),
        const Padding(
          padding: EdgeInsets.only(top: 6),
          child: Text(
              'Each selected stop brings its own ranks with it automatically.',
              style: TextStyle(fontSize: 12)),
        ),
        SectionTitle('Ranks only  (${_selRanks.length} selected)'),
        _box(
          ranks.isEmpty
              ? [const Padding(padding: EdgeInsets.all(12), child: Text('No ranks.'))]
              : [
                  for (final r in ranks)
                    CheckboxListTile(
                      dense: true,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: _selRanks.contains(r.topNumber),
                      title: Text(r.label),
                      subtitle: Text(r.name),
                      onChanged: (v) => setState(() {
                        if (v == true) {
                          _selRanks.add(r.topNumber!);
                        } else {
                          _selRanks.remove(r.topNumber);
                        }
                      }),
                    ),
                ],
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _doImport,
          icon: const Icon(Icons.download),
          label: const Text('Import selected'),
        ),
        if (_log.isNotEmpty) ...[
          const SectionTitle('Import log'),
          for (final l in _log) Text(l, style: const TextStyle(fontSize: 12)),
        ],
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _box(List<Widget> children) {
    return Container(
      height: 280,
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outline),
        borderRadius: BorderRadius.circular(4),
      ),
      child: ListView(children: children),
    );
  }
}
