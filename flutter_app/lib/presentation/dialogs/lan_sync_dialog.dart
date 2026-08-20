import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../application/providers/lan_sync_provider.dart';
import '../../application/services/lan_sync/lan_device_store.dart';
import '../l10n/app_localizations.dart';
import '../theme/dm_tool_colors.dart';
import '../widgets/save_sync_shared.dart';

/// Aynı ağdaki kendi cihazların arasında manuel içerik eşlemesi.
///
/// Tek ekran, tek karar: yukarıda **her zaman** bu cihazın eşleşme QR'ı,
/// altında eşleşmiş cihazlar (● çevrimiçi), en altta iki buton — **Eşle** ve
/// **Cihaz ekle**. Ağ arama, sekme, önizleme adımı yok.
///
/// Eşleşme kalıcıdır: bir kez okutulunca iki cihaz da birbirini hatırlar.
class LanSyncDialog extends ConsumerStatefulWidget {
  const LanSyncDialog({super.key});

  static Future<void> show(BuildContext context) => showDialog<void>(
        context: context,
        builder: (_) => const LanSyncDialog(),
      );

  @override
  ConsumerState<LanSyncDialog> createState() => _LanSyncDialogState();
}

class _LanSyncDialogState extends ConsumerState<LanSyncDialog> {
  @override
  void initState() {
    super.initState();
    // Panel açık = `/pair` ucu açık + QR üretildi. Kapanışta geri kapanır.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(lanSyncControllerProvider.notifier).openPanel();
    });
  }

  @override
  void dispose() {
    ref.read(lanSyncControllerProvider.notifier).closePanel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context)!;
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final state = ref.watch(lanSyncControllerProvider);
    final busy = state.phase == LanSyncPhase.syncing;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: palette.cbr),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 640),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header(l10n, palette),
              const SizedBox(height: 12),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _qrBlock(l10n, palette, state),
                      const SizedBox(height: 20),
                      SectionLabel(l10n.lanSyncPairedDevices, palette),
                      const SizedBox(height: 8),
                      _deviceList(l10n, palette, state, busy),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _actions(l10n, palette, state, busy),
              _statusLine(l10n, palette, state),
              const SizedBox(height: 12),
              Text(
                l10n.lanSyncNoDeleteNotice,
                style: TextStyle(
                  fontSize: 11,
                  color: palette.sidebarLabelSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(L10n l10n, DmToolColors palette) => Row(
        children: [
          Icon(Icons.wifi_tethering, size: 20, color: palette.tabActiveText),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l10n.lanSyncTitle,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: palette.tabActiveText,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: () => Navigator.pop(context),
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
        ],
      );

  // ── QR ────────────────────────────────────────────────────────────────

  Widget _qrBlock(L10n l10n, DmToolColors palette, LanSyncState state) {
    final invite = state.invite;
    if (invite == null) {
      return SizedBox(
        height: 200,
        child: Center(
          child: Text(
            l10n.lanSyncSubtitle,
            textAlign: TextAlign.center,
            style:
                TextStyle(fontSize: 12, color: palette.sidebarLabelSecondary),
          ),
        ),
      );
    }
    final address = state.manualAddresses.first;
    return Center(
      child: Column(
        children: [
          // QR her temada beyaz zeminde — koyu temada okunurluk düşmesin.
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: QrImageView(
              data: invite.toQrText(),
              version: QrVersions.auto,
              size: 180,
              backgroundColor: Colors.white,
              padding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.lanSyncQrCaption,
            style:
                TextStyle(fontSize: 12, color: palette.sidebarLabelSecondary),
          ),
          const SizedBox(height: 4),
          // Kamerası olmayan cihaz için elle giriş yedeği.
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SelectableText(
                address,
                style: TextStyle(
                  fontSize: 11,
                  color: palette.sidebarLabelSecondary,
                ),
              ),
              Text(
                '  ·  ${l10n.lanSyncPinLabel} ',
                style: TextStyle(
                  fontSize: 11,
                  color: palette.sidebarLabelSecondary,
                ),
              ),
              SelectableText(
                state.pin ?? '',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                  color: palette.featureCardAccent,
                ),
              ),
              IconButton(
                tooltip: l10n.lanSyncAddressLabel,
                icon: const Icon(Icons.copy, size: 14),
                visualDensity: VisualDensity.compact,
                onPressed: () => Clipboard.setData(
                  ClipboardData(text: address),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Cihaz listesi ─────────────────────────────────────────────────────

  Widget _deviceList(
    L10n l10n,
    DmToolColors palette,
    LanSyncState state,
    bool busy,
  ) {
    if (state.devices.isEmpty) {
      return Text(
        l10n.lanSyncNoDevices,
        style: TextStyle(fontSize: 12, color: palette.sidebarLabelSecondary),
      );
    }
    return Column(
      children: [
        for (final device in state.devices)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              device.isOnline ? Icons.circle : Icons.circle_outlined,
              size: 12,
              color: device.isOnline
                  ? palette.featureCardAccent
                  : palette.sidebarLabelSecondary,
            ),
            title: Text(
              device.name,
              style: TextStyle(fontSize: 13, color: palette.tabActiveText),
            ),
            subtitle: Text(
              device.isOnline
                  ? '${l10n.lanSyncOnline} · ${device.lastAddress}'
                  : _lastSeenText(l10n, device),
              style: TextStyle(
                fontSize: 11,
                color: palette.sidebarLabelSecondary,
              ),
            ),
            trailing: IconButton(
              tooltip: l10n.lanSyncRemoveDevice,
              icon: const Icon(Icons.close, size: 16),
              visualDensity: VisualDensity.compact,
              onPressed: busy ? null : () => _confirmRemove(device),
            ),
          ),
      ],
    );
  }

  String _lastSeenText(L10n l10n, PairedDevice device) {
    if (device.lastSeenAt.millisecondsSinceEpoch == 0) {
      return l10n.lanSyncNeverSeen;
    }
    return l10n.lanSyncLastSeen(_relative(device.lastSeenAt));
  }

  static String _relative(DateTime at) {
    final d = DateTime.now().difference(at);
    if (d.inMinutes < 1) return '<1m';
    if (d.inMinutes < 60) return '${d.inMinutes}m';
    if (d.inHours < 24) return '${d.inHours}h';
    return '${d.inDays}d';
  }

  Future<void> _confirmRemove(PairedDevice device) async {
    final l10n = L10n.of(context)!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(l10n.lanSyncRemoveConfirm(device.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.lanSyncRemove),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(lanSyncControllerProvider.notifier).removeDevice(device);
  }

  // ── Aksiyonlar ────────────────────────────────────────────────────────

  Widget _actions(
    L10n l10n,
    DmToolColors palette,
    LanSyncState state,
    bool busy,
  ) =>
      Row(
        children: [
          ActionButton(
            icon: Icons.sync,
            label: l10n.lanSyncSyncNow,
            palette: palette,
            onPressed: busy || state.devices.isEmpty
                ? null
                : () => ref.read(lanSyncControllerProvider.notifier).syncAll(),
          ),
          const SizedBox(width: 12),
          ActionButton(
            icon: Icons.add_link,
            label: l10n.lanSyncAddDevice,
            palette: palette,
            onPressed: busy ? null : _addDevice,
          ),
        ],
      );

  Widget _statusLine(
    L10n l10n,
    DmToolColors palette,
    LanSyncState state,
  ) {
    switch (state.phase) {
      case LanSyncPhase.syncing:
        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const LinearProgressIndicator(),
              const SizedBox(height: 6),
              Text(
                l10n.lanSyncProgress(state.progressLabel ?? ''),
                style: TextStyle(
                  fontSize: 11,
                  color: palette.sidebarLabelSecondary,
                ),
              ),
            ],
          ),
        );
      case LanSyncPhase.done:
        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.lanSyncSummary(state.itemsSynced, state.devicesSynced),
                style: TextStyle(fontSize: 12, color: palette.tabActiveText),
              ),
              if (state.failures.isNotEmpty)
                Text(
                  l10n.lanSyncFailures(
                    state.failures.length,
                    state.failures.join(', '),
                  ),
                  style: TextStyle(fontSize: 11, color: palette.dangerBtnBg),
                ),
            ],
          ),
        );
      case LanSyncPhase.error:
        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(
            l10n.lanSyncError(state.error ?? ''),
            style: TextStyle(fontSize: 12, color: palette.dangerBtnBg),
          ),
        );
      case LanSyncPhase.idle:
        return const SizedBox.shrink();
    }
  }

  // ── Cihaz ekleme ──────────────────────────────────────────────────────

  Future<void> _addDevice() async {
    final result = await AddLanDeviceFlow.show(context, ref);
    if (!mounted || result == null) return;
    final l10n = L10n.of(context)!;
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(SnackBar(
      content: Text(result.$1 == LanPairResult.ok
          ? l10n.lanSyncPairedWith(result.$2)
          : lanPairErrorText(l10n, result.$1)),
    ));
  }
}

