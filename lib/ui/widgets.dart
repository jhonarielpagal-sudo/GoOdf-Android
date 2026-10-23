import 'package:flutter/material.dart';

import '../odf/odf_model.dart';
import '../odf/odf_ops.dart';
import '../odf/odf_schema.dart';

Future<bool> confirmDialog(BuildContext context, String title, String message,
    {String okLabel = 'OK'}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel')),
        FilledButton(
            onPressed: () => Navigator.pop(c, true), child: Text(okLabel)),
      ],
    ),
  );
  return r ?? false;
}

void showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

class SectionTitle extends StatelessWidget {
  final String text;
  const SectionTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Text(text, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

// ---------------------------------------------------------------------------
// Single field
// ---------------------------------------------------------------------------

class FieldTile extends StatefulWidget {
  final OdfSection section;
  final FieldDef def;
  final VoidCallback onChanged;

  const FieldTile({
    super.key,
    required this.section,
    required this.def,
    required this.onChanged,
  });

  @override
  State<FieldTile> createState() => _FieldTileState();
}

class _FieldTileState extends State<FieldTile> {
  late final TextEditingController _c;
  String? _error;

  String _current() => widget.section.get(widget.def.key) ?? widget.def.def;

  @override
  void initState() {
    super.initState();
    _c = TextEditingController(text: _current());
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _onText(String v) {
    final d = widget.def;
    final s = widget.section;
    final t = v.trim();
    if (d.kind == FieldKind.integer) {
      if (t.isEmpty) {
        s.remove(d.key);
        setState(() => _error = null);
        widget.onChanged();
        return;
      }
      if (int.tryParse(t) == null) {
        setState(() => _error = 'Whole number');
        return;
      }
    } else if (d.kind == FieldKind.decimal) {
      if (t.isEmpty) {
        s.remove(d.key);
        setState(() => _error = null);
        widget.onChanged();
        return;
      }
      if (double.tryParse(t) == null) {
        setState(() => _error = 'Number');
        return;
      }
    } else {
      if (t.isEmpty && !s.has(d.key)) return;
    }
    setState(() => _error = null);
    s.set(d.key, t);
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.def;
    switch (d.kind) {
      case FieldKind.yesNo:
        return _yesNo(d);
      case FieldKind.choice:
        return _choice(d);
      case FieldKind.integer:
      case FieldKind.decimal:
      case FieldKind.text:
        return _text(d);
    }
  }

  Widget _text(FieldDef d) {
    final numeric =
        d.kind == FieldKind.integer || d.kind == FieldKind.decimal;
    return TextField(
      controller: _c,
      keyboardType: numeric
          ? const TextInputType.numberWithOptions(decimal: true, signed: true)
          : TextInputType.text,
      decoration: InputDecoration(
        labelText: d.label,
        helperText: d.help,
        errorText: _error,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      onChanged: _onText,
    );
  }

  Widget _yesNo(FieldDef d) {
    final cur = _current().trim().toUpperCase().startsWith('Y') ? 'Y' : 'N';
    return InputDecorator(
      decoration: InputDecoration(
        labelText: d.label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: SegmentedButton<String>(
          showSelectedIcon: false,
          style: const ButtonStyle(visualDensity: VisualDensity.compact),
          segments: const [
            ButtonSegment<String>(value: 'Y', label: Text('Yes')),
            ButtonSegment<String>(value: 'N', label: Text('No')),
          ],
          selected: {cur},
          onSelectionChanged: (s) {
            setState(() => widget.section.set(d.key, s.first));
            widget.onChanged();
          },
        ),
      ),
    );
  }

  Widget _choice(FieldDef d) {
    final cur = _current().trim();
    final opts = <List<String>>[...d.options];
    if (!opts.any((o) => o[0] == cur)) opts.add([cur, cur]);
    return InputDecorator(
      decoration: InputDecoration(
        labelText: d.label,
        border: const OutlineInputBorder(),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: cur,
          isExpanded: true,
          items: [
            for (final o in opts)
              DropdownMenuItem<String>(value: o[0], child: Text(o[1])),
          ],
          onChanged: (v) {
            if (v == null) return;
            setState(() => widget.section.set(d.key, v));
            widget.onChanged();
          },
        ),
      ),
    );
  }
}

/// A block of fields laid out in 1 to 3 columns depending on the width.
class FieldGroup extends StatelessWidget {
  final OdfSection section;
  final List<FieldDef> fields;
  final VoidCallback onChanged;
  final String keyPrefix;

  const FieldGroup({
    super.key,
    required this.section,
    required this.fields,
    required this.onChanged,
    this.keyPrefix = '',
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth;
      final cols = w >= 900 ? 3 : (w >= 560 ? 2 : 1);
      final tile = (w - (cols - 1) * 12) / cols;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final f in fields)
            SizedBox(
              width: f.wide ? w : tile,
              child: FieldTile(
                key: ValueKey('$keyPrefix${section.name}/${f.key}'),
                section: section,
                def: f,
                onChanged: onChanged,
              ),
            ),
        ],
      );
    });
  }
}

