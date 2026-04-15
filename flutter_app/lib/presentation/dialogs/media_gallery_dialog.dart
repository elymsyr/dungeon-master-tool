import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../application/providers/campaign_provider.dart';
import '../../data/network/asset_service.dart';
import '../../data/network/network_providers.dart';
import '../../domain/value_objects/asset_ref.dart';
import '../theme/dm_tool_colors.dart';

/// Uygulama içi medya galerisi dialogu.
///
/// İki mod destekler:
/// - **Cloud mode**: `campaignId` verilmiş ve `assetServiceProvider != null`
///   ise Cloudflare R2 üzerinden `community_assets` yüklenir. Cloud mode'da
///   "This world / All worlds" sekmeleri ile diğer kampanyaların asset'leri
///   de görüntülenir. Quota dolduğunda dosya local'e (mediaDir) kopyalanır
///   ve `cloud_off` rozetiyle işaretlenir.
/// - **Local fallback**: `mediaDir` içindeki resimleri tarar. Offline veya
///   cloud devre dışıyken regresyonsuz çalışır.
class MediaGalleryDialog extends ConsumerStatefulWidget {
  final String mediaDir;
  final String campaignId;
  final bool allowMultiple;

  const MediaGalleryDialog({
    super.key,
    required this.mediaDir,
    this.campaignId = '',
    this.allowMultiple = true,
  });

  /// Galeri dialogunu göster. Seçilen dosya yollarını döndürür.
  static Future<List<String>?> show(
    BuildContext context, {
    required String mediaDir,
    String campaignId = '',
    bool allowMultiple = true,
  }) {
    return showDialog<List<String>>(
      context: context,
      builder: (_) => MediaGalleryDialog(
        mediaDir: mediaDir,
        campaignId: campaignId,
        allowMultiple: allowMultiple,
      ),
    );
  }

  @override
  ConsumerState<MediaGalleryDialog> createState() =>
      _MediaGalleryDialogState();
}

