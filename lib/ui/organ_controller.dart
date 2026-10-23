import 'package:flutter/foundation.dart';

import '../odf/odf_model.dart';

/// Holds the organ being edited plus the current selection in the tree.
class OrganController extends ChangeNotifier {
  OdfDocument? doc;
  String fileName = 'untitled.organ';
  bool dirty = false;

  /// What is selected in the tree. One of:
  ///   `organ`, `g:<Type>`, `mg:<Manual###>:<Stop|Coupler|Divisional>`,
  ///   `sec:<SectionName>`.
  String selected = 'organ';

  /// Row ids of expanded tree nodes.
  final Set<String> expanded = {'organ'};

  /// Bumped when the editor has to be rebuilt from scratch.
  int editorGeneration = 0;

  void load(OdfDocument d, String name) {
    doc = d;
    fileName = name;
    dirty = false;
    selected = 'organ';
    expanded
      ..clear()
      ..add('organ');
    editorGeneration++;
    notifyListeners();
  }

  void select(String id) {
    selected = id;
    notifyListeners();
  }

  void toggle(String rowId) {
    if (!expanded.add(rowId)) expanded.remove(rowId);
    notifyListeners();
  }

  void expand(String rowId) {
    if (expanded.add(rowId)) notifyListeners();
  }

  /// A value changed (typing in a field). Keeps the editor as it is.
  void edited() {
    dirty = true;
    notifyListeners();
  }

  /// Something was added or removed. Rebuilds the editor.
  void structureChanged() {
    dirty = true;
    editorGeneration++;
    notifyListeners();
  }

  void markSaved(String name) {
    dirty = false;
    fileName = name;
    notifyListeners();
  }
}
