import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../../domain/entities/schema/entity_category_schema.dart';
import '../../../domain/entities/schema/field_group.dart';
import '../../../domain/entities/schema/field_schema.dart';
import '../../../domain/entities/schema/world_schema.dart';
import '../../../domain/services/template_edit.dart' as edit;

/// What the settings panel (desktop) or sheet (phone) shows.
enum TemplatePanel { info, category, group, field, preset }

enum TemplateSaveState { saved, pending, saving, failed }

/// The free template editor's working copy, selection and autosave (V26):
/// every edit is stored [saveDelay] after the last one, and on close.
class TemplateEditController extends ChangeNotifier {
  TemplateEditController(
    WorldSchema initial,
    this._save, {
    this.saveDelay = const Duration(milliseconds: 600),
  }) : _schema = initial;

  final Future<void> Function(WorldSchema) _save;
  final Duration saveDelay;
  static const _uuid = Uuid();

  WorldSchema _schema;
  WorldSchema get schema => _schema;

  TemplateSaveState saveState = TemplateSaveState.saved;
  Object? saveError;
  Timer? _timer;
  bool _disposed = false;
  int _edits = 0;

  /// The category open on the canvas.
  String? categoryId;
  TemplatePanel panel = TemplatePanel.info;
  String? groupId;
  String? fieldId;
  String? presetId;

  /// Center panel shows the card preview instead of the layout (V27).
  bool preview = false;

  EntityCategorySchema? get category => categoryById(categoryId);

  EntityCategorySchema? categoryById(String? id) =>
      _schema.categories.where((c) => c.categoryId == id).firstOrNull;

  FieldSchema? get field =>
      category?.fields.where((f) => f.fieldId == fieldId).firstOrNull;

  FieldGroup? get group =>
      category?.fieldGroups.where((g) => g.groupId == groupId).firstOrNull;

  /// The preset open in the settings (DESIGN §9).
  FieldSchema? get preset => presetById(presetId);

  FieldSchema? presetById(String? id) => edit.presetById(_schema, id);

  /// Where a palette click puts a new field: the selected group, the
  /// selected field's group, else ungrouped.
  String? get targetGroupId => switch (panel) {
    TemplatePanel.group => groupId,
    TemplatePanel.field => field?.groupId,
    _ => null,
  };

  static String _now() => DateTime.now().toUtc().toIso8601String();

  // ------------------------------------------------------------ selection

  void selectInfo() {
    panel = TemplatePanel.info;
    _changed();
  }

  void openCategory(String id) {
    categoryId = id;
    panel = TemplatePanel.category;
    groupId = null;
    fieldId = null;
    _changed();
  }

  void selectGroup(String? id) {
    groupId = id;
    fieldId = null;
    panel = id == null ? TemplatePanel.category : TemplatePanel.group;
    _changed();
  }

  void selectField(String id) {
    fieldId = id;
    panel = TemplatePanel.field;
    _changed();
  }

  void selectPreset(String id) {
    presetId = id;
    panel = TemplatePanel.preset;
    _changed();
  }

  void togglePreview() {
    preview = !preview;
    _changed();
  }

  // ---------------------------------------------------------------- edits

  void _edit(WorldSchema Function(WorldSchema) change) {
    _schema = change(_schema);
    _edits++;
    saveState = TemplateSaveState.pending;
    _timer?.cancel();
    _timer = Timer(saveDelay, flush);
    _changed();
  }

  void _editCategory(EntityCategorySchema Function(EntityCategorySchema) f) {
    final cat = category;
    if (cat == null) return;
    _edit((s) => edit.replaceCategory(s, f(cat)));
  }

  void updateInfo({String? name, String? description, String? version}) =>
      _edit(
        (s) => s.copyWith(
          name: name ?? s.name,
          description: description ?? s.description,
          version: version ?? s.version,
        ),
      );

  void addCategory(String name) {
    final id = _uuid.v4();
    _edit((s) => edit.addCategory(s, id: id, name: name, now: _now()));
    openCategory(id);
  }

  void updateCategory(EntityCategorySchema cat) =>
      _edit((s) => edit.replaceCategory(s, cat));

  void removeCategory(String id) {
    _edit((s) => edit.removeCategory(s, id));
    if (categoryId == id && category == null) {
      categoryId = null;
      selectInfo();
    }
  }

  void reorderCategories(List<String> orderedIds) =>
      _edit((s) => edit.reorderCategories(s, orderedIds));

  void addGroup(String name) {
    final id = _uuid.v4();
    _editCategory((c) => edit.addGroup(c, id: id, name: name));
    selectGroup(id);
  }

  void updateGroup(FieldGroup g) =>
      _editCategory((c) => edit.replaceGroup(c, g));