class _MediaGalleryDialogState extends ConsumerState<MediaGalleryDialog>
    with SingleTickerProviderStateMixin {
  // Cloud state
  List<CommunityAssetRow> _thisWorldRows = [];
  List<CommunityAssetRow> _allRows = [];
  Map<String, String> _campaignNames = {};
  final Map<String, File> _cloudCachedFiles = {};
  final Set<String> _cloudSelectedKeys = {};

  // Local state — cloud mode'da bile populate edilir (quota fallback dosyaları)
  List<String> _localImages = [];
  List<String> _localTrashImages = [];
  final Set<String> _localSelected = {};

  TabController? _tabController;
  int _activeTab = 0;

  // Tab indexes — cloud mode'da 3 sekme (This world, All worlds, Trash).
  static const int _tabThisWorld = 0;
  static const int _tabAllWorlds = 1;
  static const int _tabTrash = 2;

  bool get _isTrashTab => _cloudMode && _activeTab == _tabTrash;

  bool _loading = true;
  String? _error;
  bool _busy = false;

  static const _imageExtensions = {
    '.png', '.jpg', '.jpeg', '.bmp', '.webp', '.gif',
  };

  AssetService? _assetService;

  bool get _cloudMode =>
      _assetService != null && widget.campaignId.isNotEmpty;

  String get _trashDir => p.join(widget.mediaDir, '.trash');

  @override
  void initState() {
    super.initState();
    _assetService = ref.read(assetServiceProvider);
    if (_cloudMode) {
      _tabController = TabController(length: 3, vsync: this);
      _tabController!.addListener(_handleTabChange);
    }
    _load();
  }

  @override
  void dispose() {
    _tabController?.removeListener(_handleTabChange);
    _tabController?.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    if (_tabController!.indexIsChanging) return;
    setState(() => _activeTab = _tabController!.index);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    if (_cloudMode) {
      await _loadCloudData();
    }
    await _scanLocalImages();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadCloudData() async {
    try {
      final rows = await _assetService!.listAssetsForUser();
      Map<String, String> namesMap = {};
      try {
        final campaigns = await ref.read(campaignInfoListProvider.future);
        namesMap = {for (final c in campaigns) c.id: c.name};
      } catch (_) {
        // Campaign list okunamazsa badge'ler boş kalır, kritik değil
      }
      if (!mounted) return;
      setState(() {
        _allRows = rows;
        _thisWorldRows =
            rows.where((r) => r.campaignId == widget.campaignId).toList();
        _campaignNames = namesMap;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Could not load cloud assets: $e');
    }
  }

  Future<void> _scanLocalImages() async {
    final dir = Directory(widget.mediaDir);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final entries = <_ImageEntry>[];
    await for (final entry in dir.list()) {
      if (entry is File) {
        final ext = p.extension(entry.path).toLowerCase();
        if (_imageExtensions.contains(ext)) {
          final stat = await entry.stat();
          entries.add(_ImageEntry(entry.path, stat.modified));
        }
      }
    }
    entries.sort((a, b) => b.modified.compareTo(a.modified));

    // Ayrıca `.trash/` alt dizinindeki soft-delete edilmiş lokal dosyaları
    // listele. Trash sadece lokal dosyalar içindir — cloud asset'leri trash'e
    // taşınmaz, direkt kalıcı silinir.
    final trashDir = Directory(_trashDir);
    final trashEntries = <_ImageEntry>[];
    if (await trashDir.exists()) {
      await for (final entry in trashDir.list()) {
        if (entry is File) {
          final ext = p.extension(entry.path).toLowerCase();
          if (_imageExtensions.contains(ext)) {
            final stat = await entry.stat();
            trashEntries.add(_ImageEntry(entry.path, stat.modified));
          }
        }
      }
      trashEntries.sort((a, b) => b.modified.compareTo(a.modified));
    }

    if (mounted) {
      setState(() {
        _localImages = entries.map((e) => e.path).toList();
        _localTrashImages = trashEntries.map((e) => e.path).toList();
      });
    }
  }

  Future<void> _importFromFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
    );
    if (result == null || result.files.isEmpty) return;

    // Import her zaman lokal — cloud'a otomatik yükleme YOK. Dosyalar
    // `{worldsDir}/{world}/media/` altına kopyalanır; world cloud backup
    // yapıldığında MediaBundler bu dizini tarayıp R2'ye bundle'lar.
    await _importLocal(result);
  }

  /// Dosyayı widget.mediaDir'e kopyala. Çakışırsa benzersiz isim üretir.
  Future<String?> _copyToLocal(File src) async {
    try {
      final dir = Directory(widget.mediaDir);
      if (!await dir.exists()) await dir.create(recursive: true);
      final name = p.basename(src.path);
      var target = p.join(widget.mediaDir, name);
      if (await File(target).exists()) {
        final base = p.basenameWithoutExtension(name);
        final ext = p.extension(name);
        target = p.join(
          widget.mediaDir,
          '${base}_${DateTime.now().millisecondsSinceEpoch}$ext',
        );
      }
      await src.copy(target);
      return target;
    } catch (e) {
      debugPrint('media_gallery local_copy_failed ${src.path}: $e');
      return null;
    }
  }

  Future<void> _importLocal(FilePickerResult result) async {
    final imported = <String>[];
    for (final file in result.files) {
      if (file.path == null) continue;
      final src = File(file.path!);
      if (!await src.exists()) continue;
      final target = await _copyToLocal(src);
      if (target != null) imported.add(target);
    }

    await _scanLocalImages();

    if (mounted) {
      setState(() {
        for (final path in imported) {
          _localSelected.add(path);
        }
      });
    }
  }

  Future<void> _deleteSelected() async {
    final cloudCount = _cloudSelectedKeys.length;
    final localCount = _localSelected.length;
    final count = cloudCount + localCount;
    if (count == 0) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Images'),
        content: Text(
            'Delete $count selected image${count > 1 ? 's' : ''} from the media gallery?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _busy = true);
    final errors = <String>[];

    for (final key in _cloudSelectedKeys.toList()) {
      try {
        await _assetService!.deleteAsset(key);
        _cloudSelectedKeys.remove(key);
        _cloudCachedFiles.remove(key);
      } catch (e, st) {
        debugPrint('media_gallery delete_failed $key: $e\n$st');
        errors.add('${p.basename(key)}: $e');
      }
    }
    for (final path in _localSelected.toList()) {
      try {
        final file = File(path);
        if (await file.exists()) await file.delete();
        _localSelected.remove(path);
      } catch (e) {
        errors.add('${p.basename(path)}: $e');
      }
    }
    if (!mounted) return;
    setState(() => _busy = false);
    if (_cloudMode) await _loadCloudData();
    await _scanLocalImages();
    if (!mounted) return;
    if (errors.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Delete failed (${errors.length}): ${errors.first}',
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 8),
          action: SnackBarAction(
            label: 'Copy',
            textColor: Colors.white,
            onPressed: () {
              Clipboard.setData(ClipboardData(text: errors.join('\n')));
            },
          ),
        ),
      );
    }
  }

  Future<void> _deleteOne(String identifier, {required bool isCloud}) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Image'),
        content: Text(
          isCloud
              ? 'Permanently delete this cloud image? This cannot be undone.'
              : 'Move this image to Trash? You can restore it later from the '
                  'Trash tab.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: Text(isCloud ? 'Delete' : 'Move to Trash'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    if (isCloud) {
      setState(() => _busy = true);
      String? errorMessage;
      try {
        await _assetService!.deleteAsset(identifier);
        _cloudSelectedKeys.remove(identifier);
        _cloudCachedFiles.remove(identifier);
      } catch (e, st) {
        debugPrint('media_gallery delete_failed $identifier: $e\n$st');
        errorMessage = '$e';
      }
      if (!mounted) return;
      setState(() => _busy = false);
      await _loadCloudData();
      if (!mounted) return;
      if (errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Delete failed: $errorMessage'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 8),
          ),
        );
      }
    } else {
      await _moveLocalToTrash(identifier);
      _localSelected.remove(identifier);
      await _scanLocalImages();
    }
  }

  /// Dosyayı `{mediaDir}/.trash/` altına taşı. Aynı isimde dosya varsa
  /// sha-tabanlı bir suffix ekler.
  Future<void> _moveLocalToTrash(String path) async {
    final file = File(path);
    if (!await file.exists()) return;
    final trashDir = Directory(_trashDir);
    if (!await trashDir.exists()) await trashDir.create(recursive: true);
    final base = p.basename(path);
    var target = p.join(_trashDir, base);
    if (await File(target).exists()) {
      final stem = p.basenameWithoutExtension(base);
      final ext = p.extension(base);
      target = p.join(
        _trashDir,
        '${stem}_${DateTime.now().millisecondsSinceEpoch}$ext',
      );
    }
    try {
      await file.rename(target);
    } on FileSystemException {
      // Cross-device rename başarısız olursa copy + delete yap.
      await file.copy(target);
      await file.delete();
    }
  }

  /// Trash sekmesinden tile tap → Restore / Delete forever seçeneği.
  Future<void> _showTrashActions(String trashPath) async {
    final action = await showDialog<_TrashAction>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Trashed Image'),
        content: const Text('Restore this image or delete it permanently?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, _TrashAction.restore),
            child: const Text('Restore'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, _TrashAction.purge),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete forever'),
          ),
        ],
      ),
    );
    if (action == null) return;
    if (action == _TrashAction.restore) {
      await _restoreLocalTrash(trashPath);
    } else {
      await _purgeLocalTrash(trashPath);
    }
  }

  Future<void> _restoreLocalTrash(String trashPath) async {
    final file = File(trashPath);
    if (!await file.exists()) return;
    final base = p.basename(trashPath);
    var target = p.join(widget.mediaDir, base);
    if (await File(target).exists()) {
      final stem = p.basenameWithoutExtension(base);
      final ext = p.extension(base);
      target = p.join(
        widget.mediaDir,
        '${stem}_restored_${DateTime.now().millisecondsSinceEpoch}$ext',
      );
    }
    try {
      await file.rename(target);
    } on FileSystemException {
      await file.copy(target);
      await file.delete();
    }
    await _scanLocalImages();
  }

  Future<void> _purgeLocalTrash(String trashPath) async {
    final file = File(trashPath);
    if (await file.exists()) await file.delete();
    await _scanLocalImages();
  }

  void _toggleCloudSelection(String key) {
    setState(() {
      if (_cloudSelectedKeys.contains(key)) {
        _cloudSelectedKeys.remove(key);
      } else {
        if (!widget.allowMultiple) {
          _cloudSelectedKeys.clear();
          _localSelected.clear();
        }
        _cloudSelectedKeys.add(key);
      }
    });
  }

  void _toggleLocalSelection(String path) {
    setState(() {
      if (_localSelected.contains(path)) {
        _localSelected.remove(path);
      } else {
        if (!widget.allowMultiple) {
          _cloudSelectedKeys.clear();
          _localSelected.clear();
        }
        _localSelected.add(path);
      }
    });
  }

  Future<void> _confirmSelection() async {
    if (_cloudSelectedKeys.isEmpty && _localSelected.isEmpty) return;

    // Return stable refs (dmt-asset:// URIs for cloud, absolute paths for
    // local). Callers store these verbatim in entity.images[]; AssetRefImage
    // resolves them on demand. Previously cloud picks leaked the ephemeral
    // download-cache path into entities, so other devices saw a dangling
    // filesystem reference.
    final refs = <String>[];
    for (final key in _cloudSelectedKeys) {
      refs.add(AssetRef.formatCloudUri(key));
    }
    refs.addAll(_localSelected);
    Navigator.pop(context, refs);
  }

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;

    // Trash sekmesinde cloud listeleri gizli — trash sadece lokal.
    final cloudRows = (_cloudMode && !_isTrashTab)
        ? (_activeTab == _tabThisWorld ? _thisWorldRows : _allRows)
        : const <CommunityAssetRow>[];
    final cloudCount = cloudRows.length;
    final localCount =
        _isTrashTab ? _localTrashImages.length : _localImages.length;
    final totalCount = cloudCount + localCount;
    final selectedCount = _cloudSelectedKeys.length + _localSelected.length;

    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header ──
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: palette.featureCardBorder),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _cloudMode ? Icons.cloud : Icons.photo_library,
                    size: 20,
                    color: palette.tabIndicator,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _cloudMode ? 'Media Gallery (Cloud)' : 'Media Gallery',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: _busy ? null : _importFromFiles,
                    icon: const Icon(Icons.file_upload, size: 16),
                    label: const Text('Import',
                        style: TextStyle(fontSize: 12)),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Tab bar (cloud mode) ──
            if (_cloudMode && _tabController != null)
              Container(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: palette.featureCardBorder),
                  ),
                ),
                child: TabBar(
                  controller: _tabController,
                  labelColor: palette.tabActiveText,
                  unselectedLabelColor: palette.sidebarLabelSecondary,
                  indicatorColor: palette.tabIndicator,
                  labelStyle: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600),
                  unselectedLabelStyle: const TextStyle(fontSize: 12),
                  tabs: const [
                    Tab(text: 'This world', height: 32),
                    Tab(text: 'All worlds', height: 32),
                    Tab(text: 'Trash', height: 32),
                  ],
                ),
              ),

            // ── Grid / loading / empty / error ──
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              _error!,
                              style: TextStyle(color: palette.dangerBtnBg),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      : totalCount == 0
                          ? _EmptyState(palette: palette)
                          : _buildGrid(palette, cloudRows),
            ),

            // ── Footer ──
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: palette.featureCardBorder),
                ),
              ),
              child: Row(
                children: [
                  Text(
                    _isTrashTab
                        ? '$localCount trashed'
                        : _cloudMode
                            ? '$cloudCount cloud · $localCount local'
                            : '$totalCount images',
                    style: TextStyle(
                      fontSize: 11,
                      color: palette.sidebarLabelSecondary,
                    ),
                  ),
                  if (!_isTrashTab && selectedCount > 0) ...[
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: _busy ? null : _deleteSelected,
                      icon: const Icon(Icons.delete_outline, size: 16),
                      label: Text(
                        'Delete ($selectedCount)',
                        style: const TextStyle(fontSize: 12),
                      ),
                      style:
                          TextButton.styleFrom(foregroundColor: Colors.red),
                    ),
                  ],
                  const Spacer(),
                  if (_busy) ...[
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 12),
                  ],
                  TextButton(
                    onPressed:
                        _busy ? null : () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                  if (!_isTrashTab) ...[
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: (selectedCount == 0 || _busy)
                          ? null
                          : _confirmSelection,
                      child: Text(
                        selectedCount == 0
                            ? 'Select'
                            : 'Select ($selectedCount)',
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGrid(DmToolColors palette, List<CommunityAssetRow> cloudRows) {
    // Trash sekmesinde cloud tiles yok — sadece `.trash/` dizinindeki lokal
    // dosyalar gösterilir. Cloud asset silme direkt kalıcıdır (geri alınamaz).
    if (_isTrashTab) {
      final items = _localTrashImages;
      return GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
        ),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final path = items[index];
          return _LocalImageTile(
            path: path,
            isSelected: false,
            palette: palette,
            showLocalOnlyBadge: false,
            showTrashBadge: true,
            onTap: () => _showTrashActions(path),
            onDelete: () => _purgeLocalTrash(path),
          );
        },
      );
    }

    final showCampaignBadge = _cloudMode && _activeTab == _tabAllWorlds;
    final cloudCount = cloudRows.length;
    final localCount = _localImages.length;
    final total = cloudCount + localCount;

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemCount: total,
      itemBuilder: (context, index) {
        if (index < cloudCount) {
          final row = cloudRows[index];
          final isSelected = _cloudSelectedKeys.contains(row.r2Key);
          final badge = showCampaignBadge
              ? (_campaignNames[row.campaignId ?? ''] ??
                  (row.campaignId != null && row.campaignId!.length > 8
                      ? row.campaignId!.substring(0, 8)
                      : row.campaignId))
              : null;
          return _CloudImageTile(
            row: row,
            isSelected: isSelected,
            palette: palette,
            assetService: _assetService!,
            cachedFile: _cloudCachedFiles[row.r2Key],
            campaignBadge: badge,
            onDownloaded: (file) => _cloudCachedFiles[row.r2Key] = file,
            onTap: () => _toggleCloudSelection(row.r2Key),
            onDelete: () => _deleteOne(row.r2Key, isCloud: true),
          );
        }
        final path = _localImages[index - cloudCount];
        final isSelected = _localSelected.contains(path);
        return _LocalImageTile(
          path: path,
          isSelected: isSelected,
          palette: palette,
          showLocalOnlyBadge: _cloudMode,
          onTap: () => _toggleLocalSelection(path),
          onDelete: () => _deleteOne(path, isCloud: false),
        );
      },
    );
  }
}

