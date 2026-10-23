import 'package:flutter/material.dart';

import '../odf/odf_model.dart';
import '../odf/odf_ops.dart';
import '../odf/odf_schema.dart';
import 'organ_controller.dart';
import 'rank_pipes.dart';
import 'tree_panel.dart';
import 'widgets.dart';

/// Shows the editor for whatever is selected in the tree.
class EditorPane extends StatelessWidget {
  final OrganController c;
  const EditorPane({super.key, required this.c});

  @override
  Widget build(BuildContext context) {
    final doc = c.doc;
    if (doc == null) return const SizedBox();
    final sel = c.selected;
    Widget body;
    if (sel == 'organ') {
      body = OrganEditor(c: c);
    } else if (sel.startsWith('g:')) {
      body = GroupEditor(c: c, type: sel.substring(2));
    } else if (sel.startsWith('mg:')) {
      final parts = sel.split(':');
      final m = doc.find(parts[1]);
      body = m == null
          ? const Text('Nothing selected.')
          : ManualGroupEditor(c: c, manual: m, kind: parts[2]);
    } else if (sel.startsWith('sec:')) {
      final s = doc.find(sel.substring(4));
      body = s == null
          ? const Text('Nothing selected.')
          : SectionEditor(c: c, section: s);
    } else {
      body = const Text('Nothing selected.');
    }
    return KeyedSubtree(
      key: ValueKey('$sel#${c.editorGeneration}'),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: body,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

class AddRow extends StatefulWidget {
  final String label;
  final void Function(int count) onAdd;
  const AddRow({super.key, required this.label, required this.onAdd});

  @override
  State<AddRow> createState() => _AddRowState();
}

class _AddRowState extends State<AddRow> {
  final TextEditingController _c = TextEditingController(text: '1');

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const Text('Add'),
        SizedBox(
          width: 64,
          child: TextField(
            controller: _c,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
                border: OutlineInputBorder(), isDense: true),
          ),
        ),
        FilledButton.tonal(
          onPressed: () {
            var n = int.tryParse(_c.text.trim()) ?? 1;
            if (n < 1) n = 1;
            if (n > 100) n = 100;
            widget.onAdd(n);
          },
          child: Text(widget.label),
        ),
      ],
    );
  }
}

Future<void> removeSectionWithConfirm(
    BuildContext context, OrganController c, OdfSection s, String what) async {
  final ok = await confirmDialog(
    context,
    'Remove this $what?',
    '"${s.label}" will be removed. References to it are removed and the '
        'numbers of the later ${what}s shift down so the file stays valid.',
    okLabel: 'Remove',
  );
  if (!ok) return;
  final next = selectionAfterDelete(s);
  if (s.topType == null) {
    deleteSubSection(c.doc!, s);
    final m = RegExp(r'^(Manual\d+)').firstMatch(s.name);
    c.selected = m == null ? 'organ' : 'sec:${m.group(1)}';
  } else {
    deleteSection(c.doc!, s);
    c.selected = next;
  }
  c.structureChanged();
}

class RemoveButton extends StatelessWidget {
  final OrganController c;
  final OdfSection section;
  final String what;
  const RemoveButton(
      {super.key, required this.c, required this.section, required this.what});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 16),
      child: Center(
        child: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error),
          onPressed: () => removeSectionWithConfirm(context, c, section, what),
          icon: const Icon(Icons.delete_outline),
          label: Text('Remove this $what'),
        ),
      ),
    );
  }
}

