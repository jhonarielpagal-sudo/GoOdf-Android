import 'package:flutter/material.dart';

import '../odf/odf_model.dart';
import '../odf/odf_ops.dart';
import 'organ_controller.dart';

const Map<String, String> kGroupTitles = {
  'Manual': 'Manuals',
  'WindchestGroup': 'Windchestgroups',
  'Enclosure': 'Enclosures',
  'Tremulant': 'Tremulants',
  'Rank': 'Ranks',
  'Switch': 'Switches',
  'ReversiblePiston': 'Reversible Pistons',
  'DivisionalCoupler': 'Divisional Couplers',
  'General': 'Generals',
  'Panel': 'Panels',
};

/// Order of the groups under [Organ], as in GoOdf.
const List<String> kGroupOrder = [
  'Manual',
  'WindchestGroup',
  'Enclosure',
  'Tremulant',
  'Rank',
  'Switch',
  'ReversiblePiston',
  'DivisionalCoupler',
  'General',
  'Panel',
];

class TreeRow {
  final String rowId;
  final String selectId;
  final String label;
  final int depth;
  final bool expandable;
  final bool expanded;
  const TreeRow(this.rowId, this.selectId, this.label, this.depth,
      this.expandable, this.expanded);
}

List<TreeRow> buildTreeRows(OrganController c) {
  final doc = c.doc;
  if (doc == null) return const [];
  final rows = <TreeRow>[];

  bool isOpen(String id) => c.expanded.contains(id);

  void add(String rowId, String selectId, String label, int depth,
      {bool expandable = false}) {
    rows.add(TreeRow(
        rowId, selectId, label, depth, expandable, expandable && isOpen(rowId)));
  }

  add('organ', 'organ', '[Organ]', 0, expandable: true);
  if (!isOpen('organ')) return rows;

  final manualStops = refSpecFor('Manual', 'NumberOfStops');
  final manualCouplers = refSpecFor('Manual', 'NumberOfCouplers');
  final referencedStops = <int>{};
  for (final m in sectionsOf(doc, 'Manual')) {
    for (final it in readList(m, manualStops)) {
      referencedStops.add(it.number);
    }
  }

  for (final type in kGroupOrder) {
    final items = sectionsOf(doc, type);
    final gid = 'g:$type';
    add(gid, gid, kGroupTitles[type]!, 1, expandable: items.isNotEmpty);
    if (!isOpen(gid)) continue;

    for (final s in items) {
      if (type != 'Manual') {
        add('r:${s.name}', 'sec:${s.name}', s.label, 2);
        continue;
      }
      // Manuals have Stops / Couplers / Divisionals below them.
      final rid = 'r:${s.name}';
      add(rid, 'sec:${s.name}', s.label, 2, expandable: true);
      if (!isOpen(rid)) continue;

      final stops = readList(s, manualStops);
      final sid = 'mg:${s.name}:Stop';
      add('r:$sid', sid, 'Stops', 3, expandable: stops.isNotEmpty);
      if (isOpen('r:$sid')) {
        for (final it in stops) {
          final st = sectionByNumber(doc, 'Stop', it.number);
          if (st == null) continue;
          add('r:${s.name}:${st.name}', 'sec:${st.name}', st.label, 4);
        }
      }

      final couplers = readList(s, manualCouplers);
      final cid = 'mg:${s.name}:Coupler';
      add('r:$cid', cid, 'Couplers', 3, expandable: couplers.isNotEmpty);
      if (isOpen('r:$cid')) {
        for (final it in couplers) {
          final cp = sectionByNumber(doc, 'Coupler', it.number);
          if (cp == null) continue;
          add('r:${s.name}:${cp.name}', 'sec:${cp.name}', cp.label, 4);
        }
      }

      final divRe = RegExp('^${RegExp.escape(s.name)}Divisional\\d+\$');
      final divs = [
        for (final x in doc.sections)
          if (divRe.hasMatch(x.name)) x
      ];
      final did = 'mg:${s.name}:Divisional';
      add('r:$did', did, 'Divisionals', 3, expandable: divs.isNotEmpty);
      if (isOpen('r:$did')) {
        for (final dv in divs) {
          add('r:${dv.name}', 'sec:${dv.name}', dv.label, 4);
        }
      }
    }
  }

  // Stops that no manual refers to would otherwise be invisible.
  final orphans = [
    for (final s in sectionsOf(doc, 'Stop'))
      if (!referencedStops.contains(s.topNumber)) s
  ];
  if (orphans.isNotEmpty) {
    add('g:Unassigned', 'g:Unassigned', 'Stops not in a manual', 1,
        expandable: true);
    if (isOpen('g:Unassigned')) {
      for (final s in orphans) {
        add('r:u:${s.name}', 'sec:${s.name}', s.label, 2);
      }
    }
  }
  return rows;
}

class TreePanel extends StatelessWidget {
  final OrganController controller;

  /// Called after a node was selected (used to close the drawer on phones).
  final VoidCallback? onSelected;

  const TreePanel({super.key, required this.controller, this.onSelected});

  @override
  Widget build(BuildContext context) {
    final rows = buildTreeRows(controller);
    final scheme = Theme.of(context).colorScheme;
    return ListView.builder(
      itemCount: rows.length,
      itemBuilder: (context, i) {
        final r = rows[i];
        final selected = controller.selected == r.selectId;
        return Material(
          color: selected ? scheme.secondaryContainer : Colors.transparent,
          child: InkWell(
            onTap: () {
              controller.select(r.selectId);
              if (r.expandable && !r.expanded) controller.expand(r.rowId);
              onSelected?.call();
            },
            child: Padding(
              padding: EdgeInsets.only(left: 4.0 + r.depth * 14.0, right: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 32,
                    height: 36,
                    child: r.expandable
                        ? IconButton(
                            padding: EdgeInsets.zero,
                            iconSize: 20,
                            icon: Icon(r.expanded
                                ? Icons.expand_more
                                : Icons.chevron_right),
                            onPressed: () => controller.toggle(r.rowId),
                          )
                        : null,
                  ),
                  Expanded(
                    child: Text(
                      r.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight:
                            r.depth <= 1 ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The tree selection to show after [sec] was deleted.
String selectionAfterDelete(OdfSection sec) {
  final t = sec.topType;
  if (t == null) return 'organ';
  if (t == 'Stop' || t == 'Coupler') return 'g:Manual';
  return 'g:$t';
}