/// Eşleşme hatası → kullanıcı metni. Dialog ve alt akış ortak kullanır.
String lanPairErrorText(L10n l10n, LanPairResult result) => switch (result) {
      LanPairResult.ok => '',
      LanPairResult.badQr => l10n.lanSyncErrBadQr,
      LanPairResult.badAddress => l10n.lanSyncErrBadAddress,
      LanPairResult.noHostThere => l10n.lanSyncErrNoHost,
      LanPairResult.badPin => l10n.lanSyncErrBadPin,
      LanPairResult.accountMismatch => l10n.lanSyncErrAccountMismatch,
      LanPairResult.pairingClosed => l10n.lanSyncErrPairingClosed,
      LanPairResult.notSignedIn => l10n.lanSyncErrNotSignedIn,
      LanPairResult.failed => l10n.lanSyncErrFailed,
    };

/// "Cihaz ekle" alt akışı: önce **QR mı, adres+PIN mi** diye sorar.
///
/// QR seçeneği yalnız `mobile_scanner`'ın kamera desteklediği platformlarda
/// görünür (Android/iOS/macOS). Masaüstünde doğrudan form açılır — gerçek
/// akış zaten masaüstü QR'ı gösterir, telefon okur.
class AddLanDeviceFlow {
  const AddLanDeviceFlow._();