// ---------------------------------------------------------------------------
// Reference pickers
// ---------------------------------------------------------------------------

/// Drop-down that selects one section of [targetType] and stores its number
/// in [keyName], e.g. Rank.WindchestGroup.
class SingleRefDropdown extends StatefulWidget {
  final OdfDocument doc;
  final OdfSection section;
  final String keyName;
  final String targetType;
  final String label;
  final VoidCallback onChanged;

  const SingleRefDropdown({
    super.key,
    required this.doc,
    required this.section,
    required this.keyName,
    required this.targetType,
    required this.label,
    required this.onChanged,
  });

  @override
  State<SingleRefDropdown> createState() => _SingleRefDropdownState();
}

class _SingleRefDropdownState extends State<SingleRefDropdown> {
  @override
  Widget build(BuildContext context) {
    final targets = sectionsOf(widget.doc, widget.targetType);
    final raw = widget.section.get(widget.keyName);
    var cur = raw == null ? 0 : (int.tryParse(raw.trim()) ?? 0);
    if (cur != 0 && !targets.any((t) => t.topNumber == cur)) cur = 0;
    return InputDecorator(
      decoration: InputDecoration(
        labelText: widget.label,
        border: const OutlineInputBorder(),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: cur,
          isExpanded: true,
          items: [
            const DropdownMenuItem<int>(value: 0, child: Text('(not set)')),
            for (final t in targets)
              DropdownMenuItem<int>(
                value: t.topNumber!,
                child: Text('${pad3(t.topNumber!)}  ${t.label}',
                    overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (v) {
            if (v == null) return;
            setState(() {
              if (v == 0) {
                widget.section.remove(widget.keyName);
              } else {
                widget.section.set(widget.keyName, pad3(v));
              }
            });
            widget.onChanged();
          },
        ),
      ),
    );
  }
}

class _PickRow {
  final int number;
  final String label;
  _PickRow(this.number, this.label);
}

/// "Available / Referenced" lists with Add and Remove buttons, like GoOdf.
class RefPicker extends StatefulWidget {
  final OdfDocument doc;
  final OdfSection owner;
  final RefSpec spec;
  final String availableTitle;
  final String referencedTitle;
  final Map<String, String> Function(OdfSection target)? extraFor;
  final VoidCallback onChanged;

  const RefPicker({
    super.key,
    required this.doc,
    required this.owner,
    required this.spec,
    required this.availableTitle,
    required this.referencedTitle,
    required this.onChanged,
    this.extraFor,
  });

  @override
  State<RefPicker> createState() => _RefPickerState();
}

class _RefPickerState extends State<RefPicker> {
  final Set<int> _selAvail = {};
  final Set<int> _selRef = {};

  void _add() {
    for (final n in _selAvail) {
      final t = sectionByNumber(widget.doc, widget.spec.targetType, n);
      addRef(widget.owner, widget.spec, n, widget.extraFor?.call(t!));
    }
    setState(_selAvail.clear);
    widget.onChanged();
  }

  void _remove() {
    for (final n in _selRef) {
      removeRef(widget.owner, widget.spec, n);
    }
    setState(_selRef.clear);
    widget.onChanged();
  }

  Widget _list(String title, List<_PickRow> rows, Set<int> selected) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 4),
        Container(
          height: 180,
          decoration: BoxDecoration(
            border: Border.all(color: scheme.outline),
            borderRadius: BorderRadius.circular(4),
          ),
          child: rows.isEmpty
              ? const Center(child: Text('(empty)'))
              : ListView.builder(
                  itemCount: rows.length,
                  itemBuilder: (context, i) {
                    final r = rows[i];
                    final on = selected.contains(r.number);
                    return InkWell(
                      onTap: () => setState(() {
                        if (!selected.add(r.number)) selected.remove(r.number);
                      }),
                      child: Container(
                        color: on ? scheme.primaryContainer : null,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 8),
                        child: Text(r.label,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final spec = widget.spec;
    final items = readList(widget.owner, spec);
    final used = <int>{for (final i in items) i.number};
    final avail = <_PickRow>[];
    for (final t in sectionsOf(widget.doc, spec.targetType)) {
      if (!used.contains(t.topNumber)) {
        avail.add(_PickRow(t.topNumber!, '${pad3(t.topNumber!)}  ${t.label}'));
      }
    }
    final refd = <_PickRow>[];
    for (final i in items) {
      final t = sectionByNumber(widget.doc, spec.targetType, i.number);
      refd.add(_PickRow(
          i.number, '${pad3(i.number)}  ${t == null ? '(missing)' : t.label}'));
    }
    _selAvail.removeWhere((n) => !avail.any((r) => r.number == n));
    _selRef.removeWhere((n) => !refd.any((r) => r.number == n));

    final addBtn = FilledButton.tonal(
      onPressed: _selAvail.isEmpty ? null : _add,
      child: const Text('Add ->'),
    );
    final removeBtn = FilledButton.tonal(
      onPressed: _selRef.isEmpty ? null : _remove,
      child: const Text('<- Remove'),
    );

    return LayoutBuilder(builder: (context, c) {
      final a = _list(widget.availableTitle, avail, _selAvail);
      final r = _list(widget.referencedTitle, refd, _selRef);
      if (c.maxWidth >= 640) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: a),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                children: [
                  const SizedBox(height: 60),
                  addBtn,
                  const SizedBox(height: 8),
                  removeBtn,
                ],
              ),
            ),
            Expanded(child: r),
          ],
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          a,
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [addBtn, const SizedBox(width: 12), removeBtn],
          ),
          const SizedBox(height: 8),
          r,
        ],
      );
    });
  }
}

