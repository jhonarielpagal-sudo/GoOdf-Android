import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

import '../odf/odf_io.dart';
import '../odf/odf_model.dart';
import 'section_screen.dart';

/// Section types that the [Organ] section keeps a count for,
/// e.g. adding a Rank updates NumberOfRanks.
const Map<String, String> kCountKeys = {
  'Manual': 'NumberOfManuals',
  'Rank': 'NumberOfRanks',
  'Panel': 'NumberOfPanels',
  'Enclosure': 'NumberOfEnclosures',
  'Tremulant': 'NumberOfTremulants',
  'WindchestGroup': 'NumberOfWindchestGroups',
  'Switch': 'NumberOfSwitches',
  'ReversiblePiston': 'NumberOfReversiblePistons',
  'Divisional Coupler': 'NumberOfDivisionalCouplers',
  'DivisionalCoupler': 'NumberOfDivisionalCouplers',
  'Stop': 'NumberOfStops',
};

/// Types that are normally created for the user from the menu.
const List<String> kAddableTypes = [
  'Manual',
  'Stop',
  'Rank',
  'Switch',
  'Coupler',
  'Tremulant',
  'Enclosure',
  'WindchestGroup',
  'Panel',
  'DivisionalCoupler',
  'ReversiblePiston',
  'Generals',
];

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  OdfDocument? _doc;
  String _fileName = 'untitled.organ';
  bool _dirty = false;
  String _query = '';

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<bool> _confirmDiscard() async {
    if (!_dirty) return true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('May hindi pa na-save na pagbabago'),
        content: const Text('Itatapon ang mga pagbabago. Ituloy?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Kanselahin')),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Ituloy')),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _open() async {
    if (!await _confirmDiscard()) return;
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final f = result.files.single;
      final bytes = f.bytes;
      if (bytes == null) {
        _snack('Hindi mabasa ang file.');
        return;
      }
      final text = utf8.decode(bytes, allowMalformed: true);
      final doc = OdfParser.parse(text);
      if (doc.sections.isEmpty) {
        _snack('Walang nakitang section. Siguradong .organ file ito?');
        return;
      }
      setState(() {
        _doc = doc;
        _fileName = f.name;
        _dirty = false;
        _query = '';
      });
    } catch (e) {
      _snack('Error sa pagbukas: $e');
    }
  }

  Future<void> _new() async {
    if (!await _confirmDiscard()) return;
    final doc = OdfDocument();
    final organ = OdfSection('Organ');
    organ.set('ChurchName', 'Bagong Organ');
    organ.set('ChurchAddress', '');
    organ.set('OrganBuilder', '');
    organ.set('OrganBuildDate', '');
    organ.set('OrganComments', '');
    organ.set('RecordingDetails', '');
    organ.set('InfoFilename', '');
    organ.set('NumberOfManuals', '0');
    organ.set('NumberOfEnclosures', '0');
    organ.set('NumberOfTremulants', '0');
    organ.set('NumberOfWindchestGroups', '0');
    organ.set('NumberOfRanks', '0');
    organ.set('NumberOfPanels', '0');
    doc.sections.add(organ);
    setState(() {
      _doc = doc;
      _fileName = 'untitled.organ';
      _dirty = true;
      _query = '';
    });
  }

  String get _text => OdfWriter.write(_doc!);

  Future<void> _saveAs() async {
    if (_doc == null) return;
    final bytes = Uint8List.fromList(utf8.encode(_text));
    try {
      final name = _fileName.toLowerCase().endsWith('.organ')
          ? _fileName
          : '$_fileName.organ';
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'I-save ang .organ file',
        fileName: name,
        bytes: bytes,
      );
      if (path == null) return; // cancelled
      setState(() => _dirty = false);
      _snack('Na-save.');
    } catch (e) {
      _snack('Hindi ma-save: $e');
    }
  }

  Future<void> _share() async {
    if (_doc == null) return;
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$_fileName');
      await file.writeAsString(_text);
      await Share.shareXFiles([XFile(file.path)], text: _fileName);
    } catch (e) {
      _snack('Hindi maibahagi: $e');
    }
  }

  void _syncCounts(String type) {
    final doc = _doc!;
    final organ = doc.find('Organ');
    final key = kCountKeys[type];
    if (organ == null || key == null) return;
    // Stop counts live in Manual sections, not in [Organ].
    if (type == 'Stop') return;
    organ.set(key, doc.ofType(type).length.toString());
  }

  Future<void> _addSection() async {
    final doc = _doc;
    if (doc == null) return;
    final type = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(title: Text('Magdagdag ng section')),
            for (final t in kAddableTypes)
              ListTile(title: Text(t), onTap: () => Navigator.pop(c, t)),
          ],
        ),
      ),
    );
    if (type == null) return;
    final s = doc.addNumbered(type);
    _syncCounts(type);
    setState(() => _dirty = true);
    if (!mounted) return;
    await _openSection(s);
  }

  Future<void> _openSection(OdfSection s) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SectionScreen(
          doc: _doc!,
          section: s,
          onChanged: () => setState(() => _dirty = true),
          onDeleted: (type) {
            _syncCounts(type);
            setState(() => _dirty = true);
          },
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final doc = _doc;
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmDiscard() && mounted) {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(doc == null ? 'GoOdf Mobile' : '$_fileName${_dirty ? ' *' : ''}'),
          actions: [
            if (doc != null) ...[
              IconButton(
                tooltip: 'I-save',
                icon: const Icon(Icons.save),
                onPressed: _saveAs,
              ),
              IconButton(
                tooltip: 'Ibahagi',
                icon: const Icon(Icons.share),
                onPressed: _share,
              ),
            ],
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'new') _new();
                if (v == 'open') _open();
              },
              itemBuilder: (c) => const [
                PopupMenuItem(value: 'new', child: Text('Bagong organ')),
                PopupMenuItem(value: 'open', child: Text('Buksan ang .organ')),
              ],
            ),
          ],
        ),
        floatingActionButton: doc == null
            ? null
            : FloatingActionButton.extended(
                onPressed: _addSection,
                icon: const Icon(Icons.add),
                label: const Text('Section'),
              ),
        body: doc == null ? _emptyState() : _tree(doc),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.piano, size: 72),
            const SizedBox(height: 16),
            Text('GoOdf Mobile',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            const Text(
              'Editor ng GrandOrgue organ definition files (.organ).\n'
              'Laging gumamit ng kopya ng file kapag nag-e-edit.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _open,
              icon: const Icon(Icons.folder_open),
              label: const Text('Buksan ang .organ'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _new,
              icon: const Icon(Icons.note_add),
              label: const Text('Bagong organ'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tree(OdfDocument doc) {
    final q = _query.trim().toLowerCase();
    final types = doc.types;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Maghanap ng section o pangalan',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 88),
            children: [
              for (final t in types) ..._group(doc, t, q),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _group(OdfDocument doc, String type, String q) {
    final items = doc.ofType(type).where((s) {
      if (q.isEmpty) return true;
      return s.label.toLowerCase().contains(q);
    }).toList();
    if (items.isEmpty) return [];
    return [
      ExpansionTile(
        key: PageStorageKey('type_$type$q'),
        initiallyExpanded: q.isNotEmpty || type == 'Organ',
        title: Text('$type  (${items.length})'),
        children: [
          for (final s in items)
            ListTile(
              dense: true,
              title: Text(s.label),
              subtitle: Text('${s.entries.length} na key'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _openSection(s),
            ),
        ],
      ),
    ];
  }
}