  void removeGroup(String id) {
    _editCategory((c) => edit.removeGroup(c, id));
    if (groupId == id) selectGroup(null);
  }

  void moveGroupFields(String from, String? to) =>
      _editCategory((c) => edit.moveGroupFields(c, from, to));

  void reorderGroups(int oldIndex, int newIndex) =>
      _editCategory((c) => edit.reorderGroups(c, oldIndex, newIndex));

  void addField(
    String label,
    FieldType type, {
    String? key,
    String? groupId,
    int? index,
  }) {
    final id = _uuid.v4();
    _editCategory(
      (c) => edit.addField(
        c,
        id: id,
        label: label,
        type: type,
        key: key,
        groupId: groupId,
        index: index,
        now: _now(),
      ),
    );
    selectField(id);
  }

  void moveField(String id, {String? groupId, int? index}) => _editCategory(
    (c) => edit.moveField(c, id, groupId: groupId, index: index),
  );

  void updateField(FieldSchema f) =>
      _editCategory((c) => edit.replaceField(c, f.copyWith(updatedAt: _now())));

  void removeField(String id) {
    _editCategory((c) => edit.removeField(c, id));
    if (fieldId == id) selectGroup(null);
  }

  /// Adds the player card's Level or Pool to its first group (DESIGN §10.1).
  void addOwnField(FieldType type, String label) => _edit(
    (s) => edit.addOwnField(s, type, id: _uuid.v4(), label: label, now: _now()),
  );

  /// Applies a style change; an incompatible one swaps in a new field, which
  /// stays selected.
  void changeFieldType(String id, FieldType to, bool toList) {
    final newId = _uuid.v4();
    _editCategory(
      (c) => edit.changeFieldType(c, id, to, toList, newId: newId, now: _now()),
    );
    if (fieldId == id && field == null) selectField(newId);
  }

  // -------------------------------------------------------------- presets

  void addPreset(String label, FieldType type) {
    final id = _uuid.v4();
    _edit(
      (s) => edit.addPreset(s, id: id, label: label, type: type, now: _now()),
    );
    selectPreset(id);
  }

  void updatePreset(FieldSchema p) =>
      _edit((s) => edit.replacePreset(s, p.copyWith(updatedAt: _now())));

  /// The open category's field [id] becomes a preset it is bound to.
  void saveAsPreset(String id) {
    final cat = category;
    if (cat == null) return;
    final presetId = _uuid.v4();
    _edit(
      (s) => edit.saveAsPreset(
        s,
        cat.categoryId,
        id,
        id: presetId,
        now: _now(),
      ),
    );
  }

  /// Adds a field bound to [presetId] to the open category; false when the
  /// category already has it or its key (V8).
  bool addPresetField(String presetId, {String? groupId, int? index}) {
    final cat = category;
    final p = edit.presetById(_schema, presetId);
    if (cat == null || p == null || !edit.canAddPreset(cat, p)) return false;
    final id = _uuid.v4();
    _editCategory(
      (c) => edit.addPresetField(
        c,
        p,
        id: id,
        groupId: groupId,
        index: index,
        now: _now(),
      ),
    );
    selectField(id);
    return true;
  }

  void unlinkField(String id) =>
      _editCategory((c) => edit.unlinkField(c, id));

  void copyPreset(String presetId, String label) {
    final id = _uuid.v4();
    _edit(
      (s) => edit.copyPreset(s, presetId, id: id, label: label, now: _now()),
    );
    selectPreset(id);
  }

  void removePreset(String id) {
    _edit((s) => edit.removePreset(s, id));
    if (presetId == id) {
      presetId = null;
      if (category != null) {
        selectGroup(null);
      } else {
        selectInfo();
      }
    }
  }

  // ------------------------------------------------------------- autosave

  /// Stores pending edits now.
  Future<void> flush() async {
    _timer?.cancel();
    if (saveState != TemplateSaveState.pending &&
        saveState != TemplateSaveState.failed) {
      return;
    }
    final edits = _edits;
    saveState = TemplateSaveState.saving;
    _changed();
    try {
      await _save(_schema);
      saveError = null;
      // An edit made while saving keeps the state pending for its own timer.
      if (edits == _edits) saveState = TemplateSaveState.saved;
    } catch (e) {
      debugPrint('template editor: save failed: $e');
      saveError = e;
      saveState = TemplateSaveState.failed;
    }
    _changed();
  }

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  /// Stores what is still pending; the save itself outlives the editor.
  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    if (saveState != TemplateSaveState.saved) {
      _save(_schema).catchError(
        (Object e) => debugPrint('template editor: save on close failed: $e'),
      );
    }
    super.dispose();
  }
}
