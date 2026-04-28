import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../application/providers/campaign_provider.dart';
import '../../application/providers/package_provider.dart';
import '../../domain/entities/schema/entity_category_schema.dart';
import '../../domain/entities/schema/world_schema.dart';
import '../theme/dm_tool_colors.dart';

/// Dialog: pick a source world, filter its entities by source/category,
/// select which to include, then export as a new package.
///
/// Reads entities directly from the chosen campaign via campaignRepository
/// so it works without that campaign being the active one.
class ExportPackageDialog extends ConsumerStatefulWidget {
  const ExportPackageDialog({super.key});

  @override
  ConsumerState<ExportPackageDialog> createState() =>
      _ExportPackageDialogState();
}

class _EntityRow {
  final String id;
  final String name;
  final String categorySlug;
  final String source;
  final Map<String, dynamic> raw;
  _EntityRow({
    required this.id,
    required this.name,
    required this.categorySlug,
    required this.source,
    required this.raw,
  });
}

class _ExportPackageDialogState extends ConsumerState<ExportPackageDialog> {
  final _nameController = TextEditingController();
  final _searchController = TextEditingController();

  String? _sourceWorldName;
  bool _loadingEntities = false;
  String? _loadError;
  List<_EntityRow> _entities = const [];
  WorldSchema? _sourceSchema;
  Map<String, dynamic>? _sourceWorldSchemaJson;
  String? _sourceTemplateId;
  String? _sourceTemplateHash;
  String? _sourceTemplateOriginalHash;

