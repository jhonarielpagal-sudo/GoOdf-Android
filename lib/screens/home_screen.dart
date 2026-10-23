import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../odf/odf_io.dart';
import '../odf/odf_ops.dart';
import '../ui/editor_pane.dart';
import '../ui/import_screen.dart';
import '../ui/organ_controller.dart';
import '../ui/tree_panel.dart';
import '../ui/widgets.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final OrganController c = OrganController();
  final GlobalKey<ScaffoldState> _scaffold = GlobalKey<ScaffoldState>();

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  Future<bool> _confirmDiscard() async {
    if (!c.dirty) return true;
    return confirmDialog(context, 'Unsaved changes',
        'Your changes will be lost. Continue?',
        okLabel: 'Continue');
  }

  Future<void> _open() async {
    if (!await _confirmDiscard()) return;
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
        if (mounted) showSnack(context, 'No sections found. Is this an .organ file?');
        return;
      }
      c.load(doc, f.name);
      final issues = validate(doc);
      if (mounted && issues.isNotEmpty) {
        showSnack(context,
            'Opened. ${issues.length} problem(s) found - see Tools > Check file.');
      }
    } catch (e) {
      if (mounted) showSnack(context, 'Could not open: $e');
    }
  }

  Future<void> _new() async {
    if (!await _confirmDiscard()) return;
    c.load(newOrgan(), 'untitled.organ');
    c.structureChanged();
  }

  Future<void> _save() async {
    final doc = c.doc;
    if (doc == null) return;
    recount(doc);
    final bytes = Uint8List.fromList(utf8.encode(OdfWriter.write(doc)));
    var name = c.fileName;
    if (!name.toLowerCase().endsWith('.organ')) name = '$name.organ';
    try {
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Save .organ file',
        fileName: name,
        bytes: bytes,
      );
      if (path == null) return;
      c.markSaved(name);
      if (mounted) showSnack(context, 'Saved.');
    } catch (e) {
      if (mounted) showSnack(context, 'Could not save: $e');
    }
  }

  Future<void> _import() async {
    if (c.doc == null) return;
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ImportScreen(c: c)),
    );
  }

  Future<void> _check() async {
    final doc = c.doc;
    if (doc == null) return;
    final issues = validate(doc);
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(issues.isEmpty
            ? 'No problems found'
            : '${issues.length} problem(s)'),
        content: SizedBox(
          width: 420,
          child: issues.isEmpty
              ? const Text('All references and counts are consistent.')
              : ListView(
                  shrinkWrap: true,
                  children: [
                    for (final i in issues.take(200))
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Text(i, style: const TextStyle(fontSize: 13)),
                      ),
                  ],
                ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  void _menu(String v) {
    switch (v) {
      case 'new':
        _new();
        break;
      case 'open':
        _open();
        break;
      case 'save':
        _save();
        break;
      case 'import':
        _import();
        break;
      case 'check':
        _check();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final has = c.doc != null;
        return PopScope(
          canPop: !c.dirty,
          onPopInvokedWithResult: (didPop, _) async {
            if (didPop) return;
            if (await _confirmDiscard()) SystemNavigator.pop();
          },
          child: LayoutBuilder(builder: (context, box) {
            final wide = box.maxWidth >= 840;
            return Scaffold(
              key: _scaffold,
              appBar: AppBar(
                leading: (!wide && has)
                    ? IconButton(
                        tooltip: 'Organ tree',
                        icon: const Icon(Icons.account_tree),
                        onPressed: () => _scaffold.currentState?.openDrawer(),
                      )
                    : null,
                title: Text(
                  has ? '${c.fileName}${c.dirty ? ' *' : ''}' : 'GoOdf Mobile',
                  overflow: TextOverflow.ellipsis,
                ),
                actions: [
                  if (has)
                    IconButton(
                      tooltip: 'Save',
                      icon: const Icon(Icons.save),
                      onPressed: _save,
                    ),
                  PopupMenuButton<String>(
                    onSelected: _menu,
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'new', child: Text('New organ')),
                      const PopupMenuItem(value: 'open', child: Text('Open .organ')),
                      if (has) ...const [
                        PopupMenuItem(value: 'save', child: Text('Write ODF (save)')),
                        PopupMenuDivider(),
                        PopupMenuItem(
                            value: 'import', child: Text('Import Stops/Ranks')),
                        PopupMenuItem(value: 'check', child: Text('Check file')),
                      ],
                    ],
                  ),
                ],
              ),
              drawer: (!wide && has)
                  ? Drawer(
                      child: SafeArea(
                        child: TreePanel(
                          controller: c,
                          onSelected: () =>
                              _scaffold.currentState?.closeDrawer(),
                        ),
                      ),
                    )
                  : null,
              body: !has
                  ? _empty()
                  : wide
                      ? Row(
                          children: [
                            SizedBox(
                              width: 300,
                              child: TreePanel(controller: c),
                            ),
                            const VerticalDivider(width: 1),
                            Expanded(child: EditorPane(c: c)),
                          ],
                        )
                      : EditorPane(c: c),
            );
          }),
        );
      },
    );
  }

  Widget _empty() {
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
              'Create and edit GrandOrgue organ definition files (.organ).\n'
              'Always work on a copy of your file.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _open,
              icon: const Icon(Icons.folder_open),
              label: const Text('Open .organ'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _new,
              icon: const Icon(Icons.note_add),
              label: const Text('New organ'),
            ),
          ],
        ),
      ),
    );
  }
}