  static bool get canScan =>
      Platform.isAndroid || Platform.isIOS || Platform.isMacOS;

  /// `(sonuç, cihaz adı)` — iptal edilirse null.
  static Future<(LanPairResult, String)?> show(
    BuildContext context,
    WidgetRef ref,
  ) async {
    if (!canScan) return _manual(context, ref);
    final l10n = L10n.of(context)!;
    final scan = await showDialog<bool>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(l10n.lanSyncHowToAdd, style: const TextStyle(fontSize: 15)),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, true),
            child: Row(children: [
              const Icon(Icons.qr_code_scanner, size: 18),
              const SizedBox(width: 12),
              Text(l10n.lanSyncScanQr),
            ]),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, false),
            child: Row(children: [
              const Icon(Icons.keyboard, size: 18),
              const SizedBox(width: 12),
              Text(l10n.lanSyncEnterManually),
            ]),
          ),
        ],
      ),
    );
    if (scan == null) return null;
    if (!context.mounted) return null;
    return scan ? _scan(context, ref) : _manual(context, ref);
  }

  static Future<(LanPairResult, String)?> _scan(
    BuildContext context,
    WidgetRef ref,
  ) =>
      showDialog<(LanPairResult, String)>(
        context: context,
        builder: (_) => const _ScanDialog(),
      );

  static Future<(LanPairResult, String)?> _manual(
    BuildContext context,
    WidgetRef ref,
  ) =>
      showDialog<(LanPairResult, String)>(
        context: context,
        builder: (_) => const _ManualPairDialog(),
      );
}

/// Kamera ile QR okuma. İlk geçerli kod eşleşmeyi tetikler ve kapanır.
class _ScanDialog extends ConsumerStatefulWidget {
  const _ScanDialog();

  @override
  ConsumerState<_ScanDialog> createState() => _ScanDialogState();
}

class _ScanDialogState extends ConsumerState<_ScanDialog> {
  final _controller = MobileScannerController();
  bool _handled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handled) return;
    final raw = capture.barcodes
        .map((b) => b.rawValue)
        .firstWhere((v) => v != null && v.isNotEmpty, orElse: () => null);
    if (raw == null) return;
    _handled = true;
    await _controller.stop();
    final controller = ref.read(lanSyncControllerProvider.notifier);
    final (result, name) = await controller.pairWithQr(raw);
    if (!mounted) return;
    if (result == LanPairResult.ok) {
      Navigator.pop(context, (result, name));
      return;
    }
    // Yanlış kod okunmuş olabilir — kullanıcıyı kameraya geri bırak.
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
      content: Text(lanPairErrorText(L10n.of(context)!, result)),
    ));
    _handled = false;
    await _controller.start();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context)!;
    final palette = Theme.of(context).extension<DmToolColors>()!;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: palette.cbr),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380, maxHeight: 480),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.lanSyncScanQr,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: palette.tabActiveText,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 300,
              child: MobileScanner(
                controller: _controller,
                onDetect: _onDetect,
                errorBuilder: (context, error) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      l10n.lanSyncCameraDenied,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: palette.sidebarLabelSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                l10n.lanSyncScanHint,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: palette.sidebarLabelSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Adres + PIN ile eşleşme. Kamerası olmayan her cihazın yolu.
class _ManualPairDialog extends ConsumerStatefulWidget {
  const _ManualPairDialog();

  @override
  ConsumerState<_ManualPairDialog> createState() => _ManualPairDialogState();
}

class _ManualPairDialogState extends ConsumerState<_ManualPairDialog> {
  final _addressCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _addressCtrl.dispose();
    _pinCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final controller = ref.read(lanSyncControllerProvider.notifier);
    final (result, name) = await controller.pairWithPin(
      address: _addressCtrl.text,
      pin: _pinCtrl.text,
    );
    if (!mounted) return;
    if (result == LanPairResult.ok) {
      Navigator.pop(context, (result, name));
      return;
    }
    setState(() {
      _busy = false;
      _error = lanPairErrorText(L10n.of(context)!, result);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context)!;
    final palette = Theme.of(context).extension<DmToolColors>()!;
    return AlertDialog(
      title: Text(l10n.lanSyncEnterManually,
          style: const TextStyle(fontSize: 15)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _addressCtrl,
            autofocus: true,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              isDense: true,
              labelText: l10n.lanSyncManualHint,
              labelStyle: const TextStyle(fontSize: 12),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _pinCtrl,
            keyboardType: TextInputType.number,
            maxLength: 6,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(fontSize: 16, letterSpacing: 4),
            decoration: InputDecoration(
              isDense: true,
              counterText: '',
              labelText: l10n.lanSyncEnterPin,
              labelStyle: const TextStyle(fontSize: 12),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(fontSize: 12, color: palette.dangerBtnBg),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        TextButton(
          onPressed: _busy ? null : _submit,
          child: Text(l10n.lanSyncManualConnect),
        ),
      ],
    );
  }
}
