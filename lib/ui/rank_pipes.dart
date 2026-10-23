import 'package:flutter/material.dart';

import '../odf/odf_model.dart';
import 'widgets.dart';

Future<String?> askText(BuildContext context, String title, String initial,
    {bool multiline = false}) {
  final c = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: c,
        autofocus: true,
        minLines: 1,
        maxLines: multiline ? 6 : 3,
        decoration: const InputDecoration(border: OutlineInputBorder()),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(
            onPressed: () => Navigator.pop(ctx, c.text.trim()),
            child: const Text('OK')),
      ],
    ),
  );
}

/// Tree of the pipes of a rank: Pipe001 -> sample, attacks, releases, tuning...
/// Every key that belongs to a pipe (Pipe001..., Pipe001Attack001...) is shown
/// under its pipe and can be edited.
class PipeEditor extends StatefulWidget {
  final OdfSection rank;
  final VoidCallback onChanged;
  final double height;

  const PipeEditor({
    super.key,
    required this.rank,
    required this.onChanged,
    this.height = 460,
  });

  @override
  State<PipeEditor> createState() => _PipeEditorState();
}

class _PipeEditorState extends State<PipeEditor> {
  static final RegExp _pipeKey = RegExp(r'^Pipe(\d+)(.*)$');
  String _filter = '';

  Map<int, List<OdfEntry>> _group() {
    final m = <int, List<OdfEntry>>{};
    for (final e in widget.rank.entries) {
      final mm = _pipeKey.firstMatch(e.key);
      if (mm == null) continue;
      m.putIfAbsent(int.parse(mm.group(1)!), () => []).add(e);
    }
    return m;
  }

  String _fileOf(List<OdfEntry> list, int no) {
    final main = 'Pipe${no.toString().padLeft(3, '0')}';
    for (final e in list) {
      if (e.key == main) {
        final v = e.value.replaceAll('\\', '/');
        final i = v.lastIndexOf('/');
        return i >= 0 ? v.substring(i + 1) : v;
      }
    }
    return '';
  }

  Future<void> _editEntry(OdfEntry e) async {
    final r = await askText(context, e.key, e.value, multiline: true);
    if (r == null) return;
    setState(() => e.value = r);
    widget.onChanged();
  }

  void _removePipe(int no) {
    final re = RegExp('^Pipe0*$no(?!\\d)');
    setState(() => widget.rank.entries.removeWhere((e) => re.hasMatch(e.key)));
    widget.onChanged();
  }

  Future<void> _addPipe(Map<int, List<OdfEntry>> g) async {
    final next = g.isEmpty ? 1 : (g.keys.reduce((a, b) => a > b ? a : b) + 1);
    final path = await askText(
        context, 'Sample file of Pipe${next.toString().padLeft(3, '0')}', '');
    if (path == null || path.isEmpty) return;
    setState(() => widget.rank.set('Pipe${next.toString().padLeft(3, '0')}', path));
    widget.onChanged();
  }

  Future<void> _clearAll() async {
    final ok = await confirmDialog(context, 'Remove all pipes?',
        'Every Pipe key of this rank will be deleted.',
        okLabel: 'Remove');
    if (!ok) return;
    setState(() =>
        widget.rank.entries.removeWhere((e) => _pipeKey.hasMatch(e.key)));
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final g = _group();
    final nums = g.keys.toList()..sort();
    final f = _filter.trim().toLowerCase();
    final shown = f.isEmpty
        ? nums
        : [
            for (final n in nums)
              if ('pipe${n.toString().padLeft(3, '0')} ${_fileOf(g[n]!, n)}'
                  .toLowerCase()
                  .contains(f))
                n
          ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text('${nums.length} pipes',
                style: Theme.of(context).textTheme.labelLarge),
            SizedBox(
              width: 200,
              child: TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Find pipe or file',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (v) => setState(() => _filter = v),
              ),
            ),
            OutlinedButton(
                onPressed: () => _addPipe(g), child: const Text('Add pipe')),
            OutlinedButton(
                onPressed: nums.isEmpty ? null : _clearAll,
                child: const Text('Remove all pipes')),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: widget.height,
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).colorScheme.outline),
            borderRadius: BorderRadius.circular(4),
          ),
          child: shown.isEmpty
              ? const Center(child: Text('No pipes.'))
              : ListView.builder(
                  itemCount: shown.length,
                  itemBuilder: (context, i) {
                    final no = shown[i];
                    final list = g[no]!;
                    final pre = 'Pipe${no.toString().padLeft(3, '0')}';
                    final file = _fileOf(list, no);
                    return ExpansionTile(
                      key: PageStorageKey('pipe_${widget.rank.name}_$no'),
                      dense: true,
                      title: Text(pre),
                      subtitle: file.isEmpty
                          ? null
                          : Text(file,
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                      children: [
                        for (final e in list)
                          ListTile(
                            dense: true,
                            title: Text(e.key.length > pre.length
                                ? e.key.substring(pre.length)
                                : '(sample)'),
                            subtitle:
                                Text(e.value.isEmpty ? '(empty)' : e.value),
                            onTap: () => _editEntry(e),
                          ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: () => _removePipe(no),
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('Remove this pipe'),
                          ),
                        ),
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }
}