// ── Helpers ──

enum _TrashAction { restore, purge }

class _ImageEntry {
  final String path;
  final DateTime modified;
  _ImageEntry(this.path, this.modified);
}

class _EmptyState extends StatelessWidget {
  final DmToolColors palette;
  const _EmptyState({required this.palette});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.photo_library_outlined,
            size: 48,
            color: palette.sidebarLabelSecondary,
          ),
          const SizedBox(height: 12),
          Text(
            'No images yet',
            style: TextStyle(
              color: palette.sidebarLabelSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Click Import to add images',
            style: TextStyle(
              color: palette.sidebarLabelSecondary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _LocalImageTile extends StatefulWidget {
  final String path;
  final bool isSelected;
  final DmToolColors palette;
  final bool showLocalOnlyBadge;
  final bool showTrashBadge;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _LocalImageTile({
    required this.path,
    required this.isSelected,
    required this.palette,
    required this.showLocalOnlyBadge,
    this.showTrashBadge = false,
    required this.onTap,
    required this.onDelete,
  });

  @override
  State<_LocalImageTile> createState() => _LocalImageTileState();
}

class _LocalImageTileState extends State<_LocalImageTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return _TileShell(
      hovered: _hovered,
      onHover: (v) => setState(() => _hovered = v),
      isSelected: widget.isSelected,
      palette: widget.palette,
      onTap: widget.onTap,
      onDelete: widget.onDelete,
      label: p.basename(widget.path),
      bottomLeftBadge: widget.showTrashBadge
          ? const _StatusBadge(
              icon: Icons.delete_outline,
              text: 'trash',
              color: Colors.redAccent,
            )
          : widget.showLocalOnlyBadge
              ? const _StatusBadge(
                  icon: Icons.cloud_off,
                  text: 'local',
                  color: Colors.orange,
                )
              : null,
      child: Image.file(
        File(widget.path),
        fit: BoxFit.cover,
        cacheWidth: 200,
        errorBuilder: (_, _, _) => Container(
          color: widget.palette.canvasBg,
          child: Icon(
            Icons.broken_image,
            color: widget.palette.sidebarLabelSecondary,
          ),
        ),
      ),
    );
  }
}

class _CloudImageTile extends StatefulWidget {
  final CommunityAssetRow row;
  final bool isSelected;
  final DmToolColors palette;
  final AssetService assetService;
  final File? cachedFile;
  final String? campaignBadge;
  final ValueChanged<File> onDownloaded;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _CloudImageTile({
    required this.row,
    required this.isSelected,
    required this.palette,
    required this.assetService,
    required this.cachedFile,
    required this.campaignBadge,
    required this.onDownloaded,
    required this.onTap,
    required this.onDelete,
  });

  @override
  State<_CloudImageTile> createState() => _CloudImageTileState();
}

class _CloudImageTileState extends State<_CloudImageTile> {
  bool _hovered = false;
  late Future<File> _fileFuture;

  @override
  void initState() {
    super.initState();
    _fileFuture = _resolveFile();
  }

  @override
  void didUpdateWidget(_CloudImageTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.row.r2Key != widget.row.r2Key) {
      _fileFuture = _resolveFile();
    }
  }

  Future<File> _resolveFile() async {
    if (widget.cachedFile != null) return widget.cachedFile!;
    final file = await widget.assetService.downloadAsset(widget.row.r2Key);
    widget.onDownloaded(file);
    return file;
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.row.originalFilename ?? p.basename(widget.row.r2Key);
    return _TileShell(
      hovered: _hovered,
      onHover: (v) => setState(() => _hovered = v),
      isSelected: widget.isSelected,
      palette: widget.palette,
      onTap: widget.onTap,
      onDelete: widget.onDelete,
      label: label,
      bottomLeftBadge: widget.campaignBadge != null
          ? _StatusBadge(
              icon: Icons.public,
              text: widget.campaignBadge!,
              color: widget.palette.tabIndicator,
            )
          : null,
      child: FutureBuilder<File>(
        future: _fileFuture,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return Container(
              color: widget.palette.canvasBg,
              alignment: Alignment.center,
              child: const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          }
          if (snap.hasError || !snap.hasData) {
            return Container(
              color: widget.palette.canvasBg,
              child: Icon(
                Icons.cloud_off,
                color: widget.palette.sidebarLabelSecondary,
              ),
            );
          }
          return Image.file(
            snap.data!,
            fit: BoxFit.cover,
            cacheWidth: 200,
            errorBuilder: (_, _, _) => Container(
              color: widget.palette.canvasBg,
              child: Icon(
                Icons.broken_image,
                color: widget.palette.sidebarLabelSecondary,
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Tile'ın sol-altına yerleşen küçük status etiketi (örn. "local", world adı).
class _StatusBadge extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _StatusBadge({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 9, color: Colors.white),
          const SizedBox(width: 2),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 60),
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 8,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}

/// Ortak tile çerçevesi — seçim/border/delete button/label overlay.
class _TileShell extends StatelessWidget {
  final bool hovered;
  final ValueChanged<bool> onHover;
  final bool isSelected;
  final DmToolColors palette;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final String label;
  final Widget child;
  final Widget? bottomLeftBadge;

  const _TileShell({
    required this.hovered,
    required this.onHover,
    required this.isSelected,
    required this.palette,
    required this.onTap,
    required this.onDelete,
    required this.label,
    required this.child,
    this.bottomLeftBadge,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => onHover(true),
      onExit: (_) => onHover(false),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isSelected
                  ? palette.tokenBorderActive
                  : hovered
                      ? palette.featureCardBorder
                      : Colors.transparent,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: Stack(
              fit: StackFit.expand,
              children: [
                child,
                if (isSelected)
                  Positioned(
                    top: 4,
                    left: 4,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: palette.tokenBorderActive,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                  ),
                if (hovered)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: onDelete,
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                if (bottomLeftBadge != null)
                  Positioned(
                    bottom: 16,
                    left: 4,
                    child: bottomLeftBadge!,
                  ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    color: Colors.black54,
                    child: Text(
                      label,
                      style:
                          const TextStyle(color: Colors.white, fontSize: 9),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