class Heading extends StatelessWidget {
  final String title;
  final String? sub;
  const Heading(this.title, {super.key, this.sub});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          if (sub != null)
            Text(sub!, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

Set<String> _keysOf(List<FieldDef> f) => {for (final d in f) d.key};

/// Keys that have no form field are still editable here, so nothing in a file
/// is ever hidden from the user.
Widget otherKeys(OdfSection s, OrganController c,
    {required Set<String> hide, List<RegExp> patterns = const []}) {
  return ExpansionTile(
    tilePadding: EdgeInsets.zero,
    title: const Text('All other keys'),
    children: [
      RawKeysEditor(
        section: s,
        onChanged: c.edited,
        hideKeys: hide,
        hidePatterns: patterns,
        height: 320,
      ),
    ],
  );
}

// ---------------------------------------------------------------------------
// [Organ]
// ---------------------------------------------------------------------------

class OrganEditor extends StatelessWidget {
  final OrganController c;
  const OrganEditor({super.key, required this.c});

  @override
  Widget build(BuildContext context) {
    final doc = c.doc!;
    final org = doc.find('Organ');
    if (org == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('This file has no [Organ] section.'),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: () {
              doc.sections.insert(0, OdfSection('Organ'));
              recount(doc);
              c.structureChanged();
            },
            child: const Text('Create [Organ]'),
          ),
        ],
      );
    }
    final hide = {
      ..._keysOf(kOrganInfoFields),
      ..._keysOf(kOrganBehaviourFields),
      ..._keysOf(kOrganPanelFields),
      for (final p in kOrganCounts) p[0],
      'HasPedals',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Heading('Organ properties', sub: '[Organ]'),
        FieldGroup(
            section: org, fields: kOrganInfoFields, onChanged: c.edited),
        const SectionTitle('Behaviour'),
        FieldGroup(
            section: org, fields: kOrganBehaviourFields, onChanged: c.edited),
        const SectionTitle('Default panel'),
        const Text(
            'GrandOrgue builds this panel itself when the file has no panel '
            'images, so new stops and buttons show up without any panel work.'),
        const SizedBox(height: 8),
        FieldGroup(
            section: org, fields: kOrganPanelFields, onChanged: c.edited),
        const SizedBox(height: 12),
        otherKeys(org, c, hide: hide),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Group nodes (Manuals, Ranks, ...)
// ---------------------------------------------------------------------------

class GroupEditor extends StatelessWidget {
  final OrganController c;
  final String type;
  const GroupEditor({super.key, required this.c, required this.type});

  void _afterAdd(List<int> made, String t) {
    if (made.isEmpty) return;
    c.expand('g:$t');
    if (made.length == 1) c.selected = 'sec:$t${pad3(made.first)}';
    c.structureChanged();
  }

  @override
  Widget build(BuildContext context) {
    final doc = c.doc!;
    List<OdfSection> items;
    String title;
    if (type == 'Unassigned') {
      final used = <int>{};
      final spec = refSpecFor('Manual', 'NumberOfStops');
      for (final m in sectionsOf(doc, 'Manual')) {
        for (final it in readList(m, spec)) {
          used.add(it.number);
        }
      }
      items = [
        for (final s in sectionsOf(doc, 'Stop'))
          if (!used.contains(s.topNumber)) s
      ];
      title = 'Stops not in a manual';
    } else {
      items = sectionsOf(doc, type);
      title = kGroupTitles[type] ?? type;
    }

    Widget? add;
    switch (type) {
      case 'Manual':
        add = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
                'Add manuals in rising order: the pedal first, then the next '
                'lowest manual and so on up to the highest. Add any '
                '"trick" manuals last.'),
            const SizedBox(height: 8),
            Wrap(spacing: 12, runSpacing: 8, children: [
              AddRow(
                label: 'new manual(s)',
                onAdd: (n) {
                  final made = <int>[];
                  for (var i = 0; i < n; i++) {
                    made.add(addManual(doc));
                  }
                  _afterAdd(made, 'Manual');
                },
              ),
              if (!hasPedal(doc))
                OutlinedButton(
                  onPressed: () {
                    final r = addManual(doc, pedal: true);
                    if (r == 0) {
                      c.expand('g:Manual');
                      c.selected = 'sec:Manual000';
                      c.structureChanged();
                    }
                  },
                  child: const Text('Add pedal'),
                ),
            ]),
          ],
        );
        break;
      case 'WindchestGroup':
        add = AddRow(
            label: 'new windchest(s)',
            onAdd: (n) => _afterAdd(
                [for (var i = 0; i < n; i++) addWindchestGroup(doc)], type));
        break;
      case 'Enclosure':
        add = AddRow(
            label: 'new enclosure(s)',
            onAdd: (n) => _afterAdd(
                [for (var i = 0; i < n; i++) addEnclosure(doc)], type));
        break;
      case 'Tremulant':
        add = AddRow(
            label: 'new tremulant(s)',
            onAdd: (n) => _afterAdd(
                [for (var i = 0; i < n; i++) addTremulant(doc)], type));
        break;
      case 'Rank':
        add = AddRow(
            label: 'new rank(s)',
            onAdd: (n) => _afterAdd(
                [for (var i = 0; i < n; i++) addRank(doc)], type));
        break;
      case 'Switch':
        add = AddRow(
            label: 'new switch(es)',
            onAdd: (n) => _afterAdd(
                [for (var i = 0; i < n; i++) addSwitch(doc)], type));
        break;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Heading(title, sub: '${items.length} item(s)'),
        if (add != null) add,
        if (add != null) const SizedBox(height: 16),
        if (items.isEmpty) const Text('Nothing here yet.'),
        for (final s in items)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(s.label),
            subtitle: Text(s.name),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              c.expand('g:$type');
              c.select('sec:${s.name}');
            },
          ),
      ],
    );
  }
}