// ---------------------------------------------------------------------------
// Raw key editor (for keys that have no dedicated form field)
// ---------------------------------------------------------------------------

class RawKeysEditor extends StatefulWidget {
  final OdfSection section;

  /// Keys that are shown elsewhere and should not be listed here.
  final Set<String> hideKeys;

  /// Keys matching one of these patterns are hidden as well.
  final List<RegExp> hidePatterns;
  final VoidCallback onChanged;
  final double height;

  const RawKeysEditor({
    super.key,
    required this.section,
    required this.onChanged,
    this.hideKeys = const {},
    this.hidePatterns = const [],
    this.height = 360,
  });

  @override
  State<RawKeysEditor> createState() => _RawKeysEditorState();
}

class _RawKeysEditorState extends State<RawKeysEditor> {
  bool _hidden(OdfEntry e) {
    if (widget.hideKeys.contains(e.key)) return true;
    for (final p in widget.hidePatterns) {
      if (p.hasMatch(e.key)) return true;
    }
    return false;
  }

  Future<void> _edit(OdfEntry e) async {
    final c = TextEditingController(text: e.value);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(e.key),
        content: TextField(
          controller: c,
          autofocus: true,
          minLines: 1,
          maxLines: 5,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
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
        title: const Text('New key'),
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
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Add')),
        ],
      ),
    );
    final key = k.text.trim();
    if (ok != true || key.isEmpty) return;
    setState(() => widget.section.set(key, v.text.trim()));
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final list = [
      for (final e in widget.section.entries)
        if (!_hidden(e)) e
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: widget.height,
          child: list.isEmpty
              ? const Center(child: Text('No other keys.'))
              : ListView.separated(
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final e = list[i];
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
                        setState(() => widget.section.entries.remove(e));
                        widget.onChanged();
                      },
                      child: ListTile(
                        dense: true,
                        title: Text(e.key),
                        subtitle:
                            Text(e.value.isEmpty ? '(empty)' : e.value),
                        onTap: () => _edit(e),
                      ),
                    );
                  },
                ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _addKey,
            icon: const Icon(Icons.add),
            label: const Text('Add key'),
          ),
        ),
      ],
    );
  }
}
