import 'package:flutter/material.dart';

import '../odf/odf_model.dart';

/// Edits the key/value pairs of one section.
class SectionScreen extends StatefulWidget {
  final OdfDocument doc;
  final OdfSection section;
  final VoidCallback onChanged;
  final void Function(String type) onDeleted;

  const SectionScreen({
    super.key,
    required this.doc,
    required this.section,
    required this.onChanged,
    required this.onDeleted,
  });

  @override
  State<SectionScreen> createState() => _SectionScreenState();
}

class _SectionScreenState extends State<SectionScreen> {
  OdfSection get s => widget.section;

  Future<void> _editValue(OdfEntry e) async {
    final c = TextEditingController(text: e.value);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(e.key),
        content: TextField(
          controller: c,
          autofocus: true,
          minLines: 1,
          maxLines: 6,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Kanselahin')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, c.text),
              child: const Text('OK')),
        ],
      ),
    );
    if (result == null) return;
    setState(() => e.value = result.trim());
    widget.onChanged();
  }

  Future<void> _addKey() async {
    final k = TextEditingController();
    final v = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bagong key'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: k,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Key'),
            ),
            TextField(
              controller: v,
              decoration: const InputDecoration(labelText: 'Value'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Kanselahin')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Idagdag')),
        ],
      ),
    );
    final key = k.text.trim();
    if (ok != true || key.isEmpty) return;
    setState(() => s.set(key, v.text.trim()));
    widget.onChanged();
  }

  Future<void> _renameSection() async {
    final c = TextEditingController(text: s.name);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Palitan ang pangalan ng section'),
        content: TextField(controller: c, autofocus: true),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Kanselahin')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, c.text.trim()),
              child: const Text('OK')),
        ],
      ),
    );
    if (result == null || result.isEmpty || result == s.name) return;
    if (widget.doc.find(result) != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('May ganitong section na.')));
      return;
    }
    setState(() => s.name = result);
    widget.onChanged();
  }

  Future<void> _deleteSection() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Burahin ang [${s.name}]?'),
        content: const Text(
            'Hindi na-a-update ang mga reference mula sa ibang section. Suriin ang mga ito pagkatapos.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Kanselahin')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Burahin')),
        ],
      ),
    );
    if (ok != true) return;
    final type = s.type;
    widget.doc.removeSection(s);
    widget.onDeleted(type);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(s.name),
        actions: [
          IconButton(
              tooltip: 'Palitan ang pangalan',
              icon: const Icon(Icons.drive_file_rename_outline),
              onPressed: _renameSection),
          IconButton(
              tooltip: 'Burahin ang section',
              icon: const Icon(Icons.delete_outline),
              onPressed: _deleteSection),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addKey,
        icon: const Icon(Icons.add),
        label: const Text('Key'),
      ),
      body: s.entries.isEmpty
          ? const Center(child: Text('Walang laman. Magdagdag ng key.'))
          : ListView.separated(
              padding: const EdgeInsets.only(bottom: 88),
              itemCount: s.entries.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (ctx, i) {
                final e = s.entries[i];
                return Dismissible(
                  key: ObjectKey(e),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 16),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (_) {
                    setState(() => s.entries.remove(e));
                    widget.onChanged();
                  },
                  child: ListTile(
                    title: Text(e.key),
                    subtitle: Text(e.value.isEmpty ? '(walang laman)' : e.value),
                    onTap: () => _editValue(e),
                  ),
                );
              },
            ),
    );
  }
}