class ManualGroupEditor extends StatelessWidget {
  final OrganController c;
  final OdfSection manual;
  final String kind; // Stop, Coupler, Divisional
  const ManualGroupEditor(
      {super.key, required this.c, required this.manual, required this.kind});

  @override
  Widget build(BuildContext context) {
    final doc = c.doc!;
    final List<OdfSection> items = [];
    if (kind == 'Stop' || kind == 'Coupler') {
      final spec =
          refSpecFor('Manual', kind == 'Stop' ? 'NumberOfStops' : 'NumberOfCouplers');
      for (final it in readList(manual, spec)) {
        final s = sectionByNumber(doc, kind, it.number);
        if (s != null) items.add(s);
      }
    } else {
      items.addAll(divisionalsOf(doc, manual));
    }

    Widget? add;
    if (kind == 'Stop') {
      add = AddRow(
        label: 'new stop(s)',
        onAdd: (n) {
          int last = 0;
          for (var i = 0; i < n; i++) {
            last = addStop(doc, manual);
          }
          recount(doc);
          c.expand('r:mg:${manual.name}:Stop');
          if (n == 1) c.selected = 'sec:Stop${pad3(last)}';
          c.structureChanged();
        },
      );
    } else if (kind == 'Coupler') {
      add = FilledButton.tonal(
        onPressed: () {
          final no = addCoupler(doc, manual);
          recount(doc);
          c.expand('r:mg:${manual.name}:Coupler');
          c.selected = 'sec:Coupler${pad3(no)}';
          c.structureChanged();
        },
        child: const Text('Add new coupler'),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Heading('${manual.label}: ${kind}s', sub: '${items.length} item(s)'),
        if (add != null) add,
        if (add != null) const SizedBox(height: 16),
        if (items.isEmpty) const Text('Nothing here yet.'),
        for (final s in items)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(s.label),
            subtitle: Text(s.name),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => c.select('sec:${s.name}'),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// One section
// ---------------------------------------------------------------------------

class SectionEditor extends StatelessWidget {
  final OrganController c;
  final OdfSection section;
  const SectionEditor({super.key, required this.c, required this.section});

  @override
  Widget build(BuildContext context) {
    final s = section;
    switch (s.topType) {
      case 'Manual':
        return _manual(context, s);
      case 'Stop':
        return _stop(context, s);
      case 'Coupler':
        return _coupler(context, s);
      case 'Tremulant':
        return _tremulant(context, s);
      case 'Switch':
        return _plain(s, kSwitchFields, 'Switch', 'switch');
      case 'WindchestGroup':
        return _windchest(context, s);
      case 'Enclosure':
        return _plain(s, kEnclosureFields, 'Enclosure', 'enclosure');
      case 'Rank':
        return _rank(context, s);
      case 'Panel':
        return _rawOnly(s, 'Panel', 'panel');
      case 'ReversiblePiston':
        return _rawOnly(s, 'Reversible piston', 'reversible piston');
      case 'DivisionalCoupler':
        return _rawOnly(s, 'Divisional coupler', 'divisional coupler');
      case 'General':
        return _rawOnly(s, 'General', 'general');
      default:
        return _rawOnly(
            s, s.name, RegExp(r'Divisional\d+$').hasMatch(s.name) ? 'divisional' : 'section');
    }
  }

  Widget _rawOnly(OdfSection s, String title, String what) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Heading(s.label, sub: '[${s.name}]'),
        FieldGroup(
            section: s,
            fields: const [FieldDef('Name', 'Name', FieldKind.text, wide: true)],
            onChanged: c.edited),
        const SizedBox(height: 12),
        RawKeysEditor(
          section: s,
          onChanged: c.edited,
          hideKeys: const {'Name'},
          height: 420,
        ),
        RemoveButton(c: c, section: s, what: what),
      ],
    );
  }

  Widget _plain(OdfSection s, List<FieldDef> fields, String title, String what) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Heading(s.label, sub: '[${s.name}]'),
        FieldGroup(section: s, fields: fields, onChanged: c.edited),
        const SizedBox(height: 12),
        otherKeys(s, c, hide: _keysOf(fields)),
        RemoveButton(c: c, section: s, what: what),
      ],
    );
  }

  Widget _manual(BuildContext context, OdfSection s) {
    final doc = c.doc!;
    final isPedal = s.topNumber == 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Heading(s.label, sub: '[${s.name}]${isPedal ? '  -  this manual is the pedal' : ''}'),
        FieldGroup(section: s, fields: kManualFields, onChanged: c.edited),
        const SizedBox(height: 12),
        Wrap(spacing: 12, runSpacing: 8, children: [
          AddRow(
            label: 'new stop(s)',
            onAdd: (n) {
              int last = 0;
              for (var i = 0; i < n; i++) {
                last = addStop(doc, s);
              }
              recount(doc);
              c.expand('r:${s.name}');
              c.expand('r:mg:${s.name}:Stop');
              if (n == 1) c.selected = 'sec:Stop${pad3(last)}';
              c.structureChanged();
            },
          ),
          OutlinedButton(
            onPressed: () {
              final no = addCoupler(doc, s);
              recount(doc);
              c.expand('r:${s.name}');
              c.expand('r:mg:${s.name}:Coupler');
              c.selected = 'sec:Coupler${pad3(no)}';
              c.structureChanged();
            },
            child: const Text('Add new coupler'),
          ),
        ]),
        const SectionTitle('Tremulants'),
        RefPicker(
          doc: doc,
          owner: s,
          spec: refSpecFor('Manual', 'NumberOfTremulants'),
          availableTitle: 'Available tremulants',
          referencedTitle: 'Referenced tremulants',
          onChanged: c.edited,
        ),
        const SectionTitle('Switches'),
        RefPicker(
          doc: doc,
          owner: s,
          spec: refSpecFor('Manual', 'NumberOfSwitches'),
          availableTitle: 'Available switches',
          referencedTitle: 'Referenced switches',
          onChanged: c.edited,
        ),
        const SizedBox(height: 12),
        otherKeys(s, c, hide: _keysOf(kManualFields), patterns: [
          RegExp(r'^Key\d+'),
          RegExp(r'^(Stop|Coupler|Switch|Tremulant)\d{3}$'),
          RegExp(r'^NumberOf(Stops|Couplers|Switches|Tremulants)$'),
        ]),
        RemoveButton(c: c, section: s, what: 'manual'),
      ],
    );
  }

  Widget _stop(BuildContext context, OdfSection s) {
    final doc = c.doc!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Heading(s.label, sub: '[${s.name}]'),
        FieldGroup(section: s, fields: kStopFields, onChanged: c.edited),
        const SizedBox(height: 12),
        SingleRefDropdown(
          doc: doc,
          section: s,
          keyName: 'WindchestGroup',
          targetType: 'WindchestGroup',
          label: 'Windchest group',
          onChanged: c.edited,
        ),
        const SectionTitle('Ranks'),
        RefPicker(
          doc: doc,
          owner: s,
          spec: refSpecFor('Stop', 'NumberOfRanks'),
          availableTitle: 'Available ranks',
          referencedTitle: 'Referenced ranks',
          extraFor: (t) => {
            'FirstPipeNumber': '1',
            'FirstAccessibleKeyNumber': '1',
            'PipeCount': t.get('NumberOfLogicalPipes') ?? '0',
          },
          onChanged: c.edited,
        ),
        const SectionTitle('Switches'),
        RefPicker(
          doc: doc,
          owner: s,
          spec: refSpecFor('Stop', 'SwitchCount'),
          availableTitle: 'Available switches',
          referencedTitle: 'Referenced switches',
          onChanged: c.edited,
        ),
        const SizedBox(height: 12),
        otherKeys(s, c, hide: {
          ..._keysOf(kStopFields),
          'WindchestGroup',
          'NumberOfRanks',
          'SwitchCount',
        }, patterns: [
          RegExp(r'^Rank\d{3}'),
          RegExp(r'^Switch\d{3}$'),
          RegExp(r'^Pipe\d+'),
        ]),
        RemoveButton(c: c, section: s, what: 'stop'),
      ],
    );
  }

  Widget _coupler(BuildContext context, OdfSection s) {
    final doc = c.doc!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Heading(s.label, sub: '[${s.name}]'),
        FieldGroup(section: s, fields: kCouplerFields, onChanged: c.edited),
        const SizedBox(height: 12),
        SingleRefDropdown(
          doc: doc,
          section: s,
          keyName: 'DestinationManual',
          targetType: 'Manual',
          label: 'Destination manual',
          onChanged: c.edited,
        ),
        const SectionTitle('Switches'),
        RefPicker(
          doc: doc,
          owner: s,
          spec: refSpecFor('Coupler', 'SwitchCount'),
          availableTitle: 'Available switches',
          referencedTitle: 'Referenced switches',
          onChanged: c.edited,
        ),
        const SizedBox(height: 12),
        otherKeys(s, c, hide: {
          ..._keysOf(kCouplerFields),
          'DestinationManual',
          'SwitchCount',
        }, patterns: [
          RegExp(r'^Switch\d{3}$'),
        ]),
        RemoveButton(c: c, section: s, what: 'coupler'),
      ],
    );
  }

  Widget _tremulant(BuildContext context, OdfSection s) {
    final doc = c.doc!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Heading(s.label, sub: '[${s.name}]'),
        FieldGroup(section: s, fields: kTremulantFields, onChanged: c.edited),
        const SectionTitle('Switches'),
        RefPicker(
          doc: doc,
          owner: s,
          spec: refSpecFor('Tremulant', 'SwitchCount'),
          availableTitle: 'Available switches',
          referencedTitle: 'Referenced switches',
          onChanged: c.edited,
        ),
        const SizedBox(height: 12),
        otherKeys(s, c, hide: {
          ..._keysOf(kTremulantFields),
          'SwitchCount',
        }, patterns: [
          RegExp(r'^Switch\d{3}$'),
        ]),
        RemoveButton(c: c, section: s, what: 'tremulant'),
      ],
    );
  }

  Widget _windchest(BuildContext context, OdfSection s) {
    final doc = c.doc!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Heading(s.label, sub: '[${s.name}]'),
        FieldGroup(section: s, fields: kWindchestFields, onChanged: c.edited),
        const SectionTitle('Enclosures'),
        RefPicker(
          doc: doc,
          owner: s,
          spec: refSpecFor('WindchestGroup', 'NumberOfEnclosures'),
          availableTitle: 'Available enclosures',
          referencedTitle: 'Referenced enclosures',
          onChanged: c.edited,
        ),
        const SectionTitle('Tremulants'),
        RefPicker(
          doc: doc,
          owner: s,
          spec: refSpecFor('WindchestGroup', 'NumberOfTremulants'),
          availableTitle: 'Available tremulants',
          referencedTitle: 'Referenced tremulants',
          onChanged: c.edited,
        ),
        const SizedBox(height: 12),
        otherKeys(s, c, hide: {
          ..._keysOf(kWindchestFields),
          'NumberOfEnclosures',
          'NumberOfTremulants',
        }, patterns: [
          RegExp(r'^(Enclosure|Tremulant)\d{3}$'),
        ]),
        RemoveButton(c: c, section: s, what: 'windchest group'),
      ],
    );
  }

  Widget _rank(BuildContext context, OdfSection s) {
    final doc = c.doc!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Heading(s.label, sub: '[${s.name}]'),
        FieldGroup(section: s, fields: kRankFields, onChanged: c.edited),
        const SizedBox(height: 12),
        SingleRefDropdown(
          doc: doc,
          section: s,
          keyName: 'WindchestGroup',
          targetType: 'WindchestGroup',
          label: 'Windchest group',
          onChanged: c.edited,
        ),
        const SectionTitle('Pipes'),
        PipeEditor(rank: s, onChanged: c.edited),
        const SizedBox(height: 12),
        otherKeys(s, c, hide: {
          ..._keysOf(kRankFields),
          'WindchestGroup',
        }, patterns: [
          RegExp(r'^Pipe\d+'),
        ]),
        RemoveButton(c: c, section: s, what: 'rank'),
      ],
    );
  }
}
