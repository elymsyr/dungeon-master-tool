import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/dm_tool_colors.dart';

/// Karakter kağıdının sağ üstündeki minik kare. Parmak basar basmaz bölüm
/// listesi açılır (bekleme yok); kaydırıp bıraktığın bölüme sayfa atlar.
/// Bırakmadan seçmezsen liste açık kalır — item'lar tıklanabilir, boşluğa
/// dokunmak kapatır.
class SectionJumpPad extends StatefulWidget {
  final List<String> sections;
  final DmToolColors palette;
  final ValueChanged<int> onSelect;

  const SectionJumpPad({
    super.key,
    required this.sections,
    required this.palette,
    required this.onSelect,
  });

  @override
  State<SectionJumpPad> createState() => _SectionJumpPadState();
}

class _SectionJumpPadState extends State<SectionJumpPad> {
  // ponytail: sabit satır yüksekliği — indeksi parmağın y'sinden bölmeyle
  // buluyoruz. Liste kaydırılabilir olsaydı bu matematik bozulurdu; 15-20
  // bölüm 32px ile telefona sığıyor.
  static const double _itemH = 32;
  static const double _panelW = 190;

  final GlobalKey _btnKey = GlobalKey();
  final GlobalKey _listKey = GlobalKey();
  // Panel + tam ekran "boşluğa tıkla kapat" perdesi Overlay'de duruyor;
  // sayfanın Stack'i içinde kalsa perde kağıdı kaplayamazdı.
  OverlayEntry? _entry;
  int? _hover;

  bool get _open => _entry != null;

  void _updateHover(Offset globalPos) {
    final box = _listKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final local = box.globalToLocal(globalPos);
    final i = (local.dy / _itemH).floor();
    final next = (local.dx < -24 ||
            local.dx > box.size.width + 24 ||
            i < 0 ||
            i >= widget.sections.length)
        ? null
        : i;
    if (next != _hover) {
      if (next != null) HapticFeedback.selectionClick();
      _hover = next;
      _entry?.markNeedsBuild();
    }
  }

  void _openPanel() {
    if (_open || widget.sections.isEmpty) return;
    final box = _btnKey.currentContext?.findRenderObject() as RenderBox?;
    final overlay = Overlay.of(context);
    if (box == null) return;
    final origin = box.localToGlobal(Offset.zero, ancestor: overlay.context
        .findRenderObject());
    _hover = null;
    _entry = OverlayEntry(
      builder: (_) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _close,
            ),
          ),
          Positioned(
            left: (origin.dx + box.size.width - _panelW).clamp(8.0, 4000.0),
            top: origin.dy + box.size.height + 4,
            child: _panel(),
          ),
        ],
      ),
    );
    overlay.insert(_entry!);
    setState(() {});
  }

  void _close([int? pick]) {
    _entry?.remove();
    _entry = null;
    _hover = null;
    if (mounted) setState(() {});
    if (pick != null) widget.onSelect(pick);
  }

  @override
  void dispose() {
    _entry?.remove();
    _entry = null;
    super.dispose();
  }

  Widget _panel() {
    final p = widget.palette;
    return Material(
      color: p.featureCardBg,
      borderRadius: p.cbr,
      elevation: 6,
      child: Container(
        key: _listKey,
        width: _panelW,
        decoration: BoxDecoration(
          borderRadius: p.cbr,
          border: Border.all(color: p.featureCardBorder),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < widget.sections.length; i++)
              InkWell(
                onTap: () => _close(i),
                child: Container(
                  height: _itemH,
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  color:
                      _hover == i ? p.featureCardBorder : Colors.transparent,
                  child: Text(
                    widget.sections[i],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          _hover == i ? FontWeight.w700 : FontWeight.w500,
                      color: p.srdInk,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;
    // Listener: long-press gecikmesi yok — parmak değer değmez açılır,
    // kaydırıp bırakınca seçer. Mobilde tek hareket.
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) {
        HapticFeedback.selectionClick();
        _openPanel();
      },
      onPointerMove: (e) {
        if (_open) _updateHover(e.position);
      },
      onPointerUp: (_) {
        if (_hover != null) _close(_hover);
      },
      child: Container(
        key: _btnKey,
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: p.primaryBtnBg,
          borderRadius: p.br,
          border: Border.all(color: p.featureCardBorder),
        ),
        child: Icon(Icons.menu, size: 19, color: p.primaryBtnText),
      ),
    );
  }
}