  final Set<String> _selectedSlugs = <String>{};
  final Set<String> _selectedSources = <String>{};
  final Set<String> _selectedEntityIds = <String>{};
  String _searchQuery = '';
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      if (_searchQuery != _searchController.text) {
        setState(() => _searchQuery = _searchController.text);
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFromWorld(String worldName) async {
    setState(() {
      _loadingEntities = true;
      _loadError = null;
      _entities = const [];
      _selectedEntityIds.clear();
      _selectedSlugs.clear();
      _selectedSources.clear();
      _sourceWorldName = worldName;
    });
    try {
      final data =
          await ref.read(campaignRepositoryProvider).load(worldName);
      final entitiesRaw =
          (data['entities'] as Map?)?.cast<String, dynamic>() ?? const {};
      final rows = <_EntityRow>[];
      for (final e in entitiesRaw.entries) {
        final m = Map<String, dynamic>.from(e.value as Map);
        rows.add(_EntityRow(
          id: e.key,
          name: (m['name'] as String?) ?? 'Unknown',
          categorySlug: ((m['type'] as String?) ?? 'npc')
              .toLowerCase()
              .replaceAll(' ', '-'),
          source: (m['source'] as String?) ?? '',
          raw: m,
        ));
      }
      rows.sort((a, b) => a.name.compareTo(b.name));

      final schemaJson = data['world_schema'] as Map<String, dynamic>?;
      WorldSchema? schema;
      if (schemaJson != null) {
        try {
          schema = WorldSchema.fromJson(Map<String, dynamic>.from(schemaJson));
        } catch (_) {}
      }

      if (!mounted) return;
      setState(() {
        _entities = rows;
        _sourceSchema = schema;
        _sourceWorldSchemaJson = schemaJson;
        _sourceTemplateId = data['template_id'] as String?;
        _sourceTemplateHash = data['template_hash'] as String?;
        _sourceTemplateOriginalHash =
            data['template_original_hash'] as String?;
        _loadingEntities = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.toString();
        _loadingEntities = false;
      });
    }
  }

  List<_EntityRow> get _filtered {
    final q = _searchQuery.trim().toLowerCase();
    return _entities.where((r) {
      if (_selectedSlugs.isNotEmpty &&
          !_selectedSlugs.contains(r.categorySlug)) {
        return false;
      }
      if (_selectedSources.isNotEmpty &&
          !_selectedSources.contains(r.source)) {
        return false;
      }
      if (q.isNotEmpty) {
        if (!r.name.toLowerCase().contains(q) &&
            !r.source.toLowerCase().contains(q)) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  Set<String> get _allSources {
    final s = <String>{};
    for (final r in _entities) {
      if (r.source.isNotEmpty) s.add(r.source);
    }
    return s;
  }

  List<EntityCategorySchema> get _categories =>
      _sourceSchema?.categories.where((c) => !c.isArchived).toList() ??
      const [];

  Future<void> _export() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || _selectedEntityIds.isEmpty || _sourceSchema == null) {
      return;
    }
    final repo = ref.read(packageRepositoryProvider);
    final existing = await repo.getAvailable();
    if (existing.contains(name)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Package "$name" already exists')),
      );
      return;
    }

    setState(() => _exporting = true);

    try {
      final entitiesMap = <String, dynamic>{};
      for (final r in _entities) {
        if (!_selectedEntityIds.contains(r.id)) continue;
        final m = r.raw;
        entitiesMap[r.id] = {
          'name': m['name'] ?? r.name,
          'type': m['type'] ?? r.categorySlug,
          'source': m['source'] ?? r.source,
          'description': m['description'] ?? '',
          'image_path': m['image_path'] ?? '',
          'images': m['images'] ?? const [],
          'tags': m['tags'] ?? const [],
          'dm_notes': m['dm_notes'] ?? '',
          'pdfs': m['pdfs'] ?? const [],
          'location_id': m['location_id'],
          'attributes': m['attributes'] ?? const {},
        };
      }

      final data = <String, dynamic>{
        'package_id': const Uuid().v4(),
        'package_name': name,
        'created_at': DateTime.now().toIso8601String(),
        'entities': entitiesMap,
        if (_sourceWorldSchemaJson != null)
          'world_schema': _sourceWorldSchemaJson,
        if (_sourceTemplateId != null) 'template_id': _sourceTemplateId,
        if (_sourceTemplateHash != null) 'template_hash': _sourceTemplateHash,
        if (_sourceTemplateOriginalHash != null)
          'template_original_hash': _sourceTemplateOriginalHash,
      };

      await repo.save(name, data);
      ref.invalidate(packageListProvider);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Exported "$name" with ${entitiesMap.length} entities.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final mq = MediaQuery.of(context);
    final width = mq.size.width.clamp(360.0, 720.0);
    final height = (mq.size.height * 0.8).clamp(420.0, 720.0);
    final filtered = _filtered;
    final infoAsync = ref.watch(campaignInfoListProvider);

    return Dialog(
      insetPadding:
          const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: SizedBox(
        width: width,
        height: height,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
              child: Row(
                children: [
                  Icon(Icons.upload_file,
                      size: 18, color: palette.tabActiveText),
                  const SizedBox(width: 6),
                  Text('Export Entities to Package',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: palette.tabActiveText)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: palette.sidebarDivider),
            // World picker
            Padding(
              padding:
                  const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: infoAsync.when(
                data: (worlds) => DropdownButtonFormField<String>(
                  initialValue: _sourceWorldName,
                  decoration: const InputDecoration(
                    labelText: 'Source World',
                    isDense: true,
                  ),
                  items: worlds
                      .map((w) => DropdownMenuItem(
                            value: w.name,
                            child: Text(
                                '${w.name}  (${w.templateName})',
                                style: const TextStyle(fontSize: 12)),
                          ))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) _loadFromWorld(v);
                  },
                ),
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('Error: $e'),
              ),
            ),
            // Filter row
            if (_sourceWorldName != null && !_loadingEntities)
              Padding(
                padding:
                    const EdgeInsets.fromLTRB(16, 4, 16, 4),
                child: Column(
                  children: [
                    TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        hintText: 'Search entities...',
                        prefixIcon: Icon(Icons.search, size: 18),
                        isDense: true,
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _categories.isEmpty
                                ? null
                                : () => _openCategoryDialog(palette),
                            icon: const Icon(Icons.filter_list, size: 16),
                            label: Text(
                              _selectedSlugs.isEmpty
                                  ? 'All Categories'
                                  : '${_selectedSlugs.length}/${_categories.length}',
                              style: const TextStyle(fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                            style: OutlinedButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              minimumSize: const Size(0, 32),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _allSources.isEmpty
                                ? null
                                : () => _openSourceDialog(palette),
                            icon: const Icon(Icons.label_outline, size: 16),
                            label: Text(
                              _selectedSources.isEmpty
                                  ? 'All Sources'
                                  : '${_selectedSources.length}/${_allSources.length}',
                              style: const TextStyle(fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                            style: OutlinedButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              minimumSize: const Size(0, 32),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          '${_selectedEntityIds.length} of ${filtered.length} shown selected · ${_entities.length} total',
                          style: TextStyle(
                              fontSize: 11,
                              color: palette.sidebarLabelSecondary),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: filtered.isEmpty
                              ? null
                              : () => setState(() {
                                    _selectedEntityIds
                                        .addAll(filtered.map((r) => r.id));
                                  }),
                          child: const Text('Select All',
                              style: TextStyle(fontSize: 11)),
                        ),
                        TextButton(
                          onPressed: _selectedEntityIds.isEmpty
                              ? null
                              : () => setState(_selectedEntityIds.clear),
                          child: const Text('Clear',
                              style: TextStyle(fontSize: 11)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            Divider(height: 1, color: palette.sidebarDivider),
            // Entity list
            Expanded(
              child: _sourceWorldName == null
                  ? Center(
                      child: Text('Pick a world to see its entities.',
                          style: TextStyle(
                              fontSize: 12,
                              color: palette.sidebarLabelSecondary)),
                    )
                  : _loadingEntities
                      ? const Center(child: CircularProgressIndicator())
                      : _loadError != null
                          ? Center(child: Text('Error: $_loadError'))
                          : filtered.isEmpty
                              ? Center(
                                  child: Text('No entities match.',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color:
                                              palette.sidebarLabelSecondary)))
                              : ListView.builder(
                                  itemCount: filtered.length,
                                  itemBuilder: (_, i) {
                                    final r = filtered[i];
                                    final on =
                                        _selectedEntityIds.contains(r.id);
                                    return InkWell(
                                      onTap: () => setState(() {
                                        if (on) {
                                          _selectedEntityIds.remove(r.id);
                                        } else {
                                          _selectedEntityIds.add(r.id);
                                        }
                                      }),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 4),
                                        child: Row(
                                          children: [
                                            SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: Checkbox(
                                                value: on,
                                                visualDensity:
                                                    const VisualDensity(
                                                        horizontal: -4,
                                                        vertical: -4),
                                                materialTapTargetSize:
                                                    MaterialTapTargetSize
                                                        .shrinkWrap,
                                                onChanged: (_) =>
                                                    setState(() {
                                                  if (on) {
                                                    _selectedEntityIds
                                                        .remove(r.id);
                                                  } else {
                                                    _selectedEntityIds
                                                        .add(r.id);
                                                  }
                                                }),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(r.name,
                                                      style: TextStyle(
                                                          fontSize: 13,
                                                          color: palette
                                                              .tabActiveText),
                                                      overflow: TextOverflow
                                                          .ellipsis),
                                                  if (r.source.isNotEmpty)
                                                    Text(r.source,
                                                        style: TextStyle(
                                                            fontSize: 10,
                                                            color: palette
                                                                .sidebarLabelSecondary),
                                                        overflow: TextOverflow
                                                            .ellipsis),
                                                ],
                                              ),
                                            ),
                                            Text(r.categorySlug,
                                                style: TextStyle(
                                                    fontSize: 10,
                                                    color: palette
                                                        .sidebarLabelSecondary)),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
            ),
            Divider(height: 1, color: palette.sidebarDivider),
            // Name + Export
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        hintText: 'New package name',
                        isDense: true,
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: _exporting
                        ? null
                        : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 4),
                  FilledButton.icon(
                    onPressed: (_exporting ||
                            _selectedEntityIds.isEmpty ||
                            _sourceSchema == null ||
                            _nameController.text.trim().isEmpty)
                        ? null
                        : _export,
                    icon: _exporting
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.upload, size: 16),
                    label: Text(_exporting ? 'Exporting…' : 'Export'),
                    style: FilledButton.styleFrom(
                        backgroundColor: palette.successBtnBg,
                        foregroundColor: palette.successBtnText),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openCategoryDialog(DmToolColors palette) async {
    final cats = _categories;
    final working = Set<String>.from(_selectedSlugs);
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setDialogState) {
          return AlertDialog(
            title: const Text('Filter Categories'),
            content: SizedBox(
              width: 360,
              height: 420,
              child: ListView.builder(
                itemCount: cats.length,
                itemBuilder: (_, i) {
                  final c = cats[i];
                  final on = working.contains(c.slug);
                  return InkWell(
                    onTap: () => setDialogState(() {
                      if (on) {
                        working.remove(c.slug);
                      } else {
                        working.add(c.slug);
                      }
                    }),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 2),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: Checkbox(
                              value: on,
                              visualDensity: const VisualDensity(
                                  horizontal: -4, vertical: -4),
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              onChanged: (_) => setDialogState(() {
                                if (on) {
                                  working.remove(c.slug);
                                } else {
                                  working.add(c.slug);
                                }
                              }),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(c.name,
                                style: const TextStyle(fontSize: 12),
                                overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => setDialogState(working.clear),
                child: const Text('Clear'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  setState(() {
                    _selectedSlugs
                      ..clear()
                      ..addAll(working);
                  });
                  Navigator.pop(ctx);
                },
                child: const Text('Apply'),
              ),
            ],
          );
        });
      },
    );
  }

  Future<void> _openSourceDialog(DmToolColors palette) async {
    final sorted = _allSources.toList()..sort();
    final working = Set<String>.from(_selectedSources);
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setDialogState) {
          return AlertDialog(
            title: const Text('Filter Sources'),
            content: SizedBox(
              width: 360,
              height: 420,
              child: ListView.builder(
                itemCount: sorted.length,
                itemBuilder: (_, i) {
                  final s = sorted[i];
                  final on = working.contains(s);
                  return InkWell(
                    onTap: () => setDialogState(() {
                      if (on) {
                        working.remove(s);
                      } else {
                        working.add(s);
                      }
                    }),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 2),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: Checkbox(
                              value: on,
                              visualDensity: const VisualDensity(
                                  horizontal: -4, vertical: -4),
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              onChanged: (_) => setDialogState(() {
                                if (on) {
                                  working.remove(s);
                                } else {
                                  working.add(s);
                                }
                              }),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(s,
                                style: const TextStyle(fontSize: 12),
                                overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => setDialogState(working.clear),
                child: const Text('Clear'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  setState(() {
                    _selectedSources
                      ..clear()
                      ..addAll(working);
                  });
                  Navigator.pop(ctx);
                },
                child: const Text('Apply'),
              ),
            ],
          );
        });
      },
    );
  }
}
